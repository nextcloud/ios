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
            logInfo("No available background upload job slots")
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
            guard let currentAccount = await database.getTableAccountAsync(
                predicate: NSPredicate(format: "account == %@", account.account)
            ), currentAccount.autoUploadStart else {
                break
            }

            guard let currentMetadata = await database.getMetadataAsync(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)),
                  !currentMetadata.backgroundUploadCancellationRequested else {
                continue
            }
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [metadata.assetLocalIdentifier], options: nil)

            guard let asset = assets.firstObject else {
                await database.deleteMetadataAsync(id: metadata.ocId)
                madeProgress = true
                logInfo("Deleted pending background upload metadata for missing asset \(metadata.assetLocalIdentifier), file: \(metadata.fileName)")
                continue
            }

            guard let resource = uploadResource(for: asset, metadata: metadata) else {
                await database.deleteMetadataAsync(id: metadata.ocId)
                madeProgress = true

                logInfo(
                    "Deleted pending background upload metadata because the resource is no longer available for asset \(metadata.assetLocalIdentifier), file: \(metadata.fileName)"
                )

                continue
            }

            guard let destination = buildDestination(metadata: metadata, asset: asset) else {
                continue
            }

            var jobIdentifier: String?

            // PhotoKit job creation must happen inside its library change transaction.
            try library.performChangesAndWait {
                guard database.getTableAccount(account: account.account)?.autoUploadStart == true else { return }
                let request = PHAssetResourceUploadJobChangeRequest.creationRequestForJob(destination: destination, resource: resource)
                jobIdentifier = request.placeholderForCreatedAssetResourceUploadJob?.localIdentifier
            }

            guard let jobIdentifier, !jobIdentifier.isEmpty else {
                logError("Created job has no local identifier")
                continue
            }

            await persistMetadataState(
                .uploading(jobIdentifier: jobIdentifier, incrementRetryCount: false),
                metadata: metadata
            )

            if database.getTableAccount(account: account.account)?.autoUploadStart != true {
                metadata.backgroundUploadCancellationRequested = true
                await database.replaceMetadataAsync(ocId: metadata.ocId, metadata: metadata)
                _ = try await cancelRequestedUploadJobs()
                break
            }

            madeProgress = true

            logInfo("Created background upload job \(jobIdentifier), file: \(metadata.fileName), resource: \(resource.filename ?? "<unknown>")")
        }

        return madeProgress
    }

    /// Cancels jobs requested by the app and recovers jobs whose identifier was not persisted after creation.
    /// A job is treated as orphaned only when no pending metadata matches its asset and destination.
    func cancelRequestedUploadJobs() async throws -> Bool {
        let library = PHPhotoLibrary.shared()
        var madeProgress = false
        let cancellableJobs = PHAssetResourceUploadJob.fetchJobs(action: .process, options: nil)

        for index in 0..<cancellableJobs.count {
            let job = cancellableJobs.object(at: index)
            let jobIdentifier = job.localIdentifier
            let metadata = await resolveMetadata(for: job)

            guard let metadata else {
                guard try cancel(job: job, library: library) else {
                    logError("Unable to cancel orphan background upload job \(jobIdentifier)")
                    continue
                }

                madeProgress = true
                logInfo("Cancelled orphan background upload job \(jobIdentifier)")
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
            logInfo("Cancelled background upload job \(jobIdentifier), file: \(metadata.fileName)")
        }

        let retryJobs = PHAssetResourceUploadJob.fetchJobs(action: .retry, options: nil)
        let acknowledgeJobs = PHAssetResourceUploadJob.fetchJobs(action: .acknowledge, options: nil)
        var handledTerminalJobIdentifiers = Set<String>()

        for jobs in [retryJobs, acknowledgeJobs] {
            for index in 0..<jobs.count {
                let job = jobs.object(at: index)
                let jobIdentifier = job.localIdentifier

                // Failed jobs can appear in both collections; acknowledge each one only once.
                guard handledTerminalJobIdentifiers.insert(jobIdentifier).inserted else {
                    continue
                }

                let metadata = await resolveMetadata(for: job)

                guard let metadata else {
                    guard try acknowledge(job: job, library: library) else {
                        logError("Unable to acknowledge orphan background upload job \(jobIdentifier)")
                        continue
                    }

                    madeProgress = true
                    logInfo("Acknowledged orphan background upload job \(jobIdentifier)")
                    continue
                }

                guard metadata.backgroundUploadCancellationRequested else {
                    continue
                }

                if !(job.responseHeaderFields?["oc-fileid"] ?? "").isEmpty {
                    guard await processUploadSuccess(metadata: metadata, job: job) else { continue }
                    await persistMetadataState(.completed, metadata: metadata)
                } else if job.state == .succeeded {
                    logError("Stop deferred for successful job without oc-fileid: \(jobIdentifier)")
                    continue
                }

                guard try acknowledge(job: job, library: library) else {
                    logError("Unable to acknowledge cancelled job \(jobIdentifier)")
                    continue
                }

                if metadata.status != global.metadataStatusNormal {
                    await database.deleteMetadataAsync(id: metadata.ocId)
                }
                madeProgress = true
                logInfo("Acknowledged cancelled background upload job \(jobIdentifier), state: \(job.state.rawValue)")
            }
        }

        return madeProgress
    }

    /// Examines jobs for which PhotoKit offers a retry and decides whether to retry or acknowledge them.
    /// Server-confirmed uploads and permanent failures are acknowledged instead of being uploaded again.
    func processRetryableUploadJobs() async throws -> Bool {
        let jobs = PHAssetResourceUploadJob.fetchJobs(action: .retry, options: nil)

        guard jobs.count > 0 else {
            return false
        }

        let library = PHPhotoLibrary.shared()
        var madeProgress = false

        for index in 0..<jobs.count {
            let job = jobs.object(at: index)
            let jobIdentifier = job.localIdentifier

            guard let metadata = await resolveMetadata(for: job) else {
                guard try acknowledge(job: job, library: library) else {
                    logError("Unable to acknowledge orphan retry job \(jobIdentifier)")
                    continue
                }

                madeProgress = true

                logInfo("Acknowledged orphan retry job \(jobIdentifier)")
                continue
            }

            guard !metadata.backgroundUploadCancellationRequested else {
                logInfo("Skipping retry for cancellation-requested job \(jobIdentifier)")
                continue
            }

            logUploadJobDiagnostics(job: job, action: "retry")

            if hasConfirmedUploadResponse(job: job) {
                // Nextcloud committed the file even though PhotoKit classified the overwrite as failed.
                // First persist the successful response in Realm, including the server file identifier,
                // auto-upload history, and any pending Live Photo component.
                guard await processUploadSuccess(metadata: metadata, job: job) else {
                    continue
                }

                // Close local tracking before acknowledging PhotoKit. If the extension stops between
                // these operations, the remaining terminal job is safely acknowledged as an orphan.
                await persistMetadataState(.completed, metadata: metadata)

                // Acknowledgement is the final confirmation to PhotoKit: it removes the completed job
                // from the system queue and prevents PhotoKit from uploading the same resource again.
                guard try acknowledge(job: job, library: library) else {
                    logError("Unable to acknowledge server-confirmed retry job \(jobIdentifier)")
                    continue
                }

                madeProgress = true
                logInfo("Accepted server-confirmed upload for \(metadata.fileName), job: \(jobIdentifier)")
                continue
            }

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
                await persistMetadataState(.manualRetryRequired, metadata: metadata)

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
                guard try acknowledge(job: job, library: library) else {
                    logError("Unable to acknowledge retry job for missing asset \(jobIdentifier)")
                    continue
                }

                await database.deleteMetadataAsync(id: metadata.ocId)
                madeProgress = true
                logInfo("Acknowledged retry job and deleted metadata for missing asset \(metadata.assetLocalIdentifier), file: \(metadata.fileName)")
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
            await persistMetadataState(
                .uploading(jobIdentifier: jobIdentifier, incrementRetryCount: true),
                metadata: metadata
            )

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

            guard let metadata = await resolveMetadata(for: job) else {
                guard try acknowledge(job: job, library: library) else {
                    logError("Unable to acknowledge orphan job \(jobIdentifier)")
                    continue
                }

                madeProgress = true

                logInfo("Acknowledged orphan job \(jobIdentifier)")
                continue
            }

            guard !metadata.backgroundUploadCancellationRequested else {
                logInfo("Skipping normal acknowledgement for cancellation-requested job \(jobIdentifier)")
                continue
            }

            let uploadSucceeded: Bool
            let createNewJob: Bool

            switch job.state {
            case .succeeded:
                uploadSucceeded = await processUploadSuccess(metadata: metadata, job: job)
                createNewJob = false

            case .failed:
                logUploadJobDiagnostics(job: job, action: "acknowledge")

                if hasConfirmedUploadResponse(job: job) {
                    // A valid oc-fileid takes precedence over PhotoKit's failed state for HTTP 204.
                    uploadSucceeded = await processUploadSuccess(metadata: metadata, job: job)
                    createNewJob = false
                    logInfo("Accepted server-confirmed upload for \(metadata.fileName), job: \(jobIdentifier)")
                } else {
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
                }

            default:
                logUploadJobDiagnostics(job: job, action: "acknowledge")
                logError("Unexpected state \(job.state.rawValue) for job \(jobIdentifier)")
                continue
            }

            if uploadSucceeded {
                // Persist the closed local state first. If acknowledgement is interrupted, the
                // remaining PhotoKit job is harmless and will be cleaned up as an orphan next time.
                await persistMetadataState(.completed, metadata: metadata)
            }

            // The terminal result is now stored locally; acknowledge it to release PhotoKit's job slot.
            guard try acknowledge(job: job, library: library) else {
                logError("Unable to acknowledge job \(jobIdentifier)")
                continue
            }

            if !uploadSucceeded && createNewJob {
                // A PhotoKit job can be retried only once; create a fresh job for the remaining attempt.
                await persistMetadataState(.pendingRetry, metadata: metadata)

                logInfo("Prepared new background upload job for \(metadata.fileName), retry: \(metadata.backgroundUploadRetryCount)")
            } else if !uploadSucceeded {
                // `uploadError` prevents automatic scheduling while `pending` enables manual retry.
                await persistMetadataState(.manualRetryRequired, metadata: metadata)

                logInfo("Background upload requires a manual retry for \(metadata.fileName)")
            }

            madeProgress = true

            logInfo("Acknowledged job \(jobIdentifier), state: \(job.state.rawValue)")
        }

        return madeProgress
    }

    /// Resolves a job through its stored identifier or reconnects it to metadata left pending by an interruption.
    /// Asset identity narrows the candidates and the destination URL distinguishes Live Photo components.
    private func resolveMetadata(for job: PHAssetResourceUploadJob) async -> tableMetadata? {
        if let metadata = await database.getMetadataAsync(backgroundUploadJobIdentifier: job.localIdentifier) {
            return metadata
        }

        guard let resource = PHAssetResource.assetResource(forUploadJob: job),
              let destinationURL = job.destination.url else {
            return nil
        }

        let candidates = await database.getPendingBackgroundUploadMetadatasAsync(
            assetLocalIdentifier: resource.assetLocalIdentifier
        )
        let matchingCandidates = candidates.filter { metadata in
            guard let metadataURL = metadata.serverUrlFileName.encodedToUrl as? URL else {
                return false
            }

            return metadataURL == destinationURL
        }

        guard matchingCandidates.count == 1,
              let metadata = matchingCandidates.first else {
            if matchingCandidates.count > 1 {
                logError("Unable to recover job \(job.localIdentifier): multiple pending metadata match its destination")
            }
            return nil
        }

        // PhotoKit committed the job before the previous process could store its identifier in Realm.
        await persistMetadataState(
            .uploading(jobIdentifier: job.localIdentifier, incrementRetryCount: false),
            metadata: metadata
        )

        logInfo(
            "Recovered background upload job \(job.localIdentifier), file: \(metadata.fileName), " +
            "resource: \(resource.filename ?? "<unknown>")"
        )
        return metadata
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

    /// Confirms to PhotoKit that the terminal result has already been persisted and can be discarded.
    /// Acknowledgement removes the job from the system queue and prevents any further retry for it.
    /// Returns `false` if PhotoKit cannot create a change request for the supplied job.
    private func acknowledge(job: PHAssetResourceUploadJob, library: PHPhotoLibrary) throws -> Bool {
        var acknowledged = false

        try library.performChangesAndWait {
            guard let request = PHAssetResourceUploadJobChangeRequest(for: job) else {
                return
            }

            // This is the actual confirmation to PhotoKit; it is not another server request.
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
