//
//  NCNetworking+WebDAV.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 07/02/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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

import UIKit
import JGProgressHUD
import NextcloudKit
import Alamofire

extension NCNetworking {
    
    // MARK: - Read file, folder

    func readFolder(serverUrl: String,
                    account: String,
                    forceReplaceMetadatas: Bool = false,
                    completion: @escaping (_ account: String, _ metadataFolder: tableMetadata?, _ metadatas: [tableMetadata]?, _ metadatasChangedCount: Int, _ metadatasChanged: Bool, _ error: NKError) -> Void) {

        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrl,
                                             depth: "1",
                                             showHiddenFiles: NCKeychain().showHiddenFiles,
                                             includeHiddenFiles: NCGlobal.shared.includeHiddenFiles,
                                             options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { account, files, _, error in

            guard error == .success else {
                return completion(account, nil, nil, 0, false, error)
            }

            NCManageDatabase.shared.convertFilesToMetadatas(files, useMetadataFolder: true) { metadataFolder, metadatasFolder, metadatas in

                // Add metadata folder
                NCManageDatabase.shared.addMetadata(tableMetadata.init(value: metadataFolder))

                // Update directory
                NCManageDatabase.shared.addDirectory(encrypted: metadataFolder.e2eEncrypted, favorite: metadataFolder.favorite, ocId: metadataFolder.ocId, fileId: metadataFolder.fileId, etag: metadataFolder.etag, permissions: metadataFolder.permissions, serverUrl: serverUrl, account: metadataFolder.account)
                NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, richWorkspace: metadataFolder.richWorkspace, account: metadataFolder.account)

                // Update sub directories NO Update richWorkspace
                for metadata in metadatasFolder {
                    let serverUrl = metadata.serverUrl + "/" + metadata.fileName
                    NCManageDatabase.shared.addDirectory(encrypted: metadata.e2eEncrypted, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, etag: nil, permissions: metadata.permissions, serverUrl: serverUrl, account: account)
                }

#if !EXTENSION
                // Convert Live Photo
                for metadata in metadatas {
                    if NCGlobal.shared.isLivePhotoServerAvailable, metadata.isLivePhoto {
                        NCNetworking.shared.convertLivePhoto(metadata: metadata)
                    }
                }
#endif

                let predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND status == %d", account, serverUrl, NCGlobal.shared.metadataStatusNormal)

                if forceReplaceMetadatas {
                    NCManageDatabase.shared.replaceMetadata(metadatas, predicate: predicate)
                    completion(account, metadataFolder, metadatas, 0, true, error)
                } else {
                    let results = NCManageDatabase.shared.updateMetadatas(metadatas, predicate: predicate)
                    completion(account, metadataFolder, metadatas, results.metadatasChangedCount, results.metadatasChanged, error)
                }
            }
        }
    }

    func readFile(serverUrlFileName: String,
                  showHiddenFiles: Bool = NCKeychain().showHiddenFiles,
                  queue: DispatchQueue = NextcloudKit.shared.nkCommonInstance.backgroundQueue,
                  completion: @escaping (_ account: String, _ metadata: tableMetadata?, _ error: NKError) -> Void) {

        let options = NKRequestOptions(queue: queue)

        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", showHiddenFiles: showHiddenFiles, options: options) { account, files, _, error in
            guard error == .success, files.count == 1, let file = files.first else {
                completion(account, nil, error)
                return
            }

            let isDirectoryE2EE = self.utilityFileSystem.isDirectoryE2EE(file: file)
            let metadata = NCManageDatabase.shared.convertFileToMetadata(file, isDirectoryE2EE: isDirectoryE2EE)

            completion(account, metadata, error)
        }
    }

    func fileExists(serverUrlFileName: String,
                    completion: @escaping (_ account: String, _ exists: Bool?, _ file: NKFile?, _ error: NKError) -> Void) {

        let requestBody =
        """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <d:propfind xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">
            <d:prop></d:prop>
        </d:propfind>
        """

        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName,
                                             depth: "0",
                                             requestBody: requestBody.data(using: .utf8),
                                             options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { account, files, _, error in

            if error == .success, let file = files.first {
                completion(account, true, file, error)
            } else if error.errorCode == NCGlobal.shared.errorResourceNotFound {
                completion(account, false, nil, error)
            } else {
                completion(account, nil, nil, error)
            }
        }
    }

    // MARK: - Create Folder

    func createFolder(fileName: String,
                      serverUrl: String,
                      account: String,
                      urlBase: String,
                      userId: String,
                      overwrite: Bool = false,
                      withPush: Bool,
                      completion: @escaping (_ error: NKError) -> Void) {

        let isDirectoryEncrypted = utilityFileSystem.isDirectoryE2EE(account: account, urlBase: urlBase, userId: userId, serverUrl: serverUrl)
        let fileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)

        if isDirectoryEncrypted {
#if !EXTENSION
            Task {
                let error = await NCNetworkingE2EECreateFolder().createFolder(fileName: fileName, serverUrl: serverUrl, account: account, urlBase: urlBase, userId: userId, withPush: withPush)
                completion(error)
            }
#endif
        } else {
            createFolderPlain(fileName: fileName, serverUrl: serverUrl, account: account, urlBase: urlBase, overwrite: overwrite, withPush: withPush, completion: completion)
        }
    }

    private func createFolderPlain(fileName: String,
                                   serverUrl: String,
                                   account: String,
                                   urlBase: String,
                                   overwrite: Bool,
                                   withPush: Bool,
                                   completion: @escaping (_ error: NKError) -> Void) {

        var fileNameFolder = utility.removeForbiddenCharacters(fileName)
        if fileName != fileNameFolder {
            let errorDescription = String(format: NSLocalizedString("_forbidden_characters_", comment: ""), NCGlobal.shared.forbiddenCharacters.joined(separator: " "))
            let error = NKError(errorCode: NCGlobal.shared.errorConflict, errorDescription: errorDescription)
            return completion(error)
        }

        if !overwrite {
            fileNameFolder = utilityFileSystem.createFileName(fileNameFolder, serverUrl: serverUrl, account: account)
        }
        if fileNameFolder.isEmpty {
            return completion(NKError())
        }
        let fileNameFolderUrl = serverUrl + "/" + fileNameFolder

        NextcloudKit.shared.createFolder(serverUrlFileName: fileNameFolderUrl) { account, _, _, error in
            guard error == .success else {
                if error.errorCode == NCGlobal.shared.errorMethodNotSupported && overwrite {
                    completion(NKError())
                } else {
                    completion(error)
                }
                return
            }

            self.readFile(serverUrlFileName: fileNameFolderUrl) { account, metadataFolder, error in

                if error == .success {
                    if let metadata = metadataFolder {
                        NCManageDatabase.shared.addMetadata(metadata)
                        NCManageDatabase.shared.addDirectory(encrypted: metadata.e2eEncrypted, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, etag: nil, permissions: metadata.permissions, serverUrl: fileNameFolderUrl, account: account)
                    }
                    if let metadata = NCManageDatabase.shared.getMetadataFromOcId(metadataFolder?.ocId) {
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterCreateFolder, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "withPush": withPush])
                    }
                }
                completion(error)
            }
        }
    }

    func createFolder(assets: [PHAsset],
                      selector: String,
                      useSubFolder: Bool,
                      account: String,
                      urlBase: String,
                      userId: String,
                      withPush: Bool) -> Bool {

        let autoUploadPath = NCManageDatabase.shared.getAccountAutoUploadPath(urlBase: urlBase, userId: userId, account: account)
        let serverUrlBase = NCManageDatabase.shared.getAccountAutoUploadDirectory(urlBase: urlBase, userId: userId, account: account)
        let fileNameBase = NCManageDatabase.shared.getAccountAutoUploadFileName()
        let autoUploadSubfolderGranularity = NCManageDatabase.shared.getAccountAutoUploadSubfolderGranularity()

        func createFolder(fileName: String, serverUrl: String) -> Bool {
            var result: Bool = false
            let semaphore = DispatchSemaphore(value: 0)
            NCNetworking.shared.createFolder(fileName: fileName, serverUrl: serverUrl, account: account, urlBase: urlBase, userId: userId, overwrite: true, withPush: withPush) { error in
                if error == .success { result = true }
                semaphore.signal()
            }
            semaphore.wait()
            return result
        }

        func createNameSubFolder() -> [String] {

            var datesSubFolder: [String] = []
            let dateFormatter = DateFormatter()

            for asset in assets {
                let date = asset.creationDate ?? Date()
                dateFormatter.dateFormat = "yyyy"
                let year = dateFormatter.string(from: date)
                dateFormatter.dateFormat = "MM"
                let month = dateFormatter.string(from: date)
                dateFormatter.dateFormat = "dd"
                let day = dateFormatter.string(from: date)
                if autoUploadSubfolderGranularity == NCGlobal.shared.subfolderGranularityYearly {
                    datesSubFolder.append("\(year)")
                } else if autoUploadSubfolderGranularity == NCGlobal.shared.subfolderGranularityDaily {
                    datesSubFolder.append("\(year)/\(month)/\(day)")
                } else {  // Month Granularity is default
                    datesSubFolder.append("\(year)/\(month)")
                }
            }

            return Array(Set(datesSubFolder))
        }

        var result = createFolder(fileName: fileNameBase, serverUrl: serverUrlBase)

        if useSubFolder && result {
            for dateSubFolder in createNameSubFolder() {
                let subfolderArray = dateSubFolder.split(separator: "/")
                let year = subfolderArray[0]
                let serverUrlYear = autoUploadPath
                result = createFolder(fileName: String(year), serverUrl: serverUrlYear)  // Year always present independently of preference value
                if result && autoUploadSubfolderGranularity >= NCGlobal.shared.subfolderGranularityMonthly {
                    let month = subfolderArray[1]
                    let serverUrlMonth = autoUploadPath + "/" + year
                    result = createFolder(fileName: String(month), serverUrl: serverUrlMonth)
                    if result && autoUploadSubfolderGranularity == NCGlobal.shared.subfolderGranularityDaily {
                        let day = subfolderArray[2]
                        let serverUrlDay = autoUploadPath + "/" + year + "/" + month
                        result = createFolder(fileName: String(day), serverUrl: serverUrlDay)
                    }
                }
                if !result { break }
            }
        }

        return result
    }

    // MARK: - Delete

    func deleteMetadata(_ metadata: tableMetadata, onlyLocalCache: Bool) async -> (NKError) {

        if onlyLocalCache {

#if !EXTENSION
            NCActivityIndicator.shared.start()
#endif

            func delete(metadata: tableMetadata) {
                if let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
                    NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "account == %@ AND ocId == %@", metadataLive.account, metadataLive.ocId))
                    utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadataLive.ocId))
                }
                NCManageDatabase.shared.deleteVideo(metadata: metadata)
                NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "account == %@ AND ocId == %@", metadata.account, metadata.ocId))
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
            }

            if metadata.directory {
                let serverUrl = metadata.serverUrl + "/" + metadata.fileName
                if let metadatas = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND directory == false", metadata.account, serverUrl)) {
                    for metadata in metadatas {
                        delete(metadata: metadata)
                    }
                }
            } else {
                delete(metadata: metadata)
            }

#if !EXTENSION
            NCActivityIndicator.shared.stop()
#endif
            return NKError()
        }

        if metadata.isDirectoryE2EE {
#if !EXTENSION
            if let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
                let error = await NCNetworkingE2EEDelete().delete(metadata: metadataLive)
                if error == .success {
                    return await NCNetworkingE2EEDelete().delete(metadata: metadata)
                } else {
                    return error
                }
            } else {
                return await NCNetworkingE2EEDelete().delete(metadata: metadata)
            }
#else
            return NKError()
#endif
        } else {
            if let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata), metadata.isNotFlaggedAsLivePhotoByServer {
                let error = await deleteMetadataPlain(metadataLive)
                if error == .success {
                    return await deleteMetadataPlain(metadata)
                } else {
                    return error
                }
            } else {
                return await deleteMetadataPlain(metadata)
            }
        }
    }

    func deleteMetadataPlain(_ metadata: tableMetadata, customHeader: [String: String]? = nil) async -> NKError {

        // verify permission
        let permission = utility.permissionsContainsString(metadata.permissions, permissions: NCGlobal.shared.permissionCanDelete)
        if !metadata.permissions.isEmpty && permission == false {
            return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_delete_file_")
        }
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let options = NKRequestOptions(customHeader: customHeader)

        let result = await NextcloudKit.shared.deleteFileOrFolder(serverUrlFileName: serverUrlFileName, options: options)
        if result.error == .success || result.error.errorCode == NCGlobal.shared.errorResourceNotFound {

            do {
                try FileManager.default.removeItem(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
            } catch { }

            NCManageDatabase.shared.deleteVideo(metadata: metadata)
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            // LIVE PHOTO SERVER
            if let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata), metadataLive.isFlaggedAsLivePhotoByServer {
                do {
                    try FileManager.default.removeItem(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadataLive.ocId))
                } catch { }

                NCManageDatabase.shared.deleteVideo(metadata: metadataLive)
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadataLive.ocId))
                NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadataLive.ocId))
            }

            if metadata.directory {
                NCManageDatabase.shared.deleteDirectoryAndSubDirectory(serverUrl: utilityFileSystem.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName), account: metadata.account)
            }
        }
        return result.error
    }

    // MARK: - Rename

    func renameMetadata(_ metadata: tableMetadata,
                        fileNameNew: String,
                        indexPath: IndexPath,
                        viewController: UIViewController?,
                        completion: @escaping (_ error: NKError) -> Void) {

        let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata)
        let fileNameNew = fileNameNew.trimmingCharacters(in: .whitespacesAndNewlines)
        let fileNameNewLive = (fileNameNew as NSString).deletingPathExtension + ".mov"

        if metadata.isDirectoryE2EE {
#if !EXTENSION
            Task {
                if let metadataLive = metadataLive {
                    let error = await NCNetworkingE2EERename().rename(metadata: metadataLive, fileNameNew: fileNameNew, indexPath: indexPath)
                    if error == .success {
                        let error = await NCNetworkingE2EERename().rename(metadata: metadata, fileNameNew: fileNameNew, indexPath: indexPath)
                        DispatchQueue.main.async { completion(error) }
                    } else {
                        DispatchQueue.main.async { completion(error) }
                    }
                } else {
                    let error = await NCNetworkingE2EERename().rename(metadata: metadata, fileNameNew: fileNameNew, indexPath: indexPath)
                    DispatchQueue.main.async { completion(error) }
                }
            }
#endif
        } else {
            if let metadataLive, metadata.isNotFlaggedAsLivePhotoByServer {
                renameMetadataPlain(metadataLive, fileNameNew: fileNameNewLive, indexPath: indexPath) { error in
                    if error == .success {
                        self.renameMetadataPlain(metadata, fileNameNew: fileNameNew, indexPath: indexPath, completion: completion)
                    } else {
                        completion(error)
                    }
                }
            } else {
                renameMetadataPlain(metadata, fileNameNew: fileNameNew, indexPath: indexPath, completion: completion)
            }
        }
    }

    private func renameMetadataPlain(_ metadata: tableMetadata,
                                     fileNameNew: String,
                                     indexPath: IndexPath,
                                     completion: @escaping (_ error: NKError) -> Void) {

        let permission = utility.permissionsContainsString(metadata.permissions, permissions: NCGlobal.shared.permissionCanRename)
        if !metadata.permissions.isEmpty && !permission {
            return completion(NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_modify_file_"))
        }
        let fileName = utility.removeForbiddenCharacters(fileNameNew)
        if fileName != fileNameNew {
            let errorDescription = String(format: NSLocalizedString("_forbidden_characters_", comment: ""), NCGlobal.shared.forbiddenCharacters.joined(separator: " "))
            let error = NKError(errorCode: NCGlobal.shared.errorConflict, errorDescription: errorDescription)
            return completion(error)
        }
        let fileNameNew = fileName
        if fileNameNew.isEmpty || fileNameNew == metadata.fileNameView {
            return completion(NKError())
        }
        let fileNamePath = metadata.serverUrl + "/" + metadata.fileName
        let fileNameToPath = metadata.serverUrl + "/" + fileNameNew

        NextcloudKit.shared.moveFileOrFolder(serverUrlFileNameSource: fileNamePath, serverUrlFileNameDestination: fileNameToPath, overwrite: false) { _, error in
            if error == .success {
                if metadata.directory {
                    let serverUrl = self.utilityFileSystem.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)
                    let serverUrlTo = self.utilityFileSystem.stringAppendServerUrl(metadata.serverUrl, addFileName: fileNameNew)
                    if let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
                        NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, serverUrlTo: serverUrlTo, etag: "", ocId: nil, fileId: nil, encrypted: directory.e2eEncrypted, richWorkspace: nil, account: metadata.account)
                    }
                } else {
                    do {
                        try FileManager.default.removeItem(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
                    } catch { }
                    NCManageDatabase.shared.deleteVideo(metadata: metadata)
                    NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                    NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                    // LIVE PHOTO SERVER
                    if let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata), metadataLive.isFlaggedAsLivePhotoByServer {
                        do {
                            try FileManager.default.removeItem(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadataLive.ocId))
                        } catch { }
                        NCManageDatabase.shared.deleteVideo(metadata: metadataLive)
                        NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadataLive.ocId))
                        NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadataLive.ocId))
                    }
                }
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterRenameFile, userInfo: ["ocId": metadata.ocId, "account": metadata.account, "indexPath": indexPath])
            }
            completion(error)
        }
    }

    // MARK: - Move

    func moveMetadata(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool) async -> NKError {

        if let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata), metadata.isNotFlaggedAsLivePhotoByServer {
            let error = await moveMetadataPlain(metadataLive, serverUrlTo: serverUrlTo, overwrite: overwrite)
            if error == .success {
                return await moveMetadataPlain(metadata, serverUrlTo: serverUrlTo, overwrite: overwrite)
            } else {
                return error
            }
        }
        return await moveMetadataPlain(metadata, serverUrlTo: serverUrlTo, overwrite: overwrite)
    }

    private func moveMetadataPlain(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool) async -> NKError {

        let permission = utility.permissionsContainsString(metadata.permissions, permissions: NCGlobal.shared.permissionCanRename)
        if !metadata.permissions.isEmpty && !permission {
            return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_modify_file_")
        }
        let serverUrlFileNameSource = metadata.serverUrl + "/" + metadata.fileName
        let serverUrlFileNameDestination = serverUrlTo + "/" + metadata.fileName

        let result = await NextcloudKit.shared.moveFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite)
        if result.error == .success {
            if metadata.directory {
                NCManageDatabase.shared.deleteDirectoryAndSubDirectory(serverUrl: utilityFileSystem.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName), account: result.account)
            } else {
                do {
                    try FileManager.default.removeItem(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
                } catch { }
                NCManageDatabase.shared.deleteVideo(metadata: metadata)
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                // LIVE PHOTO SERVER
                if let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata), metadataLive.isFlaggedAsLivePhotoByServer {
                    do {
                        try FileManager.default.removeItem(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadataLive.ocId))
                    } catch { }
                    NCManageDatabase.shared.deleteVideo(metadata: metadataLive)
                    NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadataLive.ocId))
                    NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadataLive.ocId))
                }
            }
        }
        return result.error
    }

    // MARK: - Copy

    func copyMetadata(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool) async -> NKError {

        if let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata), metadata.isNotFlaggedAsLivePhotoByServer {
            let error = await copyMetadataPlain(metadataLive, serverUrlTo: serverUrlTo, overwrite: overwrite)
            if error == .success {
                return await copyMetadataPlain(metadata, serverUrlTo: serverUrlTo, overwrite: overwrite)
            } else {
                return error
            }
        }
        return await copyMetadataPlain(metadata, serverUrlTo: serverUrlTo, overwrite: overwrite)
    }

    private func copyMetadataPlain(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool) async -> NKError {

        let permission = utility.permissionsContainsString(metadata.permissions, permissions: NCGlobal.shared.permissionCanRename)
        if !metadata.permissions.isEmpty && !permission {
            return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_modify_file_")
        }
        let serverUrlFileNameSource = metadata.serverUrl + "/" + metadata.fileName
        let serverUrlFileNameDestination = serverUrlTo + "/" + metadata.fileName

        let result = await NextcloudKit.shared.copyFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite)
        return result.error
    }

    // MARK: - Favorite

    func favoriteMetadata(_ metadata: tableMetadata,
                          completion: @escaping (_ error: NKError) -> Void) {

        if let metadataLive = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
            favoriteMetadataPlain(metadataLive) { error in
                if error == .success {
                    self.favoriteMetadataPlain(metadata, completion: completion)
                } else {
                    completion(error)
                }
            }
        } else {
            favoriteMetadataPlain(metadata, completion: completion)
        }
    }

    private func favoriteMetadataPlain(_ metadata: tableMetadata,
                                       completion: @escaping (_ error: NKError) -> Void) {

        let fileName = utilityFileSystem.getFileNamePath(metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId)
        let favorite = !metadata.favorite
        let ocId = metadata.ocId

        NextcloudKit.shared.setFavorite(fileName: fileName, favorite: favorite) { account, error in
            if error == .success && metadata.account == account {
                NCManageDatabase.shared.setMetadataFavorite(ocId: metadata.ocId, favorite: favorite)
                if favorite, metadata.directory {
                    let serverUrl = metadata.serverUrl + "/" + metadata.fileName
                    self.synchronization(account: metadata.account, serverUrl: serverUrl, selector: NCGlobal.shared.selectorSynchronizationFavorite)
                }
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterFavoriteFile, userInfo: ["ocId": ocId, "serverUrl": metadata.serverUrl])
            }
            completion(error)
        }
    }

    // MARK: - Search

    /// WebDAV search
    func searchFiles(urlBase: NCUserBaseUrl,
                     literal: String,
                     completion: @escaping (_ metadatas: [tableMetadata]?, _ error: NKError) -> Void) {

        NextcloudKit.shared.searchLiteral(serverUrl: urlBase.urlBase,
                                          depth: "infinity",
                                          literal: literal,
                                          showHiddenFiles: NCKeychain().showHiddenFiles,
                                          options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { account, files, _, error in

            guard error == .success else {
                return completion(nil, error)
            }

            NCManageDatabase.shared.convertFilesToMetadatas(files, useMetadataFolder: false) { _, metadatasFolder, metadatas in

                // Update sub directories
                for folder in metadatasFolder {
                    let serverUrl = folder.serverUrl + "/" + folder.fileName
                    NCManageDatabase.shared.addDirectory(encrypted: folder.e2eEncrypted, favorite: folder.favorite, ocId: folder.ocId, fileId: folder.fileId, etag: nil, permissions: folder.permissions, serverUrl: serverUrl, account: account)
                }

                NCManageDatabase.shared.addMetadatas(metadatas)
                let metadatas = Array(metadatas.map(tableMetadata.init))
                completion(metadatas, error)
            }
        }
    }

    /// Unified Search (NC>=20)
    ///
    func unifiedSearchFiles(userBaseUrl: NCUserBaseUrl,
                            literal: String,
                            providers: @escaping (_ accout: String, _ searchProviders: [NKSearchProvider]?) -> Void,
                            update: @escaping (_ account: String, _ id: String, NKSearchResult?, [tableMetadata]?) -> Void,
                            completion: @escaping (_ account: String, _ error: NKError) -> Void) {

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        dispatchGroup.notify(queue: .main) {
            completion(userBaseUrl.account, NKError())
        }

        NextcloudKit.shared.unifiedSearch(term: literal, timeout: 30, timeoutProvider: 90) { _ in
            // example filter
            // ["calendar", "files", "fulltextsearch"].contains(provider.id)
            return true
        } request: { request in
            if let request = request {
                self.requestsUnifiedSearch.append(request)
            }
        } providers: { account, searchProviders in
            providers(account, searchProviders)
        } update: { account, partialResult, provider, _ in
            guard let partialResult = partialResult else { return }
            var metadatas: [tableMetadata] = []

            switch provider.id {
            case "files":
                partialResult.entries.forEach({ entry in
                    if let fileId = entry.fileId,
                       let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ && fileId == %@", userBaseUrl.userAccount, String(fileId))) {
                        metadatas.append(metadata)
                    } else if let filePath = entry.filePath {
                        let semaphore = DispatchSemaphore(value: 0)
                        self.loadMetadata(userBaseUrl: userBaseUrl, filePath: filePath, dispatchGroup: dispatchGroup) { _, metadata, _ in
                            metadatas.append(metadata)
                            semaphore.signal()
                        }
                        semaphore.wait()
                    } else { print(#function, "[ERROR]: File search entry has no path: \(entry)") }
                })
            case "fulltextsearch":
                // NOTE: FTS could also return attributes like files
                // https://github.com/nextcloud/files_fulltextsearch/issues/143
                partialResult.entries.forEach({ entry in
                    let url = URLComponents(string: entry.resourceURL)
                    guard let dir = url?.queryItems?["dir"]?.value, let filename = url?.queryItems?["scrollto"]?.value else { return }
                    if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(
                              format: "account == %@ && path == %@ && fileName == %@",
                              userBaseUrl.userAccount,
                              "/remote.php/dav/files/" + userBaseUrl.user + dir,
                              filename)) {
                        metadatas.append(metadata)
                    } else {
                        let semaphore = DispatchSemaphore(value: 0)
                        self.loadMetadata(userBaseUrl: userBaseUrl, filePath: dir + filename, dispatchGroup: dispatchGroup) { _, metadata, _ in
                            metadatas.append(metadata)
                            semaphore.signal()
                        }
                        semaphore.wait()
                    }
                })
            default:
                partialResult.entries.forEach({ entry in
                    let metadata = NCManageDatabase.shared.createMetadata(account: userBaseUrl.account, user: userBaseUrl.user, userId: userBaseUrl.userId, fileName: entry.title, fileNameView: entry.title, ocId: NSUUID().uuidString, serverUrl: userBaseUrl.urlBase, urlBase: userBaseUrl.urlBase, url: entry.resourceURL, contentType: "", isUrl: true, name: partialResult.id, subline: entry.subline, iconName: entry.icon, iconUrl: entry.thumbnailURL)
                    metadatas.append(metadata)
                })
            }
            update(account, provider.id, partialResult, metadatas)
        } completion: { _, _, _ in
            self.requestsUnifiedSearch.removeAll()
            dispatchGroup.leave()
        }
    }

    func unifiedSearchFilesProvider(userBaseUrl: NCUserBaseUrl,
                                    id: String, term: String,
                                    limit: Int, cursor: Int,
                                    completion: @escaping (_ account: String, _ searchResult: NKSearchResult?, _ metadatas: [tableMetadata]?, _ error: NKError) -> Void) {

        var metadatas: [tableMetadata] = []

        let request = NextcloudKit.shared.searchProvider(id, account: userBaseUrl.account, term: term, limit: limit, cursor: cursor, timeout: 60) { account, searchResult, _, error in
            guard let searchResult = searchResult else {
                completion(account, nil, metadatas, error)
                return
            }

            switch id {
            case "files":
                searchResult.entries.forEach({ entry in
                    if let fileId = entry.fileId, let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ && fileId == %@", userBaseUrl.userAccount, String(fileId))) {
                        metadatas.append(metadata)
                    } else if let filePath = entry.filePath {
                        let semaphore = DispatchSemaphore(value: 0)
                        self.loadMetadata(userBaseUrl: userBaseUrl, filePath: filePath, dispatchGroup: nil) { _, metadata, _ in
                            metadatas.append(metadata)
                            semaphore.signal()
                        }
                        semaphore.wait()
                    } else { print(#function, "[ERROR]: File search entry has no path: \(entry)") }
                })
            case "fulltextsearch":
                // NOTE: FTS could also return attributes like files
                // https://github.com/nextcloud/files_fulltextsearch/issues/143
                searchResult.entries.forEach({ entry in
                    let url = URLComponents(string: entry.resourceURL)
                    guard let dir = url?.queryItems?["dir"]?.value, let filename = url?.queryItems?["scrollto"]?.value else { return }
                    if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ && path == %@ && fileName == %@", userBaseUrl.userAccount, "/remote.php/dav/files/" + userBaseUrl.user + dir, filename)) {
                        metadatas.append(metadata)
                    } else {
                        let semaphore = DispatchSemaphore(value: 0)
                        self.loadMetadata(userBaseUrl: userBaseUrl, filePath: dir + filename, dispatchGroup: nil) { _, metadata, _ in
                            metadatas.append(metadata)
                            semaphore.signal()
                        }
                        semaphore.wait()
                    }
                })
            default:
                searchResult.entries.forEach({ entry in
                    let newMetadata = NCManageDatabase.shared.createMetadata(account: userBaseUrl.account, user: userBaseUrl.user, userId: userBaseUrl.userId, fileName: entry.title, fileNameView: entry.title, ocId: NSUUID().uuidString, serverUrl: userBaseUrl.urlBase, urlBase: userBaseUrl.urlBase, url: entry.resourceURL, contentType: "", isUrl: true, name: searchResult.name.lowercased(), subline: entry.subline, iconName: entry.icon, iconUrl: entry.thumbnailURL)
                    metadatas.append(newMetadata)
                })
            }

            completion(account, searchResult, metadatas, error)
        }
        if let request = request {
            requestsUnifiedSearch.append(request)
        }
    }

    func cancelUnifiedSearchFiles() {
        for request in requestsUnifiedSearch {
            request.cancel()
        }
        requestsUnifiedSearch.removeAll()
    }

    private func loadMetadata(userBaseUrl: NCUserBaseUrl,
                              filePath: String,
                              dispatchGroup: DispatchGroup? = nil,
                              completion: @escaping (String, tableMetadata, NKError) -> Void) {

        let urlPath = userBaseUrl.urlBase + "/remote.php/dav/files/" + userBaseUrl.user + filePath
        dispatchGroup?.enter()
        self.readFile(serverUrlFileName: urlPath) { account, metadata, error in
            defer { dispatchGroup?.leave() }
            guard let metadata = metadata else { return }
            let returnMetadata = tableMetadata.init(value: metadata)
            NCManageDatabase.shared.addMetadata(metadata)
            completion(account, returnMetadata, error)
        }
    }

}
