// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import Alamofire
import RealmSwift

extension NCNetworking {

    // MARK: - Download file in foreground

    @discardableResult
    func downloadFile(metadata: tableMetadata,
                      requestHandler: @escaping (_ request: DownloadRequest) -> Void = { _ in },
                      taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                      progressHandler: @escaping (_ progress: Progress) -> Void = { _ in })
    async -> (account: String,
              etag: String?,
              date: Date?,
              length: Int64,
              nkError: NKError ) {
        let options = NKRequestOptions(queue: nkComm.backgroundQueue)
        let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileName: metadata.fileName, userId: metadata.userId, urlBase: metadata.urlBase)

        if metadata.status == global.metadataStatusDownloading || metadata.status == global.metadataStatusUploading {
            return(metadata.account, metadata.etag, metadata.date as Date, metadata.size, .success)
        }

        await updateMetadataPlaceholder(metadata)

        let results = await NextcloudKit.shared.downloadAsync(serverUrlFileName: metadata.serverUrlFileName,
                                                              fileNameLocalPath: fileNameLocalPath,
                                                              account: metadata.account,
                                                              options: options) { request in
            requestHandler(request)
        } taskHandler: { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: metadata.account,
                                                                                            path: metadata.serverUrlFileName,
                                                                                            name: "download")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)

                await NCManageDatabase.shared.setMetadataSessionAsync(
                    ocId: metadata.ocId,
                    session: self.sessionDownload,
                    sessionTaskIdentifier: task.taskIdentifier,
                    status: self.global.metadataStatusDownloading)

                await self.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferChange(networkingStatus: self.global.networkingStatusDownloading,
                                            account: metadata.account,
                                            fileName: metadata.fileName,
                                            serverUrl: metadata.serverUrl,
                                            selector: metadata.sessionSelector,
                                            ocId: metadata.ocId,
                                            destination: nil,
                                            error: .success)
                }
            }
            taskHandler(task)
        } progressHandler: { progress in
            Task {
                guard await self.progressQuantizer.shouldEmit(serverUrlFileName: metadata.serverUrlFileName, fraction: progress.fractionCompleted) else {
                    return
                }
                await self.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferProgressDidUpdate(progress: Float(progress.fractionCompleted),
                                                       totalBytes: progress.totalUnitCount,
                                                       totalBytesExpected: progress.completedUnitCount,
                                                       fileName: metadata.fileName,
                                                       serverUrl: metadata.serverUrl)
                }
            }
            progressHandler(progress)
        }

        await progressQuantizer.clear(serverUrlFileName: metadata.serverUrlFileName)
        let allHeaderFields = results.response?.response?.allHeaderFields
        let etag = nkComm.normalizedETag(nkComm.findHeader("oc-etag", allHeaderFields: allHeaderFields))

        if results.nkError == .success {
            await downloadSuccess(withMetadata: metadata, etag: etag)
        } else {
            await downloadError(withMetadata: metadata, error: results.nkError)
        }

        return(metadata.account, etag, metadata.date as Date, metadata.size, results.nkError)
    }

    // MARK: - Download file in background

    @discardableResult
    func downloadFileInBackground(metadata: tableMetadata,
                                  taskHandler: @escaping (_ task: URLSessionDownloadTask?) -> Void = { _ in },
                                  start: @escaping () -> Void = { }) async -> NKError {
        let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileName: metadata.fileNameView, userId: metadata.userId, urlBase: metadata.urlBase)

        start()

        let (task, error) = await backgroundSession.downloadAsync(serverUrlFileName: metadata.serverUrlFileName,
                                                                  fileNameLocalPath: fileNameLocalPath,
                                                                  account: metadata.account,
                                                                  sessionIdentifier: sessionDownloadBackground)

        taskHandler(task)

        if let task, error == .success {
            nkLog(debug: " Downloading file \(metadata.fileNameView) with task with taskIdentifier \(task.taskIdentifier)")

            await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                  session: self.sessionDownloadBackground,
                                                                  sessionTaskIdentifier: task.taskIdentifier,
                                                                  status: self.global.metadataStatusDownloading)

            await self.transferDispatcher.notifyAllDelegates { delegate in
                delegate.transferChange(networkingStatus: self.global.networkingStatusDownloading,
                                        account: metadata.account,
                                        fileName: metadata.fileName,
                                        serverUrl: metadata.serverUrl,
                                        selector: metadata.sessionSelector,
                                        ocId: metadata.ocId,
                                        destination: nil,
                                        error: .success)
            }
        } else {
            _ = await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                      session: "",
                                                                      sessionTaskIdentifier: 0,
                                                                      sessionError: "",
                                                                      selector: "",
                                                                      status: self.global.metadataStatusNormal)
        }

        return(error)
    }

    // MARK: - DOWNLOAD SUCCESS

    func downloadSuccess(withMetadata metadata: tableMetadata, etag: String?) async {
        nkLog(success: "Downloaded file: " + metadata.serverUrlFileName)

#if !EXTENSION
        if let result = await NCManageDatabase.shared.getE2eEncryptionAsync(predicate: NSPredicate(format: "fileNameIdentifier == %@ AND serverUrl == %@", metadata.fileName, metadata.serverUrl)) {
            NCEndToEndEncryption.shared().decryptFile(metadata.fileName,
                                                      fileNameView: metadata.fileNameView,
                                                      ocId: metadata.ocId,
                                                      userId: metadata.userId,
                                                      urlBase: metadata.urlBase,
                                                      key: result.key,
                                                      initializationVector: result.initializationVector,
                                                      authenticationTag: result.authenticationTag)
        }
#endif
        await NCManageDatabase.shared.addLocalFilesAsync(metadatas: [metadata])

        await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                              session: "",
                                                              sessionTaskIdentifier: 0,
                                                              sessionError: "",
                                                              status: self.global.metadataStatusNormal,
                                                              etag: etag)

        await self.transferDispatcher.notifyAllDelegates { delegate in
            delegate.transferChange(networkingStatus: self.global.networkingStatusDownloaded,
                                    account: metadata.account,
                                    fileName: metadata.fileName,
                                    serverUrl: metadata.serverUrl,
                                    selector: metadata.sessionSelector,
                                    ocId: metadata.ocId,
                                    destination: nil,
                                    error: .success)
        }
    }

    // MARK: - DOWNLOAD ERROR

    func downloadError(withMetadata metadata: tableMetadata, error: NKError) async {
        await nkComm.appendServerErrorAccount(metadata.account, errorCode: error.errorCode)

        nkLog(error: "Downloaded file: " + metadata.serverUrlFileName + ", result: error \(error.errorCode)")

        if error.errorCode == NCGlobal.shared.errorResourceNotFound {
            self.utilityFileSystem.removeFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase))

            await NCManageDatabase.shared.deleteLocalFileAsync(id: metadata.ocId)
            await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.ocId)
        } else if error.errorCode == NSURLErrorCancelled {
            await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                  session: "",
                                                                  sessionTaskIdentifier: 0,
                                                                  sessionError: "",
                                                                  selector: "",
                                                                  status: self.global.metadataStatusNormal)

            await self.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferChange(networkingStatus: self.global.networkingStatusDownloadCancel,
                                            account: metadata.account,
                                            fileName: metadata.fileName,
                                            serverUrl: metadata.serverUrl,
                                            selector: metadata.sessionSelector,
                                            ocId: metadata.ocId,
                                            destination: nil,
                                            error: .success)
                }
        } else {
           await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                 session: "",
                                                                 sessionTaskIdentifier: 0,
                                                                 sessionError: "",
                                                                 selector: "",
                                                                 status: self.global.metadataStatusNormal)

            await self.transferDispatcher.notifyAllDelegates { delegate in
                delegate.transferChange(networkingStatus: NCGlobal.shared.networkingStatusDownloaded,
                                        account: metadata.account,
                                        fileName: metadata.fileName,
                                        serverUrl: metadata.serverUrl,
                                        selector: metadata.sessionSelector,
                                        ocId: metadata.ocId,
                                        destination: nil,
                                        error: error)
            }
        }
    }

    // MARK: - Synchronization Download

    internal func synchronizationDownload(account: String,
                                          serverUrl: String,
                                          userId: String,
                                          urlBase: String,
                                          metadatasInDownload: [tableMetadata]?) async {
        let results = await NextcloudKit.shared.readFileOrFolderAsync(
            serverUrlFileName: serverUrl,
            depth: "infinity",
            showHiddenFiles: NCPreferences().getShowHiddenFiles(account: account),
            account: account
        ) { task in
            Task {
                let identifier = await self.networkingTasks.createIdentifier(
                    account: account,
                    name: "synchronizationDownload"
                )
                await self.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        guard results.error == .success, let files = results.files else {
            nkLog(tag: self.global.logTagSync,
                  emoji: .error,
                  message: "Read infinite folder: \(serverUrl), error: \(results.error.errorCode)")
            return
        }

        nkLog(tag: self.global.logTagSync,
              emoji: .success,
              message: "Read infinite folder: \(serverUrl)")

        let ocIdsInDownload = Set(metadatasInDownload?.map(\.ocId) ?? [])
        var directoriesToCreate: [tableMetadata] = []
        var metadatasToDownload: [tableMetadata] = []

        for file in files {
            let metadata = await NCManageDatabaseCreateMetadata().convertFileToMetadataAsync(file)

            if file.directory {
                directoriesToCreate.append(metadata)
                continue
            }

            guard await isFileDifferent(ocId: file.ocId,
                                        fileName: file.fileName,
                                        etag: file.etag,
                                        ocIdsInDownload: ocIdsInDownload,
                                        userId: userId,
                                        urlBase: urlBase) else {
                continue
            }

            metadata.session = self.sessionDownloadBackground
            metadata.sessionSelector = NCGlobal.shared.selectorSynchronizationOffline
            metadata.sessionTaskIdentifier = 0
            metadata.sessionError = ""
            metadata.status = NCGlobal.shared.metadataStatusWaitDownload
            metadata.sessionDate = Date()

            metadatasToDownload.append(metadata)
        }

        await NCManageDatabase.shared.createDirectoriesAsync(metadatas: directoriesToCreate)
        await NCManageDatabase.shared.addMetadatasAsync(metadatasToDownload)

        nkLog(tag: self.global.logTagSync,
              emoji: .start,
              message: "Queued \(metadatasToDownload.count) files for offline synchronization: \(serverUrl)")

    }

    internal func isFileDifferent(ocId: String,
                                  fileName: String,
                                  etag: String,
                                  ocIdsInDownload: Set<String>,
                                  userId: String,
                                  urlBase: String) async -> Bool {
        if ocIdsInDownload.contains(ocId) {
            return false
        }

        guard let localFile = await NCManageDatabase.shared.getTableLocalFileAsync(predicate: NSPredicate(format: "ocId == %@", ocId)) else {
            return true
        }

        let fileNamePath = self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId,
                                                                                  fileName: fileName,
                                                                                  userId: userId,
                                                                                  urlBase: urlBase)
        let size = await utilityFileSystem.fileSizeAsync(atPath: fileNamePath)

        return localFile.etag != etag || size == 0
    }

    // MARK: - Download for Offline

    func setMetadataAvalableOffline(_ metadata: tableMetadata, isOffline: Bool) async {
        if isOffline {
            if metadata.directory {
                await NCManageDatabase.shared.setDirectoryAsync(serverUrl: metadata.serverUrlFileName, offline: false, metadata: metadata)
                let predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND sessionSelector == %@ AND status == %d", metadata.account, metadata.serverUrlFileName, NCGlobal.shared.selectorSynchronizationOffline, NCGlobal.shared.metadataStatusWaitDownload)
                if let metadatas = await NCManageDatabase.shared.getMetadatasAsync(predicate: predicate) {
                    await NCManageDatabase.shared.clearMetadatasSessionAsync(metadatas: metadatas)
                }
            } else {
                await NCManageDatabase.shared.setOffLocalFileAsync(ocId: metadata.ocId)
            }
        } else if metadata.directory {
            await NCManageDatabase.shared.cleanTablesOcIds(account: metadata.account, userId: metadata.userId, urlBase: metadata.urlBase)
            await NCManageDatabase.shared.setDirectoryAsync(serverUrl: metadata.serverUrlFileName, offline: true, metadata: metadata)
            await NCNetworking.shared.synchronizationDownload(account: metadata.account, serverUrl: metadata.serverUrlFileName, userId: metadata.userId, urlBase: metadata.urlBase, metadatasInDownload: nil)
        } else {
            var metadatasSynchronizationOffline: [tableMetadata] = []
            metadatasSynchronizationOffline.append(metadata)
            if let metadata = await NCManageDatabase.shared.getMetadataLivePhotoAsync(metadata: metadata) {
                metadatasSynchronizationOffline.append(metadata)
            }
            await NCManageDatabase.shared.addLocalFilesAsync(metadatas: [metadata], offline: true)
            for metadata in metadatasSynchronizationOffline {
                await NCManageDatabase.shared.setMetadataSessionInWaitDownloadAsync(ocId: metadata.ocId,
                                                                                    session: NCNetworking.shared.sessionDownloadBackground,
                                                                                    selector: NCGlobal.shared.selectorSynchronizationOffline)
            }
        }

        // Reload data sorce
        await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
            delegate.transferReloadDataSource(serverUrl: metadata.serverUrl, requestData: false, status: nil)
        }
    }
}
