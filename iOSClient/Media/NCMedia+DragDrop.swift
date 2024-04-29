//
//  NCMedia+DragDrop.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 21/04/24.
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

// MARK: - Drag

extension NCMedia: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        var metadatas: [tableMetadata] = []

        if isEditMode {
            for ocId in self.selectOcId {
                if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId), metadata.status == 0, !NCNetworkingDragDrop().isDirectoryE2EE(metadata: metadata) {
                    metadatas.append(metadata)
                }
            }
        } else {
            guard let metadata = self.metadatas?[indexPath.row], metadata.status == 0, !NCNetworkingDragDrop().isDirectoryE2EE(metadata: metadata) else { return [] }
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
}

// MARK: - Drop

extension NCMedia: UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: UIImage.self) || session.hasItemsConforming(toTypeIdentifiers: [UTType.movie.identifier, NCGlobal.shared.metadataOcIdDataRepresentation])
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        DragDropHover.shared.cleanPushDragDropHover()
        DragDropHover.shared.sourceMetadatas = nil
        guard let tableAccount = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", appDelegate.account)) else { return }
        let serverUrl = NCUtilityFileSystem().getHomeServer(urlBase: tableAccount.urlBase, userId: tableAccount.userId) + tableAccount.mediaPath

        if let metadatas = NCNetworkingDragDrop().performDrop(collectionView, performDropWith: coordinator, serverUrl: serverUrl) {
            DragDropHover.shared.sourceMetadatas = metadatas
            openMenu(collectionView: collectionView, location: coordinator.session.location(in: collectionView))
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
        guard let sourceMetadatas = DragDropHover.shared.sourceMetadatas,
              let tableAccount = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", appDelegate.account)) else { return }
        let serverUrl = NCUtilityFileSystem().getHomeServer(urlBase: tableAccount.urlBase, userId: tableAccount.userId) + tableAccount.mediaPath

        NCNetworkingDragDrop().copyFile(metadatas: sourceMetadatas, serverUrl: serverUrl)
    }

    @objc func moveMenuFile() {
        guard let sourceMetadatas = DragDropHover.shared.sourceMetadatas,
              let tableAccount = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", appDelegate.account)) else { return }
        let serverUrl = NCUtilityFileSystem().getHomeServer(urlBase: tableAccount.urlBase, userId: tableAccount.userId) + tableAccount.mediaPath

        NCNetworkingDragDrop().moveFile(metadatas: sourceMetadatas, serverUrl: serverUrl)
    }
}
