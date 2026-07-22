// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import RealmSwift

extension NCMedia: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        Task { @MainActor in
            guard let compactMetadata = dataSource.getCompactMetadata(indexPath: indexPath) else {
                return
            }

            if isEditMode {
                guard let cell = collectionView.cellForItem(at: indexPath) as? NCMediaCell else {
                    return
                }

                if let index = fileSelect.firstIndex(of: compactMetadata.ocId) {
                    fileSelect.remove(at: index)
                    cell.selected(
                        false,
                        color: NCBrandColor.shared.getElement(account: session.account)
                    )
                } else {
                    fileSelect.append(compactMetadata.ocId)
                    cell.selected(
                        true,
                        color: NCBrandColor.shared.getElement(account: session.account)
                    )
                }

                tabBarSelect.selectCount = fileSelect.count
                return
            }

            guard let metadata = await database.getMetadataFromOcIdAsync(compactMetadata.ocId),
                  dataSource.getCompactMetadata(indexPath: indexPath)?.ocId == compactMetadata.ocId else {
                return
            }

            let image = utility.getImage(
                ocId: metadata.ocId,
                etag: metadata.etag,
                ext: global.previewExt1024,
                userId: metadata.userId,
                urlBase: metadata.urlBase
            )

            var viewerTransitionSource: NCMediaViewerTransitionSource?

            if let cell = collectionView.cellForItem(at: indexPath) as? NCMediaCell,
               let imageView = cell.image,
               let transitionImage = imageView.image,
               let window = imageView.window {
                let sourceFrame = imageView.convert(
                    imageView.bounds,
                    to: window
                )

                viewerTransitionSource = NCMediaViewerTransitionSource(
                    image: transitionImage,
                    sourceFrame: sourceFrame,
                    cornerRadius: imageView.layer.cornerRadius
                )
            }

            let ocIds = dataSource.compactMetadatas.map(\.ocId)

            if let viewController = await NCViewer().getViewerController(
                metadata: metadata,
                ocIds: ocIds,
                image: image,
                delegate: self,
                viewerTransitionSource: viewerTransitionSource
            ) {
                viewController.view.backgroundColor = .clear
                navigationController?.pushViewController(
                    viewController,
                    animated: false
                )
            }
        }
    }

    /// Returns the transition source for a media item in the collection view.
    ///
    /// If the target cell is visible, the transition uses the real preview image view frame.
    /// If the target cell is not materialized yet, the transition falls back to the
    /// collection view layout attributes so the closing animation can still target
    /// the correct item position.
    ///
    /// - Parameter ocId: Nextcloud file identifier of the media item.
    /// - Returns: Transition source if the item can be resolved.
    func viewerTransitionSource(for ocId: String) -> NCMediaViewerTransitionSource? {
        guard let indexPath = self.dataSource.indexPath(forOcId: ocId),
              let window = collectionView.window else {
            return nil
        }

        collectionView.layoutIfNeeded()

        if collectionView.cellForItem(at: indexPath) == nil {
            collectionView.scrollToItem(
                at: indexPath,
                at: .centeredVertically,
                animated: false
            )

            collectionView.layoutIfNeeded()
        }

        if let cell = collectionView.cellForItem(at: indexPath) as? NCMediaCell,
           let imageView = cell.image,
           let image = imageView.image {
            let sourceFrame = imageView.convert(
                imageView.bounds,
                to: window
            )

            return NCMediaViewerTransitionSource(
                image: image,
                sourceFrame: sourceFrame,
                cornerRadius: imageView.layer.cornerRadius
            )
        }

        guard let attributes = collectionView.layoutAttributesForItem(at: indexPath) else {
            return nil
        }

        let sourceFrame = collectionView.convert(
            attributes.frame,
            to: window
        )

        return NCMediaViewerTransitionSource(
            image: UIImage(),
            sourceFrame: sourceFrame,
            cornerRadius: 6
        )
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let ocId = dataSource.getCompactMetadata(indexPath: indexPath)?.ocId,
              let metadata = database.getMetadataFromOcId(ocId)
        else {
            return nil
        }
        let identifier = indexPath as NSCopying
        let image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: global.previewExt1024, userId: metadata.userId, urlBase: metadata.urlBase)
        let sender = collectionView.cellForItem(at: indexPath) ?? collectionView

        return UIContextMenuConfiguration(identifier: identifier, previewProvider: {
            return NCViewerProviderContextMenu(metadata: metadata, image: image, sceneIdentifier: self.sceneIdentifier)
        }, actionProvider: { _ in
            let contextMenu = NCContextMenuMain(metadata: metadata.detachedCopy(), viewController: self, controller: self.controller, sender: sender)
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
