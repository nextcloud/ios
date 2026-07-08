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

    /// Handles the lifecycle of the app processing background task.
    ///
    /// The task opens the background database, schedules its next execution, and then runs either
    /// the weekly maintenance cleanup or the background synchronization pipeline. The sync pipeline
    /// performs auto-upload, media metadata backfill, and placeholder hydration for the active account.
    ///
    /// The underlying Swift task is cancelled when iOS expires the background execution time, and the
    /// processing task is marked successful only when all scheduled work finishes without cancellation.
    ///
    /// - Parameter task: The system-provided background processing task.
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

                guard let account = await NCManageDatabase.shared.getActiveTableAccountAsync() else {
                    return false
                }

                let limit = 500
                let mediaProcessor = NCMediaMetadataBackgroundProcessor()

                nkLog(tag: self.global.logTagMediaBackfill,
                      emoji: .start,
                      message: "Start media metadata backfill")

                let backfillStatus = await mediaProcessor.runBackfill(
                    account: account,
                    limit: limit
                ) { offset, inserted, updated in
                    nkLog(tag: self.global.logTagMediaBackfill,
                          emoji: .info,
                          message: "Media metadata backfill progress: offset \(offset) - inserted \(inserted) - updated \(updated)")
                }

                nkLog(tag: self.global.logTagMediaBackfill,
                      emoji: backfillStatus.isSuccessful ? .success : .error,
                      message: backfillStatus.logMessage)

                guard backfillStatus.isSuccessful,
                      !Task.isCancelled else {
                    return false
                }

                nkLog(tag: self.global.logTagMediaPlaceholder,
                      emoji: .start,
                      message: "Start media metadata placeholder hydration")

                let hydrationStatus = await mediaProcessor.runPlaceholderHydration(
                    account: account,
                    limit: limit
                ) { succeeded in
                    nkLog(tag: self.global.logTagMediaPlaceholder,
                          emoji: .info,
                          message: "Media metadata placeholder hydration progress: succeeded \(succeeded) - limit \(limit)")
                }

                nkLog(tag: self.global.logTagMediaPlaceholder,
                      emoji: hydrationStatus.isSuccessful ? .success : .error,
                      message: hydrationStatus.logMessage)

                guard hydrationStatus.isSuccessful,
                      !Task.isCancelled else {
                    return false
                }

                return true
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
}
