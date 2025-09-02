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
import Queuer
import Photos

extension NCNetworking {
    // MARK: - Read file & folder

    /// Async wrapper for `readFolder(...)`, returns a tuple with account, metadataFolder, metadatas, and error.
    func readFolderAsync(serverUrl: String,
                         account: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (account: String, metadataFolder: tableMetadata?, metadatas: [tableMetadata]?, error: NKError) {

        let showHiddenFiles = NCPreferences().getShowHiddenFiles(account: account)

        let resultsReadFolder = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrl, depth: "1", showHiddenFiles: showHiddenFiles, account: account, options: options) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                            path: serverUrl,
                                                                                            name: "readFileOrFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        guard resultsReadFolder.error == .success, let files = resultsReadFolder.files else {
            return(account, nil, nil, resultsReadFolder.error)
        }
        let (metadataFolder, metadatas) = await NCManageDatabase.shared.convertFilesToMetadatasAsync(files, serverUrlMetadataFolder: serverUrl)

        await NCManageDatabase.shared.createDirectory(metadata: metadataFolder)
        await NCManageDatabase.shared.updateMetadatasFilesAsync(metadatas, serverUrl: serverUrl, account: account)

        return (account, metadataFolder, metadatas, .success)
    }

    func readFile(serverUrlFileName: String,
                  account: String,
                  taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                  completion: @escaping (_ account: String, _ metadata: tableMetadata?, _ file: NKFile?, _ error: NKError) -> Void) {
        let showHiddenFiles = NCPreferences().getShowHiddenFiles(account: account)

        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", showHiddenFiles: showHiddenFiles, account: account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                            path: serverUrlFileName,
                                                                                            name: "readFileOrFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
            taskHandler(task)
        } completion: { account, files, _, error in
            guard error == .success, files?.count == 1, let file = files?.first else {
                return completion(account, nil, nil, error)
            }
            Task {
                let metadata = await NCManageDatabase.shared.convertFileToMetadataAsync(file)

                completion(account, metadata, file, error)
            }
        }
    }

    func readFileAsync(serverUrlFileName: String,
                       account: String,
                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (account: String, metadata: tableMetadata?, error: NKError) {
        let showHiddenFiles = NCPreferences().getShowHiddenFiles(account: account)
        let results = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrlFileName,
                                                                      depth: "0",
                                                                      showHiddenFiles: showHiddenFiles,
                                                                      account: account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                            path: serverUrlFileName,
                                                                                            name: "readFileOrFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
            taskHandler(task)
        }
        guard results.error == .success, results.files?.count == 1, let file = results.files?.first else {
            return (account, nil, results.error)
        }
        let metadata = await NCManageDatabase.shared.convertFileToMetadataAsync(file)

        return(account, metadata, results.error)
    }

    func fileExists(serverUrlFileName: String, account: String) async -> NKError? {
        let requestBody = NKDataFileXML(nkCommonInstance: NextcloudKit.shared.nkCommonInstance).getRequestBodyFileExists().data(using: .utf8)

        let results = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrlFileName,
                                                                      depth: "0",
                                                                      requestBody: requestBody,
                                                                      account: account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                            path: serverUrlFileName,
                                                                                            name: "readFileOrFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        return results.error
    }

    // MARK: - Create Filename

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
            let serverUrlFileName = utilityFileSystem.createServerUrl(serverUrl: serverUrl, fileName: resultFileName)
            let error = await fileExists(serverUrlFileName: serverUrlFileName, account: account)
            if error == .success {
                newFileName()
            } else {
                exitLoop = true
            }
        }
        return resultFileName
    }

    // MARK: - Create folder

    func createFolder(fileName: String,
                      serverUrl: String,
                      overwrite: Bool,
                      session: NCSession.Session,
                      selector: String? = nil,
                      options: NKRequestOptions = NKRequestOptions()) async -> NKError {
        let capabilities = await NKCapabilities.shared.getCapabilities(for: session.account)
        var fileNameFolder = FileAutoRenamer.rename(fileName, isFolderPath: true, capabilities: capabilities)
        if !overwrite {
            fileNameFolder = utilityFileSystem.createFileName(fileNameFolder, serverUrl: serverUrl, account: session.account)
        }
        if fileNameFolder.isEmpty {
            return NKError(errorCode: global.errorIncorrectFileName, errorDescription: "")
        }
        let serverUrlFileName = utilityFileSystem.createServerUrl(serverUrl: serverUrl, fileName: fileNameFolder)

        /* check exists folder */
        let resultReadFile = await readFileAsync(serverUrlFileName: serverUrlFileName, account: session.account)
        if resultReadFile.error == .success,
            let metadata = resultReadFile.metadata {
            await NCManageDatabase.shared.createDirectory(metadata: metadata)
            return .success
        }

        /* create folder */
        let resultCreateFolder = await NextcloudKit.shared.createFolderAsync(serverUrlFileName: serverUrlFileName, account: session.account, options: options) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: session.account,
                                                                                            path: serverUrlFileName,
                                                                                            name: "createFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }
        if resultCreateFolder.error == .success {
            let resultReadFile = await readFileAsync(serverUrlFileName: serverUrlFileName, account: session.account)
            if resultReadFile.error == .success,
               let metadata = resultReadFile.metadata {
                await NCManageDatabase.shared.createDirectory(metadata: metadata)
            }
        } else {
            await NCManageDatabase.shared.setMetadataSessionAsync(account: session.account,
                                                                  serverUrlFileName: serverUrlFileName,
                                                                  sessionError: resultCreateFolder.error.errorDescription,
                                                                  errorCode: resultCreateFolder.error.errorCode)
        }

        return resultCreateFolder.error
    }

    func createFolderForAutoUpload(serverUrlFileName: String,
                                   account: String) async -> NKError {
        // Fast path: directory already exists → cleanup + success
        let error = await fileExists(serverUrlFileName: serverUrlFileName, account: account)
        if error == .success {
            await NCManageDatabase.shared.deleteMetadataAsync(predicate: NSPredicate(format: "account == %@ AND serverUrlFileName == %@", account, serverUrlFileName))
            return (.success)
        }

        // Try to create the directory
        let results = await NextcloudKit.shared.createFolderAsync(serverUrlFileName: serverUrlFileName, account: account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                            path: serverUrlFileName,
                                                                                            name: "createFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        // If creation reported success → cleanup
        if results.error == .success {
            await NCManageDatabase.shared.deleteMetadataAsync(predicate: NSPredicate(format: "account == %@ AND serverUrlFileName == %@", account, serverUrlFileName))
        } else {
        // set error
            await NCManageDatabase.shared.setMetadataSessionAsync(account: account,
                                                                  serverUrlFileName: serverUrlFileName,
                                                                  sessionError: results.error.errorDescription,
                                                                  errorCode: results.error.errorCode)
        }

        return results.error
    }

    // MARK: - Delete

    #if !EXTENSION
    func tapHudDelete() {
        tapHudStopDelete = true
    }

    @MainActor
    func deleteCache(_ metadata: tableMetadata, sceneIdentifier: String?) async -> (NKError) {
        let ncHud = NCHud()
        var num: Float = 0

        func numIncrement() -> Float {
            num += 1
            return num
        }

        func deleteLocalFile(metadata: tableMetadata) async {
            if let metadataLive = await NCManageDatabase.shared.getMetadataLivePhotoAsync(metadata: metadata) {
                await NCManageDatabase.shared.deleteLocalFileOcIdAsync(metadataLive.ocId)
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadataLive.ocId, userId: metadata.userId, urlBase: metadata.urlBase))
            }
            await NCManageDatabase.shared.deleteVideoAsync(metadata.ocId)
            await NCManageDatabase.shared.deleteLocalFileOcIdAsync(metadata.ocId)
            utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase))

            NCImageCache.shared.removeImageCache(ocIdPlusEtag: metadata.ocId + metadata.etag)
        }

        self.tapHudStopDelete = false

        await NCManageDatabase.shared.cleanTablesOcIds(account: metadata.account, userId: metadata.userId, urlBase: metadata.urlBase)

        if metadata.directory {
            if let controller = SceneManager.shared.getController(sceneIdentifier: sceneIdentifier) {
                await MainActor.run {
                    ncHud.ringProgress(view: controller.view, tapToCancelDetailText: true, tapOperation: tapHudDelete)
                }
            }
            if let metadatas = await NCManageDatabase.shared.getMetadatasAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND directory == false", metadata.account, metadata.serverUrlFileName)) {
                let total = Float(metadatas.count)
                for metadata in metadatas {
                    await deleteLocalFile(metadata: metadata)
                    let num = numIncrement()
                    ncHud.progress(num: num, total: total)
                    if tapHudStopDelete { break }
            }
        }
            ncHud.dismiss()
        } else {
            await deleteLocalFile(metadata: metadata)

            await self.transferDispatcher.notifyAllDelegates { delegate in
                delegate.transferReloadData(serverUrl: metadata.serverUrl, status: nil)
            }
        }

        return .success
    }
    #endif

    func setStatusWaitDelete(metadatas: [tableMetadata], sceneIdentifier: String?) {
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

        if !metadatasE2EE.isEmpty {
#if !EXTENSION

            if isOffline {
                return NCContentPresenter().showInfo(error: NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_offline_not_allowed_"))
            }

            self.tapHudStopDelete = false
            let total = Float(metadatasE2EE.count)

            Task {
                if let controller = SceneManager.shared.getController(sceneIdentifier: sceneIdentifier) {
                    await MainActor.run {
                        ncHud.ringProgress(view: controller.view, tapToCancelDetailText: true, tapOperation: tapHudDelete)
                    }
                }

                var metadatasError: [tableMetadata: NKError] = [:]
                for metadata in metadatasE2EE {
                    let error = await NCNetworkingE2EEDelete().delete(metadata: metadata)
                    if error == .success {
                        metadatasError[metadata.detachedCopy()] = .success
                    } else {
                        metadatasError[metadata.detachedCopy()] = error
                    }
                    let num = numIncrement()
                    ncHud.progress(num: num, total: total)
                    if tapHudStopDelete { break }
                }
                await self.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferChange(status: self.global.networkingStatusDelete,
                                            metadatasError: metadatasError)
                }
                ncHud.dismiss()
            }
#endif
        } else {
            var ocIds = Set<String>()
            var serverUrls = Set<String>()

            for metadata in metadatasPlain {
                let permission = NCMetadataPermissions.permissionsContainsString(metadata.permissions, permissions: NCMetadataPermissions.permissionCanDeleteOrUnshare)
                if (!metadata.permissions.isEmpty && permission == false) || (metadata.status != global.metadataStatusNormal) {
                    return NCContentPresenter().showInfo(error: NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_delete_file_"))
                }

                if metadata.status == global.metadataStatusWaitCreateFolder {
                    let metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@", metadata.account, metadata.serverUrl))
                    for metadata in metadatas {
                        NCManageDatabase.shared.deleteMetadataOcId(metadata.ocId)
                        utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase))
                    }
                    return
                }

                ocIds.insert(metadata.ocId)
                serverUrls.insert(metadata.serverUrl)
            }

            Task {
                await self.transferDispatcher.notifyAllDelegatesAsync { delegate in
                    for ocId in ocIds {
                        await NCManageDatabase.shared.setMetadataSessionAsync(ocId: ocId,
                                                                              status: self.global.metadataStatusWaitDelete)
                    }
                    serverUrls.forEach { serverUrl in
                        delegate.transferReloadData(serverUrl: serverUrl, status: self.global.metadataStatusWaitDelete)
                    }
                }
            }
        }
    }

    // MARK: - Rename

    func renameMetadata(_ metadata: tableMetadata, fileNameNew: String) {
        let permission = NCMetadataPermissions.permissionsContainsString(metadata.permissions, permissions: NCMetadataPermissions.permissionCanRename)
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
            Task {
                await self.transferDispatcher.notifyAllDelegatesAsync { delegate in
                    let status = self.global.metadataStatusWaitRename
                    await NCManageDatabase.shared.renameMetadataAsync(fileNameNew: fileNameNew, ocId: metadata.ocId, status: status)
                    delegate.transferReloadData(serverUrl: metadata.serverUrl, status: status)
                }
            }
        }
    }

    // MARK: - Move

    func moveMetadata(_ metadata: tableMetadata, destination: String, overwrite: Bool) {
        let permission = NCMetadataPermissions.permissionsContainsString(metadata.permissions, permissions: NCMetadataPermissions.permissionCanRename)

        if (!metadata.permissions.isEmpty && !permission) ||
            (metadata.status != global.metadataStatusNormal && metadata.status != global.metadataStatusWaitMove) {
            return NCContentPresenter().showInfo(error: NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_modify_file_"))
        }

        Task {
            await self.transferDispatcher.notifyAllDelegatesAsync { delegate in
                let status = self.global.metadataStatusWaitMove
                await NCManageDatabase.shared.setMetadataCopyMoveAsync(ocId: metadata.ocId, destination: destination, overwrite: overwrite.description, status: status)
                delegate.transferReloadData(serverUrl: metadata.serverUrl, status: status)
            }
        }
    }

    // MARK: - Copy

    func copyMetadata(_ metadata: tableMetadata, destination: String, overwrite: Bool) {
        let permission = NCMetadataPermissions.permissionsContainsString(metadata.permissions, permissions: NCMetadataPermissions.permissionCanRename)

        if (!metadata.permissions.isEmpty && !permission) ||
            (metadata.status != global.metadataStatusNormal && metadata.status != global.metadataStatusWaitCopy) {
            return NCContentPresenter().showInfo(error: NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_modify_file_"))
        }

        Task {
            await self.transferDispatcher.notifyAllDelegatesAsync { delegate in
                let status = self.global.metadataStatusWaitCopy
                await NCManageDatabase.shared.setMetadataCopyMoveAsync(ocId: metadata.ocId, destination: destination, overwrite: overwrite.description, status: status)
                delegate.transferReloadData(serverUrl: metadata.serverUrl, status: status)
            }
        }
    }

    // MARK: - Favorite

    func favoriteMetadata(_ metadata: tableMetadata,
                          completion: @escaping (_ error: NKError) -> Void) {
        if metadata.status != global.metadataStatusNormal && metadata.status != global.metadataStatusWaitFavorite {
            return NCContentPresenter().showInfo(error: NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_favorite_file_"))
        }

        Task {
            await self.transferDispatcher.notifyAllDelegatesAsync { delegate in
                let status = self.global.metadataStatusWaitFavorite
                await NCManageDatabase.shared.setMetadataFavoriteAsync(ocId: metadata.ocId, favorite: !metadata.favorite, saveOldFavorite: metadata.favorite.description, status: status)
                delegate.transferReloadData(serverUrl: metadata.serverUrl, status: status)
            }
        }
    }

    // MARK: - Lock Files

    func lockUnlockFile(_ metadata: tableMetadata, shoulLock: Bool) {
        NextcloudKit.shared.lockUnlockFile(serverUrlFileName: metadata.serverUrlFileName, shouldLock: shoulLock, account: metadata.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: metadata.account,
                                                                                            path: metadata.serverUrlFileName,
                                                                                            name: "lockUnlockFile")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        } completion: { _, _, error in
            // 0: lock was successful; 412: lock did not change, no error, refresh
            guard error == .success || error.errorCode == self.global.errorPreconditionFailed else {
                let error = NKError(errorCode: error.errorCode, errorDescription: "_files_lock_error_")
                NCContentPresenter().messageNotification(metadata.fileName, error: error, delay: self.global.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
                return
            }
            self.readFile(serverUrlFileName: metadata.serverUrlFileName, account: metadata.account) { _, metadata, _, error in
                guard error == .success, let metadata = metadata else { return }
                NCManageDatabase.shared.addMetadata(metadata)

                Task {
                    await self.transferDispatcher.notifyAllDelegates { delegate in
                        delegate.transferReloadData(serverUrl: metadata.serverUrl, status: nil)
                    }
                }
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
            completition(URL(fileURLWithPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileName: metadata.fileNameView, userId: metadata.userId, urlBase: metadata.urlBase)), false, .success)
        } else {
            NextcloudKit.shared.getDirectDownload(fileId: metadata.fileId, account: metadata.account) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: metadata.account,
                                                                                                path: metadata.fileId,
                                                                                                name: "getDirectDownload")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            } completion: { _, url, _, error in
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
        let showHiddenFiles = NCPreferences().getShowHiddenFiles(account: account)
        let serverUrl = NCSession.shared.getSession(account: account).urlBase
        NextcloudKit.shared.searchLiteral(serverUrl: serverUrl,
                                          depth: "infinity",
                                          literal: literal,
                                          showHiddenFiles: showHiddenFiles,
                                          account: account,
                                          options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                            path: serverUrl,
                                                                                            name: "searchLiteral")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
            taskHandler(task)
        } completion: { _, files, _, error in
            guard error == .success, let files else { return completion(nil, error) }

            Task {
                let (_, metadatas) = await NCManageDatabase.shared.convertFilesToMetadatasAsync(files)
                NCManageDatabase.shared.addMetadatas(metadatas)
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
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                            path: literal,
                                                                                            name: "unifiedSearch")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
            taskHandler(task)
        } providers: { account, searchProviders in
            providers(account, searchProviders)
        } update: { account, partialResult, provider, _ in
            guard let partialResult = partialResult else {
                return
            }
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
                update(account, provider.id, partialResult, metadatas)
            case "fulltextsearch":
                // NOTE: FTS could also return attributes like files
                // https://github.com/nextcloud/files_fulltextsearch/issues/143
                partialResult.entries.forEach({ entry in
                    let url = URLComponents(string: entry.resourceURL)
                    guard let dir = url?.queryItems?["dir"]?.value, let filename = url?.queryItems?["scrollto"]?.value else { return }
                    if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ && path == %@ && fileName == %@",
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
                update(account, provider.id, partialResult, metadatas)
            default:
                Task {
                    for entry in partialResult.entries {
                        let metadata = await NCManageDatabase.shared.createMetadataAsync(fileName: entry.title,
                                                                                         ocId: NSUUID().uuidString,
                                                                                         serverUrl: session.urlBase,
                                                                                         url: entry.resourceURL,
                                                                                         isUrl: true,
                                                                                         name: partialResult.id,
                                                                                         subline: entry.subline,
                                                                                         iconUrl: entry.thumbnailURL,
                                                                                         session: session,
                                                                                         sceneIdentifier: nil)
                        metadatas.append(metadata)
                    }
                    update(account, provider.id, partialResult, metadatas)
                }
            }
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
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                            path: term,
                                                                                            name: "searchProvider")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
            taskHandler(task)
        } completion: { account, searchResult, _, error in
            guard let searchResult = searchResult else {
                return completion(account, nil, metadatas, error)
            }

            switch id {
            case "files":
                searchResult.entries.forEach({ entry in
                    if let fileId = entry.fileId, let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ && fileId == %@", session.account, String(fileId))) {
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
                completion(account, searchResult, metadatas, error)
            case "fulltextsearch":
                // NOTE: FTS could also return attributes like files
                // https://github.com/nextcloud/files_fulltextsearch/issues/143
                searchResult.entries.forEach({ entry in
                    let url = URLComponents(string: entry.resourceURL)
                    guard let dir = url?.queryItems?["dir"]?.value, let filename = url?.queryItems?["scrollto"]?.value else { return }
                    if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "account == %@ && path == %@ && fileName == %@",
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
                completion(account, searchResult, metadatas, error)
            default:
                Task {
                    for entry in searchResult.entries {
                        let metadata = await NCManageDatabase.shared.createMetadataAsync(fileName: entry.title,
                                                                                         ocId: NSUUID().uuidString,
                                                                                         serverUrl: session.urlBase,
                                                                                         url: entry.resourceURL,
                                                                                         isUrl: true,
                                                                                         name: searchResult.name.lowercased(),
                                                                                         subline: entry.subline,
                                                                                         iconUrl: entry.thumbnailURL,
                                                                                         session: session,
                                                                                         sceneIdentifier: nil)
                        metadatas.append(metadata)
                    }
                    completion(account, searchResult, metadatas, error)
                }
            }
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
        self.readFile(serverUrlFileName: urlPath, account: session.account) { account, metadata, _, error in
            defer { dispatchGroup?.leave() }
            guard let metadata else { return }
            let returnMetadata = tableMetadata.init(value: metadata)
            NCManageDatabase.shared.addMetadata(metadata)
            completion(account, returnMetadata, error)
        }
    }
}

class NCOperationDownloadAvatar: ConcurrentOperation, @unchecked Sendable {
    let utilityFileSystem = NCUtilityFileSystem()
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
        guard !isCancelled else {
            return self.finish()
        }
        let fileNameLocalPath = utilityFileSystem.createServerUrl(serverUrl: utilityFileSystem.directoryUserData, fileName: fileName)

        NextcloudKit.shared.downloadAvatar(user: user,
                                           fileNameLocalPath: fileNameLocalPath,
                                           sizeImage: NCGlobal.shared.avatarSize,
                                           avatarSizeRounded: NCGlobal.shared.avatarSizeRounded,
                                           etagResource: self.etag,
                                           account: account,
                                           options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.account,
                                                                                            path: self.user,
                                                                                            name: "downloadAvatar")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        } completion: { _, image, _, etag, _, error in

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
