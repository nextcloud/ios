// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

// MARK: - Upload Store (batched persistence)

struct UploadItemDisk: Codable {
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

final class NCUploadStore {
    static let shared = NCUploadStore()

    // Shared state
    private var uploadItemsCache: [UploadItemDisk] = []
    private let uploadStoreIO = DispatchQueue(label: "UploadStore.IO", qos: .utility)
    private let encoderUploadItem = JSONEncoder()
    private let decoderUploadItem = JSONDecoder()
    private(set) var uploadStoreURL: URL?

    // Batching controls
    private var changeCounter: Int = 0
    private var lastPersist: TimeInterval = 0
    private let batchThreshold: Int = 20            // <- persist every 20 changes
    private let maxLatencySec: TimeInterval = 5     // <- or every 5s at most
    private var debounceTimer: DispatchSourceTimer?

    init() {
        self.encoderUploadItem.dateEncodingStrategy = .iso8601
        self.decoderUploadItem.dateDecodingStrategy = .iso8601

        guard let groupDirectory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup) else {
            return
        }
        let backupDirectory = groupDirectory.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud)
        self.uploadStoreURL = backupDirectory.appendingPathComponent(fileUploadStore)

        self.uploadStoreIO.sync {
            // Load existing file
            if let url = self.uploadStoreURL,
                let data = try? Data(contentsOf: url),
                !data.isEmpty,
                let items = try? self.decoderUploadItem.decode([UploadItemDisk].self, from: data) {
                self.uploadItemsCache = items
            } else {
                self.uploadItemsCache = []
            }
        }

        self.lastPersist = CFAbsoluteTimeGetCurrent()
        setupLifecycleFlush()
        startDebounceTimer()
    }

    deinit {
        stopDebounceTimer()
        forceFlush()
    }

    private func setupLifecycleFlush() {
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { [weak self] _ in
            self?.flushWithBackgroundTime()
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
            self?.stopDebounceTimer()
            self?.flushWithBackgroundTime()
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
            self?.startDebounceTimer()
        }
    }

    private func flushWithBackgroundTime() {
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "NCUploadStore.flush") {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
        forceFlush()
        UIApplication.shared.endBackgroundTask(bgTask)
        bgTask = .invalid
    }

    // MARK: Public API

    /// Adds or merges an item, then schedules a batched commit.
    func addUploadItem(_ item: UploadItemDisk) {
        guard let url = self.uploadStoreURL else {
            return
        }

        uploadStoreIO.sync {
            // Upsert by (serverUrl + fileName + taskIdentifier)
            if let idx = uploadItemsCache.firstIndex(where: {
                $0.serverUrl == item.serverUrl &&
                $0.fileName == item.fileName &&
                $0.taskIdentifier == item.taskIdentifier
            }) {
                let merged = mergeUploadItem(existing: uploadItemsCache[idx], with: item)
                uploadItemsCache[idx] = merged
            } else {
                uploadItemsCache.append(item)
            }

            changeCounter &+= 1
            maybeCommit(url: url)
        }
    }

    /// Updates only the `progress` field of an existing upload item, then schedules a batched commit.
    /// If no matching item is found, nothing happens.
    func updateUploadProgress(serverUrl: String?, fileName: String?, taskIdentifier: Int?, progress: Double) {
        guard let url = self.uploadStoreURL else {
            return
        }

        uploadStoreIO.sync {
            if let idx = uploadItemsCache.firstIndex(where: {
                $0.serverUrl == serverUrl &&
                $0.fileName == fileName &&
                $0.taskIdentifier == taskIdentifier
            }) {
                // Update only progress field
                uploadItemsCache[idx].progress = progress
                changeCounter &+= 1
                maybeCommit(url: url)
            }
        }
    }

    /// Removes the first match by (serverUrl + fileName); batched commit.
    func removeUploadItem(serverUrl: String, fileName: String, taskIdentifier: Int?) {
        guard let url = self.uploadStoreURL else {
            return
        }

        uploadStoreIO.sync {
            if let idx = uploadItemsCache.firstIndex(where: {
                $0.serverUrl == serverUrl &&
                $0.fileName == fileName &&
                $0.taskIdentifier == taskIdentifier
            }) {
                uploadItemsCache.remove(at: idx)
                changeCounter &+= 1
                maybeCommit(url: url)
            }
        }
    }

    /// Removes the first match by (ocIdTransfer); batched commit.
    func removeUploadItem(ocIdTransfer: String) {
        guard let url = self.uploadStoreURL else {
            return
        }

        uploadStoreIO.sync {
            if let idx = uploadItemsCache.firstIndex(where: {
                $0.ocIdTransfer == ocIdTransfer
            }) {
                uploadItemsCache.remove(at: idx)
                changeCounter &+= 1
                maybeCommit(url: url)
            }
        }
    }

    /// Forces an immediate flush to disk (e.g., app background/terminate).
    func forceFlush() {
        guard let url = self.uploadStoreURL else {
            return
        }

        uploadStoreIO.sync {
            do {
                let data = try encoderUploadItem.encode(uploadItemsCache)
                try data.write(to: url, options: .atomic)
                lastPersist = CFAbsoluteTimeGetCurrent()
                changeCounter = 0
            } catch {
                nkLog(tag: NCGlobal.shared.logTagUploadStore, emoji: .info, message: "Force flush failed: \(error)")
            }
        }
    }

    // MARK: - Private

    /// Merge: only non-nil fields from `new` overwrite existing values.
    private func mergeUploadItem(existing: UploadItemDisk, with new: UploadItemDisk) -> UploadItemDisk {
        return UploadItemDisk(
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
    private func maybeCommit(url: URL) {
        let now = CFAbsoluteTimeGetCurrent()
        let tooManyChanges = changeCounter >= batchThreshold
        let tooOld = (now - lastPersist) >= maxLatencySec

        guard tooManyChanges || tooOld else {
            return
        }

        do {
            let data = try encoderUploadItem.encode(uploadItemsCache)
            try data.write(to: url, options: .atomic)
            lastPersist = now
            changeCounter = 0
        } catch {
            nkLog(tag: NCGlobal.shared.logTagUploadStore, emoji: .error, message: "Persist failed: \(error)")
        }
    }

    private func startDebounceTimer() {
        let t = DispatchSource.makeTimerSource(queue: uploadStoreIO)
        t.schedule(deadline: .now() + .seconds(Int(maxLatencySec)), repeating: .seconds(Int(maxLatencySec)))
        t.setEventHandler { [weak self] in
            guard let self, let url = self.uploadStoreURL else { return }
            // Periodic check to enforce max latency even without new changes burst
            self.maybeCommit(url: url)
        }
        t.resume()
        debounceTimer = t
    }

    private func stopDebounceTimer() {
        debounceTimer?.cancel()
        debounceTimer = nil
    }
}
