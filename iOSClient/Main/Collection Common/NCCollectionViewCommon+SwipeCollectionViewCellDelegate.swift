//
//  NCCollectionViewCommon+SwipeCollectionViewCellDelegate.swift
//  Nextcloud
//
//  Created by Milen on 01.03.24.
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
import SwipeCellKit

extension NCCollectionViewCommon: SwipeCollectionViewCellDelegate {
    func collectionView(_ collectionView: UICollectionView, editActionsForItemAt indexPath: IndexPath, for orientation: SwipeCellKit.SwipeActionsOrientation) -> [SwipeCellKit.SwipeAction]? {
        guard orientation == .right, let metadata = self.dataSource.cellForItemAt(indexPath: indexPath) else { return nil }

        let scaleTransition = ScaleTransition(duration: 0.3, initialScale: 0.8, threshold: 0.8)

        // wait a fix for truncate the text .. ? ..
        let favoriteAction = SwipeAction(style: .default, title: NSLocalizedString(metadata.favorite ? "_favorite_short_" : "_favorite_short_", comment: "") ) { _, _ in
            NCNetworking.shared.favoriteMetadata(metadata) { error in
                if error != .success {
                    NCContentPresenter().showError(error: error)
                }
            }
        }
        favoriteAction.backgroundColor = NCBrandColor.shared.yellowFavorite
        favoriteAction.image = .init(systemName: metadata.favorite ? "star.slash.fill" : "star.fill")
        favoriteAction.transitionDelegate = scaleTransition
        favoriteAction.hidesWhenSelected = true

        var actions = [favoriteAction]

        let shareAction = SwipeAction(style: .default, title: NSLocalizedString("_share_", comment: "")) { _, _ in
            NCActionCenter.shared.openActivityViewController(selectedMetadata: [metadata])
        }
        shareAction.backgroundColor = .blue
        shareAction.image = .init(systemName: "square.and.arrow.up")
        shareAction.transitionDelegate = scaleTransition
        shareAction.hidesWhenSelected = true

        let deleteAction = SwipeAction(style: .destructive, title: NSLocalizedString("_delete_", comment: "")) { _, _ in
            let titleDelete: String

            if metadata.directory {
                titleDelete = NSLocalizedString("_delete_folder_", comment: "")
            } else {
                titleDelete = NSLocalizedString("_delete_file_", comment: "")
            }

            let message = NSLocalizedString("_want_delete_", comment: "") + "\n - " + metadata.fileNameView

            let alertController = UIAlertController.deleteFileOrFolder(titleString: titleDelete + "?", message: message, canDeleteServer: !metadata.lock, selectedMetadatas: [metadata], indexPaths: self.selectIndexPaths) { _ in }

            self.viewController.present(alertController, animated: true, completion: nil)
        }
        deleteAction.image = .init(systemName: "trash")
        deleteAction.style = .destructive
        deleteAction.transitionDelegate = scaleTransition
        deleteAction.hidesWhenSelected = true

        if !NCManageDatabase.shared.isMetadataShareOrMounted(metadata: metadata, metadataFolder: metadataFolder) {
            actions.insert(deleteAction, at: 0)
        }

        if metadata.canShare {
            actions.append(shareAction)
        }

        return actions
    }

    func collectionView(_ collectionView: UICollectionView, editActionsOptionsForItemAt indexPath: IndexPath, for orientation: SwipeActionsOrientation) -> SwipeOptions {
        var options = SwipeOptions()
        options.expansionStyle = .selection
        options.transitionStyle = .border
        options.backgroundColor = .clear
        return options
    }
}
