// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2017-2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

@MainActor
class NCEndToEndInit: NSObject {
    let utilityFileSystem = NCUtilityFileSystem()
    let global = NCGlobal.shared
    var extractedPublicKey: String?
    var controller: NCMainTabBarController?
    var metadata: tableMetadata?

    var session: NCSession.Session {
        NCSession.shared.getSession(controller: controller)
    }

    var windowScene: UIWindowScene? {
        SceneManager.shared.getWindowScene(controller: controller)
    }

    enum PassphraseChoice {
        case ok(passphrase: String)
        case copy(passphrase: String)
    }

    init(controller: NCMainTabBarController?, metadata: tableMetadata?) {
        super.init()

        self.controller = controller
        self.metadata = metadata

        // Clear all keys
        NCPreferences().clearAllKeysEndToEnd(account: session.account)
    }

    func start() async throws {
        try await getPublicKey()
        try await getPrivateKey()
    }

    func statusOfService(session: NCSession.Session) async -> NKError {
        let results = await NextcloudKit.shared.getE2EECertificateAsync(account: session.account)
        return results.error
    }

    private func getPublicKey() async throws {
        let results = await NextcloudKit.shared.getE2EECertificateAsync(account: session.account)

        switch results.error.errorCode {
        case .zero:
            guard let certificate = results.certificate else {
                throw NKError(errorCode: global.errorInternalError,
                              errorDescription: NSLocalizedString("E2E get publicKey - Bad request: internal error", comment: ""))
            }
            NCPreferences().setEndToEndCertificate(account: self.session.account, certificate: certificate)
            self.extractedPublicKey = NCEndToEndEncryption.shared().extractPublicKey(fromCertificate: certificate)

        case NCGlobal.shared.errorResourceNotFound:
            // Create CSR
            guard let csr = NCEndToEndEncryption.shared().createCSR(self.session.userId, directory: self.utilityFileSystem.directoryUserData) else {
                throw NKError(errorCode: global.errorInternalError,
                              errorDescription: NSLocalizedString("Error creating CSR", comment: ""))
            }

            // Get certificate from server
            let results = await NextcloudKit.shared.signE2EECertificateAsync(certificate: csr, account: self.session.account)
            guard results.error == .success,
                  let certificate = results.certificate
            else {
                throw results.error == .success
                    ? NKError(
                        errorCode: global.errorInternalError,
                        errorDescription: "certificate absent"
                    )
                    : results.error
            }

            // Verify PublicKey
            let extractedPublicKey = NCEndToEndEncryption.shared().extractPublicKey(fromCertificate: certificate)
            guard extractedPublicKey == NCEndToEndEncryption.shared().generatedPublicKey else {
                throw NKError(
                    errorCode: global.errorInternalError,
                    errorDescription: NSLocalizedString("E2E sign publicKey: the public key is incorrect", comment: "")
                )
            }
            NCPreferences().setEndToEndCertificate(account: self.session.account, certificate: certificate)

        default:
            throw results.error
        }
    }

    private func getPrivateKey() async throws {
        let results = await NextcloudKit.shared.getE2EEPrivateKeyAsync(account: self.session.account)
        switch results.error.errorCode {
        case .zero:
            guard let privateKeyChiper = results.privateKey else {
                throw NKError(errorCode: global.errorInternalError,
                              errorDescription: "PrivateKey absent"
                )
            }
            // request Passphrase
            let passphrase = try await requestPassphraseAsync()

            guard let privateKeyData = NCEndToEndEncryption.shared().decryptPrivateKey(privateKeyChiper, passphrase: passphrase),
                  let keyData = Data(base64Encoded: privateKeyData),
                  let privateKey = String(data: keyData, encoding: .utf8)
            else {
                throw NKError(
                    errorCode: global.errorInternalError,
                    errorDescription: "E2E decrypt privateKey failed"
                )
            }

            // Save
            NCPreferences().setEndToEndPrivateKey(account: session.account, privateKey: privateKey)
            NCPreferences().setEndToEndPassphrase(account: session.account, passphrase: passphrase)

            let results = await NextcloudKit.shared.getE2EEPublicKeyAsync(account: self.session.account)
            guard results.error == .success,
                  let publicKey = results.publicKey
            else {
                throw results.error == .success
                    ? NKError(
                        errorCode: global.errorInternalError,
                        errorDescription: "PublicKey absent"
                    )
                    : results.error
            }

            try await verifyPublicKey(publicKey)

            NCPreferences().setEndToEndPublicKey(account: self.session.account, publicKey: publicKey)
            NCManageDatabase.shared.clearTablesE2EE(account: self.session.account)

        case NCGlobal.shared.errorResourceNotFound:
            let choice = try await requestNewPassphraseAsync()

            switch choice {
            case .ok(let passphrase):
                try await createNewE2EE(e2ePassphrase: passphrase, copyPassphrase: false)

            case .copy(let passphrase):
                try await createNewE2EE(e2ePassphrase: passphrase, copyPassphrase: true)
            }
        default:
            throw results.error
        }
    }

    private func createNewE2EE(e2ePassphrase: String, copyPassphrase: Bool) async throws {
        var privateKeyString: NSString?

        guard let privateKey = NCEndToEndEncryption.shared().encryptPrivateKey(session.userId,
                                                                               directory: utilityFileSystem.directoryUserData,
                                                                               passphrase: e2ePassphrase,
                                                                               privateKey: &privateKeyString) else {
            throw NKError(
                errorCode: global.errorInternalError,
                errorDescription: "error creating private key cipher"
            )
        }

        let results = await NextcloudKit.shared.storeE2EEPrivateKeyAsync(privateKey: privateKey, account: self.session.account)
        switch results.error.errorCode {
        case .zero:
            guard let privateKey = results.privateKey else {
                throw NKError(
                    errorCode: global.errorInternalError,
                    errorDescription: "privateKey absent"
                )
            }

            NCPreferences().setEndToEndPrivateKey(account: self.session.account, privateKey: String(privateKey))
            NCPreferences().setEndToEndPassphrase(account: self.session.account, passphrase: e2ePassphrase)

            let results = await NextcloudKit.shared.getE2EEPublicKeyAsync(account: session.account)
            guard let publicKey = results.publicKey else {
                throw NKError(
                    errorCode: global.errorInternalError,
                    errorDescription: "publicKey absent"
                )
            }

            try await verifyPublicKey(publicKey)

            NCPreferences().setEndToEndPublicKey(account: session.account, publicKey: publicKey)
            NCManageDatabase.shared.clearTablesE2EE(account: session.account)

            if copyPassphrase {
                UIPasteboard.general.string = e2ePassphrase
            }

        default:
            throw results.error
        }
    }

    private func verifyPublicKey(_ publicKey: String) async throws {
        var verifyCertificate: Bool = false
        if let certificate = NCPreferences().getEndToEndCertificate(account: self.session.account) {
            verifyCertificate = NCEndToEndEncryption.shared().verifyCertificate(certificate, publicKey: publicKey)
        }
        if !verifyCertificate {
            throw NKError(
                errorCode: global.errorInternalError,
                errorDescription: "verify PublicKey error"
            )
        }
    }

    @MainActor
    private func requestPassphraseAsync() async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let alertController = UIAlertController(
                title: NSLocalizedString("_e2e_passphrase_request_title_", comment: ""),
                message: NSLocalizedString("_e2e_passphrase_request_message_", comment: ""),
                preferredStyle: .alert
            )

            var passphraseTextField: UITextField?

            let ok = UIAlertAction(title: "OK", style: .default) { _ in
                let passphrase = passphraseTextField?.text ?? ""
                continuation.resume(returning: passphrase)
            }

            let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                continuation.resume(throwing: NKError(
                    errorCode: NSUserCancelledError,
                    errorDescription: "User cancelled"
                ))
            }

            alertController.addAction(ok)
            alertController.addAction(cancel)

            alertController.addTextField { textField in
                passphraseTextField = textField
                textField.placeholder = NSLocalizedString("_enter_passphrase_", comment: "")
                textField.isSecureTextEntry = true
            }

            self.controller?.present(alertController, animated: true)
        }
    }

    @MainActor
    func requestNewPassphraseAsync() async throws -> PassphraseChoice {

        guard let e2ePassphrase = NYMnemonic.generateString(128, language: "english") else {
            throw NKError(
                errorCode: global.errorInternalError,
                errorDescription: "Failed to generate passphrase"
            )
        }

        let message = "\n" +
            NSLocalizedString("_e2e_settings_view_passphrase_", comment: "") +
            "\n\n" + e2ePassphrase

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PassphraseChoice, Error>) in

            let alertController = UIAlertController(
                title: NSLocalizedString("_e2e_settings_title_", comment: ""),
                message: message,
                preferredStyle: .alert
            )

            let okAction = UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default) { _ in
                continuation.resume(returning: .ok(passphrase: e2ePassphrase))
            }

            let copyAction = UIAlertAction(title: NSLocalizedString("_ok_copy_passphrase_", comment: ""), style: .default) { _ in
                continuation.resume(returning: .copy(passphrase: e2ePassphrase))
            }

            alertController.addAction(okAction)
            alertController.addAction(copyAction)

            self.controller?.present(alertController, animated: true)
        }
    }
}
