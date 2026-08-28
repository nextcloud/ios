// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import ExtensionFoundation
import Photos
import NextcloudKit

@main
final class BackgroundUploadExtension: PHBackgroundResourceUploadJobExtension {
    let global = NCGlobal.shared
    let database = NCManageDatabase.shared
    let utilityFileSystem = NCUtilityFileSystem()
    let nkComm = NextcloudKit.shared.nkCommonInstance

    required init() {
        database.openRealm()

        NextcloudKit.configureLogger(logLevel: NCBrandOptions.shared.disable_log ? .disabled : NCPreferences().log)
        NextcloudKit.shared.setup(groupIdentifier: NCBrandOptions.shared.capabilitiesGroup)

        nkLog(tag: global.logTagBackgroundUpload, message:
            """
            BackgroundUploadExtension initialized, \
            bundle: \(Bundle.main.bundleIdentifier ?? "<nil>")
            """
        )
    }

    func processJobs() async -> PHBackgroundResourceUploadProcessingResult {
        nkLog(tag: global.logTagBackgroundUpload, message: "processJobs begin")

        let accounts = await setupAccounts()

        do {
            var madeProgress = false

            if try await retryUploadJobs() {
                madeProgress = true
            }

            if try await acknowledgeUploadJobs() {
                madeProgress = true
            }

            if await createPendingMetadatas(accounts: accounts) {
                madeProgress = true
            }

            if try await createUploadJobs() {
                madeProgress = true
            }

            let result: PHBackgroundResourceUploadProcessingResult = madeProgress ? .processing : .completed

            nkLog(tag: global.logTagBackgroundUpload, message: "processJobs end, madeProgress: \(madeProgress)")

            return result

        } catch let error as NSError
            where error.domain == PHPhotosErrorDomain && error.code == PHPhotosError.limitExceeded.rawValue {

            nkLog(tag: global.logTagBackgroundUpload, message: "Job limit reached")

            return .processing

        } catch {
            nkLog(tag: global.logTagBackgroundUpload, message: "processJobs error: \(error)")

            return .failure
        }
    }

    func willTerminate() async {

    }
}
