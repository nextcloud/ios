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
        if let object = object as? tableMetadata {
            return self.fileId == object.fileId && self.account == object.account
                   && self.path == object.path && self.fileName == object.fileName
        } else {
            return false
        }
    }

    @objc dynamic var account = ""
    @objc dynamic var assetLocalIdentifier = ""
    @objc dynamic var checksums = ""
    @objc dynamic var chunk: Bool = false
    @objc dynamic var classFile = ""
    @objc dynamic var commentsUnread: Bool = false
    @objc dynamic var contentType = ""
    @objc dynamic var creationDate = NSDate()
    @objc dynamic var dataFingerprint = ""
    @objc dynamic var date = NSDate()
    @objc dynamic var directory: Bool = false
    @objc dynamic var deleteAssetLocalIdentifier: Bool = false
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
    @objc dynamic var iconName = ""
    @objc dynamic var iconUrl = ""
    @objc dynamic var isExtractFile: Bool = false
    @objc dynamic var livePhoto: Bool = false
    @objc dynamic var mountType = ""
    @objc dynamic var name = ""                                             // for unifiedSearch is the provider.id
    @objc dynamic var note = ""
    @objc dynamic var ocId = ""
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
    @objc dynamic var serverUrl = ""
    @objc dynamic var session = ""
    @objc dynamic var sessionError = ""
    @objc dynamic var sessionSelector = ""
    @objc dynamic var sessionTaskIdentifier: Int = 0
    @objc dynamic var sharePermissionsCollaborationServices: Int = 0
    let sharePermissionsCloudMesh = List<String>()
    let shareType = List<Int>()
    @objc dynamic var size: Int64 = 0
    @objc dynamic var status: Int = 0
    @objc dynamic var subline: String?
    @objc dynamic var trashbinFileName = ""
    @objc dynamic var trashbinOriginalLocation = ""
    @objc dynamic var trashbinDeletionTime = NSDate()
    @objc dynamic var uploadDate = NSDate()
    @objc dynamic var url = ""
    @objc dynamic var urlBase = ""
    @objc dynamic var user = ""
    @objc dynamic var userId = ""

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
        sharePermissionsCollaborationServices == NCGlobal.shared.permissionReadShare && classFile == NKCommon.TypeClassFile.document.rawValue
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
        return contentType == "com.adobe.pdf" || contentType == "application/pdf" || classFile == NKCommon.TypeClassFile.image.rawValue
    }

    var isDeletable: Bool {
        if !isDirectoryE2EE && e2eEncrypted {
            return false
        }
        return true
    }

    var isSettableOnOffline: Bool {
        return session.isEmpty && !isDocumentViewableOnly
    }

    var canOpenIn: Bool {
        return session.isEmpty && !isDocumentViewableOnly && !directory && !NCBrandOptions.shared.disable_openin_file
    }

    var isDirectoySettableE2EE: Bool {
        return directory && size == 0 && !e2eEncrypted && CCUtility.isEnd(toEndEnabled: account)
    }

    var isSharable: Bool {
        let sharing = NCManageDatabase.shared.getCapabilitiesServerBool(account: account, elements: NCElementsJSON.shared.capabilitiesFileSharingApiEnabled, exists: false)
        if !sharing { return false }
        if !e2eEncrypted && !isDirectoryE2EE { return true }
        let serverVersionMajor = NCManageDatabase.shared.getCapabilitiesServerInt(account: account, elements: NCElementsJSON.shared.capabilitiesVersionMajor)
        if serverVersionMajor >= NCGlobal.shared.nextcloudVersion26 && directory {
            // E2EE DIRECTORY SECURE FILE DROP (SHARE AVAILABLE)
            return true
        } else {
            return false
        }
    }

    var isDirectoryUnsettableE2EE: Bool {
        return !isDirectoryE2EE && directory && size == 0 && e2eEncrypted && CCUtility.isEnd(toEndEnabled: account)
    }

    var canOpenExternalEditor: Bool {
        if isDocumentViewableOnly {
            return false
        }

        let editors = NCUtility.shared.isDirectEditing(account: account, contentType: contentType)
        let isRichDocument = NCUtility.shared.isRichDocument(self)

        return classFile == NKCommon.TypeClassFile.document.rawValue && editors.contains(NCGlobal.shared.editorText) && ((editors.contains(NCGlobal.shared.editorOnlyoffice) || isRichDocument))
    }

    var isDownloadUpload: Bool {
        status == NCGlobal.shared.metadataStatusInDownload || status == NCGlobal.shared.metadataStatusDownloading || status == NCGlobal.shared.metadataStatusInUpload || status == NCGlobal.shared.metadataStatusUploading
    }

    var isDownload: Bool {
        status == NCGlobal.shared.metadataStatusInDownload || status == NCGlobal.shared.metadataStatusDownloading
    }

    var isUpload: Bool {
        status == NCGlobal.shared.metadataStatusInUpload || status == NCGlobal.shared.metadataStatusUploading
    }

    @objc var isDirectoryE2EE: Bool {
        NCUtility.shared.isDirectoryE2EE(serverUrl: serverUrl, account: account, urlBase: urlBase, userId: userId)
    }

    /// Returns false if the user is lokced out of the file. I.e. The file is locked but by somone else
    func canUnlock(as user: String) -> Bool {
        return !lock || (lockOwner == user && lockOwnerType == 0)
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
            metadata.creationDate = date
        } else {
            metadata.creationDate = file.date
        }
        metadata.dataFingerprint = file.dataFingerprint
        metadata.date = file.date
        metadata.directory = file.directory
        metadata.downloadURL = file.downloadURL
        metadata.e2eEncrypted = file.e2eEncrypted
        metadata.etag = file.etag
        metadata.favorite = file.favorite
        metadata.fileId = file.fileId
        metadata.fileName = file.fileName
        metadata.fileNameView = file.fileName
        metadata.hasPreview = file.hasPreview
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
        metadata.size = file.size
        metadata.classFile = file.classFile
        //FIXME: iOS 12.0,* don't detect UTI text/markdown, text/x-markdown
        if (metadata.contentType == "text/markdown" || metadata.contentType == "text/x-markdown") && metadata.classFile == NKCommon.TypeClassFile.unknow.rawValue {
            metadata.classFile = NKCommon.TypeClassFile.document.rawValue
        }
        if let date = file.uploadDate {
            metadata.uploadDate = date
        } else {
            metadata.uploadDate = file.date
        }
        metadata.urlBase = file.urlBase
        metadata.user = file.user
        metadata.userId = file.userId

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

    func convertFilesToMetadatas(_ files: [NKFile], useMetadataFolder: Bool, completion: @escaping (_ metadataFolder: tableMetadata, _ metadatasFolder: [tableMetadata], _ metadatas: [tableMetadata]) -> Void) {

        var counter: Int = 0
        var isDirectoryE2EE: Bool = false
        let listServerUrl = ThreadSafeDictionary<String,Bool>()

        var metadataFolder = tableMetadata()
        var metadataFolders: [tableMetadata] = []
        var metadatas: [tableMetadata] = []

        for file in files {

            if let key = listServerUrl[file.serverUrl] {
                isDirectoryE2EE = key
            } else {
                isDirectoryE2EE = NCUtility.shared.isDirectoryE2EE(file: file)
                listServerUrl[file.serverUrl] = isDirectoryE2EE
            }

            let metadata = convertFileToMetadata(file, isDirectoryE2EE: isDirectoryE2EE)

            if counter == 0 && useMetadataFolder {
                metadataFolder = tableMetadata.init(value: metadata)
            } else {
                metadatas.append(metadata)
                if metadata.directory {
                    metadataFolders.append(metadata)
                }
            }

            counter += 1
        }

        //
        // Detect Live photo
        //
        var metadataOutput: [tableMetadata] = []
        metadatas = metadatas.sorted(by: {$0.fileNameView < $1.fileNameView})

        for index in metadatas.indices {
            let metadata = metadatas[index]
            if index < metadatas.count - 1,
                metadata.fileNoExtension == metadatas[index+1].fileNoExtension,
                ((metadata.classFile == NKCommon.TypeClassFile.image.rawValue && metadatas[index+1].classFile == NKCommon.TypeClassFile.video.rawValue) || (metadata.classFile == NKCommon.TypeClassFile.video.rawValue && metadatas[index+1].classFile == NKCommon.TypeClassFile.image.rawValue)){
                metadata.livePhoto = true
                metadatas[index+1].livePhoto = true
            }
            metadataOutput.append(metadata)
        }

        completion(metadataFolder, metadataFolders, metadataOutput)
    }

    func createMetadata(account: String, user: String, userId: String, fileName: String, fileNameView: String, ocId: String, serverUrl: String, urlBase: String, url: String, contentType: String, isLivePhoto: Bool = false, isUrl: Bool = false, name: String = NCGlobal.shared.appName, subline: String? = nil, iconName: String? = nil, iconUrl: String? = nil) -> tableMetadata {

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
            //FIXME: iOS 12.0,* don't detect UTI text/markdown, text/x-markdown
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
        metadata.chunk = false
        metadata.creationDate = Date() as NSDate
        metadata.date = Date() as NSDate
        metadata.hasPreview = true
        metadata.etag = ocId
        metadata.fileName = fileName
        metadata.fileNameView = fileName
        metadata.livePhoto = isLivePhoto
        metadata.name = name
        metadata.ocId = ocId
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

        let realm = try! Realm()
        let result = tableMetadata.init(value: metadata)

        do {
            try realm.write {
                realm.add(result, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
            return nil
        }
        return tableMetadata.init(value: result)
    }

    func addMetadatas(_ metadatas: [tableMetadata]) {

        let realm = try! Realm()

        do {
            try realm.write {
                for metadata in metadatas {
                    realm.add(metadata, update: .all)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func deleteMetadata(predicate: NSPredicate) {

        let realm = try! Realm()

        do {
            try realm.write {
                let results = realm.objects(tableMetadata.self).filter(predicate)
                realm.delete(results)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func moveMetadata(ocId: String, serverUrlTo: String) {

        let realm = try! Realm()

        do {
            try realm.write {
                if let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first {
                    result.serverUrl = serverUrlTo
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func renameMetadata(fileNameTo: String, ocId: String) {

        let realm = try! Realm()

        do {
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
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    @discardableResult
    func updateMetadatas(_ metadatas: [tableMetadata], metadatasResult: [tableMetadata], addCompareLivePhoto: Bool = true, addExistsInLocal: Bool = false, addCompareEtagLocal: Bool = false, addDirectorySynchronized: Bool = false) -> (metadatasUpdate: [tableMetadata], metadatasLocalUpdate: [tableMetadata], metadatasDelete: [tableMetadata]) {

        let realm = try! Realm()
        var ocIdsUdate: [String] = []
        var ocIdsLocalUdate: [String] = []
        var metadatasDelete: [tableMetadata] = []
        var metadatasUpdate: [tableMetadata] = []
        var metadatasLocalUpdate: [tableMetadata] = []

        do {
            try realm.write {

                // DELETE
                for metadataResult in metadatasResult {
                    if metadatas.firstIndex(where: { $0.ocId == metadataResult.ocId }) == nil {
                        if let result = realm.objects(tableMetadata.self).filter(NSPredicate(format: "ocId == %@", metadataResult.ocId)).first {
                            metadatasDelete.append(tableMetadata.init(value: result))
                            realm.delete(result)
                        }
                    }
                }

                // UPDATE/NEW
                for metadata in metadatas {

                    if let result = metadatasResult.first(where: { $0.ocId == metadata.ocId }) {
                        // update
                        // Workaround: check lock bc no etag changes if lock runs out in directory
                        // https://github.com/nextcloud/server/issues/8477
                        if result.status == NCGlobal.shared.metadataStatusNormal && (result.etag != metadata.etag || result.fileNameView != metadata.fileNameView || result.date != metadata.date || result.permissions != metadata.permissions || result.hasPreview != metadata.hasPreview || result.note != metadata.note || result.lock != metadata.lock || result.shareType != metadata.shareType || result.sharePermissionsCloudMesh != metadata.sharePermissionsCloudMesh || result.sharePermissionsCollaborationServices != metadata.sharePermissionsCollaborationServices || result.favorite != metadata.favorite) {
                            ocIdsUdate.append(metadata.ocId)
                            realm.add(tableMetadata.init(value: metadata), update: .all)
                        } else if result.status == NCGlobal.shared.metadataStatusNormal && addCompareLivePhoto && result.livePhoto != metadata.livePhoto {
                            ocIdsUdate.append(metadata.ocId)
                            realm.add(tableMetadata.init(value: metadata), update: .all)
                        }
                    } else {
                        // new
                        ocIdsUdate.append(metadata.ocId)
                        realm.add(tableMetadata.init(value: metadata), update: .all)
                    }

                    if metadata.directory && !ocIdsUdate.contains(metadata.ocId) {
                        let table = realm.objects(tableDirectory.self).filter(NSPredicate(format: "ocId == %@", metadata.ocId)).first
                        if table?.etag != metadata.etag {
                            ocIdsUdate.append(metadata.ocId)
                        }
                    }

                    // Local
                    if !metadata.directory && (addExistsInLocal || addCompareEtagLocal) {
                        let localFile = realm.objects(tableLocalFile.self).filter(NSPredicate(format: "ocId == %@", metadata.ocId)).first
                        if addCompareEtagLocal && localFile != nil && localFile?.etag != metadata.etag {
                            ocIdsLocalUdate.append(metadata.ocId)
                        }
                        if addExistsInLocal && (localFile == nil || localFile?.etag != metadata.etag) && !ocIdsLocalUdate.contains(metadata.ocId) {
                            ocIdsLocalUdate.append(metadata.ocId)
                        }
                    }
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }

        for ocId in ocIdsUdate {
            if let result = realm.objects(tableMetadata.self).filter(NSPredicate(format: "ocId == %@", ocId)).first {
                metadatasUpdate.append(tableMetadata.init(value: result))
            }
        }

        for ocId in ocIdsLocalUdate {
            if let result = realm.objects(tableMetadata.self).filter(NSPredicate(format: "ocId == %@", ocId)).first {
                metadatasLocalUpdate.append(tableMetadata.init(value: result))
            }
        }

        return (metadatasUpdate, metadatasLocalUpdate, metadatasDelete)
    }

    func setMetadataSession(ocId: String, newFileName: String? = nil, session: String? = nil, sessionError: String? = nil, sessionSelector: String? = nil, sessionTaskIdentifier: Int? = nil, status: Int? = nil, etag: String? = nil) {

        let realm = try! Realm()

        do {
            try realm.write {
                let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                if let newFileName = newFileName {
                    result?.fileName = newFileName
                    result?.fileNameView = newFileName
                }
                if let session = session {
                    result?.session = session
                }
                if let sessionError = sessionError {
                    result?.sessionError = sessionError
                }
                if let sessionSelector = sessionSelector {
                    result?.sessionSelector = sessionSelector
                }
                if let sessionTaskIdentifier = sessionTaskIdentifier {
                    result?.sessionTaskIdentifier = sessionTaskIdentifier
                }
                if let status = status {
                    result?.status = status
                }
                if let etag = etag {
                    result?.etag = etag
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    @discardableResult
    func setMetadataStatus(ocId: String, status: Int) -> tableMetadata? {

        let realm = try! Realm()
        var result: tableMetadata?

        do {
            try realm.write {
                result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                result?.status = status
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }

        if let result = result {
            return tableMetadata.init(value: result)
        } else {
            return nil
        }
    }

    func setMetadataEtagResource(ocId: String, etagResource: String?) {

        let realm = try! Realm()
        var result: tableMetadata?
        guard let etagResource = etagResource else { return }

        do {
            try realm.write {
                result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                result?.etagResource = etagResource
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func setMetadataFavorite(ocId: String, favorite: Bool) {

        let realm = try! Realm()

        do {
            try realm.write {
                let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                result?.favorite = favorite
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func updateMetadatasFavorite(account: String, metadatas: [tableMetadata]) {

        let realm = try! Realm()

        do {
            try realm.write {
                let results = realm.objects(tableMetadata.self).filter("account == %@ AND favorite == true", account)
                for result in results {
                    result.favorite = false
                }
                for metadata in metadatas {
                    realm.add(metadata, update: .all)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func setMetadataEncrypted(ocId: String, encrypted: Bool) {

        let realm = try! Realm()

        do {
            try realm.write {
                let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                result?.e2eEncrypted = encrypted
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func setMetadataFileNameView(serverUrl: String, fileName: String, newFileNameView: String, account: String) {

        let realm = try! Realm()

        do {
            try realm.write {
                let result = realm.objects(tableMetadata.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@", account, serverUrl, fileName).first
                result?.fileNameView = newFileNameView
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func getMetadata(predicate: NSPredicate) -> tableMetadata? {

        let realm = try! Realm()
        realm.refresh()

        guard let result = realm.objects(tableMetadata.self).filter(predicate).first else {
            return nil
        }

        return tableMetadata.init(value: result)
    }

    func getMetadata(predicate: NSPredicate, sorted: String, ascending: Bool) -> tableMetadata? {

        let realm = try! Realm()
        realm.refresh()

        guard let result = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending).first else {
            return nil
        }

        return tableMetadata.init(value: result)
    }

    func getMetadatasViewer(predicate: NSPredicate, sorted: String, ascending: Bool) -> [tableMetadata]? {

        let realm = try! Realm()
        realm.refresh()

        let results: Results<tableMetadata>
        var finals: [tableMetadata] = []

        if (tableMetadata().objectSchema.properties.contains { $0.name == sorted }) {
            results = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)
        } else {
            results = realm.objects(tableMetadata.self).filter(predicate)
        }

        // For Live Photo
        var fileNameImages: [String] = []
        let filtered = results.filter { $0.classFile.contains(NKCommon.TypeClassFile.image.rawValue) }
        filtered.forEach { print($0)
            let fileName = ($0.fileNameView as NSString).deletingPathExtension
            fileNameImages.append(fileName)
        }

        for result in results {

            let ext = (result.fileNameView as NSString).pathExtension.uppercased()
            let fileName = (result.fileNameView as NSString).deletingPathExtension

            if !(ext == "MOV" && fileNameImages.contains(fileName)) {
                finals.append(result)
            }
        }

        if finals.count > 0 {
            return Array(finals.map { tableMetadata.init(value: $0) })
        } else {
            return nil
        }
    }

    func getMetadatas(predicate: NSPredicate) -> [tableMetadata] {

        let realm = try! Realm()
        realm.refresh()

        let results = realm.objects(tableMetadata.self).filter(predicate)

        return Array(results.map { tableMetadata.init(value: $0) })
    }

    func getAdvancedMetadatas(predicate: NSPredicate, page: Int = 0, limit: Int = 0, sorted: String, ascending: Bool) -> [tableMetadata] {

        let realm = try! Realm()
        realm.refresh()
        var metadatas: [tableMetadata] = []

        let results = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)

        if results.count > 0 {
            if page == 0 || limit == 0 {
                return Array(results.map { tableMetadata.init(value: $0) })
            } else {

                let nFrom = (page - 1) * limit
                let nTo = nFrom + (limit - 1)

                for n in nFrom...nTo {
                    if n == results.count {
                        break
                    }
                    metadatas.append(tableMetadata.init(value: results[n]))
                }
            }
        }
        return metadatas
    }

    func getMetadataAtIndex(predicate: NSPredicate, sorted: String, ascending: Bool, index: Int) -> tableMetadata? {

        let realm = try! Realm()
        realm.refresh()

        let results = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)

        if results.count > 0  && results.count > index {
            return tableMetadata.init(value: results[index])
        } else {
            return nil
        }
    }

    func getMetadataFromOcId(_ ocId: String?) -> tableMetadata? {

        let realm = try! Realm()
        realm.refresh()

        guard let ocId = ocId else { return nil }
        guard let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first else { return nil }

        return tableMetadata.init(value: result)
    }

    func getMetadataFolder(account: String, urlBase: String, userId: String, serverUrl: String) -> tableMetadata? {

        let realm = try! Realm()
        realm.refresh()
        var serverUrl = serverUrl
        var fileName = ""

        let serverUrlHome = NCUtilityFileSystem.shared.getHomeServer(urlBase: urlBase, userId: userId)
        if serverUrlHome == serverUrl {
            fileName = "."
            serverUrl = ".."
        } else {
            fileName = (serverUrl as NSString).lastPathComponent
            if let path = NCUtilityFileSystem.shared.deleteLastPath(serverUrlPath: serverUrl) {
                serverUrl = path
            }
        }

        guard let result = realm.objects(tableMetadata.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@", account, serverUrl, fileName).first else { return nil }

        return tableMetadata.init(value: result)
    }

    func getTableMetadatasDirectoryFavoriteIdentifierRank(account: String) -> [String: NSNumber] {

        var listIdentifierRank: [String: NSNumber] = [:]
        let realm = try! Realm()
        var counter = 10 as Int64

        let results = realm.objects(tableMetadata.self).filter("account == %@ AND directory == true AND favorite == true", account).sorted(byKeyPath: "fileNameView", ascending: true)

        for result in results {
            counter += 1
            listIdentifierRank[result.ocId] = NSNumber(value: Int64(counter))
        }

        return listIdentifierRank
    }

    @objc func clearMetadatasUpload(account: String) {

        let realm = try! Realm()
        realm.refresh()

        do {
            try realm.write {

                let results = realm.objects(tableMetadata.self).filter("account == %@ AND (status == %d OR status == %@)", account, NCGlobal.shared.metadataStatusWaitUpload, NCGlobal.shared.metadataStatusUploadError)
                realm.delete(results)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func readMarkerMetadata(account: String, fileId: String) {

        let realm = try! Realm()

        do {
            try realm.write {
                let results = realm.objects(tableMetadata.self).filter("account == %@ AND fileId == %@", account, fileId)
                for result in results {
                    result.commentsUnread = false
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func getAssetLocalIdentifiersUploaded(account: String) -> [String] {

        let realm = try! Realm()
        realm.refresh()

        var assetLocalIdentifiers: [String] = []

        let results = realm.objects(tableMetadata.self).filter("account == %@ AND assetLocalIdentifier != '' AND deleteAssetLocalIdentifier == true", account)
        for result in results {
            assetLocalIdentifiers.append(result.assetLocalIdentifier)
        }

        return assetLocalIdentifiers
    }

    func clearAssetLocalIdentifiers(_ assetLocalIdentifiers: [String], account: String) {

        let realm = try! Realm()

        do {
            try realm.write {
                let results = realm.objects(tableMetadata.self).filter("account == %@ AND assetLocalIdentifier IN %@", account, assetLocalIdentifiers)
                for result in results {
                    result.assetLocalIdentifier = ""
                    result.deleteAssetLocalIdentifier = false
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func getMetadataLivePhoto(metadata: tableMetadata) -> tableMetadata? {

        let realm = try! Realm()
        var classFile = metadata.classFile
        var fileName = (metadata.fileNameView as NSString).deletingPathExtension

        if !metadata.livePhoto || !CCUtility.getLivePhoto() {
            return nil
        }

        if classFile == NKCommon.TypeClassFile.image.rawValue {
            classFile = NKCommon.TypeClassFile.video.rawValue
            fileName = fileName + ".mov"
        } else {
            classFile = NKCommon.TypeClassFile.image.rawValue
            fileName = fileName + ".jpg"
        }

        guard let result = realm.objects(tableMetadata.self).filter(NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView CONTAINS[cd] %@ AND ocId != %@ AND classFile == %@", metadata.account, metadata.serverUrl, fileName, metadata.ocId, classFile)).first else {
            return nil
        }

        return tableMetadata.init(value: result)
    }

    func getMetadatasMedia(predicate: NSPredicate, livePhoto: Bool) -> [tableMetadata] {

        let realm = try! Realm()
        var metadatas: [tableMetadata] = []

        do {
            try realm.write {
                let sortProperties = [SortDescriptor(keyPath: "serverUrl", ascending: false), SortDescriptor(keyPath:  "fileNameView", ascending: false)]
                let results = realm.objects(tableMetadata.self).filter(predicate).sorted(by: sortProperties)
                if livePhoto {
                    for index in results.indices {
                        let metadata = results[index]
                        if index < results.count - 1, metadata.fileNoExtension == results[index+1].fileNoExtension {
                            if !metadata.livePhoto {
                                metadata.livePhoto = true
                            }
                            if !results[index+1].livePhoto {
                                results[index+1].livePhoto = true
                            }
                        }
                        if metadata.livePhoto {
                            if metadata.classFile == NKCommon.TypeClassFile.image.rawValue {
                                metadatas.append(tableMetadata.init(value: metadata))
                            }
                            continue
                        } else {
                            metadatas.append(tableMetadata.init(value: metadata))
                        }
                    }
                } else {
                    metadatas = Array(results.map { tableMetadata.init(value: $0) })
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }

        return metadatas
    }

    func isMetadataShareOrMounted(metadata: tableMetadata, metadataFolder: tableMetadata?) -> Bool {

        var isShare = false
        var isMounted = false

        if metadataFolder != nil {

            isShare = metadata.permissions.contains(NCGlobal.shared.permissionShared) && !metadataFolder!.permissions.contains(NCGlobal.shared.permissionShared)
            isMounted = metadata.permissions.contains(NCGlobal.shared.permissionMounted) && !metadataFolder!.permissions.contains(NCGlobal.shared.permissionMounted)

        } else if let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {

            isShare = metadata.permissions.contains(NCGlobal.shared.permissionShared) && !directory.permissions.contains(NCGlobal.shared.permissionShared)
            isMounted = metadata.permissions.contains(NCGlobal.shared.permissionMounted) && !directory.permissions.contains(NCGlobal.shared.permissionMounted)
        }

        if isShare || isMounted {
            return true
        } else {
            return false
        }
    }

    func isDownloadMetadata(_ metadata: tableMetadata, download: Bool) -> Bool {

        let localFile = getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
        let fileSize = CCUtility.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView)
        if (localFile != nil || download) && (localFile?.etag != metadata.etag || fileSize == 0) {
            return true
        }
        return false
    }

    func getMetadataConflict(account: String, serverUrl: String, fileNameView: String) -> tableMetadata? {

        // verify exists conflict
        let fileNameExtension = (fileNameView as NSString).pathExtension.lowercased()
        let fileNameNoExtension = (fileNameView as NSString).deletingPathExtension
        var fileNameConflict = fileNameView

        if fileNameExtension == "heic" && CCUtility.getFormatCompatibility() {
            fileNameConflict = fileNameNoExtension + ".jpg"
        }
        return getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView == %@", account, serverUrl, fileNameConflict))
    }

    func getSubtitles(account: String, serverUrl: String, fileName: String) -> (all:[tableMetadata], existing:[tableMetadata]) {

        let realm = try! Realm()
        let nameOnly = (fileName as NSString).deletingPathExtension + "."
        var metadatas: [tableMetadata] = []

        let results = realm.objects(tableMetadata.self).filter("account == %@ AND serverUrl == %@ AND fileName BEGINSWITH[c] %@ AND fileName ENDSWITH[c] '.srt'", account, serverUrl, nameOnly)
        for result in results {
            if CCUtility.fileProviderStorageExists(result) {
                metadatas.append(result)
            }
        }
        return(Array(results.map { tableMetadata.init(value: $0) }), Array(metadatas.map { tableMetadata.init(value: $0) }))
    }

    func getNumMetadatasInUpload() -> Int {

        let realm = try! Realm()

        let num = realm.objects(tableMetadata.self).filter(NSPredicate(format: "status == %i || status == %i",  NCGlobal.shared.metadataStatusInUpload, NCGlobal.shared.metadataStatusUploading)).count

        return num
    }
}
