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
                                             includeHiddenFiles: self.global.includeHiddenFiles,
                                             account: account,
                                             options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { task in
            taskHandler(task)
        } completion: { account, files, _, error in
            guard error == .success, let files else {
                return completion(account, nil, nil, 0, 0, error)
            }

            self.database.convertFilesToMetadatas(files, useFirstAsMetadataFolder: true) { metadataFolder, metadatas in
                self.database.addMetadata(metadataFolder)
                self.database.addDirectory(e2eEncrypted: metadataFolder.e2eEncrypted,
                                           favorite: metadataFolder.favorite,
                                           ocId: metadataFolder.ocId,
                                           fileId: metadataFolder.fileId,
                                           etag: metadataFolder.etag,
                                           permissions: metadataFolder.permissions,
                                           richWorkspace: metadataFolder.richWorkspace,
                                           serverUrl: serverUrl,
                                           account: metadataFolder.account)
#if !EXTENSION
                // Convert Live Photo
                for metadata in metadatas {
                    if NCCapabilities.shared.getCapabilities(account: account).isLivePhotoServerAvailable, metadata.isLivePhoto {
                        self.convertLivePhoto(metadata: metadata)
                    }
                }
#endif
                let predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND status == %d", account, serverUrl, self.global.metadataStatusNormal)

                if forceReplaceMetadatas {
                    self.database.replaceMetadata(metadatas, predicate: predicate)
                    completion(account, metadataFolder, metadatas, 1, 1, error)
                } else {
                    let results = self.database.updateMetadatas(metadatas, predicate: predicate)
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
            guard error == .success, files?.count == 1, let file = files?.first else {
                return completion(account, nil, error)
            }
            let isDirectoryE2EE = self.utilityFileSystem.isDirectoryE2EE(file: file)
            let metadata = self.database.convertFileToMetadata(file, isDirectoryE2EE: isDirectoryE2EE)

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
            if error == .success, let file = files?.first {
                completion(account, true, file, error)
            } else if error.errorCode == self.global.errorResourceNotFound {
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
            if self.database.getMetadata(predicate: NSPredicate(format: "fileNameView == %@ AND serverUrl == %@ AND account == %@", resultFileName, serverUrl, account)) != nil {
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
                      overwrite: Bool,
                      withPush: Bool,
                      metadata: tableMetadata? = nil,
                      sceneIdentifier: String?,
                      session: NCSession.Session,
                      completion: @escaping (_ error: NKError) -> Void) {
        let isDirectoryEncrypted = utilityFileSystem.isDirectoryE2EE(session: session, serverUrl: serverUrl)
        let fileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)

        if isDirectoryEncrypted {
#if !EXTENSION
            Task {
                let error = await NCNetworkingE2EECreateFolder().createFolder(fileName: fileName, serverUrl: serverUrl, withPush: withPush, sceneIdentifier: sceneIdentifier, session: session)
                completion(error)
            }
#endif
        } else {
            createFolderPlain(fileName: fileName, serverUrl: serverUrl, overwrite: overwrite, withPush: withPush, metadata: metadata, sceneIdentifier: sceneIdentifier, session: session, completion: completion)
        }
    }

    private func createFolderPlain(fileName: String,
                                   serverUrl: String,
                                   overwrite: Bool,
                                   withPush: Bool,
                                   metadata: tableMetadata?,
                                   sceneIdentifier: String?,
                                   session: NCSession.Session,
                                   completion: @escaping (_ error: NKError) -> Void) {
        var fileNameFolder = utility.removeForbiddenCharacters(fileName)

        if fileName != fileNameFolder {
            let errorDescription = String(format: NSLocalizedString("_forbidden_characters_", comment: ""), self.global.forbiddenCharacters.joined(separator: " "))
            let error = NKError(errorCode: self.global.errorConflict, errorDescription: errorDescription)
            return completion(error)
        }
        if !overwrite {
            fileNameFolder = utilityFileSystem.createFileName(fileNameFolder, serverUrl: serverUrl, account: session.account)
        }
        if fileNameFolder.isEmpty {
            return completion(.success)
        }
        if isOffline {
            let metadataForUpload = NCManageDatabase.shared.createMetadata(fileName: fileNameFolder,
                                                                           fileNameView: fileNameFolder,
                                                                           ocId: NSUUID().uuidString,
                                                                           serverUrl: serverUrl,
                                                                           url: "",
                                                                           contentType: "httpd/unix-directory",
                                                                           directory: true,
                                                                           session: session,
                                                                           sceneIdentifier: sceneIdentifier)
            metadataForUpload.status = global.metadataStatusWaitCreateFolder
            NCManageDatabase.shared.addMetadata(metadataForUpload)

            NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterCreateFolder, userInfo: ["ocId": metadataForUpload.ocId, "serverUrl": metadataForUpload.serverUrl, "account": metadataForUpload.account, "withPush": withPush, "sceneIdentifier": sceneIdentifier as Any])
            return completion(.success)
        }

        let fileNameFolderUrl = serverUrl + "/" + fileNameFolder
        NextcloudKit.shared.createFolder(serverUrlFileName: fileNameFolderUrl, account: session.account) { account, _, _, error in
            self.readFile(serverUrlFileName: fileNameFolderUrl, account: account) { account, metadataFolder, error in

                /// metadataStatusWaitCreateFolder
                ///
                if let metadata, metadata.status == self.global.metadataStatusWaitCreateFolder {
                    if error == .success {
                        self.database.deleteMetadata(predicate: NSPredicate(format: "account == %@ AND fileName == %@ AND serverUrl == %@", metadata.account, metadata.fileName, metadata.serverUrl))
                    } else {
                        self.database.setMetadataSession(ocId: metadata.ocId, sessionError: error.errorDescription)
                    }
                }

                if error == .success, let metadataFolder {
                    self.database.addMetadata(metadataFolder)
                    self.database.addDirectory(e2eEncrypted: metadataFolder.e2eEncrypted,
                                                favorite: metadataFolder.favorite,
                                                ocId: metadataFolder.ocId,
                                                fileId: metadataFolder.fileId,
                                                permissions: metadataFolder.permissions,
                                                serverUrl: fileNameFolderUrl,
                                                account: account)

                    NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterCreateFolder, userInfo: ["ocId": metadataFolder.ocId, "serverUrl": metadataFolder.serverUrl, "account": metadataFolder.account, "withPush": withPush, "sceneIdentifier": sceneIdentifier as Any])

                }
                completion(error)
            }
        }
    }

    func createFolder(assets: [PHAsset]?,
                      useSubFolder: Bool,
                      withPush: Bool,
                      sceneIdentifier: String? = nil,
                      session: NCSession.Session) -> Bool {
        let autoUploadPath = self.database.getAccountAutoUploadPath(session: session)
        let serverUrlBase = self.database.getAccountAutoUploadDirectory(session: session)
        let fileNameBase = self.database.getAccountAutoUploadFileName()
        let autoUploadSubfolderGranularity = self.database.getAccountAutoUploadSubfolderGranularity()

        func createFolder(fileName: String, serverUrl: String) -> Bool {
            var result: Bool = false
            let semaphore = DispatchSemaphore(value: 0)
            self.createFolder(fileName: fileName, serverUrl: serverUrl, overwrite: true, withPush: withPush, metadata: nil, sceneIdentifier: sceneIdentifier, session: session) { error in
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
                if result && autoUploadSubfolderGranularity >= self.global.subfolderGranularityMonthly {
                    let month = subfolderArray[1]
                    let serverUrlMonth = autoUploadPath + "/" + year
                    result = createFolder(fileName: String(month), serverUrl: serverUrlMonth)
                    if result && autoUploadSubfolderGranularity == self.global.subfolderGranularityDaily {
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
        if metadata.status == global.metadataStatusWaitCreateFolder {
            let metadatas = database.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND status IN %@", metadata.account, metadata.serverUrl, global.metadataStatusAllUp))
            for metadata in metadatas {
                database.deleteMetadataOcId(metadata.ocId)
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
            }
        } else if onlyLocalCache {
#if !EXTENSION
            NCActivityIndicator.shared.start()
#endif
            func delete(metadata: tableMetadata) {
                if let metadataLive = self.database.getMetadataLivePhoto(metadata: metadata) {
                    self.database.deleteLocalFileOcId(metadataLive.ocId)
                    utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadataLive.ocId))
                }
                self.database.deleteVideo(metadata: metadata)
                self.database.deleteLocalFileOcId(metadata.ocId)
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
            }

            if metadata.directory {
                let serverUrl = metadata.serverUrl + "/" + metadata.fileName
                if let metadatas = self.database.getResultsMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND directory == false", metadata.account, serverUrl)) {
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
            return .success
        }

        if metadata.status == NCGlobal.shared.metadataStatusWaitCreateFolder {
            NCManageDatabase.shared.deleteMetadataOcId(metadata.ocId)
            return .success
        } else if metadata.isDirectoryE2EE {
#if !EXTENSION
            if let metadataLive = self.database.getMetadataLivePhoto(metadata: metadata) {
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
            if let metadataLive = self.database.getMetadataLivePhoto(metadata: metadata), metadata.isNotFlaggedAsLivePhotoByServer {
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
            return NKError(errorCode: self.global.errorInternalError, errorDescription: "_no_permission_delete_file_")
        }
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let options = NKRequestOptions(customHeader: customHeader)
        let result = await deleteFileOrFolder(serverUrlFileName: serverUrlFileName, account: metadata.account, options: options)

        if result.error == .success || result.error.errorCode == self.global.errorResourceNotFound {
            do {
                try FileManager.default.removeItem(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
            } catch { }

            self.database.deleteVideo(metadata: metadata)
            self.database.deleteMetadataOcId(metadata.ocId)
            self.database.deleteLocalFileOcId(metadata.ocId)
            // LIVE PHOTO SERVER
            if let metadataLive = self.database.getMetadataLivePhoto(metadata: metadata), metadataLive.isFlaggedAsLivePhotoByServer {
                do {
                    try FileManager.default.removeItem(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadataLive.ocId))
                } catch { }

                self.database.deleteVideo(metadata: metadataLive)
                self.database.deleteMetadataOcId(metadataLive.ocId)
                self.database.deleteLocalFileOcId(metadataLive.ocId)
            }

            if metadata.directory {
                self.database.deleteDirectoryAndSubDirectory(serverUrl: utilityFileSystem.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName), account: metadata.account)
            }
        }
        return result.error
    }

    // MARK: - Rename

    func renameMetadata(_ metadata: tableMetadata,
                        fileNameNew: String,
                        indexPath: IndexPath,
                        completion: @escaping (_ error: NKError) -> Void) {
        let metadataLive = self.database.getMetadataLivePhoto(metadata: metadata)
        let fileNameNew = fileNameNew.trimmingCharacters(in: .whitespacesAndNewlines)
        let fileNameNewLive = (fileNameNew as NSString).deletingPathExtension + ".mov"

        if metadata.status == NCGlobal.shared.metadataStatusWaitCreateFolder {
            metadata.fileName = fileNameNew
            metadata.fileNameView = fileNameNew
            NCManageDatabase.shared.addMetadata(metadata)
            NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterRenameFile, userInfo: ["ocId": metadata.ocId, "account": metadata.account, "indexPath": indexPath])
            completion(.success)
        } else if metadata.isDirectoryE2EE {
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
            return completion(NKError(errorCode: self.global.errorInternalError, errorDescription: "_no_permission_modify_file_"))
        }
        let fileName = utility.removeForbiddenCharacters(fileNameNew)
        if fileName != fileNameNew {
            let errorDescription = String(format: NSLocalizedString("_forbidden_characters_", comment: ""), self.global.forbiddenCharacters.joined(separator: " "))
            let error = NKError(errorCode: self.global.errorConflict, errorDescription: errorDescription)
            return completion(error)
        }
        let fileNameNew = fileName
        if fileNameNew.isEmpty || fileNameNew == metadata.fileNameView {
            return completion(NKError())
        }
        let fileNamePath = metadata.serverUrl + "/" + metadata.fileName
        let fileNameToPath = metadata.serverUrl + "/" + fileNameNew

        NextcloudKit.shared.moveFileOrFolder(serverUrlFileNameSource: fileNamePath, serverUrlFileNameDestination: fileNameToPath, overwrite: false, account: metadata.account) { account, error in
            if error == .success {
                self.database.renameMetadata(fileNameTo: fileNameNew, ocId: metadata.ocId, account: account)
                if metadata.directory {
                    let serverUrl = self.utilityFileSystem.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)
                    let serverUrlTo = self.utilityFileSystem.stringAppendServerUrl(metadata.serverUrl, addFileName: fileNameNew)
                    if let directory = self.database.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
                        self.database.setDirectory(serverUrl: serverUrl,
                                                   serverUrlTo: serverUrlTo,
                                                   etag: "",
                                                   encrypted: directory.e2eEncrypted,
                                                   account: metadata.account)
                    }
                } else {
                    if (metadata.fileName as NSString).pathExtension != (fileNameNew as NSString).pathExtension {
                        let path = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId)
                        self.utilityFileSystem.removeFile(atPath: path)
                    } else {
                        self.database.setLocalFile(ocId: metadata.ocId, fileName: fileNameNew)
                        let atPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + metadata.fileName
                        let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + fileNameNew
                        self.utilityFileSystem.moveFile(atPath: atPath, toPath: toPath)
                    }
                }
                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterRenameFile, userInfo: ["ocId": metadata.ocId, "account": metadata.account, "indexPath": indexPath])
            }
            completion(error)
        }
    }

    // MARK: - Move

    func moveMetadata(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool) async -> NKError {
        if let metadataLive = self.database.getMetadataLivePhoto(metadata: metadata), metadata.isNotFlaggedAsLivePhotoByServer {
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
            return NKError(errorCode: self.global.errorInternalError, errorDescription: "_no_permission_modify_file_")
        }
        let serverUrlFileNameSource = metadata.serverUrl + "/" + metadata.fileName
        let serverUrlFileNameDestination = serverUrlTo + "/" + metadata.fileName

        let result = await moveFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite, account: metadata.account)
        if result.error == .success {
            if metadata.directory {
                self.database.deleteDirectoryAndSubDirectory(serverUrl: utilityFileSystem.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName), account: result.account)
            } else {
                do {
                    try FileManager.default.removeItem(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
                } catch { }
                self.database.deleteVideo(metadata: metadata)
                self.database.deleteMetadataOcId(metadata.ocId)
                self.database.deleteLocalFileOcId(metadata.ocId)
                // LIVE PHOTO SERVER
                if let metadataLive = self.database.getMetadataLivePhoto(metadata: metadata), metadataLive.isFlaggedAsLivePhotoByServer {
                    do {
                        try FileManager.default.removeItem(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadataLive.ocId))
                    } catch { }
                    self.database.deleteVideo(metadata: metadataLive)
                    self.database.deleteMetadataOcId(metadataLive.ocId)
                    self.database.deleteLocalFileOcId(metadataLive.ocId)
                }
            }
        }
        return result.error
    }

    // MARK: - Copy

    func copyMetadata(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool) async -> NKError {
        if let metadataLive = self.database.getMetadataLivePhoto(metadata: metadata), metadata.isNotFlaggedAsLivePhotoByServer {
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
            return NKError(errorCode: self.global.errorInternalError, errorDescription: "_no_permission_modify_file_")
        }
        let serverUrlFileNameSource = metadata.serverUrl + "/" + metadata.fileName
        let serverUrlFileNameDestination = serverUrlTo + "/" + metadata.fileName

        let result = await copyFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite, account: metadata.account)
        return result.error
    }

    // MARK: - Favorite

    func favoriteMetadata(_ metadata: tableMetadata,
                          completion: @escaping (_ error: NKError) -> Void) {
        if let metadataLive = self.database.getMetadataLivePhoto(metadata: metadata) {
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
        let session = NCSession.Session(account: metadata.account, urlBase: metadata.urlBase, user: metadata.user, userId: metadata.userId)
        let fileName = utilityFileSystem.getFileNamePath(metadata.fileName, serverUrl: metadata.serverUrl, session: session)
        let favorite = !metadata.favorite
        let ocId = metadata.ocId

        NextcloudKit.shared.setFavorite(fileName: fileName, favorite: favorite, account: metadata.account) { _, error in
            if error == .success {
                metadata.favorite = favorite
                self.database.addMetadata(metadata)
                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterFavoriteFile, userInfo: ["ocId": ocId, "serverUrl": metadata.serverUrl])
            }
            completion(error)
        }
    }

    // MARK: - Lock Files

    func lockUnlockFile(_ metadata: tableMetadata, shoulLock: Bool) {
        NextcloudKit.shared.lockUnlockFile(serverUrlFileName: metadata.serverUrl + "/" + metadata.fileName, shouldLock: shoulLock, account: metadata.account) { _, error in
            // 0: lock was successful; 412: lock did not change, no error, refresh
            guard error == .success || error.errorCode == self.global.errorPreconditionFailed else {
                let error = NKError(errorCode: error.errorCode, errorDescription: "_files_lock_error_")
                NCContentPresenter().messageNotification(metadata.fileName, error: error, delay: self.global.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
                return
            }
            self.readFile(serverUrlFileName: metadata.serverUrl + "/" + metadata.fileName, account: metadata.account) { _, metadata, error in
                guard error == .success, let metadata = metadata else { return }
                self.database.addMetadata(metadata)
                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterReloadDataSource)
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
    func searchFiles(literal: String,
                     account: String,
                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                     completion: @escaping (_ metadatas: [tableMetadata]?, _ error: NKError) -> Void) {
        NextcloudKit.shared.searchLiteral(serverUrl: NCSession.shared.getSession(account: account).urlBase,
                                          depth: "infinity",
                                          literal: literal,
                                          showHiddenFiles: NCKeychain().showHiddenFiles,
                                          account: account,
                                          options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { task in
            taskHandler(task)
        } completion: { _, files, _, error in
            guard error == .success, let files else { return completion(nil, error) }

            self.database.convertFilesToMetadatas(files, useFirstAsMetadataFolder: false) { _, metadatas in
                self.database.addMetadatas(metadatas)
                completion(metadatas, error)
            }
        }
    }

    /// Unified Search (NC>=20)
    ///
    func unifiedSearchFiles(literal: String,
                            account: String,
                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                            providers: @escaping (_ accout: String, _ searchProviders: [NKSearchProvider]?) -> Void,
                            update: @escaping (_ account: String, _ id: String, NKSearchResult?, [tableMetadata]?) -> Void,
                            completion: @escaping (_ account: String, _ error: NKError) -> Void) {
        let dispatchGroup = DispatchGroup()
        let session = NCSession.shared.getSession(account: account)
        dispatchGroup.enter()
        dispatchGroup.notify(queue: .main) {
            completion(session.account, NKError())
        }

        NextcloudKit.shared.unifiedSearch(term: literal, timeout: 30, timeoutProvider: 90, account: session.account) { _ in
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
                       let metadata = self.database.getMetadata(predicate: NSPredicate(format: "account == %@ && fileId == %@", session.account, String(fileId))) {
                        metadatas.append(metadata)
                    } else if let filePath = entry.filePath {
                        let semaphore = DispatchSemaphore(value: 0)
                        self.loadMetadata(session: session, filePath: filePath, dispatchGroup: dispatchGroup) { _, metadata, _ in
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
                    if let metadata = self.database.getMetadata(predicate: NSPredicate(
                              format: "account == %@ && path == %@ && fileName == %@",
                              session.account,
                              "/remote.php/dav/files/" + session.user + dir,
                              filename)) {
                        metadatas.append(metadata)
                    } else {
                        let semaphore = DispatchSemaphore(value: 0)
                        self.loadMetadata(session: session, filePath: dir + filename, dispatchGroup: dispatchGroup) { _, metadata, _ in
                            metadatas.append(metadata)
                            semaphore.signal()
                        }
                        semaphore.wait()
                    }
                })
            default:
                partialResult.entries.forEach({ entry in
                    let metadata = self.database.createMetadata(fileName: entry.title,
                                                                fileNameView: entry.title,
                                                                ocId: NSUUID().uuidString,
                                                                serverUrl: session.urlBase,
                                                                url: entry.resourceURL,
                                                                contentType: "",
                                                                isUrl: true,
                                                                name: partialResult.id,
                                                                subline: entry.subline,
                                                                iconName: entry.icon,
                                                                iconUrl: entry.thumbnailURL,
                                                                session: session,
                                                                sceneIdentifier: nil)
                    metadatas.append(metadata)
                })
            }
            update(account, provider.id, partialResult, metadatas)
        } completion: { _, _, _ in
            self.requestsUnifiedSearch.removeAll()
            dispatchGroup.leave()
        }
    }

    func unifiedSearchFilesProvider(id: String, term: String,
                                    limit: Int, cursor: Int,
                                    account: String,
                                    taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                                    completion: @escaping (_ account: String, _ searchResult: NKSearchResult?, _ metadatas: [tableMetadata]?, _ error: NKError) -> Void) {
        var metadatas: [tableMetadata] = []
        let session = NCSession.shared.getSession(account: account)
        let request = NextcloudKit.shared.searchProvider(id, term: term, limit: limit, cursor: cursor, timeout: 60, account: session.account) { task in
            taskHandler(task)
        } completion: { account, searchResult, _, error in
            guard let searchResult = searchResult else {
                return completion(account, nil, metadatas, error)
            }

            switch id {
            case "files":
                searchResult.entries.forEach({ entry in
                    if let fileId = entry.fileId, let metadata = self.database.getMetadata(predicate: NSPredicate(format: "account == %@ && fileId == %@", session.account, String(fileId))) {
                        metadatas.append(metadata)
                    } else if let filePath = entry.filePath {
                        let semaphore = DispatchSemaphore(value: 0)
                        self.loadMetadata(session: session, filePath: filePath, dispatchGroup: nil) { _, metadata, _ in
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
                    if let metadata = self.database.getMetadata(predicate: NSPredicate(format: "account == %@ && path == %@ && fileName == %@",
                                                                                                 session.account,
                                                                                                 "/remote.php/dav/files/" + session.user + dir, filename)) {
                        metadatas.append(metadata)
                    } else {
                        let semaphore = DispatchSemaphore(value: 0)
                        self.loadMetadata(session: session, filePath: dir + filename, dispatchGroup: nil) { _, metadata, _ in
                            metadatas.append(metadata)
                            semaphore.signal()
                        }
                        semaphore.wait()
                    }
                })
            default:
                searchResult.entries.forEach({ entry in
                    let newMetadata = self.database.createMetadata(fileName: entry.title,
                                                                   fileNameView: entry.title,
                                                                   ocId: NSUUID().uuidString,
                                                                   serverUrl: session.urlBase,
                                                                   url: entry.resourceURL,
                                                                   contentType: "",
                                                                   isUrl: true,
                                                                   name: searchResult.name.lowercased(),
                                                                   subline: entry.subline,
                                                                   iconName: entry.icon,
                                                                   iconUrl: entry.thumbnailURL,
                                                                   session: session,
                                                                   sceneIdentifier: nil)
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

    private func loadMetadata(session: NCSession.Session,
                              filePath: String,
                              dispatchGroup: DispatchGroup? = nil,
                              completion: @escaping (String, tableMetadata, NKError) -> Void) {
        let urlPath = session.urlBase + "/remote.php/dav/files/" + session.user + filePath

        dispatchGroup?.enter()
        self.readFile(serverUrlFileName: urlPath, account: session.account) { account, metadata, error in
            defer { dispatchGroup?.leave() }
            guard let metadata = metadata else { return }
            let returnMetadata = tableMetadata.init(value: metadata)
            self.database.addMetadata(metadata)
            completion(account, returnMetadata, error)
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
