//
//  NCCollectionViewCommon+DragDrop.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 19/04/24.
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

import Foundation
import NextcloudKit

// MARK: - Drag

extension NCCollectionViewCommon: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        var dragItems: [UIDragItem] = []
        var metadatas: [tableMetadata] = []

        if isEditMode {
            for ocId in self.selectOcId {
                if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                    metadatas.append(metadata)
                    dragItems.append(UIDragItem(itemProvider: NSItemProvider(object: metadata.ocId as NSString)))
                }
            }
        } else {
            guard let metadata = dataSource.cellForItemAt(indexPath: indexPath), metadata.status == 0,
                  !isDirectoryE2EE(metadata: metadata) else { return [] }
            metadatas.append(metadata)
            dragItems.append(UIDragItem(itemProvider: NSItemProvider(object: metadata.ocId as NSString)))
        }

        DragDropHover.shared.sourceServerUrl = self.serverUrl
        DragDropHover.shared.sourceMetadatas = metadatas
        return dragItems
    }

    func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        let previewParameters = UIDragPreviewParameters()

        if layoutForView?.layout == NCGlobal.shared.layoutList, let cell = collectionView.cellForItem(at: indexPath) as? NCListCell {
            let width = (collectionView.frame.width / 3) * 2
            previewParameters.visiblePath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: width, height: cell.frame.height), cornerRadius: 10)
            return previewParameters
        } else if let cell = collectionView.cellForItem(at: indexPath) as? NCGridCell {
            previewParameters.visiblePath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: cell.frame.width, height: cell.frame.height - 40), cornerRadius: 10)
            return previewParameters
        }

        return nil
    }
}

// MARK: - Drop

extension NCCollectionViewCommon: UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        if session.canLoadObjects(ofClass: NSString.self) {
            return true
        }
        return false
    }

    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        var destinationMetadata: tableMetadata?
        if let destinationIndexPath {
            destinationMetadata = dataSource.cellForItemAt(indexPath: destinationIndexPath)
        }

        if let destinationMetadata {
            if isDirectoryE2EE(metadata: destinationMetadata) { //|| destinationMetadata.ocId == DragDropHover.shared.sourceMetadata?.ocId {
                cleanPushDragDropHover()
                return UICollectionViewDropProposal(operation: .forbidden)
            }
            if !destinationMetadata.directory && (DragDropHover.shared.sourceServerUrl == self.serverUrl || serverUrl.isEmpty) {
                cleanPushDragDropHover()
                return UICollectionViewDropProposal(operation: .forbidden)
            }
        } else {
            if DragDropHover.shared.sourceServerUrl == serverUrl || serverUrl.isEmpty {
                cleanPushDragDropHover()
                return UICollectionViewDropProposal(operation: .forbidden)
            }
        }

        // DIRECTORY - Push Metadata
        if DragDropHover.shared.pushIndexPath != destinationIndexPath || DragDropHover.shared.pushCollectionView != collectionView {
            DragDropHover.shared.pushIndexPath = destinationIndexPath
            DragDropHover.shared.pushCollectionView = collectionView
            DragDropHover.shared.pushTimerIndexPath?.invalidate()
            DragDropHover.shared.pushTimerIndexPath = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
                guard let self else { return }
                if let destinationIndexPath,
                   DragDropHover.shared.pushIndexPath == destinationIndexPath,
                   DragDropHover.shared.pushCollectionView == collectionView,
                   let metadata = self.dataSource.cellForItemAt(indexPath: destinationIndexPath),
                   metadata.directory {
                    self.cleanPushDragDropHover()
                    self.pushMetadata(metadata)
                }
            }
        }

        return UICollectionViewDropProposal(operation: .copy)
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        cleanPushDragDropHover()
        var destinationMetadata: tableMetadata?
        if let destinationIndexPath = coordinator.destinationIndexPath {
            destinationMetadata = dataSource.cellForItemAt(indexPath: destinationIndexPath)
        }

        if let sourceMetadatas = DragDropHover.shared.sourceMetadatas {
            self.openMenu(collectionView: collectionView, location: coordinator.session.location(in: collectionView), sourceMetadatas: sourceMetadatas, destinationMetadata: destinationMetadata)
        } else {
            self.handleDrop(coordinator: coordinator, destinationMetadata: destinationMetadata)
        }
    }

    func collectionView(_ collectionView: UICollectionView, dropSessionDidExit session: UIDropSession) {
        cleanPushDragDropHover()
    }

    func collectionView(_ collectionView: UICollectionView, dropSessionDidEnd session: UIDropSession) {
        cleanPushDragDropHover()

        DragDropHover.shared.sourceServerUrl = nil
        DragDropHover.shared.sourceMetadatas = nil
    }

    // MARK: -

    private func handleDrop(coordinator: UICollectionViewDropCoordinator, destinationMetadata: tableMetadata?) {
        var serverUrl: String = self.serverUrl

        for dragItem in coordinator.session.items {
            dragItem.itemProvider.loadFileRepresentation(forTypeIdentifier: kUTTypeData as String) { url, error in
                if let error {
                    NCContentPresenter().showError(error: NKError(error: error))
                    return
                }
                if let url = url {
                    do {
                        let data = try Data(contentsOf: url)
                        Task {
                            if let destinationMetadata, destinationMetadata.directory {
                                serverUrl = destinationMetadata.serverUrl + "/" + destinationMetadata.fileName
                            }
                            let ocId = NSUUID().uuidString
                            let fileName = await NCNetworking.shared.createFileName(fileNameBase: url.lastPathComponent, account: self.appDelegate.account, serverUrl: serverUrl)
                            let fileNamePath = self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId, fileNameView: fileName)

                            try data.write(to: URL(fileURLWithPath: fileNamePath))
                            let metadataForUpload = NCManageDatabase.shared.createMetadata(account: self.appDelegate.account, user: self.appDelegate.user, userId: self.appDelegate.userId, fileName: fileName, fileNameView: fileName, ocId: ocId, serverUrl: serverUrl, urlBase: self.appDelegate.urlBase, url: "", contentType: "")
                            metadataForUpload.session = NCNetworking.shared.sessionUploadBackground
                            metadataForUpload.sessionSelector = NCGlobal.shared.selectorUploadFile
                            metadataForUpload.size = self.utilityFileSystem.getFileSize(filePath: fileNamePath)
                            metadataForUpload.status = NCGlobal.shared.metadataStatusWaitUpload
                            metadataForUpload.sessionDate = Date()

                            NCManageDatabase.shared.addMetadata(metadataForUpload)
                        }
                    } catch {
                        NCContentPresenter().showError(error: NKError(error: error))
                        return
                    }
                }
            }
        }
    }

    private func openMenu(collectionView: UICollectionView, location: CGPoint, sourceMetadatas: [tableMetadata], destinationMetadata: tableMetadata?) {
        var listMenuItems: [UIMenuItem] = []
        listMenuItems.append(DragDropHoverMenuItem(title: NSLocalizedString("_copy_", comment: ""), action: #selector(copyMenuFile), sourceMetadatas: sourceMetadatas, destinationMetadata: destinationMetadata))
        listMenuItems.append(DragDropHoverMenuItem(title: NSLocalizedString("_move_", comment: ""), action: #selector(moveMenuFile), sourceMetadatas: sourceMetadatas, destinationMetadata: destinationMetadata))
        UIMenuController.shared.menuItems = listMenuItems
        UIMenuController.shared.showMenu(from: collectionView, rect: CGRect(x: location.x, y: location.y, width: 0, height: 0))
    }

    @objc func copyMenuFile(sourceMetadatas: [tableMetadata], destinationMetadata: tableMetadata?) {
        let serverUrl: String?
        if let destinationMetadata, destinationMetadata.directory {
            serverUrl = destinationMetadata.serverUrl + "/" + destinationMetadata.fileName
        } else {
            serverUrl = self.serverUrl
        }
        guard let serverUrl else { return }
        Task {
            for metadata in sourceMetadatas {
                let error = await NCNetworking.shared.copyMetadata(metadata, serverUrlTo: serverUrl, overwrite: false)
                if error != .success {
                    NCContentPresenter().showError(error: error)
                } else {
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSourceNetwork, userInfo: ["withQueryDB": true])
                }
            }
        }
    }

    @objc func moveMenuFile(sourceMetadatas: [tableMetadata], destinationMetadata: tableMetadata?) {
        let serverUrl: String?
        if let destinationMetadata, destinationMetadata.directory {
            serverUrl = destinationMetadata.serverUrl + "/" + destinationMetadata.fileName
        } else {
            serverUrl = self.serverUrl
        }
        guard let serverUrl else { return }
        Task {
            for metadata in sourceMetadatas {
                let error = await NCNetworking.shared.moveMetadata(metadata, serverUrlTo: serverUrl, overwrite: false)
                if error != .success {
                    NCContentPresenter().showError(error: error)
                } else {
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSourceNetwork, userInfo: ["withQueryDB": true])
                }
            }
        }
    }

    private func cleanPushDragDropHover() {
        DragDropHover.shared.pushTimerIndexPath?.invalidate()
        DragDropHover.shared.pushTimerIndexPath = nil
        DragDropHover.shared.pushCollectionView = nil
        DragDropHover.shared.pushIndexPath = nil
    }

    private func isDirectoryE2EE(metadata: tableMetadata) -> Bool {
        if !metadata.directory { return false }
        return NCUtilityFileSystem().isDirectoryE2EE(account: metadata.account, urlBase: metadata.urlBase, userId: metadata.userId, serverUrl: metadata.serverUrl + "/" + metadata.fileName)
    }
}

// MARK: - Drop Interaction Delegate

extension NCCollectionViewCommon: UIDropInteractionDelegate { }

// MARK: -

class DragDropHover {
    static let shared = DragDropHover()

    var pushTimerIndexPath: Timer?
    var pushCollectionView: UICollectionView?
    var pushIndexPath: IndexPath?

    var sourceServerUrl: String?
    var sourceMetadatas: [tableMetadata]?
}

// MARK: -

class DragDropHoverMenuItem: UIMenuItem {
    var sourceMetadatas: [tableMetadata]?
    var destinationMetadata: tableMetadata?

    convenience init(title: String, action: Selector, sourceMetadatas: [tableMetadata], destinationMetadata: tableMetadata?) {
        self.init(title: title, action: action)

        self.sourceMetadatas = sourceMetadatas
        self.destinationMetadata = destinationMetadata
    }
}
