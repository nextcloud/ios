// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit

// MARK: - Drag

extension NCCollectionViewCommon: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        if isEditMode {
            return NCDragDrop().performDrag(fileSelect: fileSelect)
        } else if let metadata = self.dataSource.getMetadata(indexPath: indexPath) {
            return NCDragDrop().performDrag(metadata: metadata)
        }
        return []
    }

    func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        let previewParameters = UIDragPreviewParameters()

        if isLayoutList,
            let cell = collectionView.cellForItem(at: indexPath) as? NCListCell {
            let width = (collectionView.frame.width / 3) * 2
            previewParameters.visiblePath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: width, height: cell.frame.height), cornerRadius: 10)
            return previewParameters
        } else if let cell = collectionView.cellForItem(at: indexPath) as? NCGridCell {
            previewParameters.visiblePath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: cell.frame.width, height: cell.frame.height - 40), cornerRadius: 10)
            return previewParameters
        } else if let cell = collectionView.cellForItem(at: indexPath) as? NCPhotoCell {
            previewParameters.visiblePath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: cell.frame.width, height: cell.frame.height), cornerRadius: 10)
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

        if let destinationIndexPath, let metadata = self.dataSource.getMetadata(indexPath: destinationIndexPath) {
            destinationMetadata = metadata
        }
        DragDropHover.shared.destinationMetadata = destinationMetadata

        if let destinationMetadata {
            if destinationMetadata.e2eEncrypted || destinationMetadata.isDirectoryE2EE {
                DragDropHover.shared.cleanPushDragDropHover()
                return UICollectionViewDropProposal(operation: .forbidden)
            }
            if !destinationMetadata.directory && serverUrl.isEmpty {
                DragDropHover.shared.cleanPushDragDropHover()
                return UICollectionViewDropProposal(operation: .forbidden)
            }
        } else {
            if serverUrl.isEmpty || NCUtilityFileSystem().isDirectoryE2EE(serverUrl: serverUrl, urlBase: self.session.urlBase, userId: self.session.userId, account: self.session.account) {
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
                   let metadata = self.dataSource.getMetadata(indexPath: destinationIndexPath),
                   metadata.directory {
                    DragDropHover.shared.cleanPushDragDropHover()
                    Task {
                        await self.pushMetadata(metadata)
                    }
                }
            }
        }
        return UICollectionViewDropProposal(operation: .copy)
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        DragDropHover.shared.cleanPushDragDropHover()
        DragDropHover.shared.sourceMetadatas = nil

        if let metadatas = NCDragDrop().performDrop(collectionView, performDropWith: coordinator, serverUrl: self.serverUrl, isImageVideo: false, controller: self.controller) {
            if let metadata = metadatas.first, metadata.account != self.session.account {
                DragDropHover.shared.sourceMetadatas = metadatas
                Task {
                    await NCDragDrop().transfers(windowScene: windowScene,
                                                 destination: serverUrl,
                                                 session: self.session)
                }
            } else {
                DragDropHover.shared.sourceMetadatas = metadatas
                openDragDropMenuItems(location: coordinator.session.location(in: collectionView))
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, dropSessionDidExit session: UIDropSession) {
        DragDropHover.shared.cleanPushDragDropHover()
    }

    func collectionView(_ collectionView: UICollectionView, dropSessionDidEnd session: UIDropSession) {
        DragDropHover.shared.cleanPushDragDropHover()
    }
}

// MARK: - Drop Interaction Delegate

extension NCCollectionViewCommon: UIDropInteractionDelegate { }
