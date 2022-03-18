//
//  NCShare+Menu.swift
//  Nextcloud
//
//  Created by Henrik Storch on 16.03.22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//

import Foundation

extension NCShare {
    func toggleShareMenu(for share: tableShare) {

        var actions = [NCMenuAction]()

//        if !folder {
//            actions.append(
//                NCMenuAction(
//                    title: NSLocalizedString("_open_in_", comment: ""),
//                    icon: NCUtility.shared.loadImage(named: "viewInFolder").imageColor(NCBrandColor.shared.brandElement),
//                    action: { menuAction in
//                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShareViewIn)
//                    }
//                )
//            )
//        }

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_advance_permissions_", comment: ""),
                icon: NCUtility.shared.loadImage(named: "rename").imageColor(NCBrandColor.shared.brandElement),
                action: { _ in
                    guard
                        let advancePermission = UIStoryboard(name: "NCShare", bundle: nil).instantiateViewController(withIdentifier: "NCShareAdvancePermission") as? NCShareAdvancePermission,
                        let navigationController = self.navigationController else { return }
                    // FIXME: Fatal - Object has been deleted or invalidated
                    advancePermission.share = tableShare(value: share)
                    advancePermission.metadata = self.metadata
                    navigationController.pushViewController(advancePermission, animated: true)
                }
            )
        )

//        if sendMail {
//            actions.append(
//                NCMenuAction(
//                    title: NSLocalizedString("_send_new_email_", comment: ""),
//                    icon: NCUtility.shared.loadImage(named: "email").imageColor(NCBrandColor.shared.brandElement),
//                    action: { menuAction in
//                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShareSendEmail)
//                    }
//                )
//            )
//        }

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_share_unshare_", comment: ""),
                icon: NCUtility.shared.loadImage(named: "delete").imageColor(NCBrandColor.shared.brandElement),
                action: { _ in
                    // TODO: Unshare!
                }
            )
        )

        self.presentMenu(with: actions)
    }
}
