//
//  NCNetworkingDragDrop.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 27/04/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import NextcloudKit

class NCNetworkingDragDrop: NSObject {
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    let utilityFileSystem = NCUtilityFileSystem()

    func performDrop(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator, serverUrl: String) -> [tableMetadata]? {
        var serverUrl = serverUrl
        var metadatas: [tableMetadata] = []
        DragDropHover.shared.cleanPushDragDropHover()
        DragDropHover.shared.sourceMetadatas = nil

        for item in coordinator.session.items {
            if item.itemProvider.hasItemConformingToTypeIdentifier(NCGlobal.shared.metadataOcIdDataRepresentation) {
                let semaphore = DispatchSemaphore(value: 0)
                item.itemProvider.loadDataRepresentation(forTypeIdentifier: NCGlobal.shared.metadataOcIdDataRepresentation) { data, error in
                    if error == nil, let data, let ocId = String(data: data, encoding: .utf8),
                       let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                        metadatas.append(metadata)
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
                        NCNetworkingDragDrop().uploadFile(url: url, serverUrl: serverUrl)
                    }
                }
            }
        }

        if metadatas.isEmpty {
            return nil
        } else {
            return metadatas
        }
    }

    func uploadFile(url: URL, serverUrl: String) {
        do {
            let data = try Data(contentsOf: url)
            Task {
                let ocId = NSUUID().uuidString
                let fileName = await NCNetworking.shared.createFileName(fileNameBase: url.lastPathComponent, account: appDelegate.account, serverUrl: serverUrl)
                let fileNamePath = utilityFileSystem.getDirectoryProviderStorageOcId(ocId, fileNameView: fileName)

                try data.write(to: URL(fileURLWithPath: fileNamePath))
                let metadataForUpload = await NCManageDatabase.shared.createMetadata(account: appDelegate.account, user: appDelegate.user, userId: appDelegate.userId, fileName: fileName, fileNameView: fileName, ocId: ocId, serverUrl: serverUrl, urlBase: self.appDelegate.urlBase, url: "", contentType: "")
                metadataForUpload.session = NCNetworking.shared.sessionUploadBackground
                metadataForUpload.sessionSelector = NCGlobal.shared.selectorUploadFile
                metadataForUpload.size = utilityFileSystem.getFileSize(filePath: fileNamePath)
                metadataForUpload.status = NCGlobal.shared.metadataStatusWaitUpload
                metadataForUpload.sessionDate = Date()

                NCManageDatabase.shared.addMetadata(metadataForUpload)
            }
        } catch {
            NCContentPresenter().showError(error: NKError(error: error))
            return
        }
    }

    func copyFile(metadatas: [tableMetadata], serverUrl: String) {
        Task {
            let error = NKError()
            var ocId: [String] = []
            for metadata in metadatas where error == .success {
                let error = await NCNetworking.shared.copyMetadata(metadata, serverUrlTo: serverUrl, overwrite: false)
                if error == .success {
                    ocId.append(metadata.ocId)
                }
            }
            if error != .success {
                NCContentPresenter().showError(error: error)
            }
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterCopyFile, userInfo: ["ocId": ocId, "error": error, "dragdrop": true])
        }
    }

    func moveFile(metadatas: [tableMetadata], serverUrl: String) {
        Task {
            var error = NKError()
            var ocId: [String] = []
            for metadata in metadatas where error == .success {
                error = await NCNetworking.shared.moveMetadata(metadata, serverUrlTo: serverUrl, overwrite: false)
                if error == .success {
                    ocId.append(metadata.ocId)
                }
            }
            if error != .success {
                NCContentPresenter().showError(error: error)
            }
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterMoveFile, userInfo: ["ocId": ocId, "error": error, "dragdrop": true])
        }
    }

    func isDirectoryE2EE(metadata: tableMetadata) -> Bool {
        if !metadata.directory { return false }
        return utilityFileSystem.isDirectoryE2EE(account: metadata.account, urlBase: metadata.urlBase, userId: metadata.userId, serverUrl: metadata.serverUrl + "/" + metadata.fileName)
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
