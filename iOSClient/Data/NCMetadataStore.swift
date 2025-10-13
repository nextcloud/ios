// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

/// Lightweight transactional store based on JSON with batched commits and atomic writes.
/// Acts as an in-memory micro-database synchronized to disk, ensuring low-latency persistence
/// and strong consistency between memory and file state.
///
/// Version 1.0 — October 2025 by Marino Faggiana
///
/// Notes:
/// - Actor-based isolation: all mutations are serialized by the actor itself.
/// - Flushes are lifecycle-aware and aligned with app background transitions.

// MARK: - Transfer Store (batched persistence)

/// Immutable transfer item snapshot used by the Metadata Store.
/// Fields are optional to allow partial updates/merges during upsert operations.
struct MetadataItem: Codable, Identifiable {
    var id: String {
        ocIdTransfer ?? ocId ?? (serverUrl ?? "") + (fileName ?? "") + String(taskIdentifier ?? 0)
    }

    var completed: Bool?
    var date: Date?
    var etag: String?
    var fileName: String?
    var ocId: String?
    var ocIdTransfer: String?
    var progress: Double?
    var serverUrl: String?
    var session: String?
    var size: Int64?
    var status: Int?
    var taskIdentifier: Int?
}

actor NCMetadataStore {
    static let shared = NCMetadataStore()

    var metadataItemsCache: [MetadataItem] = [] {
        didSet {
            // print("Array changed, count: \(metadataItemsCache.count)")
        }
    }
    // Timer queue used for periodic debounce commits.
    private let debounceQueue = DispatchQueue(label: "MetadataStore.Debounce", qos: .utility)
    // JSON encoders/decoders
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    // Backing file URL for persisted JSON.
    private(set) var storeURL: URL?

    // Prevents concurrent Realm synchronizations.
    // Only one `syncRealm()` can run at a time; additional requests are ignored
    // until the current one completes.
    private var isSyncingRealm = false

    // Observer
    private var observers: [NSObjectProtocol] = []

    // MARK: - Initialization

    /// Loads the on-disk snapshot, configures the encoder/decoder and schedules lifecycle observers.
    init() {
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601

        if let groupDirectory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup) {
            let backupDirectory = groupDirectory.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud)
            self.storeURL = backupDirectory.appendingPathComponent(fileMetadataStore)
        }

        if let url = self.storeURL,
            let data = try? Data(contentsOf: url),
            !data.isEmpty,
            let items = try? self.decoder.decode([MetadataItem].self, from: data) {
            self.metadataItemsCache = items
        } else {
            self.metadataItemsCache = []
        }

        // Post-init setup (actor-safe)
        Task { [weak self] in
            guard let self else {
                return
            }
            await self.setupLifecycleFlush()
        }
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }

    // MARK: - Lifecycle Hooks

    /// Aligns flush operations with app lifecycle:
    /// - Pauses timer on `willResignActive`
    /// - Forces flush on `didEnterBackground`
    /// - Reloads and restarts timer on `didBecomeActive`
    private func setupLifecycleFlush() {
        let willResignActiveNotification = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 100_000_000)
                await self?.forcedFush()
            }
        }

        let didBecomeActiveNotification = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
            Task { [weak self] in
                await self?.reloadFromDisk()
            }
        }

        observers = [willResignActiveNotification, didBecomeActiveNotification]
    }

    // MARK: Public API

    /// Upserts an item (by `serverUrl + fileName + taskIdentifier`) and schedules a commit.
    func addItem(_ item: MetadataItem,
                 forFileName fileName: String,
                 forServerUrl serverUrl: String,
                 forTaskIdentifier taskIdentifier: Int) async {
        if let idx = metadataItemsCache.firstIndex(where: {
            $0.serverUrl == serverUrl &&
            $0.fileName == fileName &&
            $0.taskIdentifier == taskIdentifier
        }) {
            let merged = mergeItem(existing: metadataItemsCache[idx], with: item)
            metadataItemsCache[idx] = merged
        } else {
            var itemForAppend = item
            itemForAppend.fileName = fileName
            itemForAppend.serverUrl = serverUrl
            itemForAppend.taskIdentifier = taskIdentifier
            metadataItemsCache.append(itemForAppend)
        }

        await flush()
    }

    /// Marks a download as completed, updates its `etag`, and triggers a commit.
    func setDownloadCompleted(fileName: String, serverUrl: String, taskIdentifier: Int, etag: String?) async {
        if let idx = metadataItemsCache.firstIndex(where: {
            $0.serverUrl == serverUrl &&
            $0.fileName == fileName &&
            $0.taskIdentifier == taskIdentifier
        }) {
            let merged = mergeItem(existing: metadataItemsCache[idx], with: MetadataItem(completed: true, etag: etag, status: 0))
            metadataItemsCache[idx] = merged
        } else {
            // Not found? get from metadata
            if let metadata = await NCManageDatabase.shared.getMetadataAsync(predicate: NSPredicate(format: "serverUrl == %@ AND fileName == %@", serverUrl, fileName)) {
                let itemForAppend = MetadataItem(completed: true,
                                                 etag: etag,
                                                 fileName: fileName,
                                                 ocId: metadata.ocId,
                                                 ocIdTransfer: metadata.ocIdTransfer,
                                                 serverUrl: serverUrl,
                                                 session: NCNetworking.shared.sessionDownload,
                                                 status: 0,
                                                 taskIdentifier: taskIdentifier)
                metadataItemsCache.append(itemForAppend)
            }
        }

        await flush()
    }

    /// Marks a upload as completed, updates its `ocid, etag, size, date`, and triggers a commit.
    func setUploadCompleted(fileName: String, serverUrl: String, taskIdentifier: Int, metadata: tableMetadata? = nil, ocId: String?, etag: String?, size: Int64, date: Date?) async {

        if let idx = metadataItemsCache.firstIndex(where: {
            $0.serverUrl == serverUrl &&
            $0.fileName == fileName &&
            $0.taskIdentifier == taskIdentifier
        }) {
            let merged = mergeItem(existing: metadataItemsCache[idx], with: MetadataItem(completed: true,
                                                                                         date: date,
                                                                                         etag: etag,
                                                                                         ocId: ocId,
                                                                                         size: size,
                                                                                         status: 0))
            metadataItemsCache[idx] = merged
        } else {
            // Not found? get from metadata
            if let metadata {
                let itemForAppend = MetadataItem(completed: true,
                                                 etag: etag,
                                                 fileName: fileName,
                                                 ocId: metadata.ocId,
                                                 ocIdTransfer: metadata.ocIdTransfer,
                                                 serverUrl: serverUrl,
                                                 session: NCNetworking.shared.sessionUpload,
                                                 status: 0,
                                                 taskIdentifier: taskIdentifier)
                metadataItemsCache.append(itemForAppend)
            }
        }

        await flush()
    }

    /// Removes a specific cached item and commits the change.
    func removeItem(fileName: String, serverUrl: String, taskIdentifier: Int) async {
        var removed = false
        if let idx = metadataItemsCache.firstIndex(where: {
            $0.serverUrl == serverUrl &&
            $0.fileName == fileName &&
            $0.taskIdentifier == taskIdentifier
        }) {
            metadataItemsCache.remove(at: idx)
            removed = true
        }

        if removed {
            await flush()
        }
    }

    /// Removes a specific cached item and commits the change.
    func removeItem(forOcIdTransfer ocIdTransfer: String) async {
        var removed = false
        if let idx = metadataItemsCache.firstIndex(where: { $0.ocIdTransfer == ocIdTransfer }) {
            metadataItemsCache.remove(at: idx)
            removed = true
        }

        if removed {
            await flush()
        }
    }

    /// Removes a specific cached item and commits the change.
    func removeItem(forOcId ocId: String) async {
        var removed = false
        if let idx = metadataItemsCache.firstIndex(where: { $0.ocId == ocId }) {
            metadataItemsCache.remove(at: idx)
            removed = true
        }

        if removed {
            await flush()
        }
    }

    /// Removes a specific cached item and commits the change.
    func removeItems(forOcIds ocIds: [String]) async {
        guard !ocIds.isEmpty else {
            return
        }

        let before = metadataItemsCache.count
        metadataItemsCache.removeAll { item in
            if let ocId = item.ocId {
                return ocIds.contains(ocId)
            }
            return false
        }
        let removedCount = before - metadataItemsCache.count

        if removedCount > 0 {
            await flush()
        }
    }

    /// Updates `progress` for an item
    func transferProgress(serverUrl: String, fileName: String, taskIdentifier: Int, progress: Double) async {
        if let idx = metadataItemsCache.firstIndex(where: {
            $0.serverUrl == serverUrl &&
            $0.fileName == fileName &&
            $0.taskIdentifier == taskIdentifier
        }) {
            metadataItemsCache[idx].progress = progress
        }
    }

    /// Forces an immediate
    func forcedFush() async {
        await flush(forced: true)
    }

    func countCache() async -> Int {
        return metadataItemsCache.count
    }

    // MARK: - Private

    /// Merges two metadata items, preferring non-nil fields from the new value.
    private func mergeItem(existing: MetadataItem, with new: MetadataItem) -> MetadataItem {
        return MetadataItem(
            completed: new.completed ?? existing.completed,
            date: new.date ?? existing.date,
            etag: new.etag ?? existing.etag,
            fileName: existing.fileName ?? new.fileName,
            ocId: new.ocId ?? existing.ocId,
            ocIdTransfer: new.ocIdTransfer ?? existing.ocIdTransfer,
            progress: new.progress ?? existing.progress,
            serverUrl: existing.serverUrl ?? new.serverUrl,
            session: new.session ?? existing.session,
            size: new.size ?? existing.size,
            status: new.status ?? existing.status,
            taskIdentifier: new.taskIdentifier ?? existing.taskIdentifier
        )
    }

    /// Serializes and atomically writes the cache to disk, respecting batching thresholds.
    private func flush(forced: Bool = false) async {
        guard let url = storeURL,
              forced || isStoreInBackground() else {
            return
        }

        let snapshot = self.metadataItemsCache
        let encoder = self.encoder

        nkLog(tag: NCGlobal.shared.logTagMetadataStore, emoji: .info, message: "Flushed \(metadataItemsCache.count) items", consoleOnly: true)

        let success = await Task.detached(priority: .utility) { () -> Bool in
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                let data = try encoder.encode(snapshot)
                try data.write(to: url, options: .atomic)
                return true
            } catch {
                nkLog(tag: NCGlobal.shared.logTagMetadataStore, emoji: .error,
                      message: "Flush failed: \(error)")
                return false
            }
        }.value

        if success {
            scheduleSyncRealm()
        }
    }

    /// Reloads the JSON snapshot from disk and removes orphaned items.
    private func reloadFromDisk() async {
        guard let url = self.storeURL else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let items = try self.decoder.decode([MetadataItem].self, from: data)
            guard !items.isEmpty else {
                self.metadataItemsCache = []
                nkLog(tag: NCGlobal.shared.logTagMetadataStore, emoji: .warning, message: "Load \(fileMetadataStore) from disk empty, cache cleared", consoleOnly: true)
                return
            }
            self.metadataItemsCache = items
            await self.checkOrphaned()
            nkLog(tag: NCGlobal.shared.logTagMetadataStore, emoji: .info, message: "\(fileMetadataStore) loaded from disk", consoleOnly: true)
        } catch {
            nkLog(tag: NCGlobal.shared.logTagMetadataStore, emoji: .error, message: "Load \(fileMetadataStore) from disk failed: \(error)")
        }
    }

    /// Prunes items not present in Realm (or with status `.normal`).
    private func checkOrphaned() async {
        if isStoreInBackground() {
            return
        }

        let transfers: Set<String> = Set(metadataItemsCache.compactMap { $0.ocIdTransfer })
        let ocids: Set<String> = Set(metadataItemsCache.compactMap { $0.ocId })

        if !transfers.isEmpty || !ocids.isEmpty {
            let predicate = NSPredicate(format: "((ocIdTransfer IN %@) OR (ocId IN %@)) AND (status IN %@)", Array(transfers), Array(ocids), [NCGlobal.shared.metadataStatusDownloading, NCGlobal.shared.metadataStatusUploading])
            let metadatas = NCManageDatabase.shared.getMetadatas(predicate: predicate)
            let foundTransfers: Set<String> = Set(metadatas.compactMap { $0.ocIdTransfer })
            let foundOcids: Set<String> = Set(metadatas.compactMap { $0.ocId })

            let before = metadataItemsCache.count
            metadataItemsCache.removeAll { item in
                let ocIdTransfer = item.ocIdTransfer
                let ocId = item.ocId
                let hasMatch =
                    (ocIdTransfer != nil && foundTransfers.contains(ocIdTransfer!)) ||
                    (ocId != nil && foundOcids.contains(ocId!))

                return !hasMatch
            }

            let removed = before - metadataItemsCache.count
            if removed > 0 {
                nkLog(tag: NCGlobal.shared.logTagMetadataStore, emoji: .warning, message: "Removed \(removed) orphaned items (no match on ocIdTransfer nor ocId)", consoleOnly: true)
            }
        }
    }

    // MARK: - Realm Sync

    /// Schedules a Realm synchronization task if none is currently running.
    ///
    /// The flag `isSyncingRealm` is set inside the `storeIO` queue to ensure
    /// serialized access with respect to other store operations.
    /// If a sync is already in progress, this call exits immediately.
    ///
    /// Safe to call from any thread.
    private func scheduleSyncRealm() {
        guard !isSyncingRealm else {
            return
        }
        isSyncingRealm = true

        Task { [weak self] in
            guard let self else { return }
            defer {
                Task {
                    await self.finishSyncRealm()
                }
            }
            await self.syncRealm()
        }
    }

    /// Runs on a background thread and awaits Realm async operations.
    private func syncRealm() async {
        if isStoreInBackground() {
            return
        }

        let snapshotUpload: [MetadataItem] = metadataItemsCache.filter { item in
            if let completed = item.completed, completed {
                return item.session == NCNetworking.shared.sessionUpload
                || item.session == NCNetworking.shared.sessionUploadBackground
                || item.session == NCNetworking.shared.sessionUploadBackgroundExt
                || item.session == NCNetworking.shared.sessionUploadBackgroundWWan
            }
            return false
        }
        let snapshotDownload: [MetadataItem] = metadataItemsCache.filter { item in
            if let completed = item.completed, completed {
                return item.session == NCNetworking.shared.sessionDownload
                || item.session == NCNetworking.shared.sessionDownloadBackground
                || item.session == NCNetworking.shared.sessionDownloadBackgroundExt
            }
            return false
        }

        if snapshotUpload.isEmpty && snapshotDownload.isEmpty {
            return
        }

        // UPLOAD
        let metadatasUploaded = await NCNetworking.shared.uploadSuccess(WithMetadataItems: snapshotUpload)
        // DOWNLOAD
        let metadatasDownloaded = await NCNetworking.shared.downloadSuccess(WithMetadataItems: snapshotDownload)

        // TransferDispatcher
        //
        if !metadatasUploaded.isEmpty {
            await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                for metadata in metadatasUploaded {
                    delegate.transferChange(status: NCGlobal.shared.networkingStatusUploaded,
                                            metadata: metadata,
                                            error: .success)
                }
            }
        }

        if !metadatasDownloaded.isEmpty {
            await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                for metadata in metadatasDownloaded {
                    delegate.transferChange(status: NCGlobal.shared.networkingStatusDownloaded,
                                            metadata: metadata,
                                            error: .success)
                }
            }
        }
    }

    // MARK: - Private helpers

    #if !EXTENSION
    @inline(__always)
    private func isStoreInBackground() -> Bool {
       return isAppInBackground
    }
    #else
    @inline(__always)
    private func isStoreInBackground() -> Bool {
        return false
    }
    #endif

    @inline(__always)
    private func finishSyncRealm() {
        isSyncingRealm = false
    }

    // Heuristics
    func cacheIsHuge(thresholdBytes: Int) async -> Bool {
        // ~500B for item
        return metadataItemsCache.count * 500 > thresholdBytes
    }

    func cacheCount() async -> Int {
        return metadataItemsCache.count
    }
}
