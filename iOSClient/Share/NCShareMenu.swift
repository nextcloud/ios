//
//  NCShareMenu.swift
//  Nextcloud
//
//  Created by T-systems on 29/06/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import UIKit

class NCShareMenu: NSObject {
    
    func toggleMenu(viewController: UIViewController, sendMail: Bool, folder: Bool) {
        
        guard let menuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateInitialViewController() as? NCMenu else {
            return
        }
        
        var actions = [NCMenuAction]()
        
        if !folder {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_open_in_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "viewInFolder").imageColor(NCBrandColor.shared.brandElement),
                    action: { menuAction in
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShareViewIn)
                    }
                )
            )
        }
        
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_advance_permissions_", comment: ""),
                icon: NCUtility.shared.loadImage(named: "rename").imageColor(NCBrandColor.shared.brandElement),
                action: { menuAction in
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShareAdvancePermission)
                }
            )
        )
        
        if sendMail {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_send_new_email_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "email").imageColor(NCBrandColor.shared.brandElement),
                    action: { menuAction in
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShareSendEmail)
                    }
                )
            )
        }
        
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_share_unshare_", comment: ""),
                icon: NCUtility.shared.loadImage(named: "delete").imageColor(NCBrandColor.shared.brandElement),
                action: { menuAction in
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShareUnshare)
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
}
