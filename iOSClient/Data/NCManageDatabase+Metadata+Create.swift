// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

extension NCManageDatabase {
    func convertFileToMetadata(_ file: NKFile, isDirectoryE2EE: Bool) -> tableMetadata {
        let metadata = self.createMetadata(file)

        #if EXTENSION_FILE_PROVIDER_EXTENSION
        // E2EE find the fileName for fileNameView
        if isDirectoryE2EE || file.e2eEncrypted {
            if let tableE2eEncryption = getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", file.account, file.serverUrl, file.fileName)) {
                metadata.fileNameView = tableE2eEncryption.fileName
            }
        }
        #endif

        if !metadata.directory {
            let results = NKTypeIdentifiersHelper(actor: .shared).getInternalTypeSync(fileName: metadata.fileNameView, mimeType: file.contentType, directory: file.directory, account: file.account)

            metadata.contentType = results.mimeType
            metadata.iconName = results.iconName
            metadata.classFile = results.classFile
            metadata.typeIdentifier = results.typeIdentifier
        }
        return metadata
    }

    func convertFileToMetadataAsync(_ file: NKFile, isDirectoryE2EE: Bool) async -> tableMetadata {
        let metadata = self.createMetadata(file)

        #if !EXTENSION_FILE_PROVIDER_EXTENSION
        // E2EE find the fileName for fileNameView
        if isDirectoryE2EE || file.e2eEncrypted {
            if let tableE2eEncryption = await getE2eEncryptionAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", file.account, file.serverUrl, file.fileName)) {
                metadata.fileNameView = tableE2eEncryption.fileName
            }
        }
        #endif

        if !metadata.directory {
            let results = await NKTypeIdentifiers.shared.getInternalType(fileName: metadata.fileNameView, mimeType: file.contentType, directory: file.directory, account: file.account)

            metadata.contentType = results.mimeType
            metadata.iconName = results.iconName
            metadata.classFile = results.classFile
            metadata.typeIdentifier = results.typeIdentifier
        }

        return metadata.detachedCopy()
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
        completion(metadataFolder.detachedCopy(), metadatas)
    }

    func convertFilesToMetadatasAsync(_ files: [NKFile], useFirstAsMetadataFolder: Bool) async -> (metadataFolder: tableMetadata, metadatas: [tableMetadata]) {
        var counter: Int = 0
        var isDirectoryE2EE: Bool = false
        var listServerUrl: [String: Bool] = [:]
        var metadataFolder = tableMetadata()
        var metadatas: [tableMetadata] = []

        for file in files {
            if let key = listServerUrl[file.serverUrl] {
                isDirectoryE2EE = key
            } else {
                isDirectoryE2EE = NCUtilityFileSystem().isDirectoryE2EE(file: file)
                listServerUrl[file.serverUrl] = isDirectoryE2EE
            }

            let metadata = await convertFileToMetadataAsync(file, isDirectoryE2EE: isDirectoryE2EE)

            if counter == 0 && useFirstAsMetadataFolder {
                metadataFolder = metadata
            } else {
                metadatas.append(metadata)
            }

            counter += 1
        }
        return (metadataFolder.detachedCopy(), metadatas)
    }

    func createMetadata(_ file: NKFile) -> tableMetadata {
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
        if (metadata.contentType == "text/markdown" || metadata.contentType == "text/x-markdown") && metadata.classFile == NKTypeClassFile.unknow.rawValue {
            metadata.classFile = NKTypeClassFile.document.rawValue
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
        metadata.typeIdentifier = file.typeIdentifier

        if file.directory {
            metadata.classFile = NKTypeClassFile.directory.rawValue
            metadata.contentType = "httpd/unix-directory"
            metadata.iconName = NKTypeIconFile.directory.rawValue
        }

        return metadata
    }

    func createMetadata(fileName: String,
                        ocId: String,
                        serverUrl: String,
                        url: String = "",
                        isUrl: Bool = false,
                        name: String = NCGlobal.shared.appName,
                        subline: String? = nil,
                        iconUrl: String? = nil,
                        session: NCSession.Session,
                        sceneIdentifier: String?) -> tableMetadata {
        let metadata = tableMetadata()

        if isUrl {
            metadata.classFile = NKTypeClassFile.url.rawValue
            metadata.contentType = "text/uri-list"
            metadata.iconName = NKTypeClassFile.url.rawValue
            metadata.typeIdentifier = "public.url"
        } else {
            let results = NKTypeIdentifiersHelper(actor: .shared).getInternalTypeSync(fileName: fileName, mimeType: "", directory: false, account: session.account)
            metadata.classFile = results.classFile
            metadata.contentType = results.mimeType
            metadata.iconName = results.iconName
            metadata.typeIdentifier = results.typeIdentifier
        }
        if let iconUrl {
            metadata.iconUrl = iconUrl
        }

        let fileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)

        metadata.account = session.account
        metadata.creationDate = Date() as NSDate
        metadata.date = Date() as NSDate
        metadata.directory = false
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

    func createMetadataDirectory(fileName: String,
                                 ocId: String,
                                 serverUrl: String,
                                 session: NCSession.Session,
                                 sceneIdentifier: String? = nil) -> tableMetadata {
        let metadata = tableMetadata()

        let fileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        metadata.account = session.account
        metadata.creationDate = Date() as NSDate
        metadata.date = Date() as NSDate
        metadata.directory = true
        metadata.hasPreview = false
        metadata.etag = ocId
        metadata.fileName = fileName
        metadata.fileNameView = fileName
        metadata.name = NCGlobal.shared.appName
        metadata.ocId = ocId
        metadata.ocIdTransfer = ocId
        metadata.permissions = "RGDNVW"
        metadata.serverUrl = serverUrl
        metadata.serveUrlFileName = serverUrl + "/" + fileName
        metadata.uploadDate = Date() as NSDate
        metadata.urlBase = session.urlBase
        metadata.user = session.user
        metadata.userId = session.userId
        metadata.sceneIdentifier = sceneIdentifier

        metadata.classFile = NKTypeClassFile.directory.rawValue
        metadata.contentType = "httpd/unix-directory"
        metadata.iconName = NKTypeIconFile.directory.rawValue
        metadata.typeIdentifier = "public.folder"

        return metadata
    }

}
