// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Photos
import NextcloudKit

extension BackgroundUploadExtension {
    func createUploadJobs(account: tableAccount) async throws -> Bool {
        let availableJobs = availableUploadJobSlots()

        guard availableJobs > 0 else {
            nkLog(tag: global.logTagBackgroundUpload, message: "No available background upload job slots")
            return false
        }

        let predicate = NSPredicate(
            format: """
            status == %d AND \
            backgroundUploadJobIdentifier == %@ AND \
            account == %@
            """,
            global.metadataStatusWaitUpload,
            "pending",
            account.account
        )

        guard let metadatas = await database.getMetadatasAsync(
            predicate: predicate,
            sortedByKeyPath: "sessionDate",
            ascending: true,
            limit: availableJobs
        ),
        !metadatas.isEmpty else {
            return false
        }

        let library = PHPhotoLibrary.shared()
        var madeProgress = false

        for metadata in metadatas {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [metadata.assetLocalIdentifier], options: nil)

            guard let asset = assets.firstObject else {
                nkLog(tag: global.logTagBackgroundUpload, message: "Asset not found: \(metadata.assetLocalIdentifier), file: \(metadata.fileName)")
                continue
            }

            guard let resource = uploadResource(for: asset, metadata: metadata) else {
                nkLog(tag: global.logTagBackgroundUpload, message: "Upload resource not found for asset \(metadata.assetLocalIdentifier)")
                continue
            }

            guard let destination = buildDestination(metadata: metadata, asset: asset) else {
                continue
            }

            var jobIdentifier: String?

            try library.performChangesAndWait {
                let request = PHAssetResourceUploadJobChangeRequest.creationRequestForJob(destination: destination, resource: resource)
                jobIdentifier = request.placeholderForCreatedAssetResourceUploadJob?.localIdentifier
            }

            guard let jobIdentifier, !jobIdentifier.isEmpty else {
                nkLog(tag: global.logTagBackgroundUpload, message: "Created job has no local identifier")
                continue
            }

            metadata.backgroundUploadJobIdentifier = jobIdentifier
            metadata.status = global.metadataStatusUploading
            metadata.sessionDate = Date()
            metadata.sessionError = ""
            metadata.errorCode = 0

            await database.replaceMetadataAsync(ocId: metadata.ocId, metadata: metadata)

            madeProgress = true

            nkLog(tag: global.logTagBackgroundUpload, message: "Created background upload job \(jobIdentifier), file: \(metadata.fileName), resource: \(resource.filename ?? "<unknown>")")
        }

        return madeProgress
    }

    func cancelRequestedUploadJobs() async throws -> Bool {
        let library = PHPhotoLibrary.shared()
        var madeProgress = false

        let cancellableJobs = PHAssetResourceUploadJob.fetchJobs(action: .process, options: nil)

        for index in 0..<cancellableJobs.count {
            let job = cancellableJobs.object(at: index)
            let jobIdentifier = job.localIdentifier

            guard let metadata = await database.getMetadataAsync(
                predicate: NSPredicate(format: "backgroundUploadJobIdentifier == %@ AND backgroundUploadCancellationRequested == true", jobIdentifier)
            ) else {
                continue
            }

            guard try cancel(job: job, library: library) else {
                nkLog(tag: global.logTagBackgroundUpload, message: "Unable to cancel job \(jobIdentifier)")
                continue
            }

            await database.deleteMetadataAsync(id: metadata.ocId)
            madeProgress = true

            nkLog(tag: global.logTagBackgroundUpload, message: "Cancelled background upload job \(jobIdentifier), file: \(metadata.fileName)")
        }

        let retryJobs = PHAssetResourceUploadJob.fetchJobs(action: .retry, options: nil)
        let acknowledgeJobs = PHAssetResourceUploadJob.fetchJobs(action: .acknowledge, options: nil)

        for jobs in [retryJobs, acknowledgeJobs] {
            for index in 0..<jobs.count {
                let job = jobs.object(at: index)
                let jobIdentifier = job.localIdentifier

                guard let metadata = await database.getMetadataAsync(
                    predicate: NSPredicate(format: "backgroundUploadJobIdentifier == %@ AND backgroundUploadCancellationRequested == true", jobIdentifier)
                ) else {
                    continue
                }

                guard try acknowledge(job: job, library: library) else {
                    nkLog(tag: global.logTagBackgroundUpload, message: "Unable to acknowledge cancelled job \(jobIdentifier)")
                    continue
                }

                await database.deleteMetadataAsync(id: metadata.ocId)
                madeProgress = true

                nkLog(tag: global.logTagBackgroundUpload, message: "Acknowledged cancelled background upload job \(jobIdentifier), state: \(job.state.rawValue)")
            }
        }

        return madeProgress
    }

    func retryUploadJobs() async throws -> Bool {
        let jobs = PHAssetResourceUploadJob.fetchJobs(action: .retry, options: nil)

        guard jobs.count > 0 else {
            return false
        }

        let library = PHPhotoLibrary.shared()
        var madeProgress = false

        for index in 0..<jobs.count {
            let job = jobs.object(at: index)
            let jobIdentifier = job.localIdentifier

            guard let metadata = await database.getMetadataAsync(predicate: NSPredicate(format: "backgroundUploadJobIdentifier == %@", jobIdentifier)) else {
                guard try acknowledge(job: job, library: library) else {
                    nkLog(tag: global.logTagBackgroundUpload, message: "Unable to acknowledge orphan retry job \(jobIdentifier)")
                    continue
                }

                madeProgress = true

                nkLog(tag: global.logTagBackgroundUpload, message: "Acknowledged orphan retry job \(jobIdentifier)")
                continue
            }

            guard !metadata.backgroundUploadCancellationRequested else {
                nkLog(tag: global.logTagBackgroundUpload, message: "Skipping retry for cancellation-requested job \(jobIdentifier)")
                continue
            }

            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [metadata.assetLocalIdentifier], options: nil)

            guard let asset = assets.firstObject else {
                nkLog(tag: global.logTagBackgroundUpload, message: "Retry asset not found for job \(jobIdentifier), asset: \(metadata.assetLocalIdentifier)")
                continue
            }

            guard let destination = buildDestination(metadata: metadata, asset: asset) else {
                nkLog(tag: global.logTagBackgroundUpload, message: "Unable to rebuild destination for job \(jobIdentifier)")
                continue
            }

            var retryRequested = false

            try library.performChangesAndWait {
                guard let request = PHAssetResourceUploadJobChangeRequest(for: job) else {
                    return
                }

                request.retry(destination: destination)
                retryRequested = true
            }

            guard retryRequested else {
                nkLog(tag: global.logTagBackgroundUpload, message: "Unable to create retry request for job \(jobIdentifier)")
                continue
            }

            if metadata.backgroundUploadRetryCount < Int.max {
                metadata.backgroundUploadRetryCount += 1
            }

            metadata.backgroundUploadNextRetryDate = nil
            metadata.sessionDate = Date()
            metadata.sessionError = ""
            metadata.errorCode = 0
            metadata.status = global.metadataStatusUploading

            await database.replaceMetadataAsync(ocId: metadata.ocId, metadata: metadata)

            madeProgress = true

            nkLog(tag: global.logTagBackgroundUpload, message: "Retry requested for \(metadata.fileName), job: \(jobIdentifier)")
        }

        return madeProgress
    }

    func acknowledgeUploadJobs() async throws -> Bool {
        let jobs = PHAssetResourceUploadJob.fetchJobs(action: .acknowledge, options: nil)

        guard jobs.count > 0 else {
            return false
        }

        let library = PHPhotoLibrary.shared()
        var madeProgress = false

        for index in 0..<jobs.count {
            let job = jobs.object(at: index)
            let jobIdentifier = job.localIdentifier

            guard let metadata = await database.getMetadataAsync(predicate: NSPredicate(format: "backgroundUploadJobIdentifier == %@", jobIdentifier)) else {
                guard try acknowledge(job: job, library: library) else {
                    nkLog(tag: global.logTagBackgroundUpload, message: "Unable to acknowledge orphan job \(jobIdentifier)")
                    continue
                }

                madeProgress = true

                nkLog(tag: global.logTagBackgroundUpload, message: "Acknowledged orphan job \(jobIdentifier)")
                continue
            }

            guard !metadata.backgroundUploadCancellationRequested else {
                nkLog(tag: global.logTagBackgroundUpload, message: "Skipping normal acknowledgement for cancellation-requested job \(jobIdentifier)")
                continue
            }

            let uploadSucceeded: Bool
            let createNewJob: Bool

            switch job.state {
            case .succeeded:
                uploadSucceeded = await processUploadSuccess(metadata: metadata, job: job)
                createNewJob = false

            case .failed:
                await updateMetadataForUploadFailure(metadata: metadata, job: job)
                uploadSucceeded = false
                createNewJob = true

            default:
                nkLog(tag: global.logTagBackgroundUpload, message: "Unexpected state \(job.state.rawValue) for job \(jobIdentifier)")
                continue
            }

            guard try acknowledge(job: job, library: library) else {
                nkLog(tag: global.logTagBackgroundUpload, message: "Unable to acknowledge job \(jobIdentifier)")
                continue
            }

            if uploadSucceeded {
                metadata.backgroundUploadJobIdentifier = ""
                metadata.backgroundUploadRetryCount = 0
                metadata.backgroundUploadNextRetryDate = nil

                await database.replaceMetadataAsync(ocId: metadata.ocId, metadata: metadata)
            } else if createNewJob {
                if metadata.backgroundUploadRetryCount < Int.max {
                    metadata.backgroundUploadRetryCount += 1
                }

                metadata.backgroundUploadJobIdentifier = "pending"
                metadata.backgroundUploadNextRetryDate = nil
                metadata.sessionTaskIdentifier = 0
                metadata.sessionDate = Date()
                metadata.status = global.metadataStatusWaitUpload

                await database.replaceMetadataAsync(ocId: metadata.ocId, metadata: metadata)

                nkLog(tag: global.logTagBackgroundUpload, message: "Prepared new background upload job for \(metadata.fileName), retry: \(metadata.backgroundUploadRetryCount)")
            }

            madeProgress = true

            nkLog(tag: global.logTagBackgroundUpload, message: "Acknowledged job \(jobIdentifier), state: \(job.state.rawValue)")
        }

        return madeProgress
    }

    private func uploadResource(for asset: PHAsset, metadata: tableMetadata) -> PHAssetResource? {
        let resources = PHAssetResource.assetResources(for: asset)

        if let resource = resources.first(where: {
            $0.filename?.caseInsensitiveCompare(metadata.fileName) == .orderedSame
        }) {
            return resource
        }

        switch asset.mediaType {
        case .image:
            return resources.first(where: {
                $0.type == .fullSizePhoto
            }) ?? resources.first(where: {
                $0.type == .photo
            })

        case .video:
            return resources.first(where: {
                $0.type == .fullSizeVideo
            }) ?? resources.first(where: {
                $0.type == .video
            })

        default:
            return nil
        }
    }

    private func acknowledge(job: PHAssetResourceUploadJob, library: PHPhotoLibrary) throws -> Bool {
        var acknowledged = false

        try library.performChangesAndWait {
            guard let request = PHAssetResourceUploadJobChangeRequest(for: job) else {
                return
            }

            request.acknowledge()
            acknowledged = true
        }

        return acknowledged
    }

    private func cancel(job: PHAssetResourceUploadJob, library: PHPhotoLibrary) throws -> Bool {
        var cancelled = false

        try library.performChangesAndWait {
            guard let request = PHAssetResourceUploadJobChangeRequest(for: job) else {
                return
            }

            request.cancel()
            cancelled = true
        }

        return cancelled
    }

    func availableUploadJobSlots() -> Int {
        let processingJobs = PHAssetResourceUploadJob.fetchJobs(action: .process, options: nil)
        let acknowledgeJobs = PHAssetResourceUploadJob.fetchJobs(action: .acknowledge, options: nil)
        let jobsInUse = processingJobs.count + acknowledgeJobs.count
        let jobLimit = min(PHAssetResourceUploadJob.jobLimit, 20)

        return max(0, jobLimit - jobsInUse)
    }
}
