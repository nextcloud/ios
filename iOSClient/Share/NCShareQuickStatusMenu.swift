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
        let menuViewController = UIStoryboard(name: "NCMenu", bundle: nil).instantiateInitialViewController() as! NCMenu
        var actions = [NCMenuAction]()

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_share_read_only_", comment: ""),
                icon: UIImage(),
                selected: tableShare.permissions == (NCGlobal.shared.permissionReadShare + NCGlobal.shared.permissionShareShare) || tableShare.permissions == NCGlobal.shared.permissionReadShare,
                on: false,
                action: { _ in
                    let canShare = CCUtility.isPermission(toCanShare: tableShare.permissions)
                    let permissions = CCUtility.getPermissionsValue(byCanEdit: false, andCanCreate: false, andCanChange: false, andCanDelete: false, andCanShare: canShare, andIsFolder: directory)
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShareChangePermissions, userInfo: ["idShare": tableShare.idShare, "permissions": permissions, "hideDownload": tableShare.hideDownload])
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: directory ? NSLocalizedString("_share_allow_upload_", comment: "") : NSLocalizedString("_share_editing_", comment: ""),
                icon: UIImage(),
                selected: hasUploadPermission(tableShare: tableShare),
                on: false,
                action: { _ in
                    let canShare = CCUtility.isPermission(toCanShare: tableShare.permissions)
                    let permissions = CCUtility.getPermissionsValue(byCanEdit: true, andCanCreate: true, andCanChange: true, andCanDelete: true, andCanShare: canShare, andIsFolder: directory)
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShareChangePermissions, userInfo: ["idShare": tableShare.idShare, "permissions": permissions, "hideDownload": tableShare.hideDownload])
                }
            )
        )

        menuViewController.actions = actions

        let menuPanelController = NCMenuPanelController()
        menuPanelController.parentPresenter = viewController
        menuPanelController.delegate = menuViewController
        menuPanelController.set(contentViewController: menuViewController)
        menuPanelController.track(scrollView: menuViewController.tableView)

        viewController.present(menuPanelController, animated: true, completion: nil)
    }

    fileprivate func hasUploadPermission(tableShare: tableShare) -> Bool {
        let uploadPermissions = [
            NCGlobal.shared.permissionMaxFileShare,
            NCGlobal.shared.permissionMaxFolderShare,
            NCGlobal.shared.permissionDefaultFileRemoteShareNoSupportShareOption,
            NCGlobal.shared.permissionDefaultFolderRemoteShareNoSupportShareOption]
        return uploadPermissions.contains(tableShare.permissions)
    }
}
