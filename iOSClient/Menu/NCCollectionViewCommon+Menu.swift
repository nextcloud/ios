//
//  NCCollectionViewCommon+Menu.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 24.01.20.
//  Copyright © 2020 Philippe Weidmann. All rights reserved.
//  Copyright © 2020 Marino Faggiana All rights reserved.
//
//  Author Philippe Weidmann
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
import NCCommunication

extension NCCollectionViewCommon {

    func toggleMenu(viewController: UIViewController, metadata: tableMetadata, image: UIImage?) {
        
        let menuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateInitialViewController() as! NCMenu
        var actions = [NCMenuAction]()
        
        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(metadata.ocId) else { return }
        let serverUrl = metadata.serverUrl+"/"+metadata.fileName
        let isFolderEncrypted = CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account, urlBase: metadata.urlBase)
        let serverUrlHome = NCUtilityFileSystem.shared.getHomeServer(urlBase: appDelegate.urlBase, account: appDelegate.account)
        var isOffline = false
        
        var titleDelete = NSLocalizedString("_delete_", comment: "")
        if NCManageDatabase.shared.isMetadataShareOrMounted(metadata: metadata, metadataFolder: metadataFolder) {
            titleDelete = NSLocalizedString("_leave_share_", comment: "")
        } else if metadata.directory {
            titleDelete = NSLocalizedString("_delete_folder_", comment: "")
        } else {
            titleDelete = NSLocalizedString("_delete_file_", comment: "")
        }
        
        if let metadataFolder = metadataFolder {
            let isShare = metadata.permissions.contains(NCGlobal.shared.permissionShared) && !metadataFolder.permissions.contains(NCGlobal.shared.permissionShared)
            let isMounted = metadata.permissions.contains(NCGlobal.shared.permissionMounted) && !metadataFolder.permissions.contains(NCGlobal.shared.permissionMounted)
            if isShare || isMounted {
                titleDelete = NSLocalizedString("_leave_share_", comment: "")
            }
        }
               
        if metadata.directory {
            if let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, serverUrl)) {
                isOffline = directory.offline
            }
        } else {
            if let localFile = NCManageDatabase.shared.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
                isOffline = localFile.offline
            }
        }
            
        var iconHeader: UIImage!
        
        if image != nil {
            iconHeader = image!
        } else {
            if metadata.directory {
                iconHeader = NCCollectionCommon.images.folder
            } else {
                iconHeader = NCCollectionCommon.images.file
            }
        }
        
        actions.append(
            NCMenuAction(
                title: metadata.fileNameView,
                icon: iconHeader,
                action: nil
            )
        )

        //
        // FAVORITE
        //
        actions.append(
            NCMenuAction(
                title: metadata.favorite ? NSLocalizedString("_remove_favorites_", comment: "") : NSLocalizedString("_add_favorites_", comment: ""),
                icon: UIImage(named: "favorite")!.image(color: NCBrandColor.shared.yellowFavorite, size: 50),
                action: { menuAction in
                    NCNetworking.shared.favoriteMetadata(metadata, urlBase: self.appDelegate.urlBase) { (errorCode, errorDescription) in
                        if errorCode != 0 {
                            NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                        }
                    }
                }
            )
        )
        
        //
        // DETAIL
        //
        if !isFolderEncrypted && !appDelegate.disableSharesView {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_details_", comment: ""),
                    icon: NCCollectionCommon.shared.loadImage(named: "info"),
                    action: { menuAction in
                        NCNetworkingNotificationCenter.shared.openShare(ViewController: self, metadata: metadata, indexPage: 0)
                    }
                )
            )
        }
        
        //
        // OFFLINE
        //
        if !isFolderEncrypted {
            actions.append(
                NCMenuAction(
                    title: isOffline ? NSLocalizedString("_remove_available_offline_", comment: "") :  NSLocalizedString("_set_available_offline_", comment: ""),
                    icon: NCCollectionCommon.shared.loadImage(named: "tray.and.arrow.down"),
                    action: { menuAction in
                        if isOffline {
                            if metadata.directory {
                                NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, offline: false, account: self.appDelegate.account)
                            } else {
                                NCManageDatabase.shared.setLocalFile(ocId: metadata.ocId, offline: false)
                            }
                        } else {
                            if metadata.directory {
                                NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, offline: true, account: self.appDelegate.account)
                                NCOperationQueue.shared.synchronizationMetadata(metadata, selector: NCGlobal.shared.selectorDownloadAllFile)
                            } else {
                                NCNetworking.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorLoadOffline) { (_) in }
                                if let metadataLivePhoto = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
                                    NCNetworking.shared.download(metadata: metadataLivePhoto, selector: NCGlobal.shared.selectorLoadOffline) { (_) in }
                                }
                            }
                        }
                        self.reloadDataSource()
                    }
                )
            )
        }
        
        //
        // OPEN IN
        //
        if !metadata.directory && !NCBrandOptions.shared.disable_openin_file {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_open_in_", comment: ""),
                    icon: UIImage(named: "openFile")!.image(color: NCBrandColor.shared.icon, size: 50),
                    action: { menuAction in
                        NCNetworkingNotificationCenter.shared.downloadOpen(metadata: metadata, selector: NCGlobal.shared.selectorOpenIn)
                    }
                )
            )
        }
        
        //
        // PRINT
        //
        if !metadata.directory && (metadata.typeFile == NCGlobal.shared.metadataTypeFileImage || metadata.contentType == "application/pdf") {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_print_", comment: ""),
                    icon: NCCollectionCommon.shared.loadImage(named: "printer"),
                    action: { menuAction in
                        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                            NCCollectionCommon.shared.printDocument(metadata: metadata)
                        } else {
                            NCOperationQueue.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorPrint)
                        }
                    }
                )
            )
        }
        
        //
        // SAVE
        //
        if metadata.typeFile == NCGlobal.shared.metadataTypeFileImage || metadata.typeFile == NCGlobal.shared.metadataTypeFileVideo {
            var title: String = NSLocalizedString("_save_selected_files_", comment: "")
            var icon = UIImage(named: "saveSelectedFiles")!.image(color: NCBrandColor.shared.icon, size: 50)
            let metadataMOV = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata)
            if metadataMOV != nil {
                title = NSLocalizedString("_livephoto_save_", comment: "")
                icon = UIImage(named: "livePhoto")!.image(color: NCBrandColor.shared.icon, size: 50)
            }
            
            actions.append(
                NCMenuAction(
                    title: title,
                    icon: icon,
                    action: { menuAction in
                        if metadataMOV != nil {
                            NCCollectionCommon.shared.saveLivePhoto(metadata: metadata, metadataMOV: metadataMOV!)
                        } else {
                            if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                                NCCollectionCommon.shared.saveAlbum(metadata: metadata)
                            } else {
                                NCOperationQueue.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorSaveAlbum)
                            }
                        }
                    }
                )
            )
        }
        
        //
        // RENAME
        //
        if !(isFolderEncrypted && metadata.serverUrl == serverUrlHome) {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_rename_", comment: ""),
                    icon: NCCollectionCommon.shared.loadImage(named: "pencil"),
                    action: { menuAction in
                        
                        if let vcRename = UIStoryboard(name: "NCRenameFile", bundle: nil).instantiateInitialViewController() as? NCRenameFile {
                            
                            vcRename.metadata = metadata
                            vcRename.imagePreview = image

                            let popup = NCPopupViewController(contentController: vcRename, popupWidth: 300, popupHeight: 360)
                                                        
                            self.present(popup, animated: true)
                        }
                    }
                )
            )
        }
        
        //
        // COPY - MOVE
        //
        if !isFolderEncrypted && serverUrl != "" {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_move_or_copy_", comment: ""),
                    icon: UIImage(named: "move")!.image(color: NCBrandColor.shared.icon, size: 50),
                    action: { menuAction in
                        NCCollectionCommon.shared.openSelectView(items: [metadata], viewController: self)
                    }
                )
            )
        }
        
        //
        // COPY
        //
        if !metadata.directory {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_copy_file_", comment: ""),
                    icon: UIImage(named: "copy")!.image(color: NCBrandColor.shared.icon, size: 50),
                    action: { menuAction in
                        self.appDelegate.pasteboardOcIds = [metadata.ocId];
                        NCCollectionCommon.shared.copyPasteboard()
                    }
                )
            )
        }
        
        //
        // VIEW IN FOLDER
        //
        if layoutKey == NCGlobal.shared.layoutViewRecent && appDelegate.activeFileViewInFolder == nil {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_view_in_folder_", comment: ""),
                    icon: UIImage(named: "viewInFolder")!.image(color: NCBrandColor.shared.icon, size: 50),
                    action: { menuAction in
                        NCCollectionCommon.shared.openFileViewInFolder(serverUrl: metadata.serverUrl, fileName: metadata.fileName)
                    }
                )
            )
        }
        
        //
        // DELETE
        //
        actions.append(
            NCMenuAction(
                title: titleDelete,
                icon: NCCollectionCommon.shared.loadImage(named: "trash"),
                action: { menuAction in
                    let alertController = UIAlertController(title: "", message: NSLocalizedString("_want_delete_", comment: ""), preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_delete_", comment: ""), style: .default) { (action:UIAlertAction) in
                        NCOperationQueue.shared.delete(metadata: metadata, onlyLocal: false)
                    })
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_remove_local_file_", comment: ""), style: .default) { (action:UIAlertAction) in
                        NCOperationQueue.shared.delete(metadata: metadata, onlyLocal: true)
                    })
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_delete_", comment: ""), style: .default) { (action:UIAlertAction) in })
                    self.present(alertController, animated: true, completion:nil)
                }
            )
        )
        
        //
        // SET FOLDER E2EE
        //
        if !metadata.e2eEncrypted && metadata.directory && CCUtility.isEnd(toEndEnabled: appDelegate.account) && metadata.serverUrl == serverUrlHome {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_e2e_set_folder_encrypted_", comment: ""),
                    icon: UIImage(named: "lock")!.image(color: NCBrandColor.shared.icon, size: 50),
                    action: { menuAction in
                        NCCommunication.shared.markE2EEFolder(fileId: metadata.fileId, delete: false) { (account, errorCode, errorDescription) in
                            if errorCode == 0 {
                                NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, serverUrl))
                                NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, serverUrlTo: nil, etag: nil, ocId: nil, fileId: nil, encrypted: true, richWorkspace: nil, account: metadata.account)
                                NCManageDatabase.shared.setMetadataEncrypted(ocId: metadata.ocId, encrypted: true)
                                
                                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeStatusFolderE2EE, userInfo: ["serverUrl":metadata.serverUrl])
                            } else {
                                NCContentPresenter.shared.messageNotification(NSLocalizedString("_e2e_error_mark_folder_", comment: ""), description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: .error, errorCode: errorCode)
                            }
                        }
                    }
                )
            )
        }
        
        //
        // UNSET FOLDER E2EE
        //
        if metadata.e2eEncrypted && metadata.directory && CCUtility.isEnd(toEndEnabled: appDelegate.account) && metadata.serverUrl == serverUrlHome {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_e2e_remove_folder_encrypted_", comment: ""),
                    icon: UIImage(named: "lock")!.image(color: NCBrandColor.shared.icon, size: 50),
                    action: { menuAction in
                        NCCommunication.shared.markE2EEFolder(fileId: metadata.fileId, delete: true) { (account, errorCode, errorDescription) in
                            if errorCode == 0 {
                                NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, serverUrl))
                                NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, serverUrlTo: nil, etag: nil, ocId: nil, fileId: nil, encrypted: false, richWorkspace: nil, account: metadata.account)
                                NCManageDatabase.shared.setMetadataEncrypted(ocId: metadata.ocId, encrypted: false)
                                
                                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeStatusFolderE2EE, userInfo: ["serverUrl":metadata.serverUrl])
                            } else {
                                NCContentPresenter.shared.messageNotification(NSLocalizedString("_e2e_error_delete_mark_folder_", comment: ""), description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: .error, errorCode: errorCode)
                            }
                        }
                    }
                )
            )
        }
        
        menuViewController.actions = actions

        let menuPanelController = NCMenuPanelController()
        menuPanelController.parentPresenter = viewController
        menuPanelController.delegate = menuViewController
        menuPanelController.set(contentViewController: menuViewController)
        menuPanelController.track(scrollView: menuViewController.tableView)

        viewController.present(menuPanelController, animated: true, completion: nil)
    }
    
    func toggleMenuSelect(viewController: UIViewController, selectOcId: [String]) {
        
        let menuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateInitialViewController() as! NCMenu
        var actions = [NCMenuAction]()
       
        //
        // SELECT ALL
        //
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_select_all_", comment: ""),
                icon: UIImage(named: "selectFull")!.image(color: NCBrandColor.shared.icon, size: 50),
                action: { menuAction in
                    self.collectionViewSelectAll()
                }
            )
        )
        
        //
        // SAVE TO PHOTO GALLERY
        //
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_save_selected_files_", comment: ""),
                icon: UIImage(named: "saveSelectedFiles")!.image(color: NCBrandColor.shared.icon, size: 50),
                action: { menuAction in
                    for ocId in selectOcId {
                        if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                            if metadata.typeFile == NCGlobal.shared.metadataTypeFileImage || metadata.typeFile == NCGlobal.shared.metadataTypeFileVideo {
                                if let metadataMOV = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
                                    NCCollectionCommon.shared.saveLivePhoto(metadata: metadata, metadataMOV: metadataMOV)
                                } else {
                                    if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                                        NCCollectionCommon.shared.saveAlbum(metadata: metadata)
                                    } else {
                                        NCOperationQueue.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorSaveAlbum)
                                    }
                                }
                            }
                        }
                    }
                    self.tapSelect(sender: self)
                }
            )
        )
        
        //
        // COPY - MOVE
        //
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_move_or_copy_selected_files_", comment: ""),
                icon: UIImage(named: "move")!.image(color: NCBrandColor.shared.icon, size: 50),
                action: { menuAction in
                    var meradatasSelect = [tableMetadata]()
                    for ocId in selectOcId {
                        if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                            meradatasSelect.append(metadata)
                        }
                    }
                    if meradatasSelect.count > 0 {
                        NCCollectionCommon.shared.openSelectView(items: meradatasSelect, viewController: self)
                    }
                    self.tapSelect(sender: self)
                }
            )
        )
        
        //
        // COPY
        //
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_copy_file_", comment: ""),
                icon: UIImage(named: "copy")!.image(color: NCBrandColor.shared.icon, size: 50),
                action: { menuAction in
                    self.appDelegate.pasteboardOcIds.removeAll()
                    for ocId in selectOcId {
                        self.appDelegate.pasteboardOcIds.append(ocId)
                    }
                    NCCollectionCommon.shared.copyPasteboard()
                    self.tapSelect(sender: self)
                }
            )
        )
        
        //
        // DELETE
        //
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_delete_selected_files_", comment: ""),
                icon: NCCollectionCommon.shared.loadImage(named: "trash"),
                action: { menuAction in
                    let alertController = UIAlertController(title: "", message: NSLocalizedString("_want_delete_", comment: ""), preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_delete_", comment: ""), style: .default) { (action:UIAlertAction) in
                        for ocId in selectOcId {
                            if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                                NCOperationQueue.shared.delete(metadata: metadata, onlyLocal: false)
                            }
                        }
                        self.tapSelect(sender: self)
                    })
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_remove_local_file_", comment: ""), style: .default) { (action:UIAlertAction) in
                        for ocId in selectOcId {
                            if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                                NCOperationQueue.shared.delete(metadata: metadata, onlyLocal: true)
                            }
                        }
                        self.tapSelect(sender: self)
                    })
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_delete_", comment: ""), style: .default) { (action:UIAlertAction) in })
                    self.present(alertController, animated: true, completion:nil)
                }
            )
        )
        
        menuViewController.actions = actions

        let menuPanelController = NCMenuPanelController()
        menuPanelController.parentPresenter = viewController
        menuPanelController.delegate = menuViewController
        menuPanelController.set(contentViewController: menuViewController)
        menuPanelController.track(scrollView: menuViewController.tableView)

        viewController.present(menuPanelController, animated: true, completion: nil)
    }
}

