// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

// MARK: - Transfer Store (batched persistence)

struct TransferItem: Codable {
    var completed: Bool?
    var date: Date?
    var etag: String?
    var fileName: String?
    var ocId: String?
    var ocIdTransfer: String?
    var progress: Double?
    var selector: String?
    var serverUrl: String?
    var session: String?
    var status: Int?
    var size: Int64?
    var taskIdentifier: Int?
}

final class NCTransferStore {
    static let shared = NCTransferStore()

    // Shared state
    private var transferItemsCache: [TransferItem] = []
    private let transferStoreIO = DispatchQueue(label: "TransferStore.IO", qos: .utility)
    private let debounceQueue = DispatchQueue(label: "TransferStore.Debounce", qos: .utility)
    private let encoderTransferItem = JSONEncoder()
    private let decoderTransferItem = JSONDecoder()
    private(set) var transferStoreURL: URL?

    // Batching controls
    private var changeCounter: Int = 0
    private var lastPersist: TimeInterval = 0
    private let batchThreshold: Int = NCBrandOptions.shared.numMaximumProcess / 2
    private let maxLatencySec: TimeInterval = 5     // <- or every 5s at most
    private var debounceTimer: DispatchSourceTimer?

    init() {
        self.encoderTransferItem.dateEncodingStrategy = .iso8601
        self.decoderTransferItem.dateDecodingStrategy = .iso8601

        guard let groupDirectory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup) else {
            return
        }
        let backupDirectory = groupDirectory.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud)
        self.transferStoreURL = backupDirectory.appendingPathComponent(fileTransferStore)

        self.transferStoreIO.sync {
            if let url = self.transferStoreURL,
                let data = try? Data(contentsOf: url),
                !data.isEmpty,
                let items = try? self.decoderTransferItem.decode([TransferItem].self, from: data) {
                self.transferItemsCache = items
            } else {
                self.transferItemsCache = []
            }
        }

        self.lastPersist = CFAbsoluteTimeGetCurrent()

        setupLifecycleFlush()
        startDebounceTimer()
    }

    deinit {
        stopDebounceTimer()
    }

    private func setupLifecycleFlush() {
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { _ in
            self.stopDebounceTimer()
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
            self.forceFlush()
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }

            // Force a synchronous reload before anything else
            self.reloadFromDisk()

            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self.startDebounceTimer()
            }
        }
    }

    // MARK: Public API

    /// Adds or merges an item, then schedules a batched commit.
    func addItem(_ item: TransferItem) {
        transferStoreIO.sync {
            // Upsert by (serverUrl + fileName + taskIdentifier)
            if let idx = transferItemsCache.firstIndex(where: {
                $0.serverUrl == item.serverUrl &&
                $0.fileName == item.fileName &&
                $0.taskIdentifier == item.taskIdentifier
            }) {
                let merged = mergeItem(existing: transferItemsCache[idx], with: item)
                transferItemsCache[idx] = merged
            } else {
                transferItemsCache.append(item)
            }

            changeCounter &+= 1
        }

        maybeCommit()
    }

    /// Updates only the `progress` field of an existing item, then schedules a batched commit.
    /// If no matching item is found, nothing happens.
    func transferProgress(serverUrl: String, fileName: String, taskIdentifier: Int, progress: Double) {
        transferStoreIO.sync {
            if let idx = transferItemsCache.firstIndex(where: {
                $0.serverUrl == serverUrl &&
                $0.fileName == fileName &&
                $0.taskIdentifier == taskIdentifier
            }) {
                transferItemsCache[idx].progress = progress
            }
        }
    }

    /// Removes the first match by (serverUrl + fileName); batched commit.
    func removeItem(serverUrl: String, fileName: String, taskIdentifier: Int) {
        transferStoreIO.sync {
            if let idx = transferItemsCache.firstIndex(where: {
                $0.serverUrl == serverUrl &&
                $0.fileName == fileName &&
                $0.taskIdentifier == taskIdentifier
            }) {
                transferItemsCache.remove(at: idx)
            }
        }
    }

    /// Removes the first match by (ocIdTransfer); batched commit.
    func removeItem(ocIdTransfer: String) {
        transferStoreIO.sync {
            if let idx = transferItemsCache.firstIndex(where: {
                $0.ocIdTransfer == ocIdTransfer
            }) {
                transferItemsCache.remove(at: idx)
            }
        }
    }

    /// Removes the first match by (ocId); batched commit.
    func removeItem(ocId: String) {
        transferStoreIO.sync {
            if let idx = transferItemsCache.firstIndex(where: {
                $0.ocId == ocId
            }) {
                transferItemsCache.remove(at: idx)
            }
        }
    }

    /// Forces an immediate flush to disk (e.g., app background/terminate).
    private func forceFlush() {
        guard let url = self.transferStoreURL else {
            return
        }
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "NCTransferStore.flush") {
            UIApplication.shared.endBackgroundTask(bgTask); bgTask = .invalid
        }
        defer {
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask); bgTask = .invalid
            }
        }

        transferStoreIO.sync {
            do {
                let data = try encoderTransferItem.encode(transferItemsCache)
                try data.write(to: url, options: .atomic)
                lastPersist = CFAbsoluteTimeGetCurrent()
                changeCounter = 0
                nkLog(tag: NCGlobal.shared.logTagTransferStore, emoji: .info, message: "Force flush to disk")
            } catch {
                nkLog(tag: NCGlobal.shared.logTagTransferStore, emoji: .error, message: "Force flush to disk failed: \(error)")
            }
        }
    }

    // MARK: - Private

    /// Merge: only non-nil fields from `new` overwrite existing values.
    private func mergeItem(existing: TransferItem, with new: TransferItem) -> TransferItem {
        return TransferItem(
            completed: new.completed ?? existing.completed,
            date: new.date ?? existing.date,
            etag: new.etag ?? existing.etag,
            fileName: existing.fileName ?? new.fileName,
            ocId: new.ocId ?? existing.ocId,
            ocIdTransfer: new.ocIdTransfer ?? existing.ocIdTransfer,
            progress: new.progress ?? existing.progress,
            selector: new.selector ?? existing.selector,
            serverUrl: existing.serverUrl ?? new.serverUrl,
            session: new.session ?? existing.session,
            status: new.status ?? existing.status,
            size: new.size ?? existing.size,
            taskIdentifier: new.taskIdentifier ?? existing.taskIdentifier
        )
    }

    /// Persist if threshold reached or max latency exceeded.
    private func maybeCommit() {
        transferStoreIO.sync {
            guard let url = self.transferStoreURL else {
                return
            }
            let now = CFAbsoluteTimeGetCurrent()
            let tooManyChanges = changeCounter >= batchThreshold
            let tooOld = (now - lastPersist) >= maxLatencySec
            guard tooManyChanges || tooOld else {
                return
            }

            do {
                let data = try encoderTransferItem.encode(transferItemsCache)
                try data.write(to: url, options: .atomic)
                lastPersist = now
                changeCounter = 0
            } catch {
                nkLog(tag: NCGlobal.shared.logTagTransferStore, emoji: .error, message: "Flush to disk failed: \(error)")
            }
        }

        Task {
            await syncUploadRealm()
        }
    }

    private func startDebounceTimer() {
        let t = DispatchSource.makeTimerSource(queue: debounceQueue)
        t.schedule(deadline: .now() + .seconds(Int(maxLatencySec)), repeating: .seconds(Int(maxLatencySec)))
        t.setEventHandler { [weak self] in
            self?.maybeCommit()
        }
        t.resume()
        debounceTimer = t
    }

    private func stopDebounceTimer() {
        debounceTimer?.cancel()
        debounceTimer = nil
    }

    /// Reloads the entire JSON store from disk synchronously.
    /// When this function returns, `transferItemsCache` is guaranteed to be updated.
    private func reloadFromDisk() {
        guard let url = self.transferStoreURL else {
            return
        }

        transferStoreIO.sync {
            do {
                let data = try Data(contentsOf: url)
                let items = try self.decoderTransferItem.decode([TransferItem].self, from: data)
                guard !items.isEmpty else {
                    self.transferItemsCache = []
                    nkLog(tag: NCGlobal.shared.logTagTransferStore, emoji: .info, message: "Load JSON from disk empty, cache cleared", consoleOnly: true)
                    return
                }
                self.transferItemsCache = items
                // check
                self.checkOrphaned()
                nkLog(tag: NCGlobal.shared.logTagTransferStore, emoji: .info, message: "JSON loaded from disk)", consoleOnly: true)
            } catch {
                nkLog(tag: NCGlobal.shared.logTagTransferStore, emoji: .error, message: "Load JSON from disk failed: \(error)")
            }
        }
    }

    private func checkOrphaned() {
        let transfers: Set<String> = Set(transferItemsCache.compactMap { $0.ocIdTransfer })
        let ocids: Set<String> = Set(transferItemsCache.compactMap { $0.ocId })

        if !transfers.isEmpty || !ocids.isEmpty {

            // Build a predicate that matches either ocIdTransfer or ocId
            // Note: pass empty sets as arrays to keep format arguments consistent
            let predicate = NSPredicate(format: "(ocIdTransfer IN %@) OR (ocId IN %@)", Array(transfers), Array(ocids))

            // Query Realm once
            let metadatas = NCManageDatabase.shared.getMetadatas(predicate: predicate)

            // Build found sets for quick lookup
            let foundTransfers: Set<String> = Set(metadatas.compactMap { $0.ocIdTransfer })
            let foundOcids: Set<String> = Set(metadatas.compactMap { $0.ocId })

            // Remove items that have NEITHER a matching ocIdTransfer NOR a matching ocId in Realm
            let before = transferItemsCache.count
            transferItemsCache.removeAll { item in
                let ocIdTransfer = item.ocIdTransfer
                let ocId = item.ocId
                // Keep if either matches; remove only if both are missing
                let hasMatch = (ocIdTransfer != nil && foundTransfers.contains(ocIdTransfer!)) || (ocId != nil && foundOcids.contains(ocId!))
                return !hasMatch
            }
            let removed = before - transferItemsCache.count
            if removed > 0 {
                nkLog(tag: NCGlobal.shared.logTagTransferStore, emoji: .warning, message: "Removed \(removed) orphaned items (no match on ocIdTransfer nor ocId)", consoleOnly: true)
            }
        }
    }

    /// Performs the actual Realm write using your async APIs.
    private func syncUploadRealm() async {
        let snapshotUpload: [TransferItem] = transferStoreIO.sync {
            transferItemsCache.filter { item in
                if let completed = item.completed, completed {
                    return item.session == NCNetworking.shared.sessionUpload
                    || item.session == NCNetworking.shared.sessionUploadBackground
                    || item.session == NCNetworking.shared.sessionUploadBackgroundExt
                    || item.session == NCNetworking.shared.sessionUploadBackgroundWWan
                }
                return false
            }
        }
        let snapshotDownload: [TransferItem] = transferStoreIO.sync {
            transferItemsCache.filter { item in
                if let completed = item.completed, completed {
                    return item.session == NCNetworking.shared.sessionDownload
                    || item.session == NCNetworking.shared.sessionDownloadBackground
                    || item.session == NCNetworking.shared.sessionDownloadBackgroundExt
                }
                return false
            }
        }
        var serversUrl = Set<String>()
        let utility = NCUtility()

        // Upload
        let ocIdTransfers = snapshotUpload.compactMap { $0.ocIdTransfer }
        let metadatasUpload = await NCManageDatabase.shared.getMetadatasAsync(predicate: NSPredicate(format: "ocIdTransfer IN %@", ocIdTransfers))
        var metadatasUploaded: [tableMetadata] = []

        for metadata in metadatasUpload {
            guard let transferItem = (snapshotUpload.first { $0.ocIdTransfer == metadata.ocIdTransfer }),
                  let etag = transferItem.etag,
                  let ocId = transferItem.ocId else {
                continue
            }

            metadata.uploadDate = (transferItem.date as? NSDate) ?? NSDate()
            metadata.etag = etag
            metadata.ocId = ocId
            metadata.chunk = 0

            if let fileId = utility.ocIdToFileId(ocId: metadata.ocId) {
                metadata.fileId = fileId
            }

            metadata.session = ""
            metadata.sessionError = ""
            metadata.sessionTaskIdentifier = 0
            metadata.status = NCGlobal.shared.metadataStatusNormal

            metadatasUploaded.append(metadata)
            serversUrl.insert(metadata.serverUrl)

            removeItem(ocIdTransfer: metadata.ocIdTransfer)
        }

        await NCManageDatabase.shared.replaceMetadataAsync(ocIdTransfers: ocIdTransfers, metadatas: metadatasUploaded)

        // Download
        let ocIds = snapshotDownload.compactMap { $0.ocId }
        let metadatasDownload = await NCManageDatabase.shared.getMetadatasAsync(predicate: NSPredicate(format: "ocId IN %@", ocIds))
        var metadatasDownloaded: [tableMetadata] = []

        if !metadatasDownload.isEmpty {
            for metadata in metadatasDownload {
                guard let transferItem = (snapshotDownload.first { $0.ocId == metadata.ocId }),
                      let etag = transferItem.etag else {
                    continue
                }

                metadata.etag = etag
                metadata.session = ""
                metadata.sessionError = ""
                metadata.sessionTaskIdentifier = 0
                metadata.status = NCGlobal.shared.metadataStatusNormal

                metadatasDownloaded.append(metadata)
                serversUrl.insert(metadata.serverUrl)

                removeItem(ocId: metadata.ocId)
            }

            await NCManageDatabase.shared.addMetadatasAsync(metadatasDownloaded)
            await NCManageDatabase.shared.addLocalFilesAsync(metadatas: metadatasDownloaded)
        }

        // TransferDispatcher Reload Data
        if !serversUrl.isEmpty {
            await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                for serverUrl in serversUrl {
                    delegate.transferReloadData(serverUrl: serverUrl, status: nil)
                }
            }
        }
    }
}
