//
//  NCEndToEndInitialize.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 03/04/17.
//  Copyright © 2017 Marino Faggiana. All rights reserved.
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
import NCCommunication

@objc protocol NCEndToEndInitializeDelegate {
    
    func endToEndInitializeSuccess()
}

class NCEndToEndInitialize : NSObject  {

    @objc weak var delegate: NCEndToEndInitializeDelegate?

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    override init() {
    }
    
    // --------------------------------------------------------------------------------------------
    // MARK: Initialize
    // --------------------------------------------------------------------------------------------
    
    @objc func initEndToEndEncryption() {
        
        // Clear all keys
        CCUtility.clearAllKeysEnd(toEnd: appDelegate.account)
        
        self.getPublicKey()
    }
    
    func getPublicKey() {
    
        NCCommunication.shared.getE2EEPublicKey { (account, publicKey, errorCode, errorDescription) in
            
            if (errorCode == 0 && account == self.appDelegate.account) {
                
                CCUtility.setEndToEndPublicKey(account, publicKey: publicKey)
                
                // Request PrivateKey chiper to Server
                self.getPrivateKeyCipher()
                
            } else if errorCode != 0 {
                
                switch errorCode {
                    
                case 400:
                    NCContentPresenter.shared.messageNotification("E2E get publicKey", description: "bad request: unpredictable internal error", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                    
                case 404:
                    guard let csr = NCEndToEndEncryption.sharedManager().createCSR(self.appDelegate.userID, directory: CCUtility.getDirectoryUserData()) else {
                        
                        NCContentPresenter.shared.messageNotification("E2E Csr", description: "Error to create Csr", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                        
                        return
                    }
                    
                    NCCommunication.shared.signE2EEPublicKey(publicKey: csr) { (account, publicKey, errorCode, errorDescription) in
                        
                        if (errorCode == 0 && account == self.appDelegate.account) {
                            
                            CCUtility.setEndToEndPublicKey(account, publicKey: publicKey)
                            
                            // Request PrivateKey chiper to Server
                            self.getPrivateKeyCipher()
                            
                        } else if errorCode != 0 {
                            
                            switch errorCode {
                                
                            case 400:
                                NCContentPresenter.shared.messageNotification("E2E sign publicKey", description: "bad request: unpredictable internal error", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                                
                            case 409:
                                NCContentPresenter.shared.messageNotification("E2E sign publicKey", description: "conflict: a public key for the user already exists", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                                
                            default:
                                NCContentPresenter.shared.messageNotification("E2E sign publicKey", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                            }
                        }
                    }
                    
                case 409:
                    NCContentPresenter.shared.messageNotification("E2E get publicKey", description: "forbidden: the user can't access the public keys", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                    
                default:
                    NCContentPresenter.shared.messageNotification("E2E get publicKey", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                }
            }
        }
    }
    
    func getPrivateKeyCipher() {
        
        // Request PrivateKey chiper to Server
        NCCommunication.shared.getE2EEPrivateKey { (account, privateKeyChiper, errorCode, errorDescription) in
            
            if (errorCode == 0 && account == self.appDelegate.account) {
                
                // request Passphrase
                
                var passphraseTextField: UITextField?
                
                let alertController = UIAlertController(title: NSLocalizedString("_e2e_passphrase_request_title_", comment: ""), message: NSLocalizedString("_e2e_passphrase_request_message_", comment: ""), preferredStyle: .alert)
                
                let ok = UIAlertAction(title: "OK", style: .default, handler: { (action) -> Void in
                    
                    let passphrase = passphraseTextField?.text
                    
                    let publicKey = CCUtility.getEndToEndPublicKey(self.appDelegate.account)
                    
                    guard let privateKey = (NCEndToEndEncryption.sharedManager().decryptPrivateKey(privateKeyChiper, passphrase: passphrase, publicKey: publicKey)) else {
                        
                        NCContentPresenter.shared.messageNotification("E2E decrypt privateKey", description: "Serious internal error to decrypt Private Key", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError))
                        
                        return
                    }
                    
                    // privateKey
                    print(privateKey)
                    
                    // Save to keychain
                    CCUtility.setEndToEndPrivateKey(self.appDelegate.account, privateKey: privateKey)
                    CCUtility.setEndToEndPassphrase(self.appDelegate.account, passphrase:passphrase)
                    
                    // request publicKey Server()
                    NCCommunication.shared.getE2EEServerPublicKey { (account, publicKey, errorCode, errorDescription) in
                        
                        if (errorCode == 0 && account == self.appDelegate.account) {
                            
                            CCUtility.setEndToEndPublicKeyServer(account, publicKey: publicKey)
                            
                            // Clear Table
                            NCManageDatabase.sharedInstance.clearTable(tableDirectory.self, account: account)
                            NCManageDatabase.sharedInstance.clearTable(tableE2eEncryption.self, account: account)
                            
                            self.delegate?.endToEndInitializeSuccess()
                            
                        } else if errorCode != 0 {
                            
                            switch (errorCode) {
                                
                            case 400:
                                NCContentPresenter.shared.messageNotification("E2E Server publicKey", description: "bad request: unpredictable internal error", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                                
                            case 404:
                                NCContentPresenter.shared.messageNotification("E2E Server publicKey", description: "Server publickey doesn't exists", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                                
                            case 409:
                                NCContentPresenter.shared.messageNotification("E2E Server publicKey", description: "forbidden: the user can't access the Server publickey", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                                
                            default:
                                NCContentPresenter.shared.messageNotification("E2E Server publicKey", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                            }
                        }
                    }
                })
                
                let cancel = UIAlertAction(title: "Cancel", style: .cancel) { (action) -> Void in
                }
                
                alertController.addAction(ok)
                alertController.addAction(cancel)
                alertController.addTextField { (textField) -> Void in
                    passphraseTextField = textField
                    passphraseTextField?.placeholder = "Enter passphrase (12 words)"
                }
                
                self.appDelegate.activeMain.present(alertController, animated: true)
                
            } else if errorCode != 0 {
                
                switch errorCode {
                    
                case 400:
                    NCContentPresenter.shared.messageNotification("E2E get privateKey", description: "bad request: unpredictable internal error", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                    
                case 404:
                    // message
                    let e2ePassphrase = NYMnemonic.generateString(128, language: "english")
                    let message = "\n" + NSLocalizedString("_e2e_settings_view_passphrase_", comment: "") + "\n\n" + e2ePassphrase!
                    
                    let alertController = UIAlertController(title: NSLocalizedString("_e2e_settings_title_", comment: ""), message: NSLocalizedString(message, comment: ""), preferredStyle: .alert)
                    
                    let OKAction = UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default) { action in
                        
                        var privateKeyString: NSString?
                        
                        guard let privateKeyChiper = NCEndToEndEncryption.sharedManager().encryptPrivateKey(self.appDelegate.userID, directory: CCUtility.getDirectoryUserData(), passphrase: e2ePassphrase, privateKey: &privateKeyString) else {
                            
                            NCContentPresenter.shared.messageNotification("E2E privateKey", description: "Serious internal error to create PrivateKey chiper", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                            
                            return
                        }
                        
                        // privateKeyChiper
                        print(privateKeyChiper)
                        
                        NCCommunication.shared.storeE2EEPrivateKey(privateKey: privateKeyChiper) { (account, privateKey, errorCode, errorDescription) in
                       
                            if (errorCode == 0 && account == self.appDelegate.account) {
                                
                                CCUtility.setEndToEndPrivateKey(account, privateKey: privateKeyString! as String)
                                CCUtility.setEndToEndPassphrase(account, passphrase: e2ePassphrase)
                                
                                // request publicKey Server()
                                NCCommunication.shared.getE2EEServerPublicKey { (account, publicKey, errorCode, errorDescription) in
                                    
                                    if (errorCode == 0 && account == self.appDelegate.account) {
                                        
                                        CCUtility.setEndToEndPublicKeyServer(account, publicKey: publicKey)
                                        
                                        // Clear Table
                                        NCManageDatabase.sharedInstance.clearTable(tableDirectory.self, account: account)
                                        NCManageDatabase.sharedInstance.clearTable(tableE2eEncryption.self, account: account)
                                        
                                        self.delegate?.endToEndInitializeSuccess()
                                        
                                    } else if errorCode != 0 {
                                        
                                        switch (errorCode) {
                                            
                                        case 400:
                                            NCContentPresenter.shared.messageNotification("E2E Server publicKey", description: "bad request: unpredictable internal error", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                                            
                                        case 404:
                                            NCContentPresenter.shared.messageNotification("E2E Server publicKey", description: "Server publickey doesn't exists", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                                            
                                        case 409:
                                            NCContentPresenter.shared.messageNotification("E2E Server publicKey", description: "forbidden: the user can't access the Server publickey", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                                            
                                        default:
                                            NCContentPresenter.shared.messageNotification("E2E Server publicKey", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                                        }
                                    }
                                }
                                
                            } else if errorCode != 0 {
                                
                                switch errorCode {
                                    
                                case 400:
                                    NCContentPresenter.shared.messageNotification("E2E store privateKey", description: "bad request: unpredictable internal error", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                                    
                                case 409:
                                    NCContentPresenter.shared.messageNotification("E2E store privateKey", description: "conflict: a private key for the user already exists", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                                    
                                default:
                                    NCContentPresenter.shared.messageNotification("E2E store privateKey", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                                }
                            }
                        }
                    }
                    
                    alertController.addAction(OKAction)
                    self.appDelegate.activeMain.present(alertController, animated: true)
                    
                case 409:
                    NCContentPresenter.shared.messageNotification("E2E get privateKey", description: "forbidden: the user can't access the private key", delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                    
                default:
                    NCContentPresenter.shared.messageNotification("E2E get privateKey", description: errorDescription,delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                }
            }
        }
    }
    
}

