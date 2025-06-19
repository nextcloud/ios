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
                completion: @escaping (_ error: NKError) -> Void = { _ in }) {
        let metadata = tableMetadata.init(value: metadata)
        var numChunks: Int = 0
        var hud: NCHud?
        nkLog(debug: " Upload file \(metadata.fileNameView) with Identifier \(metadata.assetLocalIdentifier) with size \(metadata.size) [CHUNK \(metadata.chunk), E2EE \(metadata.isDirectoryE2EE)]")

        func tapOperation() {
            NotificationCenter.default.postOnMainThread(name: NextcloudKit.shared.nkCommonInstance.notificationCenterChunkedFileStop.rawValue)
        }

        if metadata.isDirectoryE2EE {
#if !EXTENSION_FILE_PROVIDER_EXTENSION && !EXTENSION_WIDGET
            Task {
                let error = await NCNetworkingE2EEUpload().upload(metadata: metadata, uploadE2EEDelegate: uploadE2EEDelegate, controller: controller)
                completion(error)
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
            } completion: { account, _, error in
                hud?.dismiss()
                let directory = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId)

                switch error {
                case .errorChunkNoEnoughMemory, .errorChunkCreateFolder, .errorChunkFilesEmpty, .errorChunkFileNull:
                    self.database.deleteMetadataOcId(metadata.ocId)
                    self.database.deleteChunks(account: account, ocId: metadata.ocId, directory: directory)
                    NCContentPresenter().messageNotification("_error_files_upload_", error: error, delay: self.global.dismissAfterSecond, type: .error, afterDelay: 0.5)
                case .errorChunkFileUpload:
                    break
                    // self.database.deleteChunks(account: account, ocId: metadata.ocId, directory: directory)
                case .errorChunkMoveFile:
                    self.database.deleteChunks(account: account, ocId: metadata.ocId, directory: directory)
                    NCContentPresenter().messageNotification("_chunk_move_", error: error, delay: self.global.dismissAfterSecond, type: .error, afterDelay: 0.5)
                default: break
                }
                completion(error)
            }
        } else if metadata.session == sessionUpload {
            let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)
            uploadFile(metadata: metadata,
                       fileNameLocalPath: fileNameLocalPath,
                       controller: controller,
                       start: start,
                       progressHandler: progressHandler) { _, _, _, _, _, _, error in
                completion(error)
            }
        } else {
            uploadFileInBackground(metadata: metadata, controller: controller, start: start) { error in
                completion(error)
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
                    completion: @escaping (_ account: String, _ ocId: String?, _ etag: String?, _ date: Date?, _ size: Int64, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let options = NKRequestOptions(customHeader: customHeaders, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        NextcloudKit.shared.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, dateCreationFile: metadata.creationDate as Date, dateModificationFile: metadata.date as Date, account: metadata.account, options: options, requestHandler: { request in
            requestHandler(request)
        }, taskHandler: { task in
            if let metadata = self.database.setMetadataSession(ocId: metadata.ocId,
                                                               sessionTaskIdentifier: task.taskIdentifier,
                                                               status: self.global.metadataStatusUploading) {

                self.notifyAllDelegates { delegate in
                    delegate.transferChange(status: self.global.networkingStatusUploading,
                                            metadata: metadata,
                                            error: .success)
                }
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
        }) { account, ocId, etag, date, size, responseData, error in
            var error = error
            if withUploadComplete {
                if error == .errorChunkFileNull {
                    error = NKError(errorCode: self.global.errorRequestExplicityCancelled, errorDescription: "error request explicity cancelled")
                }
                self.uploadComplete(metadata: metadata, ocId: ocId, etag: etag, date: date, size: size, error: error)
            }
            completion(account, ocId, etag, date, size, responseData, error)
        }
    }

    func uploadChunkFile(metadata: tableMetadata,
                         withUploadComplete: Bool = true,
                         customHeaders: [String: String]? = nil,
                         numChunks: @escaping (_ num: Int) -> Void = { _ in },
                         counterChunk: @escaping (_ counter: Int) -> Void = { _ in },
                         start: @escaping () -> Void = { },
                         progressHandler: @escaping (_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double) -> Void = { _, _, _ in },
                         completion: @escaping (_ account: String, _ file: NKFile?, _ error: NKError) -> Void) {
        let directory = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId)
        let chunkFolder = self.database.getChunkFolder(account: metadata.account, ocId: metadata.ocId)
        let filesChunk = self.database.getChunks(account: metadata.account, ocId: metadata.ocId)
        var chunkSize = self.global.chunkSizeMBCellular
        if networkReachability == NKTypeReachability.reachableEthernetOrWiFi {
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
            self.database.setMetadataSession(ocId: metadata.ocId,
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
        } completion: { account, _, file, error in
            if error == .success {
                self.database.deleteChunks(account: account,
                                           ocId: metadata.ocId,
                                           directory: directory)
            }
            if withUploadComplete {
                self.uploadComplete(metadata: metadata, ocId: file?.ocId, etag: file?.etag, date: file?.date, size: file?.size ?? 0, error: error)
            }
            completion(account, file, error)
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

            Task {
                if let task, error == .success {
                    nkLog(debug: " Upload file \(metadata.fileNameView) with task with taskIdentifier \(task.taskIdentifier)")

                    if let metadata = await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                                  sessionTaskIdentifier: task.taskIdentifier,
                                                                                  status: self.global.metadataStatusUploading) {

                        self.notifyAllDelegates { delegate in
                            delegate.transferChange(status: self.global.networkingStatusUploading,
                                                    metadata: metadata,
                                                    error: .success)
                        }
                    }
                } else {
                    await self.database.deleteMetadataOcIdAsync(metadata.ocId)
                }

                completion(error)
            }
        }
    }

    func uploadFileInBackgroundAsync(metadata: tableMetadata, controller: UIViewController? = nil) async -> NKError {
        await withCheckedContinuation { continuation in
            uploadFileInBackground(metadata: metadata,
                                   controller: controller,
                                   start: { },
                                   completion: { error in
                continuation.resume(returning: error)
            })
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
        Task {
            if let url = task.currentRequest?.url,
               let metadata = await self.database.getMetadataAsync(from: url, sessionTaskIdentifier: task.taskIdentifier) {
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

        Task {
            let capabilities = await NKCapabilities.shared.getCapabilitiesAsync(for: metadata.account)

            if error == .success, let ocId = ocId, size == metadata.size {
                nkLog(success: "Uploaded file: " + metadata.serverUrl + "/" + metadata.fileName + ", (\(size) bytes)")

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

                await self.database.deleteMetadataAsync(predicate: NSPredicate(format: "ocIdTransfer == %@", metadata.ocIdTransfer))
                let metadata = await self.database.addMetadataAsync(metadata)

                if selector == self.global.selectorUploadFileNODelete {
                    if isAppInBackground {
#if EXTENSION
                        self.utilityFileSystem.moveFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocIdTransfer),
                                                        toPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId))
#else
                        moveFileSafely(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocIdTransfer), toPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId))
#endif
                    } else {
                        self.utilityFileSystem.moveFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocIdTransfer),
                                                        toPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId))
                    }

                    await self.database.addLocalFileAsync(metadata: metadata)

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
                    await self.database.addAutoUploadTransferAsync(account: metadata.account,
                                                                   serverUrlBase: serverUrlBase,
                                                                   fileName: metadata.fileNameView,
                                                                   assetLocalIdentifier: metadata.assetLocalIdentifier,
                                                                   date: metadata.creationDate as Date)
                }

                if metadata.isLivePhoto,
                   capabilities.isLivePhotoServerAvailable {
                    await self.createLivePhoto(metadata: metadata)
                } else {
                    self.notifyAllDelegates { delegate in
                        delegate.transferChange(status: self.global.networkingStatusUploaded,
                                                metadata: tableMetadata(value: metadata),
                                                error: error)
                    }
                }

            } else {
                nkLog(error: "Upload file: " + metadata.serverUrl + "/" + metadata.fileName + ", result: error \(error.errorCode)")

                if error.errorCode == NSURLErrorCancelled || error.errorCode == self.global.errorRequestExplicityCancelled {
                    await uploadCancelFile(metadata: metadata)
                } else if error.errorCode == self.global.errorBadRequest || error.errorCode == self.global.errorUnsupportedMediaType {
                    await uploadCancelFile(metadata: metadata)
                    NCContentPresenter().showError(error: NKError(errorCode: error.errorCode, errorDescription: "_virus_detect_"))
                    // Client Diagnostic
                    await self.database.addDiagnosticAsync(account: metadata.account, issue: self.global.diagnosticIssueVirusDetected)
                } else if error.errorCode == self.global.errorForbidden {
                    if isAppInBackground {
                        _ = await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                        sessionTaskIdentifier: 0,
                                                                        sessionError: error.errorDescription,
                                                                        status: self.global.metadataStatusUploadError,
                                                                        errorCode: error.errorCode)
                    } else {
#if EXTENSION
                        _ = await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                        sessionTaskIdentifier: 0,
                                                                        sessionError: error.errorDescription,
                                                                        status: self.global.metadataStatusUploadError,
                                                                        errorCode: error.errorCode)
#else
                        if capabilities.termsOfService {
                            self.termsOfService(metadata: metadata)
                        } else {
                            self.uploadForbidden(metadata: metadata, error: error)
                        }
#endif
                    }
                } else {
                    if let metadata = await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                                  sessionTaskIdentifier: 0,
                                                                                  sessionError: error.errorDescription,
                                                                                  status: self.global.metadataStatusUploadError,
                                                                                  errorCode: error.errorCode) {

                        self.notifyAllDelegates { delegate in
                            delegate.transferChange(status: self.global.networkingStatusUploaded,
                                                    metadata: metadata,
                                                    error: error)
                        }
                    }

                    // Client Diagnostic
                    if error.errorCode == self.global.errorInternalServerError {
                        await self.database.addDiagnosticAsync(account: metadata.account,
                                                               issue: self.global.diagnosticIssueProblems,
                                                               error: self.global.diagnosticProblemsBadResponse)
                    } else {
                        await self.database.addDiagnosticAsync(account: metadata.account,
                                                               issue: self.global.diagnosticIssueProblems,
                                                               error: self.global.diagnosticProblemsUploadServerError)
                    }
                }
            }
#if !EXTENSION
        await self.database.updateBadge()
#endif
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

    func uploadCancelFile(metadata: tableMetadata) async {
#if EXTENSION
                self.utilityFileSystem.removeFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocIdTransfer))
#else
                removeFileInBackgroundSafe(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocIdTransfer))
#endif
        await self.database.deleteMetadataOcIdAsync(metadata.ocIdTransfer)
        self.notifyAllDelegates { delegate in
            delegate.transferChange(status: self.global.networkingStatusUploadCancel,
                                    metadata: tableMetadata(value: metadata),
                                    error: .success)
        }
    }

#if !EXTENSION
    func uploadForbidden(metadata: tableMetadata, error: NKError) {
        let newFileName = self.utilityFileSystem.createFileName(metadata.fileName, serverUrl: metadata.serverUrl, account: metadata.account)
        let alertController = UIAlertController(title: error.errorDescription, message: NSLocalizedString("_change_upload_filename_", comment: ""), preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: String(format: NSLocalizedString("_save_file_as_", comment: ""), newFileName), style: .default, handler: { _ in
                let atpath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + metadata.fileName
                let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + newFileName
                self.utilityFileSystem.moveFile(atPath: atpath, toPath: toPath)
                self.database.setMetadataSession(ocId: metadata.ocId,
                                                 newFileName: newFileName,
                                                 sessionTaskIdentifier: 0,
                                                 sessionError: "",
                                                 status: self.global.metadataStatusWaitUpload,
                                                 errorCode: error.errorCode)
            }))
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_discard_changes_", comment: ""), style: .destructive, handler: { _ in
                Task {
                    await self.uploadCancelFile(metadata: metadata)
                }
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
                                        error: self.global.diagnosticProblemsForbidden)

    }

    func termsOfService(metadata: tableMetadata) {
        NextcloudKit.shared.getTermsOfService(account: metadata.account, options: NKRequestOptions(checkInterceptor: false, queue: .main)) { _, tos, _, error in
            if error == .success, let tos, !tos.hasUserSigned() {
                Task {
                    await self.uploadCancelFile(metadata: metadata)
                }
            } else {
                let newFileName = self.utilityFileSystem.createFileName(metadata.fileName, serverUrl: metadata.serverUrl, account: metadata.account)
                let alertController = UIAlertController(title: error.errorDescription, message: NSLocalizedString("_change_upload_filename_", comment: ""), preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: String(format: NSLocalizedString("_save_file_as_", comment: ""), newFileName), style: .default, handler: { _ in
                    let atpath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + metadata.fileName
                    let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + newFileName
                    self.utilityFileSystem.moveFile(atPath: atpath, toPath: toPath)
                    self.database.setMetadataSession(ocId: metadata.ocId,
                                                     newFileName: newFileName,
                                                     sessionTaskIdentifier: 0,
                                                     sessionError: "",
                                                     status: self.global.metadataStatusWaitUpload,
                                                     errorCode: error.errorCode)
                }))
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_discard_changes_", comment: ""), style: .destructive, handler: { _ in
                    Task {
                        await self.uploadCancelFile(metadata: metadata)
                    }
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
    }
    #endif
}
