//
//  NCNetworking+Download.swift
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
import RealmSwift

extension NCNetworking {

    // MARK: - Download file in foreground

    @discardableResult
    func downloadFile(metadata: tableMetadata,
                      withDownloadComplete: Bool = true,
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
        var downloadTask: URLSessionTask?

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
                if let metadata = await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                              sessionTaskIdentifier: task.taskIdentifier,
                                                                              status: self.global.metadataStatusDownloading) {

                    self.notifyAllDelegates { delegate in
                        delegate.transferChange(status: self.global.networkingStatusDownloading,
                                                metadata: metadata,
                                                error: .success)
                    }
                }
            }
            taskHandler(task)
            downloadTask = task
        } progressHandler: { progress in
            Task {
                await self.database.setMetadataProgress(ocId: metadata.ocId, progress: progress.fractionCompleted)
            }
            self.notifyAllDelegates { delegate in
                delegate.transferProgressDidUpdate(progress: Float(progress.fractionCompleted),
                                                   totalBytes: progress.totalUnitCount,
                                                   totalBytesExpected: progress.completedUnitCount,
                                                   fileName: metadata.fileName,
                                                   serverUrl: metadata.serverUrl)
            }
            progressHandler(progress)
        }

        if withDownloadComplete {
            var error = NKError()
            var dateLastModified: Date?

            if let downloadTask,
               let headers = results.headers {
                if let dateString = headers["Last-Modified"] as? String {
                    dateLastModified = NKLogFileManager.shared.convertDate(dateString, format: "EEE, dd MMM y HH:mm:ss zzz")
                }
                if results.afError?.isExplicitlyCancelledError ?? false {
                    error = NKError(errorCode: self.global.errorRequestExplicityCancelled, errorDescription: "error request explicity cancelled")
                }
                self.downloadComplete(fileName: metadata.fileName, serverUrl: metadata.serverUrl, etag: results.etag, date: results.date, dateLastModified: dateLastModified, length: results.length, task: downloadTask, error: error)
            }
        }

        return results
    }

    // MARK: - Download file in background

    @discardableResult
    func downloadFileInBackground(metadata: tableMetadata,
                                  taskHandler: @escaping (_ task: URLSessionDownloadTask?) -> Void = { _ in },
                                  start: @escaping () -> Void = { })
    async -> NKError {

        let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileName: metadata.fileNameView, userId: metadata.userId, urlBase: metadata.urlBase)

        start()

        let (task, error) = await backgroundSession.downloadAsync(serverUrlFileName: metadata.serverUrlFileName,
                                                                  fileNameLocalPath: fileNameLocalPath,
                                                                  account: metadata.account,
                                                                  sessionIdentifier: sessionDownloadBackground)

        taskHandler(task)

        if let task, error == .success {
            nkLog(debug: " Download file \(metadata.fileNameView) with task with taskIdentifier \(task.taskIdentifier)")

            if let metadata = await database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                     sessionTaskIdentifier: task.taskIdentifier,
                                                                     status: self.global.metadataStatusDownloading) {

                self.notifyAllDelegates { delegate in
                    delegate.transferChange(status: self.global.networkingStatusDownloading,
                                            metadata: metadata,
                                            error: .success)
                }
            }
        } else {
            _ = await database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                       session: "",
                                                       sessionTaskIdentifier: 0,
                                                       sessionError: "",
                                                       selector: "",
                                                       status: self.global.metadataStatusNormal)
        }

        return(error)
    }

    // MARK: - Download NextcloudKitDelegate

    func downloadingFinish(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let httpResponse = (downloadTask.response as? HTTPURLResponse) {
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300,
               let url = downloadTask.currentRequest?.url,
               var serverUrl = url.deletingLastPathComponent().absoluteString.removingPercentEncoding {
                let fileName = url.lastPathComponent
                if serverUrl.hasSuffix("/") { serverUrl = String(serverUrl.dropLast()) }
                if let metadata = database.getMetadata(predicate: NSPredicate(format: "serverUrl == %@ AND fileName == %@", serverUrl, fileName)) {
                    let destinationFilePath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileName: metadata.fileName, userId: metadata.userId, urlBase: metadata.urlBase)
                    utilityFileSystem.copyFile(at: location, to: NSURL.fileURL(withPath: destinationFilePath))
                }
            }
        }
    }

    func downloadComplete(fileName: String,
                          serverUrl: String,
                          etag: String?,
                          date: Date?,
                          dateLastModified: Date?,
                          length: Int64,
                          task: URLSessionTask,
                          error: NKError) {
        Task {
            guard let url = task.currentRequest?.url,
                  let metadata = await self.database.getMetadataAsync(from: url, sessionTaskIdentifier: task.taskIdentifier) else {
                return
            }

            await NextcloudKit.shared.nkCommonInstance.appendServerErrorAccount(metadata.account, errorCode: error.errorCode)

            #if EXTENSION_FILE_PROVIDER_EXTENSION
            await FileProviderData.shared.downloadComplete(metadata: metadata, task: task, etag: etag, error: error)
            return
            #endif

            if error == .success {
                nkLog(success: "Downloaded file: " + metadata.serverUrlFileName)
                #if !EXTENSION
                if let result = await self.database.getE2eEncryptionAsync(predicate: NSPredicate(format: "fileNameIdentifier == %@ AND serverUrl == %@", metadata.fileName, metadata.serverUrl)) {
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
                await self.database.addLocalFileAsync(metadata: metadata)

                if let updatedMetadata = await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                                     session: "",
                                                                                     sessionTaskIdentifier: 0,
                                                                                     sessionError: "",
                                                                                     status: self.global.metadataStatusNormal,
                                                                                     etag: etag) {
                    self.notifyAllDelegates { delegate in
                        delegate.transferChange(status: self.global.networkingStatusDownloaded,
                                                metadata: updatedMetadata,
                                                error: error)
                    }
                }
            } else {
                nkLog(error: "Downloaded file: " + metadata.serverUrlFileName + ", result: error \(error.errorCode)")

                if error.errorCode == NCGlobal.shared.errorResourceNotFound {
                    self.utilityFileSystem.removeFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase))

                    await self.database.deleteLocalFileOcIdAsync(metadata.ocId)
                    await self.database.deleteMetadataOcIdAsync(metadata.ocId)
                } else if error.errorCode == NSURLErrorCancelled || error.errorCode == self.global.errorRequestExplicityCancelled {
                    if let metadata = await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                                  session: "",
                                                                                  sessionTaskIdentifier: 0,
                                                                                  sessionError: "",
                                                                                  selector: "",
                                                                                  status: self.global.metadataStatusNormal) {
                            self.notifyAllDelegates { delegate in
                                delegate.transferChange(status: self.global.networkingStatusDownloadCancel,
                                                        metadata: metadata,
                                                        error: .success)
                            }
                    }
                } else {
                    if let metadata = await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                                  session: "",
                                                                                  sessionTaskIdentifier: 0,
                                                                                  sessionError: "",
                                                                                  selector: "",
                                                                                  status: self.global.metadataStatusNormal) {

                        self.notifyAllDelegates { delegate in
                            delegate.transferChange(status: NCGlobal.shared.networkingStatusDownloaded,
                                                    metadata: metadata,
                                                    error: error)
                        }
                    }
                }
                await self.database.updateBadge()
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
            await self.database.setMetadataProgress(fileName: fileName, serverUrl: serverUrl, taskIdentifier: task.taskIdentifier, progress: Double(progress))
        }
        notifyAllDelegates { delegate in
            delegate.transferProgressDidUpdate(progress: progress,
                                               totalBytes: totalBytes,
                                               totalBytesExpected: totalBytesExpected,
                                               fileName: fileName,
                                               serverUrl: serverUrl)
        }
    }
}
