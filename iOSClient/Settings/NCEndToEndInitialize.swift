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

import UIKit
import NextcloudKit

@objc protocol NCEndToEndInitializeDelegate {

    func endToEndInitializeSuccess()
}

class NCEndToEndInitialize: NSObject {

    @objc weak var delegate: NCEndToEndInitializeDelegate?

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var extractedPublicKey: String?

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

    @objc func statusOfService(completion: @escaping (_ error: NKError?) -> Void) {

        NextcloudKit.shared.getE2EECertificate { _, _, _, _, error in
            completion(error)
        }
    }

    func getPublicKey() {

        NextcloudKit.shared.getE2EECertificate { account, certificate, _, _, error in

            if error == .success && account == self.appDelegate.account {

                CCUtility.setEndToEndCertificate(account, certificate: certificate)

                self.extractedPublicKey = NCEndToEndEncryption.sharedManager().extractPublicKey(fromCertificate: certificate)

                // Request PrivateKey chiper to Server
                self.getPrivateKeyCipher()

            } else if error != .success {

                switch error.errorCode {

                case NCGlobal.shared.errorBadRequest:
                    let error = NKError(errorCode: error.errorCode, errorDescription: "bad request: unpredictable internal error")
                    NCContentPresenter.shared.messageNotification("E2E get publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                case NCGlobal.shared.errorResourceNotFound:
                    guard let csr = NCEndToEndEncryption.sharedManager().createCSR(self.appDelegate.userId, directory: CCUtility.getDirectoryUserData()) else {
                        let error = NKError(errorCode: error.errorCode, errorDescription: "Error to create Csr")
                        NCContentPresenter.shared.messageNotification("E2E Csr", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                        return
                    }

                    NextcloudKit.shared.signE2EECertificate(certificate: csr) { account, certificate, data, error in

                        if error == .success && account == self.appDelegate.account {

                            // TEST publicKey
                            let extractedPublicKey = NCEndToEndEncryption.sharedManager().extractPublicKey(fromCertificate: certificate)
                            if extractedPublicKey != NCEndToEndEncryption.sharedManager().generatedPublicKey {
                                let error = NKError(errorCode: error.errorCode, errorDescription: "error: the public key is incorrect")
                                NCContentPresenter.shared.messageNotification("E2E sign publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                            } else {

                                CCUtility.setEndToEndCertificate(account, certificate: certificate)

                                // Request PrivateKey chiper to Server
                                self.getPrivateKeyCipher()
                            }

                        } else if error != .success {

                            switch error.errorCode {

                            case NCGlobal.shared.errorBadRequest:
                                let error = NKError(errorCode: error.errorCode, errorDescription: "bad request: unpredictable internal error")
                                NCContentPresenter.shared.messageNotification("E2E sign publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                            case NCGlobal.shared.errorConflict:
                                let error = NKError(errorCode: error.errorCode, errorDescription: "conflict: a public key for the user already exists")
                                NCContentPresenter.shared.messageNotification("E2E sign publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                            default:
                                NCContentPresenter.shared.messageNotification("E2E sign publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
                            }
                        }
                    }

                case NCGlobal.shared.errorConflict:
                    let error = NKError(errorCode: error.errorCode, errorDescription: "forbidden: the user can't access the public keys")
                    NCContentPresenter.shared.messageNotification("E2E get publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                default:
                    NCContentPresenter.shared.messageNotification("E2E get publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
                }
            }
        }
    }

    func getPrivateKeyCipher() {

        // Request PrivateKey chiper to Server
        NextcloudKit.shared.getE2EEPrivateKey { account, privateKeyChiper, data, error in

            if error == .success && account == self.appDelegate.account {

                // request Passphrase

                var passphraseTextField: UITextField?

                let alertController = UIAlertController(title: NSLocalizedString("_e2e_passphrase_request_title_", comment: ""), message: NSLocalizedString("_e2e_passphrase_request_message_", comment: ""), preferredStyle: .alert)

                let ok = UIAlertAction(title: "OK", style: .default, handler: { _ -> Void in

                    let passphrase = passphraseTextField?.text

                    let publicKey = CCUtility.getEndToEndCertificate(self.appDelegate.account)

                    if let privateKeyData = (NCEndToEndEncryption.sharedManager().decryptPrivateKey(privateKeyChiper, passphrase: passphrase, publicKey: publicKey)),
                       let keyData = Data(base64Encoded: privateKeyData) {
                        let privateKey = String(data: keyData, encoding: .utf8)
                        CCUtility.setEndToEndPrivateKey(self.appDelegate.account, privateKey: privateKey)
                    } else {

                        let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "Serious internal error to decrypt Private Key")
                        NCContentPresenter.shared.messageNotification("E2E decrypt privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                        return
                    }

                    // Save to keychain
                    CCUtility.setEndToEndPassphrase(self.appDelegate.account, passphrase: passphrase)

                    // request server publicKey
                    NextcloudKit.shared.getE2EEPublicKey { account, publicKey, data, error in

                        if error == .success && account == self.appDelegate.account {

                            CCUtility.setEndToEndPublicKey(account, publicKey: publicKey)

                            // Clear Table
                            NCManageDatabase.shared.clearTable(tableDirectory.self, account: account)
                            NCManageDatabase.shared.clearTable(tableE2eEncryption.self, account: account)

                            self.delegate?.endToEndInitializeSuccess()

                        } else if error != .success {

                            switch error.errorCode {

                            case NCGlobal.shared.errorBadRequest:
                                let error = NKError(errorCode: error.errorCode, errorDescription: "bad request: unpredictable internal error")
                                NCContentPresenter.shared.messageNotification("E2E Server publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                            case NCGlobal.shared.errorResourceNotFound:
                                let error = NKError(errorCode: error.errorCode, errorDescription: "Server publickey doesn't exists")
                                NCContentPresenter.shared.messageNotification("E2E Server publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                            case NCGlobal.shared.errorConflict:
                                let error = NKError(errorCode: error.errorCode, errorDescription: "forbidden: the user can't access the Server publickey")
                                NCContentPresenter.shared.messageNotification("E2E Server publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                            default:
                                NCContentPresenter.shared.messageNotification("E2E Server publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
                            }
                        }
                    }
                })

                let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ -> Void in
                }

                alertController.addAction(ok)
                alertController.addAction(cancel)
                alertController.addTextField { textField -> Void in
                    passphraseTextField = textField
                    passphraseTextField?.placeholder = NSLocalizedString("_enter_passphrase_", comment: "")
                }

                self.appDelegate.window?.rootViewController?.present(alertController, animated: true)

            } else if error != .success {

                switch error.errorCode {

                case NCGlobal.shared.errorBadRequest:
                    let error = NKError(errorCode: error.errorCode, errorDescription: "bad request: unpredictable internal error")
                    NCContentPresenter.shared.messageNotification("E2E get privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                case NCGlobal.shared.errorResourceNotFound:
                    // message
                    guard let e2ePassphrase = NYMnemonic.generateString(128, language: "english") else { return }
                    let message = "\n" + NSLocalizedString("_e2e_settings_view_passphrase_", comment: "") + "\n\n" + e2ePassphrase

                    let alertController = UIAlertController(title: NSLocalizedString("_e2e_settings_title_", comment: ""), message: NSLocalizedString(message, comment: ""), preferredStyle: .alert)

                    let OKAction = UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default) { _ in
                        self.createNewE2EE(e2ePassphrase: e2ePassphrase, error: error, copyPassphrase: false)
                    }

                    let copyAction = UIAlertAction(title: NSLocalizedString("_ok_copy_passphrase_", comment: ""), style: .default) { _ in
                        self.createNewE2EE(e2ePassphrase: e2ePassphrase, error: error, copyPassphrase: true)
                    }

                    alertController.addAction(OKAction)
                    alertController.addAction(copyAction)

                    self.appDelegate.window?.rootViewController?.present(alertController, animated: true)

                case NCGlobal.shared.errorConflict:
                    let error = NKError(errorCode: error.errorCode, errorDescription: "forbidden: the user can't access the private key")
                    NCContentPresenter.shared.messageNotification("E2E get privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                default:
                    NCContentPresenter.shared.messageNotification("E2E get privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
                }
            }
        }
    }

    func createNewE2EE(e2ePassphrase: String, error: NKError, copyPassphrase: Bool) {

        var privateKeyString: NSString?

        guard let privateKeyChiper = NCEndToEndEncryption.sharedManager().encryptPrivateKey(self.appDelegate.userId, directory: CCUtility.getDirectoryUserData(), passphrase: e2ePassphrase, privateKey: &privateKeyString) else {
            let error = NKError(errorCode: error.errorCode, errorDescription: "Serious internal error to create PrivateKey chiper")
            NCContentPresenter.shared.messageNotification("E2E privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
            return
        }

        // privateKeyChiper
        print(privateKeyChiper)

        NextcloudKit.shared.storeE2EEPrivateKey(privateKey: privateKeyChiper) { account, privateKey, data, error in

            if error == .success && account == self.appDelegate.account {

                CCUtility.setEndToEndPrivateKey(account, privateKey: privateKeyString! as String)
                CCUtility.setEndToEndPassphrase(account, passphrase: e2ePassphrase)

                // request server publicKey
                NextcloudKit.shared.getE2EEPublicKey { account, publicKey, data, error in

                    if error == .success && account == self.appDelegate.account {

                        CCUtility.setEndToEndPublicKey(account, publicKey: publicKey)

                        // Clear Table
                        NCManageDatabase.shared.clearTable(tableDirectory.self, account: account)
                        NCManageDatabase.shared.clearTable(tableE2eEncryption.self, account: account)

                        if copyPassphrase {
                            UIPasteboard.general.string = e2ePassphrase
                        }

                        self.delegate?.endToEndInitializeSuccess()

                    } else if error != .success {

                        switch error.errorCode {

                        case NCGlobal.shared.errorBadRequest:
                            let error = NKError(errorCode: error.errorCode, errorDescription: "bad request: unpredictable internal error")
                            NCContentPresenter.shared.messageNotification("E2E Server publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                        case NCGlobal.shared.errorResourceNotFound:
                            let error = NKError(errorCode: error.errorCode, errorDescription: "Server publickey doesn't exists")
                            NCContentPresenter.shared.messageNotification("E2E Server publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                        case NCGlobal.shared.errorConflict:
                            let error = NKError(errorCode: error.errorCode, errorDescription: "forbidden: the user can't access the Server publickey")
                            NCContentPresenter.shared.messageNotification("E2E Server publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                        default:
                            NCContentPresenter.shared.messageNotification("E2E Server publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
                        }
                    }
                }

            } else if error != .success {

                switch error.errorCode {

                case NCGlobal.shared.errorBadRequest:
                    let error = NKError(errorCode: error.errorCode, errorDescription: "bad request: unpredictable internal error")
                    NCContentPresenter.shared.messageNotification("E2E store privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                case NCGlobal.shared.errorConflict:
                    let error = NKError(errorCode: error.errorCode, errorDescription: "conflict: a private key for the user already exists")
                    NCContentPresenter.shared.messageNotification("E2E store privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                default:
                    NCContentPresenter.shared.messageNotification("E2E store privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
                }
            }
        }
    }

}
