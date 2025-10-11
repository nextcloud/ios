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
struct MetadataItem: Codable {
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

    // Batching controls
    // Counts in-memory changes since the last persist.
    private var changeCounter: Int = 0
    // Last successful persist absolute time.
    private var lastPersist: TimeInterval = 0
    // Max number of changes before forcing a persist.
    private let batchThreshold: Int = max(1, NCBrandOptions.shared.numMaximumProcess / 2)
    // Max elapsed time (seconds) between persists.
    private let maxLatencySec: TimeInterval = 5 // <- or every 5s at most
    // Periodic debounce timer.
    private var debounceTimer: DispatchSourceTimer?
    private var currentLatency: TimeInterval?

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

        self.lastPersist = CFAbsoluteTimeGetCurrent()

        // Post-init setup (actor-safe)
        Task { [weak self] in
            guard let self else {
                return
            }
            await self.setupLifecycleFlush()
            await self.startDebounceTimer()
        }
    }

    deinit {
        Task { [weak self] in
            guard let self else {
                return
            }
            await self.stopDebounceTimer()
        }
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
        let willResignActiveNotification = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { [weak self] _ in
            Task { [weak self] in
                await self?.stopDebounceTimer()
            }
        }

        let didEnterBackgroundNotification = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
            Task { [weak self] in
                await self?.commit(forced: true)
            }
        }

        let didBecomeActiveNotification = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
            Task { [weak self] in
                await self?.reloadFromDisk()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await self?.startDebounceTimer()
            }
        }

        observers = [willResignActiveNotification, didEnterBackgroundNotification, didBecomeActiveNotification]
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

        await commit()
    }

    /// Marks a download as completed, updates its `etag`, and triggers a commit.
    func setDownloadCompleted(fileName: String, serverUrl: String, taskIdentifier: Int, etag: String?) async {
        var session: String?

        if let idx = metadataItemsCache.firstIndex(where: {
            $0.serverUrl == serverUrl &&
            $0.fileName == fileName &&
            $0.taskIdentifier == taskIdentifier
        }) {
            let merged = mergeItem(existing: metadataItemsCache[idx], with: MetadataItem(completed: true, etag: etag, status: 0))
            metadataItemsCache[idx] = merged
            session = merged.session
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
                session = itemForAppend.session
            }
        }

        await commit(forced: session == NCNetworking.shared.sessionDownload)
    }

    /// Marks a upload as completed, updates its `ocid, etag, size, date`, and triggers a commit.
    func setUploadCompleted(fileName: String, serverUrl: String, taskIdentifier: Int, metadata: tableMetadata? = nil, ocId: String?, etag: String?, size: Int64, date: Date?) async {
        var session: String?

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
            session = merged.session
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
                session = itemForAppend.session
            }
        }

        await commit(forced: session == NCNetworking.shared.sessionUpload)
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
            await commit()
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
            await commit()
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
            await commit()
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
            await commit()
        }
    }

    /// Updates `progress` for an item and conditionally triggers a flush (0%, 10%, … 100%).
    func transferProgress(serverUrl: String, fileName: String, taskIdentifier: Int, progress: Double) async {
        var updated = false
        if let idx = metadataItemsCache.firstIndex(where: {
            $0.serverUrl == serverUrl &&
            $0.fileName == fileName &&
            $0.taskIdentifier == taskIdentifier
        }) {
            metadataItemsCache[idx].progress = progress
            updated = true
        }

        if updated,
           progress == 0 || progress == 1 || (progress * 100).truncatingRemainder(dividingBy: 10) == 0 {
            await commit()
        }
    }

    /// Forces an immediate Realm sync, bypassing debounce logic.
    func forcedSyncRealm() async {
        await commit(forced: true)
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
    private func commit(forced: Bool = false) async {
        guard let url = self.storeURL else {
            return
        }
        var didWrite = false

        func diskStore() {
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                let data = try encoder.encode(metadataItemsCache)
                try data.write(to: url, options: .atomic)
                lastPersist = CFAbsoluteTimeGetCurrent()
                changeCounter = 0
                didWrite = true
            } catch {
                nkLog(tag: NCGlobal.shared.logTagTransferStore, emoji: .error, message: "Force flush to disk failed: \(error)")
            }
        }

        #if EXTENSION
        diskStore()
        #else
        if await appIsInBackground() || forced {
            diskStore()
        }
        #endif

        if !didWrite {
            changeCounter &+= 1
            let tooManyChanges = changeCounter >= batchThreshold
            let tooOld = (CFAbsoluteTimeGetCurrent() - lastPersist) >= maxLatencySec
            if tooManyChanges || tooOld {
                diskStore()
            }
        }

        if didWrite {
            scheduleSyncRealm()
        }
    }

    /// Returns a dynamic latency (in seconds) for debounce flushes,
    /// proportional to the number of cached items.
    /// - 1 item  → 3s
    /// - 10 items → 5s
    /// - 50+ items → 10s
    private func dynamicLatency() -> TimeInterval {
        let count = metadataItemsCache.count
        var sec: TimeInterval = 0

        switch count {
        case 0...1:
            sec = 2
        case 2..<10:
            sec = 5
        case 10..<50:
            sec = 10
        default:
            sec = 15
        }

        nkLog(tag: NCGlobal.shared.logTagTransferStore, emoji: .debug, message: "Latency: \(sec) sec.", consoleOnly: true)

        return sec
    }

    private func onTimerFired(_ timer: DispatchSourceTimer) async {
        await commit()

        let newLatency = dynamicLatency()
        if currentLatency != newLatency {
            timer.schedule(deadline: .now() + newLatency, repeating: newLatency)
            currentLatency = newLatency
        }
    }

    /// Starts or restarts the periodic debounce timer (runs every `maxLatencySec`).
    private func startDebounceTimer() {
        guard debounceTimer == nil else {
            return
        }

        let t = DispatchSource.makeTimerSource(queue: debounceQueue)
        let initial = dynamicLatency()
        currentLatency = initial
        t.schedule(deadline: .now() + initial, repeating: initial)

        t.setEventHandler { [weak self, weak t] in
            guard let self, let timer = t else {
                return
            }
            Task {
                await self.onTimerFired(timer)
            }
        }

        t.resume()
        debounceTimer = t
    }

    /// Stops and releases the debounce timer if present.
    private func stopDebounceTimer() {
        debounceTimer?.cancel()
        debounceTimer = nil
        currentLatency = nil
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
                nkLog(tag: NCGlobal.shared.logTagTransferStore, emoji: .warning, message: "Load \(fileMetadataStore) from disk empty, cache cleared", consoleOnly: true)
                return
            }
            self.metadataItemsCache = items
            await self.checkOrphaned()
            nkLog(tag: NCGlobal.shared.logTagTransferStore, emoji: .info, message: "\(fileMetadataStore) loaded from disk", consoleOnly: true)
        } catch {
            nkLog(tag: NCGlobal.shared.logTagTransferStore, emoji: .error, message: "Load \(fileMetadataStore) from disk failed: \(error)")
        }
    }

    /// Prunes items not present in Realm (or with status `.normal`).
    private func checkOrphaned() async {
        if await appIsInBackground() {
            return
        }

        let statusNormal = NCGlobal.shared.metadataStatusNormal
        let transfers: Set<String> = Set(metadataItemsCache.compactMap { $0.ocIdTransfer })
        let ocids: Set<String> = Set(metadataItemsCache.compactMap { $0.ocId })

        if !transfers.isEmpty || !ocids.isEmpty {
            let predicate = NSPredicate(format: "(ocIdTransfer IN %@) OR (ocId IN %@)", Array(transfers), Array(ocids))
            let metadatas = NCManageDatabase.shared.getMetadatas(predicate: predicate)

            // No id found
            let foundTransfers: Set<String> = Set(metadatas.compactMap { $0.ocIdTransfer })
            let foundOcids: Set<String> = Set(metadatas.compactMap { $0.ocId })

            // sessionStatus normal
            let normalTransfers: Set<String> = Set(metadatas.lazy.filter { $0.status == statusNormal }.compactMap { $0.ocIdTransfer })
            let normalOcids: Set<String> = Set(metadatas.lazy.filter { $0.status == statusNormal }.compactMap { $0.ocId })

            // No Task Identifier
            let taskIdentifierTransfers: Set<String> = Set(metadatas.lazy.filter { $0.sessionTaskIdentifier == 0 }.compactMap { $0.ocIdTransfer })
            let taskIdentifierOcids: Set<String> = Set(metadatas.lazy.filter { $0.sessionTaskIdentifier == 0 }.compactMap { $0.ocId })

            let before = metadataItemsCache.count
            metadataItemsCache.removeAll { item in
                let ocIdTransfer = item.ocIdTransfer
                let ocId = item.ocId

                let hasMatch =
                    (ocIdTransfer != nil && foundTransfers.contains(ocIdTransfer!)) ||
                    (ocId != nil && foundOcids.contains(ocId!))

                let isInactive =
                    (ocIdTransfer != nil && normalTransfers.contains(ocIdTransfer!)) ||
                    (ocId != nil && normalOcids.contains(ocId!))

                let zeroTaskIdentifier =
                    (ocIdTransfer != nil && taskIdentifierTransfers.contains(ocIdTransfer!)) ||
                    (ocId != nil && taskIdentifierOcids.contains(ocId!))

                return (!hasMatch) || isInactive || zeroTaskIdentifier
            }

            let removed = before - metadataItemsCache.count
            if removed > 0 {
                nkLog(tag: NCGlobal.shared.logTagTransferStore, emoji: .warning, message: "Removed \(removed) orphaned items (no match on ocIdTransfer nor ocId)", consoleOnly: true)
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
        if await appIsInBackground() {
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
        let metadatasUploaded = await NCNetworking.shared.uploadSuccessMetadataItems(snapshotUpload)
        // DOWNLOAD
        let metadatasDownloaded = await NCNetworking.shared.downloadSuccessMetadataItems(snapshotDownload)

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
    private func appIsInBackground() async -> Bool {
        await MainActor.run {
            UIApplication.shared.applicationState == .background
        }
    }
    #else
    @inline(__always)
    private func appIsInBackground() async -> Bool {
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
