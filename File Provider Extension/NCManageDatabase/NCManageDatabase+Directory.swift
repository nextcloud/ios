// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import RealmSwift

extension NCManageDatabase {
    func createDirectory(metadata: tableMetadata, withEtag: Bool = true) async {
        let detached = metadata.detachedCopy()

        await core.performRealmWriteAsync { realm in
            var directoryServerUrl = NCUtilityFileSystem().createServerUrl(serverUrl: metadata.serverUrl, fileName: metadata.fileName)
            if metadata.fileName == NextcloudKit.shared.nkCommonInstance.rootFileName {
                directoryServerUrl = metadata.serverUrl
            }

            // tableDirectory
            if let tableDirectory = realm.object(ofType: tableDirectory.self, forPrimaryKey: metadata.ocId) {
                if withEtag {
                    tableDirectory.etag = metadata.etag
                }
                tableDirectory.favorite = metadata.favorite
                tableDirectory.permissions = metadata.permissions
                tableDirectory.richWorkspace = metadata.richWorkspace
                tableDirectory.lastSyncDate = NSDate()
            } else {
                let directory = tableDirectory()
                directory.account = metadata.account
                if withEtag {
                    directory.etag = metadata.etag
                }
                directory.favorite = metadata.favorite
                directory.fileId = metadata.fileId
                directory.ocId = metadata.ocId
                directory.permissions = metadata.permissions
                directory.richWorkspace = metadata.richWorkspace
                directory.serverUrl = directoryServerUrl
                directory.lastSyncDate = NSDate()
                realm.add(directory, update: .all)
            }

            // tableMetadata
            let results = realm.objects(tableMetadata.self)
                .filter("account == %@ AND fileName == %@ AND serverUrl == %@", metadata.account, metadata.fileName, metadata.serverUrl)
            realm.delete(results)
            realm.add(detached, update: .all)
        }
    }

    func deleteDirectoryAndSubDirectoryAsync(serverUrl: String, account: String) async {
        await core.performRealmWriteAsync { realm in
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

    func renameDirectoryAsync(ocId: String, serverUrl: String) async {
        await core.performRealmWriteAsync { realm in
            if let result = realm.objects(tableDirectory.self)
                .filter("ocId == %@", ocId)
                .first {
                result.serverUrl = serverUrl
            }
        }
    }

    func getTableDirectory(predicate: NSPredicate) -> tableDirectory? {
        return core.performRealmRead { realm in
            guard let result = realm.objects(tableDirectory.self).filter(predicate).first
            else {
                return nil
            }
            return tableDirectory(value: result)
        }
    }

    func getTableDirectoryAsync(predicate: NSPredicate) async -> tableDirectory? {
        await core.performRealmReadAsync { realm in
            guard let result = realm.objects(tableDirectory.self).filter(predicate).first else {
                return nil
            }
            return tableDirectory(value: result)
        }
    }
}
