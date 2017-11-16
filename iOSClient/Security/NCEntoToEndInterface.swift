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
        
        // Clear Table
        NCManageDatabase.sharedInstance.clearTable(tableDirectory.self, account: appDelegate.activeAccount)
        NCManageDatabase.sharedInstance.clearTable(tableE2eEncryption.self, account: appDelegate.activeAccount)

        // Reload All Datasource
        NotificationCenter.default.post(name: Notification.Name("clearDateReadDataSource"), object: nil)

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
    
    @objc func markEndToEndFolderEncrypted(_ url: String, fileID: String, serverUrl: String) -> Bool {
        
        var token: NSString?
        
        if let error = NCNetworkingSync.sharedManager().markEnd(toEndFolderEncrypted: appDelegate.activeUser, userID: appDelegate.activeUserID, password: appDelegate.activePassword, url: url, fileID: fileID, token: &token) as NSError? {
            
            appDelegate.messageNotification("E2E Mark folder as encrypted", description: error.localizedDescription+" code \(error.code)", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: error.code)

            NCManageDatabase.sharedInstance.setDirectoryE2ETokenLock(serverUrl: serverUrl, token: token as String?)

            return false
        }
        
        return true
    }
    
    @objc func deletemarkEndToEndFolderEncrypted(_ url: String, fileID: String, serverUrl: String) -> Bool {
        
        var token: NSString?

        if let error = NCNetworkingSync.sharedManager().deletemarkEnd(toEndFolderEncrypted: appDelegate.activeUser, userID: appDelegate.activeUserID, password: appDelegate.activePassword, url: url, fileID: fileID, token: &token) as NSError? {
            
            appDelegate.messageNotification("E2E Remove mark folder as encrypted", description: error.localizedDescription+" code \(error.code)", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: error.code)
            
            NCManageDatabase.sharedInstance.setDirectoryE2ETokenLock(serverUrl: serverUrl, token: token as String?)

            return false
        }
        
        return true
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Manage Metadata
    // --------------------------------------------------------------------------------------------
    
    func getEndToEndMetadataSuccess(_ metadataNet: CCMetadataNet!) {
        
        guard let privateKey = CCUtility.getEndToEndPrivateKey(appDelegate.activeAccount) else {
            
            appDelegate.messageNotification("E2E Get Metadata", description: "Serious internal error: PrivareKey not found", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
            return
        }

        guard let main = appDelegate.listMainVC[metadataNet.serverUrl] as? CCMain else {
            
            appDelegate.messageNotification("E2E Get Metadata", description: "Serious internal error: Main not found", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
            return
        }
        
        let serverUrl = metadataNet.serverUrl + "/" + metadataNet.fileName
        
        // Decode metadata JSON
        if NCEndToEndMetadata.sharedInstance.decoderMetadata(metadataNet.encryptedMetadata, privateKey: privateKey, serverUrl: serverUrl, account: appDelegate.activeAccount, url: appDelegate.activeUrl) == false {
        
            appDelegate.messageNotification("E2E decode metadata", description: "Serious internal error in decoding metadata", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
            return
        }

        // Clear all date directory and reload data source
        NCManageDatabase.sharedInstance.setClearAllDateReadDirectory()
        main.reloadDatasource(serverUrl)
    }
    
    func getEndToEndMetadataFailure(_ metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        // Unauthorized
        if (errorCode == kOCErrorServerUnauthorized) {
            
            appDelegate.openLoginView(appDelegate.activeMain, loginType: loginModifyPasswordUser)
            
        } else if (errorCode == 404) {
            
            // Remove all record e2eEncryption
            NCManageDatabase.sharedInstance.deleteE2eEncryption(predicate: NSPredicate(format: "account = %@ AND serverUrl = %@", appDelegate.activeAccount, metadataNet.serverUrl+"/"+metadataNet.fileName))
            
        } else if (errorCode != 404) {
            
            appDelegate.messageNotification("E2E Get metadata", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        }
    }
    
    @objc func getEndToEndMetadata(_ metadata: tableMetadata) {
        
        let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
        
        metadataNet.action = actionGetEndToEndMetadata;
        metadataNet.fileID = metadata.fileID;
        metadataNet.fileName = metadata.fileName;
        
        guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
            
            appDelegate.messageNotification("E2E Get metadata", description: "Serious internal error: ServerURL not found", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
            return
        }
        metadataNet.serverUrl = serverUrl
        
        appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
    }

}








