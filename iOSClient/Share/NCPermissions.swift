//
//  NCPermissions.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 05/06/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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

import UIKit
import Foundation

class NCPermissions: NSObject {
    let permissionShared = "S"
    let permissionCanShare = "R"
    let permissionMounted = "M"
    let permissionFileCanWrite = "W"
    let permissionCanCreateFile = "C"
    let permissionCanCreateFolder = "K"
    let permissionCanDelete = "D"
    let permissionCanRename = "N"
    let permissionCanMove = "V"

    // Share permission
    // permissions - (int) 1 = read; 2 = update; 4 = create; 8 = delete; 16 = share; 31 = all
    //
    let permissionReadShare: Int = 1
    let permissionEditShare: Int = 2
    let permissionCreateShare: Int = 4
    let permissionDeleteShare: Int = 8
    let permissionShareShare: Int = 16
    //
    let permissionMinFileShare: Int = 1
    let permissionMaxFileShare: Int = 19
    let permissionMinFolderShare: Int = 1
    let permissionMaxFolderShare: Int = 31
    let permissionDefaultFileRemoteShareNoSupportShareOption: Int = 3
    let permissionDefaultFolderRemoteShareNoSupportShareOption: Int = 15

    // Additional attributes. This also includes the permission to download.
    // Check https://docs.nextcloud.com/server/latest/developer_manual/client_apis/OCS/ocs-share-api.html#share-attributes
    let permissionDownloadShare: Int = 0

    func isPermissionToRead(_ permission: Int) -> Bool {
        return ((permission & permissionReadShare) > 0)
    }

    func isPermissionToCanDelete(_ permission: Int) -> Bool {
        return ((permission & permissionDeleteShare) > 0)
    }

    func isPermissionToCanCreate(_ permission: Int) -> Bool {
        return ((permission & permissionCreateShare) > 0)
    }

    func isPermissionToCanEdit(_ permission: Int) -> Bool {
        return ((permission & permissionEditShare) > 0)
    }

    func isPermissionToCanShare(_ permission: Int) -> Bool {
        return ((permission & permissionShareShare) > 0)
    }

    func isAnyPermissionToEdit(_ permission: Int) -> Bool {
        let canCreate = isPermissionToCanCreate(permission)
        let canEdit = isPermissionToCanEdit(permission)
        let canDelete = isPermissionToCanDelete(permission)
        return canCreate || canEdit || canDelete
    }

    /// "Can edit" means it has can read, create, edit, and delete.
    func canEdit(_ permission: Int, isDirectory: Bool) -> Bool {
        let canRead   = isPermissionToRead(permission)
        let canCreate = isDirectory ? isPermissionToCanCreate(permission) : true
        let canEdit = isPermissionToCanEdit(permission)
        let canDelete = isDirectory ? isPermissionToCanDelete(permission) : true
        return canCreate && canEdit && canRead && canDelete
    }

    /// Read permission is always true for a share, hence why it's not here.
    func getPermissionValue(canRead: Bool = true, canCreate: Bool, canEdit: Bool, canDelete: Bool, canShare: Bool, isDirectory: Bool) -> Int {
        var permission = 0

        if canRead {
            permission = permission + permissionReadShare
        }

        if canCreate && isDirectory {
            permission = permission + permissionCreateShare
        }
        if canEdit {
            permission = permission + permissionEditShare
        }
        if canDelete && isDirectory {
            permission = permission + permissionDeleteShare
        }
        if canShare {
            permission = permission + permissionShareShare
        }

        return permission
    }
}
