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
        var mediaCell: NCGridMediaCell?
        if let metadata = self.metadatas?[indexPath.row] {
            if let visibleCells = self.collectionView?.indexPathsForVisibleItems.compactMap({ self.collectionView?.cellForItem(at: $0) }) {
                for case let cell as NCGridMediaCell in visibleCells {
                    if cell.ocId == metadata.ocId {
                        mediaCell = cell
                    }
                }
            }
            if isEditMode {
                if let index = selectOcId.firstIndex(of: metadata.ocId) {
                    selectOcId.remove(at: index)
                    mediaCell?.selected(false)
                } else {
                    selectOcId.append(metadata.ocId)
                    mediaCell?.selected(true)

                }
                tabBarSelect.selectCount = selectOcId.count
            } else {
                // ACTIVE SERVERURL
                serverUrl = metadata.serverUrl
                if let metadatas = self.metadatas?.getArray() {
                    NCViewer().view(viewController: self, metadata: metadata, metadatas: metadatas, imageIcon: getImage(metadata: metadata))
                }
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let cell = collectionView.cellForItem(at: indexPath) as? NCGridMediaCell,
              let metadata = self.metadatas?[indexPath.row] else { return nil }
        let identifier = indexPath as NSCopying
        let image = cell.imageItem.image
        self.serverUrl = metadata.serverUrl

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
