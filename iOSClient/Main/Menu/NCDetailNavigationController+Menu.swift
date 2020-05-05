//
//  NCDetailNavigationController+Menu.swift
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

extension NCDetailNavigationController {

    @objc func toggleMoreMenu(viewController: UIViewController, metadata: tableMetadata) {
        if appDelegate.activeDetail.backgroundView.subviews.first == nil && appDelegate.activeDetail.viewerImageViewController == nil {
            return
        }
        
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
        
        actions.append(
            NCMenuAction(
                title: titleFavorite,
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "favorite"), width: 50, height: 50, color: NCBrandColor.sharedInstance.yellowFavorite),
                action: { menuAction in
                    NCNetworking.sharedInstance.favoriteMetadata(metadata, url: self.appDelegate.activeUrl) { (errorCode, errorDescription) in }
                }
            )
        )
        
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_details_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "details"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    NCMainCommon.sharedInstance.openShare(ViewController: self, metadata: metadata, indexPage: 0)
                }
            )
        )
        
        actions.append(
            NCMenuAction(title: NSLocalizedString("_open_in_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "openFile"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    NCMainCommon.sharedInstance.downloadOpen(metadata: metadata, selector: selectorOpenInDetail)
                }
            )
        )

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
                        NCNetworking.sharedInstance.renameMetadata(metadata, fileNameNew: fileNameNew!, user: self.appDelegate.activeUser, userID: self.appDelegate.activeUserID, password: self.appDelegate.activePassword, url: self.appDelegate.activeUrl, viewController: self) { (errorCode, errorDescription) in }
                    })
                    alertController.addAction(cancelAction)
                    alertController.addAction(okAction)

                    self.present(alertController, animated: true, completion: nil)
                }
            )
        )
        
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_move_or_copy_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "move"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    
                    let storyboard = UIStoryboard(name: "NCSelect", bundle: nil)
                    let navigationController = storyboard.instantiateInitialViewController() as! UINavigationController
                    let viewController = navigationController.topViewController as! NCSelect
                    
                    viewController.delegate = self.appDelegate.activeDetail
                    viewController.hideButtonCreateFolder = false
                    viewController.selectFile = false
                    viewController.includeDirectoryE2EEncryption = false
                    viewController.includeImages = false
                    viewController.type = ""
                    viewController.titleButtonDone = NSLocalizedString("_move_", comment: "")
                    viewController.titleButtonDone1 = NSLocalizedString("_copy_", comment: "")
                    viewController.isButtonDone1Hide = false
                    viewController.isOverwriteHide = false
                    viewController.layoutViewSelect = k_layout_view_move
                    
                    navigationController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
                    self.present(navigationController, animated: true, completion: nil)
                }
            )
        )
        
        actions.append(
            NCMenuAction(
                title: titleOffline,
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "offline"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    if ((localFile == nil || !CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView)) && metadata.session == "") {
                        
                        metadata.session = k_download_session
                        metadata.sessionError = ""
                        metadata.sessionSelector = selectorLoadOffline
                        metadata.status = Int(k_metadataStatusWaitDownload)

                        NCManageDatabase.sharedInstance.addMetadata(metadata)
                        self.appDelegate.startLoadAutoDownloadUpload()
                        
                    } else {
                        NCManageDatabase.sharedInstance.setLocalFile(ocId: metadata.ocId, offline: !localFile!.offline)
                        NotificationCenter.default.post(name: Notification.Name.init(rawValue:
                        k_notificationCenter_clearDateReadDataSource), object: nil)
                    }
                }
            )
        )
        
        actions.append(
            NCMenuAction(title: NSLocalizedString("_delete_", comment: ""),
                         icon: CCGraphics.changeThemingColorImage(UIImage(named: "trash"), width: 50, height: 50, color: .red),
                action: { menuAction in
                    
                    let alertController = UIAlertController(title: "", message: NSLocalizedString("_want_delete_", comment: ""), preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_delete_", comment: ""), style: .default) { (action:UIAlertAction) in
                        
                        NCNetworking.sharedInstance.deleteMetadata(metadata, account: self.appDelegate.activeAccount, user: self.appDelegate.activeUser, userID: self.appDelegate.activeUserID, password: self.appDelegate.activePassword, url: self.appDelegate.activeUrl) { (errorCode, errorDescription) in }
                    })
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_delete_", comment: ""), style: .default) { (action:UIAlertAction) in })
                                        
                    self.present(alertController, animated: true, completion:nil)
                }
            )
        )
        
        // PDF
        
        if (metadata.typeFile == k_metadataTypeFile_document && metadata.contentType == "application/pdf" ) {
            actions.append(
                NCMenuAction(title: NSLocalizedString("_search_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "search"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        NotificationCenter.default.post(name: Notification.Name.init(rawValue:k_notificationCenter_menuSearchTextPDF), object: nil)
                    }
                )
            )
        }
        
        // IMAGE - VIDEO - AUDIO
        
        if (metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio) && !CCUtility.fileProviderStorageExists(appDelegate.activeDetail.metadata?.ocId, fileNameView: appDelegate.activeDetail.metadata?.fileNameView) && metadata.session == "" && metadata.typeFile == k_metadataTypeFile_image {
            actions.append(
                NCMenuAction(title: NSLocalizedString("_download_image_max_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "downloadImageFullRes"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_menuDownloadImage), object: nil, userInfo: ["metadata": metadata])
                    }
                )
            )
        }
        
        if metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video || metadata.typeFile == k_metadataTypeFile_audio {
            if let metadataLive = NCUtility.sharedInstance.isLivePhoto(metadata: metadata) {
                if CCUtility.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView) > 0 && CCUtility.fileProviderStorageSize(metadataLive.ocId, fileNameView: metadataLive.fileNameView) > 0 {
                    actions.append(
                        NCMenuAction(title: NSLocalizedString("_livephoto_save_", comment: ""),
                            icon: CCGraphics.changeThemingColorImage(UIImage(named: "livePhoto"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                            action: { menuAction in
                                NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_menuSaveLivePhoto), object: nil, userInfo: ["metadata": metadata, "metadataMov": metadataLive])
                            }
                        )
                    )
                }
            }
        }
                
        // CLOSE
        
        actions.append(
            NCMenuAction(title: NSLocalizedString("_close_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "exit"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_menuDetailClose), object: nil)
                }
            )
        )
        
        return actions
    }
}

