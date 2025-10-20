// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

final class TransfersViewModel: ObservableObject {
    @Published var items: [tableMetadata] = []
    @Published var progressMap: [String: Float] = [:]
    @Published var isLoading = false

    // Dependencies
    private let session: NCSession.Session
    private let database = NCManageDatabase.shared
    private let networking = NCNetworking.shared
    private let utilityFileSystem = NCUtilityFileSystem()
    private let global = NCGlobal.shared

    internal var sceneIdentifier: String = ""

    init(session: NCSession.Session) {
        self.session = session

        Task { @MainActor in
            await NCNetworking.shared.transferDispatcher.addDelegate(self)
        }
    }

    deinit {
        print("deinit")
    }

    @MainActor
    func pollTransfers() async {
        while !Task.isCancelled {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                isLoading = true
                let transfersSuccess = await networking.metadataTranfersSuccess.getAll()
                items = await database.getTransferAsync(tranfersSuccess: transfersSuccess)
                isLoading = false
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    func cancel(item: tableMetadata) async {
        guard let metadata = await self.database.getMetadataFromOcIdAndocIdTransferAsync(item.ocIdTransfer) else {
            return
        }
        await NCNetworking.shared.cancelTask(metadata: metadata)
    }

    func readablePath(for item: tableMetadata) -> String {
        let url = item.serverUrl
        let home = utilityFileSystem.getHomeServer(session: session)
        var path = url.replacingOccurrences(of: home, with: "")
        if path.isEmpty { path = "/" }
        return path
    }

    func progress(for item: tableMetadata) -> Float {
        let serverUrl = item.serverUrl
        let fileName = item.fileName
        let key = "\(serverUrl)|\(fileName)"
        return progressMap[key] ?? Float(0)
    }

    func status(for item: tableMetadata) -> (symbol: String, status: String, info: String) {
        let sizeText: String = {
            return utilityFileSystem.transformedSize(item.size)
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
            return ("exclamationmark.circle", NSLocalizedString("_status_upload_error_", comment: ""), item.sessionError)
        case global.metadataStatusNormal:
            return ("checkmark.circle", NSLocalizedString("_done_", comment: ""), sizeText)
        default:
            return ("exclamationmark.circle", "", "")
        }
    }

    func wwanWaitInfoIfNeeded(for item: tableMetadata) -> String? {
        if item.session == NCNetworking.shared.sessionUploadBackgroundWWan,
           !(NCNetworking.shared.networkReachability == .reachableEthernetOrWiFi) {
            return NSLocalizedString("_waiting_for_", comment: "") + " " + NSLocalizedString("_reachable_wifi_", comment: "")
        }
        return nil
    }
}

extension TransfersViewModel: @MainActor NCTransferDelegate {
    func transferProgressDidUpdate(progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String) {
        Task { @MainActor in
            let key = "\(serverUrl)|\(fileName)"
            return progressMap[key] = progress
        }
    }
}
