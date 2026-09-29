// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import ExtensionFoundation
import Photos
import NextcloudKit
import OSLog

@main
final class BackgroundUploadExtension: PHBackgroundResourceUploadJobExtension {
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

            if try await cancelRequestedUploadJobs() {
                madeProgress = true
            }

            processingStage = "retryUploadJobs"
            if try await retryUploadJobs() {
                madeProgress = true
            }

            processingStage = "acknowledgeUploadJobs"
            if try await acknowledgeUploadJobs() {
                madeProgress = true
            }

            if let account {
                if preferences.isBackgroundUploadSuspended(account: account.account) {
                    logInfo("Background upload queue is suspended for account \(account.account)")
                } else {
                    processingStage = "createUploadJobs(existing metadata)"
                    if try await createUploadJobs(account: account) {
                        madeProgress = true
                    }

                    let availableJobs = availableUploadJobSlots()

                    if availableJobs > 0,
                       await createPendingMetadatas(account: account, limit: availableJobs) {
                        madeProgress = true

                        processingStage = "createUploadJobs(new metadata)"
                        if try await createUploadJobs(account: account) {
                            madeProgress = true
                        }
                    }
                }
            }

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
