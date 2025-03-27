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
import NextcloudKit
import Alamofire
import Queuer
import Photos

extension NCNetworking {
    // MARK: - Read file, folder

    func readFolder(serverUrl: String,
                    account: String,
                    checkResponseDataChanged: Bool,
                    queue: DispatchQueue,
                    taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                    completion: @escaping (_ account: String, _ metadataFolder: tableMetadata?, _ metadatas: [tableMetadata]?, _ isDataChanged: Bool, _ error: NKError) -> Void) {

        func storeFolder(_ metadataFolder: tableMetadata?) {
            guard let metadataFolder else { return }

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
        }

        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrl,
                                             depth: "1",
                                             showHiddenFiles: NCKeychain().showHiddenFiles,
                                             account: account,
                                             options: NKRequestOptions(queue: queue)) { task in
            taskHandler(task)
        } completion: { account, files, responseData, error in
            guard error == .success, let files else {
                return completion(account, nil, nil, false, error)
            }

            let isResponseDataChanged = self.isResponseDataChanged(account: account, responseData: responseData)
            if checkResponseDataChanged, !isResponseDataChanged {
                let metadataFolder = self.database.getMetadataDirectoryFrom(files: files)
                storeFolder(metadataFolder)
                return completion(account, metadataFolder, nil, false, error)
            }

            self.database.convertFilesToMetadatas(files, useFirstAsMetadataFolder: true) { metadataFolder, metadatas in
                storeFolder(metadataFolder)
                self.database.updateMetadatasFiles(metadatas, serverUrl: serverUrl, account: account)
                completion(account, metadataFolder, metadatas, true, error)
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

            // Remove all known download limits from shares related to the given file.
            // This avoids obsolete download limit objects to stay around.
            // Afterwards create new download limits, should any such be returned for the known shares.

            let shares = self.database.getTableShares(account: metadata.account, serverUrl: metadata.serverUrl, fileName: metadata.fileName)

            for share in shares {
                self.database.deleteDownloadLimit(byAccount: metadata.account, shareToken: share.token)

                if let receivedDownloadLimit = file.downloadLimits.first(where: { $0.token == share.token }) {
                    self.database.createDownloadLimit(account: metadata.account, count: receivedDownloadLimit.count, limit: receivedDownloadLimit.limit, token: receivedDownloadLimit.token)
                }
            }

            completion(account, metadata, error)
        }
    }

    func readFile(serverUrlFileName: String,
                  showHiddenFiles: Bool = NCKeychain().showHiddenFiles,
                  account: String,
                  queue: DispatchQueue = NextcloudKit.shared.nkCommonInstance.backgroundQueue) async -> (account: String, metadata: tableMetadata?, error: NKError) {
        return await withCheckedContinuation { continuation in
            readFile(serverUrlFileName: serverUrlFileName, showHiddenFiles: showHiddenFiles, account: account, queue: queue) { _ in
            } completion: { account, metadata, error in
                continuation.resume(returning: (account, metadata, error))
            }
        }
    }

    func fileExists(serverUrlFileName: String,
                    account: String,
                    completion: @escaping (_ account: String, _ exists: Bool?, _ file: NKFile?, _ error: NKError) -> Void) {
        let options = NKRequestOptions(timeout: 10, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        let requestBody = NKDataFileXML(nkCommonInstance: NextcloudKit.shared.nkCommonInstance).getRequestBodyFileExists().data(using: .utf8)

        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName,
                                             depth: "0",
                                             requestBody: requestBody,
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
                      sceneIdentifier: String?,
                      session: NCSession.Session,
                      options: NKRequestOptions = NKRequestOptions()) async -> NKError {
        var fileNameFolder = utility.removeForbiddenCharacters(fileName.trimmingCharacters(in: .whitespacesAndNewlines))
        if !overwrite {
            fileNameFolder = utilityFileSystem.createFileName(fileNameFolder, serverUrl: serverUrl, account: session.account)
        }
        if fileNameFolder.isEmpty {
            return .success
        }
        let fileNameFolderUrl = serverUrl + "/" + fileNameFolder

        func writeDirectoryMetadata(_ metadata: tableMetadata) {
            self.database.deleteMetadata(predicate: NSPredicate(format: "account == %@ AND fileName == %@ AND serverUrl == %@", session.account, fileName, serverUrl))
            self.database.addMetadata(metadata)
            self.database.addDirectory(e2eEncrypted: metadata.e2eEncrypted,
                                       favorite: metadata.favorite,
                                       ocId: metadata.ocId,
                                       fileId: metadata.fileId,
                                       permissions: metadata.permissions,
                                       serverUrl: fileNameFolderUrl,
                                       account: session.account)

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["serverUrl": serverUrl])

            NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterCreateFolder, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "withPush": withPush, "sceneIdentifier": sceneIdentifier as Any])
        }

        /* check exists folder */
        var result = await readFile(serverUrlFileName: fileNameFolderUrl, account: session.account)

        if result.error == .success,
            let metadata = result.metadata {
            writeDirectoryMetadata(metadata)
            return .success
        }

        /* create folder */
        await createFolder(serverUrlFileName: fileNameFolderUrl, account: session.account, options: options)
        result = await readFile(serverUrlFileName: fileNameFolderUrl, account: session.account)

        if result.error == .success,
           let metadata = result.metadata {
            writeDirectoryMetadata(metadata)
        } else if let metadata = self.database.getMetadata(predicate: NSPredicate(format: "account == %@ AND fileName == %@ AND serverUrl == %@", session.account, fileName, serverUrl)) {
            self.database.setMetadataSession(ocId: metadata.ocId, sessionError: result.error.errorDescription)
        }

        return result.error
    }

    func createFolder(assets: [PHAsset],
                      useSubFolder: Bool,
                      session: NCSession.Session) {
        var foldersCreated: [String] = []

        func createMetadata(fileName: String, serverUrl: String) {
            var metadata = tableMetadata()
            guard !foldersCreated.contains(serverUrl + "/" + fileName) else {
                return
            }

            if let result = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView == %@", session.account, serverUrl, fileName)) {
                metadata = result
            } else {
                metadata = NCManageDatabase.shared.createMetadata(fileName: fileName,
                                                                  fileNameView: fileName,
                                                                  ocId: NSUUID().uuidString,
                                                                  serverUrl: serverUrl,
                                                                  url: "",
                                                                  contentType: "httpd/unix-directory",
                                                                  directory: true,
                                                                  session: session,
                                                                  sceneIdentifier: nil)
            }

            metadata.status = NCGlobal.shared.metadataStatusWaitCreateFolder
            metadata.sessionDate = Date()

            NCManageDatabase.shared.addMetadata(metadata)

            foldersCreated.append(serverUrl + "/" + fileName)
        }

        createMetadata(fileName: self.database.getAccountAutoUploadFileName(), serverUrl: self.database.getAccountAutoUploadDirectory(session: session))

        if useSubFolder {
            let autoUploadPath = self.database.getAccountAutoUploadPath(session: session)
            let autoUploadSubfolderGranularity = self.database.getAccountAutoUploadSubfolderGranularity()
            let folders = Set(assets.map { utilityFileSystem.createGranularityPath(asset: $0) }).sorted()

            for folder in folders {
                let componentsDate = folder.split(separator: "/")
                let year = componentsDate[0]
                let serverUrlYear = autoUploadPath

                createMetadata(fileName: String(year), serverUrl: serverUrlYear)

                if autoUploadSubfolderGranularity >= self.global.subfolderGranularityMonthly {
                    let month = componentsDate[1]
                    let serverUrlMonth = autoUploadPath + "/" + year

                    createMetadata(fileName: String(month), serverUrl: serverUrlMonth)

                    if autoUploadSubfolderGranularity == self.global.subfolderGranularityDaily {
                        let day = componentsDate[2]
                        let serverUrlDay = autoUploadPath + "/" + year + "/" + month

                        createMetadata(fileName: String(day), serverUrl: serverUrlDay)
                    }
                }
            }
        }
    }

    func createFolder(assets: [PHAsset],
                      useSubFolder: Bool,
                      session: NCSession.Session) async -> (Bool) {
        let serverUrlFileName = self.database.getAccountAutoUploadDirectory(session: session) + "/" + self.database.getAccountAutoUploadFileName()

        var result = await createFolder(serverUrlFileName: serverUrlFileName, account: session.account)

        if (result.error == .success || result.error.errorCode == 405), useSubFolder {
            let autoUploadPath = self.database.getAccountAutoUploadPath(session: session)
            let autoUploadSubfolderGranularity = self.database.getAccountAutoUploadSubfolderGranularity()
            let folders = Set(assets.map { utilityFileSystem.createGranularityPath(asset: $0) }).sorted()

            for folder in folders {
                let componentsDate = folder.split(separator: "/")
                let year = componentsDate[0]
                let serverUrlYear = autoUploadPath

                result = await createFolder(serverUrlFileName: serverUrlYear + "/" + String(year), account: session.account)

                if (result.error == .success || result.error.errorCode == 405), autoUploadSubfolderGranularity >= self.global.subfolderGranularityMonthly {
                    let month = componentsDate[1]
                    let serverUrlMonth = autoUploadPath + "/" + year

                    result = await createFolder(serverUrlFileName: serverUrlMonth + "/" + String(month), account: session.account)

                    if (result.error == .success || result.error.errorCode == 405), autoUploadSubfolderGranularity == self.global.subfolderGranularityDaily {
                        let day = componentsDate[2]
                        let serverUrlDay = autoUploadPath + "/" + year + "/" + month

                        result = await createFolder(serverUrlFileName: serverUrlDay + "/" + String(day), account: session.account)
                    }
                }

                if result.error != .success && result.error.errorCode != 405 { break }
            }
        }

        return (result.error == .success || result.error.errorCode == 405)
    }

    // MARK: - Delete

    func tapHudDelete() {
        tapHudStopDelete = true
    }

    func deleteCache(_ metadata: tableMetadata, sceneIdentifier: String?) async -> (NKError) {
        let ncHud = NCHud()
        var num: Float = 0

        func numIncrement() -> Float {
            num += 1
            return num
        }

        func deleteLocalFile(metadata: tableMetadata) {
            if let metadataLive = self.database.getMetadataLivePhoto(metadata: metadata) {
                self.database.deleteLocalFileOcId(metadataLive.ocId)
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadataLive.ocId))
            }
            self.database.deleteVideo(metadata: metadata)
            self.database.deleteLocalFileOcId(metadata.ocId)
            utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
#if !EXTENSION
            NCImageCache.shared.removeImageCache(ocIdPlusEtag: metadata.ocId + metadata.etag)
#endif
        }

        self.tapHudStopDelete = false

        if metadata.directory {
#if !EXTENSION
            if let controller = SceneManager.shared.getController(sceneIdentifier: sceneIdentifier) {
                await MainActor.run {
                    ncHud.initHudRing(view: controller.view, tapToCancelDetailText: true, tapOperation: tapHudDelete)
                }
            }
#endif
            let serverUrl = metadata.serverUrl + "/" + metadata.fileName
            let metadatas = self.database.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND directory == false", metadata.account, serverUrl))
            let total = Float(metadatas.count)
            for metadata in metadatas {
                deleteLocalFile(metadata: metadata)
                let num = numIncrement()
                ncHud.progress(num: num, total: total)
                if tapHudStopDelete { break }
            }
#if !EXTENSION
            ncHud.dismiss()
#endif
        } else {
            deleteLocalFile(metadata: metadata)
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["serverUrl": metadata.serverUrl, "clearDataSource": true])
        }

        return .success
    }

    func deleteMetadatas(_ metadatas: [tableMetadata], sceneIdentifier: String?) {
        var metadatasPlain: [tableMetadata] = []
        var metadatasE2EE: [tableMetadata] = []
        let ncHud = NCHud()
        var num: Float = 0

        func numIncrement() -> Float {
            num += 1
            return num
        }

        for metadata in metadatas {
            if metadata.isDirectoryE2EE {
                metadatasE2EE.append(metadata)
            } else {
                metadatasPlain.append(metadata)
            }
        }

#if !EXTENSION
        if !metadatasE2EE.isEmpty {
            if isOffline {
                return NCContentPresenter().showInfo(error: NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_offline_not_allowed_"))
            }

            self.tapHudStopDelete = false
            let total = Float(metadatasE2EE.count)

            Task {
                if let controller = SceneManager.shared.getController(sceneIdentifier: sceneIdentifier) {
                    await MainActor.run {
                        ncHud.initHudRing(view: controller.view, tapToCancelDetailText: true, tapOperation: tapHudDelete)
                    }
                }

                var ocIdDeleted: [String] = []
                var error = NKError()
                for metadata in metadatasE2EE where error == .success {
                    error = await NCNetworkingE2EEDelete().delete(metadata: metadata)
                    if error == .success {
                        ocIdDeleted.append(metadata.ocId)
                    }
                    let num = numIncrement()
                    ncHud.progress(num: num, total: total)
                    if tapHudStopDelete { break }
                }

                ncHud.dismiss()
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDeleteFile, userInfo: ["ocId": ocIdDeleted, "error": error])
            }
        }
#endif

        for metadata in metadatasPlain {
            let permission = NCUtility().permissionsContainsString(metadata.permissions, permissions: NCPermissions().permissionCanDelete)
            if (!metadata.permissions.isEmpty && permission == false) || (metadata.status != global.metadataStatusNormal) {
                return NCContentPresenter().showInfo(error: NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_delete_file_"))
            }

            if metadata.status == global.metadataStatusWaitCreateFolder {
                let metadatas = database.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@", metadata.account, metadata.serverUrl))
                for metadata in metadatas {
                    database.deleteMetadataOcId(metadata.ocId)
                    utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
                }
                return
            }
            self.database.setMetadataStatus(ocId: metadata.ocId, status: NCGlobal.shared.metadataStatusWaitDelete)
        }
    }

    // MARK: - Rename

    func renameMetadata(_ metadata: tableMetadata, fileNameNew: String) {
        let permission = utility.permissionsContainsString(metadata.permissions, permissions: NCPermissions().permissionCanRename)
        if (!metadata.permissions.isEmpty && permission == false) ||
            (metadata.status != global.metadataStatusNormal && metadata.status != global.metadataStatusWaitRename) {
            return NCContentPresenter().showInfo(error: NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_modify_file_"))
        }

        if metadata.isDirectoryE2EE {
#if !EXTENSION
            if isOffline {
                return NCContentPresenter().showInfo(error: NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_offline_not_allowed_"))
            }
            Task {
                let error = await NCNetworkingE2EERename().rename(metadata: metadata, fileNameNew: fileNameNew)
                if error != .success {
                    NCContentPresenter().showError(error: error)
                }
            }
#endif
        } else {
            self.database.renameMetadata(fileNameNew: fileNameNew, ocId: metadata.ocId, status: NCGlobal.shared.metadataStatusWaitRename)
        }
    }

    // MARK: - Move

    func moveMetadata(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool) {
        let permission = utility.permissionsContainsString(metadata.permissions, permissions: NCPermissions().permissionCanRename)

        if (!metadata.permissions.isEmpty && !permission) ||
            (metadata.status != global.metadataStatusNormal && metadata.status != global.metadataStatusWaitMove) {
            return NCContentPresenter().showInfo(error: NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_modify_file_"))
        }

        self.database.setMetadataCopyMove(ocId: metadata.ocId, serverUrlTo: serverUrlTo, overwrite: overwrite.description, status: NCGlobal.shared.metadataStatusWaitMove)
    }

    // MARK: - Copy

    func copyMetadata(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool) {
        let permission = utility.permissionsContainsString(metadata.permissions, permissions: NCPermissions().permissionCanRename)

        if (!metadata.permissions.isEmpty && !permission) ||
            (metadata.status != global.metadataStatusNormal && metadata.status != global.metadataStatusWaitCopy) {
            return NCContentPresenter().showInfo(error: NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_modify_file_"))
        }

        self.database.setMetadataCopyMove(ocId: metadata.ocId, serverUrlTo: serverUrlTo, overwrite: overwrite.description, status: NCGlobal.shared.metadataStatusWaitCopy)
    }

    // MARK: - Favorite

    func favoriteMetadata(_ metadata: tableMetadata,
                          completion: @escaping (_ error: NKError) -> Void) {
        if metadata.status != global.metadataStatusNormal && metadata.status != global.metadataStatusWaitFavorite {
            return NCContentPresenter().showInfo(error: NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_favorite_file_"))
        }

        self.database.setMetadataFavorite(ocId: metadata.ocId, favorite: !metadata.favorite, saveOldFavorite: metadata.favorite.description, status: global.metadataStatusWaitFavorite)

        NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterFavoriteFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl])
    }

    // MARK: - Lock Files

    func lockUnlockFile(_ metadata: tableMetadata, shoulLock: Bool) {
        NextcloudKit.shared.lockUnlockFile(serverUrlFileName: metadata.serverUrl + "/" + metadata.fileName, shouldLock: shoulLock, account: metadata.account) { _, _, error in
            // 0: lock was successful; 412: lock did not change, no error, refresh
            guard error == .success || error.errorCode == self.global.errorPreconditionFailed else {
                let error = NKError(errorCode: error.errorCode, errorDescription: "_files_lock_error_")
                NCContentPresenter().messageNotification(metadata.fileName, error: error, delay: self.global.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
                return
            }
            self.readFile(serverUrlFileName: metadata.serverUrl + "/" + metadata.fileName, account: metadata.account) { _, metadata, error in
                guard error == .success, let metadata = metadata else { return }
                self.database.addMetadata(metadata)
                NotificationCenter.default.postOnMainThread(name: self.global.notificationCenterReloadDataSource, userInfo: ["serverUrl": metadata.serverUrl, "clearDataSource": true])
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
                    if let filePath = entry.filePath {
                        let semaphore = DispatchSemaphore(value: 0)
                        self.loadMetadata(session: session, filePath: filePath, dispatchGroup: dispatchGroup) { _, metadata, _ in
                            metadatas.append(metadata)
                            semaphore.signal()
                        }
                        semaphore.wait()
                    } else {
                        print(#function, "[ERROR]: File search entry has no path: \(entry)")
                    }
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
            guard let metadata else { return }
            let returnMetadata = tableMetadata.init(value: metadata)
            self.database.addMetadata(metadata)
            completion(account, returnMetadata, error)
        }
    }
}

class NCOperationDownloadAvatar: ConcurrentOperation, @unchecked Sendable {
    var user: String
    var fileName: String
    var etag: String?
    var view: UIView?
    var account: String
    var isPreviewImageView: Bool

    init(user: String, fileName: String, account: String, view: UIView?, isPreviewImageView: Bool = false) {
        self.user = user
        self.fileName = fileName
        self.account = account
        self.view = view
        self.isPreviewImageView = isPreviewImageView
        self.etag = NCManageDatabase.shared.getTableAvatar(fileName: fileName)?.etag
    }

    override func start() {
        guard !isCancelled else { return self.finish() }

        NextcloudKit.shared.downloadAvatar(user: user,
                                           fileNameLocalPath: NCUtilityFileSystem().directoryUserData + "/" + fileName,
                                           sizeImage: NCGlobal.shared.avatarSize,
                                           avatarSizeRounded: NCGlobal.shared.avatarSizeRounded,
                                           etag: self.etag,
                                           account: account,
                                           options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { _, image, _, etag, _, error in

            if error == .success, let image {
                NCManageDatabase.shared.addAvatar(fileName: self.fileName, etag: etag ?? "")

                DispatchQueue.main.async {
                    let visibleCells: [UIView] = (self.view as? UICollectionView)?.visibleCells ?? (self.view as? UITableView)?.visibleCells ?? []
                    for case let cell as NCCellProtocol in visibleCells {
                        if self.user == cell.fileUser {

                            if self.isPreviewImageView, let filePreviewImageView = cell.filePreviewImageView {
                                UIView.transition(with: filePreviewImageView, duration: 0.75, options: .transitionCrossDissolve, animations: { filePreviewImageView.image = image}, completion: nil)
                            } else if let fileAvatarImageView = cell.fileAvatarImageView {
                                UIView.transition(with: fileAvatarImageView, duration: 0.75, options: .transitionCrossDissolve, animations: { fileAvatarImageView.image = image}, completion: nil)
                            }
                            break
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

class NCOperationFileExists: ConcurrentOperation, @unchecked Sendable {
    var serverUrlFileName: String
    var account: String
    var ocId: String

    init(metadata: tableMetadata) {
        serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        account = metadata.account
        ocId = metadata.ocId
    }

    override func start() {
        guard !isCancelled else { return self.finish() }

        NCNetworking.shared.fileExists(serverUrlFileName: serverUrlFileName, account: account) { _, _, _, error in
            if error == .success {
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterFileExists, userInfo: ["ocId": self.ocId, "fileExists": true])
            } else if error.errorCode == NCGlobal.shared.errorResourceNotFound {
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterFileExists, userInfo: ["ocId": self.ocId, "fileExists": false])
            }

            self.finish()
        }
    }
}
