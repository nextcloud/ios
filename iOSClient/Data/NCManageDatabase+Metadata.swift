//
//  NCManageDatabase+Metadata.swift
//  Nextcloud
//
//  Created by Henrik Storch on 30.11.21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import RealmSwift
import NextcloudKit

class tableMetadata: Object, NCUserBaseUrl {
    override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? tableMetadata,
           self.account == object.account,
           self.etag == object.etag,
           self.fileId == object.fileId,
           self.path == object.path,
           self.fileName == object.fileName,
           self.fileNameView == object.fileNameView,
           self.date == object.date,
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
           Array(self.tags).elementsEqual(Array(object.tags)),
           Array(self.shareType).elementsEqual(Array(object.shareType)),
           Array(self.sharePermissionsCloudMesh).elementsEqual(Array(object.sharePermissionsCloudMesh)) {
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
    @objc dynamic var directory: Bool = false
    @objc dynamic var downloadURL = ""
    @objc dynamic var e2eEncrypted: Bool = false
    @objc dynamic var edited: Bool = false
    @objc dynamic var etag = ""
    @objc dynamic var etagResource = ""
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
    @objc dynamic var ocIdTemp = ""
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
    @objc dynamic var quotaUsedBytes: Int64 = 0
    @objc dynamic var quotaAvailableBytes: Int64 = 0
    @objc dynamic var resourceType = ""
    @objc dynamic var richWorkspace: String?
    @objc dynamic var sceneIdentifier: String?
    @objc dynamic var serverUrl = ""
    @objc dynamic var session = ""
    @objc dynamic var sessionDate: Date?
    @objc dynamic var sessionError = ""
    @objc dynamic var sessionSelector = ""
    @objc dynamic var sessionTaskIdentifier: Int = 0
    @objc dynamic var sharePermissionsCollaborationServices: Int = 0
    let sharePermissionsCloudMesh = List<String>()
    let shareType = List<Int>()
    @objc dynamic var size: Int64 = 0
    @objc dynamic var status: Int = 0
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

    var isPrintable: Bool {
        if isDocumentViewableOnly {
            return false
        }
        if ["application/pdf", "com.adobe.pdf"].contains(contentType) || contentType.hasPrefix("text/") || classFile == NKCommon.TypeClassFile.image.rawValue {
            return true
        }
        return false
    }

    var isSavebleInCameraRoll: Bool {
        return (classFile == NKCommon.TypeClassFile.image.rawValue && contentType != "image/svg+xml") || classFile == NKCommon.TypeClassFile.video.rawValue
    }

    var isDocumentViewableOnly: Bool {
        sharePermissionsCollaborationServices == NCPermissions().permissionReadShare && classFile == NKCommon.TypeClassFile.document.rawValue
    }

    var isAudioOrVideo: Bool {
        return classFile == NKCommon.TypeClassFile.audio.rawValue || classFile == NKCommon.TypeClassFile.video.rawValue
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
        !isDocumentViewableOnly && !directory
    }

    var isCopyableMovable: Bool {
        !isDocumentViewableOnly && !isDirectoryE2EE && !e2eEncrypted
    }

    var isModifiableWithQuickLook: Bool {
        if directory || isDocumentViewableOnly || isDirectoryE2EE {
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
        return session.isEmpty && !isDocumentViewableOnly && !directory && !NCBrandOptions.shared.disable_openin_file
    }

    var canSetDirectoryAsE2EE: Bool {
        return directory && size == 0 && !e2eEncrypted && NCKeychain().isEndToEndEnabled(account: account)
    }

    var canUnsetDirectoryAsE2EE: Bool {
        return !isDirectoryE2EE && directory && size == 0 && e2eEncrypted && NCKeychain().isEndToEndEnabled(account: account)
    }

    var isWaitingTransfer: Bool {
        status == NCGlobal.shared.metadataStatusWaitDownload || status == NCGlobal.shared.metadataStatusWaitUpload || status == NCGlobal.shared.metadataStatusUploadError
    }

    var isInTransfer: Bool {
        status == NCGlobal.shared.metadataStatusDownloading || status == NCGlobal.shared.metadataStatusUploading
    }

    var isTransferInForeground: Bool {
        (status > 0 && (chunk > 0 || e2eEncrypted))
    }

    var isDownload: Bool {
        status == NCGlobal.shared.metadataStatusDownloading
    }

    var isUpload: Bool {
        status == NCGlobal.shared.metadataStatusUploading
    }

    @objc var isDirectoryE2EE: Bool {
        NCUtilityFileSystem().isDirectoryE2EE(account: account, urlBase: urlBase, userId: userId, serverUrl: serverUrl)
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
        !isImage && !isAudioOrVideo && hasPreview && NCUtilityFileSystem().fileProviderStoragePreviewIconExists(ocId, etag: etag)
    }

    var isAvailableEditorView: Bool {
        guard !isPDF,
              classFile == NKCommon.TypeClassFile.document.rawValue,
              NextcloudKit.shared.isNetworkReachable() else { return false }
        let utility = NCUtility()
        let directEditingEditors = utility.editorsDirectEditing(account: account, contentType: contentType)
        let richDocumentEditor = utility.isTypeFileRichDocument(self)

        if NCGlobal.shared.capabilityRichDocumentsEnabled && richDocumentEditor && directEditingEditors.isEmpty {
            // RichDocument: Collabora
            return true
        } else if directEditingEditors.contains(NCGlobal.shared.editorText) || directEditingEditors.contains(NCGlobal.shared.editorOnlyoffice) {
            // DirectEditing: Nextcloud Text - OnlyOffice
           return true
        }
        return false
    }

    var isAvailableRichDocumentEditorView: Bool {
        guard (classFile == NKCommon.TypeClassFile.document.rawValue) && NCGlobal.shared.capabilityRichDocumentsEnabled && NextcloudKit.shared.isNetworkReachable() else { return false }

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
        if !NCGlobal.shared.capabilityFileSharingApiEnabled || (NCGlobal.shared.capabilityE2EEEnabled && isDirectoryE2EE) {
            return false
        }
        return true
    }
}

extension NCManageDatabase {
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
        metadata.directory = file.directory
        metadata.downloadURL = file.downloadURL
        metadata.e2eEncrypted = file.e2eEncrypted
        metadata.etag = file.etag
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
        metadata.quotaUsedBytes = file.quotaUsedBytes
        metadata.quotaAvailableBytes = file.quotaAvailableBytes
        metadata.richWorkspace = file.richWorkspace
        metadata.resourceType = file.resourceType
        metadata.serverUrl = file.serverUrl
        metadata.sharePermissionsCollaborationServices = file.sharePermissionsCollaborationServices
        for element in file.sharePermissionsCloudMesh {
            metadata.sharePermissionsCloudMesh.append(element)
        }
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
            if let tableE2eEncryption = NCManageDatabase.shared.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", file.account, file.serverUrl, file.fileName)) {
                metadata.fileNameView = tableE2eEncryption.fileName
                let results = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: metadata.fileNameView, mimeType: file.contentType, directory: file.directory)
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
                metadataFolder = tableMetadata(value: metadata)
            } else {
                metadatas.append(metadata)
            }

            counter += 1
        }
        completion(metadataFolder, metadatas)
    }

    func convertFilesToMetadatas(_ files: [NKFile], useFirstAsMetadataFolder: Bool) async -> (metadataFolder: tableMetadata, metadatas: [tableMetadata]) {
        await withUnsafeContinuation({ continuation in
            convertFilesToMetadatas(files, useFirstAsMetadataFolder: useFirstAsMetadataFolder) { metadataFolder, metadatas in
                continuation.resume(returning: (metadataFolder, metadatas))
            }
        })
    }

    func createMetadata(account: String, user: String, userId: String, fileName: String, fileNameView: String, ocId: String, serverUrl: String, urlBase: String, url: String, contentType: String, isUrl: Bool = false, name: String = NCGlobal.shared.appName, subline: String? = nil, iconName: String? = nil, iconUrl: String? = nil) -> tableMetadata {
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
            let (mimeType, classFile, iconName, _, _, _) = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: fileName, mimeType: contentType, directory: false)
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

        metadata.account = account
        metadata.creationDate = Date() as NSDate
        metadata.date = Date() as NSDate
        metadata.hasPreview = true
        metadata.etag = ocId
        metadata.fileName = fileName
        metadata.fileNameView = fileName
        metadata.name = name
        metadata.ocId = ocId
        metadata.ocIdTemp = ocId
        metadata.permissions = "RGDNVW"
        metadata.serverUrl = serverUrl
        metadata.subline = subline
        metadata.uploadDate = Date() as NSDate
        metadata.url = url
        metadata.urlBase = urlBase
        metadata.user = user
        metadata.userId = userId

        if !metadata.urlBase.isEmpty, metadata.serverUrl.hasPrefix(metadata.urlBase) {
            metadata.path = String(metadata.serverUrl.dropFirst(metadata.urlBase.count)) + "/"
        }
        return metadata
    }

    @discardableResult
    func addMetadata(_ metadata: tableMetadata) -> tableMetadata? {
        let result = tableMetadata(value: metadata)

        do {
            let realm = try Realm()
            try realm.write {
                realm.add(result, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
            return nil
        }
        return tableMetadata(value: result)
    }

    func addMetadatasWithoutUpdate(_ metadatas: [tableMetadata]) {
        if metadatas.isEmpty { return }

        do {
            let realm = try Realm()
            for metadata in metadatas {
                if realm.objects(tableMetadata.self).filter("ocId == %@", metadata.ocId).first != nil {
                    return
                }
                try realm.write {
                    realm.add(metadata, update: .all)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func addMetadatas(_ metadatas: [tableMetadata]) {
        do {
            let realm = try Realm()
            try realm.write {
                realm.add(metadatas, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func deleteMetadata(predicate: NSPredicate) {
        do {
            let realm = try Realm()
            try realm.write {
                let results = realm.objects(tableMetadata.self).filter(predicate)
                realm.delete(results)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func deleteMetadata(results: Results<tableMetadata>) {
        do {
            let realm = try Realm()
            try realm.write {
                realm.delete(results)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func moveMetadata(ocId: String, serverUrlTo: String) {
        do {
            let realm = try Realm()
            try realm.write {
                if let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first {
                    result.serverUrl = serverUrlTo
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func renameMetadata(fileNameTo: String, ocId: String) {
        do {
            let realm = try Realm()
            try realm.write {
                if let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first {
                    let resultsType = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: fileNameTo, mimeType: "", directory: result.directory)
                    result.fileName = fileNameTo
                    result.fileNameView = fileNameTo
                    result.iconName = resultsType.iconName
                    result.contentType = resultsType.mimeType
                    result.classFile = resultsType.classFile
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func setMetadataEtagResource(ocId: String, etagResource: String?) {
        guard let etagResource = etagResource else { return }

        do {
            let realm = try Realm()
            try realm.write {
                let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                result?.etagResource = etagResource
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func setMetadataFavorite(ocId: String, favorite: Bool) {
        do {
            let realm = try Realm()
            try realm.write {
                let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                result?.favorite = favorite
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func setMetadataLivePhotoByServer(account: String, ocId: String, livePhotoFile: String) {
        do {
            let realm = try Realm()
            try realm.write {
                if let result = realm.objects(tableMetadata.self).filter("account == %@ AND ocId == %@", account, ocId).first {
                    result.isFlaggedAsLivePhotoByServer = true
                    result.livePhotoFile = livePhotoFile
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func updateMetadatasFavorite(account: String, metadatas: [tableMetadata]) {
        do {
            let realm = try Realm()
            try realm.write {
                let results = realm.objects(tableMetadata.self).filter("account == %@ AND favorite == true", account)
                for result in results {
                    result.favorite = false
                }
                for metadata in metadatas {
                    if let result = realm.objects(tableMetadata.self).filter("account == %@ AND ocId == %@", account, metadata.ocId).first {
                        result.favorite = true
                    } else {
                        realm.add(metadata, update: .modified)
                    }
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func setMetadataEncrypted(ocId: String, encrypted: Bool) {
        do {
            let realm = try Realm()
            try realm.write {
                let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                result?.e2eEncrypted = encrypted
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func setMetadataFileNameView(serverUrl: String, fileName: String, newFileNameView: String, account: String) {
        do {
            let realm = try Realm()
            try realm.write {
                let result = realm.objects(tableMetadata.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@", account, serverUrl, fileName).first
                result?.fileNameView = newFileNameView
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func getMetadata(predicate: NSPredicate) -> tableMetadata? {
        do {
            let realm = try Realm()
            realm.refresh()
            guard let result = realm.objects(tableMetadata.self).filter(predicate).first else { return nil }
            return tableMetadata(value: result)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }

        return nil
    }

    func getMetadata(predicate: NSPredicate, sorted: String, ascending: Bool) -> tableMetadata? {
        do {
            let realm = try Realm()
            realm.refresh()
            guard let result = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending).first else { return nil }
            return tableMetadata(value: result)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getMetadatas(predicate: NSPredicate) -> [tableMetadata] {
        do {
            let realm = try Realm()
            realm.refresh()
            let results = realm.objects(tableMetadata.self).filter(predicate)
            return Array(results.map { tableMetadata(value: $0) })
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return []
    }

    func getMetadatas(predicate: NSPredicate, sorted: String, ascending: Bool = false) -> [tableMetadata]? {
        do {
            let realm = try Realm()
            let results = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)
            return Array(results.map { tableMetadata(value: $0) })
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getResultsMetadatas(predicate: NSPredicate, sorted: String? = nil, ascending: Bool = false) -> Results<tableMetadata>? {
        do {
            let realm = try Realm()
            if let sorted {
                return realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)
            } else {
                return realm.objects(tableMetadata.self).filter(predicate)
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getResultsMetadatas(predicate: NSPredicate, sorted: [RealmSwift.SortDescriptor]) -> Results<tableMetadata>? {
        do {
            let realm = try Realm()
            return realm.objects(tableMetadata.self).filter(predicate).sorted(by: sorted)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getResultMetadata(predicate: NSPredicate) -> tableMetadata? {
        do {
            let realm = try Realm()
            return realm.objects(tableMetadata.self).filter(predicate).first
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getMetadatas(predicate: NSPredicate, numItems: Int, sorted: String, ascending: Bool) -> [tableMetadata] {
        var counter: Int = 0
        var metadatas: [tableMetadata] = []

        do {
            let realm = try Realm()
            realm.refresh()
            let results = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)
            for result in results where counter < numItems {
                metadatas.append(tableMetadata(value: result))
                counter += 1
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return metadatas
    }

    func getMetadataAtIndex(predicate: NSPredicate, sorted: String, ascending: Bool, index: Int) -> tableMetadata? {
        do {
            let realm = try Realm()
            realm.refresh()
            let results = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)
            if results.isEmpty {
                return nil
            } else {
                return tableMetadata(value: results[index])
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getMetadataFromOcId(_ ocId: String?) -> tableMetadata? {
        guard let ocId else { return nil }

        do {
            let realm = try Realm()
            realm.refresh()
            guard let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first else { return nil }
            return tableMetadata(value: result)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getMetadataFromOcIdAndOcIdTemp(_ ocId: String?) -> tableMetadata? {
        guard let ocId else { return nil }

        do {
            let realm = try Realm()
            realm.refresh()
            if let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first {
                return tableMetadata(value: result)
            }
            if let result = realm.objects(tableMetadata.self).filter("ocIdTemp == %@", ocId).first {
                return tableMetadata(value: result)
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getResultMetadataFromOcId(_ ocId: String?) -> tableMetadata? {
        guard let ocId else { return nil }

        do {
            let realm = try Realm()
            return realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getMetadataFromFileName(_ fileName: String, serverUrl: String) -> tableMetadata? {
        do {
            let realm = try Realm()
            realm.refresh()
            guard let result = realm.objects(tableMetadata.self).filter("fileName == %@ AND serverUrl == %@", fileName, serverUrl).first else { return nil }
            return tableMetadata(value: result)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getMetadataFromFileNameLocalPath(_ fileNameLocalPath: String?) -> tableMetadata? {
        let components = fileNameLocalPath?.components(separatedBy: "/")

        if let count = components?.count,
           components?.count ?? 0 > 2,
           let ocId = components?[count - 2] {
            do {
                let realm = try Realm()
                realm.refresh()
                guard let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first else { return nil }
                return tableMetadata(value: result)
            } catch let error as NSError {
                NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
            }
        }
        return nil
    }

    func getTableMetadataFromOcId(_ ocId: String?) -> tableMetadata? {
        guard let ocId else { return nil }

        do {
            let realm = try Realm()
            realm.refresh()
            return realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getMetadataFromFileId(_ fileId: String?) -> tableMetadata? {
        do {
            let realm = try Realm()
            realm.refresh()
            guard let fileId = fileId else { return nil }
            guard let result = realm.objects(tableMetadata.self).filter("fileId == %@", fileId).first else { return nil }
            return tableMetadata(value: result)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getMetadataFolder(account: String, urlBase: String, userId: String, serverUrl: String) -> tableMetadata? {
        var serverUrl = serverUrl
        var fileName = ""
        let serverUrlHome = utilityFileSystem.getHomeServer(urlBase: urlBase, userId: userId)

        if serverUrlHome == serverUrl {
            fileName = "."
            serverUrl = ".."
        } else {
            fileName = (serverUrl as NSString).lastPathComponent
            if let path = utilityFileSystem.deleteLastPath(serverUrlPath: serverUrl) {
                serverUrl = path
            }
        }

        do {
            let realm = try Realm()
            realm.refresh()
            guard let result = realm.objects(tableMetadata.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@", account, serverUrl, fileName).first else { return nil }
            return tableMetadata(value: result)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getTableMetadatasDirectoryFavoriteIdentifierRank(account: String) -> [String: NSNumber] {
        var listIdentifierRank: [String: NSNumber] = [:]
        var counter = 10 as Int64

        do {
            let realm = try Realm()
            realm.refresh()
            let results = realm.objects(tableMetadata.self).filter("account == %@ AND directory == true AND favorite == true", account).sorted(byKeyPath: "fileNameView", ascending: true)
            for result in results {
                counter += 1
                listIdentifierRank[result.ocId] = NSNumber(value: Int64(counter))
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return listIdentifierRank
    }

    @objc func clearMetadatasUpload(account: String) {
        do {
            let realm = try Realm()
            try realm.write {
                let results = realm.objects(tableMetadata.self).filter("account == %@ AND (status == %d OR status == %d)", account, NCGlobal.shared.metadataStatusWaitUpload, NCGlobal.shared.metadataStatusUploadError)
                realm.delete(results)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func readMarkerMetadata(account: String, fileId: String) {
        do {
            let realm = try Realm()
            try realm.write {
                let results = realm.objects(tableMetadata.self).filter("account == %@ AND fileId == %@", account, fileId)
                for result in results {
                    result.commentsUnread = false
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func getAssetLocalIdentifiersUploaded(account: String) -> [String]? {
        var assetLocalIdentifiers: [String] = []

        do {
            let realm = try Realm()
            let results = realm.objects(tableMetadata.self).filter("account == %@ AND assetLocalIdentifier != ''", account)
            for result in results {
                assetLocalIdentifiers.append(result.assetLocalIdentifier)
            }
            return assetLocalIdentifiers
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func clearAssetLocalIdentifiers(_ assetLocalIdentifiers: [String], account: String) {
        do {
            let realm = try Realm()
            try realm.write {
                let results = realm.objects(tableMetadata.self).filter("account == %@ AND assetLocalIdentifier IN %@", account, assetLocalIdentifiers)
                for result in results {
                    result.assetLocalIdentifier = ""
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func getMetadataLivePhoto(metadata: tableMetadata) -> tableMetadata? {
        guard metadata.isLivePhoto else { return nil }

        do {
            let realm = try Realm()
            guard let result = realm.objects(tableMetadata.self).filter(NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileId == %@", metadata.account, metadata.serverUrl, metadata.livePhotoFile)).first else { return nil }
            return tableMetadata(value: result)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func isMetadataShareOrMounted(metadata: tableMetadata, metadataFolder: tableMetadata?) -> Bool {
        let permissions = NCPermissions()
        var isShare = false
        var isMounted = false

        if metadataFolder != nil {
            isShare = metadata.permissions.contains(permissions.permissionShared) && !metadataFolder!.permissions.contains(permissions.permissionShared)
            isMounted = metadata.permissions.contains(permissions.permissionMounted) && !metadataFolder!.permissions.contains(permissions.permissionMounted)
        } else if let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
            isShare = metadata.permissions.contains(permissions.permissionShared) && !directory.permissions.contains(permissions.permissionShared)
            isMounted = metadata.permissions.contains(permissions.permissionMounted) && !directory.permissions.contains(permissions.permissionMounted)
        }

        if isShare || isMounted {
            return true
        } else {
            return false
        }
    }

    func getMetadataConflict(account: String, serverUrl: String, fileNameView: String) -> tableMetadata? {
        // verify exists conflict
        let fileNameExtension = (fileNameView as NSString).pathExtension.lowercased()
        let fileNameNoExtension = (fileNameView as NSString).deletingPathExtension
        var fileNameConflict = fileNameView

        if fileNameExtension == "heic", NCKeychain().formatCompatibility {
            fileNameConflict = fileNameNoExtension + ".jpg"
        }
        return getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView == %@", account, serverUrl, fileNameConflict))
    }

    func getNumMetadatasInUpload() -> Int {
        do {
            let realm = try Realm()
            realm.refresh()
            return realm.objects(tableMetadata.self).filter(NSPredicate(format: "status == %i", NCGlobal.shared.metadataStatusUploading)).count
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return 0
    }

    func getMetadataFromDirectory(account: String, serverUrl: String) -> tableMetadata? {
        do {
            let realm = try Realm()
            realm.refresh()
            guard let directory = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).first else { return nil }
            guard let result = realm.objects(tableMetadata.self).filter("ocId == %@", directory.ocId).first else { return nil }
            return tableMetadata(value: result)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getMetadatasFromGroupfolders(account: String, urlBase: String, userId: String) -> [tableMetadata] {
        var metadatas: [tableMetadata] = []
        let homeServerUrl = utilityFileSystem.getHomeServer(urlBase: urlBase, userId: userId)

        do {
            let realm = try Realm()
            realm.refresh()
            let groupfolders = realm.objects(TableGroupfolders.self).filter("account == %@", account)
            for groupfolder in groupfolders {
                let mountPoint = groupfolder.mountPoint.hasPrefix("/") ? groupfolder.mountPoint : "/" + groupfolder.mountPoint
                let serverUrlFileName = homeServerUrl + mountPoint
                if let directory = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl == %@", account, serverUrlFileName).first,
                   let metadata = realm.objects(tableMetadata.self).filter("ocId == %@", directory.ocId).first {
                    metadatas.append(tableMetadata(value: metadata))
                }
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return metadatas
    }

    func getMetadatasInError(account: String) -> Results<tableMetadata>? {
        do {
            let realm = try Realm()
            let results = realm.objects(tableMetadata.self).filter("account == %@ AND errorCodeCounter > 1", account)
            return results
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    @discardableResult
    func updateMetadatas(_ metadatas: [tableMetadata], predicate: NSPredicate) -> (metadatasDifferentCount: Int, metadatasModified: Int) {
        var metadatasDifferentCount: Int = 0
        var metadatasModified: Int = 0

        do {
            let realm = try Realm()
            try realm.write {
                let results = realm.objects(tableMetadata.self).filter(predicate)
                metadatasDifferentCount = metadatas.count - results.count
                for metadata in metadatas {
                    if let result = results.first(where: { $0.ocId == metadata.ocId }) {
                        // before realm.add copy the value not available from server
                        metadata.assetLocalIdentifier = result.assetLocalIdentifier
                        if !metadata.isEqual(result) { metadatasModified += 1 }
                    }
                }
                if metadatasDifferentCount != 0 || metadatasModified > 0 {
                    realm.delete(results)
                    for metadata in metadatas {
                        realm.add(tableMetadata(value: metadata), update: .all)
                    }
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
        return (metadatasDifferentCount, metadatasModified)
    }

    func replaceMetadata(_ metadatas: [tableMetadata], predicate: NSPredicate) {
        do {
            let realm = try Realm()
            try realm.write {
                let results = realm.objects(tableMetadata.self).filter(predicate)
                realm.delete(results)
                for metadata in metadatas {
                    if results.where({ $0.ocId == metadata.ocId }).isEmpty {
                        realm.add(tableMetadata(value: metadata), update: .modified)
                    } else {
                        continue
                    }
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func getMediaMetadatas(predicate: NSPredicate) -> ThreadSafeArray<tableMetadata>? {
        do {
            let realm = try Realm()
            let results = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: "date", ascending: false)
            return ThreadSafeArray(results.map { tableMetadata(value: $0) })
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }
}
