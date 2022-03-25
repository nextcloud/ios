//
//  NCShare+Menu.swift
//  Nextcloud
//
//  Created by A200020526 on 24/03/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//

import Foundation

extension NCShare {
    func toggleMenu(viewController: UIViewController, sendMail: Bool, folder: Bool) {
        guard (UIStoryboard(name: "NCMenu", bundle: nil).instantiateInitialViewController() as? NCMenu) != nil else {
            return
        }

        var actions = [NCMenuAction]()

        if !folder {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_open_in_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "viewInFolder").imageColor(NCBrandColor.shared.brandElement),
                    action: { _ in
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShareViewIn)
                    }
                )
            )
        }
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_advance_permissions_", comment: ""),
                icon: NCUtility.shared.loadImage(named: "rename").imageColor(NCBrandColor.shared.brandElement),
                action: { _ in
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShareAdvancePermission)
                }
            )
        )
        if sendMail {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_send_new_email_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "email").imageColor(NCBrandColor.shared.brandElement),
                    action: { _ in
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShareSendEmail)
                    }
                )
            )
        }
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_share_unshare_", comment: ""),
                icon: NCUtility.shared.loadImage(named: "trash").imageColor(NCBrandColor.shared.brandElement),
                action: { _ in
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShareUnshare)
                }
            )
        )
        presentMenu(with: actions)
    }
}
