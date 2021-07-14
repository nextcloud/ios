//
//  NCShareQuickStatusMenu.swift
//  Nextcloud
//
//  Created by TSI-mc on 30/06/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import UIKit

class NCShareQuickStatusMenu: NSObject {
//    func toggleMenu(viewController: UIViewController, key: String, sortButton: UIButton?, serverUrl: String, hideDirectoryOnTop: Bool = false) {
    
    var currentStatus = ""
    
    func toggleMenu(viewController: UIViewController, directory: Bool, status: Int) {
        
        print(status)
//        self.currentStatus = status
        let menuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateInitialViewController() as! NCMenu
        var actions = [NCMenuAction]()

//        "_share_read_only_"             = "Read only";
//        "_share_editing_"               = "Editing";
//        "_share_allow_upload_"          = "Allow upload and editing";
//        "_share_file_drop_"             = "File drop (upload only)";
        
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_share_read_only_", comment: ""),
                icon: UIImage(),
                selected: status == NCGlobal.shared.permissionReadShare + NCGlobal.shared.permissionShareShare,
                on: false,
                action: { menuAction in
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterStatusReadOnly)
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: directory ? NSLocalizedString("_share_allow_upload_", comment: "") : NSLocalizedString("_share_editing_", comment: ""),
                icon: UIImage(),
                selected: status == NCGlobal.shared.permissionMaxFileShare || status == NCGlobal.shared.permissionMaxFolderShare ||  status == NCGlobal.shared.permissionDefaultFileRemoteShareNoSupportShareOption,
                on: false,
                action: { menuAction in
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterStatusEditing)
                }
            )
        )
        
        if directory {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_share_file_drop_", comment: ""),
                    icon: UIImage(),
                    selected: status == NCGlobal.shared.permissionCreateShare,
                    on: false,
                    action: { menuAction in
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterStatusFileDrop)
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
}

