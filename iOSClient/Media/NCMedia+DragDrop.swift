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

extension NCMedia: UICollectionViewDropDelegate, UIEditMenuInteractionDelegate {
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
        let config = UIEditMenuConfiguration(identifier: nil, sourcePoint: location)
        let interaction = collectionView.interactions.first { $0 is UIEditMenuInteraction } as? UIEditMenuInteraction

        interaction?.presentEditMenu(with: config)
    }

    func editMenuInteraction(_ interaction: UIEditMenuInteraction, menuFor configuration: UIEditMenuConfiguration, suggestedActions: [UIMenuElement]) -> UIMenu? {
        let copy = UIAction(title: NSLocalizedString("_copy_", comment: ""), image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in
            self?.copyMenuFile(nil)
        }

        let move = UIAction(title: NSLocalizedString("_move_", comment: ""), image: UIImage(systemName: "folder")) { [weak self] _ in
            self?.moveMenuFile(nil)
        }

        return UIMenu(title: "", children: [copy, move])
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
