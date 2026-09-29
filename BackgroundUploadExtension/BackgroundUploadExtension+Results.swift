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
        let error = job.error.map { $0 as NSError }
        let authenticationRequired = isAuthenticationFailure(job: job)
        let message = authenticationRequired
            ? "Authentication required for account \(metadata.user)"
            : error?.localizedDescription ?? "Background upload failed"
        let errorCode = authenticationRequired
            ? NSURLErrorUserAuthenticationRequired
            : error?.code ?? NSURLErrorUnknown

        await persistMetadataState(.failed(message: message, errorCode: errorCode), metadata: metadata)

        logError("Background upload failed for \(metadata.fileName), account: \(metadata.account), job: \(job.localIdentifier), error: \(metadata.errorCode) \(metadata.sessionError)")
    }

    /// Applies Nextcloud response metadata and records the asset as successfully auto-uploaded.
    /// A missing `oc-fileid` converts the result to an upload error and requires manual recovery.
    func processUploadSuccess(metadata: tableMetadata, job: PHAssetResourceUploadJob) async -> Bool {
        let headers = job.responseHeaderFields ?? [:]

        guard let ocId = headers["oc-fileid"], !ocId.isEmpty else {
            // A successful response without Nextcloud metadata is a server-level compatibility error.
            preferences.setBackgroundUploadSuspended(true, account: metadata.account)
            await persistMetadataState(
                .failed(message: "Upload response missing oc-fileid", errorCode: NSURLErrorBadServerResponse),
                metadata: metadata
            )

            logError("Successful job without oc-fileid: \(job.localIdentifier)")

            return false
        }

        // Any confirmed upload breaks the sequence of consecutive asset failures.
        preferences.resetBackgroundUploadConsecutiveFailures(account: metadata.account)

        let etag = nkComm.normalizedETag(
            headers["oc-etag"] ?? headers["etag"]
        )

        let date = headers["date"]?.parsedDate(
            using: "EEE, dd MMM y HH:mm:ss zzz"
        )

        let ownerId = headers["x-nc-ownerid"]
        let permissions = headers["x-nc-permissions"]

        metadata.uploadDate = (date as? NSDate) ?? NSDate()
        metadata.etag = etag ?? ""
        metadata.ocId = ocId

        if let fileId = NCUtility().ocIdToFileId(ocId: ocId) {
            metadata.fileId = fileId
        }

        if let ownerId, !ownerId.isEmpty {
           metadata.ownerId = ownerId
           if let ownerDisplayName = await NCManageDatabase.shared.getOwnerDisplayName(account: metadata.account, ownerId: ownerId) {
               metadata.ownerDisplayName = ownerDisplayName
           }
       }

       if let permissions, !permissions.isEmpty {
           metadata.permissions = permissions
       }

        if metadata.sessionSelector == global.selectorUploadAutoUpload,
           let serverUrlBase = metadata.autoUploadServerUrlBase {
            await database.addAutoUploadTransferAsync(
                account: metadata.account,
                serverUrlBase: serverUrlBase,
                fileName: metadata.fileNameView,
                assetLocalIdentifier: metadata.assetLocalIdentifier,
                date: metadata.creationDate as Date
            )
        }

        await database.replaceMetadataAsync(ocId: metadata.ocIdTransfer, metadata: metadata)

        if metadata.isLivePhoto,
           let capabilities = await database.getCapabilities(account: metadata.account),
           capabilities.isLivePhotoServerAvailable {
            await database.setLivePhotoVideo(
                account: metadata.account,
                serverUrlFileName: metadata.serverUrlFileName,
                fileId: metadata.fileId,
                classFile: metadata.classFile
            )
        }

        logInfo("Completed background upload for \(metadata.fileName), job: \(job.localIdentifier), ocId: \(ocId)")

        return true
    }

    /// Applies a complete background-upload state transition and persists it in Realm.
    /// Keeping related fields together prevents partially configured metadata between processing stages.
    func persistMetadataState(_ state: MetadataState, metadata: tableMetadata) async {
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

        case let .failed(message, errorCode):
            metadata.sessionTaskIdentifier = 0
            metadata.sessionDate = Date()
            metadata.sessionError = message
            metadata.errorCode = errorCode
            metadata.status = global.metadataStatusUploadError

        case .completed:
            metadata.chunk = 0
            metadata.sceneIdentifier = nil
            metadata.session = ""
            metadata.sessionError = ""
            metadata.sessionDate = nil
            metadata.sessionTaskIdentifier = 0
            metadata.status = global.metadataStatusNormal
            metadata.backgroundUploadJobIdentifier = ""
            metadata.backgroundUploadRetryCount = 0
            metadata.backgroundUploadNextRetryDate = nil
        }

        await database.replaceMetadataAsync(ocId: metadata.ocId, metadata: metadata)
    }
}
