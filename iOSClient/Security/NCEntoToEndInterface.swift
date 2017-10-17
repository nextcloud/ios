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
    
    
    func getEndToEndServerPublicKeySuccess(_ metadataNet: CCMetadataNet!) {
    
        CCUtility.setEndToEndPublicKeySign(appDelegate.activeAccount, publicKey: metadataNet.key)
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: metadataNet.selector, note: "E2E PublicKeys present on Server and stored to keychain", type: k_activityTypeSuccess, verbose: true, activeUrl: appDelegate.activeUrl)
    }
    
    func getEndToEndPublicKeysFailure(_ metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
    
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionSignEndToEndPublicKey, note: message as String!, type: k_activityTypeFailure, verbose: true, activeUrl: appDelegate.activeUrl)
        
        switch errorCode {
            
        case 400:
            appDelegate.messageNotification("E2E public keys", description: "bad request: unpredictable internal error" as String!, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
        case 404:
            // public keys couldn't be found
            // remove keychain
            CCUtility.setEndToEndPublicKeySign(appDelegate.activeAccount, publicKey: nil)
            
            let metadataNet: CCMetadataNet = CCMetadataNet.init(account: appDelegate.activeAccount)
            let publicKey = NCEndToEndEncryption.sharedManager().createEnd(toEndPublicKey: appDelegate.activeUserID, directoryUser: appDelegate.directoryUser)
            
            if (publicKey != nil) {
                
                metadataNet.action = actionSignEndToEndPublicKey;
                metadataNet.key = publicKey;
                
                appDelegate.addNetworkingOperationQueue(appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
                
            } else {
                
                NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: actionSignEndToEndPublicKey, note: "E2E Error to create PublicKeyEncoded", type: k_activityTypeFailure, verbose: true, activeUrl: appDelegate.activeUrl)
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
        
        NCManageDatabase.sharedInstance.addActivityClient("", fileID: "", action: k_activityDebugActionEndToEndEncryption, selector: metadataNet.selector, note: "E2E PublicKey sign on Server and stored locally", type: k_activityTypeFailure, verbose: true, activeUrl: appDelegate.activeUrl)
    }

    func signEnd(toEndPublicKeyFailure metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
    }
    
    /*
    - (void)signEndToEndPublicKeyFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
    {
    [app messageNotification:@"E2E sign public key" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
    
    // Activity
    [[NCManageDatabase sharedInstance] addActivityClient:@"" fileID:@"" action:k_activityDebugActionEndToEndEncryption selector:metadataNet.selector note:message type:k_activityTypeFailure verbose:k_activityVerboseHigh activeUrl:app.activeUrl];
    }
    */
    
    
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
