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
import NCCommunication

extension NCMedia {

    func toggleMenu() {

        var actions: [NCMenuAction] = []

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
                    title: NSLocalizedString(filterClassTypeImage ? "_media_viewimage_show_" : "_media_viewimage_hide_", comment: ""),
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
                    title: NSLocalizedString(filterClassTypeVideo ? "_media_viewvideo_show_" : "_media_viewvideo_hide_", comment: ""),
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

                        self.present(navigationController, animated: true, completion: nil)
                    }
                )
            )

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
                    action: { _ in
                        self.isEditMode = false
                        self.selectOcId.removeAll()
                        self.reloadDataThenPerform { }
                    }
                )
            )

            //
            // OPEN IN
            //
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_open_in_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "square.and.arrow.up"),
                    action: { _ in
                        self.isEditMode = false
                        NCFunctionCenter.shared.openActivityViewController(selectOcId: self.selectOcId)
                        self.selectOcId.removeAll()
                        self.reloadDataThenPerform { }
                    }
                )
            )

            //
            // SAVE TO PHOTO GALLERY
            //
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_save_selected_files_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "square.and.arrow.down"),
                    action: { _ in
                        self.isEditMode = false
                        for ocId in self.selectOcId {
                            if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                                if metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue {
                                    if let metadataMOV = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
                                        NCFunctionCenter.shared.saveLivePhoto(metadata: metadata, metadataMOV: metadataMOV)
                                    } else {
                                        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                                            NCFunctionCenter.shared.saveAlbum(metadata: metadata)
                                        } else {
                                            NCOperationQueue.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorSaveAlbum)
                                        }
                                    }
                                }
                            }
                        }
                        self.selectOcId.removeAll()
                        self.reloadDataThenPerform { }
                    }
                )
            )

            //
            // COPY - MOVE
            //
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_move_or_copy_selected_files_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "arrow.up.right.square"),
                    action: { _ in
                        self.isEditMode = false
                        var meradatasSelect = [tableMetadata]()
                        for ocId in self.selectOcId {
                            if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                                meradatasSelect.append(metadata)
                            }
                        }
                        if meradatasSelect.count > 0 {
                            NCFunctionCenter.shared.openSelectView(items: meradatasSelect, viewController: self)
                        }
                        self.selectOcId.removeAll()
                        self.reloadDataThenPerform { }
                    }
                )
            )

            //
            // COPY
            //
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_copy_file_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "doc.on.doc"),
                    action: { _ in
                        self.isEditMode = false
                        self.appDelegate.pasteboardOcIds.removeAll()
                        for ocId in self.selectOcId {
                            self.appDelegate.pasteboardOcIds.append(ocId)
                        }
                        NCFunctionCenter.shared.copyPasteboard()
                        self.selectOcId.removeAll()
                        self.reloadDataThenPerform { }
                    }
                )
            )

            //
            // DELETE
            //
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_delete_selected_files_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "trash"),
                    action: { _ in
                        self.isEditMode = false
                        for ocId in self.selectOcId {
                            if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                                NCNetworking.shared.deleteMetadata(metadata, onlyLocalCache: false) { errorCode, errorDescription in
                                    if errorCode != 0 {
                                        NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                                    }
                                }
                            }
                        }
                        self.selectOcId.removeAll()
                        self.reloadDataThenPerform { }
                    }
                )
            )
        }

        presentMenu(with: actions)
    }
}
