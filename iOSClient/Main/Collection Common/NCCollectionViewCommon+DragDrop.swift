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
import JGProgressHUD

// MARK: - Drag

extension NCCollectionViewCommon: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        var metadatas: [tableMetadata] = []

        if isEditMode {
            for ocId in self.selectOcId {
                if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId), metadata.status == 0, !NCNetworkingDragDrop().isDirectoryE2EE(metadata: metadata) {
                    metadatas.append(metadata)
                }
            }
        } else {
            guard let metadata = dataSource.cellForItemAt(indexPath: indexPath), metadata.status == 0, !NCNetworkingDragDrop().isDirectoryE2EE(metadata: metadata) else { return [] }
            metadatas.append(metadata)
        }

        let dragItems = metadatas.map { metadata in
            let itemProvider = NSItemProvider()
            itemProvider.registerDataRepresentation(forTypeIdentifier: NCGlobal.shared.metadataOcIdDataRepresentation, visibility: .all) { completion in
                let data = metadata.ocId.data(using: .utf8)
                completion(data, nil)
                return nil
            }
            return UIDragItem(itemProvider: itemProvider)
        }

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
        return true
    }

    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        var destinationMetadata: tableMetadata?
        if let destinationIndexPath {
            destinationMetadata = dataSource.cellForItemAt(indexPath: destinationIndexPath)
        }
        DragDropHover.shared.destinationMetadata = destinationMetadata

        if let destinationMetadata {
            if NCNetworkingDragDrop().isDirectoryE2EE(metadata: destinationMetadata) {
                DragDropHover.shared.cleanPushDragDropHover()
                return UICollectionViewDropProposal(operation: .forbidden)
            }
            if !destinationMetadata.directory && serverUrl.isEmpty {
                DragDropHover.shared.cleanPushDragDropHover()
                return UICollectionViewDropProposal(operation: .forbidden)
            }
        } else {
            if serverUrl.isEmpty {
                DragDropHover.shared.cleanPushDragDropHover()
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
                    DragDropHover.shared.cleanPushDragDropHover()
                    self.pushMetadata(metadata)
                }
            }
        }

        return UICollectionViewDropProposal(operation: .copy)
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        var metadatas: [tableMetadata] = []
        DragDropHover.shared.cleanPushDragDropHover()
        DragDropHover.shared.sourceMetadatas = nil

        for item in coordinator.items {
            let semaphore = DispatchSemaphore(value: 0)
            let itemProvider = item.dragItem.itemProvider
            if itemProvider.hasItemConformingToTypeIdentifier(NCGlobal.shared.metadataOcIdDataRepresentation) {
                itemProvider.loadDataRepresentation(forTypeIdentifier: NCGlobal.shared.metadataOcIdDataRepresentation) { data, error in
                    if error == nil, let data, let ocId = String(data: data, encoding: .utf8), let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                        metadatas.append(metadata)
                    }
                    semaphore.signal()
                }
                semaphore.wait()
            }
        }

        // drop for metadataOcIdDataRepresentation
        if !metadatas.isEmpty {
            DragDropHover.shared.sourceMetadatas = metadatas
            self.openMenu(collectionView: collectionView, location: coordinator.session.location(in: collectionView))
        } else {
            // drop for url
            self.handleDrop(coordinator: coordinator)
        }
    }

    func collectionView(_ collectionView: UICollectionView, dropSessionDidExit session: UIDropSession) {
        DragDropHover.shared.cleanPushDragDropHover()
    }

    func collectionView(_ collectionView: UICollectionView, dropSessionDidEnd session: UIDropSession) {
        DragDropHover.shared.cleanPushDragDropHover()
    }

    // MARK: -

    private func openMenu(collectionView: UICollectionView, location: CGPoint) {
        var listMenuItems: [UIMenuItem] = []

        listMenuItems.append(UIMenuItem(title: NSLocalizedString("_copy_", comment: ""), action: #selector(copyMenuFile)))
        listMenuItems.append(UIMenuItem(title: NSLocalizedString("_move_", comment: ""), action: #selector(moveMenuFile)))
        UIMenuController.shared.menuItems = listMenuItems
        UIMenuController.shared.showMenu(from: collectionView, rect: CGRect(x: location.x, y: location.y, width: 0, height: 0))
    }

    @objc func copyMenuFile() {
        guard let sourceMetadatas = DragDropHover.shared.sourceMetadatas else { return }
        var serverUrl: String = self.serverUrl
        if let destinationMetadata = DragDropHover.shared.destinationMetadata, destinationMetadata.directory {
            serverUrl = destinationMetadata.serverUrl + "/" + destinationMetadata.fileName
        }

        NCNetworkingDragDrop().copyFile(metadatas: sourceMetadatas, serverUrl: serverUrl)
    }

    @objc func moveMenuFile() {
        guard let sourceMetadatas = DragDropHover.shared.sourceMetadatas else { return }
        var serverUrl: String = self.serverUrl
        if let destinationMetadata = DragDropHover.shared.destinationMetadata, destinationMetadata.directory {
            serverUrl = destinationMetadata.serverUrl + "/" + destinationMetadata.fileName
        }

        NCNetworkingDragDrop().moveFile(metadatas: sourceMetadatas, serverUrl: serverUrl)
    }

    private func handleDrop(coordinator: UICollectionViewDropCoordinator) {
        var serverUrl: String = self.serverUrl

        for dragItem in coordinator.session.items {
            dragItem.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.data.identifier) { url, error in
                if error == nil, let url {
                    if let destinationMetadata = DragDropHover.shared.destinationMetadata, destinationMetadata.directory {
                        serverUrl = destinationMetadata.serverUrl + "/" + destinationMetadata.fileName
                    }
                    NCNetworkingDragDrop().uploadFile(url: url, serverUrl: serverUrl)
                }
            }
        }
    }
}

// MARK: - Drop Interaction Delegate

extension NCCollectionViewCommon: UIDropInteractionDelegate { }
