//
//  NCShare+Menu.swift
//  Nextcloud
//
//  Created by Henrik Storch on 16.03.22.
//  Copyright © 2022 Henrik Storch. All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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

import Foundation

extension NCShare {
    func toggleShareMenu(for share: tableShare) {

        var actions = [NCMenuAction]()

        if share.shareType == 3, canReshare {
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

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_details_", comment: ""),
                icon: NCUtility.shared.loadImage(named: "pencil"),
                action: { _ in
                    guard
                        let advancePermission = UIStoryboard(name: "NCShare", bundle: nil).instantiateViewController(withIdentifier: "NCShareAdvancePermission") as? NCShareAdvancePermission,
                        let navigationController = self.navigationController, !share.isInvalidated else { return }
                    advancePermission.networking = self.networking
                    advancePermission.share = tableShare(value: share)
                    advancePermission.oldTableShare = tableShare(value: share)
                    advancePermission.metadata = self.metadata
                    navigationController.pushViewController(advancePermission, animated: true)
                }
            )
        )

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
                icon: NCUtility.shared.loadImage(named: "eye"),
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
                icon: NCUtility.shared.loadImage(named: "pencil"),
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
