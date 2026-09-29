// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import ExtensionFoundation
import Photos
import NextcloudKit
import OSLog

@main
final class BackgroundUploadExtension: PHBackgroundResourceUploadJobExtension {
    enum MetadataState: Sendable {
        case uploading(jobIdentifier: String, incrementRetryCount: Bool)
        case pendingRetry
        case manualRetryRequired
        case failed(message: String, errorCode: Int)
        case completed
    }

    let global = NCGlobal.shared
    let database = NCManageDatabase.shared
    let utilityFileSystem = NCUtilityFileSystem()
    let nkComm = NextcloudKit.shared.nkCommonInstance
    let preferences = NCPreferences()
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BackgroundUploadExtension", category: NCGlobal.shared.logTagBackgroundUpload)
    // One initial upload followed by at most two automatic retry attempts.
    let maximumBackgroundUploadAttempts = 3
    // Suspend the account after this many distinct assets fail without an intervening success.
    let maximumConsecutiveBackgroundUploadFailures = 3
    private let isDatabaseAvailable: Bool

    /// Opens the shared Realm database and configures NextcloudKit for extension use.
    /// A schema mismatch is retained as initialization state so job processing can fail safely.
    required init() {
        NextcloudKit.configureLogger(
            logLevel: NCBrandOptions.shared.disable_log ? .disabled : NCPreferences().log,
            logDirectory: NCPreferences.sharedLogDirectory
        )
        NextcloudKit.shared.setup(groupIdentifier: NCBrandOptions.shared.capabilitiesGroup)
        isDatabaseAvailable = NCManageDatabase.shared.openRealm()

        if isDatabaseAvailable {
            logInfo("BackgroundUploadExtension initialized, bundle: \(Bundle.main.bundleIdentifier ?? "<nil>")")
        } else {
            logError("BackgroundUploadExtension initialization stopped because the database schema version does not match")
        }
    }

    /// Reconciles cancellations, retries, completed jobs, and newly discovered assets in that order.
    /// Returns whether PhotoKit should continue processing, stop, or report an unrecoverable failure.
    func processJobs() async -> PHBackgroundResourceUploadProcessingResult {
        defer { NextcloudKit.flushLogger() }

        guard isDatabaseAvailable else {
            return .failure
        }

        logInfo("processJobs begin")

        let account = await setupAccount()
        var processingStage = "cancelRequestedUploadJobs"

        do {
            var madeProgress = false

            // Remove jobs cancelled by the user and clean up PhotoKit jobs no longer backed by metadata.
            if try await cancelRequestedUploadJobs() {
                madeProgress = true
            }

            // Inspect jobs offered for retry; confirmed uploads are acknowledged without uploading again.
            processingStage = "processRetryableUploadJobs"
            if try await processRetryableUploadJobs() {
                madeProgress = true
            }

            // Persist terminal upload results before acknowledging them and releasing PhotoKit capacity.
            processingStage = "acknowledgeUploadJobs"
            if try await acknowledgeUploadJobs() {
                madeProgress = true
            }

            if let account {
                // Link completed Live Photo pairs unless a previous failure suspended the account queue.
                if !preferences.isBackgroundUploadSuspended(account: account.account) {
                    processingStage = "processPendingLivePhotos"
                    if await processPendingLivePhotos(account: account.account) {
                        madeProgress = true
                    }
                }

                if preferences.isBackgroundUploadSuspended(account: account.account) {
                    logInfo("Background upload queue is suspended for account \(account.account)")
                } else {
                    // Register metadata already waiting in Realm before discovering more Photos assets.
                    processingStage = "createUploadJobs(existing metadata)"
                    if try await createUploadJobs(account: account) {
                        madeProgress = true
                    }

                    // Fill only the remaining PhotoKit slots so discovery stays bounded for large libraries.
                    let availableJobs = availableUploadJobSlots()

                    if availableJobs > 0,
                       await createPendingMetadatas(account: account, limit: availableJobs) {
                        madeProgress = true

                        // Convert the metadata just discovered into executable PhotoKit upload jobs.
                        processingStage = "createUploadJobs(new metadata)"
                        if try await createUploadJobs(account: account) {
                            madeProgress = true
                        }
                    }
                }
            }

            // Keep the extension scheduled while this pass progressed or PhotoKit still owns active jobs.
            let hasActiveJobs = hasActiveUploadJobs()
            let result: PHBackgroundResourceUploadProcessingResult = madeProgress || hasActiveJobs ? .processing : .completed

            logInfo("processJobs end, madeProgress: \(madeProgress), hasActiveJobs: \(hasActiveJobs)")
            return result
        } catch let error as NSError where error.domain == PHPhotosErrorDomain && error.code == PHPhotosError.limitExceeded.rawValue {
            logInfo("Job limit reached during \(processingStage)")
            return .processing
        } catch {
            let error = error as NSError
            logError("processJobs error during \(processingStage): " + "domain: \(error.domain), code: \(error.code), " + "description: \(error.localizedDescription), userInfo: \(error.userInfo)")
            return .failure
        }
    }

    /// Receives the PhotoKit notification that the extension process is about to terminate.
    /// It currently records the lifecycle event without interrupting an active processing pass.
    func willTerminate() async {
        logInfo("BackgroundUploadExtension will terminate")
        NextcloudKit.flushLogger()
    }

    /// Writes an informational message to unified logging and the persistent shared log.
    func logInfo(_ message: String) {
        logger.notice("\(message, privacy: .public)")
        nkLog(tag: global.logTagBackgroundUpload, emoji: .info, message: message)
    }

    /// Writes an error to unified logging and to the persistent Nextcloud log.
    /// Use this for failures that require later diagnosis from the host app.
    func logError(_ message: String) {
        logger.error("\(message, privacy: .public)")
        nkLog(tag: global.logTagBackgroundUpload, emoji: .error, message: message)
    }
}
