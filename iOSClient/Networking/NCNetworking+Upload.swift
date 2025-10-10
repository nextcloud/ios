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
                await NCManageDatabase.shared.setMetadataProgress(ocId: metadata.ocId, progress: progress.fractionCompleted)
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

        if withUploadComplete, let metadata {
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
        let chunkFolder = NCManageDatabase.shared.getChunkFolder(account: metadata.account, ocId: metadata.ocId)
        let filesChunk = NCManageDatabase.shared.getChunks(account: metadata.account, ocId: metadata.ocId)
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
                await NCManageDatabase.shared.addChunksAsync(account: metadata.account, ocId: metadata.ocId, chunkFolder: chunkFolder, filesChunk: filesChunk)
                await self.transferDispatcher.notifyAllDelegates { delegate in
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
            taskHandler(task)
        } progressHandler: { totalBytesExpected, totalBytes, fractionCompleted in
            Task {
                guard await self.progressQuantizer.shouldEmit(serverUrlFileName: metadata.serverUrlFileName, fraction: fractionCompleted) else {
                    return
                }
                await NCManageDatabase.shared.setMetadataProgress(ocId: metadata.ocId, progress: fractionCompleted)
                await self.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferProgressDidUpdate(progress: Float(fractionCompleted),
                                                       totalBytes: totalBytes,
                                                       totalBytesExpected: totalBytesExpected,
                                                       fileName: metadata.fileName,
                                                       serverUrl: metadata.serverUrl)
                }
            }
            progressHandler(totalBytesExpected, totalBytes, fractionCompleted)
        } assembling: {
            assembling()
        } uploaded: { fileChunk in
            Task {
                await NCManageDatabase.shared.deleteChunkAsync(account: metadata.account,
                                                               ocId: metadata.ocId,
                                                               fileChunk: fileChunk,
                                                               directory: directory)
            }
        }

        if results.error == .success {
            await NCManageDatabase.shared.deleteChunksAsync(account: metadata.account,
                                                            ocId: metadata.ocId,
                                                            directory: directory)
        } else if results.error.errorCode == -1 ||
                  results.error.errorCode == -2 ||
                  results.error.errorCode == -3 ||
                  results.error.errorCode == -4 ||
                  results.error.errorCode == -5 {
            await NCManageDatabase.shared.deleteChunksAsync(account: metadata.account,
                                                            ocId: metadata.ocId,
                                                            directory: directory)
            await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.ocId)
            utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase))

            NCContentPresenter().showError(error: results.error)
            return results
        }

        if withUploadComplete {
            await self.uploadComplete(withMetadata: metadata, ocId: results.file?.ocId, etag: results.file?.etag, date: results.file?.date, size: results.file?.size ?? 0, error: results.error)
        }

        return results
    }

    // MARK: - Upload file in background

    @discardableResult
    func uploadFileInBackground(metadata: tableMetadata,
                                withFileExistsCheck: Bool = false,
                                taskHandler: @escaping (_ task: URLSessionUploadTask?) -> Void = { _ in },
                                start: @escaping () -> Void = { })
    async -> NKError {
        if withFileExistsCheck || metadata.sessionSelector == global.selectorUploadAutoUpload {
            let error = await self.fileExists(serverUrlFileName: metadata.serverUrlFileName, account: metadata.account)
            if error == .success {
                await uploadCancelFile(metadata: metadata)
                return (.success)
            }
        }

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
                nkLog(debug: "Upload file \(metadata.fileNameView) with taskIdentifier \(task.taskIdentifier)")

                if let metadata = await NCManageDatabase.shared.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                                        sessionTaskIdentifier: task.taskIdentifier,
                                                                                        status: self.global.metadataStatusUploading) {
                    await self.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferChange(status: self.global.networkingStatusUploading,
                                            metadata: metadata,
                                            error: .success)
                    }

                    await NCMetadataStore.shared.addItem(MetadataItem(ocId: metadata.ocId,
                                                                      ocIdTransfer: metadata.ocIdTransfer,
                                                                      session: metadata.session),
                                                   forFileName: metadata.fileName,
                                                   forServerUrl: metadata.serverUrl,
                                                   forTaskIdentifier: task.taskIdentifier)
                }
            } else {
                await NCManageDatabase.shared.deleteMetadataAsync(id: metadata.ocId)
            }

            return(error)
        }
    }

    // MARK: - UPLOAD SUCCESS

    func uploadSuccessMetadataItems(_ metadataItems: [MetadataItem]) async -> [String] {
        guard !metadataItems.isEmpty else {
            return []
        }
        let ocIdTransfers = metadataItems.compactMap { $0.ocIdTransfer }
        let metadatasUpload = await NCManageDatabase.shared.getMetadatasAsync(predicate: NSPredicate(format: "ocIdTransfer IN %@", ocIdTransfers))
        var metadatasUploaded: [tableMetadata] = []
        var metadatasLocalFiles: [tableMetadata] = []
        var metadatasLivePhoto: [tableMetadata] = []
        var serversUrl = Set<String>()
        var accounts = Set<String>()
        var autoUploadTransfers: [tableAutoUploadTransfer] = []

        for metadata in metadatasUpload {
            guard let transferItem = (metadataItems.first { $0.ocIdTransfer == metadata.ocIdTransfer }),
                  let etag = transferItem.etag,
                  let ocId = transferItem.ocId else {
                continue
            }

            metadata.uploadDate = (transferItem.date as? NSDate) ?? NSDate()
            metadata.etag = etag
            metadata.ocId = ocId
            metadata.chunk = 0

            if let fileId = utility.ocIdToFileId(ocId: metadata.ocId) {
                metadata.fileId = fileId
            }

            metadata.session = ""
            metadata.sessionError = ""
            metadata.sessionTaskIdentifier = 0
            metadata.status = NCGlobal.shared.metadataStatusNormal

            // Array
            metadatasUploaded.append(metadata)
            serversUrl.insert(metadata.serverUrl)
            accounts.insert(metadata.account)

            // File System
            let fileNamePath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocIdTransfer, userId: metadata.userId, urlBase: metadata.urlBase)

            if metadata.sessionSelector == NCGlobal.shared.selectorUploadFileNODelete {
                let fineManeToPath = utilityFileSystem.getDirectoryProviderStorageOcId(ocId, userId: metadata.userId, urlBase: metadata.urlBase)
                await utilityFileSystem.moveFileAsync(atPath: fileNamePath, toPath: fineManeToPath)
                metadatasLocalFiles.append(metadata)
            } else {
                utilityFileSystem.removeFile(atPath: fileNamePath)
            }

            // Live Photo
            let capabilities = await NKCapabilities.shared.getCapabilities(for: metadata.account)
            if capabilities.isLivePhotoServerAvailable,
               metadata.isLivePhoto {
                metadatasLivePhoto.append(metadata)
            }

            // Auto Upload
            if metadata.sessionSelector == self.global.selectorUploadAutoUpload,
               let serverUrlBase = metadata.autoUploadServerUrlBase {
                autoUploadTransfers.append(tableAutoUploadTransfer(account: metadata.account,
                                                                 serverUrlBase: serverUrlBase,
                                                                 fileName: metadata.fileNameView,
                                                                 assetLocalIdentifier: metadata.assetLocalIdentifier,
                                                                 date: metadata.creationDate as Date))
            }

            await NCMetadataStore.shared.removeItem(forOcIdTransfer: metadata.ocIdTransfer)
        }

        // Metadatas
        await NCManageDatabase.shared.replaceMetadataAsync(ocIdTransfers: ocIdTransfers, metadatas: metadatasUploaded)
        // Local File
        if !metadatasLocalFiles.isEmpty {
            await NCManageDatabase.shared.addLocalFilesAsync(metadatas: metadatasLocalFiles)
        }
        // Live Photo
        if !metadatasLivePhoto.isEmpty {
            await NCManageDatabase.shared.setLivePhotoVideo(metadatas: metadatasLivePhoto)
            for account in accounts {
                await NCNetworking.shared.setLivePhoto(account: account)
            }
        }
        // Auto Upload
        if !autoUploadTransfers.isEmpty {
            await NCManageDatabase.shared.addAutoUploadTransferAsync(autoUploadTransfers)
        }

        return Array(serversUrl)
    }

    // MARK: -

    func uploadComplete(withMetadata metadata: tableMetadata,
                        ocId: String?,
                        etag: String?,
                        date: Date?,
                        size: Int64,
                        error: NKError) async {
        await NextcloudKit.shared.nkCommonInstance.appendServerErrorAccount(metadata.account, errorCode: error.errorCode)

        if error == .success, let ocId {
            await NCMetadataStore.shared.setUploadCompleted(fileName: metadata.fileName,
                                                            serverUrl: metadata.serverUrl,
                                                            taskIdentifier: metadata.sessionTaskIdentifier,
                                                            metadata: metadata,
                                                            ocId: ocId,
                                                            etag: etag,
                                                            size: size,
                                                            date: date)
        } else {
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
    }

    func uploadCancelFile(metadata: tableMetadata) async {
        /*
        #if !EXTENSION
         NCMetadataStore.shared.removeItem(ocIdTransfer: metadata.ocIdTransfer)
        #endif
        */

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
            if error == .success {
                await NCMetadataStore.shared.setUploadCompleted(fileName: fileName,
                                                                serverUrl: serverUrl,
                                                                taskIdentifier: task.taskIdentifier,
                                                                ocId: ocId,
                                                                etag: etag,
                                                                size: size,
                                                                date: date)
            } else {
                await NCMetadataStore.shared.removeItem(fileName: fileName, serverUrl: serverUrl, taskIdentifier: task.taskIdentifier)

                if let metadata = await NCManageDatabase.shared.getMetadataAsync(predicate: NSPredicate(format: "serverUrl == %@ AND fileName == %@ AND sessionTaskIdentifier == %d", serverUrl, fileName, task.taskIdentifier)) {
                    await uploadComplete(withMetadata: metadata, ocId: ocId, etag: etag, date: date, size: size, error: error)
                } else {
                    let predicate = NSPredicate(format: "fileName == %@ AND serverUrl == %@", fileName, serverUrl)
                    await NCManageDatabase.shared.deleteMetadataAsync(predicate: predicate)
                }
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

            await NCMetadataStore.shared.transferProgress(serverUrl: serverUrl,
                                                          fileName: fileName,
                                                          taskIdentifier: task.taskIdentifier,
                                                          progress: Double(progress))

            await NCManageDatabase.shared.setMetadataProgress(fileName: fileName, serverUrl: serverUrl, taskIdentifier: task.taskIdentifier, progress: Double(progress))

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
