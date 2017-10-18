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
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: metadataNet.selector, note: "E2E PublicKeys present on Server and stored to keychain", type: k_activityTypeSuccess, verbose: false, activeUrl: "")
    }
    
    func getEndToEndPublicKeysFailure(_ metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
    
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: metadataNet.selector, note: message as String!, type: k_activityTypeFailure, verbose: false, activeUrl: "")
        
        switch errorCode {
            
            case 400:
                appDelegate.messageNotification("E2E public keys", description: "bad request: unpredictable internal error", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            case 404:
                // public keys couldn't be found
                // remove keychain
                CCUtility.setEndToEndPublicKeySign(appDelegate.activeAccount, publicKey: nil)
            
                let publicKey = NCEndToEndEncryption.sharedManager().createEnd(toEndPublicKey: appDelegate.activeUserID, directoryUser: appDelegate.directoryUser)
                if (publicKey != nil) {
                
                    let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)

                    metadataNet.action = actionSignEndToEndPublicKey;
                    metadataNet.key = publicKey;
                
                    appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
                
                } else {
                
                    appDelegate.messageNotification("E2E public keys", description: "E2E Error to create PublicKey", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
                
                    NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionSignEndToEndPublicKey, note: "E2E Error to create PublicKey", type: k_activityTypeFailure, verbose: false, activeUrl: "")
                }
            
            case 409:
                appDelegate.messageNotification("E2E public keys", description: "forbidden: the user can't access the public keys", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
            default:
                appDelegate.messageNotification("E2E public keys", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        }
    }

    func signEnd(toEndPublicKeySuccess metadataNet: CCMetadataNet!) {

        // Insert CSR To Cheychain end delete
        let publicKey = NCEndToEndEncryption.sharedManager().getCSRFromDisk(appDelegate.directoryUser, delete: true)
        
        // OK signed key locally keychain
        CCUtility.setEndToEndPublicKeySign(appDelegate.activeAccount, publicKey: publicKey)
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: metadataNet.selector, note: "E2E PublicKey sign on Server and stored locally", type: k_activityTypeFailure, verbose: false, activeUrl: "")
    }

    func signEnd(toEndPublicKeyFailure metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        appDelegate.messageNotification("E2E sign public keys", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: metadataNet.selector, note: message, type: k_activityTypeFailure, verbose: false, activeUrl: "")
    }
    
    func deleteEnd(toEndPublicKeySuccess metadataNet: CCMetadataNet!) {
        appDelegate.messageNotification("E2E delete public key", description: "Public key was deleted", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.success, errorCode: 0)
    }
    
    func deleteEnd(toEndPublicKeyFailure metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        appDelegate.messageNotification("E2E delete public key", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: End To End Encryption - PrivateKey
    // --------------------------------------------------------------------------------------------
    
    func getEndToEndPrivateKeyCipherSuccess(_ metadataNet: CCMetadataNet!) {
        
        let privateKey = NCEndToEndEncryption.sharedManager().decryptPrivateKeyCipher(metadataNet.key, mnemonic: k_Mnemonic_test)
        
        if (privateKey != nil) {
            
            // Save to keychain
            CCUtility.setEndToEndPrivateKey(appDelegate.activeAccount, privateKey: privateKey)
            
            // Save mnemonic to keychain
            CCUtility.setEndToEndMnemonic(appDelegate.activeAccount, mnemonic:k_Mnemonic_test)

            NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: metadataNet.selector, note: "E2E PrivateKey present on Server and stored to keychain", type: k_activityTypeSuccess, verbose: false, activeUrl: "")
            
        } else {
            
            appDelegate.messageNotification("E2E decrypt private key", description: "E2E Error to decrypt Private Key", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
            
            NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: metadataNet.selector, note: "E2E Error to decrypt Private Key", type: k_activityTypeFailure, verbose: false, activeUrl: "")
        }
    }
    
    func getEndToEndPrivateKeyCipherFailure(_ metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: metadataNet.selector, note: message as String!, type: k_activityTypeFailure, verbose: false, activeUrl: "")
        
        switch errorCode {
            
            case 400:
                
                appDelegate.messageNotification("E2E public keys", description: "bad request: unpredictable internal error", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
            case 404:
                // private keys couldn't be found
                // remove keychain
                CCUtility.setEndToEndPrivateKey(appDelegate.activeAccount, privateKey: nil)
                CCUtility.setEndToEndMnemonic(appDelegate.activeAccount, mnemonic: nil)

                let mnemonic = k_Mnemonic_test;
            
                let privateKeyChiper = NCEndToEndEncryption.sharedManager().createEnd(toEndPrivateKey: appDelegate.activeUserID, directoryUser: appDelegate.directoryUser, mnemonic: mnemonic)
            
                if (privateKeyChiper != nil) {
                    
                    let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
                    
                    metadataNet.action = actionStoreEndToEndPrivateKeyCipher
                    metadataNet.key = privateKeyChiper
                    metadataNet.password = mnemonic
                    
                    appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
                    
                } else {
                    
                    appDelegate.messageNotification("E2E private keys", description: "E2E Error to create PublicKey chiper", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
                    
                    NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionSignEndToEndPublicKey, note: "E2E Error to create PublicKey chiper", type: k_activityTypeFailure, verbose: false, activeUrl: "")
                }
            
            case 409:
                appDelegate.messageNotification("E2E private keys", description: "forbidden: the user can't access the private keys", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            
            default:
                appDelegate.messageNotification("E2E private keys", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        }
    }
    
    func storeEnd(toEndPrivateKeyCipherSuccess metadataNet: CCMetadataNet!) {
        
        // Insert PrivateKey (end delete) and mnemonic to Cheychain
        let privateKey = NCEndToEndEncryption.sharedManager().getPrivateKey(fromDisk: appDelegate.directoryUser, delete: true)
        
        CCUtility.setEndToEndPrivateKey(appDelegate.activeAccount, privateKey: privateKey)
        CCUtility.setEndToEndMnemonic(appDelegate.activeAccount, mnemonic:metadataNet.password)
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionSignEndToEndPublicKey, note: "E2E PrivateKey stored on Server and stored locally", type: k_activityTypeSuccess, verbose: false, activeUrl: "")
    }
    
    func storeEnd(toEndPrivateKeyCipherFailure metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        appDelegate.messageNotification("E2E sign private key", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: metadataNet.selector, note: message, type: k_activityTypeFailure, verbose: false, activeUrl: "")
    }
    
    func deleteEnd(toEndPrivateKeySuccess metadataNet: CCMetadataNet!) {
        appDelegate.messageNotification("E2E delete private key", description: "Private key was deleted", visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.success, errorCode: 0)
    }
    
    func deleteEnd(toEndPrivateKeyFailure metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        appDelegate.messageNotification("E2E delete private key", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: 0)
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: End To End Encryption - Server PublicKey
    // --------------------------------------------------------------------------------------------
    
    func getEndToEndServerPublicKeySuccess(_ metadataNet: CCMetadataNet!) {
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: metadataNet.selector, note: "E2E Server PublicKey present on Server and stored to keychain", type: k_activityTypeSuccess, verbose: false, activeUrl: "")
    }
    
    func getEndToEndServerPublicKeyFailure(_ metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: metadataNet.selector, note: message as String!, type: k_activityTypeFailure, verbose: false, activeUrl: "")
        
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
    
    func deleteEnd(toEndFolderEncryptedSuccess metadataNet: CCMetadataNet!) {
        print("E2E delete folder success")
    }
    
    func deleteEnd(toEndFolderEncryptedFailure metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
       
        // Unauthorized
        if (errorCode == kOCErrorServerUnauthorized) {
            appDelegate.openLoginView(appDelegate.activeMain, loginType: loginModifyPasswordUser)
        }
        
        if (errorCode != kOCErrorServerUnauthorized) {
            
            appDelegate.messageNotification("_error_", description: message as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        }
    }
    
    @objc func deleteEndToEndFolderEncrypted(_ metadata: tableMetadata) {
        
        let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
        
        metadataNet.action = actionDeleteEndToEndFolderEncrypted;
        metadataNet.fileID = metadata.fileID;
        
        appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
    }
}
