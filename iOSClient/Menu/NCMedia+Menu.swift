//
//  NCMedia+Menu.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 03/03/2021.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
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
import FloatingPanel
import NextcloudKit

extension NCMedia {
    func tapSelect() {
        self.isEditMode = false
        self.selectOcId.removeAll()
        self.selectIndexPath.removeAll()
        self.reloadDataThenPerform { }
    }

    func toggleMenu() {

        var actions: [NCMenuAction] = []

        defer { presentMenu(with: actions) }

        if !isEditMode {
            if metadatas.count > 0 {
                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_select_", comment: ""),
                        icon: NCUtility.shared.loadImage(named: "checkmark.circle.fill"),
                        action: { _ in
                            self.isEditMode = true
                        }
                    )
                )
            }

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_media_viewimage_hide_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "photo"),
                    selected: filterClassTypeImage,
                    on: true,
                    action: { _ in
                        self.filterClassTypeImage = !self.filterClassTypeImage
                        self.filterClassTypeVideo = false
                        self.reloadDataSourceWithCompletion { _ in }
                    }
                )
            )

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_media_viewvideo_hide_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "video"),
                    selected: filterClassTypeVideo,
                    on: true,
                    action: { _ in
                        self.filterClassTypeVideo = !self.filterClassTypeVideo
                        self.filterClassTypeImage = false
                        self.reloadDataSourceWithCompletion { _ in }
                    }
                )
            )

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_select_media_folder_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "folder"),
                    action: { _ in
                        let navigationController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateInitialViewController() as! UINavigationController
                        let viewController = navigationController.topViewController as! NCSelect

                        viewController.delegate = self
                        viewController.typeOfCommandView = .select
                        viewController.type = "mediaFolder"
                        viewController.selectIndexPath = self.selectIndexPath

                        self.present(navigationController, animated: true, completion: nil)
                    }
                )
            )

            actions.append(.seperator(order: 0))

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_play_from_files_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "play.circle"),
                    action: { _ in
                        if let tabBarController =  self.appDelegate.window?.rootViewController as? UITabBarController {
                            self.documentPickerViewController = NCDocumentPickerViewController(tabBarController: tabBarController, isViewerMedia: true, allowsMultipleSelection: false, viewController: self)
                        }
                    }
                )
            )

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_play_from_url_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "network"),
                    action: { _ in

                        let alert = UIAlertController(title: NSLocalizedString("_valid_video_url_", comment: ""), message: nil, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: nil))

                        alert.addTextField(configurationHandler: { textField in
                            textField.placeholder = "http://myserver.com/movie.mkv"
                        })

                        alert.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in
                            guard let stringUrl = alert.textFields?.first?.text, !stringUrl.isEmpty, let url = URL(string: stringUrl) else { return }
                            let fileName = url.lastPathComponent
                            let metadata = NCManageDatabase.shared.createMetadata(account: self.appDelegate.account, user: self.appDelegate.user, userId: self.appDelegate.userId, fileName: fileName, fileNameView: fileName, ocId: NSUUID().uuidString, serverUrl: "", urlBase: self.appDelegate.urlBase, url: stringUrl, contentType: "")
                            NCManageDatabase.shared.addMetadata(metadata)
                            NCViewer.shared.view(viewController: self, metadata: metadata, metadatas: [metadata], imageIcon: nil)
                        }))

                        self.present(alert, animated: true)

                    }
                )
            )

            actions.append(.seperator(order: 0))

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_media_by_modified_date_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "circle.grid.cross.up.fill"),
                    selected: CCUtility.getMediaSortDate() == "date",
                    on: true,
                    action: { _ in
                        CCUtility.setMediaSortDate("date")
                        self.reloadDataSourceWithCompletion { _ in }
                    }
                )
            )

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_media_by_created_date_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "circle.grid.cross.down.fill"),
                    selected: CCUtility.getMediaSortDate() == "creationDate",
                    on: true,
                    action: { _ in
                        CCUtility.setMediaSortDate("creationDate")
                        self.reloadDataSourceWithCompletion { _ in }
                    }
                )
            )

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_media_by_upload_date_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "circle.grid.cross.right.fill"),
                    selected: CCUtility.getMediaSortDate() == "uploadDate",
                    on: true,
                    action: { _ in
                        CCUtility.setMediaSortDate("uploadDate")
                        self.reloadDataSourceWithCompletion { _ in }
                    }
                )
            )

        } else {

            //
            // CANCEL
            //
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_cancel_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "xmark"),
                    action: { _ in self.tapSelect() }
                )
            )

            guard !selectOcId.isEmpty else { return }
            let selectedMetadatas = selectOcId.compactMap(NCManageDatabase.shared.getMetadataFromOcId)

            //
            // OPEN IN
            //
            actions.append(.openInAction(selectedMetadatas: selectedMetadatas, viewController: self, completion: tapSelect))

            //
            // SAVE TO PHOTO GALLERY
            //
            actions.append(.saveMediaAction(selectedMediaMetadatas: selectedMetadatas, completion: tapSelect))

            //
            // COPY - MOVE
            //
            actions.append(.moveOrCopyAction(selectedMetadatas: selectedMetadatas, indexPath: selectIndexPath, completion: tapSelect))

            //
            // COPY
            //
            actions.append(.copyAction(selectOcId: selectOcId, hudView: self.view, completion: tapSelect))

            //
            // DELETE
            // can't delete from cache because is needed for NCMedia view, and if locked can't delete from server either.
            if !selectedMetadatas.contains(where: { $0.lock && $0.lockOwner != appDelegate.userId }) {
                actions.append(.deleteAction(selectedMetadatas: selectedMetadatas, indexPath: selectIndexPath, metadataFolder: nil, viewController: self, completion: tapSelect))
            }
        }
    }
}
