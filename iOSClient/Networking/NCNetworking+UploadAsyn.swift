import UIKit
import NextcloudKit
import Alamofire

extension NCNetworking {

    // MARK: - Upload file in foreground

    func uploadFileAsync(metadata: tableMetadata,
                         fileNameLocalPath: String,
                         withUploadComplete: Bool = true,
                         customHeaders: [String: String]? = nil,
                         requestHandler: @escaping (_ request: UploadRequest) -> Void = { _ in },
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         progressHandler: @escaping (_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double) -> Void = { _, _, _ in }) async {
        let options = NKRequestOptions(customHeader: customHeaders, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        let result = await NextcloudKit.shared.uploadAsync(serverUrlFileName: metadata.serverUrlFileName, fileNameLocalPath: fileNameLocalPath, dateCreationFile: metadata.creationDate as Date, dateModificationFile: metadata.date as Date, account: metadata.account, options: options) { request in
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
            await self.uploadCompleteAsync(withMetadata: metadata, ocId: result.ocId, etag: result.etag, date: result.date, size: result.size, error: result.error)
        }
    }

    // MARK: - Upload chunk file in foreground

    func uploadChunkFileAsync(metadata: tableMetadata,
                              withUploadComplete: Bool = true,
                              customHeaders: [String: String]? = nil,
                              numChunks: @escaping (_ num: Int) -> Void = { _ in },
                              counterChunk: @escaping (_ counter: Int) -> Void = { _ in },
                              startFilesChunk: @escaping (_ filesChunk: [(fileName: String, size: Int64)]) -> Void = { _ in },
                              requestHandler: @escaping (_ request: UploadRequest) -> Void = { _ in },
                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                              progressHandler: @escaping (_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double) -> Void = { _, _, _ in },
                              assemble: @escaping () -> Void = { }) async {
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
        } assemble: {
            assemble()
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
            await self.uploadCompleteAsync(withMetadata: metadata, ocId: results.file?.ocId, etag: results.file?.etag, date: results.file?.date, size: results.file?.size ?? 0, error: results.error)
        }
    }

    // MARK: - Upload file in background

    func uploadFileInBackgroundAsync(metadata: tableMetadata,
                                     start: @escaping () -> Void = { }) async -> (taks: URLSessionUploadTask?, error: NKError) {
        let metadata = tableMetadata.init(value: metadata)
        let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView, userId: metadata.userId, urlBase: metadata.urlBase)

        start()

        // Check file dim > 0
        if utilityFileSystem.getFileSize(filePath: fileNameLocalPath) == 0 && metadata.size != 0 {
            await self.database.deleteMetadataOcIdAsync(metadata.ocId)
            return (nil, NKError(errorCode: self.global.errorResourceNotFound, errorDescription: NSLocalizedString("_error_not_found_", value: "The requested resource could not be found", comment: "")))
        } else {
            let (task, error) = await backgroundSession.uploadAsync(serverUrlFileName: metadata.serverUrlFileName,
                                                                    fileNameLocalPath: fileNameLocalPath,
                                                                    dateCreationFile: metadata.creationDate as Date,
                                                                    dateModificationFile: metadata.date as Date,
                                                                    account: metadata.account,
                                                                    sessionIdentifier: metadata.session)

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

            return(task, error)
        }
    }

    // MARK: - Upload complete

    func uploadCompleteAsync(withMetadata metadata: tableMetadata,
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
                        termsOfService(metadata: metadata)
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
}
