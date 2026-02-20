// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import Alamofire
import Queuer
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
              headers: [AnyHashable: Any]?,
              afError: AFError?,
              nkError: NKError ) {
        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileName: metadata.fileName, userId: metadata.userId, urlBase: metadata.urlBase)

        if metadata.status == global.metadataStatusDownloading || metadata.status == global.metadataStatusUploading {
            return(metadata.account, metadata.etag, metadata.date as Date, metadata.size, nil, nil, .success)
        }

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
                    sessionTaskIdentifier: task.taskIdentifier,
                    status: self.global.metadataStatusDownloading)

                await self.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferChange(status: self.global.networkingStatusDownloading,
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

        Task {
            await progressQuantizer.clear(serverUrlFileName: metadata.serverUrlFileName)
            var error = NKError()

            if results.afError?.isExplicitlyCancelledError ?? false || (results.afError?.underlyingError as? URLError)?.code.rawValue == -999 {
                error = NKError(errorCode: self.global.errorRequestExplicityCancelled, errorDescription: "error request explicity cancelled")
            }

            if error == .success {
                await downloadSuccess(withMetadata: metadata, etag: results.etag)
            } else {
                await downloadError(withMetadata: metadata, error: error)
            }
        }

        return results
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
                                                                  sessionTaskIdentifier: task.taskIdentifier,
                                                                  status: self.global.metadataStatusDownloading)

            await self.transferDispatcher.notifyAllDelegates { delegate in
                delegate.transferChange(status: self.global.networkingStatusDownloading,
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
            delegate.transferChange(status: self.global.networkingStatusDownloaded,
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
        await NextcloudKit.shared.nkCommonInstance.appendServerErrorAccount(metadata.account, errorCode: error.errorCode)

        nkLog(error: "Downloaded file: " + metadata.serverUrlFileName + ", result: error \(error.errorCode)")

        if error.errorCode == NCGlobal.shared.errorResourceNotFound {
            self.utilityFileSystem.removeFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase))

            await NCManageDatabase.shared.deleteLocalFileAsync(id: metadata.ocId)
            await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.ocId)
        } else if error.errorCode == NSURLErrorCancelled || error.errorCode == self.global.errorRequestExplicityCancelled {
            await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                  session: "",
                                                                  sessionTaskIdentifier: 0,
                                                                  sessionError: "",
                                                                  selector: "",
                                                                  status: self.global.metadataStatusNormal)

            await self.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferChange(status: self.global.networkingStatusDownloadCancel,
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
                delegate.transferChange(status: NCGlobal.shared.networkingStatusDownloaded,
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

    internal func synchronizationDownload(account: String, serverUrl: String, userId: String, urlBase: String, metadatasInDownload: [tableMetadata]?) async {
        let showHiddenFiles = NCPreferences().getShowHiddenFiles(account: account)
        let options = NKRequestOptions(timeout: 300, taskDescription: NCGlobal.shared.taskDescriptionSynchronization, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        nkLog(tag: self.global.logTagSync, emoji: .start, message: "Start read infinite folder: \(serverUrl)")

        let results = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrl, depth: "infinity", showHiddenFiles: showHiddenFiles, account: account, options: options) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                            path: serverUrl,
                                                                                            name: "readFileOrFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        if results.error == .success, let files = results.files {
            nkLog(tag: self.global.logTagSync, emoji: .success, message: "Read infinite folder: \(serverUrl)")

            for file in files {
                if file.directory {
                    let metadata = await NCManageDatabaseCreateMetadata().convertFileToMetadataAsync(file)
                    await NCManageDatabase.shared.createDirectory(metadata: metadata)
                } else {
                    if await isFileDifferent(ocId: file.ocId, fileName: file.fileName, etag: file.etag, metadatasInDownload: metadatasInDownload, userId: userId, urlBase: urlBase) {
                        let metadata = await NCManageDatabaseCreateMetadata().convertFileToMetadataAsync(file)
                        metadata.session = self.sessionDownloadBackground
                        metadata.sessionSelector = NCGlobal.shared.selectorSynchronizationOffline
                        metadata.sessionTaskIdentifier = 0
                        metadata.sessionError = ""
                        metadata.status = NCGlobal.shared.metadataStatusWaitDownload
                        metadata.sessionDate = Date()

                        await NCManageDatabase.shared.addMetadataAsync(metadata)

                        nkLog(tag: self.global.logTagSync, emoji: .start, message: "File download: \(file.serverUrl)/\(file.fileName)")
                    }
                }
            }
        } else {
            nkLog(tag: self.global.logTagSync, emoji: .error, message: "Read infinite folder: \(serverUrl), error: \(results.error.errorCode)")
        }

        nkLog(tag: self.global.logTagSync, emoji: .stop, message: "Stop read infinite folder: \(serverUrl)")
    }

    internal func isFileDifferent(ocId: String,
                                  fileName: String,
                                  etag: String,
                                  metadatasInDownload: [tableMetadata]?,
                                  userId: String,
                                  urlBase: String) async -> Bool {
        let match = metadatasInDownload?.contains { $0.ocId == ocId } ?? false
        if match {
            return false
        }

        guard let localFile = await NCManageDatabase.shared.getTableLocalFileAsync(predicate: NSPredicate(format: "ocId == %@", ocId)) else {
            return true
        }
        let fileNamePath = self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId, fileName: fileName, userId: userId, urlBase: urlBase)
        let size = await utilityFileSystem.fileSizeAsync(atPath: fileNamePath)
        let isDifferent = (localFile.etag != etag) || size == 0

        return isDifferent
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
    }
}
