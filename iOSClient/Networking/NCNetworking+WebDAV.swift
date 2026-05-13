// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import Queuer
import Photos
import LucidBanner

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
            taskHandler(task)
        }

        guard resultsReadFolder.error == .success, let files = resultsReadFolder.files else {
            return(account, nil, nil, resultsReadFolder.error)
        }
        let (metadataFolder, metadatas) = await NCManageDatabaseCreateMetadata().convertFilesToMetadatasAsync(files, serverUrlMetadataFolder: serverUrl)

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
                let metadata = await NCManageDatabaseCreateMetadata().convertFileToMetadataAsync(file)

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
        let metadata = await NCManageDatabaseCreateMetadata().convertFileToMetadataAsync(file)

        return(account, metadata, results.error)
    }

    func fileExists(serverUrlFileName: String, account: String) async -> NKError {
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

    /// Creates a unique file name on both local metadata and remote server side.
    /// It will try to append " 1", " 2", ... to the base name until the name is free.
    /// A safety `maxAttempts` is used to avoid infinite loops in case of persistent conflicts.
    func createFileName(fileNameBase: String, account: String, serverUrl: String) async -> String {
        let maxAttempts = 100  // safety guard
        var attempt = 0
        var resultFileName = fileNameBase

        // Helper to generate next candidate name
        func makeNextFileName(from current: String) -> String {
            let ns = current as NSString
            let name = ns.deletingPathExtension
            let ext  = ns.pathExtension

            // Look for pattern: "<name> <number>"
            if let lastSpaceRange = name.range(of: " ", options: .backwards) {
                let prefix = String(name[..<lastSpaceRange.lowerBound])
                let suffix = String(name[lastSpaceRange.upperBound...])

                if let num = Int(suffix) {
                    let newNum = num + 1
                    if ext.isEmpty {
                        return "\(prefix) \(newNum)"
                    } else {
                        return "\(prefix) \(newNum).\(ext)"
                    }
                }
            }

            // No trailing number → start with " 1"
            if ext.isEmpty {
                return "\(name) 1"
            } else {
                return "\(name) 1.\(ext)"
            }
        }

        while attempt < maxAttempts {
            attempt += 1

            // Check local metadata (avoid duplicates already queued/stored)
            if NCManageDatabase.shared.getMetadata( predicate: NSPredicate(format: "fileNameView == %@ AND serverUrl == %@ AND account == %@", resultFileName, serverUrl, account)) != nil {
                resultFileName = makeNextFileName(from: resultFileName)
                continue
            }
            // Check remote (DAV) if file/folder already exists on server
            let serverUrlFileName = utilityFileSystem.createServerUrl(serverUrl: serverUrl, fileName: resultFileName)
            let existsResult = await fileExists(serverUrlFileName: serverUrlFileName, account: account)

            if existsResult == .success {
                // Remote already has it → try next name
                resultFileName = makeNextFileName(from: resultFileName)
                continue
            } else if existsResult.errorCode == 404 {
                // 404 → free name
                return resultFileName
            } else {
                // Any other HTTP/DAV error (423, 401, 500, etc.) → better to stop here
                return resultFileName
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

        // Fast path: directory already exists → createDirectory DB + success
        let resultReadFile = await readFileAsync(serverUrlFileName: serverUrlFileName, account: session.account)
        if resultReadFile.error == .success,
            let metadata = resultReadFile.metadata {
            await NCManageDatabase.shared.createDirectory(metadata: metadata)
            return .success
        }

        // Try to create the directory
        let resultCreateFolder = await NextcloudKit.shared.createFolderAsync(serverUrlFileName: serverUrlFileName, account: session.account, options: options) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: session.account,
                                                                                            path: serverUrlFileName,
                                                                                            name: "createFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        // If creation reported success → read new files -> createDirectory DB + success
        if resultCreateFolder.error == .success {
            let resultReadFile = await readFileAsync(serverUrlFileName: serverUrlFileName, account: session.account)
            if resultReadFile.error == .success,
               let metadata = resultReadFile.metadata {
                await NCManageDatabase.shared.createDirectory(metadata: metadata)
            }
        } else {
        // set error
            await NCManageDatabase.shared.setMetadataSessionAsync(account: session.account,
                                                                  serverUrlFileName: serverUrlFileName,
                                                                  sessionError: resultCreateFolder.error.errorDescription,
                                                                  errorCode: resultCreateFolder.error.errorCode)
        }

        return resultCreateFolder.error
    }

    func createFolderForAutoUpload(serverUrlFileName: String, account: String) async -> NKError {
        // Fast path: directory already exists → cleanup + success
        let existsResult = await fileExists(serverUrlFileName: serverUrlFileName, account: account)
        if existsResult == .success {
            // 207 Multi-Status → Directory already exists → cleanup related metadata
            await NCManageDatabase.shared.deleteMetadataAsync(predicate: NSPredicate(format: "account == %@ AND serverUrlFileName == %@", account, serverUrlFileName))
            return (.success)
        } else if existsResult.errorCode == 404 {
            // 404 Not Found → directory does not exist
            // Proceed
        } else {
            // Any other error (423 locked, 401 auth, 403 forbidden, 5xx, etc.)
            return(existsResult)
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

    func createFolder(metadata: tableMetadata) async -> NKError {
        var error: NKError = .success

        if metadata.sessionSelector == self.global.selectorUploadAutoUpload {
            error = await createFolderForAutoUpload(serverUrlFileName: metadata.serverUrlFileName, account: metadata.account)
        } else {
            error = await createFolder(fileName: metadata.fileName,
                                       serverUrl: metadata.serverUrl,
                                       overwrite: true,
                                       session: NCSession.shared.getSession(account: metadata.account),
                                       selector: metadata.sessionSelector)
        }

        if let sceneIdentifier = metadata.sceneIdentifier {
            await transferDispatcher.notifyDelegates(forScene: sceneIdentifier) { delegate in
                delegate.transferChange(status: self.global.networkingStatusCreateFolder,
                                        account: metadata.account,
                                        fileName: metadata.fileName,
                                        serverUrl: metadata.serverUrl,
                                        selector: metadata.sessionSelector,
                                        ocId: metadata.ocId,
                                        destination: nil,
                                        error: error)
            } others: { delegate in
                delegate.transferReloadDataSource(serverUrl: metadata.serverUrl, requestData: false, status: nil)
            }
        } else {
            await transferDispatcher.notifyAllDelegates { delegate in
                delegate.transferChange(status: self.global.networkingStatusCreateFolder,
                                        account: metadata.account,
                                        fileName: metadata.fileName,
                                        serverUrl: metadata.serverUrl,
                                        selector: metadata.sessionSelector,
                                        ocId: metadata.ocId,
                                        destination: nil,
                                        error: error)
            }
        }

        return error
    }

    // MARK: - Delete

    func deleteCache(_ metadata: tableMetadata,
                     progress: @escaping (_ progress: Double) -> Void = { _ in }) async {
        var num: Float = 0
        func numIncrement() -> Float {
            num += 1
            return num
        }

        func deleteLocalFile(metadata: tableMetadata) async {
            if let metadataLive = await NCManageDatabase.shared.getMetadataLivePhotoAsync(metadata: metadata) {
                await NCManageDatabase.shared.deleteLocalFileAsync(id: metadataLive.ocId)
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadataLive.ocId, userId: metadata.userId, urlBase: metadata.urlBase))
            }
            await NCManageDatabase.shared.deleteVideoAsync(metadata.ocId)
            await NCManageDatabase.shared.deleteLocalFileAsync(id: metadata.ocId)
            utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase))

            NCImageCache.shared.removeImageCache(ocIdPlusEtag: metadata.ocId + metadata.etag)
        }

        await NCManageDatabase.shared.cleanTablesOcIds(account: metadata.account, userId: metadata.userId, urlBase: metadata.urlBase)

        if metadata.directory {
            if let metadatas = await NCManageDatabase.shared.getMetadatasAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND directory == false", metadata.account, metadata.serverUrlFileName)) {
                let total = Float(metadatas.count)
                for metadata in metadatas {
                    await deleteLocalFile(metadata: metadata)
                    let num = numIncrement()
                    progress(Double(num) / Double(total))
                }
            }
        } else {
            await deleteLocalFile(metadata: metadata)

            await self.transferDispatcher.notifyAllDelegates { delegate in
                delegate.transferReloadDataSource(serverUrl: metadata.serverUrl, requestData: false, status: nil)
            }
        }
    }

    func setStatusWaitDelete(metadatas: [tableMetadata]) async -> NKError {
        var ocIds = Set<String>()
        var serverUrls = Set<String>()

        for metadata in metadatas {
            if metadata.status == global.metadataStatusWaitCreateFolder {
                await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.ocId)
                let metadatas = await NCManageDatabase.shared.getMetadatasAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@", metadata.account, metadata.serverUrlFileName))
                for metadata in metadatas {
                    await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.ocId)
                    utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase))
                }
                return .success
            }

            let permission = NCMetadataPermissions.permissionsContainsString(metadata.permissions, permissions: NCMetadataPermissions.permissionCanDeleteOrUnshare)
            if (!metadata.permissions.isEmpty && permission == false) || (metadata.status != global.metadataStatusNormal) {
                return NKError(errorCode: global.errorNotPermission, errorDescription: "_no_permission_delete_file_")
            }

            ocIds.insert(metadata.ocId)
            serverUrls.insert(metadata.serverUrl)
        }

        let ocIdss = ocIds
        let serverUrlss = serverUrls
        await self.transferDispatcher.notifyAllDelegatesAsync { delegate in
            for ocId in ocIdss {
                await NCManageDatabase.shared.setMetadataSessionAsync(
                    ocId: ocId,
                    status: self.global.metadataStatusWaitDelete
                )
            }
            serverUrlss.forEach { serverUrl in
                delegate.transferReloadDataSource(serverUrl: serverUrl, requestData: false, status: self.global.metadataStatusWaitDelete)
            }
        }
        return .success
    }

    func deleteFileOrFolder(metadata: tableMetadata) async -> NKError {
        var results = await NextcloudKit.shared.deleteFileOrFolderAsync(serverUrlFileName: metadata.serverUrlFileName, account: metadata.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: metadata.account,
                                                                                            path: metadata.serverUrlFileName,
                                                                                            name: "deleteFileOrFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        if results.error == .success || results.error.errorCode == NCGlobal.shared.errorResourceNotFound || (results.error.errorCode == NCGlobal.shared.errorForbidden && metadata.isLivePhotoVideo) {
            do {
                try FileManager.default.removeItem(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase))
            } catch { }

            await NCManageDatabase.shared.deleteVideoAsync(metadata.ocId)
            if !metadata.livePhotoFile.isEmpty {
                await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.livePhotoFile)
            }
            await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.ocId)
            await NCManageDatabase.shared.deleteLocalFileAsync(id: metadata.ocId)

            if metadata.directory {
                let serverUrl = utilityFileSystem.createServerUrl(serverUrl: metadata.serverUrl, fileName: metadata.fileName)
                await NCManageDatabase.shared.deleteDirectoryAndSubDirectoryAsync(serverUrl: serverUrl,
                                                                                  account: metadata.account)
            }

            results.error = .success
        } else {
            await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                  status: global.metadataStatusNormal)
        }

        await transferDispatcher.notifyAllDelegates { delegate in
            delegate.transferChange(status: NCGlobal.shared.networkingStatusDelete,
                                    account: metadata.account,
                                    fileName: metadata.fileName,
                                    serverUrl: metadata.serverUrl,
                                    selector: metadata.sessionSelector,
                                    ocId: metadata.ocId,
                                    destination: nil,
                                    error: results.error)
        }

        return results.error
    }

    // MARK: - Rename

    func setStatusWaitRename(_ metadata: tableMetadata, fileNameNew: String, windowScene: UIWindowScene?) async -> NKError {
        let permission = NCMetadataPermissions.permissionsContainsString(metadata.permissions, permissions: NCMetadataPermissions.permissionCanRename)
        if (!metadata.permissions.isEmpty && permission == false) ||
            (metadata.status != global.metadataStatusNormal && metadata.status != global.metadataStatusWaitRename) {
            return NKError(errorCode: global.errorNotPermission, errorDescription: "_no_permission_modify_file_")
        }

        if metadata.isDirectoryE2EE {
            if isOffline {
                return NKError(errorCode: global.errorOfflineNotAllowed, errorDescription: "_offline_not_allowed_")
            }

            let error = await NCNetworkingE2EERename().rename(metadata: metadata, fileNameNew: fileNameNew, windowScene: windowScene)
            if error != .success {
                return NKError(errorCode: error.errorCode, errorDescription: error.errorDescription)
            }
        } else {
            let ocId = metadata.ocId
            let serverUrl = metadata.serverUrl
            await self.transferDispatcher.notifyAllDelegatesAsync { delegate in
                await NCManageDatabase.shared.renameMetadata(fileNameNew: fileNameNew, ocId: ocId, status: self.global.metadataStatusWaitRename)
                delegate.transferReloadDataSource(serverUrl: serverUrl, requestData: false, status: self.global.metadataStatusWaitRename)
            }
        }

        return .success
    }

    func renameFileOrFolder(metadata: tableMetadata) async -> NKError {
        let serverUrlFileNameSource = metadata.serverUrlFileName
        let serverUrlFileNameDestination = utilityFileSystem.createServerUrl(serverUrl: metadata.serverUrl, fileName: metadata.fileName)

        let results = await NextcloudKit.shared.moveFileOrFolderAsync(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: false, account: metadata.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: metadata.account,
                                                                                            path: serverUrlFileNameSource,
                                                                                            name: "moveFileOrFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        if results.error == .success {
            await NCManageDatabase.shared.setMetadataServerUrlFileNameStatusNormalAsync(ocId: metadata.ocId)
        } else {
            await NCManageDatabase.shared.restoreMetadataFileNameAsync(ocId: metadata.ocId)
        }

        await transferDispatcher.notifyAllDelegates { delegate in
            delegate.transferChange(status: NCGlobal.shared.networkingStatusRename,
                                    account: metadata.account,
                                    fileName: metadata.fileName,
                                    serverUrl: metadata.serverUrl,
                                    selector: metadata.sessionSelector,
                                    ocId: metadata.ocId,
                                    destination: nil,
                                    error: results.error)
        }

        return results.error
    }

    // MARK: - Move

    func setStatusWaitMove(_ metadata: tableMetadata, destination: String, overwrite: Bool) async -> NKError {
        let permission = NCMetadataPermissions.permissionsContainsString(metadata.permissions, permissions: NCMetadataPermissions.permissionCanRename)

        if (!metadata.permissions.isEmpty && !permission) ||
            (metadata.status != global.metadataStatusNormal && metadata.status != global.metadataStatusWaitMove) {
            return NKError(errorCode: global.errorNotPermission, errorDescription: "_no_permission_modify_file_")
        }

        let ocId = metadata.ocId
        let serverUrl = metadata.serverUrl
        await self.transferDispatcher.notifyAllDelegatesAsync { delegate in
            await NCManageDatabase.shared.setMetadataCopyMoveAsync(ocId: ocId, destination: destination, overwrite: overwrite.description, status: self.global.metadataStatusWaitMove)
            delegate.transferReloadDataSource(serverUrl: serverUrl, requestData: false, status: self.global.metadataStatusWaitMove)
        }

        return .success
    }

    func moveFileOrFolder(metadata: tableMetadata) async -> NKError {
        let destination = metadata.destination
        let serverUrlFileNameDestination = utilityFileSystem.createServerUrl(serverUrl: destination, fileName: metadata.fileName)
        let overwrite = (metadata.storeFlag as? NSString)?.boolValue ?? false

        let results = await NextcloudKit.shared.moveFileOrFolderAsync(serverUrlFileNameSource: metadata.serverUrlFileName, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite, account: metadata.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: metadata.account,
                                                                                            path: serverUrlFileNameDestination,
                                                                                            name: "moveFileOrFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                              status: global.metadataStatusNormal)

        if results.error == .success {
            let resultRead = await NCNetworking.shared.readFileAsync(serverUrlFileName: serverUrlFileNameDestination, account: metadata.account)
            if resultRead.error == .success, let metadata = resultRead.metadata {
                // Remove directory
                if metadata.directory {
                    let serverUrl = utilityFileSystem.createServerUrl(serverUrl: metadata.serverUrl, fileName: metadata.fileName)
                    await NCManageDatabase.shared.deleteDirectoryAndSubDirectoryAsync(serverUrl: serverUrl,
                                                                                      account: resultRead.account)
                }
                await NCManageDatabase.shared.addMetadataAsync(metadata)
            }
        }

        await transferDispatcher.notifyAllDelegates { delegate in
            delegate.transferChange(status: self.global.networkingStatusCopyMove,
                                    account: metadata.account,
                                    fileName: metadata.fileName,
                                    serverUrl: metadata.serverUrl,
                                    selector: metadata.sessionSelector,
                                    ocId: metadata.ocId,
                                    destination: destination,
                                    error: results.error)
        }

        return results.error
    }

    // MARK: - Copy

    func setStatusWaitCopy(_ metadata: tableMetadata, destination: String, overwrite: Bool) async -> NKError {
        let permission = NCMetadataPermissions.permissionsContainsString(metadata.permissions, permissions: NCMetadataPermissions.permissionCanRename)

        if (!metadata.permissions.isEmpty && !permission) ||
            (metadata.status != global.metadataStatusNormal && metadata.status != global.metadataStatusWaitCopy) {
            return NKError(errorCode: global.errorNotPermission, errorDescription: "_no_permission_modify_file_")
        }

        let ocId = metadata.ocId
        let serverUrl = metadata.serverUrl
        await self.transferDispatcher.notifyAllDelegatesAsync { delegate in
            await NCManageDatabase.shared.setMetadataCopyMoveAsync(ocId: ocId, destination: destination, overwrite: overwrite.description, status: self.global.metadataStatusWaitCopy)
            delegate.transferReloadDataSource(serverUrl: serverUrl, requestData: false, status: self.global.metadataStatusWaitCopy)
        }

        return .success
    }

    func copyFileOrFolder(metadata: tableMetadata) async -> NKError {
        let destination = metadata.destination
        var serverUrlFileNameDestination = utilityFileSystem.createServerUrl(serverUrl: destination, fileName: metadata.fileName)
        let overwrite = (metadata.storeFlag as? NSString)?.boolValue ?? false

        // Within same folder
        if metadata.serverUrl == destination {
            let fileNameCopy = await NCNetworking.shared.createFileName(fileNameBase: metadata.fileName, account: metadata.account, serverUrl: metadata.serverUrl)
            serverUrlFileNameDestination = utilityFileSystem.createServerUrl(serverUrl: destination, fileName: fileNameCopy)
        }

        let results = await NextcloudKit.shared.copyFileOrFolderAsync(serverUrlFileNameSource: metadata.serverUrlFileName, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite, account: metadata.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: metadata.account,
                                                                                            path: serverUrlFileNameDestination,
                                                                                            name: "copyFileOrFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                              status: global.metadataStatusNormal)

        if results.error == .success {
            let resultsRead = await NCNetworking.shared.readFileAsync(serverUrlFileName: serverUrlFileNameDestination, account: metadata.account)
            if resultsRead.error == .success, let metadata = resultsRead.metadata {
                await NCManageDatabase.shared.addMetadataAsync(metadata)
            }
        }

        await transferDispatcher.notifyAllDelegates { delegate in
            delegate.transferChange(status: self.global.networkingStatusCopyMove,
                                    account: metadata.account,
                                    fileName: metadata.fileName,
                                    serverUrl: metadata.serverUrl,
                                    selector: metadata.sessionSelector,
                                    ocId: metadata.ocId,
                                    destination: destination,
                                    error: results.error)
        }

        return results.error
    }

    // MARK: - Favorite

    func setStatusWaitFavorite(_ metadata: tableMetadata) async -> NKError {
        if metadata.status != global.metadataStatusNormal,
           metadata.status != global.metadataStatusWaitFavorite {
            return NKError(errorCode: global.errorNotPermission, errorDescription: "_no_permission_favorite_file_")
        }

        let ocId = metadata.ocId
        let serverUrl = metadata.serverUrl
        let favorite = metadata.favorite
        await self.transferDispatcher.notifyAllDelegatesAsync { delegate in
            await NCManageDatabase.shared.setMetadataFavoriteAsync(ocId: ocId, favorite: !favorite, saveOldFavorite: favorite.description, status: self.global.metadataStatusWaitFavorite)
            delegate.transferReloadDataSource(serverUrl: serverUrl, requestData: false, status: self.global.metadataStatusWaitFavorite)
        }

        return .success
    }

    func setFavorite(metadata: tableMetadata) async -> NKError {
        let session = NCSession.Session(account: metadata.account, urlBase: metadata.urlBase, user: metadata.user, userId: metadata.userId)
        let fileName = utilityFileSystem.getRelativeFilePath(metadata.fileName, serverUrl: metadata.serverUrl, session: session)

        let results = await NextcloudKit.shared.setFavoriteAsync(fileName: fileName, favorite: metadata.favorite, account: metadata.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: metadata.account,
                                                                                            path: fileName,
                                                                                            name: "setFavorite")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        if results.error == .success {
            await NCManageDatabase.shared.setMetadataFavoriteAsync(ocId: metadata.ocId,
                                                                   favorite: nil,
                                                                   saveOldFavorite: nil,
                                                                   status: global.metadataStatusNormal)
        } else {
            let favorite = (metadata.storeFlag as? NSString)?.boolValue ?? false
            await NCManageDatabase.shared.setMetadataFavoriteAsync(ocId: metadata.ocId,
                                                                   favorite: favorite,
                                                                   saveOldFavorite: nil,
                                                                   status: global.metadataStatusNormal)
        }

        await transferDispatcher.notifyAllDelegates { delegate in
            delegate.transferChange(status: self.global.networkingStatusFavorite,
                                    account: metadata.account,
                                    fileName: metadata.fileName,
                                    serverUrl: metadata.serverUrl,
                                    selector: metadata.sessionSelector,
                                    ocId: metadata.ocId,
                                    destination: nil,
                                    error: results.error)
        }

        return results.error
    }

    // MARK: - Lock Files

    func lockUnlockFile(_ metadata: tableMetadata, shouldLock: Bool) async -> NKError {
        do {
            _ = try await NextcloudKit.shared.lockUnlockFile(serverUrlFileName: metadata.serverUrlFileName, shouldLock: shouldLock, account: metadata.account)

            let results = await readFileAsync(serverUrlFileName: metadata.serverUrlFileName, account: metadata.account)

            guard results.error == .success,
                    let metadata = results.metadata else {
                return results.error
            }
            NCManageDatabase.shared.addMetadata(metadata)

            await self.transferDispatcher.notifyAllDelegates { delegate in
                delegate.transferReloadDataSource(serverUrl: metadata.serverUrl, requestData: false, status: nil)
            }
        } catch let nkError as NKError {
            return nkError
        } catch {
            print(error)
        }

        return .success
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
}

class NCOperationDownloadAvatar: ConcurrentOperation, @unchecked Sendable {
    let utilityFileSystem = NCUtilityFileSystem()
    var user: String
    var fileName: String
    var etag: String?
    var view: UIView?
    var account: String
    var isPreviewImage: Bool

    init(user: String, fileName: String, account: String, view: UIView?, isPreviewImage: Bool = false) {
        self.user = user
        self.fileName = fileName
        self.account = account
        self.view = view
        self.isPreviewImage = isPreviewImage
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
                #if !EXTENSION
                NCImageCache.shared.addImageCache(image: image, key: self.fileName)
                #endif

                DispatchQueue.main.async {
                    let visibleCells: [UIView] = (self.view as? UICollectionView)?.visibleCells ?? (self.view as? UITableView)?.visibleCells ?? []
                    for case let cell as NCCellMainProtocol in visibleCells {
                        if self.user == cell.metadata?.ownerId {
                            if self.isPreviewImage, let previewImage = cell.previewImg {
                                UIView.transition(with: previewImage, duration: 0.75, options: .transitionCrossDissolve, animations: { previewImage.image = image}, completion: nil)
                            } else if let cellList = cell as? NCListCell {
                                cellList.setSharedAvatarImage(image)
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
