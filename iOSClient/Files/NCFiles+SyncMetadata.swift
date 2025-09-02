// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

extension NCFiles {
    /// Starts a detached task that accelerates metadata synchronization for the provided items.
    ///
    /// If a previous sync is still running, this method exits without starting a new one.
    /// The spawned task clears its reference upon completion.
    /// - Parameter metadatas: The list of `tableMetadata` to evaluate and possibly sync.
    func startSyncMetadata(metadatas: [tableMetadata]) {
        // Filter: not e2ee & only directory
        let metadatas = metadatas.filter { $0.directory && !$0.e2eEncrypted }
        guard !metadatas.isEmpty else {
            return
        }

        // If a sync task is already running, do not start a new one
        if let task = syncMetadatasTask,
           !task.isCancelled {
            nkLog(tag: global.logSpeedUpSyncMetadata, emoji: .info, message: "Exit: Another sync is already running. Skipping this one.", consoleOnly: true)
            return
        }

        // Create a detached task and keep reference for manual cancellation
        syncMetadatasTask = Task.detached { [weak self] in
            guard let self else { return }
            await self.networkSyncMetadata(metadatas: metadatas)
            // Once finished, clear the reference
            await MainActor.run {
                self.syncMetadatasTask = nil
            }
        }
    }

    /// Cancels the running sync task (if any) and releases the reference.
    ///
    /// Use this when the page/screen is about to disappear or the user navigates away.
    func stopSyncMetadata() {
        if let task = syncMetadatasTask {
            if task.isCancelled {
                nkLog(tag: global.logSpeedUpSyncMetadata, emoji: .stop, message: "Sync Metadata for \(self.serverUrl) was already cancelled.", consoleOnly: true)
            } else {
                nkLog(tag: global.logSpeedUpSyncMetadata, emoji: .stop, message: "Stopping active Sync Metadata for \(self.serverUrl).", consoleOnly: true)
            }
        }

        syncMetadatasTask?.cancel()
        syncMetadatasTask = nil
    }

    /// Accelerates metadata synchronization by:
    /// 1) Reading the top item (`readFileAsync`) to validate state and skip E2EE,
    /// 2) Iterating directories and triggering `readFolderAsync` where ETag changed,
    /// 3) Tracking all spawned requests for centralized cancellation/cleanup.
    ///
    /// The method cooperates with task cancellation (`Task.isCancelled`) and guarantees that
    /// all tracked `URLSessionTask` are cancelled on any exit path via `defer`.
    ///
    /// - Parameter metadatas: The list of `tableMetadata` entries to scan and refresh.
    func networkSyncMetadata(metadatas: [tableMetadata]) async {
        // Order by date (descending)
        let metadatas = metadatas.sorted {
            ($0.date as Date) > ($1.date as Date)
        }
        // Fast exit if cancellation was requested before starting
        if Task.isCancelled {
            return
        }
        let identifier = self.serverUrl + "_syncMetadata"
        nkLog(tag: global.logSpeedUpSyncMetadata, emoji: .start, message: "Start Sync Metadata for \(self.serverUrl)")

        // Always cancel and clear all tracked URLSessionTask on any exit path
        defer {
            Task {
                await networking.networkingTasks.cancel(identifier: identifier)
            }
        }

        // If a readFile for this serverUrl is already in-flight, do nothing
        if await networking.networkingTasks.isReading(identifier: identifier) {
            nkLog(tag: global.logSpeedUpSyncMetadata, emoji: .debug, message: "ReadFile for this \(self.serverUrl) is already in-flight.", consoleOnly: true)
            return
        }

        // Skip error or e2ee
        let resultsReadFile = await NCNetworking.shared.readFileAsync(serverUrlFileName: serverUrl, account: session.account) { task in
            Task {
                await self.networking.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        // Validate outcome and skip E2EE items
        guard resultsReadFile.error == .success,
              let metadata = resultsReadFile.metadata,
              !metadata.e2eEncrypted else {
            nkLog(tag: global.logSpeedUpSyncMetadata, emoji: .info, message: "Exit: result error \(resultsReadFile.error.errorDescription) or e2ee directory \(resultsReadFile.metadata?.e2eEncrypted ?? false). Skipping this one.")
            return
        }

        // Iterate directories and fetch only when ETag changed
        for metadata in metadatas {
            if Task.isCancelled {
                break
            }

            let directory = await database.getTableDirectoryAsync(ocId: metadata.ocId)
            guard directory?.etag != metadata.etag else {
                continue
            }
            let serverUrl = metadata.serverUrlFileName

            let resultsReadFolder = await NCNetworking.shared.readFolderAsync(serverUrl: serverUrl, account: session.account) { task in
                Task {
                    await self.networking.networkingTasks.track(identifier: identifier, task: task)
                }
            }

            // If this folder failed, skip it but keep processing others
            if resultsReadFolder.error == .success {
                nkLog(tag: global.logSpeedUpSyncMetadata, emoji: .network, message: "Read correctly: \(serverUrl)", consoleOnly: true)
            } else {
                nkLog(tag: global.logSpeedUpSyncMetadata, emoji: .error, message: "Read failed for \(serverUrl) with error: \(resultsReadFolder.error.errorDescription)")
                return
            }

            // Keep the in-memory list tight by removing completed tasks
            await networking.networkingTasks.cleanup()
        }
    }
}
