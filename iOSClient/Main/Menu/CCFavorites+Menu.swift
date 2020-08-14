//
//  CCFavorites+Menu.swift
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

extension CCFavorites {

    @objc func toggleMoreMenu(viewController: UIViewController, indexPath: IndexPath, metadata: tableMetadata) {
        
        if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
            
            let mainMenuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateViewController(withIdentifier: "NCMainMenuTableViewController") as! NCMainMenuTableViewController
            mainMenuViewController.actions = self.initMoreMenu(indexPath: indexPath, metadata: metadata)

            let menuPanelController = NCMenuPanelController()
            menuPanelController.parentPresenter = viewController
            menuPanelController.delegate = mainMenuViewController
            menuPanelController.set(contentViewController: mainMenuViewController)
            menuPanelController.track(scrollView: mainMenuViewController.tableView)

            viewController.present(menuPanelController, animated: true, completion: nil)
        }
    }
    
    private func initMoreMenu(indexPath: IndexPath, metadata: tableMetadata) -> [NCMenuAction] {
        var actions = [NCMenuAction]()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate

        var iconHeader: UIImage!
        if let icon = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
            iconHeader = icon
        } else {
            if(metadata.directory) {
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

        if(self.serverUrl == nil) {
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

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_details_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "details"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    NCMainCommon.sharedInstance.openShare(ViewController: self, metadata: metadata, indexPage: 0)
                }
            )
        )

        if(!metadata.directory && !NCBrandOptions.sharedInstance.disable_openin_file) {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_open_in_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "openFile"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    action: { menuAction in
                        self.tableView.setEditing(false, animated: true)
                        NCMainCommon.sharedInstance.downloadOpen(metadata: metadata, selector: selectorOpenIn)
                    }
                )
            )
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

