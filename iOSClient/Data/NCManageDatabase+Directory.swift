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
    @objc dynamic var e2eEncrypted: Bool = false
    @objc dynamic var etag = ""
    @objc dynamic var favorite: Bool = false
    @objc dynamic var fileId = ""
    @objc dynamic var ocId = ""
    @objc dynamic var offline: Bool = false
    @objc dynamic var offlineDate: Date?
    @objc dynamic var permissions = ""
    @objc dynamic var richWorkspace: String?
    @objc dynamic var serverUrl = ""

    override static func primaryKey() -> String {
        return "ocId"
    }
}

extension NCManageDatabase {

    // MARK: - Realm write

    func addDirectoryAsync(e2eEncrypted: Bool, favorite: Bool, ocId: String, fileId: String, etag: String? = nil, permissions: String? = nil, richWorkspace: String? = nil, serverUrl: String, account: String) async {
        await performRealmWriteAsync { realm in
            if let existing = realm.objects(tableDirectory.self)
                .filter("account == %@ AND ocId == %@", account, ocId)
                .first {

                existing.e2eEncrypted = e2eEncrypted
                existing.favorite = favorite
                if let etag { existing.etag = etag }
                if let permissions { existing.permissions = permissions }
                if let richWorkspace { existing.richWorkspace = richWorkspace }

            } else {
                let directory = tableDirectory()
                directory.e2eEncrypted = e2eEncrypted
                directory.favorite = favorite
                directory.ocId = ocId
                directory.fileId = fileId
                if let etag { directory.etag = etag }
                if let permissions { directory.permissions = permissions }
                if let richWorkspace { directory.richWorkspace = richWorkspace }
                directory.serverUrl = serverUrl
                directory.account = account

                realm.add(directory, update: .modified)
            }
        }
    }

    func addDirectoriesAsync(metadatas: [tableMetadata]) async {
        let detached = metadatas.map { $0.detachedCopy() }

        await performRealmWriteAsync { realm in
            for metadata in detached {
                let existing = realm.objects(tableDirectory.self)
                    .filter("account == %@ AND ocId == %@", metadata.account, metadata.ocId)
                    .first

                if let existing {
                    existing.e2eEncrypted = metadata.e2eEncrypted
                    existing.favorite = metadata.favorite
                    existing.etag = metadata.etag
                    existing.permissions = metadata.permissions
                    existing.richWorkspace = metadata.richWorkspace
                } else {
                    let directory = tableDirectory()
                    directory.account = metadata.account
                    directory.e2eEncrypted = metadata.e2eEncrypted
                    directory.etag = metadata.etag
                    directory.favorite = metadata.favorite
                    directory.fileId = metadata.fileId
                    directory.ocId = metadata.ocId
                    directory.permissions = metadata.permissions
                    directory.richWorkspace = metadata.richWorkspace
                    directory.serverUrl = metadata.serverUrlFileName
                    realm.add(directory, update: .modified)
                }
            }
        }
    }

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

    func deleteDirectoryOcIdAsync(_ ocId: String?) async {
        guard let ocId else { return }

        await performRealmWriteAsync { realm in
            let results = realm.objects(tableDirectory.self)
                .filter("ocId == %@", ocId)
            realm.delete(results)
        }
    }

    func setDirectoryAsync(serverUrl: String, serverUrlTo: String? = nil, etag: String? = nil, ocId: String? = nil, fileId: String? = nil, encrypted: Bool, richWorkspace: String? = nil, account: String) async {
        await performRealmWriteAsync { realm in
            if let result = realm.objects(tableDirectory.self)
                .filter("account == %@ AND serverUrl == %@", account, serverUrl)
                .first {

                result.e2eEncrypted = encrypted

                if let etag = etag {
                    result.etag = etag
                }
                if let ocId = ocId {
                    result.ocId = ocId
                }
                if let fileId = fileId {
                    result.fileId = fileId
                }
                if let serverUrlTo = serverUrlTo {
                    result.serverUrl = serverUrlTo
                }
                if let richWorkspace = richWorkspace {
                    result.richWorkspace = richWorkspace
                }

                realm.add(result, update: .modified)
            }
        }
    }

    func renameDirectoryAsync(ocId: String, serverUrl: String) async {
        await performRealmWriteAsync { realm in
            if let result = realm.objects(tableDirectory.self)
                .filter("ocId == %@", ocId)
                .first {
                result.serverUrl = serverUrl
            }
        }
    }

    func setDirectoryAsync(serverUrl: String, offline: Bool, metadata: tableMetadata) async {
        await performRealmWriteAsync { realm in
            if let result = realm.objects(tableDirectory.self)
                .filter("account == %@ AND serverUrl == %@", metadata.account, serverUrl)
                .first {
                result.offline = offline
            } else {
                let directory = tableDirectory()
                directory.account = metadata.account
                directory.serverUrl = serverUrl
                directory.offline = offline
                directory.e2eEncrypted = metadata.e2eEncrypted
                directory.favorite = metadata.favorite
                directory.fileId = metadata.fileId
                directory.ocId = metadata.ocId
                directory.permissions = metadata.permissions
                directory.richWorkspace = metadata.richWorkspace

                realm.add(directory, update: .all)
            }
        }
    }

    func setDirectorySynchronizationDateAsync(serverUrl: String, account: String) async {
        await performRealmWriteAsync { realm in
            realm.objects(tableDirectory.self)
                .filter("account == %@ AND serverUrl == %@", account, serverUrl)
                .first?
                .offlineDate = Date()
        }
    }

    func updateDirectoryRichWorkspaceAsync(_ richWorkspace: String?, account: String, serverUrl: String) async {
        await performRealmWriteAsync { realm in
            realm.objects(tableDirectory.self)
                .filter("account == %@ AND serverUrl == %@", account, serverUrl)
                .first?
                .richWorkspace = richWorkspace
        }
    }

    func updateDirectoryColorFolderAsync(_ colorFolder: String?, metadata: tableMetadata, serverUrl: String) async {
        await performRealmWriteAsync { realm in
            if let result = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl == %@", metadata.account, serverUrl).first {
                result.colorFolder = colorFolder
            } else {
                let directory = tableDirectory()
                directory.account = metadata.account
                directory.serverUrl = serverUrl
                directory.colorFolder = colorFolder
                directory.e2eEncrypted = metadata.e2eEncrypted
                directory.favorite = metadata.favorite
                directory.fileId = metadata.fileId
                directory.ocId = metadata.ocId
                directory.permissions = metadata.permissions
                directory.richWorkspace = metadata.richWorkspace

                realm.add(directory, update: .all)
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

    func getTableLocalFilesAsync(predicate: NSPredicate) async -> [tableLocalFile] {
        await performRealmReadAsync { realm in
            realm.objects(tableLocalFile.self)
                .filter(predicate)
                .map { tableLocalFile(value: $0) }
        } ?? []
    }

    func getTableDirectory(account: String, serverUrl: String) -> tableDirectory? {
        return performRealmRead { realm in
            realm.objects(tableDirectory.self)
                .filter("account == %@ AND serverUrl == %@", account, serverUrl)
                .first
        }
    }

    func getTableDirectoryAsync(account: String, serverUrl: String) async -> tableDirectory? {
        await performRealmReadAsync { realm in
            realm.objects(tableDirectory.self)
                .filter("account == %@ AND serverUrl == %@", account, serverUrl)
                .first
                .map { tableDirectory(value: $0) } // detached copy
        }
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
