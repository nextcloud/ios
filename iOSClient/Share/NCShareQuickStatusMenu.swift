//
//  NCShareQuickStatusMenu.swift
//  Nextcloud
//
//  Created by TSI-mc on 30/06/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import UIKit

extension NCShare {
    func toggleMenu(isDirectory: Bool, tableShare: tableShare) {
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
