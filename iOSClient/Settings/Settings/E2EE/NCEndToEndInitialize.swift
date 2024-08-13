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
    func endToEndInitializeSuccess(metadata: tableMetadata?)
}

class NCEndToEndInitialize: NSObject {
    @objc weak var delegate: NCEndToEndInitializeDelegate?
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    let utilityFileSystem = NCUtilityFileSystem()
    var extractedPublicKey: String?
    var viewController: UIViewController?
    var metadata: tableMetadata?

    // --------------------------------------------------------------------------------------------
    // MARK: Initialize
    // --------------------------------------------------------------------------------------------

    func initEndToEndEncryption(viewController: UIViewController?, metadata: tableMetadata?) {
        self.viewController = viewController
        self.metadata = metadata

        // Clear all keys
        NCKeychain().clearAllKeysEndToEnd(account: appDelegate.account)
        self.getPublicKey()
    }

    func statusOfService(completion: @escaping (_ error: NKError?) -> Void) {
        NextcloudKit.shared.getE2EECertificate(account: appDelegate.account) { _, _, _, _, error in
            completion(error)
        }
    }

    func getPublicKey() {

        NextcloudKit.shared.getE2EECertificate(account: appDelegate.account) { account, certificate, _, _, error in

            if error == .success, account == self.appDelegate.account, let certificate {

                NCKeychain().setEndToEndCertificate(account: account, certificate: certificate)

                self.extractedPublicKey = NCEndToEndEncryption.shared().extractPublicKey(fromCertificate: certificate)

                // Request PrivateKey chiper to Server
                self.getPrivateKeyCipher()

            } else if error != .success {

                switch error.errorCode {

                case NCGlobal.shared.errorBadRequest:
                    let error = NKError(errorCode: error.errorCode, errorDescription: "Bad request: internal error")
                    NCContentPresenter().messageNotification("E2E get publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                case NCGlobal.shared.errorResourceNotFound:
                    guard let csr = NCEndToEndEncryption.shared().createCSR(self.appDelegate.userId, directory: self.utilityFileSystem.directoryUserData) else {
                        let error = NKError(errorCode: error.errorCode, errorDescription: "Error creating CSR")
                        NCContentPresenter().messageNotification("E2E Csr", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                        return
                    }

                    NextcloudKit.shared.signE2EECertificate(certificate: csr, account: account) { account, certificate, _, error in

                        if error == .success, account == self.appDelegate.account, let certificate {

                            // TEST publicKey
                            let extractedPublicKey = NCEndToEndEncryption.shared().extractPublicKey(fromCertificate: certificate)
                            if extractedPublicKey != NCEndToEndEncryption.shared().generatedPublicKey {
                                let error = NKError(errorCode: error.errorCode, errorDescription: "error: the public key is incorrect")
                                NCContentPresenter().messageNotification("E2E sign publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                            } else {

                                NCKeychain().setEndToEndCertificate(account: account, certificate: certificate)

                                // Request PrivateKey chiper to Server
                                self.getPrivateKeyCipher()
                            }

                        } else if error != .success {

                            switch error.errorCode {

                            case NCGlobal.shared.errorBadRequest:
                                let error = NKError(errorCode: error.errorCode, errorDescription: "Bad request: internal error")
                                NCContentPresenter().messageNotification("E2E sign publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                            case NCGlobal.shared.errorConflict:
                                let error = NKError(errorCode: error.errorCode, errorDescription: "Conflict: a public key for the user already exists")
                                NCContentPresenter().messageNotification("E2E sign publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                            default:
                                NCContentPresenter().messageNotification("E2E sign publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
                            }
                        }
                    }

                case NCGlobal.shared.errorConflict:
                    let error = NKError(errorCode: error.errorCode, errorDescription: "Forbidden: the user can't access the public keys")
                    NCContentPresenter().messageNotification("E2E get publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                default:
                    NCContentPresenter().messageNotification("E2E get publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
                }
            }
        }
    }

    func getPrivateKeyCipher() {

        // Request PrivateKey chiper to Server
        NextcloudKit.shared.getE2EEPrivateKey(account: appDelegate.account) { account, privateKeyChiper, _, error in

            if error == .success && account == self.appDelegate.account {

                // request Passphrase

                var passphraseTextField: UITextField?

                let alertController = UIAlertController(title: NSLocalizedString("_e2e_passphrase_request_title_", comment: ""), message: NSLocalizedString("_e2e_passphrase_request_message_", comment: ""), preferredStyle: .alert)

                let ok = UIAlertAction(title: "OK", style: .default, handler: { _ -> Void in

                    let passphrase = passphraseTextField?.text ?? ""

                    let publicKey = NCKeychain().getEndToEndCertificate(account: self.appDelegate.account)

                    if let privateKeyData = (NCEndToEndEncryption.shared().decryptPrivateKey(privateKeyChiper, passphrase: passphrase, publicKey: publicKey, iterationCount: 1024)),
                       let keyData = Data(base64Encoded: privateKeyData),
                       let privateKey = String(data: keyData, encoding: .utf8) {
                        NCKeychain().setEndToEndPrivateKey(account: self.appDelegate.account, privateKey: privateKey)
                    } else {

                        let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "Serious internal error to decrypt Private Key")
                        NCContentPresenter().messageNotification("E2E decrypt privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                        return
                    }

                    // Save to keychain
                    NCKeychain().setEndToEndPassphrase(account: self.appDelegate.account, passphrase: passphrase)

                    // request server publicKey
                    NextcloudKit.shared.getE2EEPublicKey(account: account) { account, publicKey, _, error in

                        if error == .success, account == self.appDelegate.account, let publicKey {

                            NCKeychain().setEndToEndPublicKey(account: account, publicKey: publicKey)
                            NCManageDatabase.shared.clearTablesE2EE(account: account)

                            self.delegate?.endToEndInitializeSuccess(metadata: self.metadata)

                        } else if error != .success {

                            switch error.errorCode {

                            case NCGlobal.shared.errorBadRequest:
                                let error = NKError(errorCode: error.errorCode, errorDescription: "Bad request: internal error")
                                NCContentPresenter().messageNotification("E2E Server publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                            case NCGlobal.shared.errorResourceNotFound:
                                let error = NKError(errorCode: error.errorCode, errorDescription: "Server public key doesn't exist")
                                NCContentPresenter().messageNotification("E2E Server publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                            case NCGlobal.shared.errorConflict:
                                let error = NKError(errorCode: error.errorCode, errorDescription: "Forbidden: the user can't access the Server public key")
                                NCContentPresenter().messageNotification("E2E Server publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                            default:
                                NCContentPresenter().messageNotification("E2E Server publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
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

                self.viewController?.present(alertController, animated: true)

            } else if error != .success {

                switch error.errorCode {

                case NCGlobal.shared.errorBadRequest:
                    let error = NKError(errorCode: error.errorCode, errorDescription: "Bad request: internal error")
                    NCContentPresenter().messageNotification("E2E get privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

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

                    self.viewController?.present(alertController, animated: true)

                case NCGlobal.shared.errorConflict:
                    let error = NKError(errorCode: error.errorCode, errorDescription: "Forbidden: the user can't access the private key")
                    NCContentPresenter().messageNotification("E2E get privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                default:
                    NCContentPresenter().messageNotification("E2E get privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
                }
            }
        }
    }

    func createNewE2EE(e2ePassphrase: String, error: NKError, copyPassphrase: Bool) {

        var privateKeyString: NSString?

        guard let privateKeyCipher = NCEndToEndEncryption.shared().encryptPrivateKey(self.appDelegate.userId, directory: utilityFileSystem.directoryUserData, passphrase: e2ePassphrase, privateKey: &privateKeyString, iterationCount: 1024) else {
            let error = NKError(errorCode: error.errorCode, errorDescription: "Error creating private key cipher")
            NCContentPresenter().messageNotification("E2E privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
            return
        }

        // privateKeyChiper
        print(privateKeyCipher)

        NextcloudKit.shared.storeE2EEPrivateKey(privateKey: privateKeyCipher, account: appDelegate.account) { account, _, _, error in

            if error == .success, account == self.appDelegate.account, let privateKey = privateKeyString {

                NCKeychain().setEndToEndPrivateKey(account: account, privateKey: String(privateKey))
                NCKeychain().setEndToEndPassphrase(account: account, passphrase: e2ePassphrase)

                // request server publicKey
                NextcloudKit.shared.getE2EEPublicKey(account: account) { account, publicKey, _, error in

                    if error == .success, account == self.appDelegate.account, let publicKey {

                        NCKeychain().setEndToEndPublicKey(account: account, publicKey: publicKey)
                        NCManageDatabase.shared.clearTablesE2EE(account: account)

                        if copyPassphrase {
                            UIPasteboard.general.string = e2ePassphrase
                        }

                        self.delegate?.endToEndInitializeSuccess(metadata: self.metadata)

                    } else if error != .success {

                        switch error.errorCode {

                        case NCGlobal.shared.errorBadRequest:
                            let error = NKError(errorCode: error.errorCode, errorDescription: "Bad request: internal error")
                            NCContentPresenter().messageNotification("E2E Server publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                        case NCGlobal.shared.errorResourceNotFound:
                            let error = NKError(errorCode: error.errorCode, errorDescription: "Server public key doesn't exist")
                            NCContentPresenter().messageNotification("E2E Server publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                        case NCGlobal.shared.errorConflict:
                            let error = NKError(errorCode: error.errorCode, errorDescription: "Forbidden: the user can't access the Server public key")
                            NCContentPresenter().messageNotification("E2E Server publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                        default:
                            NCContentPresenter().messageNotification("E2E Server publicKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
                        }
                    }
                }

            } else if error != .success {

                switch error.errorCode {

                case NCGlobal.shared.errorBadRequest:
                    let error = NKError(errorCode: error.errorCode, errorDescription: "Bad request: internal error")
                    NCContentPresenter().messageNotification("E2E store privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                case NCGlobal.shared.errorConflict:
                    let error = NKError(errorCode: error.errorCode, errorDescription: "Conflict: a private key for the user already exists")
                    NCContentPresenter().messageNotification("E2E store privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                default:
                    NCContentPresenter().messageNotification("E2E store privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
                }
            }
        }
    }

}
