// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Photos
import NextcloudKit

@available(iOS 27, *)
final class NCBackgroundUploadExtensionManager {
    static let shared = NCBackgroundUploadExtensionManager()

    private let database = NCManageDatabase.shared
    private let global = NCGlobal.shared

    /// Creates the shared host-app manager used to control the PhotoKit extension state.
    /// Callers access this instance through `shared` so enable and disable decisions stay centralized.
    private init() {}

    /// Checks whether device authorization, app settings, account state, and server version allow delegation.
    /// This method evaluates eligibility only and does not change the PhotoKit extension state.
    func shouldUseExtension() async -> Bool {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else {
            return false
        }

        guard NCPreferences().shouldUseBackgroundUploadExtension else {
            return false
        }

        guard let account = await database.getTableAccountAsync(predicate: NSPredicate(format: "autoUploadStart == true")) else {
            return false
        }

        let capabilities = await NKCapabilities.shared.getCapabilities(for: account.account)

        guard NCBrandOptions.shared.isServerVersion(capabilities, greaterOrEqualTo: .v35) else {
            nkLog(tag: global.logTagBackgroundUpload, message: "Background upload extension unavailable for account \(account.account): server version is lower than 35")
            return false
        }

        return true
    }

    /// Enables the PhotoKit upload extension when eligible and refreshes its network options if active.
    /// Returns the resulting PhotoKit enabled state, or `false` when eligibility or configuration fails.
    func ensureEnabled() async -> Bool {
        guard NCPreferences().shouldUseBackgroundUploadExtension else {
            _ = await disableIfIdle()
            return false
        }

        guard await shouldUseExtension() else {
            return false
        }

        let library = PHPhotoLibrary.shared()
        let options = PHAssetResourceUploadJobOptions()
        // Per-request settings still enforce Wi-Fi-only uploads where configured by the account.
        options.preventsExpensiveNetworkAccess = false

        do {
            if library.uploadJobExtensionEnabled {
                try library.setUploadJobExtensionOptions(options)
            } else {
                try library.enableUploadJobExtension(with: options)
            }

            nkLog(tag: global.logTagBackgroundUpload, message: "Background upload extension enabled: \(library.uploadJobExtensionEnabled)")
            logUploadJobSnapshot()
            return library.uploadJobExtensionEnabled
        } catch {
            nkLog(tag: global.logTagBackgroundUpload, message: "Background upload extension enable failed: \(error)")
            return false
        }
    }

    /// Reads PhotoKit's actionable jobs without changing their state or requesting another upload.
    /// Pending jobs are outstanding work, not evidence that data is currently being transferred.
    private func logUploadJobSnapshot() {
        let actions: [(PHAssetResourceUploadJob.Action, String)] = [
            (.process, "process"),
            (.retry, "retry"),
            (.acknowledge, "acknowledge")
        ]
        var jobIdentifiers = Set<String>()

        for (action, actionName) in actions {
            let jobs = PHAssetResourceUploadJob.fetchJobs(action: action, options: nil)
            nkLog(tag: global.logTagBackgroundUpload, message: "PhotoKit queue snapshot, action: \(actionName), count: \(jobs.count)")

            for index in 0..<jobs.count {
                let job = jobs.object(at: index)
                jobIdentifiers.insert(job.localIdentifier)
                let state: String

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

                let error = job.error.map { $0 as NSError }
                nkLog(
                    tag: global.logTagBackgroundUpload,
                    message: "PhotoKit queue job, action: \(actionName), job: \(job.localIdentifier), " +
                        "state: \(state) (\(job.state.rawValue)), type: \(job.type.rawValue), " +
                        "error domain: \(error?.domain ?? "<nil>"), code: \(error?.code ?? 0)"
                )
            }
        }

        nkLog(tag: global.logTagBackgroundUpload, message: "PhotoKit queue snapshot, unique jobs: \(jobIdentifiers.count)")
    }

    func recordUploadSuccess(metadata: tableMetadata, job: PHAssetResourceUploadJob) async -> Bool {
        let nkComm = NextcloudKit.shared.nkCommonInstance
        let preferences = NCPreferences()
        let headers = job.responseHeaderFields ?? [:]

        guard let ocId = headers["oc-fileid"], !ocId.isEmpty else {
            // A successful response without Nextcloud metadata is a server-level compatibility error.
            preferences.setBackgroundUploadSuspended(true, account: metadata.account)

            logUploadMessage("Successful job without oc-fileid: \(job.localIdentifier)")

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

        do {
            try await NCLocalDatabase.shared.recordPhotoLibraryAssetUpload(
                account: metadata.account,
                assetLocalIdentifier: metadata.assetLocalIdentifier,
                classFile: metadata.classFile,
                isLivePhoto: metadata.isLivePhoto,
                creationDate: metadata.creationDate as Date
            )
        } catch {
            // The server upload remains successful even if its local PhotoKit state cannot be recorded.
            logUploadMessage("Unable to record uploaded photo library asset \(metadata.assetLocalIdentifier): \(error)")
        }

        logUploadMessage("Completed background upload for \(metadata.fileName), job: \(job.localIdentifier), ocId: \(ocId)")

        return true
    }

    private func logUploadMessage(_ message: String) {
        nkLog(tag: global.logTagBackgroundUpload, message: message)
    }

    /// Drains this account's jobs immediately; successful uploads are recorded before acknowledgement.
    func cancelUploads(account: String) async {
        defer { NextcloudKit.flushLogger() }
        let library = PHPhotoLibrary.shared()
        let actions: [PHAssetResourceUploadJob.Action] = [.process, .retry, .acknowledge]
        var handled = Set<String>()
        for action in actions {
            let jobs = PHAssetResourceUploadJob.fetchJobs(action: action, options: nil)
            for index in 0..<jobs.count {
                let job = jobs.object(at: index)
                guard handled.insert(job.localIdentifier).inserted,
                      let metadata = await database.getMetadataAsync(backgroundUploadJobIdentifier: job.localIdentifier),
                      metadata.account == account,
                      metadata.backgroundUploadCancellationRequested else { continue }

                let confirmed = !(job.responseHeaderFields?["oc-fileid"] ?? "").isEmpty
                if confirmed {
                    guard await recordUploadSuccess(metadata: metadata, job: job) else { continue }
                    metadata.status = global.metadataStatusNormal
                    metadata.session = ""
                    metadata.sessionTaskIdentifier = 0
                    metadata.sessionDate = nil
                    metadata.sessionError = ""
                    metadata.errorCode = 0
                    metadata.chunk = 0
                    metadata.sceneIdentifier = nil
                    metadata.backgroundUploadRetryCount = 0
                    metadata.backgroundUploadNextRetryDate = nil
                    await database.replaceMetadataAsync(ocId: metadata.ocIdTransfer, metadata: metadata)
                } else if job.state == .succeeded {
                    // Keep an unverified success recoverable instead of silently losing its result.
                    logUploadMessage("Stop deferred for successful job without oc-fileid: \(job.localIdentifier)")
                    continue
                }

                do {
                    var changed = false
                    try library.performChangesAndWait {
                        guard let request = PHAssetResourceUploadJobChangeRequest(for: job) else { return }
                        if job.state == .registered || job.state == .pending {
                            request.cancel()
                        } else {
                            request.acknowledge()
                        }
                        changed = true
                    }
                    guard changed else { continue }
                    if confirmed {
                        metadata.backgroundUploadJobIdentifier = ""
                        metadata.backgroundUploadCancellationRequested = false
                        await database.replaceMetadataAsync(ocId: metadata.ocIdTransfer, metadata: metadata)
                    } else {
                        await database.deleteMetadataAsync(id: metadata.ocId)
                    }
                    logUploadMessage("Stopped background upload job: \(job.localIdentifier)")
                } catch {
                    logUploadMessage("Unable to stop background upload job \(job.localIdentifier): \(error)")
                }
            }
        }
        _ = await disableIfIdle()
    }

    /// Disables the PhotoKit extension after the feature or auto upload is turned off and no jobs remain.
    /// Active metadata defers disabling so cancellations and terminal results can still be reconciled.
    func disableIfIdle() async -> Bool {
        let featureEnabled = NCPreferences().shouldUseBackgroundUploadExtension
        let account = await database.getTableAccountAsync(predicate: NSPredicate(format: "autoUploadStart == true"))

        guard !featureEnabled || account == nil else {
            return false
        }

        let predicate = NSPredicate(format: "sessionSelector == %@ AND backgroundUploadJobIdentifier != ''", global.selectorUploadAutoUpload)
        let metadatas: [tableMetadata] = await database.getMetadatasAsync(predicate: predicate)

        guard metadatas.isEmpty else {
            nkLog(tag: global.logTagBackgroundUpload, message: "Background upload extension disable deferred: \(metadatas.count) jobs still active")
            return false
        }

        let library = PHPhotoLibrary.shared()

        guard library.uploadJobExtensionEnabled else {
            return true
        }

        do {
            try library.disableUploadJobExtension()
            nkLog(tag: global.logTagBackgroundUpload, message: "Background upload extension disabled")
            return !library.uploadJobExtensionEnabled
        } catch {
            nkLog(tag: global.logTagBackgroundUpload, message: "Background upload extension disable failed: \(error)")
            return false
        }
    }
}
