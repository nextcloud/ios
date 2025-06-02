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
import NextcloudKit
import Alamofire

protocol UploadProgressDelegate: AnyObject {
    func uploadProgressDidUpdate(progress: Float,
                                 totalBytes: Int64,
                                 totalBytesExpected: Int64,
                                 fileName: String,
                                 serverUrl: String)
}

extension NCNetworking {
    func upload(metadata: tableMetadata,
                uploadE2EEDelegate: uploadE2EEDelegate? = nil,
                controller: UIViewController? = nil,
                start: @escaping () -> Void = { },
                requestHandler: @escaping (_ request: UploadRequest) -> Void = { _ in },
                progressHandler: @escaping (_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double) -> Void = { _, _, _ in },
                completion: @escaping (_ afError: AFError?, _ error: NKError) -> Void = { _, _ in }) {
        let metadata = tableMetadata.init(value: metadata)
        var numChunks: Int = 0
        var hud: NCHud?
        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Upload file \(metadata.fileNameView) with Identifier \(metadata.assetLocalIdentifier) with size \(metadata.size) [CHUNK \(metadata.chunk), E2EE \(metadata.isDirectoryE2EE)]")

        func tapOperation() {
            NotificationCenter.default.postOnMainThread(name: NextcloudKit.shared.nkCommonInstance.notificationCenterChunkedFileStop.rawValue)
        }

        if metadata.isDirectoryE2EE {
#if !EXTENSION_FILE_PROVIDER_EXTENSION && !EXTENSION_WIDGET
            Task {
                let error = await NCNetworkingE2EEUpload().upload(metadata: metadata, uploadE2EEDelegate: uploadE2EEDelegate, controller: controller)
                completion(nil, error)
            }
#endif
        } else if metadata.chunk > 0 {
            DispatchQueue.main.async {
                hud = NCHud(controller?.view)
                hud?.initHudRing(text: NSLocalizedString("_wait_file_preparation_", comment: ""),
                                 tapToCancelDetailText: true,
                                 tapOperation: tapOperation)
            }
            uploadChunkFile(metadata: metadata) { num in
                numChunks = num
            } counterChunk: { counter in
                hud?.progress(num: Float(counter), total: Float(numChunks))
            } start: {
                hud?.dismiss()
            } completion: { account, _, afError, error in
                hud?.dismiss()
                var sessionTaskFailedCode = 0
                let directory = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId)
                if let error = NextcloudKit.shared.nkCommonInstance.getSessionErrorFromAFError(afError) {
                    sessionTaskFailedCode = error.code
                }
                switch error.errorCode {
                case NKError.chunkNoEnoughMemory, NKError.chunkCreateFolder, NKError.chunkFilesNull, NKError.chunkFileNull:
                    self.database.deleteMetadataOcId(metadata.ocId)
                    self.database.deleteChunks(account: account, ocId: metadata.ocId, directory: directory)
                    NCContentPresenter().messageNotification("_error_files_upload_", error: error, delay: self.global.dismissAfterSecond, type: .error, afterDelay: 0.5)
                case NKError.chunkFileUpload:
                    if let afError, afError.isExplicitlyCancelledError || sessionTaskFailedCode == self.global.errorExplicitlyCancelled {
                        self.database.deleteChunks(account: account, ocId: metadata.ocId, directory: directory)
                    }
                case NKError.chunkMoveFile:
                    self.database.deleteChunks(account: account, ocId: metadata.ocId, directory: directory)
                    NCContentPresenter().messageNotification("_chunk_move_", error: error, delay: self.global.dismissAfterSecond, type: .error, afterDelay: 0.5)
                default: break
                }
                completion(afError, error)
            }
        } else if metadata.session == sessionUpload {
            let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)
            uploadFile(metadata: metadata,
                       fileNameLocalPath: fileNameLocalPath,
                       controller: controller,
                       start: start,
                       progressHandler: progressHandler) { _, _, _, _, _, _, afError, error in
                completion(afError, error)
            }
        } else {
            uploadFileInBackground(metadata: metadata, controller: controller, start: start) { error in
                completion(nil, error)
            }
        }
    }

    func uploadFile(metadata: tableMetadata,
                    fileNameLocalPath: String,
                    withUploadComplete: Bool = true,
                    customHeaders: [String: String]? = nil,
                    controller: UIViewController?,
                    start: @escaping () -> Void = { },
                    requestHandler: @escaping (_ request: UploadRequest) -> Void = { _ in },
                    progressHandler: @escaping (_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double) -> Void = { _, _, _ in },
                    completion: @escaping (_ account: String, _ ocId: String?, _ etag: String?, _ date: Date?, _ size: Int64, _ responseData: AFDataResponse<Data?>?, _ afError: AFError?, _ error: NKError) -> Void) {
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let options = NKRequestOptions(customHeader: customHeaders, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        NextcloudKit.shared.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, dateCreationFile: metadata.creationDate as Date, dateModificationFile: metadata.date as Date, account: metadata.account, options: options, requestHandler: { request in
            requestHandler(request)
        }, taskHandler: { task in
            let metadata = self.database.setMetadataSession(metadata: metadata,
                                                            sessionTaskIdentifier: task.taskIdentifier,
                                                            status: self.global.metadataStatusUploading)

            self.notifyAllDelegates { delegate in
                delegate.transferChange(status: self.global.networkingStatusUploading,
                                        metadata: metadata,
                                        error: .success)
            }

            start()
        }, progressHandler: { progress in
            self.notifyAllDelegates { delegate in
                delegate.transferProgressDidUpdate(progress: Float(progress.fractionCompleted),
                                                   totalBytes: progress.totalUnitCount,
                                                   totalBytesExpected: progress.completedUnitCount,
                                                   fileName: metadata.fileName,
                                                   serverUrl: metadata.serverUrl)
            }
            progressHandler(progress.completedUnitCount, progress.totalUnitCount, progress.fractionCompleted)
        }) { account, ocId, etag, date, size, responseData, afError, error in
            var error = error
            if withUploadComplete {
                if afError?.isExplicitlyCancelledError ?? false {
                    error = NKError(errorCode: self.global.errorRequestExplicityCancelled, errorDescription: "error request explicity cancelled")
                }
                self.uploadComplete(metadata: metadata, ocId: ocId, etag: etag, date: date, size: size, error: error)
            }
            completion(account, ocId, etag, date, size, responseData, afError, error)
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
        let chunkFolder = self.database.getChunkFolder(account: metadata.account, ocId: metadata.ocId)
        let filesChunk = self.database.getChunks(account: metadata.account, ocId: metadata.ocId)
        var chunkSize = self.global.chunkSizeMBCellular
        if networkReachability == NKCommon.TypeReachability.reachableEthernetOrWiFi {
            chunkSize = self.global.chunkSizeMBEthernetOrWiFi
        }
        let options = NKRequestOptions(customHeader: customHeaders, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        NextcloudKit.shared.uploadChunk(directory: directory, fileName: metadata.fileName, date: metadata.date as Date, creationDate: metadata.creationDate as Date, serverUrl: metadata.serverUrl, chunkFolder: chunkFolder, filesChunk: filesChunk, chunkSize: chunkSize, account: metadata.account, options: options) { num in
            numChunks(num)
        } counterChunk: { counter in
            counterChunk(counter)
        } start: { filesChunk in
            start()
            self.database.addChunks(account: metadata.account,
                                    ocId: metadata.ocId,
                                    chunkFolder: chunkFolder,
                                    filesChunk: filesChunk)
            self.notifyAllDelegates { delegate in
                delegate.transferChange(status: self.global.networkingStatusUploading,
                                        metadata: tableMetadata(value: metadata),
                                        error: .success)
            }
        } requestHandler: { _ in
        } taskHandler: { task in
            self.database.setMetadataSession(metadata: metadata,
                                             sessionTaskIdentifier: task.taskIdentifier,
                                             status: self.global.metadataStatusUploading)
        } progressHandler: { totalBytesExpected, totalBytes, fractionCompleted in
            self.notifyAllDelegates { delegate in
                delegate.transferProgressDidUpdate(progress: Float(fractionCompleted),
                                                   totalBytes: totalBytes,
                                                   totalBytesExpected: totalBytesExpected,
                                                   fileName: metadata.fileName,
                                                   serverUrl: metadata.serverUrl)
            }
            progressHandler(totalBytesExpected, totalBytes, fractionCompleted)
        } uploaded: { fileChunk in
            self.database.deleteChunk(account: metadata.account,
                                      ocId: metadata.ocId,
                                      fileChunk: fileChunk,
                                      directory: directory)
        } completion: { account, _, file, afError, error in
            if error == .success {
                self.database.deleteChunks(account: account,
                                           ocId: metadata.ocId,
                                           directory: directory)
            }
            if withUploadComplete {
                self.uploadComplete(metadata: metadata, ocId: file?.ocId, etag: file?.etag, date: file?.date, size: file?.size ?? 0, error: error)
            }
            completion(account, file, afError, error)
        }
    }

    private func uploadFileInBackground(metadata: tableMetadata,
                                        controller: UIViewController?,
                                        start: @escaping () -> Void = { },
                                        completion: @escaping (_ error: NKError) -> Void) {
        let metadata = tableMetadata.init(value: metadata)
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)

        start()

        // Check file dim > 0
        if utilityFileSystem.getFileSize(filePath: fileNameLocalPath) == 0 && metadata.size != 0 {
            self.database.deleteMetadataOcId(metadata.ocId, sync: false)
            completion(NKError(errorCode: self.global.errorResourceNotFound, errorDescription: NSLocalizedString("_error_not_found_", value: "The requested resource could not be found", comment: "")))
        } else {
            let (task, error) = NKBackground(nkCommonInstance: NextcloudKit.shared.nkCommonInstance).upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, dateCreationFile: metadata.creationDate as Date, dateModificationFile: metadata.date as Date, account: metadata.account, sessionIdentifier: metadata.session)
            if let task, error == .success {
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Upload file \(metadata.fileNameView) with task with taskIdentifier \(task.taskIdentifier)")
                let metadata = self.database.setMetadataSession(metadata: metadata,
                                                                sessionTaskIdentifier: task.taskIdentifier,
                                                                status: self.global.metadataStatusUploading)

                self.notifyAllDelegates { delegate in
                    delegate.transferChange(status: self.global.networkingStatusUploading,
                                            metadata: metadata,
                                            error: .success)
                }
            } else {
                self.database.deleteMetadataOcId(metadata.ocId, sync: false)
            }

            completion(error)
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
        isAppSuspending = false

#if EXTENSION_FILE_PROVIDER_EXTENSION

        guard let url = task.currentRequest?.url,
              let metadata = NCManageDatabase.shared.getMetadata(from: url, sessionTaskIdentifier: task.taskIdentifier) else { return }

        if let ocId, !metadata.ocIdTransfer.isEmpty {
            let atPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocIdTransfer)
            let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId)
            self.utilityFileSystem.copyFile(atPath: atPath, toPath: toPath)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if error == .success, let ocId {
                /// SIGNAL
                fileProviderData.shared.signalEnumerator(ocId: metadata.ocIdTransfer, type: .delete)
                if !metadata.ocIdTransfer.isEmpty, ocId != metadata.ocIdTransfer {
                    NCManageDatabase.shared.deleteMetadataOcId(metadata.ocIdTransfer)
                }
                metadata.fileName = fileName
                metadata.serverUrl = serverUrl
                metadata.uploadDate = (date as? NSDate) ?? NSDate()
                metadata.etag = etag ?? ""
                metadata.ocId = ocId
                metadata.size = size
                if let fileId = NCUtility().ocIdToFileId(ocId: ocId) {
                    metadata.fileId = fileId
                }

                metadata.sceneIdentifier = nil
                metadata.session = ""
                metadata.sessionError = ""
                metadata.sessionSelector = ""
                metadata.sessionDate = nil
                metadata.sessionTaskIdentifier = 0
                metadata.status = NCGlobal.shared.metadataStatusNormal

                NCManageDatabase.shared.addMetadata(metadata)
                NCManageDatabase.shared.addLocalFile(metadata: metadata)

                /// SIGNAL
                fileProviderData.shared.signalEnumerator(ocId: metadata.ocId, type: .update)
            } else {
                NCManageDatabase.shared.deleteMetadataOcId(metadata.ocIdTransfer)
                /// SIGNAL
                fileProviderData.shared.signalEnumerator(ocId: metadata.ocIdTransfer, type: .delete)
            }
        }
#else
        DispatchQueue.global().async {
            if let url = task.currentRequest?.url,
               let metadata = self.database.getMetadata(from: url, sessionTaskIdentifier: task.taskIdentifier) {
                self.uploadComplete(metadata: metadata, ocId: ocId, etag: etag, date: date, size: size, error: error)
            }
        }
#endif
    }

    func uploadComplete(metadata: tableMetadata,
                        ocId: String?,
                        etag: String?,
                        date: Date?,
                        size: Int64,
                        error: NKError) {
        NextcloudKit.shared.nkCommonInstance.appendServerErrorAccount(metadata.account, errorCode: error.errorCode)

        let selector = metadata.sessionSelector

        if error == .success, let ocId = ocId, size == metadata.size {

            var metadata = tableMetadata(value: metadata)
            metadata.uploadDate = (date as? NSDate) ?? NSDate()
            metadata.etag = etag ?? ""
            metadata.ocId = ocId
            metadata.chunk = 0

            if let fileId = self.utility.ocIdToFileId(ocId: ocId) {
                metadata.fileId = fileId
            }

            metadata.session = ""
            metadata.sessionError = ""
            metadata.sessionTaskIdentifier = 0
            metadata.status = self.global.metadataStatusNormal

            self.database.deleteMetadata(predicate: NSPredicate(format: "ocIdTransfer == %@", metadata.ocIdTransfer), sync: false)
            metadata = self.database.addMetadata(metadata)

            if selector == self.global.selectorUploadFileNODelete {
#if EXTENSION
                self.utilityFileSystem.moveFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocIdTransfer),
                                                toPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId))
#else
                moveFileSafely(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocIdTransfer),
                               toPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId))
#endif
                self.database.addLocalFile(metadata: metadata, sync: false)
            } else {
#if EXTENSION
                self.utilityFileSystem.removeFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocIdTransfer))
#else
                removeFileInBackgroundSafe(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocIdTransfer))
#endif

            }

            /// Update the auto upload data
            if selector == self.global.selectorUploadAutoUpload,
               let serverUrlBase = metadata.autoUploadServerUrlBase {
                self.database.addAutoUploadTransfer(account: metadata.account,
                                                    serverUrlBase: serverUrlBase,
                                                    fileName: metadata.fileNameView,
                                                    assetLocalIdentifier: metadata.assetLocalIdentifier,
                                                    date: metadata.creationDate as Date,
                                                    sync: false)
            }

            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Upload complete " + metadata.serverUrl + "/" + metadata.fileName + ", result: success(\(size) bytes)")

            let userInfo: [String: Any] = ["ocId": metadata.ocId,
                                           "ocIdTransfer": metadata.ocIdTransfer,
                                           "session": metadata.session,
                                           "serverUrl": metadata.serverUrl,
                                           "account": metadata.account,
                                           "fileName": metadata.fileName,
                                           "error": error]
            if metadata.isLivePhoto,
               NCCapabilities.shared.getCapabilities(account: metadata.account).isLivePhotoServerAvailable {
                DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                    self.createLivePhoto(metadata: metadata, userInfo: userInfo)
                }
            } else {
                self.notifyAllDelegates { delegate in
                    delegate.transferChange(status: self.global.networkingStatusUploaded,
                                            metadata: tableMetadata(value: metadata),
                                            error: error)
                }
            }
        } else {
            if error.errorCode == NSURLErrorCancelled || error.errorCode == self.global.errorRequestExplicityCancelled {
                self.uploadCancelFile(metadata: metadata)
            } else if error.errorCode == self.global.errorBadRequest || error.errorCode == self.global.errorUnsupportedMediaType {
                self.uploadCancelFile(metadata: metadata)
                NCContentPresenter().showError(error: NKError(errorCode: error.errorCode, errorDescription: "_virus_detect_"))

                // Client Diagnostic
                self.database.addDiagnostic(account: metadata.account, issue: self.global.diagnosticIssueVirusDetected, sync: false)
            } else if error.errorCode == self.global.errorForbidden && !isAppInBackground {
#if !EXTENSION
                NextcloudKit.shared.getTermsOfService(account: metadata.account, options: NKRequestOptions(checkInterceptor: false)) { _, tos, _, error in
                    if error == .success, let tos, !tos.hasUserSigned() {
                        self.uploadCancelFile(metadata: metadata)
                    } else {
                        let newFileName = self.utilityFileSystem.createFileName(metadata.fileName, serverUrl: metadata.serverUrl, account: metadata.account)
                        let alertController = UIAlertController(title: error.errorDescription, message: NSLocalizedString("_change_upload_filename_", comment: ""), preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: String(format: NSLocalizedString("_save_file_as_", comment: ""), newFileName), style: .default, handler: { _ in
                            let atpath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + metadata.fileName
                            let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + newFileName
                            self.utilityFileSystem.moveFile(atPath: atpath, toPath: toPath)
                            self.database.setMetadataSession(metadata: metadata,
                                                             newFileName: newFileName,
                                                             sessionTaskIdentifier: 0,
                                                             sessionError: "",
                                                             status: self.global.metadataStatusWaitUpload,
                                                             errorCode: error.errorCode)
                        }))
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("_discard_changes_", comment: ""), style: .destructive, handler: { _ in
                            self.uploadCancelFile(metadata: metadata)
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
                        self.database.addDiagnostic(account: metadata.account,
                                                    issue: self.global.diagnosticIssueProblems,
                                                    error: self.global.diagnosticProblemsForbidden,
                                                    sync: false)
                    }
                }
#endif
            } else {
                let metadata = self.database.setMetadataSession(metadata: metadata,
                                                                sessionTaskIdentifier: 0,
                                                                sessionError: error.errorDescription,
                                                                status: self.global.metadataStatusUploadError,
                                                                errorCode: error.errorCode)

                self.notifyAllDelegates { delegate in
                    delegate.transferChange(status: self.global.networkingStatusUploaded,
                                            metadata: metadata,
                                            error: error)
                }

                // Client Diagnostic
                if error.errorCode == self.global.errorInternalServerError {
                    self.database.addDiagnostic(account: metadata.account,
                                                issue: self.global.diagnosticIssueProblems,
                                                error: self.global.diagnosticProblemsBadResponse,
                                                sync: false)
                } else {
                    self.database.addDiagnostic(account: metadata.account,
                                                issue: self.global.diagnosticIssueProblems,
                                                error: self.global.diagnosticProblemsUploadServerError,
                                                sync: false)
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
        self.notifyAllDelegates { delegate in
            delegate.transferProgressDidUpdate(progress: progress,
                                               totalBytes: totalBytes,
                                               totalBytesExpected: totalBytesExpected,
                                               fileName: fileName,
                                               serverUrl: serverUrl)
        }
    }

    func uploadCancelFile(metadata: tableMetadata) {
#if EXTENSION
                self.utilityFileSystem.removeFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocIdTransfer))
#else
                removeFileInBackgroundSafe(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocIdTransfer))
#endif
        self.database.deleteMetadataOcId(metadata.ocIdTransfer, sync: false)
        self.notifyAllDelegates { delegate in
            delegate.transferChange(status: self.global.networkingStatusUploadCancel,
                                    metadata: tableMetadata(value: metadata),
                                    error: .success)
        }
    }
}
