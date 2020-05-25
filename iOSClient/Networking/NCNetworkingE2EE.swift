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

import Foundation
import OpenSSL
import NCCommunication

@objc class NCNetworkingE2EE: NSObject {
    @objc public static let sharedInstance: NCNetworkingE2EE = {
        let instance = NCNetworkingE2EE()
        return instance
    }()
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    //MARK: - WebDav Create Folder
    
    func createFolder(fileName: String, serverUrl: String, account: String, user: String, userID: String, password: String, url: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        var fileNameFolder = CCUtility.removeForbiddenCharactersServer(fileName)!
        var fileNameFolderUrl = ""
        var fileNameIdentifier = ""
        var key: NSString?
        var initializationVector: NSString?
        
        fileNameFolder = NCUtility.sharedInstance.createFileName(fileNameFolder, serverUrl: serverUrl, account: account)
        if fileNameFolder.count == 0 {
            self.NotificationPost(name: k_notificationCenter_createFolder, serverUrl: serverUrl, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": Int(0)], errorDescription: "", completion: completion)
            return
        }
        fileNameIdentifier = CCUtility.generateRandomIdentifier()
        fileNameFolderUrl = serverUrl + "/" + fileNameIdentifier
       
        guard let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) else {
            self.NotificationPost(name: k_notificationCenter_createFolder, serverUrl: serverUrl, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": k_CCErrorInternalError], errorDescription: "Directory not found", completion: completion)
            return
        }
        
        self.lock(serverUrl: serverUrl, fileId: directory.fileId) { (e2eToken, errorCode, errorDescription) in
            if errorCode == 0 && e2eToken != nil {
                               
                NCCommunication.shared.createFolder(fileNameFolderUrl, addCustomHeaders: ["e2e-token" : e2eToken!]) { (account, ocId, date, errorCode, errorDescription) in
                    if errorCode == 0 {
                        
                        NCNetworking.sharedInstance.readFile(serverUrlFileName: fileNameFolderUrl, account: account) { (account, metadataFolder, errorCode, errorDescription) in
                            if errorCode == 0 {
                                
                                // Add Metadata
                                metadataFolder?.fileNameView = fileNameFolder
                                metadataFolder?.e2eEncrypted = true
                                NCManageDatabase.sharedInstance.addMetadata(metadataFolder!)
                                // Add folder
                                NCManageDatabase.sharedInstance.addDirectory(encrypted: true, favorite: metadataFolder!.favorite, ocId: metadataFolder!.ocId, fileId: metadataFolder!.fileId, etag: nil, permissions: metadataFolder!.permissions, serverUrl: fileNameFolderUrl, richWorkspace: metadataFolder!.richWorkspace, account: account)
                                                                
                                NCCommunication.shared.markE2EEFolder(fileId: metadataFolder!.fileId, delete: false) { (account, errorCode, errorDescription) in
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
                                        
                                        if let result = NCManageDatabase.sharedInstance.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) {
                                            object.metadataKey = result.metadataKey
                                            object.metadataKeyIndex = result.metadataKeyIndex
                                        } else {
                                            object.metadataKey = (NCEndToEndEncryption.sharedManager()?.generateKey(16)?.base64EncodedString(options: []))! as String // AES_KEY_128_LENGTH
                                            object.metadataKeyIndex = 0
                                        }
                                        object.mimeType = "httpd/unix-directory"
                                        object.serverUrl = serverUrl
                                        if let e2eeApiVersion = NCManageDatabase.sharedInstance.getCapabilitiesServerString(account: account, elements: NCElementsJSON.shared.capabilitiesE2EEApiVersion) {
                                            object.version = Int(e2eeApiVersion) ?? 1
                                        } else {
                                            object.version = 1
                                        }
                                        
                                        let _ = NCManageDatabase.sharedInstance.addE2eEncryption(object)
                                        
                                        self.sendE2EMetadata(account: account, serverUrl: serverUrl, fileId: directory.fileId, fileNameRename: nil, fileNameNewRename: nil, url: url) { (errorCode, errorDescription) in
                                            self.NotificationPost(name: k_notificationCenter_createFolder, serverUrl: serverUrl, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
                                        }
                                    } else {
                                        self.NotificationPost(name: k_notificationCenter_createFolder, serverUrl: serverUrl, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
                                    }
                                }
                            } else {
                                self.NotificationPost(name: k_notificationCenter_createFolder, serverUrl: serverUrl, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
                            }
                        }
                    } else {
                        self.NotificationPost(name: k_notificationCenter_createFolder, serverUrl: serverUrl, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
                    }
                }
            } else {
                self.NotificationPost(name: k_notificationCenter_createFolder, serverUrl: serverUrl, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
            }
        }
    }
    
    //MARK: - WebDav Delete
    
    func deleteMetadata(_ metadata: tableMetadata, directory: tableDirectory, account: String, user: String, userID: String, password: String, url: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
                        
        DispatchQueue.global().async {
            // LOCK FOLDER
            let error = NCNetworkingEndToEnd.sharedManager().lockFolderEncrypted(onServerUrl: directory.serverUrl, fileId: directory.fileId, user: user, userID: userID, password: password, url: url) as NSError?
            
            DispatchQueue.main.async {
                if error == nil {
                    guard let lock = NCManageDatabase.sharedInstance.getE2ETokenLock(serverUrl: directory.serverUrl) else {
                        self.NotificationPost(name: k_notificationCenter_deleteFile, serverUrl: metadata.serverUrl, userInfo: ["metadata": metadata, "errorCode": k_CCErrorInternalError], errorDescription: "Lock not found", completion: completion)
                        return
                    }
                    NCNetworking.sharedInstance.deleteMetadataPlain(metadata, addCustomHeaders: ["e2e-token" : lock.e2eToken]) { (errorCode, errorDescription) in
                        
                        if errorCode == 0 {
                            NCManageDatabase.sharedInstance.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", metadata.account, directory.serverUrl, metadata.fileName))
                        }
                        
                        DispatchQueue.global().async {
                            NCNetworkingEndToEnd.sharedManager().rebuildAndSendMetadata(onServerUrl: directory.serverUrl, account: account, user: user, userID: userID, password: password, url: url)
                        }
                        
                        self.NotificationPost(name: k_notificationCenter_deleteFile, serverUrl: metadata.serverUrl, userInfo: ["metadata": metadata, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
                    }
                } else {
                    
                    self.NotificationPost(name: k_notificationCenter_deleteFile, serverUrl: metadata.serverUrl, userInfo: ["metadata": metadata, "errorCode": error!.code], errorDescription: error?.localizedDescription, completion: completion)
                }
            }
        }
    }
    
    //MARK: - WebDav Rename
    
    func renameMetadata(_ metadata: tableMetadata, fileNameNew: String, directory: tableDirectory, user: String, userID: String, password: String, url: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
        
        // verify if exists the new fileName
        if NCManageDatabase.sharedInstance.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, fileNameNew)) != nil {
            
            self.NotificationPost(name: k_notificationCenter_renameFile, serverUrl: metadata.serverUrl, userInfo: ["metadata": metadata, "errorCode": Int(k_CCErrorInternalError)], errorDescription: "_file_already_exists_", completion: completion)

        } else {
            
            DispatchQueue.global().async {
                
                if let error = NCNetworkingEndToEnd.sharedManager()?.sendMetadata(onServerUrl: metadata.serverUrl, fileNameRename: metadata.fileName, fileNameNewRename: fileNameNew, unlock: false, account: metadata.account, user: user, userID: userID, password: password, url: url) as NSError? {
                    
                    self.NotificationPost(name: k_notificationCenter_renameFile, serverUrl: metadata.serverUrl, userInfo: ["metadata": metadata, "errorCode": error.code], errorDescription: error.localizedDescription, completion: completion)
                    
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
                    
                    self.NotificationPost(name: k_notificationCenter_renameFile, serverUrl: metadata.serverUrl, userInfo: ["metadata": metadata, "errorCode": Int(0)], errorDescription: "", completion: completion)
                }
                
                // UNLOCK
                if let tableLock = NCManageDatabase.sharedInstance.getE2ETokenLock(serverUrl: metadata.serverUrl) {
                    if let error = NCNetworkingEndToEnd.sharedManager()?.unlockFolderEncrypted(onServerUrl: metadata.serverUrl, fileId: directory.fileId, e2eToken: tableLock.e2eToken, user: user, userID: userID, password: password, url: url) as NSError? {
                        
                        self.NotificationPost(name: k_notificationCenter_renameFile, serverUrl: metadata.serverUrl, userInfo: ["metadata": metadata, "errorCode": error.code], errorDescription: error.localizedDescription, completion: completion)
                    }
                }
            }
        }
    }
    
    //MARK: - E2EE
    
    private func lock(serverUrl: String, fileId: String, completion: @escaping (_ e2eToken: String?, _ errorCode: Int, _ errorDescription: String?)->()) {
        
        var e2eToken: String?
        
        if let tableLock = NCManageDatabase.sharedInstance.getE2ETokenLock(serverUrl: serverUrl) {
            e2eToken = tableLock.e2eToken
        }
        
        NCCommunication.shared.lockE2EEFolder(fileId: fileId, e2eToken: e2eToken, delete: false) { (account, e2eToken, errorCode, errorDescription) in
            if errorCode == 0 && e2eToken != nil {
                NCManageDatabase.sharedInstance.setE2ETokenLock(serverUrl: serverUrl, fileId: fileId, e2eToken: e2eToken!)
            }
            completion(e2eToken, errorCode, errorDescription)
        }
    }
    
    private func unlock(serverUrl: String, fileId: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
        
        var e2eToken: String?
        
        if let tableLock = NCManageDatabase.sharedInstance.getE2ETokenLock(serverUrl: serverUrl) {
            e2eToken = tableLock.e2eToken
        }
        
        NCCommunication.shared.lockE2EEFolder(fileId: fileId, e2eToken: e2eToken, delete: true) { (account, e2eToken, errorCode, errorDescription) in
            if errorCode == 0 {
                NCManageDatabase.sharedInstance.deteleE2ETokenLock(serverUrl: serverUrl)
            }
            completion(errorCode, errorDescription)
        }
    }
    
    private func sendE2EMetadata(account: String, serverUrl: String, fileId: String, fileNameRename: String?, fileNameNewRename: String?, url: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
    
        self.lock(serverUrl: serverUrl, fileId: fileId) { (e2eToken, errorCode, errorDescription) in
            if errorCode == 0 && e2eToken != nil {
                          
                NCCommunication.shared.getE2EEMetadata(fileId: fileId, e2eToken: e2eToken) { (account, metadata, errorCode, errorDescription) in
                    var method = "POST"
                    
                    if errorCode == 0 && metadata != nil {
                        if !NCEndToEndMetadata.sharedInstance.decoderMetadata(metadata!, privateKey: CCUtility.getEndToEndPrivateKey(account), serverUrl: serverUrl, account: account, url: self.appDelegate.activeUrl) {
                            completion(Int(k_CCErrorInternalError), NSLocalizedString("_e2e_error_encode_metadata_", comment: ""))
                            return
                        }
                        method = "PUT"
                    }
    
                    if (fileNameRename != nil && fileNameNewRename != nil) {
                        NCManageDatabase.sharedInstance.renameFileE2eEncryption(serverUrl: serverUrl, fileNameIdentifier: fileNameRename!, newFileName: fileNameNewRename!, newFileNamePath: CCUtility.returnFileNamePath(fromFileName: fileNameNewRename!, serverUrl: serverUrl, activeUrl: url))
                    }
                
                    guard let tableE2eEncryption = NCManageDatabase.sharedInstance.getE2eEncryptions(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) else {
                        completion(Int(k_CCErrorInternalError), NSLocalizedString("_e2e_error_record_not_found_", comment: ""))
                        return
                    }
                    guard let metadata = NCEndToEndMetadata.sharedInstance.encoderMetadata(tableE2eEncryption, privateKey: CCUtility.getEndToEndPrivateKey(account), serverUrl: serverUrl) else {
                        completion(Int(k_CCErrorInternalError), NSLocalizedString("_e2e_error_encode_metadata_", comment: ""))
                        return
                    }
            
                    NCCommunication.shared.putE2EEMetadata(fileId: fileId, e2eToken: e2eToken!, metadata: metadata, method: method) { (account, metadata, errorCode, errorDescription) in
                        self.unlock(serverUrl: serverUrl, fileId: fileId) { (errorCode, errorDescription) in }
                        
                        if errorCode == 0 && metadata != nil {
                            let result = NCEndToEndMetadata.sharedInstance.decoderMetadata(metadata!, privateKey: CCUtility.getEndToEndPrivateKey(account), serverUrl: serverUrl, account: account, url: self.appDelegate.activeUrl)
                            print("\(result)")
                        }
                        completion(errorCode, errorDescription)
                    }
                }
            } else {
                completion(errorCode, errorDescription)
            }
        }
    }
    
    //MARK: - Notification Post
       
    private func NotificationPost(name: String, serverUrl: String, userInfo: [AnyHashable : Any], errorDescription: Any?, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        var userInfo = userInfo
        DispatchQueue.main.async {
            
            // unlock
            if let tableLock = NCManageDatabase.sharedInstance.getE2ETokenLock(serverUrl: serverUrl) {
                NCCommunication.shared.lockE2EEFolder(fileId: tableLock.fileId, e2eToken: tableLock.e2eToken, delete: true) { (_, _, _, _) in }
            }
            
            if errorDescription == nil { userInfo["errorDescription"] = "" }
            else { userInfo["errorDescription"] = NSLocalizedString(errorDescription as! String, comment: "") }
               
            NotificationCenter.default.post(name: Notification.Name.init(rawValue: name), object: nil, userInfo: userInfo)
               
            completion(userInfo["errorCode"] as! Int, userInfo["errorDescription"] as! String)
        }
    }
}


