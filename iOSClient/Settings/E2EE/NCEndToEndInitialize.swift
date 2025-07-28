// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2017 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

@objc protocol NCEndToEndInitializeDelegate {
    func endToEndInitializeSuccess(metadata: tableMetadata?)
}

class NCEndToEndInitialize: NSObject {
    @objc weak var delegate: NCEndToEndInitializeDelegate?
    let utilityFileSystem = NCUtilityFileSystem()
    var extractedPublicKey: String?
    var controller: NCMainTabBarController?
    var metadata: tableMetadata?
    var session: NCSession.Session {
        NCSession.shared.getSession(controller: controller)
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Initialize
    // --------------------------------------------------------------------------------------------

    func initEndToEndEncryption(controller: NCMainTabBarController?, metadata: tableMetadata?) {
        self.controller = controller
        self.metadata = metadata

        // Clear all keys
        NCKeychain().clearAllKeysEndToEnd(account: session.account)
        self.getPublicKey()
    }

    func statusOfService(session: NCSession.Session, completion: @escaping (_ error: NKError?) -> Void) {
        NextcloudKit.shared.getE2EECertificate(account: session.account) { _, _, _, _, error in
            completion(error)
        }
    }

    private func getPublicKey() {

        NextcloudKit.shared.getE2EECertificate(account: session.account) { account, certificate, _, _, error in
            if error == .success, let certificate {
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
                    guard let csr = NCEndToEndEncryption.shared().createCSR(self.session.userId, directory: self.utilityFileSystem.directoryUserData) else {
                        let error = NKError(errorCode: error.errorCode, errorDescription: "Error creating CSR")
                        NCContentPresenter().messageNotification("E2E Csr", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                        return
                    }

                    NextcloudKit.shared.signE2EECertificate(certificate: csr, account: account) { account, certificate, _, error in
                        if error == .success, let certificate {
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

    func detectPrivateKeyFormat(from data: Data) -> String {
        print("🔍 Hex dump:", data.prefix(32).map { String(format: "%02X", $0) }.joined(separator: " "))

        // PKCS#8 has OBJECT IDENTIFIER for RSA
        let oidRsaPrefix: [UInt8] = [0x30, 0x0D, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01]

        if let range = data.range(of: Data(oidRsaPrefix)) {
            print("🔐 Format: PKCS#8 (BEGIN PRIVATE KEY)")
            return "PKCS#8"
        } else if data.starts(with: [0x30, 0x82]) {
            print("🔐 Format: PKCS#1 (BEGIN RSA PRIVATE KEY)")
            return "PKCS#1"
        } else {
            print("❌ Unknown key format")
            return "Unknown"
        }
    }

    private func getPrivateKeyCipher() {
        // Request PrivateKey chiper to Server
        NextcloudKit.shared.getE2EEPrivateKey(account: session.account) { account, privateKeyChiper, _, error in
            if error == .success {
                // request Passphrase
                var passphraseTextField: UITextField?
                let alertController = UIAlertController(title: NSLocalizedString("_e2e_passphrase_request_title_", comment: ""), message: NSLocalizedString("_e2e_passphrase_request_message_", comment: ""), preferredStyle: .alert)
                let ok = UIAlertAction(title: "OK", style: .default, handler: { _ in
                    let passphrase = passphraseTextField?.text ?? ""
                    if let privateKeyData = NCEndToEndEncryption.shared().decryptPrivateKey(privateKeyChiper, passphrase: passphrase),
                       let keyData = Data(base64Encoded: privateKeyData),
                       let privateKey = String(data: keyData, encoding: .utf8) {
                        NCKeychain().setEndToEndPrivateKey(account: account, privateKey: privateKey)
                    } else {
                        let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "Serious internal error to decrypt Private Key")
                        NCContentPresenter().messageNotification("E2E decrypt privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)

                        return
                    }
                    // Save to keychain
                    NCKeychain().setEndToEndPassphrase(account: account, passphrase: passphrase)
                    // request server publicKey
                    NextcloudKit.shared.getE2EEPublicKey(account: account) { account, publicKey, _, error in
                        if error == .success, let publicKey {
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

                self.controller?.present(alertController, animated: true)
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

                    self.controller?.present(alertController, animated: true)
                case NCGlobal.shared.errorConflict:
                    let error = NKError(errorCode: error.errorCode, errorDescription: "Forbidden: the user can't access the private key")
                    NCContentPresenter().messageNotification("E2E get privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
                default:
                    NCContentPresenter().messageNotification("E2E get privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
                }
            }
        }
    }

    private func createNewE2EE(e2ePassphrase: String, error: NKError, copyPassphrase: Bool) {
        var privateKeyString: NSString?
        guard let privateKeyCipher = NCEndToEndEncryption.shared().encryptPrivateKey(session.userId, directory: utilityFileSystem.directoryUserData, passphrase: e2ePassphrase, privateKey: &privateKeyString, iterationCount: 1024) else {
            let error = NKError(errorCode: error.errorCode, errorDescription: "Error creating private key cipher")
            NCContentPresenter().messageNotification("E2E privateKey", error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
            return
        }

        // privateKeyChiper
        print(privateKeyCipher)

        NextcloudKit.shared.storeE2EEPrivateKey(privateKey: privateKeyCipher, account: session.account) { account, _, _, error in
            if error == .success, let privateKey = privateKeyString {

                NCKeychain().setEndToEndPrivateKey(account: account, privateKey: String(privateKey))
                NCKeychain().setEndToEndPassphrase(account: account, passphrase: e2ePassphrase)

                // request server publicKey
                NextcloudKit.shared.getE2EEPublicKey(account: account) { account, publicKey, _, error in
                    if error == .success, let publicKey {

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
