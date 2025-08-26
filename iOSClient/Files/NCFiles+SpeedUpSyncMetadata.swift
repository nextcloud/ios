// Thread-safe store for tasks
actor ReadTasks {
    private var active: [(serverUrl: String, task: URLSessionTask)] = []

    func isReading(_ serverUrl: String) -> Bool {
        active.contains {
            $0.serverUrl == serverUrl && ($0.task.state == .running || $0.task.state == .suspended)
        }
    }

    func track(serverUrl: String, task: URLSessionTask) {
        active.removeAll {
            $0.serverUrl == serverUrl && $0.task.state == .running
        }
        active.append((serverUrl, task))
    }

    func cancelAll() {
        active.forEach {
            $0.task.cancel()
        }
        active.removeAll()
    }

    func cleanupCompleted() {
        active.removeAll {
            $0.task.state == .completed
        }
    }
}

extension NCFiles {
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

    func stopSyncMetadata() {
        // Cancel and release the reference
        syncMetadatasTask?.cancel()
        syncMetadatasTask = nil
    }

    // Thread-safe store used elsewhere (assumed to exist as a property)
    func speedUpSyncMetadata(metadatas: [tableMetadata]) async {
        // Fast exit if cancellation was requested before starting
        if Task.isCancelled {
            return
        }

        // If a readFile for this serverUrl is already in-flight, do nothing
        if await readTasks.isReading(serverUrl) {
            return
        }

        // Always cancel and clear all tracked URLSessionTask on any exit path
        defer {
            Task {
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
                return
            }

            // Keep the in-memory list tight by removing completed tasks
            await readTasks.cleanupCompleted()
        }
    }
}
