// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit
import Photos

class tableMetadata: Object {
    override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? tableMetadata,
           self.account == object.account,
           self.etag == object.etag,
           self.fileId == object.fileId,
           self.path == object.path,
           self.fileName == object.fileName,
           self.fileNameView == object.fileNameView,
           self.date == object.date,
           self.datePhotosOriginal == object.datePhotosOriginal,
           self.permissions == object.permissions,
           self.hasPreview == object.hasPreview,
           self.note == object.note,
           self.lock == object.lock,
           self.favorite == object.favorite,
           self.livePhotoFile == object.livePhotoFile,
           self.sharePermissionsCollaborationServices == object.sharePermissionsCollaborationServices,
           self.height == object.height,
           self.width == object.width,
           self.latitude == object.latitude,
           self.longitude == object.longitude,
           self.altitude == object.altitude,
           self.status == object.status,
           Array(self.tags).elementsEqual(Array(object.tags)),
           Array(self.shareType).elementsEqual(Array(object.shareType)) {
            return true
        } else {
            return false
        }
    }

    @objc dynamic var account = ""
    @objc dynamic var assetLocalIdentifier = ""
    @objc dynamic var checksums = ""
    @objc dynamic var chunk: Int = 0
    @objc dynamic var classFile = ""
    @objc dynamic var commentsUnread: Bool = false
    @objc dynamic var contentType = ""
    @objc dynamic var creationDate = NSDate()
    @objc dynamic var dataFingerprint = ""
    @objc dynamic var date = NSDate()
    @objc dynamic var datePhotosOriginal = NSDate()
    @objc dynamic var directory: Bool = false
    @objc dynamic var downloadURL = ""
    @objc dynamic var e2eEncrypted: Bool = false
    @objc dynamic var edited: Bool = false
    @objc dynamic var etag = ""
    let exifPhotos = List<NCKeyValue>()
    @objc dynamic var favorite: Bool = false
    @objc dynamic var fileId = ""
    /// The file name as it exists on the server.  `fileName` is the same as `fileNameView`. The only exception is when E2EE is enabled, in which case the `fileName` is obfuscated, while the `fileNameView` shows the human-readable name.
    @objc dynamic var fileName = ""
    /// The human readable file name . `fileName` is the same as `fileNameView`. The only exception is when E2EE is enabled, in which case the `fileName` is obfuscated, while the `fileNameView` shows the human-readable name.
    @objc dynamic var fileNameView = ""
    @objc dynamic var hasPreview: Bool = false
    @objc dynamic var hidden: Bool = false
    @objc dynamic var iconName = ""
    @objc dynamic var iconUrl = ""
    /// Indicating if the file is sent as a live photo from the server, or if we should detect it as such and convert it client-side
    @objc dynamic var isFlaggedAsLivePhotoByServer: Bool = false
    @objc dynamic var isExtractFile: Bool = false
    /// If this is not empty, the media is a live photo. New media gets this straight from server, but old media needs to be detected as live photo (look isFlaggedAsLivePhotoByServer)
    @objc dynamic var livePhotoFile = ""
    @objc dynamic var mountType = ""
    @objc dynamic var name = "" // for unifiedSearch is the provider.id
    @objc dynamic var note = ""
    @objc dynamic var ocId = ""
    @objc dynamic var ocIdTransfer = ""
    @objc dynamic var ownerId = ""
    @objc dynamic var ownerDisplayName = ""
    @objc public var lock = false
    @objc public var lockOwner = ""
    @objc public var lockOwnerEditor = ""
    @objc public var lockOwnerType = 0
    @objc public var lockOwnerDisplayName = ""
    @objc public var lockTime: Date?
    @objc public var lockTimeOut: Date?
    @objc dynamic var placeholder: Bool = false
    @objc dynamic var path = ""
    @objc dynamic var permissions = ""
    @objc dynamic var placePhotos: String?
    @objc dynamic var quotaUsedBytes: Int64 = 0
    @objc dynamic var quotaAvailableBytes: Int64 = 0
    @objc dynamic var resourceType = ""
    @objc dynamic var richWorkspace: String?
    @objc dynamic var sceneIdentifier: String?
    @objc dynamic var serverUrl = ""
    @objc dynamic var serverUrlFileName = ""
    @objc dynamic var destination = ""
    @objc dynamic var session = ""
    @objc dynamic var sessionDate: Date?
    @objc dynamic var sessionError = ""
    @objc dynamic var sessionSelector = ""
    @objc dynamic var sessionTaskIdentifier: Int = 0
    /// The  integer for sharing permissions.
    @objc dynamic var sharePermissionsCollaborationServices: Int = 0
    let shareType = List<Int>()
    @objc dynamic var size: Int64 = 0
    @objc dynamic var status: Int = 0
    @objc dynamic var storeFlag: String?
    @objc dynamic var subline: String?
    let tags = List<tableMetadataTag>()
    @objc dynamic var trashbinFileName = ""
    @objc dynamic var trashbinOriginalLocation = ""
    @objc dynamic var trashbinDeletionTime = NSDate()
    @objc dynamic var uploadDate = NSDate()
    @objc dynamic var url = ""
    @objc dynamic var urlBase = ""
    @objc dynamic var user = ""
    @objc dynamic var userId = ""
    @objc dynamic var latitude: Double = 0
    @objc dynamic var longitude: Double = 0
    @objc dynamic var altitude: Double = 0
    @objc dynamic var height: Int = 0
    @objc dynamic var width: Int = 0
    @objc dynamic var errorCode: Int = 0
    @objc dynamic var nativeFormat: Bool = false
    @objc dynamic var autoUploadServerUrlBase: String?
    @objc dynamic var typeIdentifier: String = ""

    // =========================
    // UI / transient properties
    // =========================

    /// Used only for UI state (not persisted, not observed by Realm)
    var isOffline: Bool = false
    var section: String = ""

    override static func primaryKey() -> String {
        return "ocId"
    }
}

extension tableMetadata {
    var fileExtension: String {
        (fileNameView as NSString).pathExtension
    }

    var fileNoExtension: String {
        (fileNameView as NSString).deletingPathExtension
    }

    var isSavebleInCameraRoll: Bool {
        return (classFile == NKTypeClassFile.image.rawValue && contentType != "image/svg+xml") || classFile == NKTypeClassFile.video.rawValue
    }

    var isAudioOrVideo: Bool {
        return classFile == NKTypeClassFile.audio.rawValue || classFile == NKTypeClassFile.video.rawValue
    }

    var isImageOrVideo: Bool {
        return classFile == NKTypeClassFile.image.rawValue || classFile == NKTypeClassFile.video.rawValue
    }

    var isVideo: Bool {
        return classFile == NKTypeClassFile.video.rawValue
    }

    var isAudio: Bool {
        return classFile == NKTypeClassFile.audio.rawValue
    }

    var isImage: Bool {
        return classFile == NKTypeClassFile.image.rawValue
    }

    var isSavebleAsImage: Bool {
        classFile == NKTypeClassFile.image.rawValue && contentType != "image/svg+xml"
    }

    var isCopyableInPasteboard: Bool {
        !directory
    }

#if !EXTENSION_FILE_PROVIDER_EXTENSION
    @objc var isDirectoryE2EE: Bool {
        return NCUtilityFileSystem().isDirectoryE2EE(serverUrl: serverUrl, urlBase: urlBase, userId: userId, account: account)
    }

    var isCopyableMovable: Bool {
        !isDirectoryE2EE && !e2eEncrypted
    }

    var isModifiableWithQuickLook: Bool {
        if directory || isDirectoryE2EE {
            return false
        }
        return isPDF || isImage
    }

    var isRenameable: Bool {
        if !NCMetadataPermissions.canRename(self) {
            return false
        }
        if lock {
            return false
        }
        if !isDirectoryE2EE && e2eEncrypted {
            return false
        }
        return true
    }

    var canUnsetDirectoryAsE2EE: Bool {
        return !isDirectoryE2EE && directory && size == 0 && e2eEncrypted && NCPreferences().isEndToEndEnabled(account: account)
    }

    var isDeletable: Bool {
        if (!isDirectoryE2EE && e2eEncrypted) || !NCMetadataPermissions.canDelete(self) {
            return false
        }
        return true
    }

    var canSetAsAvailableOffline: Bool {
        return session.isEmpty && !isDirectoryE2EE && !e2eEncrypted
    }

    func isSharable() -> Bool {
        guard let capabilities = NCNetworking.shared.capabilities[account] else {
            return false
        }
        if !capabilities.fileSharingApiEnabled || (capabilities.e2EEEnabled && isDirectoryE2EE) {
            return false
        }
        return true
    }

    var hasPreviewBorder: Bool {
        !isImage && !isAudioOrVideo && hasPreview && NCUtilityFileSystem().fileProviderStorageImageExists(ocId, etag: etag, ext: NCGlobal.shared.previewExt1024, userId: userId, urlBase: urlBase)
    }

    var isAvailableEditorView: Bool {
        guard !isPDF,
              classFile == NKTypeClassFile.document.rawValue,
              NextcloudKit.shared.isNetworkReachable() else {
            return false
        }
        let utility = NCUtility()
        let directEditingEditors = utility.editorsDirectEditing(account: account, contentType: contentType).map { $0.lowercased() }
        let richDocumentEditor = utility.isTypeFileRichDocument(self)
        let capabilities = NCNetworking.shared.capabilities[account]

        if let capabilities,
           capabilities.richDocumentsEnabled,
           richDocumentEditor,
           directEditingEditors.isEmpty {
            // RichDocument: Collabora
            return true
        } else if !directEditingEditors.isEmpty {
            return true
        }
        return false
    }

    var isAvailableRichDocumentEditorView: Bool {
        guard let capabilities = NCNetworking.shared.capabilities[account],
              classFile == NKTypeClassFile.document.rawValue,
              capabilities.richDocumentsEnabled,
              NextcloudKit.shared.isNetworkReachable() else { return false }

        if NCUtility().isTypeFileRichDocument(self) {
            return true
        }
        return false
    }

    var isAvailableDirectEditingEditorView: Bool {
        guard (classFile == NKTypeClassFile.document.rawValue) && NextcloudKit.shared.isNetworkReachable() else {
            return false
        }
        let editors = NCUtility().editorsDirectEditing(account: account, contentType: contentType)
        return !editors.isEmpty
    }

    var isPDF: Bool {
        return (contentType == "application/pdf" || contentType == "com.adobe.pdf")
    }

    var isCreatable: Bool {
        if isDirectory {
            return NCMetadataPermissions.canCreateFolder(self)
        } else {
            return NCMetadataPermissions.canCreateFile(self)
        }
    }

#endif

    var canShare: Bool {
        return session.isEmpty && !directory && !NCBrandOptions.shared.disable_openin_file
    }

    var isDownload: Bool {
        status == NCGlobal.shared.metadataStatusWaitDownload || status == NCGlobal.shared.metadataStatusDownloading
    }

    var isUpload: Bool {
        status == NCGlobal.shared.metadataStatusWaitUpload || status == NCGlobal.shared.metadataStatusUploading
    }

    var isDirectory: Bool {
        directory
    }

    var isLivePhoto: Bool {
        !livePhotoFile.isEmpty
    }

    var isLivePhotoVideo: Bool {
        !livePhotoFile.isEmpty && classFile == NKTypeClassFile.video.rawValue
    }

    var isLivePhotoImage: Bool {
        !livePhotoFile.isEmpty && classFile == NKTypeClassFile.image.rawValue
    }

    var isNotFlaggedAsLivePhotoByServer: Bool {
        !isFlaggedAsLivePhotoByServer
    }

    var imageSize: CGSize {
        CGSize(width: width, height: height)
    }

    var tagNames: [String] {
        tags.map(\.name)
    }

    /// Returns false if the user is lokced out of the file. I.e. The file is locked but by somone else
    func canUnlock(as user: String) -> Bool {
        return !lock || (lockOwner == user && lockOwnerType == 0)
    }

    /// Returns a detached (unmanaged) deep copy of the current `tableMetadata` object.
    ///
    /// - Note: Primitive properties and lists of primitive values (for example `shareType`)
    ///   are copied automatically by `init(value:)`.
    ///   For `List` properties containing Realm objects (for example `exifPhotos` and `tags`),
    ///   this method recreates each element explicitly to ensure the resulting copy is fully
    ///   detached and safe to use across Realm contexts.
    ///
    /// - Returns: A new `tableMetadata` instance fully detached from Realm.
    func detachedCopy() -> tableMetadata {
        // Use Realm's built-in copy constructor for primitive properties and lists of primitive values.
        let detached = tableMetadata(value: self)

        // Deep copy of List of Realm objects
        detached.exifPhotos.removeAll()
        detached.exifPhotos.append(objectsIn: self.exifPhotos.map {
            let copy = NCKeyValue()
            copy.key = $0.key
            copy.value = $0.value
            return copy
        })

        detached.tags.removeAll()
        detached.tags.append(objectsIn: self.tags.map {
            let copy = tableMetadataTag()
            copy.primaryKey = $0.primaryKey
            copy.account = $0.account
            copy.id = $0.id
            copy.name = $0.name
            copy.color = $0.color
            return copy
        })

        return detached
    }
}

extension NCManageDatabase {
#if !EXTENSION
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

    func getMetadataProcess() async -> [tableMetadata] {
        return await core.performRealmReadAsync { realm in
            let predicate = NSPredicate(format: "status != %d", NCGlobal.shared.metadataStatusNormal)
            let sortDescriptors = [
                RealmSwift.SortDescriptor(keyPath: "status", ascending: false),
                RealmSwift.SortDescriptor(keyPath: "sessionDate", ascending: true)
            ]
            let limit = NCBrandOptions.shared.numMaximumProcess * 4

            let results = realm.objects(tableMetadata.self)
                .filter(predicate)
                .sorted(by: sortDescriptors)

            let sliced = results.prefix(limit)
            return sliced.map { $0.detachedCopy() }
        } ?? []
    }
#endif

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
        if metadatas.isEmpty {
            return
        }
        let detached = metadatas.map { $0.detachedCopy() }

        await core.performRealmWriteAsync { realm in
            realm.add(detached, update: .all)
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

    func deleteMetadataAsync(ocId: String) async {
        await core.performRealmWriteAsync { realm in
            if let object = realm.object(ofType: tableMetadata.self, forPrimaryKey: ocId) {
                realm.delete(object)
            }
        }
    }

    func replaceMetadataAsync(ocId: String, metadata: tableMetadata) async {
        let detached = metadata.detachedCopy()

        await core.performRealmWriteAsync { realm in
            if let object = realm.object(ofType: tableMetadata.self, forPrimaryKey: ocId) {
                realm.delete(object)
            }
            realm.add(detached, update: .modified)
        }
    }

    func replaceMetadatasAsync(ocId: [String], metadatas: [tableMetadata]) async {
        guard !ocId.isEmpty else {
            return
        }
        var detacheds: [tableMetadata] = []
        for metadata in metadatas {
            metadata.ocIdTransfer = metadata.ocId
            detacheds.append(metadata.detachedCopy())
        }

        await core.performRealmWriteAsync { realm in
            let results = realm.objects(tableMetadata.self)
                .filter("ocId IN %@", ocId)
            realm.delete(results)
            realm.add(detacheds, update: .all)
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

    func deleteMetadatasAsync(ocIds: [String]) async {
        guard !ocIds.isEmpty else {
            return
        }
        await core.performRealmWriteAsync { realm in
            let results = realm.objects(tableMetadata.self)
                .filter("ocId IN %@", ocIds)
            realm.delete(results)
        }
    }

    func renameMetadata(fileNameNew: String, ocId: String, status: Int = NCGlobal.shared.metadataStatusNormal) async {
        await core.performRealmWriteAsync { realm in
            guard let metadata = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first else {
                return
            }

            let utilityFileSystem = NCUtilityFileSystem()
            let oldFileNameView = metadata.fileNameView
            let account = metadata.account
            let originalServerUrl = metadata.serverUrl

            metadata.fileName = fileNameNew
            metadata.fileNameView = fileNameNew
            metadata.status = status
            metadata.sessionDate = (status == NCGlobal.shared.metadataStatusNormal) ? nil : Date()

            if metadata.directory {
                let oldDirUrl = utilityFileSystem.createServerUrl(serverUrl: originalServerUrl, fileName: oldFileNameView)
                let newDirUrl = utilityFileSystem.createServerUrl(serverUrl: originalServerUrl, fileName: fileNameNew)

                if let dir = realm.objects(tableDirectory.self)
                    .filter("account == %@ AND serverUrl == %@", account, oldDirUrl)
                    .first {
                    dir.serverUrl = newDirUrl
                }
            } else {
                let atPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase) + "/" + oldFileNameView
                let toPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase) + "/" + fileNameNew
                utilityFileSystem.moveFile(atPath: atPath, toPath: toPath)
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

            let utilityFileSystem = NCUtilityFileSystem()
            let fileIdMOV = result.livePhotoFile
            let directoryServerUrl = utilityFileSystem.createServerUrl(serverUrl: result.serverUrl, fileName: result.fileNameView)
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
                let serverUrlTo = utilityFileSystem.createServerUrl(serverUrl: result.serverUrl, fileName: fileName)
                resultDirectory.serverUrl = serverUrlTo
            } else {
                let atPath = utilityFileSystem.getDirectoryProviderStorageOcId(result.ocId, userId: result.userId, urlBase: result.urlBase) + "/" + fileNameView
                let toPath = utilityFileSystem.getDirectoryProviderStorageOcId(result.ocId, userId: result.userId, urlBase: result.urlBase) + "/" + fileName
                utilityFileSystem.moveFile(atPath: atPath, toPath: toPath)
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

                let atPath = utilityFileSystem.getDirectoryProviderStorageOcId(resultMOV.ocId, userId: resultMOV.userId, urlBase: resultMOV.urlBase) + "/" + fileNameViewMOV
                let toPath = utilityFileSystem.getDirectoryProviderStorageOcId(resultMOV.ocId, userId: resultMOV.userId, urlBase: resultMOV.urlBase) + "/" + fullFileName
                utilityFileSystem.moveFile(atPath: atPath, toPath: toPath)
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

    /// Asynchronously refreshes the `tableMetadata` entries stored in Realm for the specified account and server URL.
    ///
    /// This function performs the following steps:
    /// 1. Collects all metadata entries with `status != metadataStatusNormal` and protects them from refresh.
    /// 2. Deletes existing normal metadata entries for the specified account and server URL, excluding the root entry.
    /// 3. Skips incoming metadata entries whose `ocId` belongs to a protected non-normal metadata entry.
    /// 4. Inserts or updates the remaining incoming metadata entries into Realm.
    ///
    /// - Parameters:
    ///   - metadatas: An array of incoming detached `tableMetadata` objects to insert or update.
    ///   - serverUrl: The server URL used to scope the metadata refresh.
    ///   - account: The account identifier used to scope the metadata refresh.
    func updateMetadatasFilesAsync(
        _ metadatas: [tableMetadata],
        serverUrl: String,
        account: String
    ) async {
        await core.performRealmWriteAsync { realm in
            // Collect metadata currently involved in non-normal operations.
            // These entries must not be deleted or overwritten by the refresh.
            let ocIdsToSkip = Set(
                realm.objects(tableMetadata.self)
                    .filter("status != %d", NCGlobal.shared.metadataStatusNormal)
                    .map(\.ocId)
            )

            // Delete current normal metadata for this account and server URL,
            // excluding the root entry and protected non-normal entries.
            let resultsToDelete = realm.objects(tableMetadata.self)
                .filter(
                    "account == %@ AND serverUrl == %@ AND status == %d AND fileName != %@",
                    account,
                    serverUrl,
                    NCGlobal.shared.metadataStatusNormal,
                    NextcloudKit.shared.nkCommonInstance.rootFileName
                )
                .filter { !ocIdsToSkip.contains($0.ocId) }

            realm.delete(resultsToDelete)

            // Insert the refreshed metadata list, skipping protected entries.
            for metadata in metadatas {
                guard !ocIdsToSkip.contains(metadata.ocId) else {
                    continue
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

    func setMetadataTagsAsync(ocId: String, account: String, tags: [NKTag]) async {
        await core.performRealmWriteAsync { realm in
            guard let result = realm.objects(tableMetadata.self)
                .filter("account == %@ AND ocId == %@", account, ocId)
                .first else {
                return
            }

            result.tags.removeAll()
            result.tags.append(objectsIn: tags, account: account)
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

    func syncPlaceholderMetadatasAsync(
        files: [NKFile],
        metadatas: [tableMetadata]
    ) async -> (inserted: Int, updated: Int, deleted: [tableMetadata]) {
        guard !files.isEmpty else {
            return (0, 0, [])
        }

        // Build lookup maps for fast diffing.
        // Using merge strategy avoids crashes when duplicated ocIds are present.
        let filesByOcId: [String: NKFile] = Dictionary(
            files.map { ($0.ocId, $0) },
            uniquingKeysWith: { _, new in new }
        )

        // Store detached copies because returned metadata objects must remain usable
        // outside the Realm lifecycle.
        let metadatasByOcId: [String: tableMetadata] = Dictionary(
            metadatas.map { ($0.ocId, $0.detachedCopy()) },
            uniquingKeysWith: { _, new in new }
        )

        let fileOcIds = Set(filesByOcId.keys)
        let metadataOcIds = Set(metadatasByOcId.keys)

        // INSERT: Remote files that are not present in the local date-window metadata list.
        let toInsertOcIds = fileOcIds.subtracting(metadataOcIds)

        // DELETE CANDIDATES: Local metadata entries that are no longer present
        // in the current remote date-window result.
        // They are returned to the caller and must be validated/deleted outside this function.
        let toDeleteOcIds = metadataOcIds.subtracting(fileOcIds)

        let deletedMetadatas: [tableMetadata] = toDeleteOcIds.compactMap { ocId in
            metadatasByOcId[ocId]
        }

        // UPDATE: Existing placeholder metadata entries whose etag changed.
        let toUpdateOcIds: [String] = Array(fileOcIds.intersection(metadataOcIds)).filter { ocId in
            guard let file = filesByOcId[ocId],
                  let metadata = metadatasByOcId[ocId] else {
                return false
            }

            return file.etag != metadata.etag
        }

        let hasChanges = !toInsertOcIds.isEmpty ||
                         !toUpdateOcIds.isEmpty

        guard hasChanges else {
            return (
                inserted: 0,
                updated: 0,
                deleted: deletedMetadatas
            )
        }

        let createMetadata = NCManageDatabaseCreateMetadata()

        await core.performRealmWriteAsync { realm in
            // MODIFY: Update lightweight fields for existing placeholder metadata entries.
            if !toUpdateOcIds.isEmpty {
                let resultsToModify = realm.objects(tableMetadata.self)
                    .filter("ocId IN %@", Array(toUpdateOcIds))

                for metadata in resultsToModify {
                    guard let file = filesByOcId[metadata.ocId] else {
                        continue
                    }

                    metadata.etag = file.etag
                    metadata.date = file.date as NSDate

                    if let date = file.creationDate as? NSDate {
                        metadata.creationDate = date
                    }
                }
            }

            // INSERT: Add placeholder metadata entries for files not currently present in the local date-window metadata list.
            if !toInsertOcIds.isEmpty {
                let insertedMetadatas: [tableMetadata] = toInsertOcIds.compactMap { ocId in
                    guard let file = filesByOcId[ocId] else {
                        return nil
                    }

                    let metadata = createMetadata.createMetadata(file)
                    metadata.placeholder = true
                    return metadata
                }

                if !insertedMetadatas.isEmpty {
                    realm.add(insertedMetadatas, update: .modified)
                }
            }
        }

        return (
            inserted: toInsertOcIds.count,
            updated: toUpdateOcIds.count,
            deleted: deletedMetadatas
        )
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

    func getResultsMetadatasAsync(predicate: NSPredicate) async -> Results<tableMetadata>? {
        await core.performRealmReadAsync { realm in
            let results = realm.objects(tableMetadata.self)
                .filter(predicate)
            return results.freeze()
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

            if let limit, limit > 0 {
                let sliced = results.prefix(limit)
                return sliced.map { $0.detachedCopy() }
            } else {
                return results.map { $0.detachedCopy() }
            }
        }
    }

    func getMetadatasAsync(predicate: NSPredicate,
                           limit: Int? = nil) async -> [tableMetadata]? {
        return await core.performRealmReadAsync { realm in
            let results = realm.objects(tableMetadata.self)
                .filter(predicate)

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

    /// Returns detached (unmanaged) copies of `tableMetadata` objects matching the provided ocIds.
    ///
    /// - Parameter ocIds: Array of ocId strings used to fetch corresponding metadata.
    /// - Returns: An array of detached `tableMetadata` objects. Empty if no matches are found.
    func getMetadatasFromOcIdsAsync(_ ocIds: [String]) async -> [tableMetadata] {
        guard !ocIds.isEmpty else { return [] }

        return await core.performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .where {
                    $0.ocId.in(ocIds)
                }
                .map { $0.detachedCopy() }
        } ?? []
    }

    /// Returns the ocIds that do not have a matching `tableMetadata` object in the local Realm database.
    ///
    /// - Parameter ocIds: The ocId strings to verify against the local Realm database.
    /// - Returns: A set containing the ocIds that were not found locally. Returns an empty set when all ocIds exist locally.
    func getMissingLocalMetadataOcIdsAsync(_ ocIds: [String]) async -> Set<String> {
        let requestedOcIds = Set(ocIds)

        guard !requestedOcIds.isEmpty else {
            return []
        }

        let existingOcIdsArray: [String] = await core.performRealmReadAsync { realm in
            let results = realm.objects(tableMetadata.self)
                .where {
                    $0.ocId.in(Array(requestedOcIds))
                }

            return Array(results.map { $0.ocId })
        } ?? []

        let existingOcIds = Set(existingOcIdsArray)

        return requestedOcIds.subtracting(existingOcIds)
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

    func getOwnerDisplayName(account: String?, ownerId: String?) async -> String? {
        guard let account = account.isNotEmpty,
              let ownerId = ownerId.isNotEmpty else {
            return nil
        }

        return await core.performRealmReadAsync { realm in
            let ownerDisplayName = realm.objects(tableMetadata.self)
                .filter("account == %@ AND ownerId == %@", account, ownerId)
                .first?
                .ownerDisplayName

            return ownerDisplayName.isNotEmpty
        }
    }

    /// Asynchronously retrieves the metadata for a folder, based on its session and serverUrl.
    /// Handles the home directory case rootFileName) and detaches the Realm object before returning.
    func getMetadataFolderAsync(session: NCSession.Session, serverUrl: String) async -> tableMetadata? {
        var serverUrl = serverUrl
        var fileName = ""
        let home = NCUtilityFileSystem().getHomeServer(session: session)

        if home == serverUrl {
            fileName = NextcloudKit.shared.nkCommonInstance.rootFileName
        } else {
            fileName = (serverUrl as NSString).lastPathComponent
            if let serverDirectoryUp = NCUtilityFileSystem().serverDirectoryUp(serverUrl: serverUrl, home: home) {
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

    /// Returns `true` if at least one metadata entry for the specified account and server URL is marked as placeholder.
    ///
    /// - Parameters:
    ///   - account: The account identifier used to scope the metadata lookup.
    ///   - serverUrl: The server URL used to scope the metadata lookup.
    /// - Returns: `true` if at least one matching placeholder metadata exists; otherwise `false`.
    func getMetadataFolderPlaceholderAsync(account: String, serverUrl: String) async -> Bool {
        return await core.performRealmReadAsync { realm in
            !realm.objects(tableMetadata.self)
                .filter(
                    "account == %@ AND serverUrl == %@ AND placeholder == true",
                    account,
                    serverUrl
                )
                .isEmpty
        } ?? false
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

#if !EXTENSION
    /// Asynchronously retrieves and sorts `tableMetadata` associated with groupfolders for a given session.
    /// - Parameters:
    ///   - session: The `NCSession.Session` containing account and server information.
    ///   - layoutForView: An optional layout configuration used for sorting.
    /// - Returns: An array of sorted and detached `tableMetadata` objects.
    func getMetadatasFromGroupfoldersAsync(session: NCSession.Session, layoutForView: NCDBLayoutForView?) async -> [tableMetadata] {
        let homeServerUrl = NCUtilityFileSystem().getHomeServer(session: session)

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
#endif

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

    /// Returns detached (unmanaged) copies of `tableMetadata` objects matching the provided ocIds.
    /// - Parameter fileIds: Array of fileId strings used to fetch corresponding metadata.
    /// - Returns: An array of detached `tableMetadata` objects. Empty if no matches are found.
    func getMetadatasFromFileIdsAsync(_ fileIds: [String]) async -> [tableMetadata] {
        guard !fileIds.isEmpty else {
            return []
        }

        return await core.performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .where {
                    $0.fileId.in(fileIds)
                }
                .map { $0.detachedCopy() }
        } ?? []
    }

#if !EXTENSION_FILE_PROVIDER_EXTENSION
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
#endif

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

    func getTransferAsync(tranfersSuccess: [tableMetadata], status: [Int], offset: Int, limit: Int) async -> (metadatas: [tableMetadata], inWaiting: Int, inProgress: Int, inError: Int) {
        await core.performRealmReadAsync { realm in
            let allTransfers = realm.objects(tableMetadata.self)
                .filter("status != 0")

            let excludedIds = Set(tranfersSuccess.compactMap(\.ocIdTransfer))

            let inWaiting = allTransfers.filter("status IN %@", NCGlobal.shared.metadatasStatusInWaiting).count
            let inProgress = allTransfers.filter("status IN %@", NCGlobal.shared.metadatasStatusDownloadingUploading).count
            let inError = allTransfers.filter("status IN %@", NCGlobal.shared.metadatasStatusInError).count

            let sortDescriptors = [
                RealmSwift.SortDescriptor(keyPath: "status", ascending: false),
                RealmSwift.SortDescriptor(keyPath: "sessionDate", ascending: true),
                RealmSwift.SortDescriptor(keyPath: "ocId", ascending: true)
            ]

            let results = allTransfers
                .filter("status IN %@", status)
                .sorted(by: sortDescriptors)
                .filter { !excludedIds.contains($0.ocIdTransfer) }

            let startIndex = min(offset, results.count)
            let endIndex = min(startIndex + limit, results.count)
            let metadatas = results[startIndex..<endIndex].map { $0.detachedCopy() }

            return (
                metadatas: metadatas,
                inWaiting: inWaiting,
                inProgress: inProgress,
                inError: inError
            )
        } ?? (metadatas: [], inWaiting: 0, inProgress: 0, inError: 0)
    }

    func getMetadatasStatusCountAsync(status: [Int]) async -> Int {
        await core.performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter("status IN %@", status)
                .count
        } ?? 0
    }

    /// Returns only the ocIds that still have a matching metadata row in Realm.
    ///
    /// - Parameter ocIds: Candidate media ocIds used by the media viewer.
    /// - Returns: Valid ocIds preserving the original input order.
    func getValidMetadataOcIdsAsync(_ ocIds: [String]) async -> [String] {
        guard !ocIds.isEmpty else {
            return []
        }

        return await core.performRealmReadAsync { realm in
            let existingOcIds = Set(
                realm.objects(tableMetadata.self)
                    .filter("ocId IN %@", ocIds)
                    .map(\.ocId)
            )

            return ocIds.filter { existingOcIds.contains($0) }
        } ?? []
    }

    func metadataExistsAsync(predicate: NSPredicate) async -> Bool {
        await core.performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter(predicate)
                .first != nil
        } ?? false
    }

    func countMetadatasFor(serverUrl: String) -> Int {
        core.performRealmRead { realm in
            let results = realm.objects(tableMetadata.self)
                .filter("serverUrl == %@", serverUrl)
            return results.count
        } ?? 0
    }

    /// Filters Auto Upload metadata entries, returning only the items that are not already queued in the local database.
    /// - Parameter metadatas: The detached Auto Upload metadata entries generated from Photos assets.
    /// - Returns: Only metadata entries that can be safely added to the upload queue.
    func filterAutoUploadMetadatasNotAlreadyQueuedAsync(_ metadatas: [tableMetadata]) async -> [tableMetadata] {
        await core.performRealmReadAsync { realm in
            metadatas.filter { metadata in
                guard !metadata.assetLocalIdentifier.isEmpty else {
                    return false
                }
                return realm.objects(tableMetadata.self)
                    .filter(
                        "account == %@ AND sessionSelector == %@ AND assetLocalIdentifier == %@ AND session != %@",
                        metadata.account,
                        NCGlobal.shared.selectorUploadAutoUpload,
                        metadata.assetLocalIdentifier,
                        ""
                    )
                    .isEmpty
            }
        } ?? []
    }

    // MARK: - helpers

    /// Extracts the relative DAV folder path and filename from metadata.
    ///
    /// - Parameter metadata: The metadata object containing DAV URLs.
    /// - Returns: A tuple containing the relative path and filename.
    func relativeDavComponents(for metadata: tableMetadata) -> (path: String, fileName: String) {
        let fullPath = metadata.serverUrlFileName
        let prefix = NKDav.homeURLStringNoSlash(urlBase: metadata.urlBase, userId: metadata.userId)

        guard fullPath.hasPrefix(prefix) else {
            return (path: "", fileName: metadata.fileName)
        }

        let relative = String(fullPath.dropFirst(prefix.count))

        // Split into path + filename
        let url = URL(fileURLWithPath: relative)

        let fileName = url.lastPathComponent
        let path = url.deletingLastPathComponent().path

        return (path, fileName)
    }
}

class tableMetadataTag: Object {
    @Persisted(primaryKey: true) var primaryKey: String
    @Persisted var account = ""
    @Persisted var id = ""
    @Persisted var name = ""
    @Persisted var color: String?

    convenience init(tag: NKTag, account: String) {
        self.init()
        self.account = account
        self.id = tag.id
        self.name = tag.name
        self.color = tag.color
        self.primaryKey = account + id
    }

    var nkTag: NKTag {
        NKTag(id: id, name: name, color: color)
    }

    static func == (lhs: tableMetadataTag, rhs: tableMetadataTag) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.color == rhs.color
    }
}

extension List where Element == tableMetadataTag {
    func append(_ tag: NKTag, account: String) {
        let object = tableMetadataTag(tag: tag, account: account)

        if let realm {
            realm.add(object, update: .all)
            if let managedObject = realm.object(ofType: tableMetadataTag.self, forPrimaryKey: object.primaryKey) {
                append(managedObject)
                return
            }
        }

        append(object)
    }

    func append(objectsIn tags: [NKTag], account: String) {
        for tag in tags {
            append(tag, account: account)
        }
    }
}
