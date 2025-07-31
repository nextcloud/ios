// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import UniformTypeIdentifiers
import NextcloudKit

// MARK: - Drag

extension NCMedia: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        if isEditMode {
            return NCDragDrop().performDrag(fileSelect: fileSelect)
        } else if let ocId = dataSource.getMetadata(indexPath: indexPath)?.ocId,
                  let metadata = database.getMetadataFromOcId(ocId) {
            return NCDragDrop().performDrag(metadata: metadata)
        }
        return []
    }
}

// MARK: - Drop

extension NCMedia: UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: UIImage.self) || session.hasItemsConforming(toTypeIdentifiers: [UTType.movie.identifier, global.metadataOcIdDataRepresentation])
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        DragDropHover.shared.cleanPushDragDropHover()
        DragDropHover.shared.sourceMetadatas = nil
        guard let tableAccount = database.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account)) else { return }
        let serverUrl = NCUtilityFileSystem().getHomeServer(session: session) + tableAccount.mediaPath

        if let metadatas = NCDragDrop().performDrop(collectionView, performDropWith: coordinator, serverUrl: serverUrl, isImageVideo: true, controller: self.controller) {
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

        listMenuItems.append(UIMenuItem(title: NSLocalizedString("_copy_", comment: ""), action: #selector(copyMenuFile(_:))))
        listMenuItems.append(UIMenuItem(title: NSLocalizedString("_move_", comment: ""), action: #selector(moveMenuFile(_:))))
        UIMenuController.shared.menuItems = listMenuItems
        UIMenuController.shared.showMenu(from: collectionView, rect: CGRect(x: location.x, y: location.y, width: 0, height: 0))
    }

    @objc func copyMenuFile(_ sender: Any?) {
        guard let sourceMetadatas = DragDropHover.shared.sourceMetadatas else { return }

        if let tableAccount = database.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account)) {
            let serverUrl = NCUtilityFileSystem().getHomeServer(session: session) + tableAccount.mediaPath
            NCDragDrop().copyFile(metadatas: sourceMetadatas, serverUrl: serverUrl)
        }
    }

    @objc func moveMenuFile(_ sender: Any?) {
        guard let sourceMetadatas = DragDropHover.shared.sourceMetadatas else { return }

        if let tableAccount = database.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account)) {
            let serverUrl = NCUtilityFileSystem().getHomeServer(session: session) + tableAccount.mediaPath
            NCDragDrop().moveFile(metadatas: sourceMetadatas, serverUrl: serverUrl)
        }
    }
}
