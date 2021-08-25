//
//  NCShareQuickStatusMenu.swift
//  Nextcloud
//
//  Created by TSI-mc on 30/06/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import UIKit

class NCShareQuickStatusMenu: NSObject {
        
    func toggleMenu(viewController: UIViewController, directory: Bool, tableShare: tableShare) {
        
        print(tableShare.permissions)
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
                selected: tableShare.permissions == NCGlobal.shared.permissionReadShare + NCGlobal.shared.permissionShareShare,
                on: false,
                action: { menuAction in
                    let permission = CCUtility.getPermissionsValue(byCanEdit: false, andCanCreate: false, andCanChange: false, andCanDelete: false, andCanShare: false, andIsFolder: directory)
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShareChangePermission, userInfo: ["idShare": tableShare.idShare, "permission": permission, "hideDownload": tableShare.hideDownload])
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: directory ? NSLocalizedString("_share_allow_upload_", comment: "") : NSLocalizedString("_share_editing_", comment: ""),
                icon: UIImage(),
                selected: tableShare.permissions == NCGlobal.shared.permissionMaxFileShare || tableShare.permissions == NCGlobal.shared.permissionMaxFolderShare ||  tableShare.permissions == NCGlobal.shared.permissionDefaultFileRemoteShareNoSupportShareOption,
                on: false,
                action: { menuAction in
                    let permission = CCUtility.getPermissionsValue(byCanEdit: true, andCanCreate: true, andCanChange: true, andCanDelete: true, andCanShare: false, andIsFolder: directory)
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShareChangePermission, userInfo: ["idShare": tableShare.idShare, "permission": permission, "hideDownload": tableShare.hideDownload])
                }
            )
        )
        
        if directory {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_share_file_drop_", comment: ""),
                    icon: UIImage(),
                    selected: tableShare.permissions == NCGlobal.shared.permissionCreateShare,
                    on: false,
                    action: { menuAction in
                        let permission = NCGlobal.shared.permissionCreateShare
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShareChangePermission, userInfo: ["idShare": tableShare.idShare, "permission": permission, "hideDownload": tableShare.hideDownload])
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

