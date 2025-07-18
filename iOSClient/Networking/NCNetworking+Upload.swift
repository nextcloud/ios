import UIKit
import NextcloudKit
import Alamofire

extension NCNetworking {

    // MARK: - Upload file in foreground

    @discardableResult
    func uploadFile(metadata: tableMetadata,
                    withUploadComplete: Bool = true,
                    customHeaders: [String: String]? = nil,
                    requestHandler: @escaping (_ request: UploadRequest) -> Void = { _ in },
                    taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                    progressHandler: @escaping (_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double) -> Void = { _, _, _ in })
    async -> (account: String,
              ocId: String?,
              etag: String?,
              date: Date?,
              size: Int64,
              headers: [AnyHashable: Any]?,
              error: NKError) {
        let options = NKRequestOptions(customHeader: customHeaders, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId,
                                                                                  fileName: metadata.fileName,
                                                                                  userId: metadata.userId,
                                                                                  urlBase: metadata.urlBase)

        let results = await NextcloudKit.shared.uploadAsync(serverUrlFileName: metadata.serverUrlFileName, fileNameLocalPath: fileNameLocalPath, dateCreationFile: metadata.creationDate as Date, dateModificationFile: metadata.date as Date, account: metadata.account, options: options) { request in
            requestHandler(request)
        } taskHandler: { task in
            Task {
                if let metadata = await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                              sessionTaskIdentifier: task.taskIdentifier,
                                                                              status: self.global.metadataStatusUploading) {

                    self.notifyAllDelegates { delegate in
                        delegate.transferChange(status: self.global.networkingStatusUploading,
                                                metadata: metadata,
                                                error: .success)
                    }
                }
            }
            taskHandler(task)
        } progressHandler: { progress in
            self.notifyAllDelegates { delegate in
                delegate.transferProgressDidUpdate(progress: Float(progress.fractionCompleted),
                                                   totalBytes: progress.totalUnitCount,
                                                   totalBytesExpected: progress.completedUnitCount,
                                                   fileName: metadata.fileName,
                                                   serverUrl: metadata.serverUrl)
            }
            progressHandler(progress.completedUnitCount, progress.totalUnitCount, progress.fractionCompleted)
        }

        if withUploadComplete {
            await self.uploadComplete(withMetadata: metadata, ocId: results.ocId, etag: results.etag, date: results.date, size: results.size, error: results.error)
        }

        return results
    }

    // MARK: - Upload chunk file in foreground

    @discardableResult
    func uploadChunkFile(metadata: tableMetadata,
                         withUploadComplete: Bool = true,
                         customHeaders: [String: String]? = nil,
                         numChunks: @escaping (_ num: Int) -> Void = { _ in },
                         counterChunk: @escaping (_ counter: Int) -> Void = { _ in },
                         startFilesChunk: @escaping (_ filesChunk: [(fileName: String, size: Int64)]) -> Void = { _ in },
                         requestHandler: @escaping (_ request: UploadRequest) -> Void = { _ in },
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         progressHandler: @escaping (_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double) -> Void = { _, _, _ in },
                         assembling: @escaping () -> Void = { })
    async -> (account: String,
              remainingChunks: [(fileName: String, size: Int64)]?,
              file: NKFile?,
              error: NKError) {
        let directory = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase)
        let chunkFolder = self.database.getChunkFolder(account: metadata.account, ocId: metadata.ocId)
        let filesChunk = self.database.getChunks(account: metadata.account, ocId: metadata.ocId)
        var chunkSize = self.global.chunkSizeMBCellular
        if networkReachability == NKTypeReachability.reachableEthernetOrWiFi {
            chunkSize = self.global.chunkSizeMBEthernetOrWiFi
        }
        let options = NKRequestOptions(customHeader: customHeaders, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        let results = await NextcloudKit.shared.uploadChunkAsync(directory: directory,
                                                                 fileName: metadata.fileName,
                                                                 date: metadata.date as Date,
                                                                 creationDate: metadata.creationDate as Date,
                                                                 serverUrl: metadata.serverUrl,
                                                                 chunkFolder: chunkFolder,
                                                                 filesChunk: filesChunk,
                                                                 chunkSize: chunkSize,
                                                                 account: metadata.account,
                                                                 options: options) { num in
            numChunks(num)
        } counterChunk: { counter in
            counterChunk(counter)
        } start: { filesChunk in
            Task {
                await self.database.addChunksAsync(account: metadata.account, ocId: metadata.ocId, chunkFolder: chunkFolder, filesChunk: filesChunk)
                self.notifyAllDelegates { delegate in
                    delegate.transferChange(status: self.global.networkingStatusUploading,
                                            metadata: metadata.detachedCopy(),
                                            error: .success)
                }
            }
            startFilesChunk(filesChunk)
        } requestHandler: { request in
            requestHandler(request)
        } taskHandler: { task in
            Task {
                await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                            sessionTaskIdentifier: task.taskIdentifier,
                                                            status: self.global.metadataStatusUploading)
            }
            taskHandler(task)
        } progressHandler: { totalBytesExpected, totalBytes, fractionCompleted in
            self.notifyAllDelegates { delegate in
                delegate.transferProgressDidUpdate(progress: Float(fractionCompleted),
                                                   totalBytes: totalBytes,
                                                   totalBytesExpected: totalBytesExpected,
                                                   fileName: metadata.fileName,
                                                   serverUrl: metadata.serverUrl)
            }
            progressHandler(totalBytesExpected, totalBytes, fractionCompleted)
        } assembling: {
            assembling()
        } uploaded: { fileChunk in
            Task {
                await self.database.deleteChunkAsync(account: metadata.account,
                                                     ocId: metadata.ocId,
                                                     fileChunk: fileChunk,
                                                     directory: directory)
            }
        }

        if results.error == .success {
            await self.database.deleteChunksAsync(account: metadata.account,
                                                  ocId: metadata.ocId,
                                                  directory: directory)
        }

        if withUploadComplete {
            await self.uploadComplete(withMetadata: metadata, ocId: results.file?.ocId, etag: results.file?.etag, date: results.file?.date, size: results.file?.size ?? 0, error: results.error)
        }

        return results
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
            await self.database.deleteMetadataOcIdAsync(metadata.ocId)
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

            return(error)
        }
    }

    // MARK: - Upload file in Foreground

    func uploadComplete(withMetadata metadata: tableMetadata,
                        ocId: String?,
                        etag: String?,
                        date: Date?,
                        size: Int64,
                        error: NKError) async {
        await NextcloudKit.shared.nkCommonInstance.appendServerErrorAccount(metadata.account, errorCode: error.errorCode)

        let selector = metadata.sessionSelector
        let capabilities = await NKCapabilities.shared.getCapabilities(for: metadata.account)

        if error == .success, let ocId = ocId, size == metadata.size {
            nkLog(success: "Uploaded file: " + metadata.serverUrlFileName + ", (\(size) bytes)")

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
            await self.database.addMetadataAsync(metadata)

            if selector == self.global.selectorUploadFileNODelete {
                if isAppInBackground {
                    self.utilityFileSystem.moveFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocIdTransfer, userId: metadata.userId, urlBase: metadata.urlBase),
                                                    toPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId, userId: metadata.userId, urlBase: metadata.urlBase))
                } else {
                    self.utilityFileSystem.moveFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocIdTransfer, userId: metadata.userId, urlBase: metadata.urlBase),
                                                    toPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId, userId: metadata.userId, urlBase: metadata.urlBase))
                }

                await self.database.addLocalFileAsync(metadata: metadata)

            } else {
                self.utilityFileSystem.removeFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocIdTransfer, userId: metadata.userId, urlBase: metadata.urlBase))
            }

            // Update the auto upload data
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
                                            metadata: metadata.detachedCopy(),
                                            error: error)
                }
            }

        } else {
            nkLog(error: "Upload file: " + metadata.serverUrlFileName + ", result: error \(error.errorCode)")

            if error.errorCode == NSURLErrorCancelled || error.errorCode == self.global.errorRequestExplicityCancelled {
                await uploadCancelFile(metadata: metadata)
            } else if error.errorCode == self.global.errorBadRequest || error.errorCode == self.global.errorUnsupportedMediaType {
                await uploadCancelFile(metadata: metadata)
                NCContentPresenter().showError(error: NKError(errorCode: error.errorCode, errorDescription: "_virus_detect_"))
                // Client Diagnostic
                await self.database.addDiagnosticAsync(account: metadata.account, issue: self.global.diagnosticIssueVirusDetected)
            } else if error.errorCode == self.global.errorForbidden {
                if isAppInBackground {
                    await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                sessionTaskIdentifier: 0,
                                                                sessionError: error.errorDescription,
                                                                status: self.global.metadataStatusUploadError,
                                                                errorCode: error.errorCode)
                } else {
                    #if EXTENSION
                    await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                sessionTaskIdentifier: 0,
                                                                sessionError: error.errorDescription,
                                                                status: self.global.metadataStatusUploadError,
                                                                errorCode: error.errorCode)
                    #else
                    if capabilities.termsOfService {
                        await termsOfService(metadata: metadata)
                    } else {
                        await uploadForbidden(metadata: metadata, error: error)
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
        await self.database.updateBadge()
    }

    func uploadCancelFile(metadata: tableMetadata) async {
        self.utilityFileSystem.removeFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocIdTransfer, userId: metadata.userId, urlBase: metadata.urlBase))
        await self.database.deleteMetadataOcIdAsync(metadata.ocIdTransfer)
        self.notifyAllDelegates { delegate in
            delegate.transferChange(status: self.global.networkingStatusUploadCancel,
                                    metadata: metadata.detachedCopy(),
                                    error: .success)
        }
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
                self.utilityFileSystem.moveFile(atPath: atpath, toPath: toPath)
                await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
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
        await self.database.addDiagnosticAsync(account: metadata.account,
                                               issue: self.global.diagnosticIssueProblems,
                                               error: self.global.diagnosticProblemsForbidden)
    }

    @MainActor
    func termsOfService(metadata: tableMetadata) async {
        let options = NKRequestOptions(checkInterceptor: false, queue: .main)
        let results = await NextcloudKit.shared.getTermsOfServiceAsync(account: metadata.account, options: options)

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
                self.utilityFileSystem.moveFile(atPath: atpath, toPath: toPath)
                await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
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
        await self.database.addDiagnosticAsync(account: metadata.account,
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

    // MARK: - Upload complete NextcloudKitDelegate

    func uploadComplete(fileName: String,
                        serverUrl: String,
                        ocId: String?,
                        etag: String?,
                        date: Date?,
                        size: Int64,
                        task: URLSessionTask,
                        error: NKError) {
        Task {
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
            if let url = task.currentRequest?.url,
               let metadata = await self.database.getMetadataAsync(from: url, sessionTaskIdentifier: task.taskIdentifier) {
                await uploadComplete(withMetadata: metadata, ocId: ocId, etag: etag, date: date, size: size, error: error)
            } else {
                let predicate = NSPredicate(format: "fileName == %@ AND serverUrl == %@", fileName, serverUrl)
                await self.database.deleteMetadataAsync(predicate: predicate)
            }
            #endif
        }
    }
}
