//
//  NCMedia+CollectionViewDelegate.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 16/07/24.
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
import RealmSwift

extension NCMedia: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
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
        } else if let metadata = database.getMetadataFromOcId(metadata.ocId) {
            let image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: global.previewExt1024)
            let ocIds = dataSource.metadatas.map { $0.ocId }

            NCViewer().view(viewController: self, metadata: metadata, ocIds: ocIds, image: image)
        }
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let ocId = dataSource.getMetadata(indexPath: indexPath)?.ocId,
              let metadata = database.getMetadataFromOcId(ocId)
        else {
            return nil
        }
        let identifier = indexPath as NSCopying
        let image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: global.previewExt1024)

        return UIContextMenuConfiguration(identifier: identifier, previewProvider: {
            return NCViewerProviderContextMenu(metadata: metadata, image: image)
        }, actionProvider: { _ in
            return NCContextMenu().viewMenu(ocId: metadata.ocId, viewController: self, image: image)
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
