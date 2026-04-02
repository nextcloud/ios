// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2017-2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

/// Coordinates the full End-to-End Encryption (E2EE) initialization flow.
///
/// Responsibilities:
/// - Ensures the user certificate exists (or creates/signs it if missing)
/// - Retrieves or creates the encrypted private key
/// - Handles user passphrase input when required
/// - Decrypts and stores the private key locally
/// - Fetches and verifies the server public key
/// - Finalizes the E2EE setup and clears local metadata tables
///
/// Notes:
/// - This class runs entirely on the MainActor due to UI interactions (alerts)
/// - Networking is performed via NextcloudKit async APIs
/// - Errors are propagated using `throws` and must be handled by the caller
@MainActor
class NCEndToEndSetup {
    let utilityFileSystem = NCUtilityFileSystem()
    let global = NCGlobal.shared
    var extractedPublicKey: String?
    var controller: NCMainTabBarController?

    var session: NCSession.Session {
        NCSession.shared.getSession(controller: controller)
    }

    enum PassphraseChoice {
        case ok(passphrase: String)
        case copy(passphrase: String)
    }

    init(controller: NCMainTabBarController?) {
        self.controller = controller
    }

    /// Starts the E2EE initialization pipeline.
    ///
    /// Flow:
    /// 1. Clear all keys e2ee in preferences
    /// 2. Ensure a valid certificate exists (fetch or create/sign)
    /// 3. Ensure a valid private key exists (fetch or create)
    ///
    /// - Throws: `NKError` if any step fails (network, crypto, validation, or user cancellation)
    func start() async throws {
        // Clear all keys
        NCPreferences().clearAllKeysEndToEnd(account: session.account)

        try await getPublicKey()
        try await getPrivateKey()
    }

    /// Ensures that a valid user certificate is available.
    ///
    /// Behavior:
    /// - If the certificate exists, it is validated and stored locally
    /// - If missing, a CSR is generated and sent to the server for signing
    /// - The returned certificate is verified against the locally generated public key
    ///
    /// - Throws:
    ///   - `NKError` if CSR generation fails
    ///   - `NKError` if certificate is missing or invalid
    ///   - Server errors propagated from NextcloudKit
    private func getPublicKey() async throws {
        let results = await NextcloudKit.shared.getE2EECertificateAsync(account: session.account)

        switch results.error.errorCode {
        case .zero:
            guard let certificate = results.certificate else {
                throw NKError(errorCode: global.errorInternalError,
                              errorDescription: NSLocalizedString("_e2ee_setup_get_certificate_", comment: ""))
            }
            NCPreferences().setEndToEndCertificate(account: self.session.account, certificate: certificate)
            self.extractedPublicKey = NCEndToEndEncryption.shared().extractPublicKey(fromCertificate: certificate)

        case NCGlobal.shared.errorResourceNotFound:
            // Create CSR
            guard let csr = NCEndToEndEncryption.shared().createCSR(self.session.userId, directory: self.utilityFileSystem.directoryUserData) else {
                throw NKError(errorCode: global.errorInternalError,
                              errorDescription: NSLocalizedString("_e2ee_setup_create_csr_", comment: ""))
            }

            // Get certificate from server
            let results = await NextcloudKit.shared.signE2EECertificateAsync(certificate: csr, account: self.session.account)
            guard results.error == .success,
                  let certificate = results.certificate
            else {
                throw results.error == .success
                    ? NKError(
                        errorCode: global.errorInternalError,
                        errorDescription: NSLocalizedString("_e2ee_setup_sign_certificate_", comment: "")
                    )
                    : results.error
            }

            // Verify PublicKey
            let extractedPublicKey = NCEndToEndEncryption.shared().extractPublicKey(fromCertificate: certificate)
            guard extractedPublicKey == NCEndToEndEncryption.shared().generatedPublicKey else {
                throw NKError(
                    errorCode: global.errorInternalError,
                    errorDescription: NSLocalizedString("_e2ee_setup_extract_publickey_", comment: "")
                )
            }
            NCPreferences().setEndToEndCertificate(account: self.session.account, certificate: certificate)

        default:
            throw results.error
        }
    }

    /// Ensures that a valid private key is available and usable.
    ///
    /// Behavior:
    /// - If the encrypted private key exists:
    ///   - Prompts the user for passphrase
    ///   - Decrypts and stores the private key locally
    /// - If missing:
    ///   - Generates a new passphrase (user-confirmed)
    ///   - Creates and uploads a new encrypted private key
    ///
    /// After success:
    /// - Fetches the server public key
    /// - Verifies certificate consistency
    /// - Clears E2EE database tables
    ///
    /// - Throws:
    ///   - `NKError` for decryption failures
    ///   - `NKError` for missing data
    ///   - `NSUserCancelledError` if user cancels input
    ///   - Server errors propagated from NextcloudKit
    private func getPrivateKey() async throws {
        let results = await NextcloudKit.shared.getE2EEPrivateKeyAsync(account: self.session.account)

        switch results.error.errorCode {
        case .zero:
            guard let privateKeyCipher = results.privateKey else {
                throw NKError(
                    errorCode: global.errorInternalError,
                    errorDescription: NSLocalizedString("_e2ee_setup_get_privatekey_", comment: "")
                )
            }

            let passphrase = try await requestPassphraseAsync()

            guard let privateKeyData = NCEndToEndEncryption.shared().decryptPrivateKey(privateKeyCipher, passphrase: passphrase),
                  let keyData = Data(base64Encoded: privateKeyData),
                  let privateKey = String(data: keyData, encoding: .utf8)
            else {
                throw NKError(
                    errorCode: global.errorInternalError,
                    errorDescription: NSLocalizedString("_e2ee_setup_passphrase_error_", comment: "")
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
                        errorDescription: NSLocalizedString("_e2ee_setup_get_publickey_", comment: "")
                    )
                    : results.error
            }

            try verifyPublicKey(publicKey)

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

    /// Creates and stores a new E2EE private key.
    ///
    /// Steps:
    /// 1. Generates a new encrypted private key using the provided passphrase
    /// 2. Uploads the encrypted key (cipher) to the server
    /// 3. Stores the plaintext private key and passphrase locally
    /// 4. Fetches and verifies the server public key
    /// 5. Finalizes E2EE setup (clears metadata tables)
    ///
    /// - Parameters:
    ///   - e2ePassphrase: User-generated passphrase
    ///   - copyPassphrase: Whether to copy the passphrase to the pasteboard
    ///
    /// - Throws:
    ///   - `NKError` if encryption fails
    ///   - `NKError` if server responses are invalid
    ///   - Server errors propagated from NextcloudKit
    private func createNewE2EE(e2ePassphrase: String, copyPassphrase: Bool) async throws {
        var privateKeyString: NSString?

        guard let privateKeyCipher = NCEndToEndEncryption.shared().encryptPrivateKey(
            session.userId,
            directory: utilityFileSystem.directoryUserData,
            passphrase: e2ePassphrase,
            privateKey: &privateKeyString
        ) else {
            throw NKError(
                errorCode: global.errorInternalError,
                errorDescription: NSLocalizedString("_e2ee_setup_encript_privatekey_", comment: "")
            )
        }

        // Store cipher on server

        let storeResults = await NextcloudKit.shared.storeE2EEPrivateKeyAsync(
            privateKey: privateKeyCipher,
            account: session.account
        )

        switch storeResults.error.errorCode {
        case .zero:

            guard let privateKeyString else {
                throw NKError(
                    errorCode: global.errorInternalError,
                    errorDescription: NSLocalizedString("_e2ee_setup_store_privatekey_", comment: "")
                )
            }

            let privateKey = String(privateKeyString)

            // Save locally
            NCPreferences().setEndToEndPrivateKey(account: session.account, privateKey: privateKey)
            NCPreferences().setEndToEndPassphrase(account: session.account, passphrase: e2ePassphrase)

            // Fetch server public key

            let publicKeyResults = await NextcloudKit.shared.getE2EEPublicKeyAsync(account: session.account)

            guard publicKeyResults.error == .success,
                  let publicKey = publicKeyResults.publicKey
            else {
                throw publicKeyResults.error == .success
                    ? NKError(
                        errorCode: global.errorInternalError,
                        errorDescription: NSLocalizedString("_e2ee_setup_get_publickey_", comment: "")
                    )
                    : publicKeyResults.error
            }

            // Verify

            try verifyPublicKey(publicKey)

            // Finalize

            NCPreferences().setEndToEndPublicKey(account: session.account, publicKey: publicKey)
            NCManageDatabase.shared.clearTablesE2EE(account: session.account)

            if copyPassphrase {
                UIPasteboard.general.string = e2ePassphrase
            }

        default:
            throw storeResults.error
        }
    }

    /// Verifies that the server public key matches the locally stored certificate.
    ///
    /// - Parameter publicKey: Public key retrieved from the server
    ///
    /// - Throws:
    ///   - `NKError` if certificate is missing or validation fails
    private func verifyPublicKey(_ publicKey: String) throws {
        guard let certificate = NCPreferences().getEndToEndCertificate(account: session.account),
              NCEndToEndEncryption.shared().verifyCertificate(certificate, publicKey: publicKey)
        else {
            throw NKError(
                errorCode: global.errorInternalError,
                errorDescription: NSLocalizedString("_e2ee_setup_verify_publickey_", comment: "")
            )
        }
    }

    /// Presents a secure alert asking the user for the E2EE passphrase.
    ///
    /// - Returns: The user-entered passphrase
    ///
    /// - Throws:
    ///   - `NKError` with `NSUserCancelledError` if the user cancels the dialog
    ///
    /// - Note:
    ///   - Always executed on MainActor due to UIKit usage
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

    /// Generates and presents a new passphrase to the user.
    ///
    /// The user can:
    /// - Accept the passphrase
    /// - Accept and copy it to clipboard
    ///
    /// - Returns: `PassphraseChoice` indicating user action and passphrase
    ///
    /// - Throws:
    ///   - `NKError` if passphrase generation fails
    ///
    /// - Note:
    ///   - Always executed on MainActor due to UIKit usage
    func requestNewPassphraseAsync() async throws -> PassphraseChoice {
        guard let e2ePassphrase = NYMnemonic.generateString(128, language: "english") else {
            throw NKError(
                errorCode: global.errorInternalError,
                errorDescription: NSLocalizedString("_e2ee_setup_generate_passphrase_", comment: "")
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
