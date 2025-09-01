// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Metadata permissions, represented as symbols (letters)
enum NCMetadataPermissions {
    static let permissionShared = "S"
    static let permissionCanShare = "R"
    static let permissionMounted = "M"
    static let permissionFileCanWrite = "W"
    static let permissionCanCreateFile = "C"
    static let permissionCanCreateFolder = "K"
    /** Note: If a folder is shared it will be unshared instead of deleted */
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

    static func canRename(_ metadata: tableMetadata) -> Bool {
        return metadata.permissions.contains(permissionCanRename)
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
