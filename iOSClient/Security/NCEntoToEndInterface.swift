//
//  NCEntoToEndInterface.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 03/04/17.
//  Copyright © 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
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

class NCEntoToEndInterface : NSObject, OCNetworkingDelegate  {

    struct e2eMetadata: Codable {
        
        struct metadataKey: Codable {
            
            let metadataKeys: [String: String]
            let version: Int
        }
        
        struct sharingKey: Codable {
            
            let recipient: [String: String]
        }
        
        struct encrypted: Codable {
            
            let key: String
            let filename: String
            let mimetype: String
            let version: Int
        }
        
        struct filesKey: Codable {
            
            let initializationVector: String
            let authenticationTag: String
            let metadataKey: Int
            let encrypted: String
        }
        
        let files: [String: filesKey]
        let metadata: metadataKey
        let sharing: sharingKey?
    }

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    override init() {
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Initialize
    // --------------------------------------------------------------------------------------------
    
    @objc func initEndToEndEncryption() {
        
        // Clear all keys 
        CCUtility.clearAllKeysEnd(toEnd: appDelegate.activeAccount)
        
        let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
        
        metadataNet.action = actionGetEndToEndPublicKeys
        appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
    }
    
    func getPrivateKeyCipher() {
        
        let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
        
        metadataNet.action = actionGetEndToEndPrivateKeyCipher
        appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
    }
    
    func getPublicKeyServer() {
        
        let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
        
        metadataNet.action = actionGetEndToEndServerPublicKey
        appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Manage PublicKey
    // --------------------------------------------------------------------------------------------
    
    func getEndToEndPublicKeysSuccess(_ metadataNet: CCMetadataNet!) {
    
        CCUtility.setEndToEndPublicKey(appDelegate.activeAccount, publicKey: metadataNet.key)
        
        // Request PrivateKey chiper to Server
        getPrivateKeyCipher()
    }
    
    func getEndToEndPublicKeysFailure(_ metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        switch errorCode {
            
        case 400:
            appDelegate.messageNotification("E2E get publicKey", description: "bad request: unpredictable internal error", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
        case 404:
            guard let csr = NCEndToEndEncryption.sharedManager().createCSR(appDelegate.activeUserID, directoryUser: appDelegate.directoryUser) else {
                
                appDelegate.messageNotification("E2E Csr", description: "Error to create Csr", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
                
                return
            }
            
            let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
            
            metadataNet.action = actionSignEndToEndPublicKey;
            metadataNet.key = csr;
            
            appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
            
        case 409:
            appDelegate.messageNotification("E2E get publicKey", description: "forbidden: the user can't access the public keys", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
        default:
            appDelegate.messageNotification("E2E get publicKey", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        }
    }

    func signEnd(toEndPublicKeySuccess metadataNet: CCMetadataNet!) {

        CCUtility.setEndToEndPublicKey(appDelegate.activeAccount, publicKey: metadataNet.key)
        
        // Request PrivateKey chiper to Server
        getPrivateKeyCipher()
    }

    func signEnd(toEndPublicKeyFailure metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        switch errorCode {
            
        case 400:
            appDelegate.messageNotification("E2E sign publicKey", description: "bad request: unpredictable internal error", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
        case 409:
            appDelegate.messageNotification("E2E sign publicKey", description: "conflict: a public key for the user already exists", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
        default:
            appDelegate.messageNotification("E2E sign publicKey", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        }
    }
    
    func deleteEnd(toEndPublicKeySuccess metadataNet: CCMetadataNet!) {
        appDelegate.messageNotification("E2E delete publicKey", description: "Success", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.success, errorCode: 0)
    }
    
    func deleteEnd(toEndPublicKeyFailure metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        appDelegate.messageNotification("E2E delete publicKey", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Manage PrivateKey
    // --------------------------------------------------------------------------------------------
    
    func getEndToEndPrivateKeyCipherSuccess(_ metadataNet: CCMetadataNet!) {
        
        // request Passphrase
        
        var passphraseTextField: UITextField?
                
        let alertController = UIAlertController(title: NSLocalizedString("_e2e_passphrase_request_title_", comment: ""), message: NSLocalizedString("_e2e_passphrase_request_message_", comment: ""), preferredStyle: .alert)
        
        //TEST
        /*
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            
            let fileURL = dir.appendingPathComponent("privatekey.txt")
            
            //writing
            do {
                try metadataNet.key.write(to: fileURL, atomically: false, encoding: .utf8)
            }
            catch {/* error handling here */}
        }
        */
        //
        
        let ok = UIAlertAction(title: "OK", style: .default, handler: { (action) -> Void in
                            
            let passphrase = passphraseTextField?.text
            
            let publicKey = CCUtility.getEndToEndPublicKey(self.appDelegate.activeAccount)

            guard let privateKey = (NCEndToEndEncryption.sharedManager().decryptPrivateKey(metadataNet.key, passphrase: passphrase, publicKey: publicKey)) else {
                
                self.appDelegate.messageNotification("E2E decrypt privateKey", description: "Serious internal error to decrypt Private Key", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
                
                return
            }
            
            // privateKey
            print(privateKey)
            
            // Save to keychain
            CCUtility.setEndToEndPrivateKey(self.appDelegate.activeAccount, privateKey: privateKey)
            CCUtility.setEndToEndPassphrase(self.appDelegate.activeAccount, passphrase:passphrase)
            
            // request publicKey Server()
            self.getPublicKeyServer()
        })
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { (action) -> Void in
        }
        
        alertController.addAction(ok)
        alertController.addAction(cancel)
        alertController.addTextField { (textField) -> Void in
            passphraseTextField = textField
            passphraseTextField?.placeholder = "Enter passphrase (12 words)"
        }
        
        appDelegate.activeMain.present(alertController, animated: true)
    }
    
    func getEndToEndPrivateKeyCipherFailure(_ metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        switch errorCode {
            
        case 400:
            appDelegate.messageNotification("E2E get privateKey", description: "bad request: unpredictable internal error", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
        case 404:
            // message
            let e2ePassphrase = NYMnemonic.generateString(128, language: "english")
            let message = "\n" + NSLocalizedString("_e2e_settings_view_passphrase_", comment: "") + "\n\n" + e2ePassphrase!
            
            let alertController = UIAlertController(title: NSLocalizedString("_e2e_settings_title_", comment: ""), message: NSLocalizedString(message, comment: ""), preferredStyle: .alert)
            
            let OKAction = UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default) { action in
                
                var privateKey : NSString?
                
                guard let privateKeyChiper = NCEndToEndEncryption.sharedManager().encryptPrivateKey(self.appDelegate.activeUserID, directoryUser: self.appDelegate.directoryUser, passphrase: e2ePassphrase, privateKey: &privateKey) else {
                    
                    self.appDelegate.messageNotification("E2E privateKey", description: "Serious internal error to create PrivateKey chiper", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
                    
                    return
                }
                
                let metadataNet: CCMetadataNet = CCMetadataNet.init(account: self.appDelegate.activeAccount)

                metadataNet.action = actionStoreEndToEndPrivateKeyCipher
                metadataNet.key = privateKey! as String
                metadataNet.keyCipher = privateKeyChiper
                metadataNet.password = e2ePassphrase
                    
                self.appDelegate.addNetworkingOperationQueue(self.appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
            }
            
            alertController.addAction(OKAction)
            appDelegate.activeMain.present(alertController, animated: true)
            
        case 409:
            appDelegate.messageNotification("E2E get privateKey", description: "forbidden: the user can't access the private key", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
        default:
            appDelegate.messageNotification("E2E get privateKey", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        }
    }
    
    func storeEnd(toEndPrivateKeyCipherSuccess metadataNet: CCMetadataNet!) {
        
        CCUtility.setEndToEndPrivateKey(appDelegate.activeAccount, privateKey: metadataNet.key)
        CCUtility.setEndToEndPassphrase(appDelegate.activeAccount, passphrase:metadataNet.password)
        
        // request publicKey Server()
        self.getPublicKeyServer()
    }
    
    func storeEnd(toEndPrivateKeyCipherFailure metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        switch errorCode {
            
        case 400:
            appDelegate.messageNotification("E2E store privateKey", description: "bad request: unpredictable internal error", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
        case 409:
            appDelegate.messageNotification("E2E store privateKey", description: "conflict: a private key for the user already exists", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        
        default:
            appDelegate.messageNotification("E2E store privateKey", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        }
    }
    
    func deleteEnd(toEndPrivateKeySuccess metadataNet: CCMetadataNet!) {
        appDelegate.messageNotification("E2E delete privateKey", description: "Success", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.success, errorCode: 0)
    }
    
    func deleteEnd(toEndPrivateKeyFailure metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        appDelegate.messageNotification("E2E delete privateKey", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Manage Server PublicKey
    // --------------------------------------------------------------------------------------------
    
    func getEndToEndServerPublicKeySuccess(_ metadataNet: CCMetadataNet!) {
        
        CCUtility.setEndToEndPublicKeyServer(appDelegate.activeAccount, publicKey: metadataNet.key)
        
        // All OK Activated flsg on Manage EndToEnd Encryption
        NotificationCenter.default.post(name: Notification.Name("reloadManageEndToEndEncryption"), object: nil)
    }
    
    func getEndToEndServerPublicKeyFailure(_ metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        switch (errorCode) {
            
        case 400:
            appDelegate.messageNotification("E2E Server publicKey", description: "bad request: unpredictable internal error", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
        case 404:
            appDelegate.messageNotification("E2E Server publicKey", description: "Server publickey doesn't exists", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
        case 409:
            appDelegate.messageNotification("E2E Server publicKey", description: "forbidden: the user can't access the Server publickey", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
        default:
            appDelegate.messageNotification("E2E Server publicKey", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        }
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Manage Mark/Delete Encrypted Folder
    // --------------------------------------------------------------------------------------------
    
    @objc func markEndToEndFolderEncrypted(_ url: String, fileID: String, token: String?) -> Bool {
        
        var token : NSString? = token as NSString?

        if let error = NCNetworkingSync.sharedManager().lockEnd(toEndFolderEncrypted: appDelegate.activeUser, userID: appDelegate.activeUserID, password: appDelegate.activePassword, url: url , fileID: fileID, token: &token) as NSError? {
            
            appDelegate.messageNotification("E2E Mark folder as encrypted", description: error.localizedDescription+" code \(error.code)", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: error.code)
            
            return false
        }
        
        if let error = NCNetworkingSync.sharedManager().markEnd(toEndFolderEncrypted: appDelegate.activeUser, userID: appDelegate.activeUserID, password: appDelegate.activePassword, url: url, fileID: fileID) as NSError? {
            
            appDelegate.messageNotification("E2E Mark folder as encrypted", description: error.localizedDescription+" code \(error.code)", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: error.code)
            
            return false
        }
        
        if let error = NCNetworkingSync.sharedManager().unlockEnd(toEndFolderEncrypted: appDelegate.activeUser, userID: appDelegate.activeUserID, password: appDelegate.activePassword, url: url, fileID: fileID, token: token! as String) as NSError? {
            
            appDelegate.messageNotification("E2E Mark folder as encrypted", description: error.localizedDescription+" code \(error.code)", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: error.code)
            
            return false
        }
        
        return true
    }
    
    @objc func deletemarkEndToEndFolderEncrypted(_ url: String, fileID: String, token: String?) -> Bool {
        
        var token : NSString? = token as NSString?
        
        if let error = NCNetworkingSync.sharedManager().lockEnd(toEndFolderEncrypted: appDelegate.activeUser, userID: appDelegate.activeUserID, password: appDelegate.activePassword, url: url , fileID: fileID, token: &token) as NSError? {
            
            appDelegate.messageNotification("E2E Remove mark folder as encrypted", description: error.localizedDescription+" code \(error.code)", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: error.code)
            
            return false
        }
        
        if let error = NCNetworkingSync.sharedManager().deletemarkEnd(toEndFolderEncrypted: appDelegate.activeUser, userID: appDelegate.activeUserID, password: appDelegate.activePassword, url: url, fileID: fileID) as NSError? {
            
            appDelegate.messageNotification("E2E Remove mark folder as encrypted", description: error.localizedDescription+" code \(error.code)", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: error.code)
            
            return false
        }
        
        if let error = NCNetworkingSync.sharedManager().unlockEnd(toEndFolderEncrypted: appDelegate.activeUser, userID: appDelegate.activeUserID, password: appDelegate.activePassword, url: url, fileID: fileID, token: token! as String) as NSError? {
            
            appDelegate.messageNotification("E2E Remove mark folder as encrypted", description: error.localizedDescription+" code \(error.code)", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: error.code)
            
            return false
        }
        
        return true
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Manage Metadata
    // --------------------------------------------------------------------------------------------
    
    func getEndToEndMetadataSuccess(_ metadataNet: CCMetadataNet!) {
        
        guard let privateKey = CCUtility.getEndToEndPrivateKey(appDelegate.activeAccount) else {
            
            appDelegate.messageNotification("E2E Get Metadata Success", description: "Serious internal error: PrivareKey not found", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
            return
        }

        guard let main = appDelegate.listMainVC[metadataNet.serverUrl] as? CCMain else {
            
            appDelegate.messageNotification("E2E Get Metadata Success", description: "Serious internal error: Main not found", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
            return
        }
        
        if (decoderMetadata(metadataNet.encryptedMetadata, privateKey: privateKey, serverUrl: metadataNet.serverUrl) == false) {
            return
        }

        // Reload data source
        main.reloadDatasource(metadataNet.serverUrl)
    }
    
    func getEndToEndMetadataFailure(_ metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        // Unauthorized
        if (errorCode == kOCErrorServerUnauthorized) {
            
            appDelegate.openLoginView(appDelegate.activeMain, loginType: loginModifyPasswordUser)
            
        } else if (errorCode != 404) {
            
            appDelegate.messageNotification("E2E Get metadata", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        }
    }
    
    @objc func getEndToEndMetadata(_ metadata: tableMetadata) {
        
        let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
        
        metadataNet.action = actionGetEndToEndMetadata;
        metadataNet.fileID = metadata.fileID;
        
        guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
            
            appDelegate.messageNotification("E2E Get metadata", description: "Serious internal error: ServerURL not found", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
            return
        }
        metadataNet.serverUrl = serverUrl
        
        appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Encode / Decode JSON Metadata
    // --------------------------------------------------------------------------------------------
    
    @objc func encoderMetadata(_ recordsE2eEncryption: [tableE2eEncryption], publicKey: String, version: Int) -> String? {
        
        let jsonEncoder = JSONEncoder.init()
        var files = [String: e2eMetadata.filesKey]()
        
        // Create "files"
        for recordE2eEncryption in recordsE2eEncryption {
            
            let plainEncrypted = recordE2eEncryption.key+"|"+recordE2eEncryption.fileName+"|"+recordE2eEncryption.mimeType+"|"+",\(recordE2eEncryption.version)"
            guard let encryptedData = NCEndToEndEncryption.sharedManager().encryptAsymmetricString(plainEncrypted, publicKey: publicKey) else {
                
                appDelegate.messageNotification("E2E encore metadata", description: "Serious internal error in creation \"encrypted\" key", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
                return nil
            }
            
            
            let e2eMetadataFilesKey = e2eMetadata.filesKey(initializationVector: recordE2eEncryption.initializationVector, authenticationTag: recordE2eEncryption.authenticationTag, metadataKey: 0, encrypted: String(data: encryptedData, encoding: .utf8)!)
            files.updateValue(e2eMetadataFilesKey, forKey: recordE2eEncryption.fileNameIdentifier)
        }
        
        // Create "metadata"
        let e2eMetadataKey = e2eMetadata.metadataKey(metadataKeys: ["0":"dcccecfvdfvfvsfdvefvefvefvefvefv"], version: version)

        // Create final Json e2emetadata
        let e2emetadata = e2eMetadata(files: files, metadata: e2eMetadataKey, sharing: nil)

        do {
            
            let jsonData = try jsonEncoder.encode(e2emetadata)
            let jsonString = String(data: jsonData, encoding: .utf8)
            print("JSON String : " + jsonString!)
            
            return jsonString
            
        } catch let error {
            
            appDelegate.messageNotification("E2E encore metadata", description: "Serious internal error in encoding metadata ("+error.localizedDescription+")", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
        }
        
        return nil
    }
    
    // let dataDecoded : NSData = NSData(base64Encoded: encrypted, options: NSData.Base64DecodingOptions(rawValue: 0))!
    @objc func decoderMetadata(_ e2eMetaDataJSON: String, privateKey: String, serverUrl: String) -> Bool {
        
        let jsonDecoder = JSONDecoder.init()
        let data = e2eMetaDataJSON.data(using: .utf8)
        
        do {
            
            let response = try jsonDecoder.decode(e2eMetadata.self, from: data!)
            
            let files = response.files
            let metadata = response.metadata
            //let sharing = response.sharing
            
            var decodeMetadataKeys = [String:String]()
            
            for metadataKeys in metadata.metadataKeys {
                
                guard let metadataKeysData : NSData = NSData(base64Encoded: metadataKeys.value, options: NSData.Base64DecodingOptions(rawValue: 0)) else {
                    appDelegate.messageNotification("E2E decode metadata", description: "Serious internal error in decoding metadata", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
                    return false
                }

                guard let metadataKey = NCEndToEndEncryption.sharedManager().decryptAsymmetricData(metadataKeysData as Data!, privateKey: privateKey) else {
                    appDelegate.messageNotification("E2E decode metadata", description: "Serious internal error in decoding metadata", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
                    return false
                }
                
                // Encode to Base64
                let metadataKeyData = Data(base64Encoded: metadataKey, options: NSData.Base64DecodingOptions(rawValue: 0))!
                let metadataKeyBase64 = String(data: metadataKeyData, encoding: .utf8)

                decodeMetadataKeys[metadataKeys.key] = metadataKeyBase64
            }
            
            for file in files {
                
                let fileNameIdentifier = file.key
                let element = file.value as e2eMetadata.filesKey
                
                let encrypted = element.encrypted
                let key = decodeMetadataKeys["\(element.metadataKey)"]
                
                guard let decyptedMetadata = NCEndToEndEncryption.sharedManager().decryptMetadata(encrypted, key: key) else {
                    appDelegate.messageNotification("E2E decode metadata", description: "Serious internal error in decoding metadata", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
                    return false
                }
                
                do {
                    
                    let decrypted = try jsonDecoder.decode(e2eMetadata.encrypted.self, from: decyptedMetadata.data(using: .utf8)!)
                    
                    let object = tableE2eEncryption()
                    
                    object.account = appDelegate.activeAccount
                    object.authenticationTag = element.authenticationTag
                    object.fileName = decrypted.filename
                    object.fileNameIdentifier = fileNameIdentifier
                    object.key = decrypted.key
                    object.initializationVector = element.initializationVector
                    object.mimeType = decrypted.mimetype
                    object.serverUrl = serverUrl
                    object.version = decrypted.version
                    
                    if NCManageDatabase.sharedInstance.addE2eEncryption(object) == false {
                        appDelegate.messageNotification("E2E decode metadata", description: "Serious internal write DB", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
                        return false
                    }
                    
                } catch let error {
                    
                    appDelegate.messageNotification("E2E decode metadata", description: "Serious internal error in decoding metadata ("+error.localizedDescription+")", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
                    return false
                }
            }
            
        } catch let error {
            
            appDelegate.messageNotification("E2E decode metadata", description: "Serious internal error in decoding metadata ("+error.localizedDescription+")", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
            return false
        }
        
        return true
    }
}








