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

    func toggleMoreMenu(viewController: UIViewController, metadata: tableMetadata) {
        
        if let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(metadata.ocId) {
            
            let mainMenuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateViewController(withIdentifier: "NCMainMenuTableViewController") as! NCMainMenuTableViewController
            mainMenuViewController.actions = self.initMenuMore(viewController: viewController, metadata: metadata)

            let menuPanelController = NCMenuPanelController()
            menuPanelController.parentPresenter = viewController
            menuPanelController.delegate = mainMenuViewController
            menuPanelController.set(contentViewController: mainMenuViewController)
            menuPanelController.track(scrollView: mainMenuViewController.tableView)

            viewController.present(menuPanelController, animated: true, completion: nil)
        }
    }
    
    private func initMenuMore(viewController: UIViewController, metadata: tableMetadata) -> [NCMenuAction] {
        
        var actions = [NCMenuAction]()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let serverUrl = metadata.serverUrl+"/"+metadata.fileName
        let isFolderEncrypted = CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account, urlBase: metadata.urlBase)
        let serverUrlHome = NCUtility.shared.getHomeServer(urlBase: appDelegate.urlBase, account: appDelegate.account)
        var isOffline = false
        
        if metadata.directory {
            if let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, serverUrl)) {
                isOffline = directory.offline
            }
        } else {
            if let localFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
                isOffline = localFile.offline
            }
        }
            
        var iconHeader: UIImage!
        if let icon = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
            iconHeader = icon
        } else {
            if metadata.directory {
                if metadata.e2eEncrypted {
                    iconHeader = NCCollectionCommon.NCCollectionCommonImages.cellFolderEncryptedImage
                } else {
                    iconHeader = NCCollectionCommon.NCCollectionCommonImages.cellFolderImage
                }
            } else {
                iconHeader = UIImage(named: metadata.iconName)
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
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "favorite"), width: 50, height: 50, color: NCBrandColor.sharedInstance.yellowFavorite),
                action: { menuAction in
                    NCNetworking.shared.favoriteMetadata(metadata, urlBase: appDelegate.urlBase) { (errorCode, errorDescription) in
                        if errorCode != 0 {
                            NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                        }
                    }
                }
            )
        )
        
        //
        // DETAIL
        //
        if !isFolderEncrypted {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_details_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "details"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        NCMainCommon.shared.openShare(ViewController: self, metadata: metadata, indexPage: 0)
                    }
                )
            )
        }
        
        //
        // OPEN IN
        //
        if !metadata.directory && !NCBrandOptions.sharedInstance.disable_openin_file {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_open_in_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "openFile"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        NCMainCommon.shared.downloadOpen(metadata: metadata, selector: selectorOpenIn)
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
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "rename"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        let alertController = UIAlertController(title: NSLocalizedString("_rename_", comment: ""), message: nil, preferredStyle: .alert)
                        
                        alertController.addTextField { (textField) in
                            textField.text = metadata.fileNameView
                        }

                        let cancelAction = UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: nil)

                        let okAction = UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { action in
                            if let fileNameNew = alertController.textFields?.first?.text {
                                NCNetworking.shared.renameMetadata(metadata, fileNameNew: fileNameNew, urlBase: appDelegate.urlBase, viewController: self) { (errorCode, errorDescription) in
                                    if errorCode != 0 {
                                        NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                                    }
                                }
                            }
                        })

                        alertController.addAction(cancelAction)
                        alertController.addAction(okAction)

                        self.present(alertController, animated: true, completion: nil)
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
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "move"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        NCCollectionCommon.shared.openSelectView(viewController: viewController, array: [metadata])
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
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "offline"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        if isOffline {
                            if metadata.directory {
                                NCManageDatabase.sharedInstance.setDirectory(serverUrl: serverUrl, offline: false, account: self.appDelegate.account)
                            } else {
                                NCManageDatabase.sharedInstance.setLocalFile(ocId: metadata.ocId, offline: false)
                            }
                        } else {
                            if metadata.directory {
                                NCManageDatabase.sharedInstance.setDirectory(serverUrl: serverUrl, offline: true, account: self.appDelegate.account)
                                NCOperationQueue.shared.synchronizationMetadata(metadata, selector: selectorDownloadAllFile)
                            } else {
                                NCNetworking.shared.download(metadata: metadata, selector: selectorLoadOffline) { (_) in }
                                if let metadataLivePhoto = NCManageDatabase.sharedInstance.isLivePhoto(metadata: metadata) {
                                    NCNetworking.shared.download(metadata: metadataLivePhoto, selector: selectorLoadOffline) { (_) in }
                                }
                            }
                        }
                        self.reloadDataSource()
                    }
                )
            )
        }
        
        //
        // DELETE
        //
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_delete_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "trash"), width: 50, height: 50, color: .red),
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
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "lock"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        NCCommunication.shared.markE2EEFolder(fileId: metadata.fileId, delete: false) { (account, errorCode, errorDescription) in
                            if errorCode == 0 {
                                NCManageDatabase.sharedInstance.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, serverUrl))
                                NCManageDatabase.sharedInstance.setDirectory(serverUrl: serverUrl, serverUrlTo: nil, etag: nil, ocId: nil, fileId: nil, encrypted: true, richWorkspace: nil, account: metadata.account)
                                NCManageDatabase.sharedInstance.setMetadataEncrypted(ocId: metadata.ocId, encrypted: true)
                                
                                NotificationCenter.default.postOnMainThread(name: k_notificationCenter_changeStatusFolderE2EE, userInfo: ["serverUrl":metadata.serverUrl])
                            } else {
                                NCContentPresenter.shared.messageNotification(NSLocalizedString("_e2e_error_mark_folder_", comment: ""), description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: .error, errorCode: errorCode)
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
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "lock"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        NCCommunication.shared.markE2EEFolder(fileId: metadata.fileId, delete: true) { (account, errorCode, errorDescription) in
                            if errorCode == 0 {
                                NCManageDatabase.sharedInstance.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, serverUrl))
                                NCManageDatabase.sharedInstance.setDirectory(serverUrl: serverUrl, serverUrlTo: nil, etag: nil, ocId: nil, fileId: nil, encrypted: false, richWorkspace: nil, account: metadata.account)
                                NCManageDatabase.sharedInstance.setMetadataEncrypted(ocId: metadata.ocId, encrypted: false)
                                
                                NotificationCenter.default.postOnMainThread(name: k_notificationCenter_changeStatusFolderE2EE, userInfo: ["serverUrl":metadata.serverUrl])
                            } else {
                                NCContentPresenter.shared.messageNotification(NSLocalizedString("_e2e_error_delete_mark_folder_", comment: ""), description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: .error, errorCode: errorCode)
                            }
                        }
                    }
                )
            )
        }
        
        return actions
    }
    
    func toggleMoreSelect(viewController: UIViewController, selectOcId: [String]) {
        
        let mainMenuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateViewController(withIdentifier: "NCMainMenuTableViewController") as! NCMainMenuTableViewController
        mainMenuViewController.actions = self.initMenuSelect(viewController: viewController, selectOcId: selectOcId)

        let menuPanelController = NCMenuPanelController()
        menuPanelController.parentPresenter = viewController
        menuPanelController.delegate = mainMenuViewController
        menuPanelController.set(contentViewController: mainMenuViewController)
        menuPanelController.track(scrollView: mainMenuViewController.tableView)

        viewController.present(menuPanelController, animated: true, completion: nil)
    }
    
    private func initMenuSelect(viewController: UIViewController, selectOcId: [String]) -> [NCMenuAction] {
        var actions = [NCMenuAction]()
       
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_select_all_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "selectFull"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    self.collectionViewSelectAll()
                }
            )
        )
        
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_move_or_copy_selected_files_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "move"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    var meradatasSelect = [tableMetadata]()
                    for ocId in selectOcId {
                        if let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(ocId) {
                            meradatasSelect.append(metadata)
                        }
                    }
                    if meradatasSelect.count > 0 {
                        NCCollectionCommon.shared.openSelectView(viewController: viewController, array: meradatasSelect)
                    }
                    self.tapSelect(sender: self)
                }
            )
        )
        
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_delete_selected_files_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "trash"), width: 50, height: 50, color: .red),
                action: { menuAction in
                    let alertController = UIAlertController(title: "", message: NSLocalizedString("_want_delete_", comment: ""), preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_delete_", comment: ""), style: .default) { (action:UIAlertAction) in
                        for ocId in selectOcId {
                            if let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(ocId) {
                                NCOperationQueue.shared.delete(metadata: metadata, onlyLocal: false)
                            }
                        }
                        self.tapSelect(sender: self)
                    })
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_remove_local_file_", comment: ""), style: .default) { (action:UIAlertAction) in
                        for ocId in selectOcId {
                            if let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(ocId) {
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
        
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_save_selected_files_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "saveSelectedFiles"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    for ocId in selectOcId {
                        if let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(ocId) {
                            if metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video {
                                NCOperationQueue.shared.download(metadata: metadata, selector: selectorSaveAlbum, setFavorite: false)
                            }
                        }
                    }
                    self.tapSelect(sender: self)
                }
            )
        )
        
        return actions
    }
}

