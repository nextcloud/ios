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

                await runMediaMetadataBackfill(account: account) { offset, inserted, updated in
                    nkLog(tag: self.global.logTagMediaBackfill, emoji: .info, message: "Media metadata backfill: offset \(offset) - inserted \(inserted) - updated \(updated)")

                }

                guard !Task.isCancelled else {
                    return false
                }

                let limit = 500
                await runMediaMetadataPlaceholderHydration(account: account, limit: limit) { processed in
                    nkLog(tag: self.global.logTagMediaPlaceholder, emoji: .info, message: "Media metadata placeholder hydration: processed \(processed) - limit \(limit)")
                }

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

    /// Progressively scans the media archive and creates missing metadata placeholders.
    func runMediaMetadataBackfill(account: tableAccount,
                                  update: @escaping (_ offset: Int, _ inserted: Int, _ updated: Int) async -> Void) async {
        let database = NCManageDatabase.shared
        let count = 500
        let state = await database.getMediaMetadataBackfillAsync(account: account.account)
        // Stops the backfill when the media archive has already been fully processed.
        guard state?.lastCompletedCycleDate == nil else {
            return
        }
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
            let resultPlaceholders = await NCManageDatabase.shared.syncPlaceholderMetadatasAsync(
                files: files,
                metadatas: metadatas
            )
            offset += files.count

            await update(offset, resultPlaceholders.inserted, resultPlaceholders.updated)

            guard !Task.isCancelled else {
                return
            }

            await database.updateMediaMetadataBackfillAsync(account: account.account, offset: offset)
            guard files.count == count else {
                await database.completeMediaMetadataBackfillAsync(account: account.account)
                break
            }

            token = result.token
        }
    }

    /// Completes media metadata placeholders by retrieving and storing their full properties.
    func runMediaMetadataPlaceholderHydration(account: tableAccount,
                                              limit: Int,
                                              update: @escaping (_ processed: Int) async -> Void) async {
        let database = NCManageDatabase.shared
        let maximumConcurrentRequests = min(8, NCBrandOptions.shared.httpMaximumConnectionsPerHost)
        var processed = 0

        guard let metadatas = await database.getMetadatasAsync(
            predicate: NSPredicate(
                format: "account == %@ AND placeholder == true",
                account.account
            ),
            sortedByKeyPath: "date",
            ascending: false,
            limit: limit
        ), !metadatas.isEmpty else {
            return
        }

        func hydrate(_ metadata: tableMetadata) async -> Bool {
            guard !Task.isCancelled else {
                return false
            }
            let result = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: metadata.serverUrlFileName,
                                                                         depth: "0",
                                                                         account: metadata.account)
            guard !Task.isCancelled,
                  result.error == .success,
                  let file = result.files?.first else {
                return false
            }

            let metadata = await NCManageDatabaseCreateMetadata().convertFileToMetadataAsync(file)
            await database.addMetadataAsync(metadata)

            return true
        }

        nkLog(tag: self.global.logTagMediaPlaceholder, emoji: .start, message: "Start media metadata placeholder hydration")

        await withTaskGroup(of: Bool.self) { group in
            var iterator = metadatas.makeIterator()

            for _ in 0..<maximumConcurrentRequests {
                guard let metadata = iterator.next() else {
                    break
                }

                group.addTask {
                    await hydrate(metadata)
                }
            }

            while let completed = await group.next() {
                if completed {
                    processed += 1
                }

                guard !Task.isCancelled,
                      let metadata = iterator.next() else {
                    continue
                }

                group.addTask {
                    await hydrate(metadata)
                }
            }
        }

        guard !Task.isCancelled else {
            return
        }

        await update(processed)
    }
}
