// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import BackgroundTasks

extension AppDelegate {
    // Schedules the next processing task.
    //
    // The scheduler may delay execution depending on device conditions,
    // battery state, thermal conditions, and system policy.
    func scheduleAppProcessing() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: global.processingTask)

        let request = BGProcessingTaskRequest(identifier: global.processingTask)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            nkLog(tag: self.global.logTagTask, emoji: .error, message: "Processing task failed to submit request: \(error)")
        }
    }

    // Handles the BGProcessingTask lifecycle for weekly cleanup or background synchronization.
    //
    // The function:
    // - validates background Realm availability,
    // - schedules the next processing task,
    // - executes either weekly cleanup or background sync,
    // - cooperates with BGTask expiration by cancelling the Swift task,
    // - reports success only if the work completes without cancellation.
    //
    // - Parameter task: The system-provided background processing task.
    func handleProcessingTask(_ task: BGProcessingTask) {
        nkLog(tag: self.global.logTagTask, emoji: .start, message: "Start processing task")

        guard NCManageDatabase.shared.openRealmBackground() else {
            nkLog(tag: self.global.logTagTask, emoji: .error, message: "Failed to open Realm in background")
            task.setTaskCompleted(success: false)
            return
        }

        // Schedule next processing task.
        scheduleAppProcessing()

        let processingTask = Task { () -> Bool in
            // If possible, cleaning every week.
            if NCPreferences().cleaningWeek() {
                nkLog(tag: self.global.logTagBgSync, emoji: .start, message: "Start cleaning week")

                let tblAccounts = await NCManageDatabase.shared.getAllTableAccountAsync()
                for tblAccount in tblAccounts {
                    guard !Task.isCancelled else {
                        return false
                    }

                    await NCManageDatabase.shared.cleanTablesOcIds(
                        account: tblAccount.account,
                        userId: tblAccount.userId,
                        urlBase: tblAccount.urlBase
                    )
                }

                guard !Task.isCancelled else {
                    return false
                }

                await NCUtilityFileSystem().cleanUpAsync()

                guard !Task.isCancelled else {
                    return false
                }

                NCPreferences().setDoneCleaningWeek()
                nkLog(tag: self.global.logTagBgSync, emoji: .stop, message: "Stop cleaning week")
                return true
            } else {
                await NCAutoUpload.shared.autoUploadBackgroundSync()

                guard !Task.isCancelled else {
                    return false
                }

                await runMediaMetadataBackfill()

                return !Task.isCancelled
            }
        }

        Task {
            let success = await processingTask.value
            task.setTaskCompleted(success: success)
        }

        task.expirationHandler = {
            nkLog(tag: self.global.logTagTask, emoji: .stop, message: "Processing task expired")
            processingTask.cancel()
        }
    }

    func runMediaMetadataBackfill() async {
        let database = NCManageDatabase.shared
        let accounts = await database.getAllTableAccountAsync()
        let count = 500

        for account in accounts {
            guard !Task.isCancelled else {
                return
            }
            let state = await database.getMediaMetadataBackfillAsync(account: account.account)
            var offset = state?.offset ?? 0
            var token: String?
            let backfill = NCMediaMetadataBackfill(account: account.account)

            nkLog(tag: self.global.logTagMediaBackfill, emoji: .start, message: "Start media metadata backfill")

            while !Task.isCancelled {
                let result = await backfill.run(mediaPath: account.mediaPath,
                                                account: account.account,
                                                offset: offset,
                                                token: token,
                                                count: count)

                guard !Task.isCancelled else {
                    return
                }

                guard let files = result.files else {
                    nkLog(tag: self.global.logTagMediaBackfill,
                          emoji: .error,
                          message: "Media metadata backfill failed \(result.error?.errorCode ?? 0) \(result.error?.errorDescription ?? "")")
                    break
                }

                guard !files.isEmpty else {
                    await database.completeMediaMetadataBackfillAsync(account: account.account)
                    break
                }

                let ocIds = files.compactMap(\.ocId)
                let metadatas = await NCManageDatabase.shared.getMetadatasFromOcIdsAsync(ocIds)
                let resultPlaceholders = await NCManageDatabase.shared.syncPlaceholderMetadatasAsync(files: files,
                                                                                                     metadatas: metadatas)

                nkLog(tag: self.global.logTagMediaBackfill, emoji: .info, message: "Media metadata backfill: offset \(offset) - inserted \(resultPlaceholders.inserted) - updated \(resultPlaceholders.updated)")

                guard !Task.isCancelled else {
                    return
                }

                offset += files.count
                await database.updateMediaMetadataBackfillAsync(account: account.account, offset: offset)

                guard files.count == count else {
                    await database.completeMediaMetadataBackfillAsync(account: account.account)
                    break
                }

                token = result.token
            }
        }
    }
}
