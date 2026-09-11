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
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BackgroundUploadExtension", category: NCGlobal.shared.logTagBackgroundUpload)

    required init() {
        database.openRealm()

        NextcloudKit.configureLogger(logLevel: NCBrandOptions.shared.disable_log ? .disabled : NCPreferences().log)
        NextcloudKit.shared.setup(groupIdentifier: NCBrandOptions.shared.capabilitiesGroup)

        logInfo("BackgroundUploadExtension initialized, bundle: \(Bundle.main.bundleIdentifier ?? "<nil>")")
    }

    func processJobs() async -> PHBackgroundResourceUploadProcessingResult {
        logDebug("processJobs begin")

        let account = await setupAccount()

        do {
            var madeProgress = false

            if try await cancelRequestedUploadJobs() {
                madeProgress = true
            }

            if try await retryUploadJobs() {
                madeProgress = true
            }

            if try await acknowledgeUploadJobs() {
                madeProgress = true
            }

            if let account {
                if try await createUploadJobs(account: account) {
                    madeProgress = true
                }

                let availableJobs = availableUploadJobSlots()

                if availableJobs > 0,
                   await createPendingMetadatas(account: account, limit: availableJobs) {
                    madeProgress = true

                    if try await createUploadJobs(account: account) {
                        madeProgress = true
                    }
                }
            }

            let hasActiveJobs = hasActiveUploadJobs()
            let result: PHBackgroundResourceUploadProcessingResult = madeProgress || hasActiveJobs ? .processing : .completed

            logDebug("processJobs end, madeProgress: \(madeProgress), hasActiveJobs: \(hasActiveJobs)")
            return result
        } catch let error as NSError where error.domain == PHPhotosErrorDomain && error.code == PHPhotosError.limitExceeded.rawValue {
            logInfo("Job limit reached")
            return .processing
        } catch {
            logError("processJobs error: \(error)")
            return .failure
        }
    }

    func willTerminate() async {
        logDebug("BackgroundUploadExtension will terminate")
    }

    func logDebug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    func logInfo(_ message: String, persist: Bool = false) {
        logger.info("\(message, privacy: .public)")

        if persist {
            nkLog(tag: global.logTagBackgroundUpload, emoji: .info, message: message)
        }
    }

    func logError(_ message: String) {
        logger.error("\(message, privacy: .public)")
        nkLog(tag: global.logTagBackgroundUpload, emoji: .error, message: message)
    }
}
