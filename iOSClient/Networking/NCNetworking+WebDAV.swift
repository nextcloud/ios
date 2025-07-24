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

        let showHiddenFiles = NCKeychain().getShowHiddenFiles(account: account)

        let resultsReadFolder = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrl, depth: "1", showHiddenFiles: showHiddenFiles, account: account, options: options)

        guard resultsReadFolder.error == .success, let files = resultsReadFolder.files else {
            return(account, nil, nil, resultsReadFolder.error)
        }
        let (metadataFolder, metadatas) = await self.database.convertFilesToMetadatasAsync(files, serverUrlMetadataFolder: serverUrl)

        await self.database.addMetadataAsync(metadataFolder)
        await self.database.addDirectoryAsync(e2eEncrypted: metadataFolder.e2eEncrypted,
                                              favorite: metadataFolder.favorite,
                                              ocId: metadataFolder.ocId,
                                              fileId: metadataFolder.fileId,
                                              etag: metadataFolder.etag,
                                              permissions: metadataFolder.permissions,
                                              richWorkspace: metadataFolder.richWorkspace,
                                              serverUrl: serverUrl,
                                              account: metadataFolder.account)
        await self.database.updateMetadatasFilesAsync(metadatas, serverUrl: serverUrl, account: account)

        return (account, metadataFolder, metadatas, .success)
    }

    func readFile(serverUrlFileName: String,
                  account: String,
                  queue: DispatchQueue = NextcloudKit.shared.nkCommonInstance.backgroundQueue,
                  taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                  completion: @escaping (_ account: String, _ metadata: tableMetadata?, _ error: NKError) -> Void) {
        let options = NKRequestOptions(queue: queue)
        let showHiddenFiles = NCKeychain().getShowHiddenFiles(account: account)

        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", showHiddenFiles: showHiddenFiles, account: account, options: options) { task in
            taskHandler(task)
        } completion: { account, files, _, error in
            guard error == .success, files?.count == 1, let file = files?.first else {
                return completion(account, nil, error)
            }
            let isDirectoryE2EE = self.utilityFileSystem.isDirectoryE2EE(file: file)

            self.database.convertFileToMetadata(file, isDirectoryE2EE: isDirectoryE2EE, capabilities: self.capabilities[account]) { metadata in
                // Remove all known download limits from shares related to the given file.
                // This avoids obsolete download limit objects to stay around.
                // Afterwards create new download limits, should any such be returned for the known shares.

                let shares = self.database.getTableShares(account: metadata.account, serverUrl: metadata.serverUrl, fileName: metadata.fileName)

                for share in shares {
                    self.database.deleteDownloadLimit(byAccount: metadata.account, shareToken: share.token, sync: false)

                    if let receivedDownloadLimit = file.downloadLimits.first(where: { $0.token == share.token }) {
                        self.database.createDownloadLimit(account: metadata.account,
                                                          count: receivedDownloadLimit.count,
                                                          limit: receivedDownloadLimit.limit,
                                                          token: receivedDownloadLimit.token)
                    }
                }

                completion(account, metadata, error)
            }
        }
    }

    /// Async wrapper for `readFile(...)`, returns a tuple with account, metadata and error.
    func readFileAsync(serverUrlFileName: String,
                       account: String,
                       queue: DispatchQueue = NextcloudKit.shared.nkCommonInstance.backgroundQueue,
                       taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (account: String, metadata: tableMetadata?, error: NKError) {
        await withCheckedContinuation { continuation in
            readFile(serverUrlFileName: serverUrlFileName,
                     account: account,
                     queue: queue,
                     taskHandler: taskHandler) { account, metadata, error in
                continuation.resume(returning: (account, metadata, error))
            }
        }
    }

    func fileExists(serverUrlFileName: String,
                    account: String,
                    completion: @escaping (_ account: String, _ exists: Bool, _ file: NKFile?, _ error: NKError) -> Void) {
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
                completion(account, false, nil, error)
            }
        }
    }

    func fileExists(serverUrlFileName: String, account: String) async -> (account: String, exists: Bool, file: NKFile?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            fileExists(serverUrlFileName: serverUrlFileName, account: account) { account, exists, file, error in
                continuation.resume(returning: (account, exists, file, error))
            }
        })
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
            if self.database.getMetadata(predicate: NSPredicate(format: "fileNameView == %@ AND serverUrl == %@ AND account == %@", resultFileName, serverUrl, account)) != nil {
                newFileName()
                continue
            }
            let results = await fileExists(serverUrlFileName: serverUrl + "/" + resultFileName, account: account)
            if results.exists {
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
                      options: NKRequestOptions = NKRequestOptions()) async -> (serverExists: Bool, error: NKError) {

        let capabilities = await NKCapabilities.shared.getCapabilities(for: session.account)
        var fileNameFolder = FileAutoRenamer.rename(fileName, isFolderPath: true, capabilities: capabilities)
        if !overwrite {
            fileNameFolder = utilityFileSystem.createFileName(fileNameFolder, serverUrl: serverUrl, account: session.account)
        }
        if fileNameFolder.isEmpty {
            return (false, NKError(errorCode: global.errorIncorrectFileName, errorDescription: ""))
        }
        let fileNameFolderUrl = serverUrl + "/" + fileNameFolder

        func writeDirectoryMetadata(_ metadata: tableMetadata) async {
            await self.database.deleteMetadataAsync(predicate: NSPredicate(format: "account == %@ AND fileName == %@ AND serverUrl == %@", session.account, fileName, serverUrl))
            await self.database.addMetadataAsync(metadata)
            await self.database.addDirectoryAsync(e2eEncrypted: metadata.e2eEncrypted,
                                                  favorite: metadata.favorite,
                                                  ocId: metadata.ocId,
                                                  fileId: metadata.fileId,
                                                  permissions: metadata.permissions,
                                                  serverUrl: fileNameFolderUrl,
                                                  account: session.account)
        }

        /* check exists folder */
        let resultReadFile = await readFileAsync(serverUrlFileName: fileNameFolderUrl, account: session.account)
        if resultReadFile.error == .success,
            let metadata = resultReadFile.metadata {
            await writeDirectoryMetadata(metadata)
            return (true, .success)
        }

        /* create folder */
        let resultCreateFolder = await NextcloudKit.shared.createFolderAsync(serverUrlFileName: fileNameFolderUrl, account: session.account, options: options)
        if resultCreateFolder.error == .success {
            let resultReadFile = await readFileAsync(serverUrlFileName: fileNameFolderUrl, account: session.account)
            if resultReadFile.error == .success,
               let metadata = resultReadFile.metadata {
                await writeDirectoryMetadata(metadata)
            }
        }

        return (false, resultCreateFolder.error)
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
            if let metadataLive = await self.database.getMetadataLivePhotoAsync(metadata: metadata) {
                await self.database.deleteLocalFileOcIdAsync(metadataLive.ocId)
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadataLive.ocId))
            }
            await self.database.deleteVideoAsync(metadata.ocId)
            await self.database.deleteLocalFileOcIdAsync(metadata.ocId)
            utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))

            NCImageCache.shared.removeImageCache(ocIdPlusEtag: metadata.ocId + metadata.etag)
        }

        self.tapHudStopDelete = false

        await database.cleanTablesOcIds(account: metadata.account)

        if metadata.directory {
            if let controller = SceneManager.shared.getController(sceneIdentifier: sceneIdentifier) {
                await MainActor.run {
                    ncHud.initHudRing(view: controller.view, tapToCancelDetailText: true, tapOperation: tapHudDelete)
                }
            }
            if let metadatas = await self.database.getMetadatasAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND directory == false", metadata.account, metadata.serverUrlFileName)) {
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

            self.notifyAllDelegates { delegate in
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
                        ncHud.initHudRing(view: controller.view, tapToCancelDetailText: true, tapOperation: tapHudDelete)
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
                self.notifyAllDelegates { delegate in
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
                    let metadatas = database.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@", metadata.account, metadata.serverUrl))
                    for metadata in metadatas {
                        database.deleteMetadataOcId(metadata.ocId)
                        utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
                    }
                    return
                }

                ocIds.insert(metadata.ocId)
                serverUrls.insert(metadata.serverUrl)
            }

            self.notifyAllDelegates { delegate in
                Task {
                    for ocId in ocIds {
                        await self.database.setMetadataSessionAsync(ocId: ocId,
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
            self.notifyAllDelegates { delegate in
                Task {
                    let status = self.global.metadataStatusWaitRename
                    await self.database.renameMetadataAsync(fileNameNew: fileNameNew, ocId: metadata.ocId, status: status)
                    delegate.transferReloadData(serverUrl: metadata.serverUrl, status: status)
                }
            }
        }
    }

    // MARK: - Move

    func moveMetadata(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool) {
        let permission = NCMetadataPermissions.permissionsContainsString(metadata.permissions, permissions: NCMetadataPermissions.permissionCanRename)

        if (!metadata.permissions.isEmpty && !permission) ||
            (metadata.status != global.metadataStatusNormal && metadata.status != global.metadataStatusWaitMove) {
            return NCContentPresenter().showInfo(error: NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_modify_file_"))
        }

        self.notifyAllDelegates { delegate in
            Task {
                let status = self.global.metadataStatusWaitMove
                await self.database.setMetadataCopyMoveAsync(ocId: metadata.ocId, serverUrlTo: serverUrlTo, overwrite: overwrite.description, status: status)
                delegate.transferReloadData(serverUrl: metadata.serverUrl, status: status)
            }
        }
    }

    // MARK: - Copy

    func copyMetadata(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool) {
        let permission = NCMetadataPermissions.permissionsContainsString(metadata.permissions, permissions: NCMetadataPermissions.permissionCanRename)

        if (!metadata.permissions.isEmpty && !permission) ||
            (metadata.status != global.metadataStatusNormal && metadata.status != global.metadataStatusWaitCopy) {
            return NCContentPresenter().showInfo(error: NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_no_permission_modify_file_"))
        }

        self.notifyAllDelegates { delegate in
            Task {
                let status = self.global.metadataStatusWaitCopy
                await self.database.setMetadataCopyMoveAsync(ocId: metadata.ocId, serverUrlTo: serverUrlTo, overwrite: overwrite.description, status: status)
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

        self.notifyAllDelegates { delegate in
            Task {
                let status = self.global.metadataStatusWaitFavorite
                await self.database.setMetadataFavoriteAsync(ocId: metadata.ocId, favorite: !metadata.favorite, saveOldFavorite: metadata.favorite.description, status: status)
                delegate.transferReloadData(serverUrl: metadata.serverUrl, status: status)
            }
        }
    }

    // MARK: - Lock Files

    func lockUnlockFile(_ metadata: tableMetadata, shoulLock: Bool) {
        NextcloudKit.shared.lockUnlockFile(serverUrlFileName: metadata.serverUrlFileName, shouldLock: shoulLock, account: metadata.account) { _, _, error in
            // 0: lock was successful; 412: lock did not change, no error, refresh
            guard error == .success || error.errorCode == self.global.errorPreconditionFailed else {
                let error = NKError(errorCode: error.errorCode, errorDescription: "_files_lock_error_")
                NCContentPresenter().messageNotification(metadata.fileName, error: error, delay: self.global.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
                return
            }
            self.readFile(serverUrlFileName: metadata.serverUrlFileName, account: metadata.account) { _, metadata, error in
                guard error == .success, let metadata = metadata else { return }
                self.database.addMetadata(metadata)

                self.notifyAllDelegates { delegate in
                    delegate.transferReloadData(serverUrl: metadata.serverUrl, status: nil)
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
        let showHiddenFiles = NCKeychain().getShowHiddenFiles(account: account)

        NextcloudKit.shared.searchLiteral(serverUrl: NCSession.shared.getSession(account: account).urlBase,
                                          depth: "infinity",
                                          literal: literal,
                                          showHiddenFiles: showHiddenFiles,
                                          account: account,
                                          options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { task in
            taskHandler(task)
        } completion: { _, files, _, error in
            guard error == .success, let files else { return completion(nil, error) }

            self.database.convertFilesToMetadatas(files, capabilities: self.capabilities[account]) { _, metadatas in
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
                    if let metadata = self.database.getMetadata(predicate: NSPredicate(format: "account == %@ && path == %@ && fileName == %@",
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
                        let metadata = await self.database.createMetadataAsync(fileName: entry.title,
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
                completion(account, searchResult, metadatas, error)
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
                completion(account, searchResult, metadatas, error)
            default:
                Task {
                    for entry in searchResult.entries {
                        let metadata = await self.database.createMetadataAsync(fileName: entry.title,
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
                                           etagResource: self.etag,
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
        serverUrlFileName = metadata.serverUrlFileName
        account = metadata.account
        ocId = metadata.ocId
    }

    override func start() {
        guard !isCancelled else { return self.finish() }

        NCNetworking.shared.fileExists(serverUrlFileName: serverUrlFileName, account: account) { _, _, _, error in
            if error == .success {
                NCNetworking.shared.notifyAllDelegates { delegate in
                    delegate.transferFileExists(ocId: self.ocId, exists: true)
                }
            } else if error.errorCode == NCGlobal.shared.errorResourceNotFound {
                NCNetworking.shared.notifyAllDelegates { delegate in
                    delegate.transferFileExists(ocId: self.ocId, exists: false)
                }
            }

            self.finish()
        }
    }
}
