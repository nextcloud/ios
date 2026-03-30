// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2017 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

@MainActor
@objc protocol NCEndToEndInitializeDelegate {
    func endToEndInitializeSuccess(metadata: tableMetadata?)
}

@MainActor
class NCEndToEndInitialize: NSObject {
    @objc weak var delegate: NCEndToEndInitializeDelegate?
    let utilityFileSystem = NCUtilityFileSystem()
    var extractedPublicKey: String?
    var controller: NCMainTabBarController?
    var metadata: tableMetadata?

    var session: NCSession.Session {
        NCSession.shared.getSession(controller: controller)
    }

    var windowScene: UIWindowScene? {
        SceneManager.shared.getWindowScene(controller: controller)
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Initialize
    // --------------------------------------------------------------------------------------------

    func initEndToEndEncryption(controller: NCMainTabBarController?, metadata: tableMetadata?) {
        self.controller = controller
        self.metadata = metadata

        // Clear all keys
        NCPreferences().clearAllKeysEndToEnd(account: session.account)
        self.getPublicKey()
    }

    func statusOfService(session: NCSession.Session, completion: @escaping (_ error: NKError?) -> Void) {
        NextcloudKit.shared.getE2EECertificate(account: session.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: session.account,
                                                                                            name: "getE2EECertificate")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        } completion: { _, _, _, _, error in
            completion(error)
        }
    }

    private func getPublicKey() {
        NextcloudKit.shared.getE2EECertificate(account: session.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.session.account,
                                                                                            name: "getE2EECertificate")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        } completion: { account, certificate, _, _, error in
            if error == .success, let certificate {
                NCPreferences().setEndToEndCertificate(account: account, certificate: certificate)
                self.extractedPublicKey = NCEndToEndEncryption.shared().extractPublicKey(fromCertificate: certificate)
                // Request PrivateKey chiper to Server
                self.getPrivateKeyCipher()
            } else if error != .success {
                switch error.errorCode {
                case NCGlobal.shared.errorBadRequest:
                    Task {
                        await showErrorBanner(windowScene: self.windowScene,
                                              text: "E2E get publicKey - Bad request: internal error")
                    }
                case NCGlobal.shared.errorResourceNotFound:
                    guard let csr = NCEndToEndEncryption.shared().createCSR(self.session.userId, directory: self.utilityFileSystem.directoryUserData) else {
                        Task {
                            await showErrorBanner(windowScene: self.windowScene,
                                                  text: "Error creating CSR")
                        }
                        return
                    }

                    NextcloudKit.shared.signE2EECertificate(certificate: csr, account: account) {task in
                        Task {
                            let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                                        name: "signE2EECertificate")
                            await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                        }
                    } completion: { account, certificate, _, error in
                        if error == .success, let certificate {
                            // TEST publicKey
                            let extractedPublicKey = NCEndToEndEncryption.shared().extractPublicKey(fromCertificate: certificate)
                            if extractedPublicKey != NCEndToEndEncryption.shared().generatedPublicKey {
                                Task {
                                    await showErrorBanner(windowScene: self.windowScene,
                                                          text: "E2E sign publicKey: the public key is incorrect")
                                }
                            } else {
                                NCPreferences().setEndToEndCertificate(account: account, certificate: certificate)
                                // Request PrivateKey chiper to Server
                                self.getPrivateKeyCipher()
                            }
                        } else if error != .success {
                            Task {
                                switch error.errorCode {
                                case NCGlobal.shared.errorBadRequest:
                                    await showErrorBanner(windowScene: self.windowScene,
                                                          text: "E2E sign publicKey: bad request: internal error")
                                case NCGlobal.shared.errorConflict:
                                    await showErrorBanner(windowScene: self.windowScene,
                                                          text: "E2E sign publicKey: conflict, a public key for the user already exists")
                                default:
                                    await showErrorBanner(windowScene: self.windowScene,
                                                          text: "E2E sign publicKey: \(error.errorDescription)")
                                }
                            }
                        }
                    }
                case NCGlobal.shared.errorConflict:
                    Task {
                        await showErrorBanner(windowScene: self.windowScene,
                                              text: "E2E get publicKey: forbidden, the user can't access the public keys")
                    }
                default:
                    Task {
                        await showErrorBanner(windowScene: self.windowScene,
                                              text: "E2E get publicKey: \(error.errorDescription)")
                    }
                }
            }
        }
    }

    func detectPrivateKeyFormat(from data: Data) -> String {
        print("🔍 Hex dump:", data.prefix(32).map { String(format: "%02X", $0) }.joined(separator: " "))

        // PKCS#8 has OBJECT IDENTIFIER for RSA
        let oidRsaPrefix: [UInt8] = [0x30, 0x0D, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01]

        if data.range(of: Data(oidRsaPrefix)) != nil {
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
        NextcloudKit.shared.getE2EEPrivateKey(account: session.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.session.account,
                                                                                            name: "getE2EEPrivateKey")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        } completion: { account, privateKeyChiper, _, error in
            if error == .success {
                // request Passphrase
                var passphraseTextField: UITextField?
                let alertController = UIAlertController(title: NSLocalizedString("_e2e_passphrase_request_title_", comment: ""), message: NSLocalizedString("_e2e_passphrase_request_message_", comment: ""), preferredStyle: .alert)
                let ok = UIAlertAction(title: "OK", style: .default, handler: { _ in
                    let passphrase = passphraseTextField?.text ?? ""
                    if let privateKeyData = NCEndToEndEncryption.shared().decryptPrivateKey(privateKeyChiper, passphrase: passphrase),
                       let keyData = Data(base64Encoded: privateKeyData),
                       let privateKey = String(data: keyData, encoding: .utf8) {
                        NCPreferences().setEndToEndPrivateKey(account: account, privateKey: privateKey)
                    } else {
                        Task {
                            await showErrorBanner(windowScene: self.windowScene,
                                                  text: "E2E decrypt privateKey: serious internal error to decrypt Private Key")
                        }
                        return
                    }
                    // Save to keychain
                    NCPreferences().setEndToEndPassphrase(account: account, passphrase: passphrase)
                    // request server publicKey
                    NextcloudKit.shared.getE2EEPublicKey(account: account) { task in
                        Task {
                            let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.session.account,
                                                                                                        name: "getE2EEPublicKey")
                            await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                        }
                    } completion: { account, publicKey, _, error in
                        if error == .success, let publicKey {

                            // Verify Certificate
                            var verifyCertificate: Bool = false
                            if let certificate = NCPreferences().getEndToEndCertificate(account: account) {
                                verifyCertificate = NCEndToEndEncryption.shared().verifyCertificate(certificate, publicKey: publicKey)
                            }
                            if verifyCertificate == false {
                                Task {
                                    await showErrorBanner(windowScene: self.windowScene,
                                                          text: "E2E verify certificate server: serious internal error to verify certificate")
                                }
                                return
                            }

                            NCPreferences().setEndToEndPublicKey(account: account, publicKey: publicKey)
                            NCManageDatabase.shared.clearTablesE2EE(account: account)

                            self.delegate?.endToEndInitializeSuccess(metadata: self.metadata)

                        } else if error != .success {
                            Task {
                                switch error.errorCode {
                                case NCGlobal.shared.errorBadRequest:
                                    await showErrorBanner(windowScene: self.windowScene,
                                                          text: "E2E Server publicKey: bad request: internal error")
                                case NCGlobal.shared.errorResourceNotFound:
                                    await showErrorBanner(windowScene: self.windowScene,
                                                          text: "E2E Server publicKey: server public key doesn't exist")
                                case NCGlobal.shared.errorConflict:
                                    await showErrorBanner(windowScene: self.windowScene,
                                                          text: "E2E Server publicKey: forbidden, the user can't access the Server public key")
                                default:
                                    await showErrorBanner(windowScene: self.windowScene,
                                                          text: "E2E Server publicKey: \(error.errorDescription)")
                                }
                            }
                        }
                    }
                })

                let cancel = UIAlertAction(title: "Cancel", style: .cancel)
                alertController.addAction(ok)
                alertController.addAction(cancel)
                alertController.addTextField { textField in
                    passphraseTextField = textField
                    passphraseTextField?.placeholder = NSLocalizedString("_enter_passphrase_", comment: "")
                }

                self.controller?.present(alertController, animated: true)
            } else if error != .success {
                switch error.errorCode {
                case NCGlobal.shared.errorBadRequest:
                    Task {
                        await showErrorBanner(windowScene: self.windowScene,
                                              text: "E2E get privateKey: bad request, internal error")
                    }
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
                    Task {
                        await showErrorBanner(windowScene: self.windowScene,
                                              text: "E2E get privateKey: forbidden, the user can't access the private key")
                    }
                default:
                    Task {
                        await showErrorBanner(windowScene: self.windowScene,
                                              text: "E2E get privateKey: \(error.errorDescription)")
                    }
                }
            }
        }
    }

    private func createNewE2EE(e2ePassphrase: String, error: NKError, copyPassphrase: Bool) {
        var privateKeyString: NSString?
        guard let privateKeyCipher = NCEndToEndEncryption.shared().encryptPrivateKey(session.userId, directory: utilityFileSystem.directoryUserData, passphrase: e2ePassphrase, privateKey: &privateKeyString) else {
            Task {
                await showErrorBanner(windowScene: self.windowScene,
                                      text: "E2E privateKey: error creating private key cipher")
            }
            return
        }

        // privateKeyChiper
        print(privateKeyCipher)

        NextcloudKit.shared.storeE2EEPrivateKey(privateKey: privateKeyCipher, account: session.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.session.account,
                                                                                            name: "storeE2EEPrivateKey")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        } completion: { account, _, _, error in
            if error == .success, let privateKey = privateKeyString {

                NCPreferences().setEndToEndPrivateKey(account: account, privateKey: String(privateKey))
                NCPreferences().setEndToEndPassphrase(account: account, passphrase: e2ePassphrase)

                // request server publicKey
                NextcloudKit.shared.getE2EEPublicKey(account: account) { task in
                    Task {
                        let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.session.account,
                                                                                                    name: "getE2EEPublicKey")
                        await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                    }
                } completion: { account, publicKey, _, error in
                    if error == .success, let publicKey {

                        var verifyCertificate: Bool = false
                        if let certificate = NCPreferences().getEndToEndCertificate(account: account) {
                            verifyCertificate = NCEndToEndEncryption.shared().verifyCertificate(certificate, publicKey: publicKey)
                        }
                        if verifyCertificate == false {
                            Task {
                                await showErrorBanner(windowScene: self.windowScene,
                                                      text: "E2E verify certificate server: serious internal error to verify certificate")
                            }
                            return
                        }

                        NCPreferences().setEndToEndPublicKey(account: account, publicKey: publicKey)
                        NCManageDatabase.shared.clearTablesE2EE(account: account)

                        if copyPassphrase {
                            UIPasteboard.general.string = e2ePassphrase
                        }
                        self.delegate?.endToEndInitializeSuccess(metadata: self.metadata)
                    } else if error != .success {
                        Task {
                            switch error.errorCode {
                            case NCGlobal.shared.errorBadRequest:
                                await showErrorBanner(windowScene: self.windowScene,
                                                      text: "E2E Server publicKey: bad request, internal error")
                            case NCGlobal.shared.errorResourceNotFound:
                                await showErrorBanner(windowScene: self.windowScene,
                                                      text: "E2E Server publicKey: server public key doesn't exist")
                            case NCGlobal.shared.errorConflict:
                                await showErrorBanner(windowScene: self.windowScene,
                                                      text: "E2E Server publicKey: forbidden, the user can't access the Server public key",)
                            default:
                                await showErrorBanner(windowScene: self.windowScene,
                                                      text: "E2E Server publicKey: \(error.errorDescription)")
                            }
                        }
                    }
                }
            } else if error != .success {
                Task {
                    switch error.errorCode {
                    case NCGlobal.shared.errorBadRequest:
                        await showErrorBanner(windowScene: self.windowScene,
                                              text: "E2E store privateKey: bad request, internal error")
                    case NCGlobal.shared.errorConflict:
                        await showErrorBanner(windowScene: self.windowScene,
                                              text: "E2E store privateKey: conflict, a private key for the user already exists")
                    default:
                        await showErrorBanner(windowScene: self.windowScene,
                                              text: "E2E store privateKey: \(error.errorDescription)")
                    }
                }
            }
        }
    }
}
