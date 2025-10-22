// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

final class TransfersViewModel: ObservableObject {
    @Published var items: [tableMetadata] = []
    @Published var progressMap: [String: Float] = [:]
    @Published var isLoading = false
    @Published var showFlushMessage = false
    @Published var inWaitingCount = 0
    @Published var inProgressCount = 0
    @Published var inErrorCount = 0

    // Dependencies
    private let session: NCSession.Session
    private let database = NCManageDatabase.shared
    private let networking = NCNetworking.shared
    private let utilityFileSystem = NCUtilityFileSystem()
    private let global = NCGlobal.shared

    private var observerToken: NSObjectProtocol?
    internal let sceneIdentifier: String = UUID().uuidString

    init(session: NCSession.Session) {
        self.session = session

        observerToken = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMetadataTranfersSuccessFlush), object: nil, queue: nil) { [weak self] _ in
            self?.showFlushMessage = true
        }

        Task { @MainActor in
            await NCNetworking.shared.transferDispatcher.addDelegate(self)
            await NCNetworkingProcess.shared.inWaitingBadge()
            await pollTransfers()
        }
    }

    deinit {
        print("deinit")
        if let token = observerToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    func detach() {
        if let token = observerToken {
            NotificationCenter.default.removeObserver(token)
            observerToken = nil
        }
        Task { @MainActor in
            await NCNetworking.shared.transferDispatcher.removeDelegate(self)
        }
    }

    @MainActor
    func pollTransfers() async {
        while !Task.isCancelled {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                isLoading = true
                let transfersSuccess = await networking.metadataTranfersSuccess.getAll()
                items = await database.getTransferAsync(tranfersSuccess: transfersSuccess)
                inWaitingCount = await NCNetworkingProcess.shared.getInWaitingCount()
                inProgressCount = items.compactMap(\.status)
                    .filter { NCGlobal.shared.metadatasStatusInProgress.contains($0) }
                    .count
               inErrorCount = items.compactMap(\.errorCode)
                    .filter { $0 != 0 }
                    .count
                isLoading = false
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
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
        return item.account + " " + path
    }

    func progress(for item: tableMetadata) -> Float {
        let serverUrl = item.serverUrl
        let fileName = item.fileName
        let key = "\(serverUrl)|\(fileName)"
        if item.status == global.metadataStatusDownloading || item.status == global.metadataStatusUploading {
            return progressMap[key] ?? Float(0)
        } else {
            return Float(0)
        }
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
            let symbol = "exclamationmark.circle"
            var status = NSLocalizedString("_status_upload_error_", comment: "")
            if let sessionDate = item.sessionDate {
                let elapsed = Date().timeIntervalSince(sessionDate)
                let remaining = max(0, 300 - elapsed)

                if remaining > 0 {
                    let minutesLeft = Int(remaining / 60)
                    let secondsLeft = Int(remaining.truncatingRemainder(dividingBy: 60))
                    // Formattiamo solo se meno di 10 min
                    if minutesLeft > 0 {
                        status += " – \(minutesLeft) " + NSLocalizedString("_retry_minutes_", comment: "")
                    } else {
                        status += " – \(secondsLeft) " + NSLocalizedString("_retry_seconds_", comment: "")
                    }
                } else {
                    status += " – " + NSLocalizedString("_retry_soon_", comment: "")
                }
            }
            return (symbol, status, item.sessionError)
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
            progressMap[key] = progress
        }
    }
}
