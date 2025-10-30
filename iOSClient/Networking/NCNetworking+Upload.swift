// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import Alamofire

extension NCNetworking {

    // MARK: - Upload file in foreground

    @discardableResult
    func uploadFile(fileNameLocalPath: String,
                    serverUrlFileName: String,
                    creationDate: Date,
                    dateModificationFile: Date,
                    account: String,
                    metadata: tableMetadata? = nil,
                    performPostProcessing: Bool = true,
                    customHeaders: [String: String]? = nil,
                    requestHandler: @escaping (_ request: UploadRequest) -> Void = { _ in },
                    taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                    progressHandler: @escaping (_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double) -> Void = { _, _, _ in })
    async -> (account: String,
              ocId: String?,
              etag: String?,
              date: Date?,
              size: Int64,
              response: AFDataResponse<Data>?,
              error: NKError) {
        let options = NKRequestOptions(customHeader: customHeaders, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        let results = await NextcloudKit.shared.uploadAsync(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, dateCreationFile: creationDate, dateModificationFile: dateModificationFile, account: account, options: options) { request in
            requestHandler(request)
        } taskHandler: { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                            path: serverUrlFileName,
                                                                                            name: "upload")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)

                if let metadata,
                   let metadata = await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                                        sessionTaskIdentifier: task.taskIdentifier,
                                                                                        status: self.global.metadataStatusUploading) {

                    await self.transferDispatcher.notifyAllDelegates { delegate in
                        delegate.transferChange(status: self.global.networkingStatusUploading,
                                                metadata: metadata,
                                                destination: nil,
                                                error: .success)
                    }
                }
            }
            taskHandler(task)
        } progressHandler: { progress in
            Task {
                guard let metadata,
                      await self.progressQuantizer.shouldEmit(serverUrlFileName: serverUrlFileName, fraction: progress.fractionCompleted) else {
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
            progressHandler(progress.completedUnitCount, progress.totalUnitCount, progress.fractionCompleted)
        }

        Task {
            await progressQuantizer.clear(serverUrlFileName: serverUrlFileName)
        }

        if performPostProcessing, let metadata {
            if results.error == .success, let ocId = results.ocId {
                await uploadSuccess(withMetadata: metadata, ocId: ocId, etag: results.etag, date: results.date)
            } else {
                await uploadError(withMetadata: metadata, error: results.error)
            }
        }

        return results
    }

    // MARK: - Upload chunk file in foreground

    @discardableResult
    func uploadChunkFile(metadata: tableMetadata,
                         performPostProcessing: Bool = true,
                         customHeaders: [String: String]? = nil,
                         chunkCountHandler: @escaping (_ num: Int) -> Void = { _ in },
                         chunkProgressHandler: @escaping (_ counter: Int) -> Void = { _ in },
                         uploadStart: @escaping (_ filesChunk: [(fileName: String, size: Int64)]) -> Void = { _ in },
                         // uploadTaskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         uploadProgressHandler: @escaping (_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double) -> Void = { _, _, _ in },
                         // uploaded: @escaping (_ fileChunk: (fileName: String, size: Int64)) -> Void = { _ in },
                         assembling: @escaping () -> Void = { }) async -> (account: String,
                                                                           remainingChunks: [(fileName: String, size: Int64)]?,
                                                                           file: NKFile?,
                                                                           error: NKError) {

        let directory = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase)
        let chunkFolder = NCManageDatabase.shared.getChunkFolder(account: metadata.account, ocId: metadata.ocId)
        let filesChunk = NCManageDatabase.shared.getChunks(account: metadata.account, ocId: metadata.ocId)
        var chunkSize = self.global.chunkSizeMBCellular
        if networkReachability == NKTypeReachability.reachableEthernetOrWiFi {
            chunkSize = self.global.chunkSizeMBEthernetOrWiFi
        }
        let options = NKRequestOptions(customHeader: customHeaders, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        do {
            let (account, remaining, file) = try await NextcloudKit.shared.uploadChunkAsync(
                directory: directory,
                fileName: metadata.fileName,
                date: metadata.date as Date,
                creationDate: metadata.creationDate as Date,
                serverUrl: metadata.serverUrl,
                chunkFolder: chunkFolder,
                filesChunk: filesChunk,
                chunkSize: chunkSize,
                account: metadata.account,
                options: options) { num in
                    chunkCountHandler(num)
                } chunkProgressHandler: { counter in
                    chunkProgressHandler(counter)
                } uploadStart: { filesChunk in
                    Task {
                        await NCManageDatabase.shared.addChunksAsync(account: metadata.account, ocId: metadata.ocId, chunkFolder: chunkFolder, filesChunk: filesChunk)
                        await self.transferDispatcher.notifyAllDelegates { delegate in
                            delegate.transferChange(status: self.global.networkingStatusUploading,
                                                    metadata: metadata.detachedCopy(),
                                                    destination: nil,
                                                    error: .success)
                        }
                    }
                    uploadStart(filesChunk)
                } uploadTaskHandler: { task in
                    Task {
                        let url = task.originalRequest?.url?.absoluteString ?? ""
                        let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: metadata.account,
                                                                                                    path: url,
                                                                                                    name: "upload")
                        await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)

                        let ocId = metadata.ocId
                        await NCManageDatabase.shared.setMetadataSessionAsync(ocId: ocId,
                                                                              sessionTaskIdentifier: task.taskIdentifier,
                                                                              status: self.global.metadataStatusUploading)
                    }
                } uploadProgressHandler: { totalBytesExpected, totalBytes, fractionCompleted in
                    Task {
                        guard await self.progressQuantizer.shouldEmit(serverUrlFileName: metadata.serverUrlFileName, fraction: fractionCompleted) else {
                            return
                        }
                        await self.transferDispatcher.notifyAllDelegates { delegate in
                            delegate.transferProgressDidUpdate(progress: Float(fractionCompleted),
                                                               totalBytes: totalBytes,
                                                               totalBytesExpected: totalBytesExpected,
                                                               fileName: metadata.fileName,
                                                               serverUrl: metadata.serverUrl)
                        }
                    }
                    uploadProgressHandler(totalBytesExpected, totalBytes, fractionCompleted)
                } uploaded: { fileChunk in
                    Task {
                        await NCManageDatabase.shared.deleteChunkAsync(account: metadata.account,
                                                                       ocId: metadata.ocId,
                                                                       fileChunk: fileChunk,
                                                                       directory: directory)
                    }
                } assembling: {
                    assembling()
                }

            await NCManageDatabase.shared.deleteChunksAsync(account: metadata.account,
                                                            ocId: metadata.ocId,
                                                            directory: directory)

            if performPostProcessing, let file {
                await uploadSuccess(withMetadata: metadata, ocId: file.ocId, etag: file.etag, date: file.date)
            }

            return (account, remaining, file, NKError())
        } catch let error as NKError {
            if error.errorCode == -1 ||
                error.errorCode == -2 ||
                error.errorCode == -3 ||
                error.errorCode == -4 ||
                error.errorCode == -5 {
                await NCManageDatabase.shared.deleteChunksAsync(account: metadata.account,
                                                                ocId: metadata.ocId,
                                                                directory: directory)
                await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.ocId)
                utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase))
            }

            return (metadata.account, nil, nil, NKError(error: error))
        } catch {
            if performPostProcessing {
                await uploadError(withMetadata: metadata, error: NKError(error: error))
            }

            return (metadata.account, nil, nil, NKError(error: error))
        }
    }

    // MARK: - Upload file in background

    @discardableResult
    func uploadFileInBackground(metadata: tableMetadata,
                                taskHandler: @escaping (_ task: URLSessionUploadTask?) -> Void = { _ in },
                                start: @escaping () -> Void = { })
    async -> NKError {
        let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileName: metadata.fileName, userId: metadata.userId, urlBase: metadata.urlBase)

        start()

        // Check file dim > 0
        if utilityFileSystem.getFileSize(filePath: fileNameLocalPath) == 0 && metadata.size != 0 {
            await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.ocId)
            return NKError(errorCode: self.global.errorResourceNotFound, errorDescription: NSLocalizedString("_error_not_found_", value: "The requested resource could not be found", comment: ""))
        } else {
            let (task, error) = await backgroundSession.uploadAsync(serverUrlFileName: metadata.serverUrlFileName,
                                                                    fileNameLocalPath: fileNameLocalPath,
                                                                    dateCreationFile: metadata.creationDate as Date,
                                                                    dateModificationFile: metadata.date as Date,
                                                                    account: metadata.account,
                                                                    sessionIdentifier: metadata.session)

            taskHandler(task)

            if let task, error == .success {
                nkLog(debug: "Uploading file \(metadata.fileNameView) with taskIdentifier \(task.taskIdentifier)")

                if let metadata = await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                                        sessionTaskIdentifier: task.taskIdentifier,
                                                                                        status: self.global.metadataStatusUploading) {
                    await self.transferDispatcher.notifyAllDelegates { delegate in
                        delegate.transferChange(status: self.global.networkingStatusUploading,
                                                metadata: metadata,
                                                destination: nil,
                                                error: .success)
                    }
                }
            } else {
                await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.ocId)
            }

            return(error)
        }
    }

    // MARK: - UPLOAD SUCCESS

    private func uploadSuccess(withMetadata metadata: tableMetadata,
                               ocId: String,
                               etag: String?,
                               date: Date?) async {
        nkLog(success: "Uploaded file: " + metadata.serverUrlFileName)

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

        let results = await helperMetadataSuccess(metadata: metadata)

        await NCManageDatabase.shared.replaceMetadataAsync(id: metadata.ocIdTransfer, metadata: metadata)
        if let localFile = results.localFile {
            await NCManageDatabase.shared.addLocalFilesAsync(metadatas: [localFile])
        }
        if let tblAutoUpload = results.autoUpload {
            await NCManageDatabase.shared.addAutoUploadTransferAsync([tblAutoUpload])
        }
        if let livePhoto = results.livePhoto {
            await NCManageDatabase.shared.setLivePhotoVideo(metadatas: [livePhoto])
            await NCNetworking.shared.setLivePhoto(account: metadata.account)
        }

        await self.transferDispatcher.notifyAllDelegates { delegate in
            delegate.transferChange(status: self.global.networkingStatusUploaded,
                                    metadata: metadata.detachedCopy(),
                                    destination: nil,
                                    error: .success)
        }
    }

    // MARK: - UPLOAD ERROR

    func uploadError(withMetadata metadata: tableMetadata, error: NKError) async {
        await NextcloudKit.shared.nkCommonInstance.appendServerErrorAccount(metadata.account, errorCode: error.errorCode)

        nkLog(error: "Upload file: " + metadata.serverUrlFileName + ", result: error \(error.errorCode)")

        if error.errorCode == NSURLErrorCancelled || error.errorCode == self.global.errorRequestExplicityCancelled {
            await uploadCancelFile(metadata: metadata)
        } else if (error.errorCode == self.global.errorBadRequest || error.errorCode == self.global.errorUnsupportedMediaType) && error.errorDescription.localizedCaseInsensitiveContains("virus") {
            await uploadCancelFile(metadata: metadata)
            NCContentPresenter().showError(error: NKError(errorCode: error.errorCode, errorDescription: "_virus_detect_"))
            // Client Diagnostic
            await NCManageDatabase.shared.addDiagnosticAsync(account: metadata.account, issue: self.global.diagnosticIssueVirusDetected)
        } else if error.errorCode == self.global.errorForbidden {
            await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                  sessionTaskIdentifier: 0,
                                                                  sessionError: error.errorDescription,
                                                                  status: self.global.metadataStatusUploadError,
                                                                  errorCode: error.errorCode)
            #if !EXTENSION
            let capabilities = await NKCapabilities.shared.getCapabilities(for: metadata.account)
            if !isAppInBackground {
                if capabilities.termsOfService {
                    await termsOfService(metadata: metadata)
                } else {
                    await uploadForbidden(metadata: metadata, error: error)
                }
            }
            #endif
        } else {
            if let metadata = await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                                    sessionTaskIdentifier: 0,
                                                                                    sessionError: error.errorDescription,
                                                                                    status: self.global.metadataStatusUploadError,
                                                                                    errorCode: error.errorCode) {

                await self.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferChange(status: self.global.networkingStatusUploaded,
                                            metadata: metadata,
                                            destination: nil,
                                            error: error)
                }
            }

            // Client Diagnostic
            if error.errorCode == self.global.errorInternalServerError {
                await NCManageDatabase.shared.addDiagnosticAsync(account: metadata.account,
                                                                 issue: self.global.diagnosticIssueProblems,
                                                                 error: self.global.diagnosticProblemsBadResponse)
            } else {
                await NCManageDatabase.shared.addDiagnosticAsync(account: metadata.account,
                                                                 issue: self.global.diagnosticIssueProblems,
                                                                 error: self.global.diagnosticProblemsUploadServerError)
            }
        }
    }

    // MARK: -

    func uploadCancelFile(metadata: tableMetadata) async {
        self.utilityFileSystem.removeFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocIdTransfer, userId: metadata.userId, urlBase: metadata.urlBase))
        await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.ocIdTransfer)
    }

#if !EXTENSION
    @MainActor
    func uploadForbidden(metadata: tableMetadata, error: NKError) async {
        let newFileName = self.utilityFileSystem.createFileName(metadata.fileName, serverUrl: metadata.serverUrl, account: metadata.account)
        let alertController = UIAlertController(title: error.errorDescription, message: NSLocalizedString("_change_upload_filename_", comment: ""), preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: String(format: NSLocalizedString("_save_file_as_", comment: ""), newFileName), style: .default, handler: { _ in
            Task {
                let atpath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase) + "/" + metadata.fileName
                let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase) + "/" + newFileName
                await self.utilityFileSystem.moveFileAsync(atPath: atpath, toPath: toPath)
                await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                      newFileName: newFileName,
                                                                      sessionTaskIdentifier: 0,
                                                                      sessionError: "",
                                                                      status: self.global.metadataStatusWaitUpload,
                                                                      errorCode: error.errorCode)
            }
        }))
        alertController.addAction(UIAlertAction(title: NSLocalizedString("_discard_changes_", comment: ""), style: .destructive, handler: { _ in
            Task {
                await self.uploadCancelFile(metadata: metadata)
            }
        }))

        self.getViewController(metadata: metadata)?.present(alertController, animated: true)

        // Client Diagnostic
        await NCManageDatabase.shared.addDiagnosticAsync(account: metadata.account,
                                                         issue: self.global.diagnosticIssueProblems,
                                                         error: self.global.diagnosticProblemsForbidden)
    }

    @MainActor
    func termsOfService(metadata: tableMetadata) async {
        let options = NKRequestOptions(checkInterceptor: false, queue: .main)
        let results = await NextcloudKit.shared.getTermsOfServiceAsync(account: metadata.account, options: options, taskHandler: { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: metadata.account,
                                                                                            name: "getTermsOfService")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        })

        if results.error == .success, let tos = results.tos, !tos.hasUserSigned() {
            await self.uploadCancelFile(metadata: metadata)
            return
        }

        let newFileName = self.utilityFileSystem.createFileName(metadata.fileName, serverUrl: metadata.serverUrl, account: metadata.account)

        let alertController = UIAlertController(title: results.error.errorDescription, message: NSLocalizedString("_change_upload_filename_", comment: ""), preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: String(format: NSLocalizedString("_save_file_as_", comment: ""), newFileName), style: .default, handler: { _ in
            Task {
                let atpath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase) + "/" + metadata.fileName
                let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase) + "/" + newFileName
                await self.utilityFileSystem.moveFileAsync(atPath: atpath, toPath: toPath)
                await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                      newFileName: newFileName,
                                                                      sessionTaskIdentifier: 0,
                                                                      sessionError: "",
                                                                      status: self.global.metadataStatusWaitUpload,
                                                                      errorCode: results.error.errorCode)
            }
        }))

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_discard_changes_", comment: ""), style: .destructive, handler: { _ in
            Task {
                await self.uploadCancelFile(metadata: metadata)
            }
        }))

        self.getViewController(metadata: metadata)?.present(alertController, animated: true)

        // Client Diagnostic
        await NCManageDatabase.shared.addDiagnosticAsync(account: metadata.account,
                                                         issue: self.global.diagnosticIssueProblems,
                                                         error: self.global.diagnosticProblemsForbidden)
    }

    private func getViewController(metadata: tableMetadata) -> UIViewController? {
        var controller = UIApplication.shared.firstWindow?.rootViewController
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for windowScene in windowScenes {
            if let rootViewController = windowScene.keyWindow?.rootViewController as? NCMainTabBarController,
               rootViewController.currentServerUrl() == metadata.serverUrl {
                controller = rootViewController
                break
            }
        }
        return controller
    }
#endif

    // MARK: - Upload NextcloudKitDelegate

    func uploadComplete(fileName: String,
                        serverUrl: String,
                        ocId: String?,
                        etag: String?,
                        date: Date?,
                        size: Int64,
                        task: URLSessionTask,
                        error: NKError) {
        Task {
            await progressQuantizer.clear(serverUrlFileName: serverUrl + "/" + fileName)

            #if EXTENSION_FILE_PROVIDER_EXTENSION
                await FileProviderData.shared.uploadComplete(fileName: fileName,
                                                             serverUrl: serverUrl,
                                                             ocId: ocId,
                                                             etag: etag,
                                                             date: date,
                                                             size: size,
                                                             task: task,
                                                             error: error)

            #else
            guard let metadata = await NCManageDatabase.shared.getMetadataAsync(predicate: NSPredicate(format: "serverUrl == %@ AND fileName == %@ AND sessionTaskIdentifier == %d", serverUrl, fileName, task.taskIdentifier)) else {
                await NCManageDatabase.shared.deleteMetadataAsync(predicate: NSPredicate(format: "fileName == %@ AND serverUrl == %@", fileName, serverUrl))
                return
            }

            if error == .success {
                if let ocId {
                    if isInBackground() {
                        await uploadSuccess(withMetadata: metadata,
                                            ocId: ocId,
                                            etag: etag,
                                            date: date)
                    } else {
                        await NCNetworking.shared.metadataTranfersSuccess.append(metadata: metadata,
                                                                                 ocId: ocId,
                                                                                 date: date,
                                                                                 etag: etag)
                    }
                } else {
                    await NCManageDatabase.shared.deleteMetadataAsync(predicate: NSPredicate(format: "fileName == %@ AND serverUrl == %@", fileName, serverUrl))
                }
            } else {
                await uploadError(withMetadata: metadata, error: error)
            }
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
