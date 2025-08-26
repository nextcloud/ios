// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

// Thread-safe store for tasks
actor ReadTasks {
    private var active: [(serverUrl: String, task: URLSessionTask)] = []

    /// Returns whether there is an in-flight task for the given URL.
    ///
    /// A task is considered in-flight if its `state` is `.running` or `.suspended`.
    /// - Parameter serverUrl: The server URL to check.
    /// - Returns: `true` if a matching in-flight task exists; otherwise `false`.
    func isReading(_ serverUrl: String) -> Bool {
        active.contains {
            $0.serverUrl == serverUrl && ($0.task.state == .running || $0.task.state == .suspended)
        }
    }

    /// Tracks a newly created `URLSessionTask` for the given URL.
    ///
    /// If a running entry for the same URL exists, it is removed before appending the new one.
    /// - Parameters:
    ///   - serverUrl: The server URL associated with the task.
    ///   - task: The `URLSessionTask` to track.
    func track(serverUrl: String, task: URLSessionTask) {
        active.removeAll {
            $0.serverUrl == serverUrl && $0.task.state == .running
        }
        active.append((serverUrl, task))
    }

    /// Cancels all tracked `URLSessionTask` and clears the registry.
    ///
    /// Call this when leaving the page/screen or when the operation must be forcefully stopped.
    func cancelAll() {
        active.forEach {
            $0.task.cancel()
        }
        active.removeAll()
    }

    /// Removes tasks that have completed from the registry.
    ///
    /// Useful to keep the in-memory list compact during long-running operations.
    func cleanupCompleted() {
        active.removeAll {
            $0.task.state == .completed
        }
    }
}

extension NCFiles {
    /// Starts a detached task that accelerates metadata synchronization for the provided items.
    ///
    /// If a previous sync is still running, this method exits without starting a new one.
    /// The spawned task clears its reference upon completion.
    /// - Parameter metadatas: The list of `tableMetadata` to evaluate and possibly sync.
    func startSyncMetadata(metadatas: [tableMetadata]) {
        // If a sync task is already running, do not start a new one
        if let task = syncMetadatasTask,
           !task.isCancelled {
            return
        }

        // Create a detached task and keep reference for manual cancellation
        syncMetadatasTask = Task.detached { [weak self] in
            guard let self else { return }
            await self.speedUpSyncMetadata(metadatas: metadatas)
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
        nkLog(tag: global.logSpeedUpSyncMetadata, emoji: .stop, message: "Forced stop Sync Metadata for \(self.serverUrl)")

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
    func speedUpSyncMetadata(metadatas: [tableMetadata]) async {
        nkLog(tag: global.logSpeedUpSyncMetadata, emoji: .start, message: "Start Sync Metadata for \(self.serverUrl)")

        // Fast exit if cancellation was requested before starting
        if Task.isCancelled {
            return
        }

        // If a readFile for this serverUrl is already in-flight, do nothing
        if await readTasks.isReading(serverUrl) {
            nkLog(tag: global.logSpeedUpSyncMetadata, emoji: .debug, message: "ReadFile for this \(self.serverUrl) is already in-flight.")
            return
        }

        // Always cancel and clear all tracked URLSessionTask on any exit path
        defer {
            Task {
                nkLog(tag: global.logSpeedUpSyncMetadata, emoji: .stop, message: "Stop Sync Metadata for \(self.serverUrl)")
                await readTasks.cancelAll()
            }
        }

        // Skip error or e2ee
        let resultsReadFile = await NCNetworking.shared.readFileAsync(serverUrlFileName: serverUrl, account: session.account) { task in
            Task {
                await self.readTasks.track(serverUrl: self.serverUrl, task: task)
            }
        }

        // Validate outcome and skip E2EE items
        guard resultsReadFile.error == .success,
              let metadata = resultsReadFile.metadata,
              !metadata.e2eEncrypted else {
            return
        }

        // Iterate directories and fetch only when ETag changed
        for metadata in metadatas {
            if Task.isCancelled {
                break
            }

            // Directory only
            if !metadata.directory {
                continue
            }

            let directory = database.getTableDirectory(ocId: metadata.ocId)
            guard directory?.etag != metadata.etag else {
                continue
            }
            let serverUrl = metadata.serverUrlFileName

            let resultsReadFolder = await NCNetworking.shared.readFolderAsync(serverUrl: serverUrl, account: session.account) { task in
                Task {
                    await self.readTasks.track(serverUrl: serverUrl, task: task)
                }
            }

            // If this folder failed, skip it but keep processing others
            if resultsReadFolder.error != .success {
                nkLog(tag: global.logSpeedUpSyncMetadata, emoji: .error, message: "Read folder failed for \(serverUrl) with error: \(resultsReadFolder.error.errorDescription)")
                return
            }

            // Keep the in-memory list tight by removing completed tasks
            await readTasks.cleanupCompleted()
        }
    }
}
