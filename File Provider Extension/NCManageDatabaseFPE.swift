// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import RealmSwift

final class NCManageDatabaseFPE {
    static let shared = NCManageDatabaseFPE()

    internal let core: NCManageDatabaseCore

    init() {
        self.core = NCManageDatabaseCore()
        guard let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup) else {
            return
        }
        let databaseFileUrl = dirGroup.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud + "/" + databaseName)
        let objectTypes = [
            NCKeyValue.self, tableMetadata.self, tableLocalFile.self,
            tableDirectory.self, tableTag.self, tableAccount.self
        ]

        do {
            // Migration configuration
            let migrationCfg = Realm.Configuration(fileURL: databaseFileUrl,
                                                   schemaVersion: databaseSchemaVersion,
                                                   migrationBlock: { migration, oldSchemaVersion in
                self.core.migrationSchema(migration, oldSchemaVersion)
            })
            try autoreleasepool {
                _ = try Realm(configuration: migrationCfg)
            }

            // Runtime and default configuration
            let runtimeCfg = Realm.Configuration(fileURL: databaseFileUrl, schemaVersion: databaseSchemaVersion, objectTypes: objectTypes)
            Realm.Configuration.defaultConfiguration = runtimeCfg

            let realm = try Realm(configuration: runtimeCfg)
            if let url = realm.configuration.fileURL {
                nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .start, message: "Realm is located at: \(url.path)", consoleOnly: true)
            }
        } catch let error {
            nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .error, message: "Realm error: \(error)")
            isSuspendingDatabaseOperation = true
        }
    }

    func getAllTableAccount() -> [tableAccount] {
        core.performRealmRead { realm in
            let sorted = [SortDescriptor(keyPath: "active", ascending: false),
                          SortDescriptor(keyPath: "user", ascending: true)]
            let results = realm.objects(tableAccount.self)
                        .sorted(by: sorted)
            return results.map { tableAccount(value: $0) }
        } ?? []
    }

    func getActiveTableAccount() -> tableAccount? {
        core.performRealmRead { realm in
            realm.objects(tableAccount.self)
                .filter("active == true")
                .first
                .map { tableAccount(value: $0) }
        }
    }

    func addMetadataIfNotExistsAsync(_ metadata: tableMetadata) async {
        let detached = metadata.detachedCopy()

        await core.performRealmWriteAsync { realm in
            if realm.object(ofType: tableMetadata.self, forPrimaryKey: metadata.ocId) == nil {
                realm.add(detached)
            }
        }
    }

    func getMetadataFromOcIdAsync(_ ocId: String?) async -> tableMetadata? {
        guard let ocId else { return nil }

        return await core.performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first
                .map { $0.detachedCopy() }
        }
    }

    func getMetadataAsync(predicate: NSPredicate) async -> tableMetadata? {
        return await core.performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter(predicate)
                .first
                .map { $0.detachedCopy() }
        }
    }

    @discardableResult
    func setMetadataSessionAsync(account: String? = nil,
                                 ocId: String? = nil,
                                 serverUrlFileName: String? = nil,
                                 newFileName: String? = nil,
                                 session: String? = nil,
                                 sessionTaskIdentifier: Int? = nil,
                                 sessionError: String? = nil,
                                 selector: String? = nil,
                                 status: Int? = nil,
                                 etag: String? = nil,
                                 errorCode: Int? = nil) async -> tableMetadata? {
        var query: NSPredicate = NSPredicate()
        if let ocId {
            query = NSPredicate(format: "ocId == %@", ocId)
        } else if let account, let serverUrlFileName {
            query = NSPredicate(format: "account == %@ AND serverUrlFileName == %@", account, serverUrlFileName)
        } else {
            return nil
        }

        await core.performRealmWriteAsync { realm in
            guard let metadata = realm.objects(tableMetadata.self)
                .filter(query)
                .first else {
                    return
            }

            metadata.sessionDate = Date()

            if let name = newFileName {
                metadata.fileName = name
                metadata.fileNameView = name
            }

            if let session {
                metadata.session = session
            }

            if let sessionTaskIdentifier {
                metadata.sessionTaskIdentifier = sessionTaskIdentifier
            }

            if let sessionError {
                metadata.sessionError = sessionError
                if sessionError.isEmpty {
                    metadata.errorCode = 0
                }
            }

            if let selector {
                metadata.sessionSelector = selector
            }

            if let status {
                metadata.status = status
                switch status {
                case NCGlobal.shared.metadataStatusWaitDownload,
                     NCGlobal.shared.metadataStatusWaitUpload:
                    metadata.sessionDate = Date()
                case NCGlobal.shared.metadataStatusNormal:
                    metadata.sessionDate = nil
                default: break
                }
            }

            if let etag {
                metadata.etag = etag
            }

            if let errorCode {
                metadata.errorCode = errorCode
            }
        }

        return await core.performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter(query)
                .first?
                .detachedCopy()
        }
    }

    func addLocalFilesAsync(metadatas: [tableMetadata], offline: Bool? = nil) async {
        guard !metadatas.isEmpty else {
            return
        }

        // Extract ocIds for efficient lookup
        let ocIds = metadatas.compactMap { $0.ocId }
        guard !ocIds.isEmpty else {
            return
        }

        // Preload existing entries to avoid creating duplicates
        let existingMap: [String: tableLocalFile] = await core.performRealmReadAsync { realm in
                let existing = realm.objects(tableLocalFile.self)
                    .filter(NSPredicate(format: "ocId IN %@", ocIds))
                return Dictionary(uniqueKeysWithValues:
                    existing.map { ($0.ocId, tableLocalFile(value: $0)) } // detached copy via value init
                )
            } ?? [:]

        await core.performRealmWriteAsync { realm in
            for metadata in metadatas {
                // Reuse existing object or create a new one
                let local = existingMap[metadata.ocId] ?? tableLocalFile()

                local.account = metadata.account
                local.etag = metadata.etag
                local.exifDate = NSDate()
                local.exifLatitude = "-1"
                local.exifLongitude = "-1"
                local.ocId = metadata.ocId
                local.fileName = metadata.fileName

                if let offline {
                    local.offline = offline
                }

                realm.add(local, update: .all)
            }
        }
    }

    func deleteMetadataAsync(predicate: NSPredicate) async {
        await core.performRealmWriteAsync { realm in
            let result = realm.objects(tableMetadata.self)
                .filter(predicate)
            realm.delete(result)
        }
    }

    func deleteMetadataAsync(id: String?) async {
        guard let id else { return }

        await core.performRealmWriteAsync { realm in
            let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@ OR fileId == %@", id, id)
            realm.delete(result)
        }
    }

    func addMetadataAsync(_ metadata: tableMetadata) async {
        let detached = metadata.detachedCopy()

        await core.performRealmWriteAsync { realm in
            realm.add(detached, update: .all)
        }
    }

    func getAllTableAccountAsync() async -> [tableAccount] {
        await core.performRealmReadAsync { realm in
            let sorted = [
                SortDescriptor(keyPath: "active", ascending: false),
                SortDescriptor(keyPath: "user", ascending: true)
            ]
            let results = realm.objects(tableAccount.self)
                               .sorted(by: sorted)
            return results.map { tableAccount(value: $0) } // detached copy
        } ?? []
    }

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

    func deleteLocalFileAsync(id: String?) async {
        guard let id else { return }

        await core.performRealmWriteAsync { realm in
            let results = realm.objects(tableLocalFile.self)
                .filter("ocId == %@", id)
            realm.delete(results)
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

    func moveMetadataAsync(ocId: String, serverUrlTo: String) async {
        await core.performRealmWriteAsync { realm in
            if let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first {
                result.serverUrl = serverUrlTo
            }
        }
    }

    func renameMetadata(fileNameNew: String, ocId: String, status: Int = NCGlobal.shared.metadataStatusNormal) async {
        await core.performRealmWriteAsync { realm in
            guard let metadata = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first else {
                return
            }

            let oldFileNameView = metadata.fileNameView
            let account = metadata.account
            let originalServerUrl = metadata.serverUrl

            metadata.fileName = fileNameNew
            metadata.fileNameView = fileNameNew
            metadata.status = status
            metadata.sessionDate = (status == NCGlobal.shared.metadataStatusNormal) ? nil : Date()

            if metadata.directory {
                let oldDirUrl = NCUtilityFileSystem().createServerUrl(serverUrl: originalServerUrl, fileName: oldFileNameView)
                let newDirUrl = NCUtilityFileSystem().createServerUrl(serverUrl: originalServerUrl, fileName: fileNameNew)

                if let dir = realm.objects(tableDirectory.self)
                    .filter("account == %@ AND serverUrl == %@", account, oldDirUrl)
                    .first {
                    dir.serverUrl = newDirUrl
                }
            } else {
                let atPath = NCUtilityFileSystem().getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase) + "/" + oldFileNameView
                let toPath = NCUtilityFileSystem().getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase) + "/" + fileNameNew
                NCUtilityFileSystem().moveFile(atPath: atPath, toPath: toPath)
            }
        }
    }


    func setMetadataServerUrlFileNameStatusNormalAsync(ocId: String) async {
        await core.performRealmWriteAsync { realm in
            if let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first {
                result.serverUrlFileName = NCUtilityFileSystem().createServerUrl(serverUrl: result.serverUrl, fileName: result.fileName)
                result.status = NCGlobal.shared.metadataStatusNormal
                result.sessionDate = nil
            }
        }
    }

    func getMetadataFromOcId(_ ocId: String?) -> tableMetadata? {
        guard let ocId else { return nil }

        return core.performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first
                .map { $0.detachedCopy() }
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

    func getTableMetadatasDirectoryFavoriteIdentifierRankAsync(account: String) async -> [String: NSNumber] {
        let result = await core.performRealmReadAsync { realm in
            var listIdentifierRank: [String: NSNumber] = [:]
            var counter = Int64(10)

            let results = realm.objects(tableMetadata.self)
                .filter("account == %@ AND directory == true AND favorite == true", account)
                .sorted(byKeyPath: "fileNameView", ascending: true)

            results.forEach { item in
                counter += 1
                listIdentifierRank[item.ocId] = NSNumber(value: counter)
            }

            return listIdentifierRank
        }
        return result ?? [:]
    }

    func getResultsMetadatasAsync(predicate: NSPredicate) async -> Results<tableMetadata>? {
        await core.performRealmReadAsync { realm in
            let results = realm.objects(tableMetadata.self)
                .filter(predicate)
            return results.freeze()
        }
    }

    func getMetadata(predicate: NSPredicate) -> tableMetadata? {
        return core.performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter(predicate)
                .first
                .map { $0.detachedCopy() }
        }
    }

    func getMetadataFromOcIdAndocIdTransferAsync(_ ocId: String?) async -> tableMetadata? {
        guard let ocId else {
            return nil
        }

        return await core.performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter("ocId == %@ OR ocIdTransfer == %@", ocId, ocId)
                .first
                .map { $0.detachedCopy() }
        }
    }

    func getTableLocalFileAsync(predicate: NSPredicate) async -> tableLocalFile? {
        await core.performRealmReadAsync { realm in
            realm.objects(tableLocalFile.self)
                .filter(predicate)
                .first
                .map { tableLocalFile(value: $0) }
        }
    }

    func addTagAsunc(_ ocId: String, tagIOS: Data?, account: String) async {
        await core.performRealmWriteAsync { realm in
            let addObject = tableTag()
            addObject.account = account
            addObject.ocId = ocId
            addObject.tagIOS = tagIOS
            realm.add(addObject, update: .all)
        }
    }

    func getTagsAsync(predicate: NSPredicate) async -> [tableTag]? {
        await core.performRealmReadAsync { realm in
            let results = realm.objects(tableTag.self)
                .filter(predicate)
            return results.compactMap { tableTag(value: $0) }
        }
    }

    func getTags(predicate: NSPredicate) -> [tableTag]? {
        core.performRealmRead { realm in
            let results = realm.objects(tableTag.self)
                .filter(predicate)
            return results.compactMap { tableTag(value: $0) }
        }
    }

    func getTagAsync(predicate: NSPredicate) async -> tableTag? {
        await core.performRealmReadAsync { realm in
            return realm.objects(tableTag.self)
                .filter(predicate)
                .first.map { tableTag(value: $0) }
        }
    }

    func getTag(predicate: NSPredicate) -> tableTag? {
        var tag: tableTag?

        core.performRealmRead { realm in
            tag = realm.objects(tableTag.self)
                .filter(predicate)
                .first.map {
                    tableTag(value: $0)
                }
        }
        return tag
    }
}
