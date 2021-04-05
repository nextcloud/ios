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

import Foundation
import NCCommunication
import Queuer

extension NCNetworking {
    
    internal func uploadChunkedFile(metadata: tableMetadata, userId: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        let directoryProviderStorageOcId = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId)!
        let chunkFolder = NCManageDatabase.shared.getChunkFolder(account: metadata.account, ocId: metadata.ocId)
        let chunkFolderPath = metadata.urlBase + "/" + NCUtilityFileSystem.shared.getDAV() + "/uploads/" + userId + "/" + chunkFolder
        let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
        let chunkSize = CCUtility.getChunkSize()
        
        var uploadErrorCode: Int = 0
        var uploadErrorDescription: String = ""
        var counterFileNameInUpload: Int = 0
        var filesNames = NCManageDatabase.shared.getChunks(account: metadata.account, ocId: metadata.ocId)
        
        if filesNames.count == 0 {
                        
            if let chunkedFilesNames = NCCommunicationCommon.shared.chunkedFile(path: directoryProviderStorageOcId, fileName: metadata.fileName, outPath: directoryProviderStorageOcId, sizeInMB: chunkSize) {
                filesNames = chunkedFilesNames
                NCManageDatabase.shared.addChunks(account: metadata.account, ocId: metadata.ocId, chunkFolder: chunkFolder, fileNames: filesNames)
                
                completion(uploadErrorCode, uploadErrorDescription)

            } else {
                
                NCContentPresenter.shared.messageNotification("_error_", description: "_err_file_not_found_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode:NCGlobal.shared.errorReadFile, forced: true)
                
                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                
                completion(uploadErrorCode, uploadErrorDescription)
                return
            }
        }

        NCContentPresenter.shared.messageNotification("_info_", description: "_upload_chunk_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.info, errorCode:0, forced: false)
        
        createChunkedFolder(chunkFolderPath: chunkFolderPath, account: metadata.account) { (errorCode, errorDescription) in
            
            if errorCode == 0 {
                    
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadStartFile, userInfo: ["ocId": metadata.ocId])
                
                DispatchQueue.global(qos: .background).async {
                        
                    for fileName in filesNames {
                                                
                        let serverUrlFileName = chunkFolderPath + "/" + fileName
                        let fileNameChunkLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: fileName)!
                        
                        let semaphore = Semaphore()
                                                    
                        NCCommunication.shared.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameChunkLocalPath, requestHandler: { (request) in
                                
                            self.uploadRequest[fileNameLocalPath] = request
                            
                            counterFileNameInUpload += 1

                            let progress: Float = Float(counterFileNameInUpload) / Float(filesNames.count)
                            let totalBytes: Int64 = (metadata.size / Int64(filesNames.count)) * Int64(counterFileNameInUpload)
                            let totalBytesExpected: Int64 = metadata.size

                            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterProgressTask, userInfo: ["account":metadata.account, "ocId":metadata.ocId, "serverUrl":metadata.serverUrl, "status":NSNumber(value: NCGlobal.shared.metadataStatusInUpload), "progress":NSNumber(value: progress), "totalBytes":NSNumber(value: totalBytes), "totalBytesExpected":NSNumber(value: totalBytesExpected)])
                            
                        }, taskHandler: { (task) in
                            
                            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, sessionError: "", sessionTaskIdentifier: task.taskIdentifier, status: NCGlobal.shared.metadataStatusUploading)
                           
                        }, progressHandler: { (_) in
                            
                        }) { (_, _, _, _, _, _, _, errorCode, errorDescription) in
                               
                            self.uploadRequest[fileNameLocalPath] = nil
                            uploadErrorCode = errorCode
                            uploadErrorDescription = errorDescription
                            semaphore.continue()
                        }
                            
                        semaphore.wait()
                            
                        if uploadErrorCode == 0 {
                            NCManageDatabase.shared.deleteChunk(account: metadata.account, ocId: metadata.ocId, fileName: fileName)
                        } else {
                            break
                        }
                    }
                        
                    if uploadErrorCode == 0 {
                            
                        // Assembling the chunks
                            
                        let serverUrlFileNameSource = chunkFolderPath + "/.file"
                        let pathServerUrl = CCUtility.returnPathfromServerUrl(metadata.serverUrl, urlBase: metadata.urlBase, account: metadata.account)!
                        let serverUrlFileNameDestination = metadata.urlBase + "/" + NCUtilityFileSystem.shared.getDAV() + "/files/" + userId + pathServerUrl + "/" + metadata.fileName
                        
                        var addCustomHeaders: [String:String] = [:]
                        let creationDate = "\(metadata.creationDate.timeIntervalSince1970)"
                        let modificationDate = "\(metadata.date.timeIntervalSince1970)"
                            
                        addCustomHeaders["X-OC-CTime"] = creationDate
                        addCustomHeaders["X-OC-MTime"] = modificationDate

                        NCCommunication.shared.moveFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: true, addCustomHeaders: addCustomHeaders) { (_, errorCode, errorDescription) in
                                                    
                            if errorCode == 0 {
                                
                                let serverUrl = metadata.serverUrl

                                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                                NCManageDatabase.shared.deleteChunks(account: metadata.account, ocId: metadata.ocId)
                                NCUtilityFileSystem.shared.deleteFile(filePath: directoryProviderStorageOcId)

                                self.readFile(serverUrlFileName: serverUrlFileNameDestination, account: metadata.account) { (_, metadata, _, _) in
                                        
                                    if errorCode == 0, let metadata = metadata {
                                        
                                        NCManageDatabase.shared.addMetadata(metadata)
                                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["serverUrl":serverUrl])
                                        
                                    } else {
                                        
                                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSourceNetworkForced, userInfo: ["serverUrl": serverUrl])
                                    }
                                }
                                
                            } else {
                                
                                self.uploadChunkFileError(metadata: metadata, chunkFolderPath: chunkFolderPath, directoryProviderStorageOcId: directoryProviderStorageOcId, errorCode: errorCode, errorDescription: errorDescription)
                            }
                        }
                                                        
                    } else {
                            
                        NCCommunication.shared.deleteFileOrFolder(chunkFolderPath) { (_, _, _) in
                                
                            self.uploadChunkFileError(metadata: metadata, chunkFolderPath: chunkFolderPath, directoryProviderStorageOcId: directoryProviderStorageOcId, errorCode: uploadErrorCode, errorDescription: uploadErrorDescription)
                        }
                    }
                }
                
            } else {
                
                self.uploadChunkFileError(metadata: metadata, chunkFolderPath: chunkFolderPath, directoryProviderStorageOcId: directoryProviderStorageOcId, errorCode: errorCode, errorDescription: errorDescription)
            }
        }
    }
    
    private func createChunkedFolder(chunkFolderPath: String, account: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        NCCommunication.shared.readFileOrFolder(serverUrlFileName: chunkFolderPath, depth: "0", showHiddenFiles: CCUtility.getShowHiddenFiles()) { (_, _, _, errorCode, errorDescription) in
        
            if errorCode == 0 {
                completion(0, "")
            } else if errorCode == NCGlobal.shared.errorResourceNotFound {
                NCCommunication.shared.createFolder(chunkFolderPath) { (_, _, _, errorCode, errorDescription) in
                    completion(errorCode, errorDescription)
                }
            } else {
                completion(errorCode, errorDescription)
            }
        }
    }

    private func uploadChunkFileError(metadata: tableMetadata, chunkFolderPath: String, directoryProviderStorageOcId: String, errorCode: Int, errorDescription: String) {
        
        if errorCode == NSURLErrorCancelled || errorCode == NCGlobal.shared.errorRequestExplicityCancelled {
            
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NCManageDatabase.shared.deleteChunks(account: metadata.account, ocId: metadata.ocId)
            NCUtilityFileSystem.shared.deleteFile(filePath: directoryProviderStorageOcId)
            
            NCCommunication.shared.deleteFileOrFolder(chunkFolderPath) { (_, _, _) in }
            
        } else {
                        
            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: errorDescription, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusUploadError)
            
            let description = errorDescription + " code: \(errorCode)"
            NCContentPresenter.shared.messageNotification("_error_", description: description, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorInternalError, forced: true)
        }
        
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["serverUrl":metadata.serverUrl])
    }
}
