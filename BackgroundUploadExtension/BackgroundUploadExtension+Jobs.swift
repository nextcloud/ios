// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Photos
import NextcloudKit

extension BackgroundUploadExtension {
    /// Converts pending metadata records into PhotoKit upload jobs until the job limit is reached.
    /// Persists each PhotoKit identifier so later invocations can reconcile the job with Realm state.
    func createUploadJobs(account: tableAccount) async throws -> Bool {
        let availableJobs = availableUploadJobSlots()

        guard availableJobs > 0 else {
            logDebug("No available background upload job slots")
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
                logError("Asset not found: \(metadata.assetLocalIdentifier), file: \(metadata.fileName)")
                continue
            }

            guard let resource = uploadResource(for: asset, metadata: metadata) else {
                logError("Upload resource not found for asset \(metadata.assetLocalIdentifier)")
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
                logError("Created job has no local identifier")
                continue
            }

            metadata.backgroundUploadJobIdentifier = jobIdentifier
            metadata.status = global.metadataStatusUploading
            metadata.sessionDate = Date()
            metadata.sessionError = ""
            metadata.errorCode = 0

            await database.replaceMetadataAsync(ocId: metadata.ocId, metadata: metadata)

            madeProgress = true

            logInfo("Created background upload job \(jobIdentifier), file: \(metadata.fileName), resource: \(resource.filename ?? "<unknown>")")
        }

        return madeProgress
    }

    /// Cancels active jobs requested by the app and cleans up terminal or orphaned jobs.
    /// Associated metadata is deleted only after PhotoKit accepts the cancellation or acknowledgement.
    func cancelRequestedUploadJobs() async throws -> Bool {
        let library = PHPhotoLibrary.shared()
        var madeProgress = false
        let cancellableJobs = PHAssetResourceUploadJob.fetchJobs(action: .process, options: nil)

        for index in 0..<cancellableJobs.count {
            let job = cancellableJobs.object(at: index)
            let jobIdentifier = job.localIdentifier
            let metadata = await database.getMetadataAsync(backgroundUploadJobIdentifier: jobIdentifier)

            guard let metadata else {
                guard try cancel(job: job, library: library) else {
                    logError("Unable to cancel orphan background upload job \(jobIdentifier)")
                    continue
                }

                madeProgress = true
                logInfo("Cancelled orphan background upload job \(jobIdentifier)", persist: true)
                continue
            }

            guard metadata.backgroundUploadCancellationRequested else {
                continue
            }

            guard try cancel(job: job, library: library) else {
                logError("Unable to cancel job \(jobIdentifier)")
                continue
            }

            await database.deleteMetadataAsync(id: metadata.ocId)
            madeProgress = true
            logInfo("Cancelled background upload job \(jobIdentifier), file: \(metadata.fileName)", persist: true)
        }

        let retryJobs = PHAssetResourceUploadJob.fetchJobs(action: .retry, options: nil)
        let acknowledgeJobs = PHAssetResourceUploadJob.fetchJobs(action: .acknowledge, options: nil)

        for jobs in [retryJobs, acknowledgeJobs] {
            for index in 0..<jobs.count {
                let job = jobs.object(at: index)
                let jobIdentifier = job.localIdentifier
                let metadata = await database.getMetadataAsync(backgroundUploadJobIdentifier: jobIdentifier)

                guard let metadata else {
                    guard try acknowledge(job: job, library: library) else {
                        logError("Unable to acknowledge orphan background upload job \(jobIdentifier)")
                        continue
                    }

                    madeProgress = true
                    logInfo("Acknowledged orphan background upload job \(jobIdentifier)", persist: true)
                    continue
                }

                guard metadata.backgroundUploadCancellationRequested else {
                    continue
                }

                guard try acknowledge(job: job, library: library) else {
                    logError("Unable to acknowledge cancelled job \(jobIdentifier)")
                    continue
                }

                await database.deleteMetadataAsync(id: metadata.ocId)
                madeProgress = true
                logInfo("Acknowledged cancelled background upload job \(jobIdentifier), state: \(job.state.rawValue)", persist: true)
            }
        }

        return madeProgress
    }

    /// Retries PhotoKit jobs eligible for one system retry using freshly built credentials and settings.
    /// Authentication failures are acknowledged and left in Realm for an explicit manual retry.
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

            guard let metadata = await database.getMetadataAsync(backgroundUploadJobIdentifier: jobIdentifier) else {
                guard try acknowledge(job: job, library: library) else {
                    logError("Unable to acknowledge orphan retry job \(jobIdentifier)")
                    continue
                }

                madeProgress = true

                logInfo("Acknowledged orphan retry job \(jobIdentifier)", persist: true)
                continue
            }

            guard !metadata.backgroundUploadCancellationRequested else {
                logDebug("Skipping retry for cancellation-requested job \(jobIdentifier)")
                continue
            }

            let error = job.error.map { $0 as NSError }

            logInfo("Retryable job \(jobIdentifier), error domain: \(error?.domain ?? "<nil>"), code: \(error?.code ?? 0), description: \(error?.localizedDescription ?? "<nil>"), headers: \(job.responseHeaderFields ?? [:])")

            let authenticationRequired = isAuthenticationFailure(job: job)
            let retryLimitReached = !canAutomaticallyRetry(metadata: metadata)
            let queueSuspended = preferences.isBackgroundUploadSuspended(account: metadata.account)

            // Stop before a fourth upload, invalid credentials, or work on a suspended account queue.
            if authenticationRequired || retryLimitReached || queueSuspended {
                if authenticationRequired {
                    // Invalid credentials affect every file, so suspend the account immediately.
                    preferences.setBackgroundUploadSuspended(true, account: metadata.account)
                } else if retryLimitReached,
                          !queueSuspended,
                          recordTerminalUploadFailure(metadata: metadata) {
                    logError("Suspended background upload after \(maximumConsecutiveBackgroundUploadFailures) consecutive asset failures for account \(metadata.account)")
                }
                await updateMetadataForUploadFailure(metadata: metadata, job: job)

                guard try acknowledge(job: job, library: library) else {
                    logError("Unable to acknowledge stopped job \(jobIdentifier)")
                    continue
                }

                // Keep the failed transfer available for an explicit retry from the host app.
                metadata.backgroundUploadJobIdentifier = "pending"
                metadata.backgroundUploadNextRetryDate = nil
                await database.replaceMetadataAsync(ocId: metadata.ocId, metadata: metadata)

                madeProgress = true
                if authenticationRequired {
                    logError("Stopped background upload after authentication failure for \(metadata.fileName), job: \(jobIdentifier)")
                } else if retryLimitReached {
                    logError("Stopped background upload after \(maximumBackgroundUploadAttempts) failed attempts for \(metadata.fileName), job: \(jobIdentifier)")
                } else {
                    logInfo("Stopped background upload because the account queue is suspended for \(metadata.fileName), job: \(jobIdentifier)")
                }
                continue
            }

            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [metadata.assetLocalIdentifier], options: nil)

            guard let asset = assets.firstObject else {
                logError("Retry asset not found for job \(jobIdentifier), asset: \(metadata.assetLocalIdentifier)")
                continue
            }

            guard let destination = buildDestination(metadata: metadata, asset: asset) else {
                logError("Unable to rebuild destination for job \(jobIdentifier)")
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
                logError("Unable to create retry request for job \(jobIdentifier)")
                continue
            }

            // PhotoKit is about to perform the next upload attempt for the same job.
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

            logInfo("Retry requested for \(metadata.fileName), job: \(jobIdentifier)")
        }

        return madeProgress
    }

    /// Records terminal job results in Realm before acknowledging them to free PhotoKit capacity.
    /// Successful uploads are finalized; retryable failures create pending work for a new job.
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

            guard let metadata = await database.getMetadataAsync(backgroundUploadJobIdentifier: jobIdentifier) else {
                guard try acknowledge(job: job, library: library) else {
                    logError("Unable to acknowledge orphan job \(jobIdentifier)")
                    continue
                }

                madeProgress = true

                logInfo("Acknowledged orphan job \(jobIdentifier)", persist: true)
                continue
            }

            guard !metadata.backgroundUploadCancellationRequested else {
                logDebug("Skipping normal acknowledgement for cancellation-requested job \(jobIdentifier)")
                continue
            }

            let uploadSucceeded: Bool
            let createNewJob: Bool

            switch job.state {
            case .succeeded:
                uploadSucceeded = await processUploadSuccess(metadata: metadata, job: job)
                createNewJob = false

            case .failed:
                let authenticationRequired = isAuthenticationFailure(job: job)
                let retryLimitReached = !canAutomaticallyRetry(metadata: metadata)
                let queueSuspended = preferences.isBackgroundUploadSuspended(account: metadata.account)

                if authenticationRequired {
                    // Invalid credentials affect every file, so suspend the account immediately.
                    preferences.setBackgroundUploadSuspended(true, account: metadata.account)
                } else if retryLimitReached,
                          !queueSuspended,
                          recordTerminalUploadFailure(metadata: metadata) {
                    logError("Suspended background upload after \(maximumConsecutiveBackgroundUploadFailures) consecutive asset failures for account \(metadata.account)")
                }

                await updateMetadataForUploadFailure(metadata: metadata, job: job)
                uploadSucceeded = false
                createNewJob = !authenticationRequired && !retryLimitReached && !queueSuspended

            default:
                logError("Unexpected state \(job.state.rawValue) for job \(jobIdentifier)")
                continue
            }

            guard try acknowledge(job: job, library: library) else {
                logError("Unable to acknowledge job \(jobIdentifier)")
                continue
            }

            if uploadSucceeded {
                metadata.backgroundUploadJobIdentifier = ""
                metadata.backgroundUploadRetryCount = 0
                metadata.backgroundUploadNextRetryDate = nil

                await database.replaceMetadataAsync(ocId: metadata.ocId, metadata: metadata)
            } else if createNewJob {
                // A PhotoKit job can be retried only once; create a fresh job for the remaining attempt.
                if metadata.backgroundUploadRetryCount < Int.max {
                    metadata.backgroundUploadRetryCount += 1
                }

                metadata.backgroundUploadJobIdentifier = "pending"
                metadata.backgroundUploadNextRetryDate = nil
                metadata.sessionTaskIdentifier = 0
                metadata.sessionDate = Date()
                metadata.status = global.metadataStatusWaitUpload

                await database.replaceMetadataAsync(ocId: metadata.ocId, metadata: metadata)

                logInfo("Prepared new background upload job for \(metadata.fileName), retry: \(metadata.backgroundUploadRetryCount)")
            } else {
                // `uploadError` prevents automatic scheduling while `pending` enables manual retry.
                metadata.backgroundUploadJobIdentifier = "pending"
                metadata.backgroundUploadNextRetryDate = nil
                await database.replaceMetadataAsync(ocId: metadata.ocId, metadata: metadata)

                logInfo("Background upload requires a manual retry for \(metadata.fileName)")
            }

            madeProgress = true

            logDebug("Acknowledged job \(jobIdentifier), state: \(job.state.rawValue)")
        }

        return madeProgress
    }

    /// Resolves the Photos resource represented by a metadata record, including Live Photo components.
    /// It prefers an exact filename match before falling back to the asset's primary resource type.
    private func uploadResource(for asset: PHAsset, metadata: tableMetadata) -> PHAssetResource? {
        let resources = PHAssetResource.assetResources(for: asset)

        if metadata.isLivePhotoVideo {
            return resources.first {
                $0.type == .fullSizePairedVideo
            } ?? resources.first {
                $0.type == .pairedVideo
            }
        }

        if metadata.isLivePhotoImage {
            return resources.first {
                $0.type == .fullSizePhoto
            } ?? resources.first {
                $0.type == .photo
            }
        }

        if let resource = resources.first(where: {
            $0.filename?.caseInsensitiveCompare(metadata.fileName) == .orderedSame
        }) {
            return resource
        }

        switch asset.mediaType {
        case .image:
            return resources.first {
                $0.type == .fullSizePhoto
            } ?? resources.first {
                $0.type == .photo
            }

        case .video:
            return resources.first {
                $0.type == .fullSizeVideo
            } ?? resources.first {
                $0.type == .video
            }

        default:
            return nil
        }
    }

    /// Requests acknowledgement of a terminal PhotoKit job inside a synchronous library transaction.
    /// Returns `false` if PhotoKit cannot create a change request for the supplied job.
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

    /// Requests cancellation of a registered or pending PhotoKit job inside a library transaction.
    /// Returns `false` if the job is no longer mutable by the time the change block executes.
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

    /// Computes free PhotoKit capacity by deduplicating jobs exposed through all actionable states.
    /// The extension intentionally caps its own queue at 20 jobs even if the system limit is higher.
    func availableUploadJobSlots() -> Int {
        let actions: [PHAssetResourceUploadJob.Action] = [.process, .retry, .acknowledge]
        var jobIdentifiers = Set<String>()

        for action in actions {
            let jobs = PHAssetResourceUploadJob.fetchJobs(action: action, options: nil)

            for index in 0..<jobs.count {
                jobIdentifiers.insert(jobs.object(at: index).localIdentifier)
            }
        }

        let jobLimit = min(PHAssetResourceUploadJob.jobLimit, 20)
        return max(0, jobLimit - jobIdentifiers.count)
    }

    /// Reports whether PhotoKit still exposes jobs requiring processing, retry, or acknowledgement.
    /// This keeps the extension scheduled while system-managed upload work remains outstanding.
    func hasActiveUploadJobs() -> Bool {
        PHAssetResourceUploadJob.fetchJobs(action: .process, options: nil).count > 0 ||
        PHAssetResourceUploadJob.fetchJobs(action: .retry, options: nil).count > 0 ||
        PHAssetResourceUploadJob.fetchJobs(action: .acknowledge, options: nil).count > 0
    }
}
