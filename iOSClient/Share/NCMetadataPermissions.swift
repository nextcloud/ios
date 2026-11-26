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

    /** Note: If a folder is shared it will be unshared instead of deleted */
    static func canDelete(_ metadata: tableMetadata) -> Bool {
        return metadata.permissions.contains(permissionCanDeleteOrUnshare)
    }

    /// This includes deleting as deleting a file is moving it to the trash
    static func canMoveAndDelete(_ metadata: tableMetadata) -> Bool {
        return metadata.permissions.contains(permissionCanMove)
    }

    /// Whether an item is the top of a share received from another user.
    ///
    /// The server marks every item inside a received share with `S`, so the top of the
    /// share is the item that has `S` while its parent folder does not. Deleting that item
    /// only removes the share for the current user; the owner's data is not touched.
    ///
    /// - Parameters:
    ///   - permissions: The WebDAV permissions of the item.
    ///   - parentPermissions: The WebDAV permissions of the folder that contains it, or `nil` if unknown.
    /// - Returns: `false` when the parent folder is unknown.
    static func isReceivedShareRoot(permissions: String, parentPermissions: String?) -> Bool {
        guard let parentPermissions else {
            return false
        }
        return permissions.contains(permissionShared) && !parentPermissions.contains(permissionShared)
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
