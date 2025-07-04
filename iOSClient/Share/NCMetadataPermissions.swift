//
//  NCMetadataPermissions.swift
//  Nextcloud
//
//  Created by Milen Pivchev on 21.05.25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import Foundation

/// Metadata permissions, represented as symbols (letters)
class NCMetadataPermissions: NSObject {
    static let permissionShared = "S"
    static let permissionCanShare = "R"
    static let permissionMounted = "M"
    static let permissionFileCanWrite = "W"
    static let permissionCanCreateFile = "C"
    static let permissionCanCreateFolder = "K"
    static let permissionCanDeleteOrUnshare = "D"
    static let permissionCanRename = "N"
    static let permissionCanMove = "V"

    static func canCreateFile(_ metadata: tableMetadata) -> Bool {
        return metadata.permissions.contains(permissionCanCreateFile)
    }

    static func canCreateFolder(_ metadata: tableMetadata) -> Bool {
        return metadata.permissions.contains(permissionCanCreateFolder)
    }

    static func canDelete(_ metadata: tableMetadata) -> Bool {
        return metadata.permissions.contains(permissionCanDeleteOrUnshare)
    }

    static func permissionsContainsString(_ metadataPermissions: String, permissions: String) -> Bool {
        for char in permissions {
            if metadataPermissions.contains(char) == false {
                return false
            }
        }
        return true
    }
}
