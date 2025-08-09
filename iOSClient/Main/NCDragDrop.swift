// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import UniformTypeIdentifiers
import NextcloudKit
import Alamofire

class NCDragDrop: NSObject {
    let utilityFileSystem = NCUtilityFileSystem()
    let database = NCManageDatabase.shared
    let global = NCGlobal.shared

    func performDrag(metadata: tableMetadata? = nil, fileSelect: [String]? = nil) -> [UIDragItem] {
        var metadatas: [tableMetadata] = []

        if let metadata, metadata.status == 0, !metadata.isDirectoryE2EE, !metadata.e2eEncrypted {
            metadatas.append(metadata)
        } else if let fileSelect {
            for ocId in fileSelect {
                if let metadata = database.getMetadataFromOcId(ocId), metadata.status == 0, !metadata.isDirectoryE2EE, !metadata.e2eEncrypted {
                    metadatas.append(metadata)
                }
            }
        }

        let dragItems = metadatas.map { metadata in
            let itemProvider = NSItemProvider()
            itemProvider.registerDataRepresentation(forTypeIdentifier: global.metadataOcIdDataRepresentation, visibility: .all) { completion in
                let data = metadata.ocId.data(using: .utf8)
                completion(data, nil)
                return nil
            }
            return UIDragItem(itemProvider: itemProvider)
        }

        return dragItems
    }

    func performDrop(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator, serverUrl: String, isImageVideo: Bool, controller: NCMainTabBarController?) -> [tableMetadata]? {
        var serverUrl = serverUrl
        var metadatas: [tableMetadata] = []
        DragDropHover.shared.cleanPushDragDropHover()
        DragDropHover.shared.sourceMetadatas = nil

        for item in coordinator.session.items {
            if item.itemProvider.hasItemConformingToTypeIdentifier(global.metadataOcIdDataRepresentation) {
                let semaphore = DispatchSemaphore(value: 0)
                item.itemProvider.loadDataRepresentation(forTypeIdentifier: global.metadataOcIdDataRepresentation) { data, error in
                    if error == nil, let data, let ocId = String(data: data, encoding: .utf8),
                       let metadata = self.database.getMetadataFromOcId(ocId) {
                        if !isImageVideo {
                            metadatas.append(metadata)
                        } else if isImageVideo, metadata.isImageOrVideo {
                            metadatas.append(metadata)
                        }
                    }
                    semaphore.signal()
                }
                semaphore.wait()
            } else {
                item.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.data.identifier) { url, error in
                    if error == nil, let url = url {
                        if let destinationMetadata = DragDropHover.shared.destinationMetadata, destinationMetadata.directory {
                            serverUrl = destinationMetadata.serverUrl + "/" + destinationMetadata.fileName
                        }
                        let serverUrl = serverUrl
                        Task {
                            await self.uploadFile(url: url, serverUrl: serverUrl, controller: controller)
                        }
                    }
                }
            }
        }

        var invalidNameIndexes: [Int] = []
        let session = NCSession.shared.getSession(controller: controller)
        let capabilities = NCNetworking.shared.capabilities[session.account] ?? NKCapabilities.Capabilities()

        for (index, metadata) in metadatas.enumerated() {
            if let fileNameError = FileNameValidator.checkFileName(metadata.fileName, account: session.account, capabilities: capabilities) {
                if metadatas.count == 1 {
                    let alert = UIAlertController.renameFile(fileName: metadata.fileNameView, isDirectory: metadata.directory, capabilities: capabilities, account: metadata.account) { newFileName in
                        metadatas[index].fileName = newFileName
                        metadatas[index].fileNameView = newFileName
                        metadatas[index].serverUrlFileName = metadatas[index].serverUrl + "/" + newFileName
                    }

                    controller?.present(alert, animated: true)
                    return nil
                } else {
                    controller?.present(UIAlertController.warning(message: "\(fileNameError.errorDescription) \(NSLocalizedString("_please_rename_file_", comment: ""))"), animated: true)
                    invalidNameIndexes.append(index)
                }
            }
        }

        for index in invalidNameIndexes.reversed() {
            metadatas.remove(at: index)
        }

        if metadatas.isEmpty {
            return nil
        } else {
            return metadatas
        }
    }

    func uploadFile(url: URL, serverUrl: String, controller: NCMainTabBarController?) async {
        do {
            let data = try Data(contentsOf: url)
            let ocId = NSUUID().uuidString
            let session = NCSession.shared.getSession(controller: controller)
            let capabilities = await NKCapabilities.shared.getCapabilities(for: session.account)
            let newFileName = FileAutoRenamer.rename(url.lastPathComponent, capabilities: capabilities)
            let fileNamePath = utilityFileSystem.getDirectoryProviderStorageOcId(ocId, fileName: newFileName, userId: session.userId, urlBase: session.urlBase)

            if let fileNameError = FileNameValidator.checkFileName(newFileName, account: session.account, capabilities: capabilities),
                let controller {
                let message = "\(fileNameError.errorDescription) \(NSLocalizedString("_please_rename_file_", comment: ""))"
                await UIAlertController.warningAsync( message: message, presenter: controller)
                return
            }

            let fileName = await NCNetworking.shared.createFileName(fileNameBase: newFileName, account: session.account, serverUrl: serverUrl)

            try data.write(to: URL(fileURLWithPath: fileNamePath))

            let metadataForUpload = await database.createMetadataAsync(fileName: fileName,
                                                                       ocId: ocId,
                                                                       serverUrl: serverUrl,
                                                                       session: session,
                                                                       sceneIdentifier: controller?.sceneIdentifier)

            metadataForUpload.session = NCNetworking.shared.sessionUploadBackground
            metadataForUpload.sessionSelector = global.selectorUploadFile
            metadataForUpload.size = utilityFileSystem.getFileSize(filePath: fileNamePath)
            metadataForUpload.status = global.metadataStatusWaitUpload
            metadataForUpload.sessionDate = Date()

            database.addMetadata(metadataForUpload)
        } catch {
            NCContentPresenter().showError(error: NKError(error: error))
            return
        }
    }

    func copyFile(metadatas: [tableMetadata], destination: String) async {
        for metadata in metadatas {
            NCNetworking.shared.copyMetadata(metadata, destination: destination, overwrite: false)
            await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                delegate.transferCopy(metadata: metadata, destination: destination, error: .success)
            }
        }
    }

    func moveFile(metadatas: [tableMetadata], destination: String) async {
        for metadata in metadatas {
            NCNetworking.shared.moveMetadata(metadata, destination: destination, overwrite: false)
            await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                delegate.transferMove(metadata: metadata, destination: destination, error: .success)
            }
        }
    }

    @MainActor
    func transfers(collectionViewCommon: NCCollectionViewCommon, destination: String, session: NCSession.Session) async {
        guard let metadatas = DragDropHover.shared.sourceMetadatas else {
            return
        }
        let hud = NCHud(collectionViewCommon.controller?.view)
        var uploadRequest: UploadRequest?
        var downloadRequest: DownloadRequest?

        func setDetailText(status: String, percent: Int) {
            let text = "\(NSLocalizedString("_tap_to_cancel_", comment: "")) \(status) (\(percent)%)"
            hud.setDetailText(text)
        }

        hud.pieProgress(text: NSLocalizedString("_keep_active_for_transfers_", comment: ""),
                        tapToCancelDetailText: true) {
            if let downloadRequest {
                downloadRequest.cancel()
            } else if let uploadRequest {
                uploadRequest.cancel()
            }
        }

        for (index, metadata) in metadatas.enumerated() {
            if metadata.directory {
                continue
            }

            downloadRequest = nil
            uploadRequest = nil

            // DOWNLOAD
            if !utilityFileSystem.fileProviderStorageExists(metadata) {
                let results = await NCNetworking.shared.downloadFile(metadata: metadata,
                                                                     withDownloadComplete: true) { request in
                    downloadRequest = request
                } progressHandler: { progress in
                    let status = NSLocalizedString("_status_downloading_", comment: "").lowercased()
                    setDetailText(status: status, percent: Int(progress.fractionCompleted * 100))
                }
                guard results.nkError == .success else {
                    hud.error(text: results.nkError.errorDescription)
                    break
                }
            }

            // UPLOAD
            let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId,
                                                                                      fileName: metadata.fileName,
                                                                                      userId: metadata.userId,
                                                                                      urlBase: metadata.urlBase)

            let fileName = await NCNetworking.shared.createFileName(fileNameBase: metadata.fileName, account: session.account, serverUrl: destination)
            let serverUrlFileName = destination + "/" + fileName

            let results = await NCNetworking.shared.uploadFile(fileNameLocalPath: fileNameLocalPath,
                                                               serverUrlFileName: serverUrlFileName,
                                                               creationDate: metadata.creationDate as Date,
                                                               dateModificationFile: metadata.date as Date,
                                                               account: session.account,
                                                               withUploadComplete: false) { request in
                uploadRequest = request
            } progressHandler: { _, _, fractionCompleted in
                let status = NSLocalizedString("_status_uploading_", comment: "").lowercased()
                setDetailText(status: status, percent: Int(fractionCompleted * 100))
            }
            guard results.error == .success else {
                hud.error(text: results.error.errorDescription)
                break
            }

            hud.progress(Double(index + 1) / Double(metadatas.count))
        }

        await collectionViewCommon.getServerData(forced: true)
        hud.success()
    }
}

// MARK: -

class DragDropHover {
    static let shared = DragDropHover()

    var pushTimerIndexPath: Timer?
    var pushCollectionView: UICollectionView?
    var pushIndexPath: IndexPath?

    var sourceMetadatas: [tableMetadata]?
    var destinationMetadata: tableMetadata?

    func cleanPushDragDropHover() {
        pushTimerIndexPath?.invalidate()
        pushTimerIndexPath = nil
        pushCollectionView = nil
        pushIndexPath = nil
    }
}
