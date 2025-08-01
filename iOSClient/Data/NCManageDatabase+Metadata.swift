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
    @objc dynamic var fileName = ""
    @objc dynamic var fileNameView = ""
    @objc dynamic var hasPreview: Bool = false
    @objc dynamic var hidden: Bool = false
    @objc dynamic var iconName = ""
    @objc dynamic var iconUrl = ""
    @objc dynamic var isFlaggedAsLivePhotoByServer: Bool = false // Indicating if the file is sent as a live photo from the server, or if we should detect it as such and convert it client-side
    @objc dynamic var isExtractFile: Bool = false
    @objc dynamic var livePhotoFile = "" // If this is not empty, the media is a live photo. New media gets this straight from server, but old media needs to be detected as live photo (look isFlaggedAsLivePhotoByServer)
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
    @objc dynamic var mediaSearch: Bool = false
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
    @objc dynamic var serverUrlTo = ""
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
    let tags = List<String>()
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
    @objc dynamic var progress: Double = 0

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

    var isRenameable: Bool {
        if lock {
            return false
        }
        if !isDirectoryE2EE && e2eEncrypted {
            return false
        }
        return true
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

    var isCopyableMovable: Bool {
        !isDirectoryE2EE && !e2eEncrypted
    }

    var isModifiableWithQuickLook: Bool {
        if directory || isDirectoryE2EE {
            return false
        }
        return isPDF || isImage
    }

    var isDeletable: Bool {
        if !isDirectoryE2EE && e2eEncrypted {
            return false
        }
        return true
    }

    var canSetAsAvailableOffline: Bool {
        return session.isEmpty && !isDirectoryE2EE && !e2eEncrypted
    }

    var canShare: Bool {
        return session.isEmpty && !directory && !NCBrandOptions.shared.disable_openin_file
    }

    var canUnsetDirectoryAsE2EE: Bool {
        return !isDirectoryE2EE && directory && size == 0 && e2eEncrypted && NCKeychain().isEndToEndEnabled(account: account)
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

    @objc var isDirectoryE2EE: Bool {
        let session = NCSession.Session(account: account, urlBase: urlBase, user: user, userId: userId)
        return NCUtilityFileSystem().isDirectoryE2EE(session: session, serverUrl: serverUrl)
    }

    var isDirectoryE2EETop: Bool {
        NCUtilityFileSystem().isDirectoryE2EETop(account: account, serverUrl: serverUrl)
    }

    var isLivePhoto: Bool {
        !livePhotoFile.isEmpty
    }

    var isNotFlaggedAsLivePhotoByServer: Bool {
        !isFlaggedAsLivePhotoByServer
    }

    var imageSize: CGSize {
        CGSize(width: width, height: height)
    }

    var hasPreviewBorder: Bool {
        !isImage && !isAudioOrVideo && hasPreview && NCUtilityFileSystem().fileProviderStorageImageExists(ocId, etag: etag, ext: NCGlobal.shared.previewExt1024, userId: userId, urlBase: urlBase)
    }

    var isAvailableEditorView: Bool {
        guard !isPDF,
              classFile == NKTypeClassFile.document.rawValue,
              NextcloudKit.shared.isNetworkReachable() else { return false }
        let utility = NCUtility()
        let directEditingEditors = utility.editorsDirectEditing(account: account, contentType: contentType)
        let richDocumentEditor = utility.isTypeFileRichDocument(self)
        let capabilities = NCNetworking.shared.capabilities[account]

        if let capabilities,
           capabilities.richDocumentsEnabled,
           richDocumentEditor,
           directEditingEditors.isEmpty {
            // RichDocument: Collabora
            return true
        } else if directEditingEditors.contains("Nextcloud Text") || directEditingEditors.contains("onlyoffice") {
            // DirectEditing: Nextcloud Text - OnlyOffice
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
        guard (classFile == NKTypeClassFile.document.rawValue) && NextcloudKit.shared.isNetworkReachable() else { return false }
        let editors = NCUtility().editorsDirectEditing(account: account, contentType: contentType)

        if editors.contains("Nextcloud Text") || editors.contains("ONLYOFFICE") {
            return true
        }
        return false
    }

    var isPDF: Bool {
        return (contentType == "application/pdf" || contentType == "com.adobe.pdf")
    }

    /// Returns false if the user is lokced out of the file. I.e. The file is locked but by somone else
    func canUnlock(as user: String) -> Bool {
        return !lock || (lockOwner == user && lockOwnerType == 0)
    }

    // Return if is sharable
    func isSharable() -> Bool {
        guard let capabilities = NCNetworking.shared.capabilities[account] else {
            return false
        }
        if !capabilities.fileSharingApiEnabled || (capabilities.e2EEEnabled && isDirectoryE2EE) {
            return false
        }
        return true
    }

    /// Returns a detached (unmanaged) deep copy of the current `tableMetadata` object.
    ///
    /// - Note: The Realm `List` properties containing primitive types (e.g., `tags`, `shareType`) are copied automatically
    ///         by the Realm initializer `init(value:)`. For `List` containing Realm objects (e.g., `exifPhotos`), this method
    ///         creates new instances to ensure the copy is fully detached and safe to use outside of a Realm context.
    ///
    /// - Returns: A new `tableMetadata` instance fully detached from Realm.
    func detachedCopy() -> tableMetadata {
        // Use Realm's built-in copy constructor for primitive properties and List of primitives
        let detached = tableMetadata(value: self)

        // Deep copy of List of Realm objects (exifPhotos)
        detached.exifPhotos.removeAll()
        detached.exifPhotos.append(objectsIn: self.exifPhotos.map { NCKeyValue(value: $0) })

        return detached
    }
}

extension NCManageDatabase {
    func isMetadataShareOrMounted(metadata: tableMetadata, metadataFolder: tableMetadata?) -> Bool {
        let permissions = NCPermissions()
        var isShare = false
        var isMounted = false

        if metadataFolder != nil {
            isShare = metadata.permissions.contains(permissions.permissionShared) && !metadataFolder!.permissions.contains(permissions.permissionShared)
            isMounted = metadata.permissions.contains(permissions.permissionMounted) && !metadataFolder!.permissions.contains(permissions.permissionMounted)
        } else if let directory = getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
            isShare = metadata.permissions.contains(permissions.permissionShared) && !directory.permissions.contains(permissions.permissionShared)
            isMounted = metadata.permissions.contains(permissions.permissionMounted) && !directory.permissions.contains(permissions.permissionMounted)
        }

        if isShare || isMounted {
            return true
        } else {
            return false
        }
    }

    // MARK: - Realm Write

    func addMetadataIfNeededAsync(_ metadata: tableMetadata, sync: Bool = true) {
        let detached = metadata.detachedCopy()

        performRealmWrite(sync: sync) { realm in
            if realm.object(ofType: tableMetadata.self, forPrimaryKey: metadata.ocId) == nil {
                realm.add(detached)
            }
        }
    }

    func addAndReturnMetadata(_ metadata: tableMetadata) -> tableMetadata? {
        let detached = metadata.detachedCopy()

        performRealmWrite { realm in
            realm.add(detached, update: .all)
        }

        return performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter("ocId == %@", metadata.ocId)
                .first
                .map { $0.detachedCopy() }
        }
    }

    func addAndReturnMetadataAsync(_ metadata: tableMetadata) async -> tableMetadata? {
        let detached = metadata.detachedCopy()

        await performRealmWriteAsync { realm in
            realm.add(detached, update: .all)
        }

        return await performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter("ocId == %@", metadata.ocId)
                .first?
                .detachedCopy()
        }
    }

    func addMetadata(_ metadata: tableMetadata, sync: Bool = true) {
        let detached = metadata.detachedCopy()

        performRealmWrite(sync: sync) { realm in
            realm.add(detached, update: .all)
        }
    }

    func addMetadataAsync(_ metadata: tableMetadata) async {
        let detached = metadata.detachedCopy()

        await performRealmWriteAsync { realm in
            realm.add(detached, update: .all)
        }
    }

    func addMetadatas(_ metadatas: [tableMetadata], sync: Bool = true) {
        let detached = metadatas.map { $0.detachedCopy() }

        performRealmWrite(sync: sync) { realm in
            realm.add(detached, update: .all)
        }
    }

    func addMetadatasAsync(_ metadatas: [tableMetadata]) async {
        let detached = metadatas.map { $0.detachedCopy() }

        await performRealmWriteAsync { realm in
            realm.add(detached, update: .all)
        }
    }

    func deleteMetadataAsync(predicate: NSPredicate) async {
        await performRealmWriteAsync { realm in
            let result = realm.objects(tableMetadata.self)
                .filter(predicate)
            realm.delete(result)
        }
    }

    func deleteMetadataOcId(_ ocId: String?, sync: Bool = true) {
        guard let ocId else { return }

        performRealmWrite(sync: sync) { realm in
            let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
            realm.delete(result)
        }
    }

    func deleteMetadataOcIdAsync(_ ocId: String?) async {
        guard let ocId else { return }

        await performRealmWriteAsync { realm in
            let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
            realm.delete(result)
        }
    }

    func deleteMetadataOcIds(_ ocIds: [String], sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            let result = realm.objects(tableMetadata.self)
                .filter("ocId IN %@", ocIds)
            realm.delete(result)
        }
    }

    // Asynchronously deletes an array of `tableMetadata` entries from the Realm database.
    /// - Parameter metadatas: The `tableMetadata` objects to be deleted.
    func deleteMetadatasAsync(_ metadatas: [tableMetadata]) async {
        guard !metadatas.isEmpty else {
            return
        }
        let detached = metadatas.map { $0.detachedCopy() }

        await performRealmWriteAsync { realm in
            for detached in detached {
                if let managed = realm.object(ofType: tableMetadata.self, forPrimaryKey: detached.ocId) {
                    realm.delete(managed)
                }
            }
        }
    }

    func renameMetadata(fileNameNew: String, ocId: String, status: Int = NCGlobal.shared.metadataStatusNormal, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            if let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first {
                let fileNameView = result.fileNameView
                let fileIdMOV = result.livePhotoFile
                let directoryServerUrl = self.utilityFileSystem.stringAppendServerUrl(result.serverUrl, addFileName: fileNameView)

                result.fileName = fileNameNew
                result.fileNameView = fileNameNew
                result.status = status

                if status == NCGlobal.shared.metadataStatusNormal {
                    result.sessionDate = nil
                } else {
                    result.sessionDate = Date()
                }

                if result.directory,
                   let resultDirectory = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl == %@", result.account, directoryServerUrl).first {
                    let serverUrlTo = self.utilityFileSystem.stringAppendServerUrl(result.serverUrl, addFileName: fileNameNew)

                    resultDirectory.serverUrl = serverUrlTo
                } else {
                    let atPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(result.ocId, userId: result.userId, urlBase: result.urlBase) + "/" + fileNameView
                    let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(result.ocId, userId: result.userId, urlBase: result.urlBase) + "/" + fileNameNew

                    self.utilityFileSystem.moveFile(atPath: atPath, toPath: toPath)
                }

                if result.isLivePhoto,
                   let resultMOV = realm.objects(tableMetadata.self).filter("fileId == %@ AND account == %@", fileIdMOV, result.account).first {
                    let fileNameView = resultMOV.fileNameView
                    let fileName = (fileNameNew as NSString).deletingPathExtension
                    let ext = (resultMOV.fileName as NSString).pathExtension
                    resultMOV.fileName = fileName + "." + ext
                    resultMOV.fileNameView = fileName + "." + ext

                    let atPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(resultMOV.ocId, userId: resultMOV.userId, urlBase: resultMOV.urlBase) + "/" + fileNameView
                    let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(resultMOV.ocId, userId: resultMOV.userId, urlBase: resultMOV.urlBase) + "/" + fileName + "." + ext

                    self.utilityFileSystem.moveFile(atPath: atPath, toPath: toPath)
                }
            }
        }
    }

    func renameMetadataAsync(fileNameNew: String, ocId: String, status: Int = NCGlobal.shared.metadataStatusNormal) async {
        await performRealmWriteAsync { realm in
            guard let metadata = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first else {
                return
            }

            let oldFileNameView = metadata.fileNameView
            let fileIdMOV = metadata.livePhotoFile
            let account = metadata.account
            let originalServerUrl = metadata.serverUrl

            metadata.fileName = fileNameNew
            metadata.fileNameView = fileNameNew
            metadata.status = status
            metadata.sessionDate = (status == NCGlobal.shared.metadataStatusNormal) ? nil : Date()

            if metadata.directory {
                let oldDirUrl = self.utilityFileSystem.stringAppendServerUrl(originalServerUrl, addFileName: oldFileNameView)
                let newDirUrl = self.utilityFileSystem.stringAppendServerUrl(originalServerUrl, addFileName: fileNameNew)

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

            if metadata.isLivePhoto,
               let livePhotoMetadata = realm.objects(tableMetadata.self)
                    .filter("fileId == %@ AND account == %@", fileIdMOV, account)
                    .first {

                let oldMOVNameView = livePhotoMetadata.fileNameView
                let baseName = (fileNameNew as NSString).deletingPathExtension
                let ext = (livePhotoMetadata.fileName as NSString).pathExtension
                let newMOVName = baseName + "." + ext

                livePhotoMetadata.fileName = newMOVName
                livePhotoMetadata.fileNameView = newMOVName

                let atPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(livePhotoMetadata.ocId,
                                                                                    userId: livePhotoMetadata.userId,
                                                                                    urlBase: livePhotoMetadata.urlBase) + "/" + oldMOVNameView
                let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(livePhotoMetadata.ocId,
                                                                                    userId: livePhotoMetadata.userId,
                                                                                    urlBase: livePhotoMetadata.urlBase) + "/" + newMOVName

                self.utilityFileSystem.moveFile(atPath: atPath, toPath: toPath)
            }
        }
    }

    func restoreMetadataFileName(ocId: String, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            if let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first,
               let encodedURLString = result.serverUrlFileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: encodedURLString) {
                let fileIdMOV = result.livePhotoFile
                let directoryServerUrl = self.utilityFileSystem.stringAppendServerUrl(result.serverUrl, addFileName: result.fileNameView)
                let lastPathComponent = url.lastPathComponent
                let fileName = lastPathComponent.removingPercentEncoding ?? lastPathComponent
                let fileNameView = result.fileNameView

                result.fileName = fileName
                result.fileNameView = fileName
                result.status = NCGlobal.shared.metadataStatusNormal
                result.sessionDate = nil

                if result.directory,
                   let resultDirectory = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl == %@", result.account, directoryServerUrl).first {
                    let serverUrlTo = self.utilityFileSystem.stringAppendServerUrl(result.serverUrl, addFileName: fileName)

                    resultDirectory.serverUrl = serverUrlTo
                } else {
                    let atPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(result.ocId, userId: result.userId, urlBase: result.urlBase) + "/" + fileNameView
                    let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(result.ocId, userId: result.userId, urlBase: result.urlBase) + "/" + fileName

                    self.utilityFileSystem.moveFile(atPath: atPath, toPath: toPath)
                }

                if result.isLivePhoto,
                   let resultMOV = realm.objects(tableMetadata.self).filter("fileId == %@ AND account == %@", fileIdMOV, result.account).first {
                    let fileNameView = resultMOV.fileNameView
                    let fileName = (fileName as NSString).deletingPathExtension
                    let ext = (resultMOV.fileName as NSString).pathExtension
                    resultMOV.fileName = fileName + "." + ext
                    resultMOV.fileNameView = fileName + "." + ext

                    let atPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(resultMOV.ocId, userId: resultMOV.userId, urlBase: resultMOV.urlBase) + "/" + fileNameView
                    let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(resultMOV.ocId, userId: resultMOV.userId, urlBase: resultMOV.urlBase) + "/" + fileName + "." + ext

                    self.utilityFileSystem.moveFile(atPath: atPath, toPath: toPath)
                }
            }
        }
    }

    /// Asynchronously restores the file name of a metadata entry and updates related file system and Realm entries.
    /// - Parameter ocId: The object ID (ocId) of the file to restore.
    func restoreMetadataFileNameAsync(ocId: String) async {
        await performRealmWriteAsync { realm in
            guard let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first,
                  let encodedURLString = result.serverUrlFileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: encodedURLString)
            else {
                return
            }

            let fileIdMOV = result.livePhotoFile
            let directoryServerUrl = self.utilityFileSystem.stringAppendServerUrl(result.serverUrl, addFileName: result.fileNameView)
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
                let serverUrlTo = self.utilityFileSystem.stringAppendServerUrl(result.serverUrl, addFileName: fileName)
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

    func setMetadataServerUrlFileNameStatusNormal(ocId: String, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            if let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first {
                result.serverUrlFileName = self.utilityFileSystem.stringAppendServerUrl(result.serverUrl, addFileName: result.fileName)
                result.status = NCGlobal.shared.metadataStatusNormal
                result.sessionDate = nil
            }
        }
    }

    func setMetadataServerUrlFileNameStatusNormalAsync(ocId: String) async {
        await performRealmWriteAsync { realm in
            if let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first {
                result.serverUrlFileName = self.utilityFileSystem.stringAppendServerUrl(result.serverUrl, addFileName: result.fileName)
                result.status = NCGlobal.shared.metadataStatusNormal
                result.sessionDate = nil
            }
        }
    }

    func setMetadataLivePhotoByServerAsync(account: String,
                                           ocId: String,
                                           livePhotoFile: String) async {
        await performRealmWriteAsync { realm in
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

        await performRealmWriteAsync { realm in
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
        await performRealmWriteAsync { realm in
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

    func setMetadataEncrypted(ocId: String, encrypted: Bool, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first
            result?.e2eEncrypted = encrypted
        }
    }

    func setMetadataEncryptedAsync(ocId: String, encrypted: Bool) async {
        await performRealmWriteAsync { realm in
            let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first
            result?.e2eEncrypted = encrypted
        }
    }

    func setMetadataFileNameView(serverUrl: String, fileName: String, newFileNameView: String, account: String, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            let result = realm.objects(tableMetadata.self)
                .filter("account == %@ AND serverUrl == %@ AND fileName == %@", account, serverUrl, fileName)
                .first
            result?.fileNameView = newFileNameView
        }
    }

    func setMetadataFileNameViewAsync(serverUrl: String, fileName: String, newFileNameView: String, account: String) async {
        await performRealmWriteAsync { realm in
            let result = realm.objects(tableMetadata.self)
                .filter("account == %@ AND serverUrl == %@ AND fileName == %@", account, serverUrl, fileName)
                .first
            result?.fileNameView = newFileNameView
        }
    }

    func moveMetadata(ocId: String, serverUrlTo: String, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            if let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first {
                result.serverUrl = serverUrlTo
            }
        }
    }

    func moveMetadataAsync(ocId: String, serverUrlTo: String) async {
        await performRealmWriteAsync { realm in
            if let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first {
                result.serverUrl = serverUrlTo
            }
        }
    }

    func clearAssetLocalIdentifiersAsync(_ assetLocalIdentifiers: [String]) async {
        await performRealmWriteAsync { realm in
            let results = realm.objects(tableMetadata.self)
                .filter("assetLocalIdentifier IN %@", assetLocalIdentifiers)
            for result in results {
                result.assetLocalIdentifier = ""
            }
        }
    }

    func setMetadataFavorite(ocId: String, favorite: Bool?, saveOldFavorite: String?, status: Int, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first
            if let favorite {
                result?.favorite = favorite
            }
            result?.storeFlag = saveOldFavorite
            result?.status = status

            if status == NCGlobal.shared.metadataStatusNormal {
                result?.sessionDate = nil
            } else {
                result?.sessionDate = Date()
            }
        }
    }

    /// Asynchronously sets the favorite status of a `tableMetadata` entry.
    /// Optionally stores the previous favorite flag and updates the sync status.
    func setMetadataFavoriteAsync(ocId: String, favorite: Bool?, saveOldFavorite: String?, status: Int) async {
        await performRealmWriteAsync { realm in
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

    func setMetadataCopyMove(ocId: String, serverUrlTo: String, overwrite: String?, status: Int, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            if let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first {
                result.serverUrlTo = serverUrlTo
                result.storeFlag = overwrite
                result.status = status

                if status == NCGlobal.shared.metadataStatusNormal {
                    result.sessionDate = nil
                } else {
                    result.sessionDate = Date()
                }
            }
        }
    }

    /// Asynchronously updates a `tableMetadata` entry to set copy/move status and target server URL.
    func setMetadataCopyMoveAsync(ocId: String, serverUrlTo: String, overwrite: String?, status: Int) async {
        await performRealmWriteAsync { realm in
            guard let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first else {
                return
            }

            result.serverUrlTo = serverUrlTo
            result.storeFlag = overwrite
            result.status = status
            result.sessionDate = (status == NCGlobal.shared.metadataStatusNormal) ? nil : Date()
        }
    }

    func clearMetadatasUpload(account: String, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            let results = realm.objects(tableMetadata.self)
                .filter("account == %@ AND (status == %d OR status == %d)", account, NCGlobal.shared.metadataStatusWaitUpload, NCGlobal.shared.metadataStatusUploadError)
            realm.delete(results)
        }
    }

    func clearMetadatasUploadAsync(account: String) async {
        await performRealmWriteAsync { realm in
            let results = realm.objects(tableMetadata.self)
                .filter("account == %@ AND (status == %d OR status == %d)", account, NCGlobal.shared.metadataStatusWaitUpload, NCGlobal.shared.metadataStatusUploadError)
            realm.delete(results)
        }
    }

    // MARK: - Realm Read

    func getAllTableMetadataAsync() async -> [tableMetadata] {
        return await performRealmReadAsync { realm in
            realm.objects(tableMetadata.self).map { tableMetadata(value: $0) }
        } ?? []
    }

    func getMetadata(predicate: NSPredicate) -> tableMetadata? {
        return performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter(predicate)
                .first
                .map { $0.detachedCopy() }
        }
    }

    func getMetadataAsync(predicate: NSPredicate) async -> tableMetadata? {
        return await performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter(predicate)
                .first
                .map { $0.detachedCopy() }
        }
    }

    func getMetadatas(predicate: NSPredicate) -> [tableMetadata] {
        performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter(predicate)
                .map { $0.detachedCopy() }
        } ?? []
    }

    func getMetadatas(predicate: NSPredicate,
                      sortedByKeyPath: String,
                      ascending: Bool = false) -> [tableMetadata]? {
        return performRealmRead { realm in
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
        return await performRealmReadAsync { realm in
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
        return performRealmRead { realm in
            let results = realm.objects(tableMetadata.self)
                .filter(predicate)
                .sorted(byKeyPath: sorted, ascending: ascending)
            return results.prefix(numItems)
                .map { $0.detachedCopy() }
        } ?? []
    }

    func getMetadataFromOcId(_ ocId: String?) -> tableMetadata? {
        guard let ocId else { return nil }

        return performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first
                .map { $0.detachedCopy() }
        }
    }

    func getMetadataFromOcIdAsync(_ ocId: String?) async -> tableMetadata? {
        guard let ocId else { return nil }

        return await performRealmReadAsync { realm in
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

        return await performRealmReadAsync { realm in
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
        let serverUrlHome = utilityFileSystem.getHomeServer(session: session)

        if serverUrlHome == serverUrl {
            fileName = NextcloudKit.shared.nkCommonInstance.rootFileName
        } else {
            fileName = (serverUrl as NSString).lastPathComponent
            if let path = utilityFileSystem.deleteLastPath(serverUrlPath: serverUrl) {
                serverUrl = path
            }
        }

        return await performRealmReadAsync { realm in
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

        return performRealmRead { realm in
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

        return await performRealmReadAsync { realm in
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

        return await performRealmReadAsync { realm in
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
            let metadatas = realm.objects(tableMetadata.self)
                .filter("ocId IN %@", ocIds)
                .map { $0.detachedCopy() }

            let sorted = self.sortedMetadata(layoutForView: layoutForView, account: session.account, metadatas: Array(metadatas))

            return sorted
        } ?? []
    }

    func getRootContainerMetadata(accout: String) -> tableMetadata? {
        return performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter("fileName == %@ AND account == %@", NextcloudKit.shared.nkCommonInstance.rootFileName, accout)
                .first
                .map { $0.detachedCopy() }
        }
    }

    func getRootContainerMetadataAsync(accout: String) async -> tableMetadata? {
        return await performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter("fileName == %@ AND account == %@", NextcloudKit.shared.nkCommonInstance.rootFileName, accout)
                .first
                .map { $0.detachedCopy() }
        }
    }

    func getMetadatasAsync(predicate: NSPredicate) async -> [tableMetadata] {
        await performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter(predicate)
                .map { $0.detachedCopy() }
        } ?? []
    }

    func getTableMetadatasDirectoryFavoriteIdentifierRankAsync(account: String) async -> [String: NSNumber] {
        let result = await performRealmReadAsync { realm in
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

    func getAssetLocalIdentifiersUploadedAsync() async -> [String]? {
        return await performRealmReadAsync { realm in
            let results = realm.objects(tableMetadata.self).filter("assetLocalIdentifier != ''")
            return results.map { $0.assetLocalIdentifier }
        }
    }

    func getMetadataFromFileId(_ fileId: String?) -> tableMetadata? {
        guard let fileId else {
            return nil
        }

        return performRealmRead { realm in
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

        return await performRealmReadAsync { realm in
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
        let detachedMetadatas = await performRealmReadAsync { realm in
            realm.objects(tableMetadata.self)
                .filter(predicate)
                .map { $0.detachedCopy() }
        } ?? []

        let sorted = self.sortedMetadata(layoutForView: layoutForView, account: account, metadatas: detachedMetadatas)

        return sorted
    }

    func getMetadatasAsync(predicate: NSPredicate,
                           withSort sortDescriptors: [RealmSwift.SortDescriptor] = [],
                           withLimit limit: Int? = nil) async -> [tableMetadata]? {
        await performRealmReadAsync { realm in
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
        return performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter("status == %d AND (chunk > 0 OR e2eEncrypted == true)", NCGlobal.shared.metadataStatusUploading)
                .first != nil
        } ?? false
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

        await performRealmWriteAsync { realm in
            let toAdd = remoteMetadatas.filter { toAddOcIds.contains($0.ocId) }
            let toDelete = toDeleteKeys.compactMap {
                realm.object(ofType: tableMetadata.self, forPrimaryKey: $0)
            }

            realm.delete(toDelete)
            realm.add(toAdd, update: .modified)
        }

        return true
    }
}
