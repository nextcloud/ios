// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Photos
import NextcloudKit

extension BackgroundUploadExtension {
    /// Reports whether another automatic upload attempt is available for the metadata.
    /// The stored retry count excludes the initial upload, so the limit reserves one attempt for it.
    func canAutomaticallyRetry(metadata: tableMetadata) -> Bool {
        metadata.backgroundUploadRetryCount < maximumBackgroundUploadAttempts - 1
    }

    /// Records a terminal asset failure and suspends the account after three distinct failures.
    /// Returns `true` when this failure opens the account-level circuit breaker.
    @discardableResult
    func recordTerminalUploadFailure(metadata: tableMetadata) -> Bool {
        let assetIdentifier = metadata.assetLocalIdentifier.isEmpty ? metadata.ocIdTransfer : metadata.assetLocalIdentifier
        let failureCount = preferences.recordBackgroundUploadFailure(
            account: metadata.account,
            assetIdentifier: assetIdentifier
        )
        let shouldSuspend = failureCount >= maximumConsecutiveBackgroundUploadFailures

        if shouldSuspend {
            preferences.setBackgroundUploadSuspended(true, account: metadata.account)
        }

        return shouldSuspend
    }

    /// Detects authentication failures from normalized response headers or the sanitized URL error.
    /// The shared classification keeps retry and acknowledgement behavior consistent.
    func isAuthenticationFailure(job: PHAssetResourceUploadJob) -> Bool {
        let error = job.error.map { $0 as NSError }

        return job.responseHeaderFields?["www-authenticate"] != nil ||
            (error?.domain == NSURLErrorDomain && error?.code == URLError.userAuthenticationRequired.rawValue)
    }

    /// Treats a valid Nextcloud file identifier as proof that the server committed the upload.
    /// This covers successful overwrites that PhotoKit may expose as failed after an HTTP 204 response.
    func hasConfirmedUploadResponse(job: PHAssetResourceUploadJob) -> Bool {
        guard let ocId = job.responseHeaderFields?["oc-fileid"] else {
            return false
        }

        return !ocId.isEmpty
    }

    /// Logs the diagnostic values PhotoKit exposes for a failed or otherwise unexpected upload job.
    /// Request headers are excluded and sensitive response header values are redacted.
    func logUploadJobDiagnostics(job: PHAssetResourceUploadJob, action: String) {
        let error = job.error.map { $0 as NSError }
        let sensitiveHeaderNames = Set(["authorization", "cookie", "proxy-authorization", "set-cookie"])
        let responseHeaders = job.responseHeaderFields?.reduce(into: [String: String]()) { result, header in
            result[header.key] = sensitiveHeaderNames.contains(header.key.lowercased())
                ? "<redacted>"
                : header.value
        } ?? [:]
        let state: String
        let type: String

        switch job.state {
        case .registered:
            state = "registered"
        case .pending:
            state = "pending"
        case .failed:
            state = "failed"
        case .succeeded:
            state = "succeeded"
        case .cancelled:
            state = "cancelled"
        @unknown default:
            state = "unknown"
        }

        switch job.type {
        case .upload:
            type = "upload"
        case .downloadOnly:
            type = "downloadOnly"
        @unknown default:
            type = "unknown"
        }

        var destinationComponents = job.destination.url.flatMap {
            URLComponents(url: $0, resolvingAgainstBaseURL: false)
        }
        destinationComponents?.user = nil
        destinationComponents?.password = nil
        destinationComponents?.query = nil
        destinationComponents?.fragment = nil

        logInfo(
            "PhotoKit job diagnostics, action: \(action), job: \(job.localIdentifier), " +
            "state: \(state) (\(job.state.rawValue)), type: \(type) (\(job.type.rawValue)), " +
            "method: \(job.destination.httpMethod ?? "<nil>"), " +
            "destination: \(destinationComponents?.string ?? "<nil>"), " +
            "error domain: \(error?.domain ?? "<nil>"), code: \(error?.code ?? 0), " +
            "description: \(error?.localizedDescription ?? "<nil>"), " +
            "failure reason: \(error?.localizedFailureReason ?? "<nil>"), " +
            "recovery suggestion: \(error?.localizedRecoverySuggestion ?? "<nil>"), " +
            "userInfo: \(error?.userInfo ?? [:]), headers: \(responseHeaders)"
        )
    }

    /// Stores the terminal upload error and resets transient task state on the associated metadata.
    /// Authentication failures receive a stable error code so the host app can require manual retry.
    func updateMetadataForUploadFailure(metadata: tableMetadata, job: PHAssetResourceUploadJob) async {
        let error: NKError

        if isAuthenticationFailure(job: job) {
            error = NKError(errorCode: NSURLErrorUserAuthenticationRequired, errorDescription: "Authentication required for account \(metadata.user)")
        } else if let jobError = job.error {
            error = NKError(error: jobError)
        } else {
            error = NKError(errorCode: NSURLErrorUnknown, errorDescription: "Background upload failed")
        }

        await persistMetadataState(.failed(error), metadata: metadata)

        logError("Background upload failed for \(metadata.fileName), account: \(metadata.account), job: \(job.localIdentifier), error: \(error.logDescription)")
    }

    /// Checks for an existing destination only after a protected PUT failed.
    /// PhotoKit sanitizes HTTP errors, so a generic failure cannot be assumed to be HTTP 412.
    /// Returns nil for ordinary failures, false to retain a result that could not be persisted,
    /// or true once the existing resource is recorded and the transfer metadata is removed.
    func processExistingUpload(metadata: tableMetadata, job: PHAssetResourceUploadJob) async -> Bool? {
        guard job.state == .failed,
              job.destination.value(forHTTPHeaderField: "If-None-Match") == "*",
              !isAuthenticationFailure(job: job),
              database.getTableAccount(account: metadata.account)?.autoUploadForceReupload == false else { return nil }

        let result = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: metadata.serverUrlFileName, depth: "0", account: metadata.account)
        guard result.error == .success, result.files?.count == 1, let file = result.files?.first else { return nil }
        let remote = await NCManageDatabaseCreateMetadata().convertFileToMetadataAsync(file)
        guard !remote.directory, !remote.ocId.isEmpty else { return nil }

        // Stop or a new upload session may have replaced this transfer while checking the server.
        guard let account = database.getTableAccount(account: metadata.account),
              account.autoUploadStart, !account.autoUploadForceReupload,
              let current = await database.getMetadataAsync(backgroundUploadJobIdentifier: job.localIdentifier),
              current.ocId == metadata.ocId, !current.backgroundUploadCancellationRequested else { return false }

        do {
            guard try await NCLocalDatabase.shared.recordAutoUploadTransfer(current, sessionIdentifier: account.autoUploadSessionIdentifier, uploaded: true) else { return false }
            try await NCLocalDatabase.shared.recordPhotoLibraryAssetUpload(
                account: current.account, assetLocalIdentifier: current.assetLocalIdentifier,
                classFile: current.classFile, isLivePhoto: current.isLivePhoto, creationDate: current.creationDate as Date
            )
        } catch {
            logError("Unable to record existing background upload file \(current.fileName): \(error)")
            return false
        }

        if current.isLivePhoto,
           let capabilities = await database.getCapabilities(account: current.account),
           capabilities.isLivePhotoServerAvailable {
            await database.setLivePhotoVideo(account: current.account, serverUrlFileName: current.serverUrlFileName, fileId: remote.fileId, classFile: current.classFile)
        }
        await database.deleteMetadataAsync(predicate: NSPredicate(
            format: "ocId == %@ AND backgroundUploadJobIdentifier == %@ AND backgroundUploadCancellationRequested == false",
            current.ocId, job.localIdentifier
        ))
        logInfo("Skipped existing background upload file \(current.fileName), job: \(job.localIdentifier)")
        return true
    }

    /// Applies Nextcloud response metadata and records the asset as successfully auto-uploaded.
    /// A missing `oc-fileid` converts the result to an upload error and requires manual recovery.
    func processUploadSuccess(metadata: tableMetadata, job: PHAssetResourceUploadJob) async -> Bool {
        let succeeded = await NCBackgroundUploadExtensionManager.shared.recordUploadSuccess(metadata: metadata, job: job)
        if !succeeded, !hasConfirmedUploadResponse(job: job) {
            await persistMetadataState(
                .failed(NKError(errorCode: NSURLErrorBadServerResponse, errorDescription: "Upload response missing oc-fileid")),
                metadata: metadata
            )
        }
        return succeeded
    }

    /// Applies a complete background-upload state transition and persists it in Realm.
    /// Keeping related fields together prevents partially configured metadata between processing stages.
    func persistMetadataState(_ state: MetadataState, metadata: tableMetadata, sessionIdentifier: String? = nil) async {
        let expectedJobIdentifier = metadata.backgroundUploadJobIdentifier
        switch state {
        case let .uploading(jobIdentifier, incrementRetryCount):
            if incrementRetryCount, metadata.backgroundUploadRetryCount < Int.max {
                metadata.backgroundUploadRetryCount += 1
            }

            metadata.backgroundUploadJobIdentifier = jobIdentifier
            metadata.backgroundUploadNextRetryDate = nil
            metadata.sessionDate = Date()
            metadata.sessionError = ""
            metadata.errorCode = 0
            metadata.errorKind = ""
            metadata.status = global.metadataStatusUploading

        case .pendingRetry:
            if metadata.backgroundUploadRetryCount < Int.max {
                metadata.backgroundUploadRetryCount += 1
            }

            metadata.backgroundUploadJobIdentifier = "pending"
            metadata.backgroundUploadNextRetryDate = nil
            metadata.sessionTaskIdentifier = 0
            metadata.sessionDate = Date()
            metadata.status = global.metadataStatusWaitUpload

        case .manualRetryRequired:
            metadata.backgroundUploadJobIdentifier = "pending"
            metadata.backgroundUploadNextRetryDate = nil

        case let .failed(error):
            metadata.sessionTaskIdentifier = 0
            metadata.sessionDate = Date()
            metadata.sessionError = error.errorDescription
            metadata.errorCode = error.errorCode
            metadata.errorKind = error.kind?.rawValue ?? ""
            metadata.status = global.metadataStatusUploadError

        case .completed:
            metadata.chunk = 0
            metadata.sceneIdentifier = nil
            metadata.session = ""
            metadata.sessionError = ""
            metadata.errorKind = ""
            metadata.sessionDate = nil
            metadata.sessionTaskIdentifier = 0
            metadata.status = global.metadataStatusNormal
            metadata.backgroundUploadJobIdentifier = ""
            metadata.backgroundUploadRetryCount = 0
            metadata.backgroundUploadNextRetryDate = nil
        }

        await database.updateBackgroundUploadMetadataAsync(metadata, expectedJobIdentifier: expectedJobIdentifier, sessionIdentifier: sessionIdentifier)
    }
}
