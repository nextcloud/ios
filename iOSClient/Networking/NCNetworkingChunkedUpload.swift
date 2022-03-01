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
import NCCommunication
import Queuer

extension NCNetworking {

    internal func uploadChunkedFile(metadata: tableMetadata, start: @escaping () -> Void, completion: @escaping (_ error: NCCError) -> Void) {

        let directoryProviderStorageOcId = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId)!
        let chunkFolder = NCManageDatabase.shared.getChunkFolder(account: metadata.account, ocId: metadata.ocId)
        let chunkFolderPath = metadata.urlBase + "/" + NCUtilityFileSystem.shared.getWebDAV(account: metadata.account) + "/uploads/" + metadata.userId + "/" + chunkFolder
        let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
        let chunkSize = CCUtility.getChunkSize()

        var uploadError = NCCError.success
        var filesNames = NCManageDatabase.shared.getChunks(account: metadata.account, ocId: metadata.ocId)
        if filesNames.count == 0 {

            filesNames = NCCommunicationCommon.shared.chunkedFile(inputDirectory: directoryProviderStorageOcId, outputDirectory: directoryProviderStorageOcId, fileName: metadata.fileName, chunkSizeMB: chunkSize)

            if filesNames.count > 0 {
                NCManageDatabase.shared.addChunks(account: metadata.account, ocId: metadata.ocId, chunkFolder: chunkFolder, fileNames: filesNames)
            } else {
                NCContentPresenter.shared.messageNotification("_error_", description: "_err_file_not_found_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorReadFile)
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                return completion(.success)
            }

        } else {

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["serverUrl": metadata.serverUrl])
        }

        NCContentPresenter.shared.noteTop(text: NSLocalizedString("_upload_chunk_", comment: ""), image: nil, type: NCContentPresenter.messageType.info, delay: NCGlobal.shared.dismissAfterSecond, priority: .max)

        createChunkedFolder(chunkFolderPath: chunkFolderPath, account: metadata.account) { error in

            start()

            if error.errorCode == 0 {

                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadStartFile, userInfo: ["ocId": metadata.ocId])

                for fileName in filesNames {

                    let serverUrlFileName = chunkFolderPath + "/" + fileName
                    let fileNameChunkLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: fileName)!

                    var size: Int64?
                    if let tableChunk = NCManageDatabase.shared.getChunk(account: metadata.account, fileName: fileName) {
                        size = tableChunk.size - NCUtilityFileSystem.shared.getFileSize(filePath: fileNameChunkLocalPath)
                    }

                    let semaphore = Semaphore()

                    NCCommunication.shared.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameChunkLocalPath, requestHandler: { request in

                        self.uploadRequest[fileNameLocalPath] = request

                    }, taskHandler: { task in

                        NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, sessionError: "", sessionTaskIdentifier: task.taskIdentifier, status: NCGlobal.shared.metadataStatusUploading)

                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadStartFile, userInfo: ["ocId": metadata.ocId])

                        NCCommunicationCommon.shared.writeLog("Upload chunk: " + fileName)

                    }, progressHandler: { progress in

                        if let size = size {

                            let totalBytesExpected = size + progress.completedUnitCount
                            let totalBytes = metadata.size
                            let fractionCompleted = Float(totalBytesExpected) / Float(totalBytes)

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
                        }

                    }) { _, _, _, _, _, _, _, error in

                        self.uploadRequest[fileNameLocalPath] = nil
                        uploadError = error
                        semaphore.continue()
                    }

                    semaphore.wait()

                    if uploadError.errorCode == 0 {
                        NCManageDatabase.shared.deleteChunk(account: metadata.account, ocId: metadata.ocId, fileName: fileName)
                    } else {
                        break
                    }
                }

                if uploadError.errorCode == 0 {

                    // Assembling the chunks
                    let serverUrlFileNameSource = chunkFolderPath + "/.file"
                    let pathServerUrl = CCUtility.returnPathfromServerUrl(metadata.serverUrl, urlBase: metadata.urlBase, account: metadata.account)!
                    let serverUrlFileNameDestination = metadata.urlBase + "/" + NCUtilityFileSystem.shared.getWebDAV(account: metadata.account) + "/files/" + metadata.userId + pathServerUrl + "/" + metadata.fileName

                    var addCustomHeaders: [String: String] = [:]
                    let creationDate = "\(metadata.creationDate.timeIntervalSince1970)"
                    let modificationDate = "\(metadata.date.timeIntervalSince1970)"

                    addCustomHeaders["X-OC-CTime"] = creationDate
                    addCustomHeaders["X-OC-MTime"] = modificationDate

                    NCCommunication.shared.moveFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: true, addCustomHeaders: addCustomHeaders) { _, error in

                        NCCommunicationCommon.shared.writeLog("Assembling chunk with error code: \(error.errorCode)")

                        if error.errorCode == 0 {

                            let serverUrl = metadata.serverUrl

                            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                            NCManageDatabase.shared.deleteChunks(account: metadata.account, ocId: metadata.ocId)
                            NCUtilityFileSystem.shared.deleteFile(filePath: directoryProviderStorageOcId)

                            self.readFile(serverUrlFileName: serverUrlFileNameDestination, account: metadata.account) { _, metadata, _ in

                                if error.errorCode == 0, let metadata = metadata {

                                    NCManageDatabase.shared.addMetadata(metadata)
                                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["serverUrl": serverUrl])

                                } else {

                                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSourceNetworkForced, userInfo: ["serverUrl": serverUrl])
                                }

                                completion(error)
                            }

                        } else {

                            self.uploadChunkFileError(metadata: metadata, chunkFolderPath: chunkFolderPath, directoryProviderStorageOcId: directoryProviderStorageOcId, error: error)
                            completion(error)
                        }
                    }

                } else {

                    self.uploadChunkFileError(metadata: metadata, chunkFolderPath: chunkFolderPath, directoryProviderStorageOcId: directoryProviderStorageOcId, error: error)
                    completion(error)
                }

            } else {

                self.uploadChunkFileError(metadata: metadata, chunkFolderPath: chunkFolderPath, directoryProviderStorageOcId: directoryProviderStorageOcId, error: error)
                completion(error)
            }
        }
    }

    private func createChunkedFolder(chunkFolderPath: String, account: String, completion: @escaping (_ error: NCCError) -> Void) {

        NCCommunication.shared.readFileOrFolder(serverUrlFileName: chunkFolderPath, depth: "0", showHiddenFiles: CCUtility.getShowHiddenFiles(), queue: NCCommunicationCommon.shared.backgroundQueue) { _, _, _, error in

            if error.errorCode == 0 {
                completion(.success)
            } else if error.errorCode == NCGlobal.shared.errorResourceNotFound {
                NCCommunication.shared.createFolder(chunkFolderPath, queue: NCCommunicationCommon.shared.backgroundQueue) { _, _, _, error in
                    completion(error)
                }
            } else {
                completion(error)
            }
        }
    }

    private func uploadChunkFileError(metadata: tableMetadata, chunkFolderPath: String, directoryProviderStorageOcId: String, error: NCCError) {

        var errorDescription = error.errorDescription

        NCCommunicationCommon.shared.writeLog("Upload chunk error code: \(error.errorCode)")

        if error.errorCode == NSURLErrorCancelled || error.errorCode == NCGlobal.shared.errorRequestExplicityCancelled {

            // Delete chunk folder
            NCCommunication.shared.deleteFileOrFolder(chunkFolderPath) { _, _ in }

            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NCManageDatabase.shared.deleteChunks(account: metadata.account, ocId: metadata.ocId)
            NCUtilityFileSystem.shared.deleteFile(filePath: directoryProviderStorageOcId)

            NCCommunication.shared.deleteFileOrFolder(chunkFolderPath) { _, _ in }

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadCancelFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account])

        } else {

            // NO report for the connection lost
            if error.errorCode == NCGlobal.shared.errorConnectionLost {
                errorDescription = ""
            } else {
                let description = errorDescription + " code: \(error.errorCode)"
                NCContentPresenter.shared.messageNotification("_error_", description: description, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorInternalError)
            }

            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: errorDescription, sessionTaskIdentifier: NCGlobal.shared.metadataStatusNormal, status: NCGlobal.shared.metadataStatusUploadError)
        }

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "ocIdTemp": metadata.ocId, "errorCode": error.errorCode, "errorDescription": ""])
    }
}
