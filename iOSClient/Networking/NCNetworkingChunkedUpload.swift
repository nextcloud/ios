//
//  NCNetworkingUploadChunk.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 05/04/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
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

extension NCNetworking {

    internal func uploadChunkedFile(metadata: tableMetadata,
                                    start: @escaping () -> () = { },
                                    progressHandler: @escaping (_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double) -> () = { _, _, _ in },
                                    completion: @escaping (_ error: NKError) -> Void) {

        let directoryProviderStorageOcId = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId)!
        let chunkFolder = NCManageDatabase.shared.getChunkFolder(account: metadata.account, ocId: metadata.ocId)
        let chunkFolderPath = metadata.urlBase + "/" + NextcloudKit.shared.nkCommonInstance.dav + "/uploads/" + metadata.userId + "/" + chunkFolder
        let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
        let chunkSize = CCUtility.getChunkSize()
        let fileSizeInGB = Double(metadata.size) / 1e9
        let ocIdTemp = metadata.ocId
        let selector = metadata.sessionSelector
        var uploadError = NKError()

        var filesNames = NCManageDatabase.shared.getChunks(account: metadata.account, ocId: metadata.ocId)
        if filesNames.count == 0 {
            NCContentPresenter.shared.noteTop(text: NSLocalizedString("_upload_chunk_", comment: ""), image: nil, type: NCContentPresenter.messageType.info, delay: .infinity, priority: .max)
            filesNames = NextcloudKit.shared.nkCommonInstance.chunkedFile(inputDirectory: directoryProviderStorageOcId, outputDirectory: directoryProviderStorageOcId, fileName: metadata.fileName, chunkSizeMB: chunkSize)
            if filesNames.count > 0 {
                NCManageDatabase.shared.addChunks(account: metadata.account, ocId: metadata.ocId, chunkFolder: chunkFolder, fileNames: filesNames)
            } else {
                NCContentPresenter.shared.dismiss()
                let error = NKError(errorCode: NCGlobal.shared.errorReadFile, errorDescription: "_err_file_not_found_")
                NCContentPresenter.shared.showError(error: error)
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                return completion(uploadError)
            }
        } else {
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["serverUrl": metadata.serverUrl])
        }

        createChunkedFolder(chunkFolderPath: chunkFolderPath, account: metadata.account) { error in

            NCContentPresenter.shared.dismiss(after: NCGlobal.shared.dismissAfterSecond)

            guard error == .success else {
                self.uploadChunkFileError(metadata: metadata, chunkFolderPath: chunkFolderPath, directoryProviderStorageOcId: directoryProviderStorageOcId, error: error)
                completion(error)
                return
            }

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadStartFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "sessionSelector": metadata.sessionSelector])

            start()

            for fileName in filesNames {

                let serverUrlFileName = chunkFolderPath + "/" + fileName
                let fileNameChunkLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: fileName)!

                var size: Int64?
                if let tableChunk = NCManageDatabase.shared.getChunk(account: metadata.account, fileName: fileName) {
                    size = tableChunk.size - NCUtilityFileSystem.shared.getFileSize(filePath: fileNameChunkLocalPath)
                }

                let semaphore = DispatchSemaphore(value: 0)

                NextcloudKit.shared.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameChunkLocalPath, requestHandler: { request in

                    self.uploadRequest[fileNameLocalPath] = request

                }, taskHandler: { task in

                    NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, sessionError: "", sessionTaskIdentifier: task.taskIdentifier, status: NCGlobal.shared.metadataStatusUploading)
                    NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Upload chunk: " + fileName)

                }, progressHandler: { progress in

                    if let size = size {
                        let totalBytesExpected = metadata.size
                        let totalBytes = size + progress.completedUnitCount
                        let fractionCompleted = Double(totalBytes) / Double(totalBytesExpected)

                        NotificationCenter.default.postOnMainThread(
                            name: NCGlobal.shared.notificationCenterProgressTask,
                            object: nil,
                            userInfo: [
                                "account": metadata.account,
                                "ocId": metadata.ocId,
                                "fileName": metadata.fileName,
                                "serverUrl": metadata.serverUrl,
                                "status": NSNumber(value: NCGlobal.shared.metadataStatusInUpload),
                                "progress": NSNumber(value: fractionCompleted),
                                "totalBytes": NSNumber(value: totalBytes),
                                "totalBytesExpected": NSNumber(value: totalBytesExpected)])

                        progressHandler(totalBytesExpected, totalBytes, fractionCompleted)
                    }

                }) { _, _, _, _, _, _, _, error in

                    self.uploadRequest.removeValue(forKey: fileNameLocalPath)
                    uploadError = error
                    semaphore.signal()
                }

                semaphore.wait()

                if uploadError == .success {
                    NCManageDatabase.shared.deleteChunk(account: metadata.account, ocId: metadata.ocId, fileName: fileName)
                } else {
                    break
                }
            }

            guard uploadError == .success else {
                self.uploadChunkFileError(metadata: metadata, chunkFolderPath: chunkFolderPath, directoryProviderStorageOcId: directoryProviderStorageOcId, error: uploadError)
                completion(error)
                return
            }

            // Assembling the chunks
            let serverUrlFileNameSource = chunkFolderPath + "/.file"
            let pathServerUrl = CCUtility.returnPathfromServerUrl(metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId, account: metadata.account)!
            let serverUrlFileNameDestination = metadata.urlBase + "/" + NextcloudKit.shared.nkCommonInstance.dav + "/files/" + metadata.userId + pathServerUrl + "/" + metadata.fileName

            var customHeader: [String: String] = [:]
            let creationDate = "\(metadata.creationDate.timeIntervalSince1970)"
            let modificationDate = "\(metadata.date.timeIntervalSince1970)"

            customHeader["X-OC-CTime"] = creationDate
            customHeader["X-OC-MTime"] = modificationDate

            // Calculate Assemble Timeout
            let ASSEMBLE_TIME_PER_GB: Double    = 3 * 60            // 3  min
            let ASSEMBLE_TIME_MIN: Double       = 60                // 60 sec
            let ASSEMBLE_TIME_MAX: Double       = 30 * 60           // 30 min
            let timeout = max(ASSEMBLE_TIME_MIN, min(ASSEMBLE_TIME_PER_GB * fileSizeInGB, ASSEMBLE_TIME_MAX))

            let options = NKRequestOptions(customHeader: customHeader, timeout: timeout, queue: DispatchQueue.global())
            
            NextcloudKit.shared.moveFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: true, options: options) { _, error in

                NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Assembling chunk with error code: \(error.errorCode)")

                guard error == .success else {
                    self.uploadChunkFileError(metadata: metadata, chunkFolderPath: chunkFolderPath, directoryProviderStorageOcId: directoryProviderStorageOcId, error: error)
                    completion(error)
                    return
                }

                let serverUrl = metadata.serverUrl
                let assetLocalIdentifier = metadata.assetLocalIdentifier
                let isLivePhoto = metadata.livePhoto
                let account = metadata.account
                let fileName = metadata.fileName

                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp))
                NCManageDatabase.shared.deleteChunks(account: metadata.account, ocId: ocIdTemp)

                self.readFile(serverUrlFileName: serverUrlFileNameDestination) { (_, metadata, _) in

                    if error == .success, let metadata = metadata {

                        metadata.assetLocalIdentifier = assetLocalIdentifier
                        metadata.livePhoto = isLivePhoto

                        // Delete Asset on Photos album
                        if CCUtility.getRemovePhotoCameraRoll() && !metadata.assetLocalIdentifier.isEmpty {
                            metadata.deleteAssetLocalIdentifier = true
                        }
                        NCManageDatabase.shared.addMetadata(metadata)

                        if selector == NCGlobal.shared.selectorUploadFileNODelete {
                            NCUtilityFileSystem.shared.moveFile(atPath: CCUtility.getDirectoryProviderStorageOcId(ocIdTemp, fileNameView: fileName), toPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: fileName))
                            NCManageDatabase.shared.addLocalFile(metadata: metadata)
                        }
                        NCUtilityFileSystem.shared.deleteFile(filePath: directoryProviderStorageOcId)

                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["serverUrl": serverUrl])
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": serverUrl, "account": account, "fileName": fileName, "ocIdTemp": ocIdTemp, "error": error])

                    } else {

                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSourceNetworkForced)
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": ocIdTemp, "serverUrl": serverUrl, "account": account, "fileName": fileName, "ocIdTemp": ocIdTemp, "error": error])
                    }

                    completion(error)
                }
            }
        }
    }

    private func createChunkedFolder(chunkFolderPath: String, account: String, completion: @escaping (_ errorCode: NKError) -> Void) {

        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        
        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: chunkFolderPath, depth: "0", showHiddenFiles: CCUtility.getShowHiddenFiles(), options: options) { _, _, _, error in

            if error == .success {
                completion(NKError())
            } else if error.errorCode == NCGlobal.shared.errorResourceNotFound {
                NextcloudKit.shared.createFolder(serverUrlFileName: chunkFolderPath, options: options) { _, _, _, error in
                    completion(error)
                }
            } else {
                completion(error)
            }
        }
    }

    private func uploadChunkFileError(metadata: tableMetadata, chunkFolderPath: String, directoryProviderStorageOcId: String, error: NKError) {

        var errorDescription = error.errorDescription

        NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Upload chunk error code: \(error.errorCode)")

        if error.errorCode == NSURLErrorCancelled || error.errorCode == NCGlobal.shared.errorRequestExplicityCancelled {

            // Delete chunk folder
            NextcloudKit.shared.deleteFileOrFolder(serverUrlFileName: chunkFolderPath) { _, _ in }

            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NCManageDatabase.shared.deleteChunks(account: metadata.account, ocId: metadata.ocId)
            NCUtilityFileSystem.shared.deleteFile(filePath: directoryProviderStorageOcId)

            NextcloudKit.shared.deleteFileOrFolder(serverUrlFileName: chunkFolderPath) { _, _ in }

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadCancelFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account])

        } else {

            // NO report for the connection lost
            if error.errorCode == NCGlobal.shared.errorConnectionLost {
                errorDescription = ""
            } else {
                let description = errorDescription + " code: \(error.errorCode)"
                let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: description)
                NCContentPresenter.shared.showError(error: error)
            }

            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: errorDescription, sessionTaskIdentifier: NCGlobal.shared.metadataStatusNormal, status: NCGlobal.shared.metadataStatusUploadError)
        }

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": metadata.ocId, "error": error])
    }
}
