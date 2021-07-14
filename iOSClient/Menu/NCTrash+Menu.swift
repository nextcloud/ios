//
//  NCTrash+Menu.swift
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

extension NCTrash {

    func toggleMenuMoreHeader() {
        
        let menuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateInitialViewController() as! NCMenu
        var actions: [NCMenuAction] = []
                
        if isEditMode {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_trash_delete_selected_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "trash"),
                    action: { menuAction in
                        let alert = UIAlertController(title: NSLocalizedString("_trash_delete_selected_", comment: ""), message: "", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .destructive, handler: { _ in
                            for ocId in self.selectOcId {
                                self.deleteItem(with: ocId)
                            }
                            self.isEditMode = false
                            self.selectOcId.removeAll()
                            self.collectionView.reloadData()
                        }))
                        alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: { _ in
                        }))
                        self.present(alert, animated: true, completion: nil)
                    }
                )
            )
        } else {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_trash_delete_all_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "trash"),
                    action: { menuAction in
                        let alert = UIAlertController(title: NSLocalizedString("_trash_delete_all_", comment: ""), message: "", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .destructive, handler: { _ in
                            self.emptyTrash()
                        }))
                        alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: { _ in
                        }))
                        self.present(alert, animated: true, completion: nil)
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
    
    func toggleMenuMoreList(with objectId: String, image: UIImage?) {
        
        let menuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateInitialViewController() as! NCMenu
        var actions: [NCMenuAction] = []

        guard let tableTrash = NCManageDatabase.shared.getTrashItem(fileId: objectId, account: appDelegate.account) else {
            return
        }

        var iconHeader: UIImage!
        if let icon = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(tableTrash.fileId, etag: tableTrash.fileName)) {
            iconHeader = icon
        } else {
            if(tableTrash.directory) {
                iconHeader = UIImage(named: "folder")!.image(color: NCBrandColor.shared.gray, size: 50)
            } else {
                iconHeader = UIImage(named: tableTrash.iconName)
            }
        }

        actions.append(
            NCMenuAction(
                title: tableTrash.trashbinFileName,
                icon: iconHeader,
                action: nil
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_delete_", comment: ""),
                icon: NCUtility.shared.loadImage(named: "trash"),
                action: { menuAction in
                    self.deleteItem(with: objectId)
                }
            )
        )

        menuViewController.actions = actions

        let menuPanelController = NCMenuPanelController()
        menuPanelController.parentPresenter = self
        menuPanelController.delegate = menuViewController
        menuPanelController.set(contentViewController: menuViewController)
        menuPanelController.track(scrollView: menuViewController.tableView)

        self.present(menuPanelController, animated: true, completion: nil)
    }
    
    func toggleMenuMoreGrid(with objectId: String, namedButtonMore: String, image: UIImage?) {
        
        let menuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateInitialViewController() as! NCMenu
        var actions: [NCMenuAction] = []

        guard let tableTrash = NCManageDatabase.shared.getTrashItem(fileId: objectId, account: appDelegate.account) else {
            return
        }

        var iconHeader: UIImage!
        if let icon = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(tableTrash.fileId, etag: tableTrash.fileName)) {
            iconHeader = icon
        } else {
            if(tableTrash.directory) {
                iconHeader = UIImage(named: "folder")!.image(color: NCBrandColor.shared.gray, size: 50)
            } else {
                iconHeader = UIImage(named: tableTrash.iconName)
            }
        }

        actions.append(
            NCMenuAction(
                title: tableTrash.trashbinFileName,
                icon: iconHeader,
                action: nil
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_restore_", comment: ""),
                icon: UIImage(named: "restore")!.image(color: NCBrandColor.shared.gray, size: 50),
                action: { menuAction in
                    self.restoreItem(with: objectId)
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_delete_", comment: ""),
                icon: NCUtility.shared.loadImage(named: "trash"),
                action: { menuAction in
                    self.deleteItem(with: objectId)
                }
            )
        )

        menuViewController.actions = actions

        let menuPanelController = NCMenuPanelController()
        menuPanelController.parentPresenter = self
        menuPanelController.delegate = menuViewController
        menuPanelController.set(contentViewController: menuViewController)
        menuPanelController.track(scrollView: menuViewController.tableView)

        self.present(menuPanelController, animated: true, completion: nil)
    }
}

