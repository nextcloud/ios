//
//  NCPermissions.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 05/06/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

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
    let permissionUpdateShare: Int = 2
    let permissionCreateShare: Int = 4
    let permissionDeleteShare: Int = 8
    let permissionShareShare: Int = 16

    let permissionMinFileShare: Int = 1
    let permissionMaxFileShare: Int = 19
    let permissionMinFolderShare: Int = 1
    let permissionMaxFolderShare: Int = 31
    let permissionDefaultFileRemoteShareNoSupportShareOption: Int = 3
    let permissionDefaultFolderRemoteShareNoSupportShareOption: Int = 15
    // ATTRIBUTES
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
    func isPermissionToCanChange(_ permission: Int) -> Bool {
        return ((permission & permissionUpdateShare) > 0)
    }
    func isPermissionToCanShare(_ permission: Int) -> Bool {
        return ((permission & permissionShareShare) > 0)
    }
    func isAnyPermissionToEdit(_ permission: Int) -> Bool {
        let canCreate = isPermissionToCanCreate(permission)
        let canChange = isPermissionToCanChange(permission)
        let canDelete = isPermissionToCanDelete(permission)
        return canCreate || canChange || canDelete
    }
    func isPermissionToReadCreateUpdate(_ permission: Int) -> Bool {
        let canRead   = isPermissionToRead(permission)
        let canCreate = isPermissionToCanCreate(permission)
        let canChange = isPermissionToCanChange(permission)
        return canCreate && canChange && canRead
    }
    func getPermission(canEdit: Bool, canCreate: Bool, canChange: Bool, canDelete: Bool, canShare: Bool, isFolder: Bool) -> Int {
        var permission = permissionReadShare

        if canEdit && !isFolder {
            permission = permission + permissionUpdateShare
        }
        if canCreate && isFolder {
            permission = permission + permissionCreateShare
        }
        if canChange && isFolder {
            permission = permission + permissionUpdateShare
        }
        if canDelete && isFolder {
            permission = permission + permissionDeleteShare
        }
        if canShare {
            permission = permission + permissionShareShare
        }
        return permission
    }
}
