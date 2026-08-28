// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Photos
import NextcloudKit

extension BackgroundUploadExtension {
    func createUploadJobs() async throws -> Bool {
        let processingJobs = PHAssetResourceUploadJob.fetchJobs(
            action: .process,
            options: nil
        )

        let acknowledgeJobs = PHAssetResourceUploadJob.fetchJobs(
            action: .acknowledge,
            options: nil
        )

        let jobsInUse = processingJobs.count + acknowledgeJobs.count
        let availableJobs = max(
            0,
            PHAssetResourceUploadJob.jobLimit - jobsInUse
        )

        guard availableJobs > 0 else {
            nkLog(
                tag: global.logTagBackgroundUpload,
                message: "No available background upload job slots"
            )
            return false
        }

        let predicate = NSPredicate(
            format: """
            status == %d AND \
            backgroundUploadJobIdentifier == %@
            """,
            global.metadataStatusWaitUpload,
            "pending"
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
            let assets = PHAsset.fetchAssets(
                withLocalIdentifiers: [metadata.assetLocalIdentifier],
                options: nil
            )

            guard let asset = assets.firstObject else {
                nkLog(
                    tag: global.logTagBackgroundUpload,
                    message: """
                    Asset not found: \(metadata.assetLocalIdentifier), \
                    file: \(metadata.fileName)
                    """
                )
                continue
            }

            guard let resource = uploadResource(
                for: asset,
                metadata: metadata
            ) else {
                nkLog(
                    tag: global.logTagBackgroundUpload,
                    message: """
                    Upload resource not found for asset \
                    \(metadata.assetLocalIdentifier)
                    """
                )
                continue
            }

            guard let destination = buildDestination(
                metadata: metadata,
                asset: asset
            ) else {
                continue
            }

            var jobIdentifier: String?

            try library.performChangesAndWait {
                let request =
                    PHAssetResourceUploadJobChangeRequest
                        .creationRequestForJob(
                            destination: destination,
                            resource: resource
                        )

                jobIdentifier =
                    request
                        .placeholderForCreatedAssetResourceUploadJob?
                        .localIdentifier
            }

            guard let jobIdentifier, !jobIdentifier.isEmpty else {
                nkLog(
                    tag: global.logTagBackgroundUpload,
                    message: "Created job has no local identifier"
                )
                continue
            }

            metadata.backgroundUploadJobIdentifier = jobIdentifier
            metadata.status = global.metadataStatusUploading
            metadata.sessionDate = Date()
            metadata.sessionError = ""
            metadata.errorCode = 0

            await database.replaceMetadataAsync(
                ocId: metadata.ocId,
                metadata: metadata
            )

            madeProgress = true

            nkLog(
                tag: global.logTagBackgroundUpload,
                message: """
                Created background upload job \(jobIdentifier), \
                file: \(metadata.fileName), \
                resource: \(resource.filename ?? "<unknown>")
                """
            )
        }

        return madeProgress
    }

    func retryUploadJobs() async throws -> Bool {
        let jobs = PHAssetResourceUploadJob.fetchJobs(
            action: .retry,
            options: nil
        )

        guard jobs.count > 0 else {
            return false
        }

        let library = PHPhotoLibrary.shared()
        var madeProgress = false

        for index in 0..<jobs.count {
            let job = jobs.object(at: index)
            let jobIdentifier = job.localIdentifier

            guard let metadata = await database.getMetadataAsync(
                predicate: NSPredicate(
                    format: "backgroundUploadJobIdentifier == %@",
                    jobIdentifier
                )
            ) else {
                nkLog(
                    tag: global.logTagBackgroundUpload,
                    message: "Retry metadata not found for job \(jobIdentifier)"
                )
                continue
            }

            let assets = PHAsset.fetchAssets(
                withLocalIdentifiers: [metadata.assetLocalIdentifier],
                options: nil
            )

            guard let asset = assets.firstObject else {
                nkLog(
                    tag: global.logTagBackgroundUpload,
                    message: """
                    Retry asset not found for job \(jobIdentifier), \
                    asset: \(metadata.assetLocalIdentifier)
                    """
                )
                continue
            }

            guard let destination = buildDestination(
                metadata: metadata,
                asset: asset
            ) else {
                nkLog(
                    tag: global.logTagBackgroundUpload,
                    message: "Unable to rebuild destination for job \(jobIdentifier)"
                )
                continue
            }

            var retryRequested = false

            try library.performChangesAndWait {
                guard let request = PHAssetResourceUploadJobChangeRequest(
                    for: job
                ) else {
                    return
                }

                request.retry(destination: destination)
                retryRequested = true
            }

            guard retryRequested else {
                nkLog(
                    tag: global.logTagBackgroundUpload,
                    message: "Unable to create retry request for job \(jobIdentifier)"
                )
                continue
            }

            metadata.sessionDate = Date()
            metadata.sessionError = ""
            metadata.errorCode = 0
            metadata.status = global.metadataStatusUploading

            // Manteniamo lo stesso job identifier.
            await database.replaceMetadataAsync(
                ocId: metadata.ocId,
                metadata: metadata
            )

            madeProgress = true

            nkLog(
                tag: global.logTagBackgroundUpload,
                message: """
                Retry requested for \(metadata.fileName), \
                job: \(jobIdentifier)
                """
            )
        }

        return madeProgress
    }

    func acknowledgeUploadJobs() async throws -> Bool {
        let jobs = PHAssetResourceUploadJob.fetchJobs(
            action: .acknowledge,
            options: nil
        )

        guard jobs.count > 0 else {
            return false
        }

        let library = PHPhotoLibrary.shared()
        var madeProgress = false

        for index in 0..<jobs.count {
            let job = jobs.object(at: index)
            let jobIdentifier = job.localIdentifier

            guard let metadata = await database.getMetadataAsync(
                predicate: NSPredicate(
                    format: "backgroundUploadJobIdentifier == %@",
                    jobIdentifier
                )
            ) else {
                nkLog(
                    tag: global.logTagBackgroundUpload,
                    message: "Metadata not found for job \(jobIdentifier)"
                )

                // Non facciamo acknowledge: il risultato rimane recuperabile.
                continue
            }

            switch job.state {
            case .succeeded:
                guard await processUploadSuccess(
                    metadata: metadata,
                    job: job
                ) else {
                    continue
                }

            case .failed:
                await updateMetadataForUploadFailure(
                    metadata: metadata,
                    job: job
                )

            default:
                nkLog(
                    tag: global.logTagBackgroundUpload,
                    message: "Unexpected state \(job.state.rawValue) for job \(jobIdentifier)"
                )
                continue
            }

            try library.performChangesAndWait {
                guard let request = PHAssetResourceUploadJobChangeRequest(
                    for: job
                ) else {
                    return
                }

                request.acknowledge()
            }

            madeProgress = true

            nkLog(
                tag: global.logTagBackgroundUpload,
                message: "Acknowledged job \(jobIdentifier), state: \(job.state.rawValue)"
            )
        }

        return madeProgress
    }

    func uploadResource(
        for asset: PHAsset,
        metadata: tableMetadata
    ) -> PHAssetResource? {
        let resources = PHAssetResource.assetResources(for: asset)

        // Prima prova a trovare la risorsa con lo stesso nome.
        if let resource = resources.first(where: {
            $0.filename?.caseInsensitiveCompare(metadata.fileName) ==
                .orderedSame
        }) {
            return resource
        }

        // Altrimenti seleziona la risorsa principale.
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

}
