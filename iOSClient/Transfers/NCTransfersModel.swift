// FILE: NCTransferModel.swift
import Foundation
import Combine
import NextcloudKit

// MARK: - Notification Keys

/// Strongly-typed notification names used to mirror legacy delegate callbacks.
extension Notification.Name {
    static let NCTransferChange = Notification.Name("NCTransferChange")
    static let NCTransferReloadData = Notification.Name("NCTransferReloadData")
    static let NCTransferProgressDidUpdate = Notification.Name("NCTransferProgressDidUpdate")
}

// MARK: - Debounce / Throttle helpers

/// Coalesces rapid sequences of calls into a single execution after a delay.
final class Debouncer {
    private var task: Task<Void, Never>?
    private let delay: UInt64
    init(milliseconds: Int = 150) { self.delay = UInt64(milliseconds) * 1_000_000 }
    func call(_ action: @escaping @Sendable () -> Void) {
        task?.cancel()
        task = Task { [delay] in
            try? await Task.sleep(nanoseconds: delay)
            if Task.isCancelled { return }
            action()
        }
    }
}

/// Per-key throttle to limit publish frequency for progress updates.
final class ProgressThrottler {
    private var lastFire: [String: UInt64] = [:] // key -> nanoseconds
    func shouldFire(key: String, every milliseconds: Int) -> Bool {
        let now = DispatchTime.now().uptimeNanoseconds
        let minDelta = UInt64(milliseconds) * 1_000_000
        defer { lastFire[key] = now }
        guard let prev = lastFire[key] else { return true }
        return now - prev >= minDelta
    }
}

// MARK: - Transfer Events Bridge

/// Bridges networking transfer updates into the ViewModel using NotificationCenter.
/// Replace with production hooks if your networking exposes Combine or delegates directly.
final class TransferEventsBridge {
    private var cancellables = Set<AnyCancellable>()
    private let onChange: () -> Void
    private let onProgress: (_ progress: Float, _ total: Int64, _ expected: Int64, _ file: String, _ url: String) -> Void
    private let debouncer = Debouncer(milliseconds: 150)
    private let throttler = ProgressThrottler()

    init(onChange: @escaping () -> Void,
         onProgress: @escaping (_ progress: Float, _ total: Int64, _ expected: Int64, _ file: String, _ url: String) -> Void) {
        self.onChange = onChange
        self.onProgress = onProgress
    }

    func register(with networking: NCNetworking) {
        // If NCNetworking already posts these notifications, nothing else is needed.
        // Otherwise, wire your legacy delegates to post them (see adapter below).
        NotificationCenter.default.publisher(for: .NCTransferChange)
            .sink { [weak self] _ in
                guard let self else { return }
                self.debouncer.call {
                    self.onChange()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .NCTransferReloadData)
            .sink { [weak self] _ in
                guard let self else { return }
                self.debouncer.call {
                    self.onChange()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .NCTransferProgressDidUpdate)
            .compactMap { $0.userInfo as? [String: Any] }
            .sink { [weak self] info in
                guard let self else { return }
                let progress = info["progress"] as? Float ?? 0
                let total = info["totalBytes"] as? Int64 ?? 0
                let expected = info["totalBytesExpected"] as? Int64 ?? 0
                let fileName = info["fileName"] as? String ?? ""
                let serverUrl = info["serverUrl"] as? String ?? ""
                let key = "\(serverUrl)|\(fileName)"

                // Throttle to max ~10fps per key and ignore <1% deltas
                guard throttler.shouldFire(key: key, every: 100) else { return }
                self.onProgress(progress, total, expected, fileName, serverUrl)
            }
            .store(in: &cancellables)
    }

    func unregister() {
        cancellables.removeAll()
    }
}

// MARK: - Legacy Delegate → Notification adapter

/// Call these helpers from your existing UIKit delegate methods to notify the SwiftUI layer.
struct NCTransferLegacyAdapter {
    static func postChange(status: String) {
        NotificationCenter.default.post(name: .NCTransferChange, object: nil, userInfo: ["status": status])
    }
    static func postChange(status: String, errorMapCount: Int) {
        NotificationCenter.default.post(name: .NCTransferChange, object: nil, userInfo: ["status": status, "errors": errorMapCount])
    }
    static func postReload(serverUrl: String?, status: Int?) {
        var info: [String: Any] = [:]
        if let serverUrl { info["serverUrl"] = serverUrl }
        if let status { info["status"] = status }
        NotificationCenter.default.post(name: .NCTransferReloadData, object: nil, userInfo: info)
    }
    static func postProgress(progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String) {
        NotificationCenter.default.post(name: .NCTransferProgressDidUpdate,
                                        object: nil,
                                        userInfo: [
                                            "progress": progress,
                                            "totalBytes": totalBytes,
                                            "totalBytesExpected": totalBytesExpected,
                                            "fileName": fileName,
                                            "serverUrl": serverUrl
                                        ])
    }
}

// MARK: - ViewModel (MetadataItem based)

/// ViewModel powering the SwiftUI Transfers UI using `MetadataItem` records.
/// It mirrors the old NCTransfers list behavior, but reads from `getMetadataItemsTransfersAsync()`.
@MainActor
final class TransfersViewModel: ObservableObject {
    @Published var items: [MetadataItem] = []
    @Published var progressMap: [String: Float] = [:]
    @Published var isLoading = false
    @Published var title: String = NSLocalizedString("_transfers_", comment: "")

    // Dependencies
    private let session: NCSession.Session
    private let database = NCManageDatabase.shared
    private let networking = NCNetworking.shared
    private let utilityFileSystem = NCUtilityFileSystem()

    private var eventBridge: TransferEventsBridge?

    init(session: NCSession.Session) {
        self.session = session
    }

    /// Loads current transfer items using the new async source.
    func reload() async {
        isLoading = true
        defer {
            isLoading = false
        }
        self.items = await database.getMetadataItemsTransfersAsync()
    }

    /// Start observing transfer change/progress notifications.
    func startObserving() {
        guard eventBridge == nil else { return }
        let bridge = TransferEventsBridge { [weak self] in
            guard let self else { return }
            Task { await self.reload() }
        } onProgress: { [weak self] progress, total, expected, fileName, serverUrl in
            guard let self else { return }
            let key = "\(serverUrl)|\(fileName)"
            let old = progressMap[key] ?? 0
            // Ignore very tiny changes < 1%
            guard abs(progress - old) >= 0.01 else { return }
            self.progressMap[key] = progress
        }
        bridge.register(with: networking)
        self.eventBridge = bridge
    }

    /// Stop observing events.
    func stopObserving() {
        eventBridge?.unregister()
        eventBridge = nil
    }

    func cancel(item: MetadataItem) async {
        await reload()
    }

    func startTask(item: MetadataItem) async {
        await reload()
    }

    /// Cancel all transfers.
    func cancelAll() {
        networking.cancelAllTask()
        Task {
            try? await Task.sleep(nanoseconds: 150_000_000);
            await reload()
        }
    }

    /// Force start based on a seed item (replicates long-press -> startTask).
    func forceStart(from item: MetadataItem) async {
        if let ocId = item.ocId,
           let updated = await database.setMetadataSessionAsync(ocId: ocId, status: NCGlobal.shared.metadataStatusUploading) {
            await networking.uploadFileInBackground(metadata: updated)
        }
        await reload()
    }

    /// Human-readable path computed from serverUrl relative to home.
    func readablePath(for item: MetadataItem) -> String {
        guard let url = item.serverUrl else { return "/" }
        let home = utilityFileSystem.getHomeServer(session: session)
        var path = url.replacingOccurrences(of: home, with: "")
        if path.isEmpty { path = "/" }
        return path
    }

    /// Progress for a row.
    func progress(for item: MetadataItem) -> Float {
        let serverUrl = item.serverUrl ?? ""
        let fileName = item.fileName ?? ""
        let key = "\(serverUrl)|\(fileName)"
        return progressMap[key] ?? Float(item.progress ?? 0)
    }

    func status(for item: MetadataItem) -> (symbol: String?, status: String, info: String) {
        let sizeText: String = {
            if let size = item.size {
                return utilityFileSystem.transformedSize(size)
            }
            return ""
        }()

        let st = item.status ?? NCGlobal.shared.metadataStatusNormal
        switch st {
        case NCGlobal.shared.metadataStatusWaitCreateFolder:
            return ("arrow.triangle.2.circlepath", NSLocalizedString("_status_wait_create_folder_", comment: ""), "")
        case NCGlobal.shared.metadataStatusWaitDelete:
            return ("trash.circle", NSLocalizedString("_status_wait_delete_", comment: ""), "")
        case NCGlobal.shared.metadataStatusWaitFavorite:
            return ("star.circle", NSLocalizedString("_status_wait_favorite_", comment: ""), "")
        case NCGlobal.shared.metadataStatusWaitCopy:
            return ("c.circle", NSLocalizedString("_status_wait_copy_", comment: ""), "")
        case NCGlobal.shared.metadataStatusWaitMove:
            return ("m.circle", NSLocalizedString("_status_wait_move_", comment: ""), "")
        case NCGlobal.shared.metadataStatusWaitRename:
            return ("a.circle", NSLocalizedString("_status_wait_rename_", comment: ""), "")
        case NCGlobal.shared.metadataStatusWaitDownload:
            return ("arrow.triangle.2.circlepath", NSLocalizedString("_status_wait_download_", comment: ""), sizeText)
        case NCGlobal.shared.metadataStatusDownloading:
            return ("arrowshape.down.circle", NSLocalizedString("_status_downloading_", comment: ""), sizeText)
        case NCGlobal.shared.metadataStatusWaitUpload:
            return ("arrow.triangle.2.circlepath", NSLocalizedString("_status_wait_upload_", comment: ""), "")
        case NCGlobal.shared.metadataStatusUploading:
            return ("arrowshape.up.circle", NSLocalizedString("_status_uploading_", comment: ""), sizeText)
        case NCGlobal.shared.metadataStatusDownloadError, NCGlobal.shared.metadataStatusUploadError:
            return ("exclamationmark.circle", NSLocalizedString("_status_upload_error_", comment: ""), "")
        default:
            return (nil, "", "")
        }
    }

    /// Extra info line for WWAN waiting condition based on `session` string.
    func wwanWaitInfoIfNeeded(for item: MetadataItem) -> String? {
        guard let s = item.session else { return nil }
        if s == NCNetworking.shared.sessionUploadBackgroundWWan,
           !(NCNetworking.shared.networkReachability == .reachableEthernetOrWiFi) {
            return NSLocalizedString("_waiting_for_", comment: "") + " " + NSLocalizedString("_reachable_wifi_", comment: "")
        }
        return nil
    }
}
