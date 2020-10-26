//
//  NCViewer.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 07/02/2020.
//  Copyright © 2020 Marino Faggiana All rights reserved.
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
import NCCommunication

extension NCViewer {

    @objc func toggleMoreMenu(viewController: UIViewController, metadata: tableMetadata) {
        
        let mainMenuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateViewController(withIdentifier: "NCMainMenuTableViewController") as! NCMainMenuTableViewController
        
        mainMenuViewController.actions = self.initMoreMenu(viewController: viewController, metadata: metadata)
        
        let menuPanelController = NCMenuPanelController()
        menuPanelController.parentPresenter = viewController
        menuPanelController.delegate = mainMenuViewController
        menuPanelController.set(contentViewController: mainMenuViewController)
        menuPanelController.track(scrollView: mainMenuViewController.tableView)

        viewController.present(menuPanelController, animated: true, completion: nil)
    }
    
    private func initMoreMenu(viewController: UIViewController, metadata: tableMetadata) -> [NCMenuAction] {
        
        var actions = [NCMenuAction]()
        var titleFavorite = NSLocalizedString("_add_favorites_", comment: "")
        if metadata.favorite { titleFavorite = NSLocalizedString("_remove_favorites_", comment: "") }
        let localFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
        
        var titleOffline = ""
        if (localFile == nil || localFile!.offline == false) {
            titleOffline = NSLocalizedString("_set_available_offline_", comment: "")
        } else {
            titleOffline = NSLocalizedString("_remove_available_offline_", comment: "")
        }
        
        var titleDelete = NSLocalizedString("_delete_", comment: "")
        if NCManageDatabase.sharedInstance.isMetadataShareOrMounted(metadata: metadata, metadataFolder: nil) {
            titleDelete = NSLocalizedString("_leave_share_", comment: "")
        } else if metadata.directory {
            titleDelete = NSLocalizedString("_delete_folder_", comment: "")
        } else {
            titleDelete = NSLocalizedString("_delete_file_", comment: "")
        }
        
        //
        // FAVORITE
        //
        actions.append(
            NCMenuAction(
                title: titleFavorite,
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "favorite"), width: 50, height: 50, color: NCBrandColor.sharedInstance.yellowFavorite),
                action: { menuAction in
                    NCNetworking.shared.favoriteMetadata(metadata, urlBase: self.appDelegate.urlBase) { (errorCode, errorDescription) in
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
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_details_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "details"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    NCNetworkingNotificationCenter.shared.openShare(ViewController: viewController, metadata: metadata, indexPage: 0)
                }
            )
        )
        
        //
        // OPEN IN
        //
        if metadata.session == "" {
            actions.append(
                NCMenuAction(title: NSLocalizedString("_open_in_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "openFile"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        NCNetworkingNotificationCenter.shared.downloadOpen(metadata: metadata, selector: selectorOpenIn)
                    }
                )
            )
        }
        
        //
        // RENAME
        //
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_rename_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "rename"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    let alertController = UIAlertController(title: NSLocalizedString("_rename_", comment: ""), message: nil, preferredStyle: .alert)

                    alertController.addTextField { (textField) in textField.text = metadata.fileNameView }
                    let cancelAction = UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: nil)
                    let okAction = UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { action in
                        let fileNameNew = alertController.textFields![0].text
                        NCNetworking.shared.renameMetadata(metadata, fileNameNew: fileNameNew!, urlBase: self.appDelegate.urlBase, viewController: viewController) { (errorCode, errorDescription) in
                            if errorCode != 0 {
                                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                            }
                        }
                    })
                    alertController.addAction(cancelAction)
                    alertController.addAction(okAction)

                    viewController.present(alertController, animated: true, completion: nil)
                }
            )
        )
        
        //
        // COPY - MOVE
        //
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_move_or_copy_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "move"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    
                    let storyboard = UIStoryboard(name: "NCSelect", bundle: nil)
                    let navigationController = storyboard.instantiateInitialViewController() as! UINavigationController
                    let viewController = navigationController.topViewController as! NCSelect
                    
                    viewController.delegate = NCViewer.shared
                    viewController.hideButtonCreateFolder = false
                    viewController.selectFile = false
                    viewController.includeDirectoryE2EEncryption = false
                    viewController.includeImages = false
                    viewController.type = ""
                    viewController.titleButtonDone = NSLocalizedString("_move_", comment: "")
                    viewController.titleButtonDone1 = NSLocalizedString("_copy_", comment: "")
                    viewController.isButtonDone1Hide = false
                    viewController.isOverwriteHide = false
                    
                    navigationController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
                    self.appDelegate.window?.rootViewController?.present(navigationController, animated: true, completion: nil)
                }
            )
        )
        
        //
        // OFFLINE
        //
        if metadata.session == "" {
            actions.append(
                NCMenuAction(
                    title: titleOffline,
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "offline"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        if ((localFile == nil || !CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView)) && metadata.session == "") {
                            
                            NCNetworking.shared.download(metadata: metadata, selector: selectorLoadOffline) { (_) in }
                        } else {
                            NCManageDatabase.sharedInstance.setLocalFile(ocId: metadata.ocId, offline: !localFile!.offline)
                        }
                    }
                )
            )
        }
        
        //
        // VIEW IN FOLDER
        //
        if appDelegate.activeFileViewInFolder == nil {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_view_in_folder_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "viewInFolder"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
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
            NCMenuAction(title: titleDelete,
                         icon: CCGraphics.changeThemingColorImage(UIImage(named: "trash"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    
                    let alertController = UIAlertController(title: "", message: NSLocalizedString("_want_delete_", comment: ""), preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_delete_", comment: ""), style: .default) { (action:UIAlertAction) in
                        
                        NCNetworking.shared.deleteMetadata(metadata, account: self.appDelegate.account, urlBase: self.appDelegate.urlBase, onlyLocal: false) { (errorCode, errorDescription) in
                            if errorCode != 0 {
                                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                            }
                        }
                    })
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_delete_", comment: ""), style: .default) { (action:UIAlertAction) in })
                                        
                    viewController.present(alertController, animated: true, completion:nil)
                }
            )
        )
        
        //
        // PDF
        //
        if (metadata.typeFile == k_metadataTypeFile_document && metadata.contentType == "application/pdf" ) {
            actions.append(
                NCMenuAction(title: NSLocalizedString("_search_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "search"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        NotificationCenter.default.postOnMainThread(name: k_notificationCenter_menuSearchTextPDF)
                    }
                )
            )
        }
        
        //
        // IMAGE - VIDEO - AUDIO
        //
        /*
        if metadata.session == "" {
            if (metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio) && !CCUtility.fileProviderStorageExists(appDelegate.activeDetail.metadata?.ocId, fileNameView: appDelegate.activeDetail.metadata?.fileNameView) && metadata.session == "" && metadata.typeFile == k_metadataTypeFile_image {
                actions.append(
                    NCMenuAction(title: NSLocalizedString("_download_image_max_", comment: ""),
                        icon: CCGraphics.changeThemingColorImage(UIImage(named: "downloadImageFullRes"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                        action: { menuAction in
                            NotificationCenter.default.postOnMainThread(name: k_notificationCenter_menuDownloadImage, userInfo: ["metadata": metadata])
                        }
                    )
                )
            }
        }
        */
        
        if metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio {
            if let metadataLive = NCManageDatabase.sharedInstance.isLivePhoto(metadata: metadata) {
                if CCUtility.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView) > 0 && CCUtility.fileProviderStorageSize(metadataLive.ocId, fileNameView: metadataLive.fileNameView) > 0 {
                    actions.append(
                        NCMenuAction(title: NSLocalizedString("_livephoto_save_", comment: ""),
                            icon: CCGraphics.changeThemingColorImage(UIImage(named: "livePhoto"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                            action: { menuAction in
                                NotificationCenter.default.postOnMainThread(name: k_notificationCenter_menuSaveLivePhoto, userInfo: ["metadata": metadata, "metadataMov": metadataLive])
                            }
                        )
                    )
                }
            }
        }
         
        return actions
    }
}
