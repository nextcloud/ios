// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import BackgroundTasks

extension AppDelegate {

    /// Schedules the next background processing task.
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

    /// Handles background maintenance, media backfill, placeholder hydration, and preview generation.
    func handleProcessingTask(_ task: BGProcessingTask) {
        nkLog(tag: self.global.logTagTask, emoji: .start, message: "Start processing task")

        guard NCManageDatabase.shared.openRealmBackground() else {
            nkLog(tag: self.global.logTagTask, emoji: .error, message: "Failed to open Realm in background")
            task.setTaskCompleted(success: false)
            return
        }

        // Schedule the next processing task.
        scheduleAppProcessing()

        let processingTask = Task { () -> Bool in
            let accounts = await NCManageDatabase.shared.getAllTableAccountAsync()
            let activeAccount = accounts.first(where: { $0.active })
            let sortedAccounts = accounts.sorted { $0.active && !$1.active }
            guard let activeAccount else {
                return true
            }

            // Auto upload.
            await NCAutoUpload.shared.autoUploadBackgroundSync()

            guard !Task.isCancelled else {
                return false
            }

            // Weekly cleanup.
            if NCPreferences().cleaningWeek() {
                nkLog(tag: self.global.logTagBgSync, emoji: .start, message: "Start cleaning week")

                for account in accounts {
                    await NCManageDatabase.shared.cleanTablesOcIds(
                        account: account.account,
                        userId: account.userId,
                        urlBase: account.urlBase
                    )

                    guard !Task.isCancelled else {
                        return false
                    }
                }

                await NCUtilityFileSystem().cleanUpAsync()

                guard !Task.isCancelled else {
                    return false
                }

                NCPreferences().setDoneCleaningWeek()

                nkLog(tag: self.global.logTagBgSync, emoji: .stop, message: "Stop cleaning week")
            }

            guard !Task.isCancelled else {
                return false
            }

            // Media metadata backfill for the active account.
            nkLog(tag: self.global.logTagMediaBackfill,
                  emoji: .start,
                  message: "Start media metadata backfill for account \(activeAccount.account)")

            let backfillStatus = await NCMediaMetadataBackfillProcessor().runBackfill(
                account: activeAccount,
                limit: 250
            ) { offset, inserted, updated in
                nkLog(tag: self.global.logTagMediaBackfill,
                      emoji: .info,
                      message: "Media metadata backfill progress: offset \(offset) - inserted \(inserted) - updated \(updated) - account: \(activeAccount.account)")
            }

            nkLog(tag: self.global.logTagMediaBackfill,
                  emoji: backfillStatus.isSuccessful ? .stop : .error,
                  message: backfillStatus.logMessage)

            guard !Task.isCancelled else {
                return false
            }

            for account in sortedAccounts {
                // Placeholder hydration and preview backfill for all accounts.
                nkLog(tag: self.global.logTagMediaPlaceholder,
                      emoji: .start,
                      message: "Start media metadata placeholder hydration for account \(account.account)")

                let hydrationStatus = await NCMediaPlaceholderHydrationProcessor().runPlaceholderHydration(
                    account: account,
                    limit: 100
                ) { succeeded in
                    nkLog(tag: self.global.logTagMediaPlaceholder,
                          emoji: .info,
                          message: "Media metadata placeholder hydration progress: succeeded \(succeeded) account \(account.account)")
                }

                nkLog(tag: self.global.logTagMediaPlaceholder,
                      emoji: hydrationStatus.isSuccessful ? .stop : .error,
                      message: hydrationStatus.logMessage)

                guard !Task.isCancelled else {
                    return false
                }

                // Media preview backfill.
                nkLog(tag: self.global.logTagMediaPreview,
                      emoji: .start,
                      message: "Start media preview backfill for account \(account.account)")

                let previewStatus = await NCMediaPreviewBackfillProcessor().runPreviewBackfill(
                    account: account,
                    limit: 100
                ) { succeeded, failed in
                    nkLog(tag: self.global.logTagMediaPreview,
                          emoji: .info,
                          message: "Media preview backfill progress: succeeded \(succeeded) - failed \(failed) account \(account.account)")
                }

                nkLog(tag: self.global.logTagMediaPreview,
                      emoji: previewStatus.isSuccessful ? .stop : .error,
                      message: previewStatus.logMessage)

                guard !Task.isCancelled else {
                    return false
                }
            }

            return true
        }

        Task {
            let success = await processingTask.value

            nkLog(tag: self.global.logTagTask,
                  emoji: success ? .stop : .error,
                  message: "Stop processing task")

            task.setTaskCompleted(success: success)
        }

        task.expirationHandler = {
            nkLog(tag: self.global.logTagTask, emoji: .stop, message: "Processing task expired")
            processingTask.cancel()
        }
    }
}
