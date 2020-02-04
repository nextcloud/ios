//
//  CCFavorites+Menu.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 24.01.20.
//  Copyright © 2020 TWS. All rights reserved.
//

import FloatingPanel

extension CCFavorites {

    private func initMoreMenu(indexPath: IndexPath, metadata: tableMetadata) -> [NCMenuAction] {
        var actions = [NCMenuAction]()

        var iconHeader: UIImage!
        if let icon = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileNameView)) {
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
                        self.settingFavorite(metadata, favorite: false)
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
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "trash"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    self.actionDelete(indexPath)
                }
            )
        )

        return actions
    }

    @objc func toggleMoreMenu(viewController: UIViewController, indexPath: IndexPath, metadata: tableMetadata) {
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

