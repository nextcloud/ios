//
//  NCNetworkingE2EE.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 05/05/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//

import Foundation
import OpenSSL
import NCCommunication

@objc class NCNetworkingE2EE: NSObject {
    @objc public static let sharedInstance: NCNetworkingE2EE = {
        let instance = NCNetworkingE2EE()
        return instance
    }()
    
    //MARK: - WebDav Create Folder
    
    func createFolder(fileName: String, serverUrl: String, account: String, user: String, userID: String, password: String, url: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String)->()) {
        
        var fileNameFolder = CCUtility.removeForbiddenCharactersServer(fileName)!
        var fileNameFolderUrl = ""
        var fileNameIdentifier = ""
        var key: NSString?
        var initializationVector: NSString?
        
        fileNameFolder = NCUtility.sharedInstance.createFileName(fileNameFolder, serverUrl: serverUrl, account: account)
        if fileNameFolder.count == 0 {
            self.NotificationPost(name: k_notificationCenter_createFolder, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": Int(0)], errorDescription: "", completion: completion)
            return
        }
        fileNameIdentifier = CCUtility.generateRandomIdentifier()
        fileNameFolderUrl = serverUrl + "/" + fileNameIdentifier
       
        DispatchQueue.global().async {
            
            let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl))
            if directory == nil {
                self.NotificationPost(name: k_notificationCenter_createFolder, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": k_CCErrorInternalError], errorDescription: "Directory not found", completion: completion)
                return
            }
            
            if let error = NCNetworkingEndToEnd.sharedManager()?.lockFolderEncrypted(onServerUrl: serverUrl, fileId: directory?.fileId, user: user, userID: userID, password: password, url: url) as NSError? {
                self.NotificationPost(name: k_notificationCenter_createFolder, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": error.code], errorDescription: error.localizedDescription, completion: completion)
                return
            }
            
            guard let lock = NCManageDatabase.sharedInstance.getE2ETokenLock(serverUrl: serverUrl) else {
                self.NotificationPost(name: k_notificationCenter_createFolder, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": k_CCErrorInternalError], errorDescription: "Lock not found", completion: completion)
                return
            }
            
            let e2eToken = lock.e2eToken
            
            DispatchQueue.main.async {
                
                NCCommunication.sharedInstance.createFolder(fileNameFolderUrl, customUserAgent: nil, addCustomHeaders: ["e2e-token" : e2eToken], account: account) { (account, ocId, date, errorCode, errorDescription) in
                    if errorCode == 0 {
                        NCNetworking.sharedInstance.readFile(serverUrlFileName: fileNameFolderUrl, account: account) { (account, metadataFolder, errorCode, errorDescription) in
                            if errorCode == 0 {
                                // Add Metadata
                                metadataFolder?.fileNameView = fileNameFolder
                                metadataFolder?.e2eEncrypted = true
                                NCManageDatabase.sharedInstance.addMetadata(metadataFolder!)
                                // Add folder
                                NCManageDatabase.sharedInstance.addDirectory(encrypted: true, favorite: metadataFolder!.favorite, ocId: metadataFolder!.ocId, fileId: metadataFolder!.fileId, etag: nil, permissions: metadataFolder!.permissions, serverUrl: fileNameFolderUrl, richWorkspace: metadataFolder!.richWorkspace, account: account)
                                
                                let fileId = metadataFolder?.fileId
                                
                                DispatchQueue.global().async {
                                
                                    if let error = NCNetworkingEndToEnd.sharedManager()?.markFolderEncrypted(onServerUrl: fileNameFolderUrl, fileId: fileId, user: user, userID: userID, password: password, url: url) as NSError? {
                                        self.NotificationPost(name: k_notificationCenter_createFolder, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": error.code], errorDescription: error.localizedDescription, completion: completion)
                                        return
                                    }

                                    let newobject = tableE2eEncryption()
                                    
                                    NCEndToEndEncryption.sharedManager()?.encryptkey(&key, initializationVector: &initializationVector)
                                    
                                    newobject.account = account
                                    newobject.authenticationTag = nil
                                    newobject.fileName = fileNameFolder
                                    newobject.fileNameIdentifier = fileNameIdentifier
                                    newobject.fileNamePath = ""
                                    newobject.key = key! as String
                                    newobject.initializationVector = initializationVector! as String
                                    
                                    if let object = NCManageDatabase.sharedInstance.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) {
                                        newobject.metadataKey = object.metadataKey
                                        newobject.metadataKeyIndex = object.metadataKeyIndex
                                    } else {
                                        newobject.metadataKey = (NCEndToEndEncryption.sharedManager()?.generateKey(16)?.base64EncodedString(options: []))! as String // AES_KEY_128_LENGTH
                                        newobject.metadataKeyIndex = 0
                                    }
                                    newobject.mimeType = "application/directory"
                                    newobject.serverUrl = serverUrl
                                    newobject.version = Int(NCManageDatabase.sharedInstance.getEndToEndEncryptionVersion(account: account))
                                    
                                    let _ = NCManageDatabase.sharedInstance.addE2eEncryption(newobject)

                                    // Send Metadata
                                    if let error = NCNetworkingEndToEnd.sharedManager()?.sendMetadata(onServerUrl: serverUrl, fileNameRename: nil, fileNameNewRename: nil, unlock: true, account: account, user: user, userID: userID, password: password, url: url) as NSError? {
                                        self.NotificationPost(name: k_notificationCenter_createFolder, userInfo: ["fileName": fileName, "serverUrl": serverUrl, "errorCode": error.code], errorDescription: error.localizedDescription, completion: completion)
                                        return
                                    }
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
                        self.NotificationPost(name: k_notificationCenter_deleteFile, userInfo: ["metadata": metadata, "errorCode": k_CCErrorInternalError], errorDescription: "Lock not found", completion: completion)
                        return
                    }
                    NCNetworking.sharedInstance.deleteMetadataPlain(metadata, addCustomHeaders: ["e2e-token" : lock.e2eToken]) { (errorCode, errorDescription) in
                        
                        if errorCode == 0 {
                            NCManageDatabase.sharedInstance.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", metadata.account, directory.serverUrl, metadata.fileName))
                        }
                        
                        DispatchQueue.global().async {
                            NCNetworkingEndToEnd.sharedManager().rebuildAndSendMetadata(onServerUrl: directory.serverUrl, account: account, user: user, userID: userID, password: password, url: url)
                        }
                        
                        self.NotificationPost(name: k_notificationCenter_deleteFile, userInfo: ["metadata": metadata, "errorCode": errorCode], errorDescription: errorDescription, completion: completion)
                    }
                } else {
                    
                    self.NotificationPost(name: k_notificationCenter_deleteFile, userInfo: ["metadata": metadata, "errorCode": error!.code], errorDescription: error?.localizedDescription, completion: completion)
                }
            }
        }
    }
    
    //MARK: - WebDav Rename
    
    func renameMetadata(_ metadata: tableMetadata, fileNameNew: String, directory: tableDirectory, user: String, userID: String, password: String, url: String, completion: @escaping (_ errorCode: Int, _ errorDescription: String?)->()) {
        
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
                    if let error = NCNetworkingEndToEnd.sharedManager()?.unlockFolderEncrypted(onServerUrl: metadata.serverUrl, fileId: directory.fileId, e2eToken: tableLock.e2eToken, user: user, userID: userID, password: password, url: url) as NSError? {
                        
                        self.NotificationPost(name: k_notificationCenter_renameFile, userInfo: ["metadata": metadata, "errorCode": error.code], errorDescription: error.localizedDescription, completion: completion)
                    }
                }
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


