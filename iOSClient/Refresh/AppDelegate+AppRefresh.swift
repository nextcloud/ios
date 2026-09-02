// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import BackgroundTasks

extension AppDelegate {
    // Schedules the next app refresh task.
    //
    // The scheduler may delay execution depending on device conditions,
    // battery state, usage patterns, and system policy.
    func scheduleAppRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: global.refreshTask)

        let request = BGAppRefreshTaskRequest(identifier: global.refreshTask)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            nkLog(tag: self.global.logTagTask, emoji: .error, message: "Refresh task failed to submit request: \(error)")
        }
    }

    // Handles the BGAppRefreshTask lifecycle for background synchronization.
    //
    // The function:
    // - validates background Realm availability,
    // - schedules the next refresh task,
    // - starts the background synchronization flow,
    // - cooperates with BGTask expiration by cancelling the Swift task,
    // - reports success only if the work completes without cancellation.
    //
    // - Parameter task: The system-provided background refresh task.
    func handleAppRefresh(_ task: BGAppRefreshTask) {
        nkLog(tag: self.global.logTagTask, emoji: .start, message: "Start refresh task")

        guard NCManageDatabase.shared.openRealmBackground() else {
            nkLog(tag: self.global.logTagTask, emoji: .error, message: "Failed to open Realm in background")
            task.setTaskCompleted(success: false)
            return
        }

        // Schedule next refresh.
        scheduleAppRefresh()

        let refreshTask = Task { () -> Bool in
            await NCAutoUpload.shared.autoUploadBackgroundSync()
            return !Task.isCancelled
        }

        Task {
            let success = await refreshTask.value
            task.setTaskCompleted(success: success)
        }

        task.expirationHandler = {
            nkLog(tag: self.global.logTagTask, emoji: .stop, message: "Refresh task expired")
            refreshTask.cancel()
        }
    }
}
