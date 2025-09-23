// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

class tableDirectory: Object {
    @objc dynamic var account = ""
    @objc dynamic var colorFolder: String?
    @objc dynamic var etag = ""
    @objc dynamic var favorite: Bool = false
    @objc dynamic var fileId = ""
    @objc dynamic var lastOpeningDate = NSDate()
    @objc dynamic var ocId = ""
    @objc dynamic var offline: Bool = false
    @objc dynamic var permissions = ""
    @objc dynamic var richWorkspace: String?
    @objc dynamic var serverUrl = ""

    override static func primaryKey() -> String {
        return "ocId"
    }
}

extension NCManageDatabase {

    // MARK: - Realm write

    /// Asynchronously creates a directory record in the database based on the provided metadata.
    ///
    /// This function performs the following steps inside a Realm write transaction:
    /// 1. Creates a detached copy of the provided `tableMetadata`.
    /// 2. Builds the correct `serverUrl` for the new directory (handling root directory case).
    /// 3. Inserts or updates a `tableDirectory` entry with the relevant attributes from the metadata.
    /// 4. Removes any existing `tableMetadata` entries for the same account, file name, and server URL.
    /// 5. Inserts or updates the detached copy of the provided metadata.
    ///
    /// - Parameter metadata: The `tableMetadata` object containing directory information such as
    ///   account, server URL, file name, etag, fileId, ocId, permissions, and workspace.
    /// - Note: The operation is performed asynchronously and thread-safely within `performRealmWriteAsync`.
    func createDirectory(metadata: tableMetadata) async {
        let detached = metadata.detachedCopy()

        await performRealmWriteAsync { realm in
            var directoryServerUrl = self.utilityFileSystem.createServerUrl(serverUrl: metadata.serverUrl, fileName: metadata.fileName)
            if metadata.fileName == NextcloudKit.shared.nkCommonInstance.rootFileName {
                directoryServerUrl = metadata.serverUrl
            }

            // tableDirectory
            if let tableDirectory = realm.object(ofType: tableDirectory.self, forPrimaryKey: metadata.ocId) {
                tableDirectory.etag = metadata.etag
                tableDirectory.favorite = metadata.favorite
                tableDirectory.permissions = metadata.permissions
                tableDirectory.richWorkspace = metadata.richWorkspace
            } else {
                let directory = tableDirectory()
                directory.account = metadata.account
                directory.etag = metadata.etag
                directory.favorite = metadata.favorite
                directory.fileId = metadata.fileId
                directory.ocId = metadata.ocId
                directory.permissions = metadata.permissions
                directory.richWorkspace = metadata.richWorkspace
                directory.serverUrl = directoryServerUrl
                realm.add(directory, update: .all)
            }

            // tableMetadata
            let results = realm.objects(tableMetadata.self)
                .filter("account == %@ AND fileName == %@ AND serverUrl == %@", metadata.account, metadata.fileName, metadata.serverUrl)
            realm.delete(results)
            realm.add(detached, update: .all)
        }
    }

    /// Asynchronously deletes a directory and all its subdirectories, along with their associated metadata and local files.
    ///
    /// This function performs the following steps inside a Realm write transaction:
    /// 1. Retrieves all `tableDirectory` objects for the given `account` whose `serverUrl` starts with the specified path.
    /// 2. For each directory, retrieves related `tableMetadata` entries matching the same account and server URL.
    /// 3. Collects the `ocId` values from those metadata entries and fetches corresponding `tableLocalFile` objects.
    /// 4. Deletes the related local files and metadata from the database.
    /// 5. Deletes the directories themselves from the database.
    ///
    /// - Parameters:
    ///   - serverUrl: The base server URL prefix used to identify the target directory and its subdirectories.
    ///   - account: The account identifier used to scope the deletion.
    /// - Note: The operation is performed asynchronously and thread-safely within `performRealmWriteAsync`.
    func deleteDirectoryAndSubDirectoryAsync(serverUrl: String, account: String) async {
        await performRealmWriteAsync { realm in
            let directories = realm.objects(tableDirectory.self)
                .filter("account == %@ AND serverUrl BEGINSWITH %@", account, serverUrl)

            for directory in directories {
                let metadatas = realm.objects(tableMetadata.self)
                    .filter("account == %@ AND serverUrl == %@", account, directory.serverUrl)

                let ocIds = Array(metadatas.map(\.ocId))
                let localFiles = realm.objects(tableLocalFile.self)
                    .filter("ocId IN %@", ocIds)

                realm.delete(localFiles)
                realm.delete(metadatas)
            }

            realm.delete(directories)
        }
    }

    /// Asynchronously deletes a directory entry from the database by its `ocId`.
    ///
    /// This function performs the following steps inside a Realm write transaction:
    /// 1. Verifies that the provided `ocId` is not `nil`.
    /// 2. Retrieves all `tableDirectory` objects matching the given `ocId`.
    /// 3. Deletes the matching directory entries from the database.
    ///
    /// - Parameter ocId: The unique object identifier (`ocId`) of the directory to delete.
    ///   If `nil`, the function exits without performing any operation.
    /// - Note: The operation is performed asynchronously and thread-safely within `performRealmWriteAsync`.
    func deleteDirectoryOcIdAsync(_ ocId: String?) async {
        guard let ocId else {
            return
        }

        await performRealmWriteAsync { realm in
            let results = realm.objects(tableDirectory.self)
                .filter("ocId == %@", ocId)
            realm.delete(results)
        }
    }

    /// Asynchronously renames a directory by updating its `serverUrl`.
    ///
    /// This function performs the following steps inside a Realm write transaction:
    /// 1. Retrieves the first `tableDirectory` object matching the given `ocId`.
    /// 2. If found, updates the `serverUrl` property of the directory with the provided value.
    /// 3. Persists the change in the database.
    ///
    /// - Parameters:
    ///   - ocId: The unique object identifier (`ocId`) of the directory to rename.
    ///   - serverUrl: The new server URL to assign to the directory.
    /// - Note: The operation is performed asynchronously and thread-safely within `performRealmWriteAsync`.
    func renameDirectoryAsync(ocId: String, serverUrl: String) async {
        await performRealmWriteAsync { realm in
            if let result = realm.objects(tableDirectory.self)
                .filter("ocId == %@", ocId)
                .first {
                result.serverUrl = serverUrl
            }
        }
    }

    /// Asynchronously sets or updates a directory entry in the database with the specified offline state and metadata.
    ///
    /// This function performs the following steps inside a Realm write transaction:
    /// 1. Searches for an existing `tableDirectory` entry matching the given account and server URL.
    /// 2. If found, updates its `offline` property with the provided value.
    /// 3. If not found, creates a new `tableDirectory` entry using the provided metadata and assigns
    ///    the `offline` state and other attributes (favorite, fileId, ocId, permissions, richWorkspace).
    /// 4. Inserts or updates the directory entry in the database.
    ///
    /// - Parameters:
    ///   - serverUrl: The server URL of the directory to set or update.
    ///   - offline: A Boolean flag indicating whether the directory should be marked as available offline.
    ///   - metadata: The `tableMetadata` object containing directory information such as account,
    ///     favorite, fileId, ocId, permissions, and workspace.
    /// - Note: The operation is performed asynchronously and thread-safely within `performRealmWriteAsync`.
    func setDirectoryAsync(serverUrl: String, offline: Bool, metadata: tableMetadata) async {
        await performRealmWriteAsync { realm in
            if let result = realm.objects(tableDirectory.self)
                .filter("account == %@ AND serverUrl == %@", metadata.account, serverUrl)
                .first {
                result.offline = offline
            } else {
                let directory = tableDirectory()
                directory.account = metadata.account
                directory.favorite = metadata.favorite
                directory.fileId = metadata.fileId
                directory.ocId = metadata.ocId
                directory.offline = offline
                directory.permissions = metadata.permissions
                directory.richWorkspace = metadata.richWorkspace
                directory.serverUrl = serverUrl

                realm.add(directory, update: .all)
            }
        }
    }

    /// Asynchronously updates the `richWorkspace` field of a directory entry in the database.
    ///
    /// This function performs the following steps inside a Realm write transaction:
    /// 1. Retrieves the first `tableDirectory` entry matching the given account and server URL.
    /// 2. If found, updates its `richWorkspace` property with the provided value.
    /// 3. Persists the change in the database.
    ///
    /// - Parameters:
    ///   - richWorkspace: The new `richWorkspace` value to assign to the directory. Can be `nil`.
    ///   - account: The account identifier associated with the directory.
    ///   - serverUrl: The server URL of the directory to update.
    /// - Note: The operation is performed asynchronously and thread-safely within `performRealmWriteAsync`.
    func updateDirectoryRichWorkspaceAsync(_ richWorkspace: String?, account: String, serverUrl: String) async {
        await performRealmWriteAsync { realm in
            realm.objects(tableDirectory.self)
                .filter("account == %@ AND serverUrl == %@", account, serverUrl)
                .first?
                .richWorkspace = richWorkspace
        }
    }

    /// Asynchronously updates or creates a directory entry with the specified color folder attribute.
    ///
    /// This function performs the following steps inside a Realm write transaction:
    /// 1. Searches for an existing `tableDirectory` entry matching the given account and server URL.
    /// 2. If found, updates its `colorFolder` property with the provided value.
    /// 3. If not found, creates a new `tableDirectory` entry using the provided metadata and assigns
    ///    the `colorFolder` value and other attributes (favorite, fileId, ocId, permissions, richWorkspace).
    /// 4. Inserts or updates the directory entry in the database.
    ///
    /// - Parameters:
    ///   - colorFolder: The new color folder value to assign to the directory. Can be `nil`.
    ///   - metadata: The `tableMetadata` object containing directory information such as account,
    ///     favorite, fileId, ocId, permissions, and workspace.
    ///   - serverUrl: The server URL of the directory to update or create.
    /// - Note: The operation is performed asynchronously and thread-safely within `performRealmWriteAsync`.
    func updateDirectoryColorFolderAsync(_ colorFolder: String?, metadata: tableMetadata, serverUrl: String) async {
        await performRealmWriteAsync { realm in
            if let result = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl == %@", metadata.account, serverUrl).first {
                result.colorFolder = colorFolder
            } else {
                let directory = tableDirectory()
                directory.account = metadata.account
                directory.colorFolder = colorFolder
                directory.favorite = metadata.favorite
                directory.fileId = metadata.fileId
                directory.ocId = metadata.ocId
                directory.permissions = metadata.permissions
                directory.richWorkspace = metadata.richWorkspace
                directory.serverUrl = serverUrl

                realm.add(directory, update: .all)
            }
        }
    }

    func setDirectoryLastOpeningDateAsync(ocId: String) async {
        await performRealmWriteAsync { realm in
            if let result = realm.objects(tableDirectory.self)
                .filter("ocId == %@", ocId)
                .first {
                result.lastOpeningDate = NSDate()
            }
        }
    }

    // MARK: - Realm Read

    func getTableDirectory(predicate: NSPredicate) -> tableDirectory? {
        return performRealmRead { realm in
            guard let result = realm.objects(tableDirectory.self).filter(predicate).first
            else {
                return nil
            }
            return tableDirectory(value: result)
        }
    }

    func getTableDirectoryAsync(predicate: NSPredicate) async -> tableDirectory? {
        await performRealmReadAsync { realm in
            guard let result = realm.objects(tableDirectory.self).filter(predicate).first else {
                return nil
            }
            return tableDirectory(value: result)
        }
    }

    func getDirectoriesAsync(predicate: NSPredicate) async -> [tableDirectory] {
        await performRealmReadAsync { realm in
            realm.objects(tableDirectory.self)
                .filter(predicate)
                .map { tableDirectory(value: $0) }
        } ?? []
    }

    /// Asynchronously retrieves a detached copy of `tableDirectory` by ocId.
    /// - Parameter ocId: The identifier to query.
    /// - Returns: A detached copy of the matching `tableDirectory`, or `nil` if not found.
    func getTableDirectoryAsync(ocId: String) async -> tableDirectory? {
        await performRealmReadAsync { realm in
            realm.objects(tableDirectory.self)
                .filter("ocId == %@", ocId)
                .first
                .map { tableDirectory(value: $0) }
        }
    }

    func getTableDirectory(ocId: String) -> tableDirectory? {
        return performRealmRead { realm in
            return realm.objects(tableDirectory.self)
                .filter("ocId == %@", ocId)
                .first
                .map { tableDirectory(value: $0) }
        }
    }

    func getTablesDirectoryAsync(predicate: NSPredicate, sorted: String, ascending: Bool) async -> [tableDirectory] {
        await performRealmReadAsync { realm in
            realm.objects(tableDirectory.self)
            .filter(predicate)
            .sorted(byKeyPath: sorted, ascending: ascending)
            .map { tableDirectory(value: $0) }
        } ?? []
    }
}
