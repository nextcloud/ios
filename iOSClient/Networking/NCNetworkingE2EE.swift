//
//  NCNetworkingE2EE.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 05/05/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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
import OpenSSL
import NCCommunication
import CFNetwork
import Alamofire

@objc class NCNetworkingE2EE: NSObject {
    @objc public static let shared: NCNetworkingE2EE = {
        let instance = NCNetworkingE2EE()
        return instance
    }()

    // MARK: - WebDav Create Folder

    func createFolder(fileName: String, serverUrl: String, account: String, urlBase: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String) -> Void) {

        var fileNameFolder = CCUtility.removeForbiddenCharactersServer(fileName)!
        var fileNameFolderUrl = ""
        var fileNameIdentifier = ""
        var key: NSString?
        var initializationVector: NSString?

        fileNameFolder = NCUtilityFileSystem.shared.createFileName(fileNameFolder, serverUrl: serverUrl, account: account)
        if fileNameFolder.count == 0 {
            return completion(0, "")
        }
        fileNameIdentifier = CCUtility.generateRandomIdentifier()
        fileNameFolderUrl = serverUrl + "/" + fileNameIdentifier

        self.lock(account: account, serverUrl: serverUrl) { directory, e2eToken, errorCode, errorDescription in
            if errorCode == 0 && e2eToken != nil && directory != nil {

                NCCommunication.shared.createFolder(fileNameFolderUrl, addCustomHeaders: ["e2e-token": e2eToken!]) { account, ocId, _, errorCode, errorDescription in
                    if errorCode == 0 {
                        guard let fileId = NCUtility.shared.ocIdToFileId(ocId: ocId) else {
                            // unlock
                            if let tableLock = NCManageDatabase.shared.getE2ETokenLock(account: account, serverUrl: serverUrl) {
                                NCCommunication.shared.lockE2EEFolder(fileId: tableLock.fileId, e2eToken: tableLock.e2eToken, method: "DELETE") { _, _, _, _ in }
                            }
                            return completion(NCGlobal.shared.errorInternalError, "Error convert ocId")
                        }
                        NCCommunication.shared.markE2EEFolder(fileId: fileId, delete: false) { account, errorCode, errorDescription in
                            if errorCode == 0 {

                                let object = tableE2eEncryption()

                                NCEndToEndEncryption.sharedManager()?.encryptkey(&key, initializationVector: &initializationVector)

                                object.account = account
                                object.authenticationTag = nil
                                object.fileName = fileNameFolder
                                object.fileNameIdentifier = fileNameIdentifier
                                object.fileNamePath = ""
                                object.key = key! as String
                                object.initializationVector = initializationVector! as String

                                if let result = NCManageDatabase.shared.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) {
                                    object.metadataKey = result.metadataKey
                                    object.metadataKeyIndex = result.metadataKeyIndex
                                } else {
                                    object.metadataKey = (NCEndToEndEncryption.sharedManager()?.generateKey(16)?.base64EncodedString(options: []))! as String // AES_KEY_128_LENGTH
                                    object.metadataKeyIndex = 0
                                }
                                object.mimeType = "httpd/unix-directory"
                                object.serverUrl = serverUrl
                                object.version = 1

                                NCManageDatabase.shared.addE2eEncryption(object)

                                self.sendE2EMetadata(account: account, serverUrl: serverUrl, fileNameRename: nil, fileNameNewRename: nil, deleteE2eEncryption: nil, urlBase: urlBase) { e2eToken, errorCode, errorDescription in
                                    // unlock
                                    if let tableLock = NCManageDatabase.shared.getE2ETokenLock(account: account, serverUrl: serverUrl) {
                                        NCCommunication.shared.lockE2EEFolder(fileId: tableLock.fileId, e2eToken: tableLock.e2eToken, method: "DELETE") { _, _, _, _ in }
                                    }
                                    if errorCode == 0 {
                                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterCreateFolder, userInfo: nil)
                                    }
                                    completion(errorCode, errorDescription)
                                }

                            } else {
                                // unlock
                                if let tableLock = NCManageDatabase.shared.getE2ETokenLock(account: account, serverUrl: serverUrl) {
                                    NCCommunication.shared.lockE2EEFolder(fileId: tableLock.fileId, e2eToken: tableLock.e2eToken, method: "DELETE") { _, _, _, _ in }
                                }
                                completion(errorCode, errorDescription)
                            }
                        }

                    } else {
                        // unlock
                        if let tableLock = NCManageDatabase.shared.getE2ETokenLock(account: account, serverUrl: serverUrl) {
                            NCCommunication.shared.lockE2EEFolder(fileId: tableLock.fileId, e2eToken: tableLock.e2eToken, method: "DELETE") { _, _, _, _ in }
                        }
                        completion(errorCode, errorDescription)
                    }
                }
            } else {
                completion(errorCode, errorDescription ?? "")
            }
        }
    }

    // MARK: - WebDav Delete

    func deleteMetadata(_ metadata: tableMetadata, completion: @escaping (_ errorCode: Int, _ errorDescription: String) -> Void) {

        self.lock(account: metadata.account, serverUrl: metadata.serverUrl) { directory, e2eToken, errorCode, errorDescription in
            if errorCode == 0 && e2eToken != nil && directory != nil {
                let deleteE2eEncryption = NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", metadata.account, metadata.serverUrl, metadata.fileName)
                NCNetworking.shared.deleteMetadataPlain(metadata, addCustomHeaders: ["e2e-token": e2eToken!]) { errorCode, errorDescription in

                    let home = NCUtilityFileSystem.shared.getHomeServer(account: metadata.account)
                    if metadata.serverUrl != home {
                        self.sendE2EMetadata(account: metadata.account, serverUrl: metadata.serverUrl, fileNameRename: nil, fileNameNewRename: nil, deleteE2eEncryption: deleteE2eEncryption, urlBase: metadata.urlBase) { e2eToken, errorCode, errorDescription in
                            // unlock
                            if let tableLock = NCManageDatabase.shared.getE2ETokenLock(account: metadata.account, serverUrl: metadata.serverUrl) {
                                NCCommunication.shared.lockE2EEFolder(fileId: tableLock.fileId, e2eToken: tableLock.e2eToken, method: "DELETE") { _, _, _, _ in }
                            }
                            completion(errorCode, errorDescription)
                        }
                    } else {
                        // unlock
                        if let tableLock = NCManageDatabase.shared.getE2ETokenLock(account: metadata.account, serverUrl: metadata.serverUrl) {
                            NCCommunication.shared.lockE2EEFolder(fileId: tableLock.fileId, e2eToken: tableLock.e2eToken, method: "DELETE") { _, _, _, _ in }
                        }
                        completion(errorCode, errorDescription)
                    }
                }
            } else {
                completion(errorCode, errorDescription ?? "")
            }
        }
    }

    // MARK: - WebDav Rename

    func renameMetadata(_ metadata: tableMetadata, fileNameNew: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String?) -> Void) {

        // verify if exists the new fileName
        if NCManageDatabase.shared.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, fileNameNew)) != nil {

            completion(NCGlobal.shared.errorInternalError, "_file_already_exists_")

        } else {

            self.sendE2EMetadata(account: metadata.account, serverUrl: metadata.serverUrl, fileNameRename: metadata.fileName, fileNameNewRename: fileNameNew, deleteE2eEncryption: nil, urlBase: metadata.urlBase) { e2eToken, errorCode, errorDescription in

                if errorCode == 0 {
                    NCManageDatabase.shared.setMetadataFileNameView(serverUrl: metadata.serverUrl, fileName: metadata.fileName, newFileNameView: fileNameNew, account: metadata.account)

                    // Move file system
                    let atPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + metadata.fileNameView
                    let toPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + fileNameNew
                    do {
                        try FileManager.default.moveItem(atPath: atPath, toPath: toPath)
                    } catch { }

                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterRenameFile, userInfo: ["ocId": metadata.ocId])
                }

                // unlock
                if let tableLock = NCManageDatabase.shared.getE2ETokenLock(account: metadata.account, serverUrl: metadata.serverUrl) {
                    NCCommunication.shared.lockE2EEFolder(fileId: tableLock.fileId, e2eToken: tableLock.e2eToken, method: "DELETE") { _, _, _, _ in }
                }

                completion(errorCode, errorDescription)
            }
        }
    }

    // MARK: - Upload

    func upload(metadata: tableMetadata, start: @escaping () -> Void, completion: @escaping (_ errorCode: Int, _ errorDescription: String) -> Void) {

        let objectE2eEncryption = tableE2eEncryption()
        var key: NSString?, initializationVector: NSString?, authenticationTag: NSString?
        let ocIdTemp = metadata.ocId
        let serverUrl = metadata.serverUrl

        // Verify max size
        if metadata.size > NCGlobal.shared.e2eeMaxFileSize {
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp))

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "ocIdTemp": ocIdTemp, "errorCode": NCGlobal.shared.errorInternalError, "errorDescription": "E2E Error file too big"])
            start()
            return completion(NCGlobal.shared.errorInternalError, "E2E Error file too big")
        }

        // Update metadata
        var metadata = tableMetadata.init(value: metadata)
        metadata.fileName = CCUtility.generateRandomIdentifier()!
        metadata.e2eEncrypted = true
        metadata.session = NCCommunicationCommon.shared.sessionIdentifierUpload
        metadata.sessionError = ""
        NCManageDatabase.shared.addMetadata(metadata)

        let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)!
        let fileNameLocalPathRequest = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
        let serverUrlFileName = serverUrl + "/" + metadata.fileName

        if NCEndToEndEncryption.sharedManager()?.encryptFileName(metadata.fileNameView, fileNameIdentifier: metadata.fileName, directory: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId), key: &key, initializationVector: &initializationVector, authenticationTag: &authenticationTag) == false {

            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp))
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "ocIdTemp": ocIdTemp, "errorCode": NCGlobal.shared.errorInternalError, "errorDescription": "_e2e_error_create_encrypted_"])
            start()
            return completion(NCGlobal.shared.errorInternalError, "_e2e_error_create_encrypted_")
        }

        if let result = NCManageDatabase.shared.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, serverUrl)) {
            objectE2eEncryption.metadataKey = result.metadataKey
            objectE2eEncryption.metadataKeyIndex = result.metadataKeyIndex
        } else {
            let key = NCEndToEndEncryption.sharedManager()?.generateKey(16) as NSData?
            objectE2eEncryption.metadataKey = key!.base64EncodedString()
            objectE2eEncryption.metadataKeyIndex = 0
        }

        objectE2eEncryption.account = metadata.account
        objectE2eEncryption.authenticationTag = authenticationTag as String?
        objectE2eEncryption.fileName = metadata.fileNameView
        objectE2eEncryption.fileNameIdentifier = metadata.fileName
        objectE2eEncryption.fileNamePath = fileNameLocalPath
        objectE2eEncryption.key = key! as String
        objectE2eEncryption.initializationVector = initializationVector! as String
        objectE2eEncryption.mimeType = metadata.contentType
        objectE2eEncryption.serverUrl = serverUrl
        objectE2eEncryption.version = 1

        NCManageDatabase.shared.addE2eEncryption(objectE2eEncryption)

        if let getMetadata = NCManageDatabase.shared.getMetadataFromOcId(ocIdTemp) {
            metadata = getMetadata
        } else {
            start()
            return completion(NCGlobal.shared.errorInternalError, "_e2e_error_create_encrypted_")
        }

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl])

        NCContentPresenter.shared.noteTop(text: NSLocalizedString("_upload_e2ee_", comment: ""), image: nil, type: NCContentPresenter.messageType.info, delay: NCGlobal.shared.dismissAfterSecond, priority: .max)

        NCNetworkingE2EE.shared.sendE2EMetadata(account: metadata.account, serverUrl: serverUrl, fileNameRename: nil, fileNameNewRename: nil, deleteE2eEncryption: nil, urlBase: metadata.urlBase, upload: true) { e2eToken, errorCode, errorDescription in

            start()

            if errorCode == 0 && e2eToken != nil {

                NCCommunication.shared.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, dateCreationFile: metadata.date as Date, dateModificationFile: metadata.date as Date, addCustomHeaders: ["e2e-token": e2eToken!], requestHandler: { request in

                    NCNetworking.shared.uploadRequest[fileNameLocalPathRequest] = request
                    NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: nil, sessionSelector: nil, sessionTaskIdentifier: nil, status: NCGlobal.shared.metadataStatusUploading)

                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadStartFile, userInfo: ["ocId": metadata.ocId])

                }, taskHandler: { _ in

                }, progressHandler: { progress in

                    NotificationCenter.default.postOnMainThread(
                        name: NCGlobal.shared.notificationCenterProgressTask,
                        userInfo: [
                            "account": metadata.account,
                            "ocId": metadata.ocId,
                            "fileName": metadata.fileName,
                            "serverUrl": serverUrl,
                            "status": NSNumber(value: NCGlobal.shared.metadataStatusInUpload),
                            "progress": NSNumber(value: progress.fractionCompleted),
                            "totalBytes": NSNumber(value: progress.totalUnitCount),
                            "totalBytesExpected": NSNumber(value: progress.completedUnitCount)])

                }) { account, ocId, etag, date, _, _, error, errorCode, errorDescription in

                    NCNetworking.shared.uploadRequest[fileNameLocalPath] = nil

                    if let metadata = NCManageDatabase.shared.getMetadataFromOcId(metadata.ocId) {

                        let metadata = tableMetadata.init(value: metadata)

                        if error?.isExplicitlyCancelledError ?? false {

                            CCUtility.removeFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "ocIdTemp": ocIdTemp, "errorCode": errorCode, "errorDescription": ""])
                            completion(0, "")

                        } else if errorCode == 0 && ocId != nil {

                            NCUtilityFileSystem.shared.moveFileInBackground(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId), toPath: CCUtility.getDirectoryProviderStorageOcId(ocId))

                            metadata.date = date ?? NSDate()
                            metadata.etag = etag ?? ""
                            metadata.ocId = ocId!

                            metadata.session = ""
                            metadata.sessionError = ""
                            metadata.sessionTaskIdentifier = 0
                            metadata.status = NCGlobal.shared.metadataStatusNormal

                            NCManageDatabase.shared.addMetadata(metadata)
                            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp))
                            NCManageDatabase.shared.addLocalFile(metadata: metadata)

                            NCUtility.shared.createImageFrom(fileName: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)

                            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "ocIdTemp": ocIdTemp, "errorCode": errorCode, "errorDescription": ""])

                        } else {

                            if errorCode == 401 || errorCode == 403 {

                                #if !EXTENSION
                                NCNetworkingCheckRemoteUser.shared.checkRemoteUser(account: metadata.account, errorCode: errorCode, errorDescription: errorDescription)
                                #endif
                                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: errorDescription, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusUploadError)
                                
                            } else {

                                NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: errorDescription, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusUploadError)
                            }

                            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "ocIdTemp": ocIdTemp, "errorCode": errorCode, "errorDescription": ""])
                        }
                    }

                    NCNetworkingE2EE.shared.unlock(account: metadata.account, serverUrl: serverUrl) { _, _, _, _ in
                        completion(errorCode, errorDescription)
                    }
                }

            } else {

                if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocIdTemp) {
                    NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: errorDescription, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusUploadError)

                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "ocIdTemp": ocIdTemp, "errorCode": errorCode, "errorDescription": errorDescription])
                }
                completion(errorCode, errorDescription)
            }
        }
    }

    // MARK: - E2EE

    @objc func lock(account: String, serverUrl: String, completion: @escaping (_ direcrtory: tableDirectory?, _ e2eToken: String?, _ errorCode: Int, _ errorDescription: String?) -> Void) {

        var e2eToken: String?

        guard let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) else {
            return completion(nil, nil, 0, "")
        }

        if let tableLock = NCManageDatabase.shared.getE2ETokenLock(account: account, serverUrl: serverUrl) {
            e2eToken = tableLock.e2eToken
        }

        NCCommunication.shared.lockE2EEFolder(fileId: directory.fileId, e2eToken: e2eToken, method: "POST") { account, e2eToken, errorCode, errorDescription in
            if errorCode == 0 && e2eToken != nil {
                NCManageDatabase.shared.setE2ETokenLock(account: account, serverUrl: serverUrl, fileId: directory.fileId, e2eToken: e2eToken!)
            }
            completion(directory, e2eToken, errorCode, errorDescription)
        }
    }

    @objc func unlock(account: String, serverUrl: String, completion: @escaping (_ direcrtory: tableDirectory?, _ e2eToken: String?, _ errorCode: Int, _ errorDescription: String?) -> Void) {

        var e2eToken: String?

        guard let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) else {
            return completion(nil, nil, 0, "")
        }

        if let tableLock = NCManageDatabase.shared.getE2ETokenLock(account: account, serverUrl: serverUrl) {
            e2eToken = tableLock.e2eToken
        }

        NCCommunication.shared.lockE2EEFolder(fileId: directory.fileId, e2eToken: e2eToken, method: "DELETE") { account, e2eToken, errorCode, errorDescription in
            if errorCode == 0 {
                NCManageDatabase.shared.deteleE2ETokenLock(account: account, serverUrl: serverUrl)
            }
            completion(directory, e2eToken, errorCode, errorDescription)
        }
    }

    @objc func sendE2EMetadata(account: String, serverUrl: String, fileNameRename: String?, fileNameNewRename: String?, deleteE2eEncryption: NSPredicate?, urlBase: String, upload: Bool = false, completion: @escaping (_ e2eToken: String?, _ errorCode: Int, _ errorDescription: String) -> Void) {

        self.lock(account: account, serverUrl: serverUrl) { directory, e2eToken, errorCode, errorDescription in
            if errorCode == 0 && e2eToken != nil && directory != nil {

                NCCommunication.shared.getE2EEMetadata(fileId: directory!.fileId, e2eToken: e2eToken) { account, e2eMetadata, errorCode, errorDescription in
                    var method = "POST"
                    var e2eMetadataNew: String?

                    if errorCode == 0 && e2eMetadata != nil {
                        if !NCEndToEndMetadata.shared.decoderMetadata(e2eMetadata!, privateKey: CCUtility.getEndToEndPrivateKey(account), serverUrl: serverUrl, account: account, urlBase: urlBase) {
                            return completion(e2eToken, NCGlobal.shared.errorInternalError, NSLocalizedString("_e2e_error_encode_metadata_", comment: ""))
                        }
                        method = "PUT"
                    }

                    // Rename
                    if fileNameRename != nil && fileNameNewRename != nil {
                        NCManageDatabase.shared.renameFileE2eEncryption(serverUrl: serverUrl, fileNameIdentifier: fileNameRename!, newFileName: fileNameNewRename!, newFileNamePath: CCUtility.returnFileNamePath(fromFileName: fileNameNewRename!, serverUrl: serverUrl, urlBase: urlBase, account: account))
                    }

                    // Delete
                    if deleteE2eEncryption != nil {
                        NCManageDatabase.shared.deleteE2eEncryption(predicate: deleteE2eEncryption!)
                    }

                    // Rebuild metadata for send it
                    let tableE2eEncryption = NCManageDatabase.shared.getE2eEncryptions(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl))
                    if tableE2eEncryption != nil {
                        e2eMetadataNew = NCEndToEndMetadata.shared.encoderMetadata(tableE2eEncryption!, privateKey: CCUtility.getEndToEndPrivateKey(account), serverUrl: serverUrl)
                    } else {
                        method = "DELETE"
                    }

                    NCCommunication.shared.putE2EEMetadata(fileId: directory!.fileId, e2eToken: e2eToken!, e2eMetadata: e2eMetadataNew, method: method) { account, _, errorCode, errorDescription in

                        if upload {
                            completion(e2eToken, errorCode, errorDescription)
                        } else {
                            self.unlock(account: account, serverUrl: serverUrl) { _, e2eToken, _, _ in
                                completion(e2eToken, errorCode, errorDescription)
                            }
                        }
                    }
                }
            } else {
                completion(e2eToken, errorCode, errorDescription ?? "")
            }
        }
    }
}
