//
//  NCNetworking+Upload.swift
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

extension NCNetworking {
    func upload(metadata: tableMetadata,
                uploadE2EEDelegate: uploadE2EEDelegate? = nil,
                hudView: UIView?,
                hud: JGProgressHUD?,
                start: @escaping () -> Void = { },
                requestHandler: @escaping (_ request: UploadRequest) -> Void = { _ in },
                progressHandler: @escaping (_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double) -> Void = { _, _, _ in },
                completion: @escaping (_ afError: AFError?, _ error: NKError) -> Void = { _, _ in }) {
        let metadata = tableMetadata.init(value: metadata)
        var numChunks: Int = 0
        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Upload file \(metadata.fileNameView) with Identifier \(metadata.assetLocalIdentifier) with size \(metadata.size) [CHUNK \(metadata.chunk), E2EE \(metadata.isDirectoryE2EE)]")

        if metadata.isDirectoryE2EE {
#if !EXTENSION_FILE_PROVIDER_EXTENSION && !EXTENSION_WIDGET
            Task {
                let error = await NCNetworkingE2EEUpload().upload(metadata: metadata, uploadE2EEDelegate: uploadE2EEDelegate, hudView: hudView, hud: hud)
                completion(nil, error)
            }
#endif
        } else if metadata.chunk > 0 {
                if let hudView {
                    DispatchQueue.main.async {
                        if let hud {
                            hud.indicatorView = JGProgressHUDRingIndicatorView()
                            if let indicatorView = hud.indicatorView as? JGProgressHUDRingIndicatorView {
                                indicatorView.ringWidth = 1.5
                                indicatorView.ringColor = NCBrandColor.shared.brandElement
                            }
                            hud.tapOnHUDViewBlock = { _ in
                                NotificationCenter.default.postOnMainThread(name: "NextcloudKit.chunkedFile.stop")
                            }
                            hud.textLabel.text = NSLocalizedString("_wait_file_preparation_", comment: "")
                            hud.detailTextLabel.text = NSLocalizedString("_tap_to_cancel_", comment: "")
                            hud.detailTextLabel.textColor = NCBrandColor.shared.iconImageColor2
                            hud.show(in: hudView)
                        }
                    }
                }
            uploadChunkFile(metadata: metadata) { num in
                numChunks = num
            } counterChunk: { counter in
                DispatchQueue.main.async { hud?.progress = Float(counter) / Float(numChunks) }
            } start: {
                DispatchQueue.main.async { hud?.dismiss() }
            } completion: { account, _, afError, error in
                DispatchQueue.main.async { hud?.dismiss() }
                var sessionTaskFailedCode = 0
                let directory = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId)
                if let error = NextcloudKit.shared.nkCommonInstance.getSessionErrorFromAFError(afError) {
                    sessionTaskFailedCode = error.code
                }
                switch error.errorCode {
                case NKError.chunkNoEnoughMemory, NKError.chunkCreateFolder, NKError.chunkFilesNull, NKError.chunkFileNull:
                    NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                    NCManageDatabase.shared.deleteChunks(account: account, ocId: metadata.ocId, directory: directory)
                    NCContentPresenter().messageNotification("_error_files_upload_", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .error, afterDelay: 0.5)
                case NKError.chunkFileUpload:
                    if let afError, (afError.isExplicitlyCancelledError || sessionTaskFailedCode == NCGlobal.shared.errorExplicitlyCancelled ) {
                        NCManageDatabase.shared.deleteChunks(account: account, ocId: metadata.ocId, directory: directory)
                    }
                case NKError.chunkMoveFile:
                    NCManageDatabase.shared.deleteChunks(account: account, ocId: metadata.ocId, directory: directory)
                    NCContentPresenter().messageNotification("_chunk_move_", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .error, afterDelay: 0.5)
                default: break
                }
                completion(afError, error)
            }
        } else if metadata.session == NextcloudKit.shared.nkCommonInstance.sessionIdentifierUpload {
            let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)
            uploadFile(metadata: metadata, fileNameLocalPath: fileNameLocalPath, start: start, progressHandler: progressHandler) { _, _, _, _, _, _, afError, error in
                completion(afError, error)
            }
        } else {
            uploadFileInBackground(metadata: metadata, start: start) { error in
                completion(nil, error)
            }
        }
    }

    func uploadFile(metadata: tableMetadata,
                    fileNameLocalPath: String,
                    withUploadComplete: Bool = true,
                    customHeaders: [String: String]? = nil,
                    start: @escaping () -> Void = { },
                    requestHandler: @escaping (_ request: UploadRequest) -> Void = { _ in },
                    progressHandler: @escaping (_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double) -> Void = { _, _, _ in },
                    completion: @escaping (_ account: String, _ ocId: String?, _ etag: String?, _ date: Date?, _ size: Int64, _ allHeaderFields: [AnyHashable: Any]?, _ afError: AFError?, _ error: NKError) -> Void) {
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let options = NKRequestOptions(customHeader: customHeaders, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        NextcloudKit.shared.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, dateCreationFile: metadata.creationDate as Date, dateModificationFile: metadata.date as Date, account: metadata.account, options: options, requestHandler: { request in

            self.uploadRequest[fileNameLocalPath] = request
            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                       status: NCGlobal.shared.metadataStatusUploading)
            requestHandler(request)
        }, taskHandler: { task in
            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                       taskIdentifier: task.taskIdentifier)

            NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterUploadStartFile),
                                            object: nil,
                                            userInfo: ["ocId": metadata.ocId,
                                                       "serverUrl": metadata.serverUrl,
                                                       "account": metadata.account,
                                                       "fileName": metadata.fileName,
                                                       "sessionSelector": metadata.sessionSelector])
            start()
        }, progressHandler: { progress in
            NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterProgressTask),
                                            object: nil,
                                            userInfo: ["account": metadata.account,
                                                       "ocId": metadata.ocId,
                                                       "fileName": metadata.fileName,
                                                       "serverUrl": metadata.serverUrl,
                                                       "status": NSNumber(value: NCGlobal.shared.metadataStatusUploading),
                                                       "progress": NSNumber(value: progress.fractionCompleted),
                                                       "totalBytes": NSNumber(value: progress.totalUnitCount),
                                                       "totalBytesExpected": NSNumber(value: progress.completedUnitCount)])
            progressHandler(progress.completedUnitCount, progress.totalUnitCount, progress.fractionCompleted)
        }) { account, ocId, etag, date, size, allHeaderFields, afError, error in
            var error = error
            self.uploadRequest.removeValue(forKey: fileNameLocalPath)
            if withUploadComplete {
                if afError?.isExplicitlyCancelledError ?? false {
                    error = NKError(errorCode: NCGlobal.shared.errorRequestExplicityCancelled, errorDescription: "error request explicity cancelled")
                }
                self.uploadComplete(metadata: metadata, ocId: ocId, etag: etag, date: date, size: size, error: error)
            }
            completion(account, ocId, etag, date, size, allHeaderFields, afError, error)
        }
    }

    func uploadChunkFile(metadata: tableMetadata,
                         withUploadComplete: Bool = true,
                         customHeaders: [String: String]? = nil,
                         numChunks: @escaping (_ num: Int) -> Void = { _ in },
                         counterChunk: @escaping (_ counter: Int) -> Void = { _ in },
                         start: @escaping () -> Void = { },
                         progressHandler: @escaping (_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double) -> Void = { _, _, _ in },
                         completion: @escaping (_ account: String, _ file: NKFile?, _ afError: AFError?, _ error: NKError) -> Void) {
        let directory = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId)
        let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)
        let chunkFolder = NCManageDatabase.shared.getChunkFolder(account: metadata.account, ocId: metadata.ocId)
        let filesChunk = NCManageDatabase.shared.getChunks(account: metadata.account, ocId: metadata.ocId)
        var chunkSize = NCGlobal.shared.chunkSizeMBCellular
        if NCNetworking.shared.networkReachability == NKCommon.TypeReachability.reachableEthernetOrWiFi {
            chunkSize = NCGlobal.shared.chunkSizeMBEthernetOrWiFi
        }
        let options = NKRequestOptions(customHeader: customHeaders, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        NextcloudKit.shared.uploadChunk(directory: directory, fileName: metadata.fileName, date: metadata.date as Date, creationDate: metadata.creationDate as Date, serverUrl: metadata.serverUrl, chunkFolder: chunkFolder, filesChunk: filesChunk, chunkSize: chunkSize, account: metadata.account, options: options) { num in
            numChunks(num)
        } counterChunk: { counter in
            counterChunk(counter)
        } start: { filesChunk in
            start()
            NCManageDatabase.shared.addChunks(account: metadata.account, ocId: metadata.ocId, chunkFolder: chunkFolder, filesChunk: filesChunk)
            NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterUploadStartFile),
                                            object: nil,
                                            userInfo: ["ocId": metadata.ocId,
                                                       "serverUrl": metadata.serverUrl,
                                                       "account": metadata.account,
                                                       "fileName": metadata.fileName,
                                                       "sessionSelector": metadata.sessionSelector])
        } requestHandler: { request in
            self.uploadRequest[fileNameLocalPath] = request
            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                       status: NCGlobal.shared.metadataStatusUploading)
        } taskHandler: { task in
            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                       taskIdentifier: task.taskIdentifier)
        } progressHandler: { totalBytesExpected, totalBytes, fractionCompleted in
            NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterProgressTask),
                                            object: nil,
                                            userInfo: ["account": metadata.account,
                                                       "ocId": metadata.ocId,
                                                       "fileName": metadata.fileName,
                                                       "serverUrl": metadata.serverUrl,
                                                       "status": NSNumber(value: NCGlobal.shared.metadataStatusUploading),
                                                       "chunk": metadata.chunk,
                                                       "e2eEncrypted": metadata.e2eEncrypted,
                                                       "progress": NSNumber(value: fractionCompleted),
                                                       "totalBytes": NSNumber(value: totalBytes),
                                                       "totalBytesExpected": NSNumber(value: totalBytesExpected)])

            progressHandler(totalBytesExpected, totalBytes, fractionCompleted)
        } uploaded: { fileChunk in
            NCManageDatabase.shared.deleteChunk(account: metadata.account, ocId: metadata.ocId, fileChunk: fileChunk, directory: directory)
        } completion: { account, _, file, afError, error in
            self.uploadRequest.removeValue(forKey: fileNameLocalPath)
            if error == .success {
                NCManageDatabase.shared.deleteChunks(account: account, ocId: metadata.ocId, directory: directory)
            }
            if withUploadComplete {
                self.uploadComplete(metadata: metadata, ocId: file?.ocId, etag: file?.etag, date: file?.date, size: file?.size ?? 0, error: error)
            }
            completion(account, file, afError, error)
        }
    }

    private func uploadFileInBackground(metadata: tableMetadata,
                                        start: @escaping () -> Void = { },
                                        completion: @escaping (_ error: NKError) -> Void) {
        var session: URLSession?
        let metadata = tableMetadata.init(value: metadata)
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)

        if metadata.session == sessionUploadBackground || metadata.session == sessionUploadBackgroundExtension {
            session = sessionManagerUploadBackground
        } else if metadata.session == sessionUploadBackgroundWWan {
            session = sessionManagerUploadBackgroundWWan
        }

        start()

        // Check file dim > 0
        if utilityFileSystem.getFileSize(filePath: fileNameLocalPath) == 0 && metadata.size != 0 {
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            completion(NKError(errorCode: NCGlobal.shared.errorResourceNotFound, errorDescription: NSLocalizedString("_error_not_found_", value: "The requested resource could not be found", comment: "")))
        } else {
            if let task = nkBackground.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, dateCreationFile: metadata.creationDate as Date, dateModificationFile: metadata.date as Date, account: metadata.account, session: session!) {

                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Upload file \(metadata.fileNameView) with task with taskIdentifier \(task.taskIdentifier)")
                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                           status: NCGlobal.shared.metadataStatusUploading,
                                                           taskIdentifier: task.taskIdentifier)
                NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterUploadStartFile),
                                                object: nil,
                                                userInfo: ["ocId": metadata.ocId,
                                                           "serverUrl": metadata.serverUrl,
                                                           "account": metadata.account,
                                                           "fileName": metadata.fileName,
                                                           "sessionSelector": metadata.sessionSelector])
                completion(NKError())
            } else {
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                completion(NKError(errorCode: NCGlobal.shared.errorResourceNotFound, errorDescription: "task null"))
            }
        }
    }

    func uploadComplete(fileName: String,
                        serverUrl: String,
                        ocId: String?,
                        etag: String?,
                        date: Date?,
                        size: Int64,
                        task: URLSessionTask,
                        error: NKError) {
        if let delegate {
            return delegate.uploadComplete(fileName: fileName, serverUrl: serverUrl, ocId: ocId, etag: etag, date: date, size: size, task: task, error: error)
        }

        guard let url = task.currentRequest?.url,
              let metadata = NCManageDatabase.shared.getMetadata(from: url, sessionTaskIdentifier: task.taskIdentifier) else { return }
        uploadComplete(metadata: metadata, ocId: ocId, etag: etag, date: date, size: size, error: error)
    }

    func uploadComplete(metadata: tableMetadata,
                        ocId: String?,
                        etag: String?,
                        date: Date?,
                        size: Int64,
                        error: NKError) {
        DispatchQueue.main.async {
            var isApplicationStateActive = false
#if !EXTENSION
            isApplicationStateActive = UIApplication.shared.applicationState == .active
#endif
            DispatchQueue.global(qos: .userInteractive).async {
                let ocIdTemp = metadata.ocId
                let selector = metadata.sessionSelector

                self.uploadMetadataInBackground.removeValue(forKey: FileNameServerUrl(fileName: metadata.fileName, serverUrl: metadata.serverUrl))

                if error == .success, let ocId = ocId, size == metadata.size {
                    self.removeTransferInError(ocId: ocIdTemp)

                    let metadata = tableMetadata.init(value: metadata)
                    metadata.uploadDate = (date as? NSDate) ?? NSDate()
                    metadata.etag = etag ?? ""
                    metadata.ocId = ocId
                    metadata.chunk = 0

                    if let fileId = self.utility.ocIdToFileId(ocId: ocId) {
                        metadata.fileId = fileId
                    }

                    metadata.session = ""
                    metadata.sessionError = ""
                    metadata.status = NCGlobal.shared.metadataStatusNormal

                    NCManageDatabase.shared.addMetadata(metadata)
                    NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp))

                    if selector == NCGlobal.shared.selectorUploadFileNODelete {
                        self.utilityFileSystem.moveFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(ocIdTemp), toPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId))
                        NCManageDatabase.shared.addLocalFile(metadata: metadata)
                    } else {
                        self.utilityFileSystem.removeFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(ocIdTemp))
                    }

                    NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Upload complete " + metadata.serverUrl + "/" + metadata.fileName + ", result: success(\(size) bytes)")

                    let userInfo: [AnyHashable: Any] = ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": ocIdTemp, "error": error]
                    if metadata.isLivePhoto, NCGlobal.shared.isLivePhotoServerAvailable {
                        self.uploadLivePhoto(metadata: metadata, userInfo: userInfo)
                    } else {
                        NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile),
                                                        object: nil,
                                                        userInfo: userInfo)
                    }
                } else {
                    if error.errorCode == NSURLErrorCancelled || error.errorCode == NCGlobal.shared.errorRequestExplicityCancelled {
                        self.removeTransferInError(ocId: ocIdTemp)
                        self.utilityFileSystem.removeFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
                        NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                        NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterUploadCancelFile),
                                                        object: nil,
                                                        userInfo: ["ocId": metadata.ocId,
                                                                   "serverUrl": metadata.serverUrl,
                                                                   "account": metadata.account])
                    } else if error.errorCode == NCGlobal.shared.errorBadRequest || error.errorCode == NCGlobal.shared.errorUnsupportedMediaType {
                        self.removeTransferInError(ocId: ocIdTemp)
                        self.utilityFileSystem.removeFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
                        NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                        NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterUploadCancelFile),
                                                        object: nil,
                                                        userInfo: ["ocId": metadata.ocId,
                                                                   "serverUrl": metadata.serverUrl,
                                                                   "account": metadata.account])
                        if isApplicationStateActive {
                            NCContentPresenter().showError(error: NKError(errorCode: error.errorCode, errorDescription: "_virus_detect_"))
                        }

                        // Client Diagnostic
                        NCManageDatabase.shared.addDiagnostic(account: metadata.account, issue: NCGlobal.shared.diagnosticIssueVirusDetected)
                    } else if error.errorCode == NCGlobal.shared.errorForbidden && isApplicationStateActive {
                        self.removeTransferInError(ocId: ocIdTemp)
#if !EXTENSION
                        DispatchQueue.main.async {
                            let newFileName = self.utilityFileSystem.createFileName(metadata.fileName, serverUrl: metadata.serverUrl, account: metadata.account)
                            let alertController = UIAlertController(title: error.errorDescription, message: NSLocalizedString("_change_upload_filename_", comment: ""), preferredStyle: .alert)
                            alertController.addAction(UIAlertAction(title: String(format: NSLocalizedString("_save_file_as_", comment: ""), newFileName), style: .default, handler: { _ in
                                let atpath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + metadata.fileName
                                let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + newFileName
                                self.utilityFileSystem.moveFile(atPath: atpath, toPath: toPath)
                                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                                           newFileName: newFileName,
                                                                           sessionError: "",
                                                                           status: NCGlobal.shared.metadataStatusWaitUpload,
                                                                           errorCode: error.errorCode)
                            }))
                            alertController.addAction(UIAlertAction(title: NSLocalizedString("_discard_changes_", comment: ""), style: .destructive, handler: { _ in
                                self.utilityFileSystem.removeFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
                                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                                NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterUploadCancelFile),
                                                                object: nil,
                                                                userInfo: ["ocId": metadata.ocId,
                                                                           "serverUrl": metadata.serverUrl,
                                                                           "account": metadata.account])
                            }))

                            // Select UIWindowScene active in serverUrl
                            var controller = UIApplication.shared.firstWindow?.rootViewController
                            let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                            for windowScene in windowScenes {
                                if let rootViewController = windowScene.keyWindow?.rootViewController as? NCMainTabBarController,
                                   rootViewController.currentServerUrl() == metadata.serverUrl {
                                    controller = rootViewController
                                    break
                                }
                            }
                            controller?.present(alertController, animated: true)

                            // Client Diagnostic
                            NCManageDatabase.shared.addDiagnostic(account: metadata.account, issue: NCGlobal.shared.diagnosticIssueProblems, error: NCGlobal.shared.diagnosticProblemsForbidden)
                        }
#endif
                    } else {
                        self.transferInError(ocId: metadata.ocId)
                        NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                                   sessionError: error.errorDescription,
                                                                   status: NCGlobal.shared.metadataStatusUploadError,
                                                                   errorCode: error.errorCode)
                        NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile),
                                                        object: nil,
                                                        userInfo: ["ocId": metadata.ocId,
                                                                   "serverUrl": metadata.serverUrl,
                                                                   "account": metadata.account,
                                                                   "fileName": metadata.fileName,
                                                                   "ocIdTemp": ocIdTemp,
                                                                   "error": error])

                        // Client Diagnostic
                        if error.errorCode == NCGlobal.shared.errorInternalServerError {
                            NCManageDatabase.shared.addDiagnostic(account: metadata.account, issue: NCGlobal.shared.diagnosticIssueProblems, error: NCGlobal.shared.diagnosticProblemsBadResponse)
                        } else {
                            NCManageDatabase.shared.addDiagnostic(account: metadata.account, issue: NCGlobal.shared.diagnosticIssueProblems, error: NCGlobal.shared.diagnosticProblemsUploadServerError)
                        }
                    }
                }
            }
        }
    }

    func uploadProgress(_ progress: Float,
                        totalBytes: Int64,
                        totalBytesExpected: Int64,
                        fileName: String,
                        serverUrl: String,
                        session: URLSession,
                        task: URLSessionTask) {
        if let delegate {
            return delegate.uploadProgress(progress, totalBytes: totalBytes, totalBytesExpected: totalBytesExpected, fileName: fileName, serverUrl: serverUrl, session: session, task: task)
        }

        DispatchQueue.global(qos: .userInteractive).async {
            var metadata: tableMetadata?

            if let metadataTmp = self.uploadMetadataInBackground[FileNameServerUrl(fileName: fileName, serverUrl: serverUrl)] {
                metadata = metadataTmp
            } else if let metadataTmp = NCManageDatabase.shared.getMetadataFromFileName(fileName, serverUrl: serverUrl) {
                self.uploadMetadataInBackground[FileNameServerUrl(fileName: fileName, serverUrl: serverUrl)] = metadataTmp
                metadata = metadataTmp
            }

            if let metadata {
                NotificationCenter.default.post(name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterProgressTask),
                                                object: nil,
                                                userInfo: ["account": metadata.account,
                                                           "ocId": metadata.ocId,
                                                           "fileName": metadata.fileName,
                                                           "serverUrl": serverUrl,
                                                           "status": NSNumber(value: NCGlobal.shared.metadataStatusUploading),
                                                           "chunk": metadata.chunk,
                                                           "e2eEncrypted": metadata.e2eEncrypted,
                                                           "progress": NSNumber(value: progress),
                                                           "totalBytes": NSNumber(value: totalBytes),
                                                           "totalBytesExpected": NSNumber(value: totalBytesExpected)])
            }
        }
    }

    func getUploadBackgroundSession(queue: DispatchQueue = .main,
                                    completion: @escaping (_ filesNameLocalPath: [String]) -> Void) {
        var filesNameLocalPath: [String] = []

        sessionManagerUploadBackground.getAllTasks(completionHandler: { tasks in
            for task in tasks {
                filesNameLocalPath.append(task.description)
            }
            self.sessionManagerUploadBackgroundWWan.getAllTasks(completionHandler: { tasks in
                for task in tasks {
                    filesNameLocalPath.append(task.description)
                }
                queue.async { completion(filesNameLocalPath) }
            })
        })
    }

    func cancelUploadTasks() {
        uploadRequest.removeAll()
        let sessionManager = NextcloudKit.shared.sessionManager
        sessionManager.session.getTasksWithCompletionHandler { _, uploadTasks, _ in
            uploadTasks.forEach {
                $0.cancel()
            }
        }

        if let results = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "status > 0 AND session == %@", NextcloudKit.shared.nkCommonInstance.sessionIdentifierUpload)) {
            NCManageDatabase.shared.deleteMetadata(results: results)
        }
    }

    func cancelUploadBackgroundTask() {
        Task {
            let tasksBackground = await NCNetworking.shared.sessionManagerUploadBackground.tasks
            for task in tasksBackground.1 { // ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask])
                task.cancel()
            }
            let tasksBackgroundWWan = await NCNetworking.shared.sessionManagerUploadBackgroundWWan.tasks
            for task in tasksBackgroundWWan.1 { // ([URLSessionDataTask], [URLSessionUploadTask], [URLSessionDownloadTask])
                task.cancel()
            }
            if let results = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "status > 0 AND (session == %@ || session == %@)", NCNetworking.shared.sessionUploadBackground, NCNetworking.shared.sessionUploadBackgroundWWan)) {
                NCManageDatabase.shared.deleteMetadata(results: results)
            }
        }
    }
}
