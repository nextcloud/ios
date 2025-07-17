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

extension NCNetworking {
    /*
    func uploadHub(metadata: tableMetadata,
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
            let detachedMetadata = metadata.detachedCopy()
            Task {
                let error = await NCNetworkingE2EEUpload().upload(metadata: detachedMetadata, uploadE2EEDelegate: uploadE2EEDelegate, controller: controller)
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
                hud?.initHudRing(text: NSLocalizedString("_keep_active_for_upload_", comment: ""))
            } progressHandler: { _, _, fractionCompleted in
                hud?.progress(fractionCompleted)
            } completion: { account, _, error in
                hud?.dismiss()
                let directory = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase)

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
            let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView, userId: metadata.userId, urlBase: metadata.urlBase)
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
                    completion: @escaping (_ account: String, _ ocId: String?, _ etag: String?, _ date: Date?, _ size: Int64, _ headers: [AnyHashable: Any]?, _ error: NKError) -> Void) {
        let options = NKRequestOptions(customHeader: customHeaders, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        NextcloudKit.shared.upload(serverUrlFileName: metadata.serverUrlFileName, fileNameLocalPath: fileNameLocalPath, dateCreationFile: metadata.creationDate as Date, dateModificationFile: metadata.date as Date, account: metadata.account, options: options, requestHandler: { request in
            requestHandler(request)
        }, taskHandler: { task in
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
                start()
            }
        }, progressHandler: { progress in
            self.notifyAllDelegates { delegate in
                delegate.transferProgressDidUpdate(progress: Float(progress.fractionCompleted),
                                                   totalBytes: progress.totalUnitCount,
                                                   totalBytesExpected: progress.completedUnitCount,
                                                   fileName: metadata.fileName,
                                                   serverUrl: metadata.serverUrl)
            }
            progressHandler(progress.completedUnitCount, progress.totalUnitCount, progress.fractionCompleted)
        }) { account, ocId, etag, date, size, headers, error in
            var error = error
            if withUploadComplete {
                if error == .errorChunkFileNull {
                    error = NKError(errorCode: self.global.errorRequestExplicityCancelled, errorDescription: "error request explicity cancelled")
                }
                Task {
                    await self.uploadCompleteAsync(withMetadata: metadata, ocId: ocId, etag: etag, date: date, size: size, error: error)
                }
            }
            completion(account, ocId, etag, date, size, headers, error)
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
        let directory = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase)
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
                                        metadata: metadata.detachedCopy(),
                                        error: .success)
            }
        } requestHandler: { _ in
        } taskHandler: { task in
            Task {
                await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                            sessionTaskIdentifier: task.taskIdentifier,
                                                            status: self.global.metadataStatusUploading)
            }
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
                Task {
                    await self.uploadCompleteAsync(withMetadata: metadata, ocId: file?.ocId, etag: file?.etag, date: file?.date, size: file?.size ?? 0, error: error)
                }
            }
            completion(account, file, error)
        }
    }
     */
}
