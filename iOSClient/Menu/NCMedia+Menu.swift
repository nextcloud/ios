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

import FloatingPanel

extension NCMedia {

    func toggleMenu() {
        
        let menuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateInitialViewController() as! NCMenu
        var actions: [NCMenuAction] = []

        if !isEditMode {
            if metadatas.count > 0 {
                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_select_", comment: ""),
                        icon: NCUtility.shared.loadImage(named: "checkmark.circle.fill"),
                        action: { menuAction in
                            self.isEditMode = true
                        }
                    )
                )
            }

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString(filterTypeFileImage ? "_media_viewimage_show_" : "_media_viewimage_hide_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "photo"),
                    selected: filterTypeFileImage,
                    on: true,
                    action: { menuAction in
                        self.filterTypeFileImage = !self.filterTypeFileImage
                        self.filterTypeFileVideo = false
                        self.reloadDataSource()
                    }
                )
            )

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString(filterTypeFileVideo ? "_media_viewvideo_show_" : "_media_viewvideo_hide_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "video"),
                    selected: filterTypeFileVideo,
                    on: true,
                    action: { menuAction in
                        self.filterTypeFileVideo = !self.filterTypeFileVideo
                        self.filterTypeFileImage = false
                        self.reloadDataSource()
                    }
                )
            )
            
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_select_media_folder_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "folder-search-outline"),
                    action: { menuAction in
                        let navigationController = UIStoryboard(name: "NCSelect", bundle: nil).instantiateInitialViewController() as! UINavigationController
                        let viewController = navigationController.topViewController as! NCSelect
                        
                        viewController.delegate = self
                        viewController.hideButtonCreateFolder = true
                        viewController.includeDirectoryE2EEncryption = false
                        viewController.includeImages = false
                        viewController.selectFile = false
                        viewController.titleButtonDone = NSLocalizedString("_select_", comment: "")
                        viewController.type = "mediaFolder"
                        
                        navigationController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
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
                    action: { menuAction in
                        CCUtility.setMediaSortDate("date")
                        self.reloadDataSource()
                    }
                )
            )
            
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_media_by_created_date_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "circle.grid.cross.down.fill"),
                    selected: CCUtility.getMediaSortDate() == "creationDate",
                    on: true,
                    action: { menuAction in
                        CCUtility.setMediaSortDate("creationDate")
                        self.reloadDataSource()
                    }
                )
            )
            
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_media_by_upload_date_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "circle.grid.cross.right.fill"),
                    selected: CCUtility.getMediaSortDate() == "uploadDate",
                    on: true,
                    action: { menuAction in
                        CCUtility.setMediaSortDate("uploadDate")
                        self.reloadDataSource()
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
                    action: { menuAction in
                        self.isEditMode = false
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
                    action: { menuAction in
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
                    action: { menuAction in
                        self.isEditMode = false
                        for ocId in self.selectOcId {
                            if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                                NCNetworking.shared.deleteMetadata(metadata, account: self.appDelegate.account, urlBase: self.appDelegate.urlBase, onlyLocal: false) { (errorCode, errorDescription) in
                                    if errorCode != 0 {
                                        NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                                    }
                                }
                            }
                        }
                        self.selectOcId.removeAll()
                    }
                )
            )
        }

        menuViewController.actions = actions
        let menuPanelController = NCMenuPanelController()
        menuPanelController.parentPresenter = self
        menuPanelController.delegate = menuViewController
        menuPanelController.set(contentViewController: menuViewController)
        menuPanelController.track(scrollView: menuViewController.tableView)

        self.present(menuPanelController, animated: true, completion: nil)
    }
}

