//
//  CCMain+Menu.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 24.01.20.
//  Copyright © 2020 Philippe Weidmann. All rights reserved.
//  Copyright © 2020 Marino Faggiana All rights reserved.
//
//  Author Philippe Weidmann <philippe.weidmann@infomaniak.com>
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

extension CCMain {

    // MARK: - Select Menu
    
    @objc func toggleSelectMenu(viewController: UIViewController) {
           
        let mainMenuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateViewController(withIdentifier: "NCMainMenuTableViewController") as! NCMainMenuTableViewController
        mainMenuViewController.actions = self.initSelectMenu()

        let menuPanelController = NCMenuPanelController()
        menuPanelController.parentPresenter = viewController
        menuPanelController.delegate = mainMenuViewController
        menuPanelController.set(contentViewController: mainMenuViewController)
        menuPanelController.track(scrollView: mainMenuViewController.tableView)

        viewController.present(menuPanelController, animated: true, completion: nil)
    }
    
    private func initSelectMenu() -> [NCMenuAction] {
        var actions = [NCMenuAction]()

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_select_all_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "selectFull"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    self.didSelectAll()
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_move_or_copy_selected_files_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "move"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    self.moveOpenWindow(self.tableView.indexPathsForSelectedRows)
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_save_selected_files_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "saveSelectedFiles"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    self.saveSelectedFiles()
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_delete_selected_files_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "trash"), width: 50, height: 50, color: .red),
                action: { menuAction in
                    self.deleteMetadatas()
                }
            )
        )

        return actions
    }

    // MARK: - More Menu ...

    @objc func toggleMoreMenu(viewController: UIViewController, indexPath: IndexPath, metadata: tableMetadata, metadataFolder: tableMetadata) {
           
        if let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(metadata.ocId) {
            
            let mainMenuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateViewController(withIdentifier: "NCMainMenuTableViewController") as! NCMainMenuTableViewController
            mainMenuViewController.actions = self.initMoreMenu(indexPath: indexPath, metadata: metadata, metadataFolder: metadataFolder)

            let menuPanelController = NCMenuPanelController()
            menuPanelController.parentPresenter = viewController
            menuPanelController.delegate = mainMenuViewController
            menuPanelController.set(contentViewController: mainMenuViewController)
            menuPanelController.track(scrollView: mainMenuViewController.tableView)

            viewController.present(menuPanelController, animated: true, completion: nil)
        }
    }
    
    private func initMoreMenu(indexPath: IndexPath, metadata: tableMetadata, metadataFolder: tableMetadata) -> [NCMenuAction] {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate

        var actions = [NCMenuAction]()

        if (metadata.directory) {
            
            var isOffline = false
            let isFolderEncrypted = CCUtility.isFolderEncrypted(metadata.serverUrl+"/"+metadata.fileName, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account, urlBase: metadata.urlBase)

            if let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)!)) {
                isOffline = directory.offline
            }

            actions.append(
                NCMenuAction(
                    title: metadata.fileNameView,
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "folder"), width: 50, height: 50, color: NCBrandColor.sharedInstance.brandElement),
                    action: nil
                )
            )

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

            if (!isFolderEncrypted) {
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

            if (!metadata.e2eEncrypted) {
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
                                let fileNameNew = alertController.textFields![0].text
                                NCNetworking.shared.renameMetadata(metadata, fileNameNew: fileNameNew!, urlBase: appDelegate.urlBase, viewController: self) { (errorCode, errorDescription) in
                                    if errorCode != 0 {
                                        NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
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

            if (!isFolderEncrypted) {
                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_move_or_copy_", comment: ""),
                        icon: CCGraphics.changeThemingColorImage(UIImage(named: "move"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                        action: { menuAction in
                            self.moveOpenWindow([indexPath])
                        }
                    )
                )
            }

            if (!isFolderEncrypted) {
                actions.append(
                    NCMenuAction(
                        title: isOffline ? NSLocalizedString("_remove_available_offline_", comment: "") : NSLocalizedString("_set_available_offline_", comment: ""),
                        icon: CCGraphics.changeThemingColorImage(UIImage(named: "offline"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                        action: { menuAction in
                            let serverUrl = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)!
                            NCManageDatabase.sharedInstance.setDirectory(serverUrl: serverUrl, offline: !isOffline, account: appDelegate.account)
                            if (!isOffline) {
                                NCOperationQueue.shared.synchronizationMetadata(metadata, selector: selectorDownloadAllFile)
                            }
                            NotificationCenter.default.postOnMainThread(name: k_notificationCenter_reloadDataSource, userInfo: ["ocId":metadata.ocId, "serverUrl":metadata.serverUrl])
                        }
                    )
                )
            }

            if (!metadata.e2eEncrypted && CCUtility.isEnd(toEndEnabled: appDelegate.account)) {
                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_e2e_set_folder_encrypted_", comment: ""),
                        icon: CCGraphics.changeThemingColorImage(UIImage(named: "lock"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                        action: { menuAction in
                            NCCommunication.shared.markE2EEFolder(fileId: metadata.fileId, delete: false) { (account, errorCode, errorDescription) in
                                if errorCode == 0 {
                                    let serverUrl = self.serverUrl + "/" + metadata.fileName
                                    NCManageDatabase.sharedInstance.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, serverUrl))
                                    NCManageDatabase.sharedInstance.setDirectory(serverUrl: serverUrl, serverUrlTo: nil, etag: nil, ocId: nil, fileId: nil, encrypted: true, richWorkspace: nil, account: metadata.account)
                                    NCManageDatabase.sharedInstance.setMetadataEncrypted(ocId: metadata.ocId, encrypted: true)
                                    
                                    NotificationCenter.default.postOnMainThread(name: k_notificationCenter_reloadDataSource, userInfo: ["ocId":metadata.ocId, "serverUrl":metadata.serverUrl])
                                } else {
                                    NCContentPresenter.shared.messageNotification(NSLocalizedString("_e2e_error_mark_folder_", comment: ""), description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: .error, errorCode: errorCode)
                                }
                            }
                        }
                    )
                )
            }
        
            if (metadata.e2eEncrypted && !metadataFolder.e2eEncrypted && CCUtility.isEnd(toEndEnabled: appDelegate.account)) {
                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_e2e_remove_folder_encrypted_", comment: ""),
                        icon: CCGraphics.changeThemingColorImage(UIImage(named: "lock"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                        action: { menuAction in
                            NCCommunication.shared.markE2EEFolder(fileId: metadata.fileId, delete: true) { (account, errorCode, errorDescription) in
                                if errorCode == 0 {
                                    let serverUrl = self.serverUrl + "/" + metadata.fileName
                                    NCManageDatabase.sharedInstance.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, "\(self.serverUrl ?? "")/\(metadata.fileName)"))
                                    NCManageDatabase.sharedInstance.setDirectory(serverUrl: serverUrl, serverUrlTo: nil, etag: nil, ocId: nil, fileId: nil, encrypted: false, richWorkspace: nil, account: metadata.account)
                                    NCManageDatabase.sharedInstance.setMetadataEncrypted(ocId: metadata.ocId, encrypted: false)
                                    
                                    NotificationCenter.default.postOnMainThread(name: k_notificationCenter_reloadDataSource, userInfo: ["ocId":metadata.ocId, "serverUrl":metadata.serverUrl])
                                } else {
                                    NCContentPresenter.shared.messageNotification(NSLocalizedString("_e2e_error_delete_mark_folder_", comment: ""), description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: .error, errorCode: errorCode)
                                }
                            }
                        }
                    )
                )
            }
            
        } else {
            
            var iconHeader: UIImage!
            if let icon = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
                iconHeader = icon
            } else {
                iconHeader = UIImage(named: metadata.iconName)
            }
            let isEncrypted = CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account, urlBase: metadata.urlBase)

            actions.append(
                NCMenuAction(
                    title: metadata.fileNameView,
                    icon: iconHeader,
                    action: nil
                )
            )

            actions.append(
                NCMenuAction(
                    title: metadata.favorite ? NSLocalizedString("_remove_favorites_", comment: "") : NSLocalizedString("_add_favorites_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "favorite"), width: 50, height: 50, color: NCBrandColor.sharedInstance.yellowFavorite),
                    action: { menuAction in
                        NCNetworking.shared.favoriteMetadata(metadata, urlBase: appDelegate.urlBase) { (errorCode, errorDescription) in }
                    }
                )
            )

            if (!isEncrypted) {
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

            if(!NCBrandOptions.sharedInstance.disable_openin_file) {
                actions.append(
                    NCMenuAction(title: NSLocalizedString("_open_in_", comment: ""),
                        icon: CCGraphics.changeThemingColorImage(UIImage(named: "openFile"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                        action: { menuAction in
                            self.tableView.setEditing(false, animated: true)
                            NCMainCommon.shared.downloadOpen(metadata: metadata, selector: selectorOpenIn)
                        }
                    )
                )
            }

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
                            let fileNameNew = alertController.textFields![0].text
                            NCNetworking.shared.renameMetadata(metadata, fileNameNew: fileNameNew!, urlBase: appDelegate.urlBase, viewController: self) { (errorCode, errorDescription) in }
                        })
                        
                        alertController.addAction(cancelAction)
                        alertController.addAction(okAction)

                        self.present(alertController, animated: true, completion: nil)
                    }
                )
            )
            
            if (!isEncrypted) {
                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_move_or_copy_", comment: ""),
                        icon: CCGraphics.changeThemingColorImage(UIImage(named: "move"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                        action: { menuAction in
                            self.moveOpenWindow([indexPath])
                        }
                    )
                )
            }

            if (!isEncrypted) {
                let localFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                var title: String!
                if (localFile == nil || localFile!.offline == false) {
                    title = NSLocalizedString("_set_available_offline_", comment: "")
                } else {
                    title = NSLocalizedString("_remove_available_offline_", comment: "")
                }

                actions.append(
                    NCMenuAction(
                        title: title,
                        icon: CCGraphics.changeThemingColorImage(UIImage(named: "offline"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                        action: { menuAction in
                            if (localFile == nil || !CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView)) {
                                
                                NCNetworking.shared.download(metadata: metadata, selector: selectorLoadOffline) { (_) in }
                                
                                if let metadataLivePhoto = NCManageDatabase.sharedInstance.isLivePhoto(metadata: metadata) {
                                    NCNetworking.shared.download(metadata: metadataLivePhoto, selector: selectorLoadOffline) { (_) in }
                                }
                                
                            } else {
                                NCManageDatabase.sharedInstance.setLocalFile(ocId: metadata.ocId, offline: !localFile!.offline)
                                NotificationCenter.default.postOnMainThread(name: k_notificationCenter_reloadDataSource, userInfo: ["ocId":metadata.ocId, "serverUrl":metadata.serverUrl])
                            }
                        }
                    )
                )
            }
        }

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_delete_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "trash"), width: 50, height: 50, color: .red),
                action: { menuAction in
                    self.actionDelete(indexPath)
                }
            )
        )

        return actions
    }
}
