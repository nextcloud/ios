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
    
    //MARK: - File <> Metadata
    
    @objc func convertFile(_ file: NCFile, urlString: String, serverUrl : String?, fileName: String, user: String) -> tableMetadata {
        
        let metadata = tableMetadata()
        
        metadata.account = account
        metadata.commentsUnread = file.commentsUnread
        metadata.contentType = file.contentType
        metadata.creationDate = file.creationDate
        metadata.date = file.date
        metadata.directory = file.directory
        metadata.e2eEncrypted = file.e2eEncrypted
        metadata.etag = file.etag
        metadata.favorite = file.favorite
        metadata.fileId = file.fileId
        metadata.fileName = fileName
        metadata.fileNameView = fileName
        metadata.hasPreview = file.hasPreview
        metadata.mountType = file.mountType
        metadata.ocId = file.ocId
        metadata.ownerId = file.ownerId
        metadata.ownerDisplayName = file.ownerDisplayName
        metadata.permissions = file.permissions
        metadata.quotaUsedBytes = file.quotaUsedBytes
        metadata.quotaAvailableBytes = file.quotaAvailableBytes
        metadata.richWorkspace = file.richWorkspace
        metadata.resourceType = file.resourceType
        if serverUrl == nil {
            metadata.serverUrl = urlString + file.path.replacingOccurrences(of: "dav/files/"+user, with: "webdav").dropLast()
        } else {
            metadata.serverUrl = serverUrl!
        }
        metadata.size = file.size
                   
        CCUtility.insertTypeFileIconName(metadata.fileName, metadata: metadata)
        
        return metadata
    }
    
    @objc func convertFiles(_ files: [NCFile], urlString: String, serverUrl : String?, user: String, metadataFolder: UnsafeMutablePointer<tableMetadata>?) -> [tableMetadata] {
        
        var metadatas = [tableMetadata]()
        
        for file in files {
            
            if !CCUtility.getShowHiddenFiles() && file.fileName.first == "." { continue }
            
            let metadata = tableMetadata()
            
            metadata.account = account
            metadata.commentsUnread = file.commentsUnread
            metadata.contentType = file.contentType
            metadata.creationDate = file.creationDate
            metadata.date = file.date
            metadata.directory = file.directory
            metadata.e2eEncrypted = file.e2eEncrypted
            metadata.etag = file.etag
            metadata.favorite = file.favorite
            metadata.fileId = file.fileId
            metadata.fileName = file.fileName
            metadata.fileNameView = file.fileName
            metadata.hasPreview = file.hasPreview
            metadata.mountType = file.mountType
            metadata.ocId = file.ocId
            metadata.ownerId = file.ownerId
            metadata.ownerDisplayName = file.ownerDisplayName
            metadata.permissions = file.permissions
            metadata.quotaUsedBytes = file.quotaUsedBytes
            metadata.quotaAvailableBytes = file.quotaAvailableBytes
            metadata.richWorkspace = file.richWorkspace
            metadata.resourceType = file.resourceType
            if serverUrl == nil {
                metadata.serverUrl = urlString + file.path.replacingOccurrences(of: "dav/files/"+user, with: "webdav").dropLast()
            } else {
                metadata.serverUrl = serverUrl!
            }
            metadata.size = file.size
                        
            CCUtility.insertTypeFileIconName(metadata.fileName, metadata: metadata)
            
            // Folder
            if file.fileName.count == 0 && metadataFolder != nil {
                metadataFolder!.initialize(to: metadata)
            } else {
                metadatas.append(metadata)
            }
        }
        
        return metadatas
    }
    
    //MARK: - WebDav
    
    @objc func deleteMetadata(_ metadata: tableMetadata, user: String, userID: String, password: String, url: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
                
        let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl))
            
        if directory != nil && directory?.e2eEncrypted == true {
            self.deleteMetadataE2EE(metadata, directory: directory!, user: user, userID: userID, password: password, url: url, completion: completion)
        } else {
            // Verify Live Photo
            if let metadataMov = NCUtility.sharedInstance.hasMOV(metadata: metadata) {
                self.deleteMetadataPlain(metadataMov) { (errorCode, errorDescription) in
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
            let userInfo: [String : Any] = ["metadata": metadata, "errorCode": Int(k_CCErrorNotPermission), "errorDescription": NSLocalizedString("_no_permission_delete_file_", comment: "")]
            NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_deleteFile), object: nil, userInfo: userInfo)
            completion(Int(k_CCErrorNotPermission), "_no_permission_delete_file_")
            return
        }
                
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        NCCommunication.sharedInstance.deleteFileOrFolder(serverUrlFileName, account: metadata.account) { (account, errorCode, errorDescription) in
            var description = ""
            if errorDescription != nil { description = errorDescription! }
            
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
            } else {
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
            }
            
            let userInfo: [String : Any] = ["metadata": metadata, "errorCode": Int(errorCode), "errorDescription": description]
            NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_deleteFile), object: nil, userInfo: userInfo)
            completion(errorCode, description)
        }
    }
    
    private func deleteMetadataE2EE(_ metadata: tableMetadata, directory: tableDirectory, user: String, userID: String, password: String, url: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
                        
        DispatchQueue.global().async {
            // LOCK FOLDER
            let error = NCNetworkingEndToEnd.sharedManager().lockFolderEncrypted(onServerUrl: directory.serverUrl, ocId: directory.ocId, user: user, userID: userID, password: password, url: url)
            
            DispatchQueue.main.async {
                if error == nil {
                    self.deleteMetadataPlain(metadata) { (errorCode, errorDescription) in
                        
                        if errorCode == 0 {
                            NCManageDatabase.sharedInstance.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", metadata.account, directory.serverUrl, metadata.fileName))
                        }
                        
                        DispatchQueue.global().async {
                            NCNetworkingEndToEnd.sharedManager().rebuildAndSendMetadata(onServerUrl: directory.serverUrl, account: self.account, user: user, userID: userID, password: password, url: url)
                            DispatchQueue.main.async {
                                completion(errorCode, errorDescription)
                            }
                        }
                    }
                } else {
                    NCContentPresenter.shared.messageNotification("_delete_", description: error!.localizedDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError))
                    completion(Int(k_CCErrorInternalError), error!.localizedDescription)
                }
            }
        }
    }
    
    @objc func favoriteMetadata(_ metadata: tableMetadata, url: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        let fileName = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, activeUrl: url)!
        var favorite = true
        if metadata.favorite { favorite = false }
        
        NCCommunication.sharedInstance.setFavorite(serverUrl: url, fileName: fileName, favorite: favorite, account: metadata.account) { (account, errorCode, errorDescription) in
            
            var description = ""
            if errorDescription != nil { description = errorDescription! }
            
            if errorCode == 0 && metadata.account == account {
                
                NCManageDatabase.sharedInstance.setMetadataFavorite(ocId: metadata.ocId, favorite: favorite)
                
            } else if (errorCode != 0) {
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
            } else {
                print("[LOG] It has been changed user during networking process, error.")

            }
            
            let userInfo: [String : Any] = ["metadata": metadata, "errorCode": Int(errorCode), "errorDescription": description, "favorite": Bool(favorite)]
            NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_favoriteFile), object: nil, userInfo: userInfo)
            
            completion(errorCode, description)
        }
    }
    
    @objc func renameMetadata(_ metadata: tableMetadata, fileNameNew: String, user: String, userID: String, password: String, url: String, viewController: UIViewController?, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
        
        guard let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) else {
            completion(Int(k_CCErrorInternalError), "")
            return
        }
        
        if directory.e2eEncrypted == true {
            renameMetadataE2EE(metadata, fileNameNew: fileNameNew, directory: directory, user: user, userID: userID, password: password, url: url, completion: completion)
        } else {
            renameMetadataPlain(metadata, fileNameNew: fileNameNew, viewController: viewController, completion: completion)
        }
    }
    
    private func renameMetadataPlain(_ metadata: tableMetadata, fileNameNew: String, viewController: UIViewController?, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
        
        let permission = NCUtility.sharedInstance.permissionsContainsString(metadata.permissions, permissions: k_permission_can_rename)
        if !(metadata.permissions == "") && !permission {
            NCContentPresenter.shared.messageNotification("_error_", description: "_no_permission_modify_file_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError))
            completion(Int(k_CCErrorInternalError),  "_no_permission_modify_file_")
            return
        }
        
        guard let fileNameNew = CCUtility.removeForbiddenCharactersServer(fileNameNew) else { return }
        if fileNameNew.count == 0 || fileNameNew == metadata.fileNameView { return }
        
        // Verify if exists the fileName TO
        let serverUrlFileName = metadata.serverUrl + "/" + fileNameNew
        NCCommunication.sharedInstance.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", account: metadata.account) { (account ,files, errorCode, errorDescription) in
           
            if errorCode == 0  {
                
                let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: NSLocalizedString("_file_already_exists_", comment: ""), preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default) { (action:UIAlertAction) in })
                viewController?.present(alertController, animated: true, completion:nil)
                
                completion(Int(k_CCErrorInternalError), "_file_already_exists_")
                
            } else if errorCode == kOCErrorServerPathNotFound {
                
                let fileNamePath = metadata.serverUrl + "/" + metadata.fileName
                let fileNameToPath = metadata.serverUrl + "/" + fileNameNew
                
                NCCommunication.sharedInstance.moveFileOrFolder(serverUrlFileNameSource: fileNamePath, serverUrlFileNameDestination: fileNameToPath, account: metadata.account) { (account, errorCode, errorDescription) in
                    
                    if errorCode == 0 {
                        
                        if let metadataNew = NCManageDatabase.sharedInstance.renameMetadata(fileNameTo: fileNameNew, ocId: metadata.ocId) {
                            let userInfo: [String : Any] = ["metadata": metadata, "metadataNew": metadataNew, "errorCode": Int(errorCode), "errorDescription": ""]
                            NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_renameFile), object: nil, userInfo: userInfo)
                        }
                        NCManageDatabase.sharedInstance.renameMedia(fileNameTo: fileNameNew, ocId: metadata.ocId)
                        
                        if metadata.directory {
                            
                            let serverUrl = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)!
                            let serverUrlTo = CCUtility.stringAppendServerUrl(metadata.serverUrl, addFileName: fileNameNew)!
                            if let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
                                
                                NCManageDatabase.sharedInstance.setDirectory(serverUrl: serverUrl, serverUrlTo: serverUrlTo, etag: "", ocId: nil, encrypted: directory.e2eEncrypted, richWorkspace: nil, account: metadata.account)
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
                        
                    } else {
                        
                        NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                        
                        let userInfo: [String : Any] = ["metadata": metadata, "errorCode": Int(errorCode), "errorDescription": errorDescription!]
                        NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_renameFile), object: nil, userInfo: userInfo)
                    }
                    
                    completion(errorCode, errorDescription)
                }
                
            } else {
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                
                completion(errorCode, errorDescription)
            }
        }
    }
    
    private func renameMetadataE2EE(_ metadata: tableMetadata, fileNameNew: String, directory: tableDirectory, user: String, userID: String, password: String, url: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
        
        // verify if exists the new fileName
        if NCManageDatabase.sharedInstance.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, fileNameNew)) != nil {
            
            NCContentPresenter.shared.messageNotification("_error_e2ee_", description: "_file_already_exists_", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError))
            
            completion(Int(k_CCErrorInternalError), "_file_already_exists_")
        
        } else {
            
            DispatchQueue.global().async {
                
                var errorCode: Int = 0
                var errorDescription = ""
                
                if let error = NCNetworkingEndToEnd.sharedManager()?.sendMetadata(onServerUrl: metadata.serverUrl, fileNameRename: metadata.fileName, fileNameNewRename: fileNameNew, account: metadata.account, user: user, userID: userID, password: password, url: url) as NSError? {
                    errorCode = error.code
                    errorDescription = "_e2e_error_send_metadata_"
                    NCContentPresenter.shared.messageNotification("_error_e2ee_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
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
                    
                    DispatchQueue.main.async {
                        let userInfo: [String : Any] = ["metadata": metadata, "errorCode": Int(0), "errorDescription": ""]
                        NotificationCenter.default.post(name: Notification.Name.init(rawValue: k_notificationCenter_renameFile), object: nil, userInfo: userInfo)
                    }
                }
                
                // UNLOCK
                if let tableLock = NCManageDatabase.sharedInstance.getE2ETokenLock(serverUrl: metadata.serverUrl) {
                    if let error = NCNetworkingEndToEnd.sharedManager()?.unlockFolderEncrypted(onServerUrl: metadata.serverUrl, ocId: directory.ocId, token: tableLock.token, user: user, userID: userID, password: password, url: url) as NSError? {
                        errorCode = error.code
                        errorDescription = error.localizedDescription
                        NCContentPresenter.shared.messageNotification("_error_e2ee_", description: error.localizedDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                    }
                }
                
                DispatchQueue.main.async {
                    completion(errorCode, errorDescription)
                }
            }
        }
    }
}
