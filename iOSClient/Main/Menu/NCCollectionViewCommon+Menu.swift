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

extension NCCollectionViewCommon {

    func toggleMoreMenu(viewController: UIViewController, metadata: tableMetadata, selectOcId: [String]) {
        
        if let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(metadata.ocId) {
            
            let mainMenuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateViewController(withIdentifier: "NCMainMenuTableViewController") as! NCMainMenuTableViewController
            mainMenuViewController.actions = self.initMenu(viewController: viewController, metadata: metadata, selectOcId: selectOcId)

            let menuPanelController = NCMenuPanelController()
            menuPanelController.parentPresenter = viewController
            menuPanelController.delegate = mainMenuViewController
            menuPanelController.set(contentViewController: mainMenuViewController)
            menuPanelController.track(scrollView: mainMenuViewController.tableView)

            viewController.present(menuPanelController, animated: true, completion: nil)
        }
    }
    
    private func initMenu(viewController: UIViewController, metadata: tableMetadata, selectOcId: [String]) -> [NCMenuAction] {
        var actions = [NCMenuAction]()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let isFolderEncrypted = CCUtility.isFolderEncrypted(metadata.serverUrl+"/"+metadata.fileName, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account, urlBase: metadata.urlBase)
        
        var iconHeader: UIImage!
        if let icon = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
            iconHeader = icon
        } else {
            if metadata.directory {
                iconHeader = CCGraphics.changeThemingColorImage(UIImage(named: "folder"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon)
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

        // Favorite
        if (layoutKey == k_layout_view_favorite && serverUrl == "") || (layoutKey != k_layout_view_favorite) {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_remove_favorites_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "favorite"), width: 50, height: 50, color: NCBrandColor.sharedInstance.yellowFavorite),
                    action: { menuAction in
                        NCNetworking.shared.favoriteMetadata(metadata, urlBase: appDelegate.urlBase) { (errorCode, errorDescription) in }
                    }
                )
            )
        }
        
        // Offline
        if layoutKey == k_layout_view_offline && self.serverUrl == "" || (layoutKey != k_layout_view_offline) {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_remove_available_offline_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "offline"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        if metadata.directory {
                            NCManageDatabase.sharedInstance.setDirectory(serverUrl: CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)!, offline: false, account: self.appDelegate.account)
                        } else {
                            NCManageDatabase.sharedInstance.setLocalFile(ocId: metadata.ocId, offline: false)
                        }
                        self.reloadDataSource()
                    }
                )
            )
        }

        // All
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_details_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "details"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    NCMainCommon.shared.openShare(ViewController: self, metadata: metadata, indexPage: 0)
                }
            )
        )

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
        
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_rename_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "rename"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    let alertController = UIAlertController(title: NSLocalizedString("_rename_", comment: ""), message: nil, preferredStyle: .alert)
                    
                    alertController.addTextField { (textField) in
                        textField.text = metadata.fileNameView
                        textField.delegate = self as? UITextFieldDelegate
                        textField.addTarget(self, action: #selector(self.minCharTextFieldDidChange(sender:)), for: UIControl.Event.editingChanged)
                    }

                    let cancelAction = UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: nil)

                    let okAction = UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { action in
                        let fileNameNew = alertController.textFields![0].text
                        NCNetworking.shared.renameMetadata(metadata, fileNameNew: fileNameNew!, urlBase: appDelegate.urlBase, viewController: self) { (errorCode, errorDescription) in }
                    })
                    okAction.isEnabled = false
                    alertController.addAction(cancelAction)
                    alertController.addAction(okAction)

                    self.present(alertController, animated: true, completion: nil)
                }
            )
        )
        

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
        
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_delete_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "trash"), width: 50, height: 50, color: .red),
                action: { menuAction in
                    let alertController = UIAlertController(title: "", message: NSLocalizedString("_want_delete_", comment: ""), preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_delete_", comment: ""), style: .default) { (action:UIAlertAction) in
                        if selectOcId.count > 0 {
                            for ocId in selectOcId {
                                if let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(ocId) {
                                    NCOperationQueue.shared.delete(metadata: metadata, onlyLocal: false)
                                }
                            }
                        } else {
                            NCOperationQueue.shared.delete(metadata: metadata, onlyLocal: false)
                        }
                    })
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_remove_local_file_", comment: ""), style: .default) { (action:UIAlertAction) in
                        if selectOcId.count > 0 {
                            for ocId in selectOcId {
                                if let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(ocId) {
                                    NCOperationQueue.shared.delete(metadata: metadata, onlyLocal: true)
                                }
                            }
                        } else {
                            NCOperationQueue.shared.delete(metadata: metadata, onlyLocal: true)
                        }
                    })
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_delete_", comment: ""), style: .default) { (action:UIAlertAction) in })
                    self.present(alertController, animated: true, completion:nil)
                }
            )
        )

        return actions
    }
}

