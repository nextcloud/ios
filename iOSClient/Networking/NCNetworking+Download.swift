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

                if let metadata = await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                                        sessionTaskIdentifier: task.taskIdentifier,
                                                                                        status: self.global.metadataStatusDownloading) {

                    await self.transferDispatcher.notifyAllDelegates { delegate in
                        delegate.transferChange(status: self.global.networkingStatusDownloading,
                                                metadata: metadata,
                                                destination: nil,
                                                error: .success)
                    }
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

            if let metadata = await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                                    sessionTaskIdentifier: task.taskIdentifier,
                                                                                    status: self.global.metadataStatusDownloading) {
                await self.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferChange(status: self.global.networkingStatusDownloading,
                                            metadata: metadata,
                                            destination: nil,
                                            error: .success)
                }
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

    private func downloadSuccess(withMetadata metadata: tableMetadata, etag: String?) async {
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

        if let downloadedMetadata = await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                                          session: "",
                                                                                          sessionTaskIdentifier: 0,
                                                                                          sessionError: "",
                                                                                          status: self.global.metadataStatusNormal,
                                                                                          etag: etag) {
            await self.transferDispatcher.notifyAllDelegates { delegate in
                delegate.transferChange(status: self.global.networkingStatusDownloaded,
                                        metadata: downloadedMetadata,
                                        destination: nil,
                                        error: .success)
            }
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
            if let metadata = await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                                    session: "",
                                                                                    sessionTaskIdentifier: 0,
                                                                                    sessionError: "",
                                                                                    selector: "",
                                                                                    status: self.global.metadataStatusNormal) {
                await self.transferDispatcher.notifyAllDelegates { delegate in
                        delegate.transferChange(status: self.global.networkingStatusDownloadCancel,
                                                metadata: metadata,
                                                destination: nil,
                                                error: .success)
                    }
            }
        } else {
            if let metadata = await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                                    session: "",
                                                                                    sessionTaskIdentifier: 0,
                                                                                    sessionError: "",
                                                                                    selector: "",
                                                                                    status: self.global.metadataStatusNormal) {

                await self.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferChange(status: NCGlobal.shared.networkingStatusDownloaded,
                                            metadata: metadata,
                                            destination: nil,
                                            error: error)
                }
            }
        }
    }

    // MARK: - Download NextcloudKitDelegate

    func downloadComplete(fileName: String,
                          serverUrl: String,
                          etag: String?,
                          date: Date?,
                          dateLastModified: Date?,
                          length: Int64,
                          task: URLSessionTask,
                          error: NKError) {
        Task {
            await progressQuantizer.clear(serverUrlFileName: serverUrl + "/" + fileName)

            #if EXTENSION_FILE_PROVIDER_EXTENSION
            await FileProviderData.shared.downloadComplete(fileName: fileName,
                                                           serverUrl: serverUrl,
                                                           etag: etag,
                                                           date: date,
                                                           dateLastModified: dateLastModified,
                                                           length: length,
                                                           task: task,
                                                           error: error)
            #else
            guard let metadata = await NCManageDatabase.shared.getMetadataAsync(predicate: NSPredicate(format: "serverUrl == %@ AND fileName == %@", serverUrl, fileName)) else {
                return
            }
            if error == .success {
                await downloadSuccess(withMetadata: metadata, etag: etag)
            } else {
                await downloadError(withMetadata: metadata, error: error)
            }
            #endif
        }
    }

    func downloadingFinish(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let httpResponse = (downloadTask.response as? HTTPURLResponse) {
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300,
               let url = downloadTask.currentRequest?.url,
               var serverUrl = url.deletingLastPathComponent().absoluteString.removingPercentEncoding {
                let fileName = url.lastPathComponent
                if serverUrl.hasSuffix("/") { serverUrl = String(serverUrl.dropLast()) }
                if let metadata = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "serverUrl == %@ AND fileName == %@", serverUrl, fileName)) {
                    let destinationFilePath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileName: metadata.fileName, userId: metadata.userId, urlBase: metadata.urlBase)
                    do {
                        if FileManager.default.fileExists(atPath: destinationFilePath) {
                            try FileManager.default.removeItem(atPath: destinationFilePath)
                        }
                        try FileManager.default.copyItem(at: location, to: NSURL.fileURL(withPath: destinationFilePath))
                    } catch {
                        print(error)
                    }
                }
            }
        }
    }

    func downloadProgress(_ progress: Float,
                          totalBytes: Int64,
                          totalBytesExpected: Int64,
                          fileName: String,
                          serverUrl: String,
                          session: URLSession,
                          task: URLSessionTask) {

        Task {
            guard await progressQuantizer.shouldEmit(serverUrlFileName: serverUrl + "/" + fileName, fraction: Double(progress)) else {
                return
            }

            await self.transferDispatcher.notifyAllDelegates { delegate in
                delegate.transferProgressDidUpdate(progress: progress,
                                                   totalBytes: totalBytes,
                                                   totalBytesExpected: totalBytesExpected,
                                                   fileName: fileName,
                                                   serverUrl: serverUrl)
            }
        }
    }
}
