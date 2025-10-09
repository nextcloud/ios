// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

/// A lightweight transactional store based on JSON, implementing batched commits and atomic writes.
/// Acts as an in-memory document-oriented micro-database synchronized to disk.
/// Designed for efficient, low-latency persistence of transient transfer metadata with strong consistency guarantees
/// between in-memory state and its file-backed representation.
///
/// Version 0.1 - October 2025 by Marino Faggiana

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
    var selector: String?
    var serverUrl: String?
    var session: String?
    var status: Int?
    var size: Int64?
    var taskIdentifier: Int?
}

/// Centralized, batched persistence of transfer items with low-IO strategy and lifecycle-aware flushes.
///
/// The store keeps an in-memory cache and periodically persists it to disk (JSON)
/// based on change count and latency thresholds. It also reacts to app lifecycle
/// events to ensure data safety across foreground/background transitions.
final class NCMetadataStore {
    static let shared = NCMetadataStore()

    // Shared state
    // In-memory cache of metadata items. Access must be performed on `storeIO`.
    private var metadataItemsCache: [MetadataItem] = []
    // Serialization queue for disk and cache mutations.
    private let storeIO = DispatchQueue(label: "MetadataStore.IO", qos: .utility)
    // Timer queue used for periodic debounce commits.
    private let debounceQueue = DispatchQueue(label: "MetadataStore.Debounce", qos: .utility)
    // JSON encoders/decoders configured with ISO8601 dates.
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
    private let maxLatencySec: TimeInterval = 5     // <- or every 5s at most
    // Periodic debounce timer.
    private var debounceTimer: DispatchSourceTimer?

    private var observers: [NSObjectProtocol] = []

    /// Initializes the store, loads any existing snapshot from disk,
    /// configures date strategies and installs lifecycle observers and debounce timer.
    init() {
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601

        guard let groupDirectory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup) else {
            return
        }
        let backupDirectory = groupDirectory.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud)
        self.storeURL = backupDirectory.appendingPathComponent(fileMetadataStore)

        self.storeIO.sync {
            if let url = self.storeURL,
                let data = try? Data(contentsOf: url),
                !data.isEmpty,
               let items = try? self.decoder.decode([MetadataItem].self, from: data) {
                self.metadataItemsCache = items
            } else {
                self.metadataItemsCache = []
            }
        }

        self.lastPersist = CFAbsoluteTimeGetCurrent()

        setupLifecycleFlush()
        startDebounceTimer()
    }

    deinit {
        stopDebounceTimer()
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }

    /// Installs observers to align flush behavior with app lifecycle:
    /// - Stop debounce when resigning active.
    /// - Force a flush on backgrounding.
    /// - Reload from disk and restart debounce shortly after becoming active.
    private func setupLifecycleFlush() {
        let willResignActiveNotification = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { _ in
            self.stopDebounceTimer()
        }

        let didEnterBackgroundNotification = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
            self.commit(forced: true)
        }

        let didBecomeActiveNotification = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }
            // Force a synchronous reload before anything else
            self.reloadFromDisk()

            Task {
                // Small delay to avoid racing with other app-activation tasks.
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self.startDebounceTimer()
            }
        }

        observers = [willResignActiveNotification, didEnterBackgroundNotification, didBecomeActiveNotification]
    }

    // MARK: Public API

    /// Inserts or updates a item (upsert by `serverUrl + fileName + taskIdentifier`), then schedules a commit.
    ///
    /// - Parameter item: The item to insert or merge into the cache.
    func addItem(_ item: MetadataItem,
                 forFileName fileName: String,
                 forServerUrl serverUrl: String,
                 forTaskIdentifier taskIdentifier: Int) {
        storeIO.sync {
            // Upsert by (serverUrl + fileName + taskIdentifier)
            if let idx = metadataItemsCache.firstIndex(where: {
                $0.serverUrl == serverUrl &&
                $0.fileName == fileName &&
                $0.taskIdentifier == taskIdentifier
            }) {
                let merged = mergeItem(existing: metadataItemsCache[idx], with: item)
                metadataItemsCache[idx] = merged
            } else {
                metadataItemsCache.append(item)
            }
        }

        commit()
    }

    /// Removes the first item matching `(serverUrl, fileName, taskIdentifier)` and schedules a commit.
    ///
    /// - Parameters:
    ///   - serverUrl: Server URL associated with the transfer.
    ///   - fileName: File name of the transfer.
    ///   - taskIdentifier: URLSession task identifier.
    func removeItem(forFileName fileName: String,
                    forServerUrl serverUrl: String,
                    forTaskIdentifier taskIdentifier: Int) {
        let removed: Bool = storeIO.sync {
            if let idx = metadataItemsCache.firstIndex(where: {
                $0.serverUrl == serverUrl &&
                $0.fileName == fileName &&
                $0.taskIdentifier == taskIdentifier
            }) {
                metadataItemsCache.remove(at: idx)
                return true
            }
            return false
        }

        if removed {
            commit()
        }
    }

    /// Removes the first item matching `ocIdTransfer` and schedules a commit.
    ///
    /// - Parameter ocIdTransfer: Transfer identifier used to track upload sessions.
    func removeItem(forOcIdTransfer ocIdTransfer: String) {
        let removed: Bool = storeIO.sync {
            if let idx = metadataItemsCache.firstIndex(where: {
                $0.ocIdTransfer == ocIdTransfer
            }) {
                metadataItemsCache.remove(at: idx)
                return true
            }
            return false
        }

        if removed {
            commit()
        }
    }

    /// Removes the first item matching `ocId` and schedules a commit.
    ///
    /// - Parameter ocId: Object identifier (Nextcloud file OCID).
    func removeItem(forOcId ocId: String) {
        let removed: Bool = storeIO.sync {
            if let idx = metadataItemsCache.firstIndex(where: {
                $0.ocId == ocId
            }) {
                metadataItemsCache.remove(at: idx)
                return true
            }
            return false
        }

        if removed {
            commit()
        }
    }

    /// Updates the transfer progress for a specific item and triggers periodic persistence.
    ///
    /// This method locates the in-memory `MetadataItem` matching the provided
    /// `(serverUrl, fileName, taskIdentifier)` tuple and updates its `progress` value.
    /// The operation is performed synchronously on the `storeIO` queue
    /// to maintain thread-safe access to the cache.
    ///
    /// After updating the value, a conditional commit is triggered to limit
    /// disk I/O:
    /// - Progress values of **0.0** or **1.0** (start or completion) always trigger a flush.
    /// - Intermediate progress triggers a flush only when reaching a multiple of **10%**
    ///   (e.g. 0.1, 0.2, 0.3, ...), ensuring periodic persistence during long transfers.
    ///
    /// - Parameters:
    ///   - serverUrl: The server URL associated with the transfer.
    ///   - fileName: The file name associated with the transfer.
    ///   - taskIdentifier: The unique URLSession task identifier.
    ///   - progress: The new progress value, normalized in the range `[0.0, 1.0]`.
    func transferProgress(serverUrl: String, fileName: String, taskIdentifier: Int, progress: Double) {
        let updated = storeIO.sync { () -> Bool in
            if let idx = metadataItemsCache.firstIndex(where: {
                $0.serverUrl == serverUrl &&
                $0.fileName == fileName &&
                $0.taskIdentifier == taskIdentifier
            }) {
                metadataItemsCache[idx].progress = progress
                return true
            }
            return false
        }

        if updated,
           progress == 0 || progress == 1 || (progress * 100).truncatingRemainder(dividingBy: 10) == 0 {
            commit()
        }
    }

    // MARK: - Private

    /// Field-wise merge of two `MetadataItem` values preferring non-nil fields from `new`.
    ///
    /// - Parameters:
    ///   - existing: Current cached value.
    ///   - new: New snapshot to merge in.
    /// - Returns: The merged `TransferItem`.
    private func mergeItem(existing: MetadataItem, with new: MetadataItem) -> MetadataItem {
        return MetadataItem(
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

    /// Commits (flushes) the in-memory metadata items cache to disk, optionally forcing the operation.
    ///
    /// This method safely serializes the `metadataItemsCache` and writes it to the file at `storeURL`.
    /// The operation is executed synchronously on the dedicated `storeIO` queue to ensure thread safety.
    ///
    /// Behavior:
    /// - When running inside an extension (`#if EXTENSION`), the cache is always written immediately.
    /// - In the main app, the cache is written if either:
    ///     - The app is currently in background (`UIApplication.shared.applicationState == .background`), or
    ///     - The call is explicitly forced (`forced == true`).
    ///
    /// The method uses a **batched commit** strategy to limit disk I/O:
    /// - The write is skipped unless one of the following thresholds is reached:
    ///     - `changeCounter >= batchThreshold` (too many in-memory modifications)
    ///     - `maxLatencySec` seconds have passed since the last persist (`tooOld`)
    /// - After a successful write, both `changeCounter` and `lastPersist` are reset.
    ///
    /// When a flush occurs, the cache is encoded using `encoder` and persisted atomically to prevent corruption.
    /// Any error during serialization or write is logged through `nkLog` with detailed context.
    ///
    /// Parameters:
    /// - forced: When `true`, bypasses batching and app-state checks to force an immediate disk flush.
    ///
    /// Side effects:
    /// - Triggers an asynchronous call to `syncRealm()` after each disk commit to synchronize the persisted data with Realm.
    /// - Logs successful and failed flushes using the tag `NCGlobal.shared.logTagTransferStore`.
    ///
    /// This method is optimized for reliability during background transitions and efficient I/O behavior under frequent cache updates.
    private func commit(forced: Bool = false) {
        guard let url = self.storeURL else {
            return
        }
        var didWrite = false

        func diskStore() {
            storeIO.sync {
                do {
                    // Ensure directory exists
                    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

                    let data = try encoder.encode(metadataItemsCache)
                    try data.write(to: url, options: .atomic)
                    lastPersist = CFAbsoluteTimeGetCurrent()
                    changeCounter = 0
                    didWrite = true
                    nkLog(tag: NCGlobal.shared.logTagTransferStore, emoji: .info, message: "Force flush to disk")
                } catch {
                    nkLog(tag: NCGlobal.shared.logTagTransferStore, emoji: .error, message: "Force flush to disk failed: \(error)")
                }
            }
            return
        }

        #if EXTENSION
        diskStore()
        #else
        if appIsInBackground() || forced {
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
            Task {
                await syncRealm()
            }
        }
    }

    /// Starts the periodic debounce timer that triggers time-based commits.
    ///
    /// The timer runs on `debounceQueue` and calls `commit()` every `maxLatencySec` seconds.
    /// It is idempotent across start calls if `debounceTimer` is already active.
    private func startDebounceTimer() {
        guard debounceTimer == nil else {
            return
        }

        let t = DispatchSource.makeTimerSource(queue: debounceQueue)
        t.schedule(deadline: .now() + .seconds(Int(maxLatencySec)), repeating: .seconds(Int(maxLatencySec)))
        t.setEventHandler { [weak self] in
            self?.commit()
        }
        t.resume()
        debounceTimer = t
    }

    /// Stops and releases the debounce timer if present.
    private func stopDebounceTimer() {
        debounceTimer?.cancel()
        debounceTimer = nil
    }

    /// Reloads the on-disk JSON store into the in-memory cache, replacing the current snapshot.
    ///
    /// This method executes synchronously on `storeIO` to keep mutation serialized.
    /// It logs success/failure and clears the cache if the file is empty.
    private func reloadFromDisk() {
        guard let url = self.storeURL else {
            return
        }

        storeIO.sync {
            do {
                let data = try Data(contentsOf: url)
                let items = try self.decoder.decode([MetadataItem].self, from: data)
                guard !items.isEmpty else {
                    self.metadataItemsCache = []
                    nkLog(tag: NCGlobal.shared.logTagTransferStore, emoji: .info, message: "Load JSON from disk empty, cache cleared", consoleOnly: true)
                    return
                }
                self.metadataItemsCache = items
                // check
                self.checkOrphaned()
                nkLog(tag: NCGlobal.shared.logTagTransferStore, emoji: .info, message: "JSON loaded from disk", consoleOnly: true)
            } catch {
                nkLog(tag: NCGlobal.shared.logTagTransferStore, emoji: .error, message: "Load JSON from disk failed: \(error)")
            }
        }
    }

    /// Removes items from the in-memory cache that no longer exist in Realm (no match on `ocIdTransfer` nor `ocId`).
    ///
    /// Skips execution while the app is in background (main app only).
    /// Performs a single Realm query using a composed predicate for efficiency, then prunes unmatched items.
    private func checkOrphaned() {
        if appIsInBackground() {
            return
        }

        let transfers: Set<String> = Set(metadataItemsCache.compactMap { $0.ocIdTransfer })
        let ocids: Set<String> = Set(metadataItemsCache.compactMap { $0.ocId })

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
            let before = metadataItemsCache.count
            metadataItemsCache.removeAll { item in
                let ocIdTransfer = item.ocIdTransfer
                let ocId = item.ocId
                // Keep if either matches; remove only if both are missing
                let hasMatch = (ocIdTransfer != nil && foundTransfers.contains(ocIdTransfer!)) || (ocId != nil && foundOcids.contains(ocId!))
                return !hasMatch
            }
            let removed = before - metadataItemsCache.count
            if removed > 0 {
                nkLog(tag: NCGlobal.shared.logTagTransferStore, emoji: .warning, message: "Removed \(removed) orphaned items (no match on ocIdTransfer nor ocId)", consoleOnly: true)
            }
        }
    }

    /// Synchronizes completed upload and download items with Realm metadata.
    /// - Performs a foreground-only sync (skips if app is in background).
    /// - Builds snapshots of completed uploads/downloads from `metadataItemsCache`.
    /// - Updates matching `tableMetadata` entries in Realm:
    ///   • Uploads: apply `etag`, `ocId`, `uploadDate`, reset session fields.
    ///   • Downloads: apply `etag`, reset session fields, add to local files.
    /// - Removes processed items from memory (`removeItem`).
    /// - Notifies delegates via `transferDispatcher` to refresh affected `serverUrl`s.
    ///
    /// Runs on a background thread and awaits Realm async operations.
    private func syncRealm() async {
        if appIsInBackground() {
            return
        }

        let snapshotUpload: [MetadataItem] = storeIO.sync {
            metadataItemsCache.filter { item in
                if let completed = item.completed, completed {
                    return item.session == NCNetworking.shared.sessionUpload
                    || item.session == NCNetworking.shared.sessionUploadBackground
                    || item.session == NCNetworking.shared.sessionUploadBackgroundExt
                    || item.session == NCNetworking.shared.sessionUploadBackgroundWWan
                }
                return false
            }
        }
        let snapshotDownload: [MetadataItem] = storeIO.sync {
            metadataItemsCache.filter { item in
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

            removeItem(forOcIdTransfer: metadata.ocIdTransfer)
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

                removeItem(forOcId: metadata.ocId)
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

    // MARK: - Private helpers

    #if !EXTENSION
    @inline(__always)
    private func appIsInBackground() -> Bool {
        if Thread.isMainThread {
            return UIApplication.shared.applicationState == .background
        } else {
            var isBg = false
            DispatchQueue.main.sync {
                isBg = (UIApplication.shared.applicationState == .background)
            }
            return isBg
        }
    }
    #else

    @inline(__always)
    private func appIsInBackground() -> Bool {
        // In extensions we treat "background" checks as false by convention
        return false
    }
    #endif
}
