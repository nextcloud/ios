// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

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

    private var changeObserver: NSObjectProtocol?
    private var reloadObserver: NSObjectProtocol?
    private var progressObserver: NSObjectProtocol?

    init(session: NCSession.Session) {
        self.session = session
        startObserving()
    }

    func reload() async {
        isLoading = true
        defer {
            isLoading = false
        }
        self.items = await database.getMetadataItemsTransfersAsync()
    }

    func startObserving() {
        changeObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("NCTransferChanged"),
            object: nil, queue: .main
        ) { [weak self] _ in
            Task {
                await self?.reload()
            }
        }

        reloadObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("NCTransferReloaded"),
            object: nil, queue: .main
        ) { [weak self] _ in
            Task {
                await self?.reload()
            }
        }

        progressObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("NCTransferProgress"),
            object: nil, queue: .main
        ) { [weak self] note in
            guard
                let info = note.userInfo as? [String: Any],
                let progress = info["progress"] as? Float,
                let total = info["total"] as? Int64,
                let expected = info["expected"] as? Int64,
                let file = info["file"] as? String,
                let url = info["url"] as? String
            else { return }

            let key = "\(url)|\(file)"
            self?.progressMap[key] = progress
        }
    }

    func stopObserving() {
        if let changeObserver {
            NotificationCenter.default.removeObserver(changeObserver)
        }
        if let reloadObserver {
            NotificationCenter.default.removeObserver(reloadObserver)
        }
        if let progressObserver {
            NotificationCenter.default.removeObserver(progressObserver)
        }
        changeObserver = nil
        reloadObserver = nil
        progressObserver = nil
    }

    func cancel(item: MetadataItem) async {
        await reload()
    }

    func startTask(item: MetadataItem) async {
        if let ocId = item.ocId,
           let updated = await database.setMetadataSessionAsync(ocId: ocId, status: NCGlobal.shared.metadataStatusUploading) {
            await networking.uploadFileInBackground(metadata: updated)
        }
        await reload()
    }

    func cancelAll() {
        networking.cancelAllTask()
        Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            await reload()
        }
    }

    func readablePath(for item: MetadataItem) -> String {
        guard let url = item.serverUrl else { return "/" }
        let home = utilityFileSystem.getHomeServer(session: session)
        var path = url.replacingOccurrences(of: home, with: "")
        if path.isEmpty { path = "/" }
        return path
    }

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

        let status = item.status ?? NCGlobal.shared.metadataStatusNormal
        switch status {
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

    func wwanWaitInfoIfNeeded(for item: MetadataItem) -> String? {
        guard let s = item.session else { return nil }
        if s == NCNetworking.shared.sessionUploadBackgroundWWan,
           !(NCNetworking.shared.networkReachability == .reachableEthernetOrWiFi) {
            return NSLocalizedString("_waiting_for_", comment: "") + " " + NSLocalizedString("_reachable_wifi_", comment: "")
        }
        return nil
    }
}
