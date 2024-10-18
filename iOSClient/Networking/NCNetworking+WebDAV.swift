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
import Queuer
import Photos

extension NCNetworking {

    // MARK: - Read file, folder

    func readFolder(serverUrl: String,
                    account: String,
                    forceReplaceMetadatas: Bool = false,
                    taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                    completion: @escaping (_ account: String, _ metadataFolder: tableMetadata?, _ metadatas: [tableMetadata]?, _ metadatasDifferentCount: Int, _ metadatasModified: Int, _ error: NKError) -> Void) {
        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrl,
                                             depth: "1",
                                             showHiddenFiles: NCKeychain().showHiddenFiles,
                                             includeHiddenFiles: NCGlobal.shared.includeHiddenFiles,
                                             account: account,
                                             options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { task in
            taskHandler(task)
        } completion: { account, files, _, error in
            guard error == .success else {
                return completion(account, nil, nil, 0, 0, error)
            }

            NCManageDatabase.shared.convertFilesToMetadatas(files, useFirstAsMetadataFolder: true) { metadataFolder, metadatas in
                NCManageDatabase.shared.addMetadata(metadataFolder)
                NCManageDatabase.shared.addDirectory(e2eEncrypted: metadataFolder.e2eEncrypted, favorite: metadataFolder.favorite, ocId: metadataFolder.ocId, fileId: metadataFolder.fileId, etag: metadataFolder.etag, permissions: metadataFolder.permissions, richWorkspace: metadataFolder.richWorkspace, serverUrl: serverUrl, account: metadataFolder.account)
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
                    completion(account, metadataFolder, metadatas, 1, 1, error)
                } else {
                    let results = NCManageDatabase.shared.updateMetadatas(metadatas, predicate: predicate)
                    completion(account, metadataFolder, metadatas, results.metadatasDifferentCount, results.metadatasModified, error)
                }
            }
        }
    }

    func readFile(serverUrlFileName: String,
                  showHiddenFiles: Bool = NCKeychain().showHiddenFiles,
                  account: String,
                  queue: DispatchQueue = NextcloudKit.shared.nkCommonInstance.backgroundQueue,
                  taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                  completion: @escaping (_ account: String, _ metadata: tableMetadata?, _ error: NKError) -> Void) {
        let options = NKRequestOptions(queue: queue)

        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", showHiddenFiles: showHiddenFiles, account: account, options: options) { task in
            taskHandler(task)
        } completion: { account, files, _, error in
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
                    account: String,
                    completion: @escaping (_ account: String, _ exists: Bool?, _ file: NKFile?, _ error: NKError) -> Void) {
        let options = NKRequestOptions(timeout: 10, createProperties: [], queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName,
                                             depth: "0",
                                             account: account,
                                             options: options) { account, files, _, error in
            if error == .success, let file = files.first {
                completion(account, true, file, error)
            } else if error.errorCode == NCGlobal.shared.errorResourceNotFound {
                completion(account, false, nil, error)
            } else {
                completion(account, nil, nil, error)
            }
        }
    }

    func fileExists(serverUrlFileName: String, account: String) async -> (account: String, exists: Bool?, file: NKFile?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            fileExists(serverUrlFileName: serverUrlFileName, account: account) { account, exists, file, error in
                continuation.resume(returning: (account, exists, file, error))
            }
        })
    }

    func createFileName(fileNameBase: String, account: String, serverUrl: String) async -> String {
        var exitLoop = false
        var resultFileName = fileNameBase

        func newFileName() {
            var name = NSString(string: resultFileName).deletingPathExtension
            let ext = NSString(string: resultFileName).pathExtension
            let characters = Array(name)
            if characters.count < 2 {
                if ext.isEmpty {
                    resultFileName = name + " 1"
                } else {
                    resultFileName = name + " 1" + "." + ext
                }
            } else {
                let space = characters[characters.count - 2]
                let numChar = characters[characters.count - 1]
                var num = Int(String(numChar))
                if space == " " && num != nil {
                    name = String(name.dropLast())
                    num = num! + 1
                    if ext.isEmpty {
                        resultFileName = name + "\(num!)"
                    } else {
                        resultFileName = name + "\(num!)" + "." + ext
                    }
                } else {
                    if ext.isEmpty {
                        resultFileName = name + " 1"
                    } else {
                        resultFileName = name + " 1" + "." + ext
                    }
                }
            }
        }

        while !exitLoop {
            if NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "fileNameView == %@ AND serverUrl == %@ AND account == %@", resultFileName, serverUrl, account)) != nil {
                newFileName()
                continue
            }
            let results = await fileExists(serverUrlFileName: serverUrl + "/" + resultFileName, account: account)
            if let exists = results.exists, exists {
                newFileName()
            } else {
                exitLoop = true
            }
        }
        return resultFileName
    }

    // MARK: - Create Folder

    func createFolder(fileName: String,
                      serverUrl: String,
                      account: String,
                      urlBase: String,
                      userId: String,
                      overwrite: Bool = false,
                      withPush: Bool,
                      sceneIdentifier: String?,
                      completion: @escaping (_ error: NKError) -> Void) {
        let isDirectoryEncrypted = utilityFileSystem.isDirectoryE2EE(account: account, urlBase: urlBase, userId: userId, serverUrl: serverUrl)
        let fileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)

        if isDirectoryEncrypted {
#if !EXTENSION
            Task {
                let error = await NCNetworkingE2EECreateFolder().createFolder(fileName: fileName, serverUrl: serverUrl, account: account, urlBase: urlBase, userId: userId, withPush: withPush, sceneIdentifier: sceneIdentifier)
                completion(error)
            }
#endif
        } else {
            createFolderPlain(fileName: fileName, serverUrl: serverUrl, account: account, urlBase: urlBase, overwrite: overwrite, withPush: withPush, sceneIdentifier: sceneIdentifier, completion: completion)
        }
    }

    private func createFolderPlain(fileName: String,
                                   serverUrl: String,
                                   account: String,
                                   urlBase: String,
                                   overwrite: Bool,
                                   withPush: Bool,
                                   sceneIdentifier: String?,
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

        NextcloudKit.shared.createFolder(serverUrlFileName: fileNameFolderUrl, account: account) { account, _, _, error in
            guard error == .success else {
                if error.errorCode == NCGlobal.shared.errorMethodNotSupported && overwrite {
                    completion(NKError())
                } else {
                    completion(error)
                }
                return
            }

            self.readFile(serverUrlFileName: fileNameFolderUrl, account: account) { account, metadataFolder, error in
                if error == .success {
                    if let metadata = metadataFolder {
                        NCManageDatabase.shared.addMetadata(metadata)
                        NCManageDatabase.shared.addDirectory(e2eEncrypted: metadata.e2eEncrypted, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, permissions: metadata.permissions, serverUrl: fileNameFolderUrl, account: account)
                    }
                    if let metadata = NCManageDatabase.shared.getMetadataFromOcId(metadataFolder?.ocId) {
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterCreateFolder, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "withPush": withPush, "sceneIdentifier": sceneIdentifier as Any])
                    }
                }
                completion(error)
            }
        }
    }

    func createFolder(assets: [PHAsset]?,
                      useSubFolder: Bool,
                      account: String,
                      urlBase: String,
                      userId: String,
                      withPush: Bool,
                      sceneIdentifier: String? = nil) -> Bool {
        let autoUploadPath = NCManageDatabase.shared.getAccountAutoUploadPath(urlBase: urlBase, userId: userId, account: account)
        let serverUrlBase = NCManageDatabase.shared.getAccountAutoUploadDirectory(urlBase: urlBase, userId: userId, account: account)
        let fileNameBase = NCManageDatabase.shared.getAccountAutoUploadFileName()
        let autoUploadSubfolderGranularity = NCManageDatabase.shared.getAccountAutoUploadSubfolderGranularity()

        func createFolder(fileName: String, serverUrl: String) -> Bool {
            var result: Bool = false
            let semaphore = DispatchSemaphore(value: 0)
            NCNetworking.shared.createFolder(fileName: fileName, serverUrl: serverUrl, account: account, urlBase: urlBase, userId: userId, overwrite: true, withPush: withPush, sceneIdentifier: sceneIdentifier) { error in
                if error == .success { result = true }
                semaphore.signal()
            }
            semaphore.wait()
            return result
        }

        func createNameSubFolder() -> [String] {
            var datesSubFolder: [String] = []
            if let assets {
                for asset in assets {
                    datesSubFolder.append(utilityFileSystem.createGranularityPath(asset: asset))
                }
            } else {
                datesSubFolder.append(utilityFileSystem.createGranularityPath())
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
        let permission = utility.permissionsContainsString(metadata.permissions, permissions: NCPermissions().permissionCanDelete)
        if !metadata.permissions.isEmpty && permission == false {
            return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_delete_file_")
        }
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let options = NKRequestOptions(customHeader: customHeader)
        let result = await NCNetworking.shared.deleteFileOrFolder(serverUrlFileName: serverUrlFileName, account: metadata.account ,options: options)

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
        let permission = utility.permissionsContainsString(metadata.permissions, permissions: NCPermissions().permissionCanRename)
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

        NextcloudKit.shared.moveFileOrFolder(serverUrlFileNameSource: fileNamePath, serverUrlFileNameDestination: fileNameToPath, overwrite: false, account: metadata.account) { _, error in
            if error == .success {
                NCManageDatabase.shared.renameMetadata(fileNameTo: fileNameNew, ocId: metadata.ocId)
                if metadata.directory {
                    let serverUrl = self.utilityFileSystem.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)
                    let serverUrlTo = self.utilityFileSystem.stringAppendServerUrl(metadata.serverUrl, addFileName: fileNameNew)
                    if let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
                        NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, serverUrlTo: serverUrlTo, etag: "", encrypted: directory.e2eEncrypted, account: metadata.account)
                    }
                } else {
                    if (metadata.fileName as NSString).pathExtension != (fileNameNew as NSString).pathExtension {
                        let path = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId)
                        self.utilityFileSystem.removeFile(atPath: path)
                    } else {
                        NCManageDatabase.shared.setLocalFile(ocId: metadata.ocId, fileName: fileNameNew)
                        let atPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + metadata.fileName
                        let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + fileNameNew
                        self.utilityFileSystem.moveFile(atPath: atPath, toPath: toPath)
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
        let permission = utility.permissionsContainsString(metadata.permissions, permissions: NCPermissions().permissionCanRename)
        if !metadata.permissions.isEmpty && !permission {
            return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_modify_file_")
        }
        let serverUrlFileNameSource = metadata.serverUrl + "/" + metadata.fileName
        let serverUrlFileNameDestination = serverUrlTo + "/" + metadata.fileName

        let result = await NCNetworking.shared.moveFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite, account: metadata.account)
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
        let permission = utility.permissionsContainsString(metadata.permissions, permissions: NCPermissions().permissionCanRename)
        if !metadata.permissions.isEmpty && !permission {
            return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_modify_file_")
        }
        let serverUrlFileNameSource = metadata.serverUrl + "/" + metadata.fileName
        let serverUrlFileNameDestination = serverUrlTo + "/" + metadata.fileName

        let result = await NCNetworking.shared.copyFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite, account: metadata.account)
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

        NextcloudKit.shared.setFavorite(fileName: fileName, favorite: favorite, account: metadata.account) { account, error in
            if error == .success && metadata.account == account {
                metadata.favorite = favorite
                NCManageDatabase.shared.addMetadata(metadata)
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterFavoriteFile, userInfo: ["ocId": ocId, "serverUrl": metadata.serverUrl])
            }
            completion(error)
        }
    }

    // MARK: - Lock Files

    func lockUnlockFile(_ metadata: tableMetadata, shoulLock: Bool) {
        NextcloudKit.shared.lockUnlockFile(serverUrlFileName: metadata.serverUrl + "/" + metadata.fileName, shouldLock: shoulLock, account: metadata.account) { _, error in
            // 0: lock was successful; 412: lock did not change, no error, refresh
            guard error == .success || error.errorCode == NCGlobal.shared.errorPreconditionFailed else {
                let error = NKError(errorCode: error.errorCode, errorDescription: "_files_lock_error_")
                NCContentPresenter().messageNotification(metadata.fileName, error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
                return
            }
            NCNetworking.shared.readFile(serverUrlFileName: metadata.serverUrl + "/" + metadata.fileName, account: metadata.account) { _, metadata, error in
                guard error == .success, let metadata = metadata else { return }
                NCManageDatabase.shared.addMetadata(metadata)
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource)
            }
        }
    }

    // MARK: - Direct Download

    func getVideoUrl(metadata: tableMetadata,
                     completition: @escaping (_ url: URL?, _ autoplay: Bool, _ error: NKError) -> Void) {
        if !metadata.url.isEmpty {
            if metadata.url.hasPrefix("/") {
                completition(URL(fileURLWithPath: metadata.url), true, .success)
            } else {
                completition(URL(string: metadata.url), true, .success)
            }
        } else if utilityFileSystem.fileProviderStorageExists(metadata) {
            completition(URL(fileURLWithPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)), false, .success)
        } else {
            NextcloudKit.shared.getDirectDownload(fileId: metadata.fileId, account: metadata.account) { _, url, _, error in
                if error == .success && url != nil {
                    if let url = URL(string: url!) {
                        completition(url, false, error)
                    } else {
                        completition(nil, false, error)
                    }
                } else {
                    completition(nil, false, error)
                }
            }
        }
    }

    // MARK: - Search

    /// WebDAV search
    func searchFiles(urlBase: NCUserBaseUrl,
                     literal: String,
                     account: String,
                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                     completion: @escaping (_ metadatas: [tableMetadata]?, _ error: NKError) -> Void) {
        NextcloudKit.shared.searchLiteral(serverUrl: urlBase.urlBase,
                                          depth: "infinity",
                                          literal: literal,
                                          showHiddenFiles: NCKeychain().showHiddenFiles,
                                          account: account,
                                          options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { task in
            taskHandler(task)
        } completion: { _, files, _, error in
            guard error == .success else { return completion(nil, error) }

            NCManageDatabase.shared.convertFilesToMetadatas(files, useFirstAsMetadataFolder: false) { _, metadatas in
                NCManageDatabase.shared.addMetadatas(metadatas)
                completion(metadatas, error)
            }
        }
    }

    /// Unified Search (NC>=20)
    ///
    func unifiedSearchFiles(userBaseUrl: NCUserBaseUrl,
                            literal: String,
                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                            providers: @escaping (_ accout: String, _ searchProviders: [NKSearchProvider]?) -> Void,
                            update: @escaping (_ account: String, _ id: String, NKSearchResult?, [tableMetadata]?) -> Void,
                            completion: @escaping (_ account: String, _ error: NKError) -> Void) {
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        dispatchGroup.notify(queue: .main) {
            completion(userBaseUrl.account, NKError())
        }

        NextcloudKit.shared.unifiedSearch(term: literal, timeout: 30, timeoutProvider: 90, account: userBaseUrl.account) { _ in
            // example filter
            // ["calendar", "files", "fulltextsearch"].contains(provider.id)
            return true
        } request: { request in
            if let request = request {
                self.requestsUnifiedSearch.append(request)
            }
        } taskHandler: { task in
            taskHandler(task)
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
                                    taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                    completion: @escaping (_ account: String, _ searchResult: NKSearchResult?, _ metadatas: [tableMetadata]?, _ error: NKError) -> Void) {
        var metadatas: [tableMetadata] = []

        let request = NextcloudKit.shared.searchProvider(id, term: term, limit: limit, cursor: cursor, timeout: 60, account: userBaseUrl.account) { task in
            taskHandler(task)
        } completion: { account, searchResult, _, error in
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
        self.readFile(serverUrlFileName: urlPath, account: userBaseUrl.account) { account, metadata, error in
            defer { dispatchGroup?.leave() }
            guard let metadata = metadata else { return }
            let returnMetadata = tableMetadata.init(value: metadata)
            NCManageDatabase.shared.addMetadata(metadata)
            completion(account, returnMetadata, error)
        }
    }

    func cancelDataTask() {
        let sessionManager = NextcloudKit.shared.sessionManager

        sessionManager.session.getTasksWithCompletionHandler { dataTasks, _, _ in
            dataTasks.forEach {
                $0.cancel()
            }
        }
    }
}

class NCOperationDownloadAvatar: ConcurrentOperation {
    var user: String
    var fileName: String
    var etag: String?
    var fileNameLocalPath: String
    var cell: NCCellProtocol!
    var view: UIView?
    var account: String

    init(user: String, fileName: String, fileNameLocalPath: String, account: String, cell: NCCellProtocol, view: UIView?) {
        self.user = user
        self.fileName = fileName
        self.fileNameLocalPath = fileNameLocalPath
        self.account = account
        self.cell = cell
        self.view = view
        self.etag = NCManageDatabase.shared.getTableAvatar(fileName: fileName)?.etag
    }

    override func start() {
        guard !isCancelled else { return self.finish() }

        NextcloudKit.shared.downloadAvatar(user: user,
                                           fileNameLocalPath: fileNameLocalPath,
                                           sizeImage: NCGlobal.shared.avatarSize,
                                           avatarSizeRounded: NCGlobal.shared.avatarSizeRounded,
                                           etag: self.etag,
                                           account: account,
                                           options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { _, imageAvatar, _, etag, error in
            if error == .success, let imageAvatar {
                NCManageDatabase.shared.addAvatar(fileName: self.fileName, etag: etag ?? "")
                DispatchQueue.main.async {
                    if self.user == self.cell.fileUser, let cellFileAvatarImageView = self.cell.fileAvatarImageView {
                        cellFileAvatarImageView.contentMode = .scaleAspectFill
                        UIView.transition(with: cellFileAvatarImageView,
                                          duration: 0.75,
                                          options: .transitionCrossDissolve,
                                          animations: { cellFileAvatarImageView.image = imageAvatar },
                                          completion: nil)
                    } else {
                        if self.view is UICollectionView {
                            (self.view as? UICollectionView)?.reloadData()
                        } else if self.view is UITableView {
                            (self.view as? UITableView)?.reloadData()
                        }
                    }
                }
            } else if error.errorCode == NCGlobal.shared.errorNotModified {
                NCManageDatabase.shared.setAvatarLoaded(fileName: self.fileName)
            }
            self.finish()
        }
    }
}
