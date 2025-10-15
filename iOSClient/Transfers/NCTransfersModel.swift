// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

final class TransfersViewModel: ObservableObject {
    @Published var items: [MetadataItem] = []
    @Published var progressMap: [String: Float] = [:]
    @Published var isLoading = false

    // Dependencies
    private let session: NCSession.Session
    private let database = NCManageDatabase.shared
    private let networking = NCNetworking.shared
    private let utilityFileSystem = NCUtilityFileSystem()
    private let global = NCGlobal.shared

    internal var sceneIdentifier: String = ""
    internal var itemsDB: [MetadataItem] = []

    init(session: NCSession.Session) {
        self.session = session

        Task { @MainActor in
            await NCNetworking.shared.transferDispatcher.addDelegate(self)
        }
    }

    deinit { }

    @MainActor
    func reload(withDatabase: Bool) async {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return
        }

        isLoading = true
        defer {
            isLoading = false
        }
        if withDatabase {
            itemsDB = await database.getTransferAsync()
        }
        let metadataItemsCache = await NCMetadataStore.shared.metadataItemsCache
        items = itemsDB + metadataItemsCache
    }

    func cancel(item: MetadataItem) async {
        await reload(withDatabase: true)
    }

    func cancelAll() {
        networking.cancelAllTask()
        Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            await reload(withDatabase: true)
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
        return progressMap[key] ?? Float(item.progress)
    }

    func status(for item: MetadataItem) -> (symbol: String, status: String, info: String) {
        let sizeText: String = {
            if let size = item.size {
                return utilityFileSystem.transformedSize(size)
            }
            return ""
        }()

        switch item.status {
        case global.metadataStatusWaitCreateFolder:
            return ("arrow.triangle.2.circlepath", NSLocalizedString("_status_wait_create_folder_", comment: ""), "")
        case global.metadataStatusWaitDelete:
            return ("trash.circle", NSLocalizedString("_status_wait_delete_", comment: ""), "")
        case global.metadataStatusWaitFavorite:
            return ("star.circle", NSLocalizedString("_status_wait_favorite_", comment: ""), "")
        case global.metadataStatusWaitCopy:
            return ("c.circle", NSLocalizedString("_status_wait_copy_", comment: ""), "")
        case global.metadataStatusWaitMove:
            return ("m.circle", NSLocalizedString("_status_wait_move_", comment: ""), "")
        case global.metadataStatusWaitRename:
            return ("a.circle", NSLocalizedString("_status_wait_rename_", comment: ""), "")
        case global.metadataStatusWaitDownload:
            return ("arrow.triangle.2.circlepath", NSLocalizedString("_status_wait_download_", comment: ""), sizeText)
        case global.metadataStatusDownloading:
            return ("arrowshape.down.circle", NSLocalizedString("_status_downloading_", comment: ""), sizeText)
        case global.metadataStatusWaitUpload:
            return ("arrow.triangle.2.circlepath", NSLocalizedString("_status_wait_upload_", comment: ""), "")
        case global.metadataStatusUploading:
            return ("arrowshape.up.circle", NSLocalizedString("_status_uploading_", comment: ""), sizeText)
        case global.metadataStatusDownloadError, global.metadataStatusUploadError:
            return ("exclamationmark.circle", NSLocalizedString("_status_upload_error_", comment: ""), "")
        default:
            return ("exclamationmark.circle", "", "")
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

extension TransfersViewModel: @MainActor NCTransferDelegate {
    func transferChange(status: String, metadatasError: [tableMetadata: NKError]) {
        Task {
            await self.reload(withDatabase: true)
        }
    }

    func transferChange(status: String, metadata: tableMetadata, error: NKError) {
        Task {
            let withDatabase = global.metadataStatusWaitWebDav.contains( metadata.status)
            await self.reload(withDatabase: withDatabase)
        }
    }

    func transferReloadData(serverUrl: String?, status: Int?) {
        Task {
            await self.reload(withDatabase: true)
        }
    }

    func transferProgressDidUpdate(progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String) {
        Task { @MainActor in
            let key = "\(serverUrl)|\(fileName)"
            return progressMap[key] = progress
        }
    }
}
