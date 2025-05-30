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
    @objc dynamic var etagResource = ""
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
    @objc dynamic var path = ""
    @objc dynamic var permissions = ""
    @objc dynamic var placePhotos: String?
    @objc dynamic var quotaUsedBytes: Int64 = 0
    @objc dynamic var quotaAvailableBytes: Int64 = 0
    @objc dynamic var resourceType = ""
    @objc dynamic var richWorkspace: String?
    @objc dynamic var sceneIdentifier: String?
    @objc dynamic var serverUrl = ""
    @objc dynamic var serveUrlFileName = ""
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
        return (classFile == NKCommon.TypeClassFile.image.rawValue && contentType != "image/svg+xml") || classFile == NKCommon.TypeClassFile.video.rawValue
    }

    /*
    var isDocumentViewableOnly: Bool {
        sharePermissionsCollaborationServices == NCPermissions().permissionReadShare && classFile == NKCommon.TypeClassFile.document.rawValue
    }
    */

    var isAudioOrVideo: Bool {
        return classFile == NKCommon.TypeClassFile.audio.rawValue || classFile == NKCommon.TypeClassFile.video.rawValue
    }

    var isImageOrVideo: Bool {
        return classFile == NKCommon.TypeClassFile.image.rawValue || classFile == NKCommon.TypeClassFile.video.rawValue
    }

    var isVideo: Bool {
        return classFile == NKCommon.TypeClassFile.video.rawValue
    }

    var isAudio: Bool {
        return classFile == NKCommon.TypeClassFile.audio.rawValue
    }

    var isImage: Bool {
        return classFile == NKCommon.TypeClassFile.image.rawValue
    }

    var isSavebleAsImage: Bool {
        classFile == NKCommon.TypeClassFile.image.rawValue && contentType != "image/svg+xml"
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

    var canSetDirectoryAsE2EE: Bool {
        return directory && size == 0 && !e2eEncrypted && NCKeychain().isEndToEndEnabled(account: account)
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
        !isImage && !isAudioOrVideo && hasPreview && NCUtilityFileSystem().fileProviderStorageImageExists(ocId, etag: etag, ext: NCGlobal.shared.previewExt1024)
    }

    var isAvailableEditorView: Bool {
        guard !isPDF,
              classFile == NKCommon.TypeClassFile.document.rawValue,
              NextcloudKit.shared.isNetworkReachable() else { return false }
        let utility = NCUtility()
        let directEditingEditors = utility.editorsDirectEditing(account: account, contentType: contentType)
        let richDocumentEditor = utility.isTypeFileRichDocument(self)

        if NCCapabilities.shared.getCapabilities(account: account).capabilityRichDocumentsEnabled && richDocumentEditor && directEditingEditors.isEmpty {
            // RichDocument: Collabora
            return true
        } else if directEditingEditors.contains(NCGlobal.shared.editorText) || directEditingEditors.contains(NCGlobal.shared.editorOnlyoffice) {
            // DirectEditing: Nextcloud Text - OnlyOffice
           return true
        }
        return false
    }

    var isAvailableRichDocumentEditorView: Bool {
        guard classFile == NKCommon.TypeClassFile.document.rawValue,
              NCCapabilities.shared.getCapabilities(account: account).capabilityRichDocumentsEnabled,
              NextcloudKit.shared.isNetworkReachable() else { return false }

        if NCUtility().isTypeFileRichDocument(self) {
            return true
        }
        return false
    }

    var isAvailableDirectEditingEditorView: Bool {
        guard (classFile == NKCommon.TypeClassFile.document.rawValue) && NextcloudKit.shared.isNetworkReachable() else { return false }
        let editors = NCUtility().editorsDirectEditing(account: account, contentType: contentType)

        if editors.contains(NCGlobal.shared.editorText) || editors.contains(NCGlobal.shared.editorOnlyoffice) {
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
        if !NCCapabilities.shared.getCapabilities(account: account).capabilityFileSharingApiEnabled || (NCCapabilities.shared.getCapabilities(account: account).capabilityE2EEEnabled && isDirectoryE2EE) {
            return false
        }
        return true
    }
}

extension NCManageDatabase {

    // MARK: - Create Metadata

    func convertFileToMetadata(_ file: NKFile, isDirectoryE2EE: Bool) -> tableMetadata {
        let metadata = tableMetadata()

        metadata.account = file.account
        metadata.checksums = file.checksums
        metadata.commentsUnread = file.commentsUnread
        metadata.contentType = file.contentType
        if let date = file.creationDate {
            metadata.creationDate = date as NSDate
        } else {
            metadata.creationDate = file.date as NSDate
        }
        metadata.dataFingerprint = file.dataFingerprint
        metadata.date = file.date as NSDate
        if let datePhotosOriginal = file.datePhotosOriginal {
            metadata.datePhotosOriginal = datePhotosOriginal as NSDate
        } else {
            metadata.datePhotosOriginal = metadata.date
        }
        metadata.directory = file.directory
        metadata.downloadURL = file.downloadURL
        metadata.e2eEncrypted = file.e2eEncrypted
        metadata.etag = file.etag
        for dict in file.exifPhotos {
            for (key, value) in dict {
                let keyValue = NCKeyValue()
                keyValue.key = key
                keyValue.value = value
                metadata.exifPhotos.append(keyValue)
            }
        }
        metadata.favorite = file.favorite
        metadata.fileId = file.fileId
        metadata.fileName = file.fileName
        metadata.fileNameView = file.fileName
        metadata.hasPreview = file.hasPreview
        metadata.hidden = file.hidden
        metadata.iconName = file.iconName
        metadata.mountType = file.mountType
        metadata.name = file.name
        metadata.note = file.note
        metadata.ocId = file.ocId
        metadata.ocIdTransfer = file.ocId
        metadata.ownerId = file.ownerId
        metadata.ownerDisplayName = file.ownerDisplayName
        metadata.lock = file.lock
        metadata.lockOwner = file.lockOwner
        metadata.lockOwnerEditor = file.lockOwnerEditor
        metadata.lockOwnerType = file.lockOwnerType
        metadata.lockOwnerDisplayName = file.lockOwnerDisplayName
        metadata.lockTime = file.lockTime
        metadata.lockTimeOut = file.lockTimeOut
        metadata.path = file.path
        metadata.permissions = file.permissions
        metadata.placePhotos = file.placePhotos
        metadata.quotaUsedBytes = file.quotaUsedBytes
        metadata.quotaAvailableBytes = file.quotaAvailableBytes
        metadata.richWorkspace = file.richWorkspace
        metadata.resourceType = file.resourceType
        metadata.serverUrl = file.serverUrl
        metadata.serveUrlFileName = file.serverUrl + "/" + file.fileName
        metadata.sharePermissionsCollaborationServices = file.sharePermissionsCollaborationServices

        for element in file.shareType {
            metadata.shareType.append(element)
        }
        for element in file.tags {
            metadata.tags.append(element)
        }
        metadata.size = file.size
        metadata.classFile = file.classFile
        // iOS 12.0,* don't detect UTI text/markdown, text/x-markdown
        if (metadata.contentType == "text/markdown" || metadata.contentType == "text/x-markdown") && metadata.classFile == NKCommon.TypeClassFile.unknow.rawValue {
            metadata.classFile = NKCommon.TypeClassFile.document.rawValue
        }
        if let date = file.uploadDate {
            metadata.uploadDate = date as NSDate
        } else {
            metadata.uploadDate = file.date as NSDate
        }
        metadata.urlBase = file.urlBase
        metadata.user = file.user
        metadata.userId = file.userId
        metadata.latitude = file.latitude
        metadata.longitude = file.longitude
        metadata.altitude = file.altitude
        metadata.height = Int(file.height)
        metadata.width = Int(file.width)
        metadata.livePhotoFile = file.livePhotoFile
        metadata.isFlaggedAsLivePhotoByServer = file.isFlaggedAsLivePhotoByServer

        // E2EE find the fileName for fileNameView
        if isDirectoryE2EE || file.e2eEncrypted {
            if let tableE2eEncryption = getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", file.account, file.serverUrl, file.fileName)) {
                metadata.fileNameView = tableE2eEncryption.fileName
                let results = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: metadata.fileNameView, mimeType: file.contentType, directory: file.directory, account: file.account)
                metadata.contentType = results.mimeType
                metadata.iconName = results.iconName
                metadata.classFile = results.classFile
            }
        }
        return metadata
    }

    func convertFilesToMetadatas(_ files: [NKFile], useFirstAsMetadataFolder: Bool, completion: @escaping (_ metadataFolder: tableMetadata, _ metadatas: [tableMetadata]) -> Void) {
        var counter: Int = 0
        var isDirectoryE2EE: Bool = false
        let listServerUrl = ThreadSafeDictionary<String, Bool>()
        var metadataFolder = tableMetadata()
        var metadatas: [tableMetadata] = []

        for file in files {
            if let key = listServerUrl[file.serverUrl] {
                isDirectoryE2EE = key
            } else {
                isDirectoryE2EE = NCUtilityFileSystem().isDirectoryE2EE(file: file)
                listServerUrl[file.serverUrl] = isDirectoryE2EE
            }

            let metadata = convertFileToMetadata(file, isDirectoryE2EE: isDirectoryE2EE)

            if counter == 0 && useFirstAsMetadataFolder {
                metadataFolder = metadata
            } else {
                metadatas.append(metadata)
            }

            counter += 1
        }
        completion(tableMetadata(value: metadataFolder), metadatas)
    }

    func getMetadataDirectoryFrom(files: [NKFile]) -> tableMetadata? {
        guard let file = files.first else { return nil }
        let isDirectoryE2EE = NCUtilityFileSystem().isDirectoryE2EE(file: file)
        let metadata = convertFileToMetadata(file, isDirectoryE2EE: isDirectoryE2EE)

        return metadata
    }

    func convertFilesToMetadatas(_ files: [NKFile], useFirstAsMetadataFolder: Bool) async -> (metadataFolder: tableMetadata, metadatas: [tableMetadata]) {
        await withUnsafeContinuation({ continuation in
            convertFilesToMetadatas(files, useFirstAsMetadataFolder: useFirstAsMetadataFolder) { metadataFolder, metadatas in
                continuation.resume(returning: (metadataFolder, metadatas))
            }
        })
    }

    func createMetadata(fileName: String, fileNameView: String, ocId: String, serverUrl: String, url: String, contentType: String, isUrl: Bool = false, name: String = NCGlobal.shared.appName, subline: String? = nil, iconName: String? = nil, iconUrl: String? = nil, directory: Bool = false, session: NCSession.Session, sceneIdentifier: String?) -> tableMetadata {
        let metadata = tableMetadata()

        if isUrl {
            metadata.contentType = "text/uri-list"
            if let iconName = iconName {
                metadata.iconName = iconName
            } else {
                metadata.iconName = NKCommon.TypeClassFile.url.rawValue
            }
            metadata.classFile = NKCommon.TypeClassFile.url.rawValue
        } else {
            let (mimeType, classFile, iconName, _, _, _) = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: fileName, mimeType: contentType, directory: directory, account: session.account)
            metadata.contentType = mimeType
            metadata.iconName = iconName
            metadata.classFile = classFile
            // iOS 12.0,* don't detect UTI text/markdown, text/x-markdown
            if classFile == NKCommon.TypeClassFile.unknow.rawValue && (mimeType == "text/x-markdown" || mimeType == "text/markdown") {
                metadata.iconName = NKCommon.TypeIconFile.txt.rawValue
                metadata.classFile = NKCommon.TypeClassFile.document.rawValue
            }
        }
        if let iconUrl = iconUrl {
            metadata.iconUrl = iconUrl
        }

        let fileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)

        metadata.account = session.account
        metadata.creationDate = Date() as NSDate
        metadata.date = Date() as NSDate
        metadata.directory = directory
        metadata.hasPreview = true
        metadata.etag = ocId
        metadata.fileName = fileName
        metadata.fileNameView = fileName
        metadata.name = name
        metadata.ocId = ocId
        metadata.ocIdTransfer = ocId
        metadata.permissions = "RGDNVW"
        metadata.serverUrl = serverUrl
        metadata.serveUrlFileName = serverUrl + "/" + fileName
        metadata.subline = subline
        metadata.uploadDate = Date() as NSDate
        metadata.url = url
        metadata.urlBase = session.urlBase
        metadata.user = session.user
        metadata.userId = session.userId
        metadata.sceneIdentifier = sceneIdentifier
        metadata.nativeFormat = !NCKeychain().formatCompatibility

        if !metadata.urlBase.isEmpty, metadata.serverUrl.hasPrefix(metadata.urlBase) {
            metadata.path = String(metadata.serverUrl.dropFirst(metadata.urlBase.count)) + "/"
        }
        return metadata
    }

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

    func addMetadata(_ metadata: tableMetadata, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            realm.add(metadata, update: .all)
        }
    }

    func addMetadataIfNeeded(_ metadata: tableMetadata, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            if realm.object(ofType: tableMetadata.self, forPrimaryKey: metadata.ocId) == nil {
                realm.add(metadata)
            }
        }
    }

    func addMetadataAndReturn(_ metadata: tableMetadata, sync: Bool = true) -> tableMetadata {
        var addedMetadata = tableMetadata(value: metadata)

        performRealmWrite(sync: sync) { realm in
            let created = realm.create(tableMetadata.self, value: metadata, update: .all)
            addedMetadata = tableMetadata(value: created)
        }
        return addedMetadata
    }

    func addMetadatas(_ metadatas: [tableMetadata], sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            realm.add(metadatas, update: .all)
        }
    }

    func deleteMetadata(predicate: NSPredicate, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
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

    func deleteMetadataOcIds(_ ocIds: [String], sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            let result = realm.objects(tableMetadata.self)
                .filter("ocId IN %@", ocIds)
            realm.delete(result)
        }
    }

    func deleteMetadatas(_ metadatas: [tableMetadata], sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            realm.delete(metadatas)
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
                let resultsType = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: fileNameNew, mimeType: "", directory: result.directory, account: result.account)

                result.fileName = fileNameNew
                result.fileNameView = fileNameNew
                result.iconName = resultsType.iconName
                result.contentType = resultsType.mimeType
                result.classFile = resultsType.classFile
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
                    let atPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(result.ocId) + "/" + fileNameView
                    let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(result.ocId) + "/" + fileNameNew

                    self.utilityFileSystem.moveFile(atPath: atPath, toPath: toPath)
                }

                if result.isLivePhoto,
                   let resultMOV = realm.objects(tableMetadata.self).filter("fileId == %@ AND account == %@", fileIdMOV, result.account).first {
                    let fileNameView = resultMOV.fileNameView
                    let fileName = (fileNameNew as NSString).deletingPathExtension
                    let ext = (resultMOV.fileName as NSString).pathExtension
                    resultMOV.fileName = fileName + "." + ext
                    resultMOV.fileNameView = fileName + "." + ext

                    let atPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(resultMOV.ocId) + "/" + fileNameView
                    let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(resultMOV.ocId) + "/" + fileName + "." + ext

                    self.utilityFileSystem.moveFile(atPath: atPath, toPath: toPath)
                }
            }
        }
    }

    func restoreMetadataFileName(ocId: String, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            if let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first,
               let encodedURLString = result.serveUrlFileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
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
                    let atPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(result.ocId) + "/" + fileNameView
                    let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(result.ocId) + "/" + fileName

                    self.utilityFileSystem.moveFile(atPath: atPath, toPath: toPath)
                }

                if result.isLivePhoto,
                   let resultMOV = realm.objects(tableMetadata.self).filter("fileId == %@ AND account == %@", fileIdMOV, result.account).first {
                    let fileNameView = resultMOV.fileNameView
                    let fileName = (fileName as NSString).deletingPathExtension
                    let ext = (resultMOV.fileName as NSString).pathExtension
                    resultMOV.fileName = fileName + "." + ext
                    resultMOV.fileNameView = fileName + "." + ext

                    let atPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(resultMOV.ocId) + "/" + fileNameView
                    let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(resultMOV.ocId) + "/" + fileName + "." + ext

                    self.utilityFileSystem.moveFile(atPath: atPath, toPath: toPath)
                }
            }
        }
    }

    func setMetadataServeUrlFileNameStatusNormal(ocId: String, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            if let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first {
                result.serveUrlFileName = self.utilityFileSystem.stringAppendServerUrl(result.serverUrl, addFileName: result.fileName)
                result.status = NCGlobal.shared.metadataStatusNormal
                result.sessionDate = nil
            }
        }
    }

    func setMetadataEtagResource(ocId: String, etagResource: String?, sync: Bool = true) {
        guard let etagResource else { return }

        performRealmWrite(sync: sync) { realm in
            let result = realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first
            result?.etagResource = etagResource
        }
    }

    func setMetadataLivePhotoByServer(account: String, ocId: String, livePhotoFile: String, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            if let result = realm.objects(tableMetadata.self)
                .filter("account == %@ AND ocId == %@", account, ocId)
                .first {
                result.isFlaggedAsLivePhotoByServer = true
                result.livePhotoFile = livePhotoFile
            }
        }
    }

    func updateMetadatasFavorite(account: String, metadatas: [tableMetadata], sync: Bool = true) {
        guard !metadatas.isEmpty
        else {
            return
        }

        performRealmWrite(sync: sync) { realm in
            let oldFavorites = realm.objects(tableMetadata.self)
                .filter("account == %@ AND favorite == true", account)
            for item in oldFavorites {
                item.favorite = false
            }
            realm.add(metadatas, update: .all)
        }
    }

    func updateMetadatasFiles(_ metadatas: [tableMetadata], serverUrl: String, account: String) {
        performRealmWrite(sync: false) { realm in
            let ocIdsToSkip = Set(
                realm.objects(tableMetadata.self)
                    .filter("status != %d", NCGlobal.shared.metadataStatusNormal)
                    .map(\.ocId)
                )

            let resultsToDelete = realm.objects(tableMetadata.self)
                .filter("account == %@ AND serverUrl == %@ AND status == %d", account, serverUrl, NCGlobal.shared.metadataStatusNormal)
                .filter { !ocIdsToSkip.contains($0.ocId) }

            realm.delete(resultsToDelete)

            for metadata in metadatas {
                guard !ocIdsToSkip.contains(metadata.ocId)
                else {
                    continue
                }
                realm.add(tableMetadata(value: metadata), update: .all)
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

    func setMetadataFileNameView(serverUrl: String, fileName: String, newFileNameView: String, account: String, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
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

    func clearAssetLocalIdentifiers(_ assetLocalIdentifiers: [String], sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
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

    func clearMetadatasUpload(account: String, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            let results = realm.objects(tableMetadata.self)
                .filter("account == %@ AND (status == %d OR status == %d)", account, NCGlobal.shared.metadataStatusWaitUpload, NCGlobal.shared.metadataStatusUploadError)
            realm.delete(results)
        }
    }

    // MARK: - Realm Read

    func getMetadata(predicate: NSPredicate) -> tableMetadata? {
        return performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter(predicate)
                .first
                .map { tableMetadata(value: $0) }
        }
    }

    func getMetadataAsync(predicate: NSPredicate, completion: @escaping (tableMetadata?) -> Void) {
        performRealmRead({ realm in
            return realm.objects(tableMetadata.self)
                .filter(predicate)
                .first
                .map { tableMetadata(value: $0) }
        }, sync: false) { result in
            completion(result)
        }
    }

    func getMetadatas(predicate: NSPredicate,
                      completion: @escaping ([tableMetadata]) -> Void) {
        performRealmRead({ realm in
            let results = realm.objects(tableMetadata.self)
                .filter(predicate)
            return Array(results.map { tableMetadata(value: $0) })
        }, sync: false) { results in
            completion(results ?? [])
        }
    }

    func getMetadatas(predicate: NSPredicate) -> [tableMetadata] {
        return performRealmRead { realm in
            let result = realm.objects(tableMetadata.self)
                .filter(predicate)
            return Array(result.map { tableMetadata(value: $0) })
        } ?? []
    }

    func getMetadatas(predicate: NSPredicate, sortedByKeyPath: String, ascending: Bool = false) -> [tableMetadata]? {
        return performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter(predicate)
                .sorted(byKeyPath: sortedByKeyPath, ascending: ascending)
                .map { tableMetadata(value: $0) }
        }
    }

    func getMetadatasAsync(predicate: NSPredicate,
                           sortedByKeyPath: String,
                           ascending: Bool = false) async -> [tableMetadata]? {
        return await performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter(predicate)
                .sorted(byKeyPath: sortedByKeyPath, ascending: ascending)
                .map { tableMetadata(value: $0) }
        }
    }

    func getMetadatas(predicate: NSPredicate, numItems: Int, sorted: String, ascending: Bool) -> [tableMetadata] {
        return performRealmRead { realm in
            let results = realm.objects(tableMetadata.self)
                .filter(predicate)
                .sorted(byKeyPath: sorted, ascending: ascending)
            return results.prefix(numItems).map { tableMetadata(value: $0) }
        } ?? []
    }

    func getMetadataFromOcId(_ ocId: String?) -> tableMetadata? {
        guard let ocId else { return nil }

        return performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first
                .map { tableMetadata(value: $0) }
        }
    }

    func getMetadataFromOcId(_ ocId: String?,
                             dispatchOnMainQueue: Bool = true,
                             completion: @escaping (_ metadata: tableMetadata?) -> Void) {
        guard let ocId else {
            return completion(nil)
        }

        performRealmRead({ realm in
            return realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first
                .map { tableMetadata(value: $0) }
        }, sync: false) { result in
            if dispatchOnMainQueue {
                DispatchQueue.main.async {
                    completion(result)
                }
            } else {
                completion(result)
            }
        }
    }

    func getMetadataFromOcIdAndocIdTransfer(_ ocId: String?) -> tableMetadata? {
        guard let ocId else { return nil }

        return performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter("ocId == %@ OR ocIdTransfer == %@", ocId, ocId)
                .first
                .map { tableMetadata(value: $0) }
        }
    }

    func getMetadataFolder(session: NCSession.Session, serverUrl: String) -> tableMetadata? {
        var serverUrl = serverUrl
        var fileName = ""
        let serverUrlHome = utilityFileSystem.getHomeServer(session: session)

        if serverUrlHome == serverUrl {
            fileName = "."
            serverUrl = ".."
        } else {
            fileName = (serverUrl as NSString).lastPathComponent
            if let path = utilityFileSystem.deleteLastPath(serverUrlPath: serverUrl) {
                serverUrl = path
            }
        }

        return performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter("account == %@ AND serverUrl == %@ AND fileName == %@", session.account, serverUrl, fileName)
                .first
                .map { tableMetadata(value: $0) }
        }
    }

    func getMetadataLivePhoto(metadata: tableMetadata) -> tableMetadata? {
        guard metadata.isLivePhoto
        else {
            return nil
        }

        return performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter(NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileId == %@",
                                    metadata.account,
                                    metadata.serverUrl,
                                    metadata.livePhotoFile))
                .first
                .map { tableMetadata(value: $0) }
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

    // MARK: - Realm Read (result)

    func getResultsMetadatasFromGroupfolders(session: NCSession.Session, layoutForView: NCDBLayoutForView?) -> [tableMetadata] {
        let homeServerUrl = utilityFileSystem.getHomeServer(session: session)

        return performRealmRead { realm in
            var ocIds: [String] = []

            let groupfolders = realm.objects(TableGroupfolders.self)
                .filter("account == %@", session.account)
                .sorted(byKeyPath: "mountPoint", ascending: true)
                .freeze()

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

            let result = realm.objects(tableMetadata.self)
                .filter("ocId IN %@", ocIds)
                .freeze()

            let sorted = self.sortedResultsMetadata(layoutForView: layoutForView, account: session.account, metadatas: result)

            return sorted
        } ?? []
    }

    func getResultsMetadatas(predicate: NSPredicate, sortedByKeyPath: String, ascending: Bool, arraySlice: Int) -> [tableMetadata] {
        return performRealmRead { realm in
            let results = realm.objects(tableMetadata.self)
                .filter(predicate)
                .sorted(byKeyPath: sortedByKeyPath, ascending: ascending)
                .prefix(arraySlice)
            return Array(results)
        } ?? []
    }

    func getResultMetadata(predicate: NSPredicate) -> tableMetadata? {
        return performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter(predicate)
                .first
        }
    }

    func getResultMetadataFromFileName(_ fileName: String, serverUrl: String, sessionTaskIdentifier: Int) -> tableMetadata? {
        return performRealmRead { realm in
            return realm.objects(tableMetadata.self)
                .filter("fileName == %@ AND serverUrl == %@ AND sessionTaskIdentifier == %d", fileName, serverUrl, sessionTaskIdentifier)
                .first
        }
    }

    func getTableMetadatasDirectoryFavoriteIdentifierRank(account: String) -> [String: NSNumber] {
        return performRealmRead { realm in
            var listIdentifierRank: [String: NSNumber] = [:]
            var counter = 10 as Int64

            let results = realm.objects(tableMetadata.self)
                .filter("account == %@ AND directory == true AND favorite == true", account)
                .sorted(byKeyPath: "fileNameView", ascending: true)

            results.forEach { result in
                counter += 1
                listIdentifierRank[result.ocId] = NSNumber(value: Int64(counter))
            }

            return listIdentifierRank
        } ?? [:]
    }

    func getAssetLocalIdentifiersUploaded() -> [String]? {
        return performRealmRead { realm in
            let results = realm.objects(tableMetadata.self).filter("assetLocalIdentifier != ''")
            return results.map { $0.assetLocalIdentifier }
        }
    }

    func getAssetLocalIdentifiersWaitUpload() -> [String]? {
        return performRealmRead { realm in
            let results = realm.objects(tableMetadata.self).filter("sessionSelector == %@ AND status == %d AND assetLocalIdentifier != ''", NCGlobal.shared.selectorUploadAutoUpload, NCGlobal.shared.metadataStatusWaitUpload)
            return results.map { $0.assetLocalIdentifier }
        }
    }

    func getAssetLocalIdentifiersWaitUpload(completion: @escaping ([String]) -> Void) {
        performRealmRead({ realm in
            return realm.objects(tableMetadata.self)
                .filter("sessionSelector == %@ AND status == %d AND assetLocalIdentifier != ''", NCGlobal.shared.selectorUploadAutoUpload, NCGlobal.shared.metadataStatusWaitUpload)
        }, sync: false) { result in
            let identifiers = Array(result?.compactMap { $0.assetLocalIdentifier } ?? [])
            completion(identifiers)
        }
    }

    func getMetadataFromDirectory(account: String, serverUrl: String) -> Bool {
        return performRealmRead { realm in
            guard let directory = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).first,
                  realm.objects(tableMetadata.self).filter("ocId == %@", directory.ocId).first != nil
            else {
                return false
            }
            return true
        } ?? false
    }

    func getMetadataFromFileId(_ fileId: String?) -> tableMetadata? {
        guard let fileId
        else {
            return nil
        }

        return performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter("fileId == %@", fileId)
                .first.map {
                    tableMetadata(value: $0)
                }
        }
    }

    func getResultFreezeMetadataFromOcId(_ ocId: String?) -> tableMetadata? {
        guard let ocId
        else {
            return nil
        }

        return performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter("ocId == %@", ocId)
                .first?
                .freeze()
        }
    }

    func getResultsMetadatas(predicate: NSPredicate, sortedByKeyPath: String? = nil, ascending: Bool = false, freeze: Bool = false) -> Results<tableMetadata>? {
        return performRealmRead { realm in
            let query = realm.objects(tableMetadata.self).filter(predicate)
            let results: Results<tableMetadata>

            if let sortedByKeyPath {
                results = query.sorted(byKeyPath: sortedByKeyPath, ascending: ascending)
            } else {
                results = query
            }

            return freeze ? results.freeze() : results
        }
    }

    func getMetadatas(predicate: NSPredicate,
                      layoutForView: NCDBLayoutForView?,
                      account: String,
                      completion: @escaping (_ metadatas: [tableMetadata], _ layoutForView: NCDBLayoutForView?, _ account: String ) -> Void) {
        performRealmRead({ realm in
            return realm.objects(tableMetadata.self)
                .filter(predicate)
        }, sync: false) { result in
            guard let result else {
                return completion([], layoutForView, account)
            }
            let sorted = self.sortedResultsMetadata(layoutForView: layoutForView, account: account, metadatas: result)
            let metadatas = sorted.map { tableMetadata(value: $0) }

            return completion(metadatas, layoutForView, account)
        }
    }

    func getResultsMetadatas(predicate: NSPredicate,
                             sortDescriptors: [RealmSwift.SortDescriptor] = [],
                             freeze: Bool = false,
                             completion: @escaping (Results<tableMetadata>?) -> Void) {
        performRealmRead({ realm in
            var results = realm.objects(tableMetadata.self).filter(predicate)
            if !sortDescriptors.isEmpty {
                results = results.sorted(by: sortDescriptors)
            }
            return freeze ? results.freeze() : results
        }, sync: false, completion: completion)
    }

    func getResultsMetadatasAsync(predicate: NSPredicate,
                                  sortDescriptors: [RealmSwift.SortDescriptor] = [],
                                  freeze: Bool = false) async -> Results<tableMetadata>? {
        await performRealmRead { realm in
            var results = realm.objects(tableMetadata.self).filter(predicate)
            if !sortDescriptors.isEmpty {
                results = results.sorted(by: sortDescriptors)
            }
            return freeze ? results.freeze() : results
        }
    }

    func fetchNetworkingProcessDownload(limit: Int, session: String) -> [tableMetadata] {
        return performRealmRead { realm in
            let metadatas = realm.objects(tableMetadata.self)
                .filter("session == %@ AND status == %d", session, NCGlobal.shared.metadataStatusWaitDownload)
                .sorted(byKeyPath: "sessionDate")

            let safeLimit = min(limit, metadatas.count)
            let limitedMetadatas = metadatas.prefix(safeLimit)

            return limitedMetadatas.map { tableMetadata(value: $0) }
        } ?? []
    }

    func hasUploadingMetadataWithChunksOrE2EE() -> Bool {
        return performRealmRead { realm in
            realm.objects(tableMetadata.self)
                .filter("status == %d AND (chunk > 0 OR e2eEncrypted == true)", NCGlobal.shared.metadataStatusUploading)
                .first != nil
        } ?? false
    }

    func createMetadatasFolder(assets: [PHAsset],
                               useSubFolder: Bool,
                               session: NCSession.Session, completion: @escaping ([tableMetadata]) -> Void) {
        var foldersCreated: Set<String> = []
        var metadatas: [tableMetadata] = []
        let serverUrlBase = getAccountAutoUploadDirectory(session: session)
        let fileNameBase = getAccountAutoUploadFileName(account: session.account)
        let predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND directory == true", session.account, serverUrlBase)

        func createMetadata(serverUrl: String, fileName: String, metadata: tableMetadata?) {
            guard !foldersCreated.contains(serverUrl + "/" + fileName) else {
                return
            }
            foldersCreated.insert(serverUrl + "/" + fileName)

            if let metadata {
                metadata.status = NCGlobal.shared.metadataStatusWaitCreateFolder
                metadata.sessionSelector = NCGlobal.shared.selectorUploadAutoUpload
                metadata.sessionDate = Date()
                metadatas.append(tableMetadata(value: metadata))
            } else {
                let metadata = NCManageDatabase.shared.createMetadata(fileName: fileName,
                                                                      fileNameView: fileName,
                                                                      ocId: NSUUID().uuidString,
                                                                      serverUrl: serverUrl,
                                                                      url: "",
                                                                      contentType: "httpd/unix-directory",
                                                                      directory: true,
                                                                      session: session,
                                                                      sceneIdentifier: nil)
                metadata.status = NCGlobal.shared.metadataStatusWaitCreateFolder
                metadata.sessionSelector = NCGlobal.shared.selectorUploadAutoUpload
                metadata.sessionDate = Date()
                metadatas.append(metadata)
            }
        }

        let metadatasFolder = getMetadatas(predicate: predicate)
        let targetPath = serverUrlBase + "/" + fileNameBase
        let metadata = metadatasFolder.first(where: { $0.serverUrl + "/" + $0.fileNameView == targetPath })
        createMetadata(serverUrl: serverUrlBase, fileName: fileNameBase, metadata: metadata)

        if useSubFolder {
            let autoUploadServerUrlBase = self.getAccountAutoUploadServerUrlBase(session: session)
            let autoUploadSubfolderGranularity = self.getAccountAutoUploadSubfolderGranularity()
            let folders = Set(assets.map { self.utilityFileSystem.createGranularityPath(asset: $0) }).sorted()

            for folder in folders {
                let componentsDate = folder.split(separator: "/")
                let year = componentsDate[0]
                let serverUrl = autoUploadServerUrlBase
                let fileName = String(year)
                let targetPath = serverUrl + "/" + fileName
                let metadata = metadatasFolder.first(where: { $0.serverUrl + "/" + $0.fileNameView == targetPath })

                createMetadata(serverUrl: serverUrl, fileName: fileName, metadata: metadata)

                if autoUploadSubfolderGranularity >= NCGlobal.shared.subfolderGranularityMonthly {
                    let month = componentsDate[1]
                    let serverUrl = autoUploadServerUrlBase + "/" + year
                    let fileName = String(month)
                    let targetPath = serverUrl + "/" + fileName
                    let metadata = metadatasFolder.first(where: { $0.serverUrl + "/" + $0.fileNameView == targetPath })

                    createMetadata(serverUrl: serverUrl, fileName: fileName, metadata: metadata)

                    if autoUploadSubfolderGranularity == NCGlobal.shared.subfolderGranularityDaily {
                        let day = componentsDate[2]
                        let serverUrl = autoUploadServerUrlBase + "/" + year + "/" + month
                        let fileName = String(day)
                        let targetPath = serverUrl + "/" + fileName
                        let metadata = metadatasFolder.first(where: { $0.serverUrl + "/" + $0.fileNameView == targetPath })

                        createMetadata(serverUrl: serverUrl, fileName: fileName, metadata: metadata)
                    }
                }
            }
            completion(metadatas)
        } else {
            completion(metadatas)
        }
    }
}
