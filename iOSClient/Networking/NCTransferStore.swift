// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

// MARK: - Transfer Store (batched persistence)

/// Immutable transfer item snapshot used by the Transfer Store.
/// Fields are optional to allow partial updates/merges during upsert operations.
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

/// Centralized, batched persistence of transfer items with low-IO strategy and lifecycle-aware flushes.
///
/// The store keeps an in-memory cache and periodically persists it to disk (JSON)
/// based on change count and latency thresholds. It also reacts to app lifecycle
/// events to ensure data safety across foreground/background transitions.
final class NCTransferStore {
    static let shared = NCTransferStore()

    // Shared state
    // In-memory cache of transfer items. Access must be performed on `transferStoreIO`.
    private var transferItemsCache: [TransferItem] = []
    // Serialization queue for disk and cache mutations.
    private let transferStoreIO = DispatchQueue(label: "TransferStore.IO", qos: .utility)
    // Timer queue used for periodic debounce commits.
    private let debounceQueue = DispatchQueue(label: "TransferStore.Debounce", qos: .utility)
    // JSON encoders/decoders configured with ISO8601 dates.
    private let encoderTransferItem = JSONEncoder()
    private let decoderTransferItem = JSONDecoder()
    // Backing file URL for persisted JSON.
    private(set) var transferStoreURL: URL?

    // Batching controls
    // Counts in-memory changes since the last persist.
    private var changeCounter: Int = 0
    // Last successful persist absolute time.
    private var lastPersist: TimeInterval = 0
    // Max number of changes before forcing a persist.
    private let batchThreshold: Int = NCBrandOptions.shared.numMaximumProcess / 2
    // Max elapsed time (seconds) between persists.
    private let maxLatencySec: TimeInterval = 5     // <- or every 5s at most
    // Periodic debounce timer.
    private var debounceTimer: DispatchSourceTimer?

    /// Initializes the store, loads any existing snapshot from disk,
    /// configures date strategies and installs lifecycle observers and debounce timer.
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

    }

    /// Installs observers to align flush behavior with app lifecycle:
    /// - Stop debounce when resigning active.
    /// - Force a flush on backgrounding.
    /// - Reload from disk and restart debounce shortly after becoming active.
    private func setupLifecycleFlush() {
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { _ in
            self.stopDebounceTimer()
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
            self.commit(forced: true)
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }
            // Force a synchronous reload before anything else
            self.reloadFromDisk()

            Task {
                // Small delay to avoid racing with other app-activation tasks.
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self.startDebounceTimer()
            }
        }
    }

    // MARK: Public API

    /// Inserts or updates a transfer item (upsert by `serverUrl + fileName + taskIdentifier`), then schedules a commit.
    ///
    /// - Parameter item: The item to insert or merge into the cache.
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
        }

        commit()
    }

    /// Removes the first item matching `(serverUrl, fileName, taskIdentifier)` and schedules a commit.
    ///
    /// - Parameters:
    ///   - serverUrl: Server URL associated with the transfer.
    ///   - fileName: File name of the transfer.
    ///   - taskIdentifier: URLSession task identifier.
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

        commit()
    }

    /// Removes the first item matching `ocIdTransfer` and schedules a commit.
    ///
    /// - Parameter ocIdTransfer: Transfer identifier used to track upload sessions.
    func removeItem(ocIdTransfer: String) {
        transferStoreIO.sync {
            if let idx = transferItemsCache.firstIndex(where: {
                $0.ocIdTransfer == ocIdTransfer
            }) {
                transferItemsCache.remove(at: idx)
            }
        }

        commit()
    }

    /// Removes the first item matching `ocId` and schedules a commit.
    ///
    /// - Parameter ocId: Object identifier (Nextcloud file OCID).
    func removeItem(ocId: String) {
        transferStoreIO.sync {
            if let idx = transferItemsCache.firstIndex(where: {
                $0.ocId == ocId
            }) {
                transferItemsCache.remove(at: idx)
            }
        }

        commit()
    }

    /// Updates `progress` for the item identified by `(serverUrl, fileName, taskIdentifier)`.
    ///
    /// - Parameters:
    ///   - serverUrl: The server URL associated with the item.
    ///   - fileName: The file name associated with the item.
    ///   - taskIdentifier: URLSession task identifier.
    ///   - progress: New progress value in `[0.0, 1.0]`.
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

    // MARK: - Private

    /// Field-wise merge of two `TransferItem` values preferring non-nil fields from `new`.
    ///
    /// - Parameters:
    ///   - existing: Current cached value.
    ///   - new: New snapshot to merge in.
    /// - Returns: The merged `TransferItem`.
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

    /// Commits (flushes) the in-memory transfer items cache to disk, optionally forcing the operation.
    ///
    /// This method safely serializes the `transferItemsCache` and writes it to the file at `transferStoreURL`.
    /// The operation is executed synchronously on the dedicated `transferStoreIO` queue to ensure thread safety.
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
    /// When a flush occurs, the cache is encoded using `encoderTransferItem` and persisted atomically to prevent corruption.
    /// Any error during serialization or write is logged through `nkLog` with detailed context.
    ///
    /// Parameters:
    /// - forced: When `true`, bypasses batching and app-state checks to force an immediate disk flush.
    ///
    /// Side effects:
    /// - Triggers an asynchronous call to `syncUploadRealm()` after each disk commit to synchronize the persisted data with Realm.
    /// - Logs successful and failed flushes using the tag `NCGlobal.shared.logTagTransferStore`.
    ///
    /// This method is optimized for reliability during background transitions and efficient I/O behavior under frequent cache updates.
    private func commit(forced: Bool = false) {
        guard let url = self.transferStoreURL else {
            return
        }

        func diskStore() {
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
            return
        }

        #if EXTENSION
            diskStore()
        #else
        if UIApplication.shared.applicationState == .background || forced {
            diskStore()
        }
        #endif

        changeCounter &+= 1

        let tooManyChanges = changeCounter >= batchThreshold
        let tooOld = (CFAbsoluteTimeGetCurrent() - lastPersist) >= maxLatencySec
        guard tooManyChanges || tooOld else {
            return
        }

        diskStore()

        Task {
            await syncUploadRealm()
        }
    }

    /// Starts the periodic debounce timer that triggers time-based commits.
    ///
    /// The timer runs on `debounceQueue` and calls `commit()` every `maxLatencySec` seconds.
    /// It is idempotent across start calls if `debounceTimer` is already active.
    private func startDebounceTimer() {
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
    /// This method executes synchronously on `transferStoreIO` to keep mutation serialized.
    /// It logs success/failure and clears the cache if the file is empty.
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

    /// Removes items from the in-memory cache that no longer exist in Realm (no match on `ocIdTransfer` nor `ocId`).
    ///
    /// Skips execution while the app is in background (main app only).
    /// Performs a single Realm query using a composed predicate for efficiency, then prunes unmatched items.
    private func checkOrphaned() {
        #if !EXTENSION
        if UIApplication.shared.applicationState == .background {
            return
        }
        #endif

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

    /// Synchronizes completed transfers from the cache into Realm and notifies delegates to refresh UI state.
    ///
    /// - Note: No-op while the main app is in background.
    /// - Upload path:
    ///   - Finds completed upload transfers, fetches corresponding metadatas by `ocIdTransfer`,
    ///     updates fields (`uploadDate`, `etag`, `ocId`, `fileId`, `status`, clears session fields),
    ///     persists via `replaceMetadataAsync`, and removes processed items from the cache.
    /// - Download path:
    ///   - Finds completed download transfers, fetches metadatas by `ocId`,
    ///     updates fields (`etag`, `status`, clears session fields),
    ///     persists via `addMetadatasAsync` and `addLocalFilesAsync`, and removes processed items.
    /// - Finally, notifies all transfer delegates per `serverUrl` to reload data.
    private func syncUploadRealm() async {
        #if !EXTENSION
        if await UIApplication.shared.applicationState == .background {
            return
        }
        #endif

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
