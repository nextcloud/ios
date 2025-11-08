// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit
import Photos

extension NCManageDatabase {
    func isMetadataShareOrMounted(metadata: tableMetadata, metadataFolder: tableMetadata?) -> Bool {
        var isShare = false
        var isMounted = false

        if metadataFolder != nil {
            isShare = metadata.permissions.contains(NCMetadataPermissions.permissionShared) && !metadataFolder!.permissions.contains(NCMetadataPermissions.permissionShared)
            isMounted = metadata.permissions.contains(NCMetadataPermissions.permissionMounted) && !metadataFolder!.permissions.contains(NCMetadataPermissions.permissionMounted)
        } else if let directory = getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
            isShare = metadata.permissions.contains(NCMetadataPermissions.permissionShared) && !directory.permissions.contains(NCMetadataPermissions.permissionShared)
            isMounted = metadata.permissions.contains(NCMetadataPermissions.permissionMounted) && !directory.permissions.contains(NCMetadataPermissions.permissionMounted)
        }

        if isShare || isMounted {
            return true
        } else {
            return false
        }
    }

    // MARK: - Realm Write

    func addAndReturnMetadata(_ metadata: tableMetadata) -> tableMetadata? {
        let detached = metadata.detachedCopy()

        core.performRealmWrite { realm in
            realm.add(detached, update: .all)
        }

        return core.performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter("ocId == %@", metadata.ocId)
                .first
                .map { $0.detachedCopy() }
        }
    }

    func addAndReturnMetadataAsync(_ metadata: tableMetadata) async -> tableMetadata? {
        let detached = metadata.detachedCopy()

        await core.performRealmWriteAsync { realm in
            realm.add(detached, update: .all)
        }

        return await core.performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter("ocId == %@", metadata.ocId)
                .first?
                .detachedCopy()
        }
    }

    func addMetadata(_ metadata: tableMetadata, sync: Bool = true) {
        let detached = metadata.detachedCopy()

        core.performRealmWrite(sync: sync) { realm in
            realm.add(detached, update: .all)
        }
    }

    func addMetadataAsync(_ metadata: tableMetadata) async {
        let detached = metadata.detachedCopy()

        await core.performRealmWriteAsync { realm in
            realm.add(detached, update: .all)
        }
    }

    func addMetadatas(_ metadatas: [tableMetadata], sync: Bool = true) {
        let detached = metadatas.map { $0.detachedCopy() }

        core.performRealmWrite(sync: sync) { realm in
            realm.add(detached, update: .all)
        }
    }

    func addMetadatasAsync(_ metadatas: [tableMetadata]) async {
        let detached = metadatas.map { $0.detachedCopy() }

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

    func replaceMetadataAsync(id: String, metadata: tableMetadata) async {
        let detached = metadata.detachedCopy()

        await core.performRealmWriteAsync { realm in
            let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@ OR ocIdTransfer == %@", id, id)
            realm.delete(result)
            realm.add(detached, update: .all)
        }
    }

    func replaceMetadataAsync(ocIdTransfersToDelete: [String], metadatas: [tableMetadata]) async {
        guard !ocIdTransfersToDelete.isEmpty else {
            return
        }
        var detached: [tableMetadata] = []
        for metadata in metadatas {
            detached.append(metadata.detachedCopy())
        }

        await core.performRealmWriteAsync { realm in
            let result = realm.objects(tableMetadata.self)
                .filter("ocIdTransfer IN %@", ocIdTransfersToDelete)
            realm.delete(result)
            realm.add(detached, update: .all)
        }
    }

    // Asynchronously deletes an array of `tableMetadata` entries from the Realm database.
    /// - Parameter metadatas: The `tableMetadata` objects to be deleted.
    func deleteMetadatasAsync(_ metadatas: [tableMetadata]) async {
        guard !metadatas.isEmpty else {
            return
        }
        let detached = metadatas.map { $0.detachedCopy() }

        await core.performRealmWriteAsync { realm in
            for detached in detached {
                if let managed = realm.object(ofType: tableMetadata.self, forPrimaryKey: detached.ocId) {
                    realm.delete(managed)
                }
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
                let oldDirUrl = self.utilityFileSystem.createServerUrl(serverUrl: originalServerUrl, fileName: oldFileNameView)
                let newDirUrl = self.utilityFileSystem.createServerUrl(serverUrl: originalServerUrl, fileName: fileNameNew)

                if let dir = realm.objects(tableDirectory.self)
                    .filter("account == %@ AND serverUrl == %@", account, oldDirUrl)
                    .first {
                    dir.serverUrl = newDirUrl
                }
            } else {
                let atPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase) + "/" + oldFileNameView
                let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase) + "/" + fileNameNew
                self.utilityFileSystem.moveFile(atPath: atPath, toPath: toPath)
            }
        }
    }

    /// Asynchronously restores the file name of a metadata entry and updates related file system and Realm entries.
    /// - Parameter ocId: The object ID (ocId) of the file to restore.
    func restoreMetadataFileNameAsync(ocId: String) async {
        await core.performRealmWriteAsync { realm in
            guard let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first,
                  let encodedURLString = result.serverUrlFileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: encodedURLString)
            else {
                return
            }

            let fileIdMOV = result.livePhotoFile
            let directoryServerUrl = self.utilityFileSystem.createServerUrl(serverUrl: result.serverUrl, fileName: result.fileNameView)
            let lastPathComponent = url.lastPathComponent
            let fileName = lastPathComponent.removingPercentEncoding ?? lastPathComponent
            let fileNameView = result.fileNameView

            result.fileName = fileName
            result.fileNameView = fileName
            result.status = NCGlobal.shared.metadataStatusNormal
            result.sessionDate = nil

            if result.directory,
               let resultDirectory = realm.objects(tableDirectory.self)
                   .filter("account == %@ AND serverUrl == %@", result.account, directoryServerUrl)
                   .first {
                let serverUrlTo = self.utilityFileSystem.createServerUrl(serverUrl: result.serverUrl, fileName: fileName)
                resultDirectory.serverUrl = serverUrlTo
            } else {
                let atPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(result.ocId, userId: result.userId, urlBase: result.urlBase) + "/" + fileNameView
                let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(result.ocId, userId: result.userId, urlBase: result.urlBase) + "/" + fileName
                self.utilityFileSystem.moveFile(atPath: atPath, toPath: toPath)
            }

            if result.isLivePhoto,
               let resultMOV = realm.objects(tableMetadata.self)
                   .filter("fileId == %@ AND account == %@", fileIdMOV, result.account)
                   .first {
                let fileNameViewMOV = resultMOV.fileNameView
                let baseName = (fileName as NSString).deletingPathExtension
                let ext = (resultMOV.fileName as NSString).pathExtension
                let fullFileName = baseName + "." + ext

                resultMOV.fileName = fullFileName
                resultMOV.fileNameView = fullFileName

                let atPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(resultMOV.ocId, userId: resultMOV.userId, urlBase: resultMOV.urlBase) + "/" + fileNameViewMOV
                let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(resultMOV.ocId, userId: resultMOV.userId, urlBase: resultMOV.urlBase) + "/" + fullFileName
                self.utilityFileSystem.moveFile(atPath: atPath, toPath: toPath)
            }
        }
    }

    func setMetadataServerUrlFileNameStatusNormalAsync(ocId: String) async {
        await core.performRealmWriteAsync { realm in
            if let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first {
                result.serverUrlFileName = self.utilityFileSystem.createServerUrl(serverUrl: result.serverUrl, fileName: result.fileName)
                result.status = NCGlobal.shared.metadataStatusNormal
                result.sessionDate = nil
            }
        }
    }

    func setMetadataLivePhotoByServerAsync(account: String,
                                           ocId: String,
                                           livePhotoFile: String) async {
        await core.performRealmWriteAsync { realm in
            if let result = realm.objects(tableMetadata.self)
                .filter("account == %@ AND ocId == %@", account, ocId)
                .first {
                result.isFlaggedAsLivePhotoByServer = true
                result.livePhotoFile = livePhotoFile
            }
        }
    }

    func updateMetadatasFavoriteAsync(account: String, metadatas: [tableMetadata]) async {
        guard !metadatas.isEmpty else { return }

        await core.performRealmWriteAsync { realm in
            let oldFavorites = realm.objects(tableMetadata.self)
                .filter("account == %@ AND favorite == true", account)
            for item in oldFavorites {
                item.favorite = false
            }
            realm.add(metadatas, update: .all)
        }
    }

    /// Asynchronously updates a list of `tableMetadata` entries in Realm for a given account and server URL.
    ///
    /// This function performs the following steps:
    /// 1. Skips all entries with `status != metadataStatusNormal`.
    /// 2. Deletes existing metadata entries with `status == metadataStatusNormal` that are not in the skip list.
    /// 3. Copies matching `mediaSearch` from previously deleted metadata to the incoming list.
    /// 4. Inserts or updates new metadata entries into Realm, except those in the skip list.
    ///
    /// - Parameters:
    ///   - metadatas: An array of incoming detached `tableMetadata` objects to insert or update.
    ///   - serverUrl: The server URL associated with the metadata entries.
    ///   - account: The account identifier used to scope the metadata update.
    func updateMetadatasFilesAsync(_ metadatas: [tableMetadata], serverUrl: String, account: String) async {
        await core.performRealmWriteAsync { realm in
            let ocIdsToSkip = Set(
                realm.objects(tableMetadata.self)
                    .filter("status != %d", NCGlobal.shared.metadataStatusNormal)
                    .map(\.ocId)
            )

            let resultsToDelete = realm.objects(tableMetadata.self)
                .filter("account == %@ AND serverUrl == %@ AND status == %d AND fileName != %@", account, serverUrl, NCGlobal.shared.metadataStatusNormal, NextcloudKit.shared.nkCommonInstance.rootFileName)
                .filter { !ocIdsToSkip.contains($0.ocId) }
            let metadatasCopy = Array(resultsToDelete).map { tableMetadata(value: $0) }

            realm.delete(resultsToDelete)

            for metadata in metadatas {
                guard !ocIdsToSkip.contains(metadata.ocId) else {
                    continue
                }
                if let match = metadatasCopy.first(where: { $0.ocId == metadata.ocId }) {
                    metadata.mediaSearch = match.mediaSearch
                }
                realm.add(metadata.detachedCopy(), update: .all)
            }
        }
    }

    func setMetadataEncryptedAsync(ocId: String, encrypted: Bool) async {
        await core.performRealmWriteAsync { realm in
            let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first
            result?.e2eEncrypted = encrypted
        }
    }

    func setMetadataFileNameViewAsync(serverUrl: String, fileName: String, newFileNameView: String, account: String) async {
        await core.performRealmWriteAsync { realm in
            let result = realm.objects(tableMetadata.self)
                .filter("account == %@ AND serverUrl == %@ AND fileName == %@", account, serverUrl, fileName)
                .first
            result?.fileNameView = newFileNameView
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

    func setLivePhotoFile(fileId: String, livePhotoFile: String) async {
        await core.performRealmWriteAsync { realm in
            let result = realm.objects(tableMetadata.self)
                .filter("fileId == %@", fileId)
                .first
            result?.livePhotoFile = livePhotoFile
        }
    }

    func clearAssetLocalIdentifiersAsync(_ assetLocalIdentifiers: [String]) async {
        await core.performRealmWriteAsync { realm in
            let results = realm.objects(tableMetadata.self)
                .filter("assetLocalIdentifier IN %@", assetLocalIdentifiers)
            for result in results {
                result.assetLocalIdentifier = ""
            }
        }
    }

    /// Asynchronously sets the favorite status of a `tableMetadata` entry.
    /// Optionally stores the previous favorite flag and updates the sync status.
    func setMetadataFavoriteAsync(ocId: String, favorite: Bool?, saveOldFavorite: String?, status: Int) async {
        await core.performRealmWriteAsync { realm in
            guard let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first else {
                return
            }

            if let favorite {
                result.favorite = favorite
            }

            result.storeFlag = saveOldFavorite
            result.status = status
            result.sessionDate = (status == NCGlobal.shared.metadataStatusNormal) ? nil : Date()
        }
    }

    /// Asynchronously updates a `tableMetadata` entry to set copy/move status and target server URL.
    func setMetadataCopyMoveAsync(ocId: String, destination: String, overwrite: String?, status: Int) async {
        await core.performRealmWriteAsync { realm in
            guard let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first else {
                return
            }

            result.destination = destination
            result.storeFlag = overwrite
            result.status = status
            result.sessionDate = (status == NCGlobal.shared.metadataStatusNormal) ? nil : Date()
        }
    }

    func clearMetadatasUploadAsync(account: String) async {
        await core.performRealmWriteAsync { realm in
            let results = realm.objects(tableMetadata.self)
                .filter("account == %@ AND (status == %d OR status == %d)", account, NCGlobal.shared.metadataStatusWaitUpload, NCGlobal.shared.metadataStatusUploadError)
            realm.delete(results)
        }
    }

    /// Syncs the remote and local metadata.
    /// Returns true if there were changes (additions or deletions), false if everything was already up-to-date.
    func mergeRemoteMetadatasAsync(remoteMetadatas: [tableMetadata], localMetadatas: [tableMetadata]) async -> Bool {
        // Set of ocId
        let remoteOcIds = Set(remoteMetadatas.map { $0.ocId })
        let localOcIds = Set(localMetadatas.map { $0.ocId })

        // Calculate diffs
        let toDeleteOcIds = localOcIds.subtracting(remoteOcIds)
        let toAddOcIds = remoteOcIds.subtracting(localOcIds)

        guard !toDeleteOcIds.isEmpty || !toAddOcIds.isEmpty else {
            return false // No changes needed
        }

        let toDeleteKeys = Array(toDeleteOcIds)

        await core.performRealmWriteAsync { realm in
            let toAdd = remoteMetadatas.filter { toAddOcIds.contains($0.ocId) }
            let toDelete = toDeleteKeys.compactMap {
                realm.object(ofType: tableMetadata.self, forPrimaryKey: $0)
            }

            realm.delete(toDelete)
            realm.add(toAdd, update: .modified)
        }

        return true
    }

    // MARK: - Realm Read

    func getAllTableMetadataAsync() async -> [tableMetadata] {
        return await core.performRealmReadAsync { realm in
            realm.objects(tableMetadata.self).map { tableMetadata(value: $0) }
        } ?? []
    }

    func getMetadata(predicate: NSPredicate) -> tableMetadata? {
        return core.performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter(predicate)
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

    func getMetadatas(predicate: NSPredicate) -> [tableMetadata] {
        core.performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter(predicate)
                .map { $0.detachedCopy() }
        } ?? []
    }

    func getMetadatas(predicate: NSPredicate,
                      sortedByKeyPath: String,
                      ascending: Bool = false) -> [tableMetadata]? {
        return core.performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter(predicate)
                .sorted(byKeyPath: sortedByKeyPath, ascending: ascending)
                .map { $0.detachedCopy() }
        }
    }

    func getMetadatasAsync(predicate: NSPredicate,
                           sortedByKeyPath: String,
                           ascending: Bool = false,
                           limit: Int? = nil) async -> [tableMetadata]? {
        return await core.performRealmReadAsync { realm in
            let results = realm.objects(tableMetadata.self)
                .filter(predicate)
                .sorted(byKeyPath: sortedByKeyPath,
                        ascending: ascending)

            if let limit {
                let sliced = results.prefix(limit)
                return sliced.map { $0.detachedCopy() }
            } else {
                return results.map { $0.detachedCopy() }
            }
        }
    }

    func getMetadatas(predicate: NSPredicate,
                      numItems: Int,
                      sorted: String,
                      ascending: Bool) -> [tableMetadata] {
        return core.performRealmRead { realm in
            let results = realm.objects(tableMetadata.self)
                .filter(predicate)
                .sorted(byKeyPath: sorted, ascending: ascending)
            return results.prefix(numItems)
                .map { $0.detachedCopy() }
        } ?? []
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

    func getMetadataFromOcIdAsync(_ ocId: String?) async -> tableMetadata? {
        guard let ocId else { return nil }

        return await core.performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
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

    /// Asynchronously retrieves the metadata for a folder, based on its session and serverUrl.
    /// Handles the home directory case rootFileName) and detaches the Realm object before returning.
    func getMetadataFolderAsync(session: NCSession.Session, serverUrl: String) async -> tableMetadata? {
        var serverUrl = serverUrl
        var fileName = ""
        let home = utilityFileSystem.getHomeServer(session: session)

        if home == serverUrl {
            fileName = NextcloudKit.shared.nkCommonInstance.rootFileName
        } else {
            fileName = (serverUrl as NSString).lastPathComponent
            if let serverDirectoryUp = utilityFileSystem.serverDirectoryUp(serverUrl: serverUrl, home: home) {
                serverUrl = serverDirectoryUp
            }
        }

        return await core.performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter("account == %@ AND serverUrl == %@ AND fileName == %@", session.account, serverUrl, fileName)
                .first
                .map { $0.detachedCopy() }
        }
    }

    func getMetadataLivePhoto(metadata: tableMetadata) -> tableMetadata? {
        guard metadata.isLivePhoto else {
            return nil
        }
        let detached = metadata.detachedCopy()

        return core.performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter(NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileId == %@",
                                    detached.account,
                                    detached.serverUrl,
                                    detached.livePhotoFile))
                .first
                .map { $0.detachedCopy() }
        }
    }

    func getMetadataLivePhotoAsync(metadata: tableMetadata) async -> tableMetadata? {
        guard metadata.isLivePhoto else {
            return nil
        }
        let detached = metadata.detachedCopy()

        return await core.performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter(NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileId == %@",
                                    detached.account,
                                    detached.serverUrl,
                                    detached.livePhotoFile))
                .first
                .map { $0.detachedCopy() }
        }
    }

    func getMetadataConflict(account: String, serverUrl: String, fileNameView: String, nativeFormat: Bool) -> tableMetadata? {
        let fileNameExtension = (fileNameView as NSString).pathExtension.lowercased()
        let fileNameNoExtension = (fileNameView as NSString).deletingPathExtension
        var fileNameConflict = fileNameView

        if fileNameExtension == "heic", !nativeFormat {
            fileNameConflict = fileNameNoExtension + ".jpg"
        }
        return getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView == %@",
                                                  account,
                                                  serverUrl,
                                                  fileNameConflict))
    }

    /// Asynchronously retrieves and sorts `tableMetadata` associated with groupfolders for a given session.
    /// - Parameters:
    ///   - session: The `NCSession.Session` containing account and server information.
    ///   - layoutForView: An optional layout configuration used for sorting.
    /// - Returns: An array of sorted and detached `tableMetadata` objects.
    func getMetadatasFromGroupfoldersAsync(session: NCSession.Session, layoutForView: NCDBLayoutForView?) async -> [tableMetadata] {
        let homeServerUrl = utilityFileSystem.getHomeServer(session: session)

        let detachedMetadatas: [tableMetadata] = await core.performRealmReadAsync { realm in
            var ocIds: [String] = []

            // Safely fetch and detach groupfolders
            let groupfolders = realm.objects(TableGroupfolders.self)
                .filter("account == %@", session.account)
                .sorted(byKeyPath: "mountPoint", ascending: true)
                .map { TableGroupfolders(value: $0) }

            for groupfolder in groupfolders {
                let mountPoint = groupfolder.mountPoint.hasPrefix("/") ? groupfolder.mountPoint : "/" + groupfolder.mountPoint
                let serverUrlFileName = homeServerUrl + mountPoint

                if let directory = realm.objects(tableDirectory.self)
                    .filter("account == %@ AND serverUrl == %@", session.account, serverUrlFileName)
                    .first,
                   let metadata = realm.objects(tableMetadata.self)
                    .filter("ocId == %@", directory.ocId)
                    .first {
                    ocIds.append(metadata.ocId)
                }
            }

            // Fetch and detach the corresponding metadatas
            return realm.objects(tableMetadata.self)
                .filter("ocId IN %@", ocIds)
                .map { $0.detachedCopy() }
        } ?? []

        let sorted = await self.sortedMetadata(layoutForView: layoutForView, account: session.account, metadatas: detachedMetadatas)
        return sorted
    }

    func getRootContainerMetadataAsync(accout: String) async -> tableMetadata? {
        return await core.performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter("fileName == %@ AND account == %@", NextcloudKit.shared.nkCommonInstance.rootFileName, accout)
                .first
                .map { $0.detachedCopy() }
        }
    }

    func getMetadatasAsync(predicate: NSPredicate) async -> [tableMetadata] {
        await core.performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter(predicate)
                .map { $0.detachedCopy() }
        } ?? []
    }

    func getAssetLocalIdentifiersUploadedAsync() async -> [String]? {
        return await core.performRealmReadAsync { realm in
            let results = realm.objects(tableMetadata.self).filter("assetLocalIdentifier != ''")
            return results.map { $0.assetLocalIdentifier }
        }
    }

    func getMetadataFromFileId(_ fileId: String?) -> tableMetadata? {
        guard let fileId else {
            return nil
        }

        return core.performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter("fileId == %@", fileId)
                .first
                .map { $0.detachedCopy() }
        }
    }

    /// Asynchronously retrieves a `tableMetadata` object matching the given `fileId`, if available.
    /// - Parameter fileId: The file identifier used to query the Realm database.
    /// - Returns: A detached copy of the `tableMetadata` object, or `nil` if not found.
    func getMetadataFromFileIdAsync(_ fileId: String?) async -> tableMetadata? {
        guard let fileId else {
            return nil
        }

        return await core.performRealmReadAsync { realm in
            let object = realm.objects(tableMetadata.self)
                .filter("fileId == %@", fileId)
                .first
            return object?.detachedCopy()
        }
    }

    /// Asynchronously retrieves and sorts `tableMetadata` objects matching a given predicate and layout.
    func getMetadatasAsync(predicate: NSPredicate,
                           withLayout layoutForView: NCDBLayoutForView?,
                           withAccount account: String) async -> [tableMetadata] {
        let detachedMetadatas = await core.performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter(predicate)
                .map { $0.detachedCopy() }
        } ?? []

        let sorted = await self.sortedMetadata(layoutForView: layoutForView, account: account, metadatas: detachedMetadatas)
        return sorted
    }

    /// Asynchronously retrieves and sorts `tableMetadata` objects matching a given predicate and layout.
    func getMetadatasAsyncDataSource(withServerUrl serverUrl: String,
                                     withUserId userId: String,
                                     withAccount account: String,
                                     withLayout layoutForView: NCDBLayoutForView?,
                                     withPreficate predicateSource: NSPredicate? = nil) async -> [tableMetadata] {
        var predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName != %@ AND NOT (status IN %@)", account, serverUrl, NextcloudKit.shared.nkCommonInstance.rootFileName, NCGlobal.shared.metadataStatusHideInView)

        if NCPreferences().getPersonalFilesOnly(account: account) {
            predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName != %@ AND (ownerId == %@ || ownerId == '') AND mountType == '' AND NOT (status IN %@)", account, serverUrl, NextcloudKit.shared.nkCommonInstance.rootFileName, userId, NCGlobal.shared.metadataStatusHideInView)
        }

        if let predicateSource {
            predicate = predicateSource
        }

        let detachedMetadatas = await core.performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter(predicate)
                .map { $0.detachedCopy() }
        } ?? []

        let cleanedMetadatas = filterAndNormalizeLivePhotos(from: detachedMetadatas)
        let sorted = await self.sortedMetadata(layoutForView: layoutForView, account: account, metadatas: cleanedMetadatas)

        return sorted
    }

    func getMetadatasAsync(predicate: NSPredicate,
                           withSort sortDescriptors: [RealmSwift.SortDescriptor] = [],
                           withLimit limit: Int? = nil) async -> [tableMetadata]? {
        await core.performRealmReadAsync { realm in
            var results = realm.objects(tableMetadata.self)
                .filter(predicate)

            if !sortDescriptors.isEmpty {
                results = results.sorted(by: sortDescriptors)
            }

            if let limit {
                let sliced = results.prefix(limit)
                return sliced.map { $0.detachedCopy() }
            } else {
                return results.map { $0.detachedCopy() }
            }
        }
    }

    func hasUploadingMetadataWithChunksOrE2EE() -> Bool {
        return core.performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter("status == %d AND (chunk > 0 OR e2eEncrypted == true)", NCGlobal.shared.metadataStatusUploading)
                .first != nil
        } ?? false
    }

    func getMetadataDirectoryAsync(serverUrl: String, account: String) async -> tableMetadata? {
        guard let url = URL(string: serverUrl) else {
            return nil
        }
        let fileName = url.lastPathComponent
        var baseUrl = url.deletingLastPathComponent().absoluteString
        if baseUrl.hasSuffix("/") {
            baseUrl.removeLast()
        }
        guard let decodedBaseUrl = baseUrl.removingPercentEncoding else {
            return nil
        }

        return await core.performRealmReadAsync { realm in
            let object = realm.objects(tableMetadata.self)
                .filter("account == %@ AND serverUrl == %@ AND fileName == %@", account, decodedBaseUrl, fileName)
                .first
            return object?.detachedCopy()
        }
    }

    func getMetadataDirectory(serverUrl: String, account: String) -> tableMetadata? {
        guard let url = URL(string: serverUrl) else {
            return nil
        }
        let fileName = url.lastPathComponent
        var baseUrl = url.deletingLastPathComponent().absoluteString
        if baseUrl.hasSuffix("/") {
            baseUrl.removeLast()
        }
        guard let decodedBaseUrl = baseUrl.removingPercentEncoding else {
            return nil
        }

        return core.performRealmRead { realm in
            let object = realm.objects(tableMetadata.self)
                .filter("account == %@ AND serverUrl == %@ AND fileName == %@", account, decodedBaseUrl, fileName)
                .first
            return object?.detachedCopy()
        }
    }

    func getMetadataProcess() async -> [tableMetadata] {
        await core.performRealmReadAsync { realm in
            let predicate = NSPredicate(format: "status != %d", NCGlobal.shared.metadataStatusNormal)
            let sortDescriptors = [
                RealmSwift.SortDescriptor(keyPath: "status", ascending: false),
                RealmSwift.SortDescriptor(keyPath: "sessionDate", ascending: true)
            ]
            let limit = NCBrandOptions.shared.numMaximumProcess * 3

            let results = realm.objects(tableMetadata.self)
                .filter(predicate)
                .sorted(by: sortDescriptors)

            let sliced = results.prefix(limit)
            return sliced.map { $0.detachedCopy() }

        } ?? []
    }

    func getTransferAsync(tranfersSuccess: [tableMetadata]) async -> [tableMetadata] {
        await core.performRealmReadAsync { realm in
            let predicate = NSPredicate(format: "status IN %@", NCGlobal.shared.metadataStatusTransfers)
            let sortDescriptors = [
                RealmSwift.SortDescriptor(keyPath: "status", ascending: false),
                RealmSwift.SortDescriptor(keyPath: "sessionDate", ascending: true)
            ]

            let results = realm.objects(tableMetadata.self)
                .filter(predicate)
                .sorted(by: sortDescriptors)

            let excludedIds = Set(tranfersSuccess.compactMap { $0.ocIdTransfer })
            let filtered = results.filter { !excludedIds.contains($0.ocIdTransfer) }

            return filtered.map { $0.detachedCopy() }
        } ?? []
    }

    func getMetadatasInWaitingCountAsync() async -> Int {
        await core.performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter("status IN %@", NCGlobal.shared.metadatasStatusInWaiting)
                .count
        } ?? 0
    }
}
