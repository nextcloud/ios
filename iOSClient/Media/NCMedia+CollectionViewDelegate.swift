// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import RealmSwift

extension NCMedia: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        Task {
            guard let metadata = dataSource.getMetadata(indexPath: indexPath),
                  let cell = collectionView.cellForItem(at: indexPath) as? NCMediaCell else { return }

            if isEditMode {
                if let index = fileSelect.firstIndex(of: metadata.ocId) {
                    fileSelect.remove(at: index)
                    cell.selected(false)
                } else {
                    fileSelect.append(metadata.ocId)
                    cell.selected(true)
                }
                tabBarSelect.selectCount = fileSelect.count
            } else if let metadata = await self.database.getMetadataFromOcIdAsync(metadata.ocId) {
                let image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: global.previewExt1024, userId: metadata.userId, urlBase: metadata.urlBase)
                let ocIds = dataSource.metadatas.map { $0.ocId }

                NCViewer().getViewerController(metadata: metadata, ocIds: ocIds, image: image, delegate: self) { vc in
                    guard let vc else {
                        return
                    }
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let ocId = dataSource.getMetadata(indexPath: indexPath)?.ocId,
              let metadata = database.getMetadataFromOcId(ocId)
        else {
            return nil
        }
        let identifier = indexPath as NSCopying
        let image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: global.previewExt1024, userId: metadata.userId, urlBase: metadata.urlBase)

        return UIContextMenuConfiguration(identifier: identifier, previewProvider: {
            return NCViewerProviderContextMenu(metadata: metadata, image: image, sceneIdentifier: self.sceneIdentifier)
        }, actionProvider: { _ in
            let contextMenu = NCContextMenu(metadata: metadata.detachedCopy(), viewController: self, sceneIdentifier: self.sceneIdentifier, image: image)
            return contextMenu.viewMenu()
        })
    }

    func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        animator.addCompletion {
            if let indexPath = configuration.identifier as? IndexPath {
                self.collectionView(collectionView, didSelectItemAt: indexPath)
            }
        }
    }
}
