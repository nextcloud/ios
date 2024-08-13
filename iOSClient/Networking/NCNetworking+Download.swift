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
import JGProgressHUD
import NextcloudKit
import Alamofire
import Queuer

extension NCNetworking {
    func download(metadata: tableMetadata,
                  withNotificationProgressTask: Bool,
                  start: @escaping () -> Void = { },
                  requestHandler: @escaping (_ request: DownloadRequest) -> Void = { _ in },
                  progressHandler: @escaping (_ progress: Progress) -> Void = { _ in },
                  completion: @escaping (_ afError: AFError?, _ error: NKError) -> Void = { _, _ in }) {
        if metadata.session == NextcloudKit.shared.nkCommonInstance.sessionIdentifierDownload {
            downloadFile(metadata: metadata, withNotificationProgressTask: withNotificationProgressTask) {
                start()
            } requestHandler: { request in
                requestHandler(request)
            } progressHandler: { progress in
                progressHandler(progress)
            } completion: { afError, error in
                completion(afError, error)
            }
        } else {
            downloadFileInBackground(metadata: metadata, start: start, completion: { afError, error in
                completion(afError, error)
            })
        }
    }

    private func downloadFile(metadata: tableMetadata,
                              withNotificationProgressTask: Bool,
                              start: @escaping () -> Void = { },
                              requestHandler: @escaping (_ request: DownloadRequest) -> Void = { _ in },
                              progressHandler: @escaping (_ progress: Progress) -> Void = { _ in },
                              completion: @escaping (_ afError: AFError?, _ error: NKError) -> Void = { _, _ in }) {
        guard !metadata.isInTransfer else { return completion(nil, NKError()) }
        var downloadTask: URLSessionTask?
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)
        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        if NCManageDatabase.shared.getMetadataFromOcId(metadata.ocId) == nil {
            NCManageDatabase.shared.addMetadata(metadata)
        }

        NextcloudKit.shared.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, account: metadata.account, options: options, requestHandler: { request in
            self.downloadRequest[fileNameLocalPath] = request
            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                       status: NCGlobal.shared.metadataStatusDownloading)
            requestHandler(request)
        }, taskHandler: { task in
            downloadTask = task
            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                       taskIdentifier: task.taskIdentifier)
            NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadStartFile),
                                            object: nil,
                                            userInfo: ["ocId": metadata.ocId,
                                                       "serverUrl": metadata.serverUrl,
                                                       "account": metadata.account])
            start()
        }, progressHandler: { progress in
            NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterProgressTask),
                                            object: nil,
                                            userInfo: ["account": metadata.account,
                                                       "ocId": metadata.ocId,
                                                       "fileName": metadata.fileName,
                                                       "serverUrl": metadata.serverUrl,
                                                       "status": NSNumber(value: NCGlobal.shared.metadataStatusDownloading),
                                                       "progress": NSNumber(value: progress.fractionCompleted),
                                                       "totalBytes": NSNumber(value: progress.totalUnitCount),
                                                       "totalBytesExpected": NSNumber(value: progress.completedUnitCount)])
            progressHandler(progress)
        }) { _, etag, date, length, allHeaderFields, afError, error in
            var error = error
            var dateLastModified: Date?

            self.downloadRequest.removeValue(forKey: fileNameLocalPath)
            // this delay was added because for small file the "taskHandler: { task" is not called, so this part of code is not executed
            NextcloudKit.shared.nkCommonInstance.backgroundQueue.asyncAfter(deadline: .now() + 0.5) {
                if let downloadTask = downloadTask {
                    if let header = allHeaderFields, let dateString = header["Last-Modified"] as? String {
                        dateLastModified = NextcloudKit.shared.nkCommonInstance.convertDate(dateString, format: "EEE, dd MMM y HH:mm:ss zzz")
                    }
                    if afError?.isExplicitlyCancelledError ?? false {
                        error = NKError(errorCode: NCGlobal.shared.errorRequestExplicityCancelled, errorDescription: "error request explicity cancelled")
                    }
                    self.downloadComplete(fileName: metadata.fileName, serverUrl: metadata.serverUrl, etag: etag, date: date, dateLastModified: dateLastModified, length: length, task: downloadTask, error: error)
                }
                completion(afError, error)
            }
        }
    }

    private func downloadFileInBackground(metadata: tableMetadata,
                                          start: @escaping () -> Void = { },
                                          requestHandler: @escaping (_ request: DownloadRequest) -> Void = { _ in },
                                          progressHandler: @escaping (_ progress: Progress) -> Void = { _ in },
                                          completion: @escaping (_ afError: AFError?, _ error: NKError) -> Void = { _, _ in }) {
        let session: URLSession = sessionManagerDownloadBackground
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)

        start()

        if let task = nkBackground.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, account: metadata.account, session: session) {
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Download file \(metadata.fileNameView) with task with taskIdentifier \(task.taskIdentifier)")
            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                       status: NCGlobal.shared.metadataStatusDownloading,
                                                       taskIdentifier: task.taskIdentifier)
            NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadStartFile),
                                            object: nil,
                                            userInfo: ["ocId": metadata.ocId,
                                                       "serverUrl": metadata.serverUrl,
                                                       "account": metadata.account])
            completion(nil, NKError())
        } else {
            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                       session: "",
                                                       sessionError: "",
                                                       selector: "",
                                                       status: NCGlobal.shared.metadataStatusNormal)
            completion(nil, NKError(errorCode: NCGlobal.shared.errorResourceNotFound, errorDescription: "task null"))
        }
    }

    func downloadingFinish(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let httpResponse = (downloadTask.response as? HTTPURLResponse) {
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300,
               let url = downloadTask.currentRequest?.url,
               var serverUrl = url.deletingLastPathComponent().absoluteString.removingPercentEncoding {
                let fileName = url.lastPathComponent
                if serverUrl.hasSuffix("/") { serverUrl = String(serverUrl.dropLast()) }
                if let metadata = NCManageDatabase.shared.getResultMetadata(predicate: NSPredicate(format: "serverUrl == %@ AND fileName == %@", serverUrl, fileName)) {
                    let destinationFilePath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)
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
        if let delegate {
            return delegate.downloadComplete(fileName: fileName, serverUrl: serverUrl, etag: etag, date: date, dateLastModified: dateLastModified, length: length, task: task, error: error)
        }

        DispatchQueue.global(qos: .userInteractive).async {
            guard let url = task.currentRequest?.url,
                  let metadata = NCManageDatabase.shared.getMetadata(from: url, sessionTaskIdentifier: task.taskIdentifier) else { return }

            self.downloadMetadataInBackground.removeValue(forKey: FileNameServerUrl(fileName: fileName, serverUrl: serverUrl))

            if error == .success {
                self.removeTransferInError(ocId: metadata.ocId)
#if !EXTENSION
                if let result = NCManageDatabase.shared.getE2eEncryption(predicate: NSPredicate(format: "fileNameIdentifier == %@ AND serverUrl == %@", metadata.fileName, metadata.serverUrl)) {
                    NCEndToEndEncryption.shared().decryptFile(metadata.fileName, fileNameView: metadata.fileNameView, ocId: metadata.ocId, key: result.key, initializationVector: result.initializationVector, authenticationTag: result.authenticationTag)
                }
#endif
                NCManageDatabase.shared.addLocalFile(metadata: metadata)
                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                           session: "",
                                                           sessionError: "",
                                                           status: NCGlobal.shared.metadataStatusNormal,
                                                           etag: etag)
                NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile),
                                                object: nil,
                                                userInfo: ["ocId": metadata.ocId,
                                                           "serverUrl": metadata.serverUrl,
                                                           "account": metadata.account,
                                                           "selector": metadata.sessionSelector,
                                                           "error": error])
            } else if error.errorCode == NSURLErrorCancelled || error.errorCode == NCGlobal.shared.errorRequestExplicityCancelled {
                self.removeTransferInError(ocId: metadata.ocId)
                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                           session: "",
                                                           sessionError: "",
                                                           selector: "",
                                                           status: NCGlobal.shared.metadataStatusNormal)
                NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadCancelFile),
                                                object: nil,
                                                userInfo: ["ocId": metadata.ocId,
                                                           "serverUrl": metadata.serverUrl,
                                                           "account": metadata.account])
            } else {
                self.transferInError(ocId: metadata.ocId)
                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                           session: "",
                                                           sessionError: "",
                                                           selector: "",
                                                           status: NCGlobal.shared.metadataStatusNormal)
                NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile),
                                                object: nil,
                                                userInfo: ["ocId": metadata.ocId,
                                                           "serverUrl": metadata.serverUrl,
                                                           "account": metadata.account,
                                                           "selector": metadata.sessionSelector,
                                                           "error": error])
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
        if let delegate {
            return delegate.downloadProgress(progress, totalBytes: totalBytes, totalBytesExpected: totalBytesExpected, fileName: fileName, serverUrl: serverUrl, session: session, task: task)
        }

        DispatchQueue.global(qos: .userInteractive).async {
            var metadata: tableMetadata?

            if let metadataTmp = self.downloadMetadataInBackground[FileNameServerUrl(fileName: fileName, serverUrl: serverUrl)] {
                metadata = metadataTmp
            } else if let metadataTmp = NCManageDatabase.shared.getMetadataFromFileName(fileName, serverUrl: serverUrl) {
                self.downloadMetadataInBackground[FileNameServerUrl(fileName: fileName, serverUrl: serverUrl)] = metadataTmp
                metadata = metadataTmp
            }

            if let metadata {
                NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterProgressTask),
                                                object: nil,
                                                userInfo: ["account": metadata.account,
                                                           "ocId": metadata.ocId,
                                                           "fileName": metadata.fileName,
                                                           "serverUrl": metadata.serverUrl,
                                                           "status": NSNumber(value: NCGlobal.shared.metadataStatusDownloading),
                                                           "progress": NSNumber(value: progress),
                                                           "totalBytes": NSNumber(value: totalBytes),
                                                           "totalBytesExpected": NSNumber(value: totalBytesExpected)])
            }
        }
    }

#if !EXTENSION
    func downloadAvatar(user: String,
                        dispalyName: String?,
                        fileName: String,
                        cell: NCCellProtocol,
                        view: UIView?) {
        let fileNameLocalPath = utilityFileSystem.directoryUserData + "/" + fileName
        guard let tableAccount = NCManageDatabase.shared.getActiveAccount() else { return }

        if let image = NCManageDatabase.shared.getImageAvatarLoaded(fileName: fileName) {
            cell.fileAvatarImageView?.image = image
            return
        }

        cell.fileAvatarImageView?.image = utility.loadUserImage(for: user, displayName: dispalyName, userBaseUrl: tableAccount)

        for case let operation as NCOperationDownloadAvatar in downloadAvatarQueue.operations where operation.fileName == fileName { return }
        downloadAvatarQueue.addOperation(NCOperationDownloadAvatar(user: user, fileName: fileName, fileNameLocalPath: fileNameLocalPath, account: tableAccount.account, cell: cell, view: view))
    }
#endif

    func cancelDownloadTasks() {
        downloadRequest.removeAll()
        let sessionManager = NextcloudKit.shared.sessionManager
        sessionManager.session.getTasksWithCompletionHandler { _, _, downloadTasks in
            downloadTasks.forEach {
                $0.cancel()
            }
        }
        if let results = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "status < 0 AND session == %@", NextcloudKit.shared.nkCommonInstance.sessionIdentifierDownload)) {
            NCManageDatabase.shared.clearMetadataSession(metadatas: results)
        }
    }

    func cancelDownloadBackgroundTask() {
        Task {
            let tasksBackground = await NCNetworking.shared.sessionManagerDownloadBackground.tasks
            for task in tasksBackground.2 { // ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask])
                task.cancel()
            }
            if let results = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "status < 0 AND session == %@", NCNetworking.shared.sessionDownloadBackground)) {
                NCManageDatabase.shared.clearMetadataSession(metadatas: results)
            }
        }
    }
}

class NCOperationDownload: ConcurrentOperation {
    var metadata: tableMetadata
    var selector: String

    init(metadata: tableMetadata, selector: String) {
        self.metadata = tableMetadata.init(value: metadata)
        self.selector = selector
    }

    override func start() {
        guard !isCancelled else { return self.finish() }

        metadata.session = NextcloudKit.shared.nkCommonInstance.sessionIdentifierDownload
        metadata.sessionError = ""
        metadata.sessionSelector = selector
        metadata.sessionTaskIdentifier = 0
        metadata.status = NCGlobal.shared.metadataStatusWaitDownload

        NCManageDatabase.shared.addMetadata(metadata)

        NCNetworking.shared.download(metadata: metadata, withNotificationProgressTask: true) {
        } completion: { _, _ in
            self.finish()
        }
    }
}
