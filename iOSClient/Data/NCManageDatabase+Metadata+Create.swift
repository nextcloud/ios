// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit
import Photos

extension NCManageDatabase {
    func convertFileToMetadataAsync(_ file: NKFile, mediaSearch: Bool = false, isDirectoryE2EE: Bool? = nil) async -> tableMetadata {
        let metadata = self.createMetadata(file)
        let e2eEncryptedDirectory: Bool
        if let value = isDirectoryE2EE {
            e2eEncryptedDirectory = value
        } else {
            e2eEncryptedDirectory = await NCUtilityFileSystem().isDirectoryE2EEAsync(serverUrl: file.serverUrl,
                                                                                     urlBase: file.urlBase,
                                                                                     userId: file.userId,
                                                                                     account: file.account)
        }

        #if !EXTENSION_FILE_PROVIDER_EXTENSION
        // E2EE find the fileName for fileNameView
        if e2eEncryptedDirectory || file.e2eEncrypted {
            if let tableE2eEncryption = await getE2eEncryptionAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", file.account, file.serverUrl, file.fileName)) {
                metadata.fileNameView = tableE2eEncryption.fileName
            } else if e2eEncryptedDirectory {
                metadata.fileNameView = NSLocalizedString("_e2e_file_encrypted_", comment: "")
            }
        }
        #endif

        if !metadata.directory {
            let results = await NKTypeIdentifiers.shared.getInternalType(fileName: metadata.fileNameView, mimeType: file.contentType, directory: file.directory, account: file.account)

            metadata.contentType = results.mimeType
            metadata.iconName = results.iconName
            metadata.classFile = results.classFile
            metadata.typeIdentifier = results.typeIdentifier
            metadata.mediaSearch = mediaSearch
        }

        return metadata.detachedCopy()
    }

    func convertFileToMetadata(_ file: NKFile, capabilities: NKCapabilities.Capabilities?, isDirectoryE2EE: Bool? = nil, completion: @escaping (tableMetadata) -> Void) {
        let metadata = self.createMetadata(file)
        let e2eEncryptedDirectory: Bool = isDirectoryE2EE ?? NCUtilityFileSystem().isDirectoryE2EE(serverUrl: file.serverUrl,
                                                                                                   urlBase: file.urlBase,
                                                                                                   userId: file.userId,
                                                                                                   account: file.account)

        #if !EXTENSION_FILE_PROVIDER_EXTENSION
        // E2EE find the fileName for fileNameView
        if e2eEncryptedDirectory || file.e2eEncrypted {
            if let tableE2eEncryption = getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", file.account, file.serverUrl, file.fileName)) {
                metadata.fileNameView = tableE2eEncryption.fileName
            } else if e2eEncryptedDirectory {
                metadata.fileNameView = NSLocalizedString("_e2e_file_encrypted_", comment: "")
            }
        }
        #endif

        if !metadata.directory {
            let results = NKTypeIdentifiersHelper.shared.getInternalType(fileName: metadata.fileNameView, mimeType: file.contentType, directory: file.directory, capabilities: capabilities ?? NKCapabilities.Capabilities())

            metadata.contentType = results.mimeType
            metadata.iconName = results.iconName
            metadata.classFile = results.classFile
            metadata.typeIdentifier = results.typeIdentifier
        }
        completion(metadata)
    }

    func convertFilesToMetadatasAsync(_ files: [NKFile], serverUrlMetadataFolder: String? = nil, mediaSearch: Bool = false) async -> (metadataFolder: tableMetadata, metadatas: [tableMetadata]) {
        var counter: Int = 0
        var isDirectoryE2EE: Bool = false
        var listServerUrl: [String: Bool] = [:]
        var metadataFolder = tableMetadata()
        var metadatas: [tableMetadata] = []

        for file in files {
            if let key = listServerUrl[file.serverUrl] {
                isDirectoryE2EE = key
            } else {
                isDirectoryE2EE = NCUtilityFileSystem().isDirectoryE2EE(serverUrl: file.serverUrl, urlBase: file.urlBase, userId: file.userId, account: file.account)
                listServerUrl[file.serverUrl] = isDirectoryE2EE
            }

            let metadata = await convertFileToMetadataAsync(file, mediaSearch: mediaSearch, isDirectoryE2EE: isDirectoryE2EE)

            if serverUrlMetadataFolder == metadata.serverUrlFileName || metadata.fileName == NextcloudKit.shared.nkCommonInstance.rootFileName {
                metadataFolder = metadata
            } else {
                metadatas.append(metadata)
            }

            counter += 1
        }
        return (metadataFolder.detachedCopy(), metadatas)
    }

    func convertFilesToMetadatas(_ files: [NKFile], capabilities: NKCapabilities.Capabilities?, serverUrlMetadataFolder: String? = nil, completion: @escaping (_ metadataFolder: tableMetadata?, _ metadatas: [tableMetadata]) -> Void) {
        var counter: Int = 0
        var isDirectoryE2EE: Bool = false
        let listServerUrl = ThreadSafeDictionary<String, Bool>()
        var metadataFolder: tableMetadata?
        var metadatas: [tableMetadata] = []

        for file in files {
            if let key = listServerUrl[file.serverUrl] {
                isDirectoryE2EE = key
            } else {
                isDirectoryE2EE = NCUtilityFileSystem().isDirectoryE2EE(serverUrl: file.serverUrl, urlBase: file.urlBase, userId: file.userId, account: file.account)
                listServerUrl[file.serverUrl] = isDirectoryE2EE
            }

            convertFileToMetadata(file, capabilities: capabilities, isDirectoryE2EE: isDirectoryE2EE) { metadata in
                if serverUrlMetadataFolder == metadata.serverUrlFileName || metadata.fileName == NextcloudKit.shared.nkCommonInstance.rootFileName {
                    metadataFolder = metadata.detachedCopy()
                } else {
                    metadatas.append(metadata)
                }

                counter += 1
            }
        }
        completion(metadataFolder, metadatas)
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
        metadata.serverUrlFileName = utilityFileSystem.createServerUrl(serverUrl: file.serverUrl, fileName: file.fileName)
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
                        sceneIdentifier: String?,
                        completion: @escaping (tableMetadata) -> Void) {
        Task { @MainActor in
            let metadata = tableMetadata()

            if isUrl {
                metadata.classFile = NKTypeClassFile.url.rawValue
                metadata.contentType = "text/uri-list"
                metadata.iconName = NKTypeClassFile.url.rawValue
                metadata.typeIdentifier = "public.url"
            } else {
                let results = await NKTypeIdentifiers.shared.getInternalType(fileName: fileName, mimeType: "", directory: false, account: session.account)
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
            metadata.serverUrlFileName = utilityFileSystem.createServerUrl(serverUrl: serverUrl, fileName: fileName)
            metadata.subline = subline
            metadata.uploadDate = Date() as NSDate
            metadata.url = url
            metadata.urlBase = session.urlBase
            metadata.user = session.user
            metadata.userId = session.userId
            metadata.sceneIdentifier = sceneIdentifier
            metadata.nativeFormat = !NCPreferences().formatCompatibility

            if !metadata.urlBase.isEmpty, metadata.serverUrl.hasPrefix(metadata.urlBase) {
                metadata.path = String(metadata.serverUrl.dropFirst(metadata.urlBase.count)) + "/"
            }

            completion(metadata)
        }
    }

    func createMetadataAsync(fileName: String,
                             ocId: String,
                             serverUrl: String,
                             url: String = "",
                             isUrl: Bool = false,
                             name: String = NCGlobal.shared.appName,
                             subline: String? = nil,
                             iconUrl: String? = nil,
                             session: NCSession.Session,
                             sceneIdentifier: String?) async -> tableMetadata {
        let metadata = tableMetadata()

        if isUrl {
            metadata.classFile = NKTypeClassFile.url.rawValue
            metadata.contentType = "text/uri-list"
            metadata.iconName = NKTypeClassFile.url.rawValue
            metadata.typeIdentifier = "public.url"
        } else {
            let results = await NKTypeIdentifiers.shared.getInternalType(fileName: fileName,
                                                                         mimeType: "",
                                                                         directory: false,
                                                                         account: session.account)
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
        metadata.serverUrlFileName = utilityFileSystem.createServerUrl(serverUrl: serverUrl, fileName: fileName)
        metadata.subline = subline
        metadata.uploadDate = Date() as NSDate
        metadata.url = url
        metadata.urlBase = session.urlBase
        metadata.user = session.user
        metadata.userId = session.userId
        metadata.sceneIdentifier = sceneIdentifier
        metadata.nativeFormat = !NCPreferences().formatCompatibility

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
        metadata.serverUrlFileName = utilityFileSystem.createServerUrl(serverUrl: serverUrl, fileName: fileName)
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

    private func createMetadatasFolder(assets: [PHAsset],
                                       useSubFolder: Bool,
                                       metadatasFolder: [tableMetadata],
                                       autoUploadDirectory: String,
                                       autoUploadServerUrlBase: String,
                                       autoUploadSubfolderGranularity: Int,
                                       session: NCSession.Session) -> [tableMetadata] {
        var foldersCreated: Set<String> = []
        var metadatas: [tableMetadata] = []
        let autoUploadFileName = getAccountAutoUploadFileName(account: session.account)

        func createMetadata(serverUrl: String, fileName: String, metadata: tableMetadata?) {
            let folder = utilityFileSystem.createServerUrl(serverUrl: serverUrl, fileName: fileName)
            guard !foldersCreated.contains(folder) else {
                return
            }
            foldersCreated.insert(folder)

            if let metadata {
                metadata.status = NCGlobal.shared.metadataStatusWaitCreateFolder
                metadata.sessionSelector = NCGlobal.shared.selectorUploadAutoUpload
                metadata.sessionDate = Date()
                metadatas.append(metadata.detachedCopy())
            } else {
                let metadata = NCManageDatabase.shared.createMetadataDirectory(fileName: fileName,
                                                                               ocId: NSUUID().uuidString,
                                                                               serverUrl: serverUrl,
                                                                               session: session)
                metadata.status = NCGlobal.shared.metadataStatusWaitCreateFolder
                metadata.sessionSelector = NCGlobal.shared.selectorUploadAutoUpload
                metadata.sessionDate = Date()
                metadatas.append(metadata)
            }
        }

        // Create Auto Upload Directory
        let serverUrlBase = utilityFileSystem.createServerUrl(serverUrl: autoUploadDirectory, fileName: autoUploadFileName)
        let fileNameBase = getAccountAutoUploadFileName(account: session.account)
        let metadata = metadatasFolder.first(where: { $0.serverUrl + "/" + $0.fileNameView == serverUrlBase })

        createMetadata(serverUrl: autoUploadDirectory, fileName: fileNameBase, metadata: metadata)

        // Create Auto Upload SubDirectory - Granularity
        if useSubFolder {
            let autoUploadServerUrlBase = self.getAccountAutoUploadServerUrlBase(session: session)
            let autoUploadSubfolderGranularity = self.getAccountAutoUploadSubfolderGranularity()
            let folders = Set(assets.map { self.utilityFileSystem.createGranularityPath(asset: $0) }).sorted()

            for folder in folders {
                let componentsDate = folder.split(separator: "/")
                let year = String(componentsDate[0])
                let serverUrlYear = utilityFileSystem.createServerUrl(serverUrl: autoUploadServerUrlBase, fileName: year)
                let metadata = metadatasFolder.first(where: { $0.serverUrl + "/" + $0.fileNameView == serverUrlYear })

                createMetadata(serverUrl: autoUploadServerUrlBase, fileName: year, metadata: metadata)

                if autoUploadSubfolderGranularity >= NCGlobal.shared.subfolderGranularityMonthly {
                    let month = String(componentsDate[1])
                    let serverUrlMonth = utilityFileSystem.createServerUrl(serverUrl: serverUrlYear, fileName: month)
                    let metadata = metadatasFolder.first(where: { $0.serverUrl + "/" + $0.fileNameView == serverUrlMonth })

                    createMetadata(serverUrl: serverUrlYear, fileName: month, metadata: metadata)

                    if autoUploadSubfolderGranularity == NCGlobal.shared.subfolderGranularityDaily {
                        let day = String(componentsDate[2])
                        let serverUrlDay = utilityFileSystem.createServerUrl(serverUrl: serverUrlMonth, fileName: day)
                        let metadata = metadatasFolder.first(where: { $0.serverUrl + "/" + $0.fileNameView == serverUrlDay })

                        createMetadata(serverUrl: serverUrlMonth, fileName: day, metadata: metadata)
                    }
                }
            }
        }

        return metadatas
    }

    func createMetadatasFolder(assets: [PHAsset],
                               useSubFolder: Bool,
                               session: NCSession.Session, completion: @escaping ([tableMetadata]) -> Void) {
        let autoUploadDirectory = getAccountAutoUploadDirectory(account: session.account, urlBase: session.urlBase, userId: session.userId)
        let predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND directory == true", session.account, autoUploadDirectory)
        let metadatasFolder = getMetadatas(predicate: predicate)
        let autoUploadServerUrlBase = self.getAccountAutoUploadServerUrlBase(session: session)
        let autoUploadSubfolderGranularity = self.getAccountAutoUploadSubfolderGranularity()
        let metadatas = self.createMetadatasFolder(assets: assets,
                                                   useSubFolder: useSubFolder,
                                                   metadatasFolder: metadatasFolder,
                                                   autoUploadDirectory: autoUploadDirectory,
                                                   autoUploadServerUrlBase: autoUploadServerUrlBase,
                                                   autoUploadSubfolderGranularity: autoUploadSubfolderGranularity,
                                                   session: session)
        completion(metadatas)
    }

    func createMetadatasFolderAsync(assets: [PHAsset],
                                    useSubFolder: Bool,
                                    session: NCSession.Session) async -> [tableMetadata] {
        let autoUploadDirectory = await getAccountAutoUploadDirectoryAsync(account: session.account, urlBase: session.urlBase, userId: session.userId)
        let predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND directory == true", session.account, autoUploadDirectory)
        let metadatasFolder = await getMetadatasAsync(predicate: predicate)
        let autoUploadServerUrlBase = await self.getAccountAutoUploadServerUrlBaseAsync(session: session)
        let autoUploadSubfolderGranularity = await self.getAccountAutoUploadSubfolderGranularityAsync()
        let metadatas = self.createMetadatasFolder(assets: assets,
                                                   useSubFolder: useSubFolder,
                                                   metadatasFolder: metadatasFolder,
                                                   autoUploadDirectory: autoUploadDirectory,
                                                   autoUploadServerUrlBase: autoUploadServerUrlBase,
                                                   autoUploadSubfolderGranularity: autoUploadSubfolderGranularity,
                                                   session: session)
        return metadatas
    }
}
