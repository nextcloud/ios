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
    
    var deletePublicKey = false;
    var deletePrivateKey = false;
    
    var signPublicKey = false;
    var storePrivateKey = false;
    
    override init() {
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: End To End Encryption - PublicKey
    // --------------------------------------------------------------------------------------------
    
    @objc func initEndToEndEncryption() {
        
        let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
        
        metadataNet.action = actionGetEndToEndPublicKeys;
        appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)

        metadataNet.action = actionGetEndToEndPrivateKeyCipher;
        appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
        
        metadataNet.action = actionGetEndToEndServerPublicKey;
        appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
    }
    
    func getEndToEndPublicKeysSuccess(_ metadataNet: CCMetadataNet!) {
    
        CCUtility.setEndToEndPublicKeySign(appDelegate.activeAccount, publicKey: metadataNet.key)
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionGetEndToEndPublicKeys, note: "E2E PublicKeys present on Server and stored to keychain", type: k_activityTypeSuccess, verbose: false, activeUrl: "")
    }
    
    func getEndToEndPublicKeysFailure(_ metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
    
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionGetEndToEndPublicKeys, note: message as String!, type: k_activityTypeFailure, verbose: false, activeUrl: "")
        
        switch errorCode {
            
        case 400:
            
            appDelegate.messageNotification("E2E public keys", description: "bad request: unpredictable internal error", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
        case 404:
            
            // public keys couldn't be found
            // remove keychain
            CCUtility.setEndToEndPublicKeySign(appDelegate.activeAccount, publicKey: nil)
            
            guard let publicKey = NCEndToEndEncryption.sharedManager().createEnd(toEndPublicKey: appDelegate.activeUserID, directoryUser: appDelegate.directoryUser) else {
                
                appDelegate.messageNotification("E2E public keys", description: "E2E Error to create PublicKey", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
                
                NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionGetEndToEndPublicKeys, note: "E2E Error to create PublicKey", type: k_activityTypeFailure, verbose: false, activeUrl: "")
                
                return
            }
            
            let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
            
            metadataNet.action = actionSignEndToEndPublicKey;
            metadataNet.key = publicKey;
            
            appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
            
        case 409:
        
            appDelegate.messageNotification("E2E public keys", description: "forbidden: the user can't access the public keys", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
        default:
        
            appDelegate.messageNotification("E2E public keys", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        }
    }

    func signEnd(toEndPublicKeySuccess metadataNet: CCMetadataNet!) {

        // Insert CSR To Cheychain end delete
        guard let publicKey = NCEndToEndEncryption.sharedManager().getCSRFromDisk(appDelegate.directoryUser, delete: true) else {
            
            appDelegate.messageNotification("E2E public key", description: "Error : publicKey not present", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
            
            return
        }
        
        // OK signed key locally keychain
        CCUtility.setEndToEndPublicKeySign(appDelegate.activeAccount, publicKey: publicKey)
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionSignEndToEndPublicKey, note: "E2E PublicKey sign on Server and stored locally", type: k_activityTypeFailure, verbose: false, activeUrl: "")
        
        signPublicKey = true
        if (storePrivateKey) {
            signPublicKey = false
            storePrivateKey = false
            alertController("_success_", message: "_e2e_settings_activated_")
        }
    }

    func signEnd(toEndPublicKeyFailure metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        signPublicKey = false
        
        appDelegate.messageNotification("E2E sign public keys", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionSignEndToEndPublicKey, note: message, type: k_activityTypeFailure, verbose: false, activeUrl: "")
    }
    
    func deleteEnd(toEndPublicKeySuccess metadataNet: CCMetadataNet!) {
        
        deletePublicKey = true
        if (deletePrivateKey) {
            deletePublicKey = false
            deletePrivateKey = false
            initEndToEndEncryption()
        }
    }
    
    func deleteEnd(toEndPublicKeyFailure metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        deletePublicKey = false
        
        appDelegate.messageNotification("E2E delete public key", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: End To End Encryption - PrivateKey
    // --------------------------------------------------------------------------------------------
    
    func getEndToEndPrivateKeyCipherSuccess(_ metadataNet: CCMetadataNet!) {
        
        // request Passphrase
        
        var passphraseTextField: UITextField?
        
        let alertController = UIAlertController(title: "UIAlertController", message: "UIAlertController With TextField", preferredStyle: .alert)
        
        let ok = UIAlertAction(title: "OK", style: .default, handler: { (action) -> Void in
            
            let passphrase = passphraseTextField?.text

            guard let privateKey = NCEndToEndEncryption.sharedManager().decryptPrivateKeyCipher(metadataNet.key, passphrase: passphrase) else {
                
                self.appDelegate.messageNotification("E2E decrypt private key", description: "E2E Error to decrypt Private Key", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
                
                NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionGetEndToEndPrivateKeyCipher, note: "E2E Error to decrypt Private Key", type: k_activityTypeFailure, verbose: false, activeUrl: "")
                
                return
            }
            
            // Save to keychain
            CCUtility.setEndToEndPrivateKey(self.appDelegate.activeAccount, privateKey: privateKey)
            
            // Save passphrase to keychain
            CCUtility.setEndToEndPassphrase(self.appDelegate.activeAccount, passphrase:passphrase)
            
            NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionGetEndToEndPrivateKeyCipher, note: "E2E PrivateKey present on Server and stored to keychain", type: k_activityTypeSuccess, verbose: false, activeUrl: "")
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
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionGetEndToEndPrivateKeyCipher, note: message as String!, type: k_activityTypeFailure, verbose: false, activeUrl: "")
        
        switch errorCode {
            
        case 400:
                
            appDelegate.messageNotification("E2E public keys", description: "bad request: unpredictable internal error", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
        case 404:
            
            // private keys couldn't be found
            // remove keychain
            CCUtility.setEndToEndPrivateKey(appDelegate.activeAccount, privateKey: nil)
            CCUtility.setEndToEndPassphrase(appDelegate.activeAccount, passphrase: nil)
            
            // message
            let message = NSLocalizedString("_e2e_settings_start_request_", comment: "") + "\n\n" + NSLocalizedString("_e2e_settings_view_passphrase_", comment: "") + "\n\n"
            
            let alertController = UIAlertController(title: NSLocalizedString("_start_", comment: ""), message: NSLocalizedString(message, comment: ""), preferredStyle: .alert)
            
            let OKAction = UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default) { action in

                guard let privateKeyChiper = NCEndToEndEncryption.sharedManager().createEnd(toEndPrivateKey: self.appDelegate.activeUserID, directoryUser: self.appDelegate.directoryUser, passphrase: self.appDelegate.e2ePassphrase) else {
                    
                    self.appDelegate.messageNotification("E2E private keys", description: "E2E Error to create PublicKey chiper", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
                    
                    NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionGetEndToEndPrivateKeyCipher, note: "E2E Error to create PublicKey chiper", type: k_activityTypeFailure, verbose: false, activeUrl: "")
                    
                    return
                }
                
                let metadataNet: CCMetadataNet = CCMetadataNet.init(account: self.appDelegate.activeAccount)
                
                metadataNet.action = actionStoreEndToEndPrivateKeyCipher
                metadataNet.key = privateKeyChiper
                metadataNet.password = self.appDelegate.e2ePassphrase
                
                self.appDelegate.addNetworkingOperationQueue(self.appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
            }
            
            alertController.addAction(OKAction)
            appDelegate.activeMain.present(alertController, animated: true)
            
        case 409:
            
            appDelegate.messageNotification("E2E private keys", description: "forbidden: the user can't access the private keys", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
        default:
            
            appDelegate.messageNotification("E2E private keys", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        }
    }
    
    func storeEnd(toEndPrivateKeyCipherSuccess metadataNet: CCMetadataNet!) {
        
        // Insert PrivateKey (end delete) and passphrase to Cheychain
        guard let privateKey = NCEndToEndEncryption.sharedManager().getPrivateKey(fromDisk: appDelegate.directoryUser, delete: true) else {
            
            appDelegate.messageNotification("E2E private key", description: "Error : privateKey not present", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
            
            return
        }
        
        CCUtility.setEndToEndPrivateKey(appDelegate.activeAccount, privateKey: privateKey)
        CCUtility.setEndToEndPassphrase(appDelegate.activeAccount, passphrase:metadataNet.password)
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionStoreEndToEndPrivateKeyCipher, note: "E2E PrivateKey stored on Server and stored locally", type: k_activityTypeSuccess, verbose: false, activeUrl: "")
        
        storePrivateKey = true
        if (signPublicKey) {
            signPublicKey = false
            storePrivateKey = false
            alertController("_success_", message: "_e2e_settings_activated_")
        }
    }
    
    func storeEnd(toEndPrivateKeyCipherFailure metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        storePrivateKey = false
        
        appDelegate.messageNotification("E2E sign private key", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionStoreEndToEndPrivateKeyCipher, note: message, type: k_activityTypeFailure, verbose: false, activeUrl: "")
    }
    
    func deleteEnd(toEndPrivateKeySuccess metadataNet: CCMetadataNet!) {
        
        deletePrivateKey = true
        if (deletePublicKey) {
            deletePublicKey = false
            deletePrivateKey = false
            initEndToEndEncryption()
        }
    }
    
    func deleteEnd(toEndPrivateKeyFailure metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        deletePrivateKey = false
        
        appDelegate.messageNotification("E2E delete private key", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: End To End Encryption - Server PublicKey
    // --------------------------------------------------------------------------------------------
    
    func getEndToEndServerPublicKeySuccess(_ metadataNet: CCMetadataNet!) {
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionGetEndToEndServerPublicKey, note: "E2E Server PublicKey present on Server and stored to keychain", type: k_activityTypeSuccess, verbose: false, activeUrl: "")
    }
    
    func getEndToEndServerPublicKeyFailure(_ metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionGetEndToEndServerPublicKey, note: message as String!, type: k_activityTypeFailure, verbose: false, activeUrl: "")
        
        switch (errorCode) {
            
        case 400:
            
            appDelegate.messageNotification("E2E Server public key", description: "bad request: unpredictable internal error", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
        case 404:
            
            appDelegate.messageNotification("E2E Server public key", description: "Server publickey doesn't exists", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
        case 409:
            appDelegate.messageNotification("E2E Server public key", description: "forbidden: the user can't access the Server publickey", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
        default:
            appDelegate.messageNotification("E2E Server public key", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        }
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Mark/Delete Encrypted Folder
    // --------------------------------------------------------------------------------------------
    
    func markEnd(toEndFolderEncryptedSuccess metadataNet: CCMetadataNet!) {
        print("E2E mark folder success")
    }
    
    func markEnd(toEndFolderEncryptedFailure metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
    
        // Unauthorized
        if (errorCode == kOCErrorServerUnauthorized) {
            appDelegate.openLoginView(appDelegate.activeMain, loginType: loginModifyPasswordUser)
        }
        
        if (errorCode != kOCErrorServerUnauthorized) {
            
            appDelegate.messageNotification("_error_", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        }
    }
    
    @objc func markEndToEndFolderEncrypted(_ metadata: tableMetadata) {
        
        let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)

        metadataNet.action = actionMarkEndToEndFolderEncrypted;
        metadataNet.fileID = metadata.fileID;
        
        appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)        
    }
    
    func deletemarkEnd(toEndFolderEncryptedSuccess metadataNet: CCMetadataNet!) {
        print("E2E delete mark folder success")
    }
    
    func deletemarkEnd(toEndFolderEncryptedFailure metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
       
        // Unauthorized
        if (errorCode == kOCErrorServerUnauthorized) {
            appDelegate.openLoginView(appDelegate.activeMain, loginType: loginModifyPasswordUser)
        }
        
        if (errorCode != kOCErrorServerUnauthorized) {
            
            appDelegate.messageNotification("_error_", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        }
    }
    
    @objc func deletemarkEndToEndFolderEncrypted(_ metadata: tableMetadata) {
        
        let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
        
        metadataNet.action = actionDeletemarkEndToEndFolderEncrypted;
        metadataNet.fileID = metadata.fileID;
        
        appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Form
    // --------------------------------------------------------------------------------------------
    
    func alertController(_ title: String, message: String) {
        
        let alertController = UIAlertController(title: NSLocalizedString(title, comment: ""), message: NSLocalizedString(message, comment: ""), preferredStyle: .alert)
        
        let OKAction = UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default) { action in
        }
        alertController.addAction(OKAction)

        appDelegate.activeMain.present(alertController, animated: true)
    }
}
