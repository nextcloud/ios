//
//  NCNetworking.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 23/10/19.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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
import OpenSSL
import NCCommunication

@objc public protocol NCNetworkingDelegate {
    @objc optional func downloadProgress(_ progress: Double, fileName: String, ServerUrl: String, session: URLSession, task: URLSessionTask)
    @objc optional func uploadProgress(_ progress: Double, fileName: String, ServerUrl: String, session: URLSession, task: URLSessionTask)
    @objc optional func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: NSDate?, dateLastModified: NSDate?, length: Double, description: String?, error: Error?, statusCode: Int)
    @objc optional func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: NSDate?, size: Int64, description: String?, error: Error?, statusCode: Int)
}

@objc class NCNetworking: NSObject, NCCommunicationCommonDelegate {
    @objc public static let sharedInstance: NCNetworking = {
        let instance = NCNetworking()
        return instance
    }()
    
    var account = ""
    
    // Protocol
    var delegate: NCNetworkingDelegate?
    
    //MARK: - Setup
    
    @objc public func setup(account: String, delegate: NCNetworkingDelegate?) {
        self.account = account
        self.delegate = delegate
    }
    
    //MARK: - Communication Delegate
       
    func authenticationChallenge(_ challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if NCNetworking.sharedInstance.checkTrustedChallenge(challenge: challenge, directoryCertificate: CCUtility.getDirectoryCerificates()) {
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential.init(trust: challenge.protectionSpace.serverTrust!))
        } else {
            completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
        }
    }
    
    func downloadProgress(_ progress: Double, fileName: String, ServerUrl: String, session: URLSession, task: URLSessionTask) {
        delegate?.downloadProgress?(progress, fileName: fileName, ServerUrl: ServerUrl, session: session, task: task)
    }
    
    func uploadProgress(_ progress: Double, fileName: String, ServerUrl: String, session: URLSession, task: URLSessionTask) {
        delegate?.uploadProgress?(progress, fileName: fileName, ServerUrl: ServerUrl, session: session, task: task)
    }
    
    func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: NSDate?, size: Int64, description: String?, error: Error?, statusCode: Int) {
        delegate?.uploadComplete?(fileName: fileName, serverUrl: serverUrl, ocId: ocId, etag: etag, date: date, size:size, description: description, error: error, statusCode: statusCode)
    }
    
    func downloadComplete(fileName: String, serverUrl: String, etag: String?, date: NSDate?, dateLastModified: NSDate?, length: Double, description: String?, error: Error?, statusCode: Int) {
        delegate?.downloadComplete?(fileName: fileName, serverUrl: serverUrl, etag: etag, date: date, dateLastModified: dateLastModified, length: length, description: description, error: error, statusCode: statusCode)
    }
    
    //MARK: - Pinning check
    
    @objc func checkTrustedChallenge(challenge: URLAuthenticationChallenge, directoryCertificate: String) -> Bool {
        
        var trusted = false
        let protectionSpace: URLProtectionSpace = challenge.protectionSpace
        let directoryCertificateUrl = URL.init(fileURLWithPath: directoryCertificate)
        
        if let trust: SecTrust = protectionSpace.serverTrust {
            saveX509Certificate(trust, certName: "tmp.der", directoryCertificate: directoryCertificate)
            do {
                let directoryContents = try FileManager.default.contentsOfDirectory(at: directoryCertificateUrl, includingPropertiesForKeys: nil)
                let certTmpPath = directoryCertificate+"/"+"tmp.der"
                for file in directoryContents {
                    let certPath = file.path
                    if certPath == certTmpPath { continue }
                    if FileManager.default.contentsEqual(atPath:certTmpPath, andPath: certPath) {
                        trusted = true
                        break
                    }
                }
            } catch { print(error) }
        }
        
        return trusted
    }
    
    @objc func wrtiteCertificate(directoryCertificate: String) {
        
        let certificateAtPath = directoryCertificate + "/tmp.der"
        let certificateToPath = directoryCertificate + "/" + CCUtility.getTimeIntervalSince197() + ".der"
        
        do {
            try FileManager.default.moveItem(atPath: certificateAtPath, toPath: certificateToPath)
        } catch { }
    }
    
    private func saveX509Certificate(_ trust: SecTrust, certName: String, directoryCertificate: String) {
        
        let currentServerCert = secTrustGetLeafCertificate(trust)
        let certNamePath = directoryCertificate + "/" + certName
        let data: CFData = SecCertificateCopyData(currentServerCert!)
        let mem = BIO_new_mem_buf(CFDataGetBytePtr(data), Int32(CFDataGetLength(data)))
        let x509cert = d2i_X509_bio(mem, nil)

        BIO_free(mem)
        if x509cert == nil {
            print("[LOG] OpenSSL couldn't parse X509 Certificate")
        } else {
            if FileManager.default.fileExists(atPath: certNamePath) {
                do {
                    try FileManager.default.removeItem(atPath: certNamePath)
                } catch { }
            }
            let file = fopen(certNamePath, "w")
            if file != nil {
                PEM_write_X509(file, x509cert);
            }
            fclose(file);
            X509_free(x509cert);
        }
    }
    
    private func secTrustGetLeafCertificate(_ trust: SecTrust) -> SecCertificate? {
        
        let result: SecCertificate?
        
        if SecTrustGetCertificateCount(trust) > 0 {
            result = SecTrustGetCertificateAtIndex(trust, 0)!
            assert(result != nil);
        } else {
            result = nil
        }
        
        return result
    }
    
    //MARK: - WebDav
    
    @objc func readFolder(serverUrl: String, account: String, completion: @escaping (_ account: String, _ metadataFolder: tableMetadata?, _ metadatas: [tableMetadata]?, _ errorCode: Int, _ errorDescription: String)->()) {
        
        NCCommunication.sharedInstance.readFileOrFolder(serverUrlFileName: serverUrl, depth: "1", showHiddenFiles: CCUtility.getShowHiddenFiles(), customUserAgent: nil, addCustomHeaders: nil, account: account) { (account, files, errorCode, errorDescription) in
            
            if errorCode == 0 && files != nil {
                              
                NCManageDatabase.sharedInstance.convertNCFilesToMetadatas(files!, useMetadataFolder: true, account: account) { (metadataFolder, metadatasFolder, metadatas) in
                    
                    // Add directory
                    NCManageDatabase.sharedInstance.addDirectory(encrypted: metadataFolder.e2eEncrypted, favorite: metadataFolder.favorite, ocId: metadataFolder.ocId, fileId: metadataFolder.fileId, etag: metadataFolder.etag, permissions: metadataFolder.permissions, serverUrl: serverUrl, richWorkspace: metadataFolder.richWorkspace, account: account)
                    NCManageDatabase.sharedInstance.setDateReadDirectory(serverUrl: serverUrl, account: account)
                    
                    // Add other directories
                    for metadata in metadatasFolder {
                       let serverUrl = metadata.serverUrl + "/" + metadata.fileName
                       NCManageDatabase.sharedInstance.addDirectory(encrypted: metadata.e2eEncrypted, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, etag: nil, permissions: metadata.permissions, serverUrl: serverUrl, richWorkspace: metadata.richWorkspace, account: account)
                    }
                    
                    // Save status transfer metadata
                    let metadatasInDownload = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND (status == %d OR status == %d OR status == %d OR status == %d)", account, serverUrl, k_metadataStatusWaitDownload, k_metadataStatusInDownload, k_metadataStatusDownloading, k_metadataStatusDownloadError), sorted: nil, ascending: false)
                    
                    let metadatasInUpload = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND (status == %d OR status == %d OR status == %d OR status == %d)", account, serverUrl, k_metadataStatusWaitUpload, k_metadataStatusInUpload, k_metadataStatusUploading, k_metadataStatusUploadError), sorted: nil, ascending: false)

                    // Delete metadata
                    NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND status == %d", account, serverUrl, k_metadataStatusNormal))
                    
                    // Add metadata
                    let metadataFolderInserted = NCManageDatabase.sharedInstance.addMetadata(metadataFolder)
                    let metadatasInserted = NCManageDatabase.sharedInstance.addMetadatas(metadatas)
                     
                    if metadatasInDownload != nil {
                        NCManageDatabase.sharedInstance.addMetadatas(metadatasInDownload!)
                    }
                    if metadatasInUpload != nil {
                        NCManageDatabase.sharedInstance.addMetadatas(metadatasInUpload!)
                    }
                    
                    completion(account, metadataFolderInserted, metadatasInserted, errorCode, "")
                }
            
            } else {
                
                var errorDescription = errorDescription
                if errorDescription == nil { errorDescription = "Internal error. Error not found" }
                
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                
                completion(account, nil, nil, errorCode, errorDescription!)
            }
        }
    }
    
    @objc func readFile(serverUrlFileName: String, account: String, completion: @escaping (_ account: String, _ metadata: tableMetadata?, _ errorCode: Int, _ errorDescription: String)->()) {
        
        NCCommunication.sharedInstance.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", showHiddenFiles: CCUtility.getShowHiddenFiles(), customUserAgent: nil, addCustomHeaders: nil, account: account) { (account, files, errorCode, errorDescription) in

            if errorCode == 0 && files != nil {
             
                let file = files![0]
                let isEncrypted = CCUtility.isFolderEncrypted(file.serverUrl, e2eEncrypted:file.e2eEncrypted, account: account)
                let metadata = NCManageDatabase.sharedInstance.convertNCFileToMetadata(file, isEncrypted: isEncrypted, account: account)
                completion(account, metadata, errorCode, "")
                
            } else {

                completion(account, nil, errorCode, errorDescription!)
            }
        }
    }
    
    @objc func deleteMetadata(_ metadata: tableMetadata, user: String, userID: String, password: String, url: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
                
        let isDirectoryEncrypted = CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account)
            
        if isDirectoryEncrypted {
            
            if let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
                
                self.deleteMetadataE2EE(metadata, directory: directory, user: user, userID: userID, password: password, url: url, completion: completion)
            }
            
        } else {
            // Verify Live Photo
            if let metadataLive = NCUtility.sharedInstance.isLivePhoto(metadata: metadata) {
                self.deleteMetadataPlain(metadataLive) { (errorCode, errorDescription) in
                    if errorCode == 0 {
                        self.deleteMetadataPlain(metadata, completion: completion)
                    } else {
                        completion(errorCode, errorDescription)
                    }
                }
            } else {
                self.deleteMetadataPlain(metadata, completion: completion)
            }
        }
    }
    
    private func deleteMetadataPlain(_ metadata: tableMetadata, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        // verify permission
        let permission = NCUtility.sharedInstance.permissionsContainsString(metadata.permissions, permissions: k_permission_can_delete)
        if metadata.permissions != "" && permission == false {
            
            self.NotificationPost(name: k_notificationCenter_deleteFile, userInfo: ["metadata": metadata, "errorCode": Int(k_CCErrorNotPermission)], errorDescription: "_no_permission_delete_file_", completion: completion)
            return
        }
                
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        NCCommunication.sharedInstance.deleteFileOrFolder(serverUrlFileName, customUserAgent: nil, addCustomHeaders: nil, account: metadata.account) { (account, errorCode, errorDescription) in
        
            if errorCode == 0 || errorCode == kOCErrorServerPathNotFound {
                
                do {
                    try FileManager.default.removeItem(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
                } catch { }
                                       
                NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NCManageDatabase.sharedInstance.deleteMedia(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
                NCManageDatabase.sharedInstance.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))

                if metadata.directory {
                    NCManageDatabase.sharedInstance.deleteDirectoryAndSubDirectory(serverUrl: CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName), account: metadata.account)
                }
            }
            
            self.NotificationPost(name: k_notificationCenter_deleteFile, userInfo: ["metadata": metadata, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
        }
    }
    
    private func deleteMetadataE2EE(_ metadata: tableMetadata, directory: tableDirectory, user: String, userID: String, password: String, url: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
                        
        DispatchQueue.global().async {
            // LOCK FOLDER
            let error = NCNetworkingEndToEnd.sharedManager().lockFolderEncrypted(onServerUrl: directory.serverUrl, fileId: directory.fileId, user: user, userID: userID, password: password, url: url) as NSError?
            
            DispatchQueue.main.async {
                if error == nil {
                    self.deleteMetadataPlain(metadata) { (errorCode, errorDescription) in
                        
                        if errorCode == 0 {
                            NCManageDatabase.sharedInstance.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", metadata.account, directory.serverUrl, metadata.fileName))
                        }
                        
                        DispatchQueue.global().async {
                            NCNetworkingEndToEnd.sharedManager().rebuildAndSendMetadata(onServerUrl: directory.serverUrl, account: self.account, user: user, userID: userID, password: password, url: url)
                        }
                        
                        self.NotificationPost(name: k_notificationCenter_deleteFile, userInfo: ["metadata": metadata, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
                    }
                } else {
                    
                    self.NotificationPost(name: k_notificationCenter_deleteFile, userInfo: ["metadata": metadata, "errorCode": error!.code], errorDescription: error?.localizedDescription, completion: completion)
                }
            }
        }
    }
    
    @objc func favoriteMetadata(_ metadata: tableMetadata, url: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        let fileName = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, activeUrl: url)!
        let favorite = !metadata.favorite
        
        NCCommunication.sharedInstance.setFavorite(serverUrl: url, fileName: fileName, favorite: favorite, customUserAgent: nil, addCustomHeaders: nil, account: metadata.account) { (account, errorCode, errorDescription) in
    
            if errorCode == 0 && metadata.account == account {
                NCManageDatabase.sharedInstance.setMetadataFavorite(ocId: metadata.ocId, favorite: favorite)
            }
            
            self.NotificationPost(name: k_notificationCenter_favoriteFile, userInfo: ["metadata": metadata, "favorite": favorite, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
        }
    }
    
    @objc func renameMetadata(_ metadata: tableMetadata, fileNameNew: String, user: String, userID: String, password: String, url: String, viewController: UIViewController?, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
        
        let isDirectoryEncrypted = CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account)
        
        if isDirectoryEncrypted {
            
            if let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
                
                 renameMetadataE2EE(metadata, fileNameNew: fileNameNew, directory: directory, user: user, userID: userID, password: password, url: url, completion: completion)
            }
    
        } else {
            
            renameMetadataPlain(metadata, fileNameNew: fileNameNew, completion: completion)
        }
    }
    
    private func renameMetadataPlain(_ metadata: tableMetadata, fileNameNew: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
        
        let permission = NCUtility.sharedInstance.permissionsContainsString(metadata.permissions, permissions: k_permission_can_rename)
        if !(metadata.permissions == "") && !permission {
            self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "errorCode": Int(k_CCErrorInternalError)], errorDescription: "_no_permission_modify_file_", completion: completion)
            return
        }
        guard let fileNameNew = CCUtility.removeForbiddenCharactersServer(fileNameNew) else {
            self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "errorCode": Int(0)], errorDescription: "", completion: completion)
            return
        }
        if fileNameNew.count == 0 || fileNameNew == metadata.fileNameView {
            self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "errorCode": Int(0)], errorDescription: "", completion: completion)
            return
        }
        
        let fileNamePath = metadata.serverUrl + "/" + metadata.fileName
        let fileNameToPath = metadata.serverUrl + "/" + fileNameNew
                
        NCCommunication.sharedInstance.moveFileOrFolder(serverUrlFileNameSource: fileNamePath, serverUrlFileNameDestination: fileNameToPath, overwrite: false, customUserAgent: nil, addCustomHeaders: nil, account: metadata.account) { (account, errorCode, errorDescription) in
                    
            if errorCode == 0 {
                        
                NCManageDatabase.sharedInstance.renameMetadata(fileNameTo: fileNameNew, ocId: metadata.ocId)
                NCManageDatabase.sharedInstance.renameMedia(fileNameTo: fileNameNew, ocId: metadata.ocId)
                        
                if metadata.directory {
                            
                    let serverUrl = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)!
                    let serverUrlTo = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: fileNameNew)!
                    if let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
                                
                        NCManageDatabase.sharedInstance.setDirectory(serverUrl: serverUrl, serverUrlTo: serverUrlTo, etag: "", ocId: nil, fileId: nil, encrypted: directory.e2eEncrypted, richWorkspace: nil, account: metadata.account)
                    }
                            
                } else {
                            
                    NCManageDatabase.sharedInstance.setLocalFile(ocId: metadata.ocId, date: nil, exifDate: nil, exifLatitude: nil, exifLongitude: nil, fileName: fileNameNew, etag: nil)
                    // Move file system
                    let atPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + metadata.fileName
                    let toPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + fileNameNew
                    do {
                        try FileManager.default.moveItem(atPath: atPath, toPath: toPath)
                    } catch { }
                    let atPathIcon = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileName)!
                    let toPathIcon = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: fileNameNew)!
                    do {
                        try FileManager.default.moveItem(atPath: atPathIcon, toPath: toPathIcon)
                    } catch { }
                }
            }
                    
            self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
        }
    }
    
    private func renameMetadataE2EE(_ metadata: tableMetadata, fileNameNew: String, directory: tableDirectory, user: String, userID: String, password: String, url: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
        
        // verify if exists the new fileName
        if NCManageDatabase.sharedInstance.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, fileNameNew)) != nil {
            
            self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "errorCode": Int(k_CCErrorInternalError)], errorDescription: "_file_already_exists_", completion: completion)

        } else {
            
            DispatchQueue.global().async {
                
                if let error = NCNetworkingEndToEnd.sharedManager()?.sendMetadata(onServerUrl: metadata.serverUrl, fileNameRename: metadata.fileName, fileNameNewRename: fileNameNew, unlock: false, account: metadata.account, user: user, userID: userID, password: password, url: url) as NSError? {
                    
                    self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "errorCode": error.code], errorDescription: error.localizedDescription, completion: completion)
                    
                } else {
                    NCManageDatabase.sharedInstance.setMetadataFileNameView(serverUrl: metadata.serverUrl, fileName: metadata.fileName, newFileNameView: fileNameNew, account: metadata.account)
                    
                    // Move file system
                    let atPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + metadata.fileNameView
                    let toPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + fileNameNew
                    do {
                        try FileManager.default.moveItem(atPath: atPath, toPath: toPath)
                    } catch { }
                    let atPathIcon = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
                    let toPathIcon = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: fileNameNew)!
                    do {
                        try FileManager.default.moveItem(atPath: atPathIcon, toPath: toPathIcon)
                    } catch { }
                    
                    self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "errorCode": Int(0)], errorDescription: "", completion: completion)
                }
                
                // UNLOCK
                if let tableLock = NCManageDatabase.sharedInstance.getE2ETokenLock(serverUrl: metadata.serverUrl) {
                    if let error = NCNetworkingEndToEnd.sharedManager()?.unlockFolderEncrypted(onServerUrl: metadata.serverUrl, fileId: directory.fileId, token: tableLock.token, user: user, userID: userID, password: password, url: url) as NSError? {
                        
                        self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "errorCode": error.code], errorDescription: error.localizedDescription, completion: completion)
                    }
                }
            }
        }
    }
    
    @objc func moveMetadata(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
    
        let permission = NCUtility.sharedInstance.permissionsContainsString(metadata.permissions, permissions: k_permission_can_rename)
        if !(metadata.permissions == "") && !permission {
            self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "serverUrlTo": serverUrlTo, "errorCode": Int(k_CCErrorInternalError)], errorDescription: "_no_permission_modify_file_", completion: completion)
            return
        }
        
        let serverUrlFileNameSource = metadata.serverUrl + "/" + metadata.fileName
        let serverUrlFileNameDestination = serverUrlTo + "/" + metadata.fileName
        
        NCCommunication.sharedInstance.moveFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite, customUserAgent: nil, addCustomHeaders: nil, account: metadata.account) { (account, errorCode, errorDescription) in
                    
            var metadataNew = tableMetadata()
            
            if errorCode == 0 {
    
                if metadata.directory {
                    NCManageDatabase.sharedInstance.deleteDirectoryAndSubDirectory(serverUrl: CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName), account: account)
                }
                
                if let metadataMove = NCManageDatabase.sharedInstance.moveMetadata(ocId: metadata.ocId, serverUrlTo: serverUrlTo) {
                    metadataNew = metadataMove
                }
                NCManageDatabase.sharedInstance.moveMedia(ocId: metadata.ocId, serverUrlTo: serverUrlTo)
                
                NCManageDatabase.sharedInstance.clearDateRead(serverUrl: metadata.serverUrl, account: account)
                NCManageDatabase.sharedInstance.clearDateRead(serverUrl: serverUrlTo, account: account)
            }
                    
            self.NotificationPost(name: k_notificationCenter_moveFile, userInfo: ["metadata": metadata, "metadataNew": metadataNew, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
        }
    }
    
    @objc func copyMetadata(_ metadata: tableMetadata, serverUrlTo: String, overwrite: Bool, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
    
        let permission = NCUtility.sharedInstance.permissionsContainsString(metadata.permissions, permissions: k_permission_can_rename)
        if !(metadata.permissions == "") && !permission {
            self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "serverUrlTo": serverUrlTo, "errorCode": Int(k_CCErrorInternalError)], errorDescription: "_no_permission_modify_file_", completion: completion)
            return
        }
        
        let serverUrlFileNameSource = metadata.serverUrl + "/" + metadata.fileName
        let serverUrlFileNameDestination = serverUrlTo + "/" + metadata.fileName
        
        NCCommunication.sharedInstance.copyFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileNameDestination, overwrite: overwrite, customUserAgent: nil, addCustomHeaders: nil, account: metadata.account) { (account, errorCode, errorDescription) in
                    
            self.NotificationPost(name: k_notificationCenter_copyFile, userInfo: ["metadata": metadata, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
        }
    }
    
    @objc func createFolder(fileName: String, serverUrl: String, account: String, user: String, userID: String, password: String, url: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        var fileNameFolder = CCUtility.removeForbiddenCharactersServer(fileName)!
        var fileNameFolderUrl = ""
        var fileNameIdentifier = ""
        var key: NSString?
        var initializationVector: NSString?
        let object = tableE2eEncryption()
        
        fileNameFolder = NCUtility.sharedInstance.createFileName(fileNameFolder, serverUrl: serverUrl, account: account)
        if fileNameFolder.count == 0 {
            self.NotificationPost(name: k_notificationCenter_createFolder, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": Int(0)], errorDescription: "", completion: completion)
            return
        }
        let isDirectoryEncrypted = CCUtility.isFolderEncrypted(serverUrl, e2eEncrypted: false, account: account)
        if isDirectoryEncrypted && NCManageDatabase.sharedInstance.getServerVersion(account: account) == k_nextcloud_version_19_0 {
            fileNameIdentifier = CCUtility.generateRandomIdentifier()
            fileNameFolderUrl = serverUrl + "/" + fileNameIdentifier
        } else {
            fileNameFolderUrl = serverUrl + "/" + fileNameFolder
        }
        
        NCCommunication.sharedInstance.createFolder(fileNameFolderUrl, customUserAgent: nil, addCustomHeaders: nil, account: account) { (account, ocId, date, errorCode, errorDescription) in
            if errorCode == 0 {
                
                self.readFile(serverUrlFileName: fileNameFolderUrl, account: account) { (account, metadataFolder, errorCode, errorDescription) in
                    if errorCode == 0 {
                        
                        // Add folder
                        NCManageDatabase.sharedInstance.addDirectory(encrypted: metadataFolder!.e2eEncrypted, favorite: metadataFolder!.favorite, ocId: metadataFolder!.ocId, fileId: metadataFolder!.fileId, etag: nil, permissions: metadataFolder!.permissions, serverUrl: fileNameFolderUrl, richWorkspace: metadataFolder!.richWorkspace, account: account)
                        
                        if isDirectoryEncrypted {
                            
                            DispatchQueue.global().async {
                                
                                if let error = NCNetworkingEndToEnd.sharedManager()?.markFolderEncrypted(onServerUrl: fileNameFolderUrl, fileId: metadataFolder?.fileId, user: user, userID: userID, password: password, url: url) as NSError? {
                                    self.NotificationPost(name: k_notificationCenter_createFolder, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": error.code], errorDescription: error.localizedDescription, completion: completion)
                                    return
                                }
                                
                                if NCManageDatabase.sharedInstance.getServerVersion(account: account) == k_nextcloud_version_19_0 {
                                                                
                                    NCEndToEndEncryption.sharedManager()?.encryptkey(&key, initializationVector: &initializationVector)
                                    let metadataKey = NCEndToEndEncryption.sharedManager()?.generateKey(16)?.base64EncodedString(options: []) // AES_KEY_128_LENGTH
                                    
                                    object.account = account
                                    object.authenticationTag = nil
                                    object.fileName = fileNameFolder
                                    object.fileNameIdentifier = fileNameIdentifier
                                    object.fileNamePath = ""
                                    object.key = key! as String
                                    object.initializationVector = initializationVector! as String
                                    object.metadataKey = metadataKey!
                                    object.metadataKeyIndex = 0
                                    object.mimeType = "application/directory"
                                    object.serverUrl = serverUrl
                                    object.version = Int(NCManageDatabase.sharedInstance.getEndToEndEncryptionVersion(account: account))
                                    let _ = NCManageDatabase.sharedInstance.addE2eEncryption(object)
                                    
                                    // Send Metadata
                                    if let error = NCNetworkingEndToEnd.sharedManager()?.sendMetadata(onServerUrl: serverUrl, fileNameRename: nil, fileNameNewRename: nil, unlock: true, account: account, user: user, userID: userID, password: password, url: url) as NSError? {
                                        self.NotificationPost(name: k_notificationCenter_createFolder, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": error.code], errorDescription: error.localizedDescription, completion: completion)
                                        return
                                    }
                                }
                                
                                DispatchQueue.main.async {
                                    self.NotificationPost(name: k_notificationCenter_createFolder, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
                                }
                            }
                        } else {
                            self.NotificationPost(name: k_notificationCenter_createFolder, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
                        }
                    } else {
                        self.NotificationPost(name: k_notificationCenter_createFolder, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
                    }
                }
            } else {
                self.NotificationPost(name: k_notificationCenter_createFolder, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
            }
        }
    }
    
    //MARK: - Notification Post
    
    private func NotificationPost(name: String, userInfo: [AnyHashable : Any], errorDescription: Any?, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        var userInfo = userInfo
        DispatchQueue.main.async {
            
            if errorDescription == nil { userInfo["errorDescription"] = "" }
            else { userInfo["errorDescription"] = NSLocalizedString(errorDescription as! String, comment: "") }
            
            NotificationCenter.default.post(name: Notification.Name.init(rawValue: name), object: nil, userInfo: userInfo)
            
            completion(userInfo["errorCode"] as! Int, userInfo["errorDescription"] as! String)
        }
    }
}
