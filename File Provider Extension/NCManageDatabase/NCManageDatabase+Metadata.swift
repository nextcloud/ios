// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import RealmSwift

extension NCManageDatabase {
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
}
