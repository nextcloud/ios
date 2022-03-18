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

        if share.shareType == 3 {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_share_add_sharelink_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "shareAdd"),
                    action: { _ in
                        self.makeNewLinkShare()
                    }
                )
            )
        }
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
                title: NSLocalizedString("_share_advanced_permissions_", comment: ""),
                icon: NCUtility.shared.loadImage(named: "edit"),
                action: { _ in
                    guard
                        let advancePermission = UIStoryboard(name: "NCShare", bundle: nil).instantiateViewController(withIdentifier: "NCShareAdvancePermission") as? NCShareAdvancePermission,
                        let navigationController = self.navigationController, !share.isInvalidated else { return }
                    // FIXME: Fatal - Object has been deleted or invalidated
                    advancePermission.networking = self.networking
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
                icon: NCUtility.shared.loadImage(named: "trash"),
                action: { _ in
                    self.networking?.unShare(idShare: share.idShare)
                }
            )
        )

        self.presentMenu(with: actions)
    }

    func toggleUserPermissionMenu(isDirectory: Bool, tableShare: tableShare) {
        var actions = [NCMenuAction]()

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_share_read_only_", comment: ""),
                icon: UIImage(),
                selected: tableShare.permissions == (NCGlobal.shared.permissionReadShare + NCGlobal.shared.permissionShareShare) || tableShare.permissions == NCGlobal.shared.permissionReadShare,
                on: false,
                action: { _ in
                    let canShare = CCUtility.isPermission(toCanShare: tableShare.permissions)
                    let permissions = CCUtility.getPermissionsValue(byCanEdit: false, andCanCreate: false, andCanChange: false, andCanDelete: false, andCanShare: canShare, andIsFolder: isDirectory)
                    self.updateSharePermissions(share: tableShare, permissions: permissions)
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: isDirectory ? NSLocalizedString("_share_allow_upload_", comment: "") : NSLocalizedString("_share_editing_", comment: ""),
                icon: UIImage(),
                selected: hasUploadPermission(tableShare: tableShare),
                on: false,
                action: { _ in
                    let canShare = CCUtility.isPermission(toCanShare: tableShare.permissions)
                    let permissions = CCUtility.getPermissionsValue(byCanEdit: true, andCanCreate: true, andCanChange: true, andCanDelete: true, andCanShare: canShare, andIsFolder: isDirectory)
                    self.updateSharePermissions(share: tableShare, permissions: permissions)
                }
            )
        )

        self.presentMenu(with: actions)
    }

    fileprivate func hasUploadPermission(tableShare: tableShare) -> Bool {
        let uploadPermissions = [
            NCGlobal.shared.permissionMaxFileShare,
            NCGlobal.shared.permissionMaxFolderShare,
            NCGlobal.shared.permissionDefaultFileRemoteShareNoSupportShareOption,
            NCGlobal.shared.permissionDefaultFolderRemoteShareNoSupportShareOption]
        return uploadPermissions.contains(tableShare.permissions)
    }

    func updateSharePermissions(share: tableShare, permissions: Int) {
        let updatedShare = tableShare(value: share)
        updatedShare.permissions = permissions
        networking?.updateShare(option: updatedShare)
    }
}
