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
    let preference = NCPreferences()
    let networkingE2EE = NCNetworkingE2EE()
    let endToEndEncryption = NCEndToEndEncryption.shared()

    var extractedPublicKey: String?
    var controller: NCMainTabBarController?
    var options = NKRequestOptions()

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
    /// 1. Archive the current E2EE key set and temporarily clear the active keys
    /// 2. Ensure a valid certificate exists (fetch or create/sign)
    /// 3. Ensure a valid private key exists (fetch or create)
    /// 4. Restore the previous active state if any step fails
    ///
    /// - Throws: `NKError` if any step fails (network, crypto, validation, or user cancellation)
    func start() async throws {
        // Preserve the previous key space before replacing the active keys.
        // A Keychain failure stops setup before any key material is removed.
        let previousKeySet = try preference.archiveCurrentEndToEndKeySet(account: session.account)
        let wasServerKeyStale = preference.isEndToEndServerKeyStale(account: session.account)
        preference.clearCurrentKeysEndToEnd(account: session.account)
        nkLog(
            tag: global.logTagE2EE,
            message: "E2EE setup started; previous active key set archived: \(previousKeySet != nil)."
        )

        do {
            // get version E2EE
            let capabilities = await NKCapabilities.shared.getCapabilities(for: session.account)
            options = networkingE2EE.getOptions(account: session.account, capabilities: capabilities)

            try await getPublicKey()
            try await getPrivateKey()
            preference.setEndToEndServerKeyStale(account: session.account, stale: false)
            await NCNetworkingE2EE.markServerKeyAsValidated(account: session.account)
            nkLog(tag: global.logTagE2EE, message: "E2EE setup completed successfully.")
        } catch {
            restoreCurrentKeySet(previousKeySet, serverKeyStale: wasServerKeyStale)
            nkLog(tag: global.logTagE2EE, message: "E2EE setup failed; restored the previous active key state.")
            throw error
        }
    }

    /// Restores the exact local state that existed before setup started.
    /// The archived snapshot remains available and immutable.
    private func restoreCurrentKeySet(_ keySet: NCEndToEndKeySet?, serverKeyStale: Bool) {
        preference.setEndToEndCertificate(account: session.account, certificate: keySet?.certificate)
        preference.setEndToEndPrivateKey(account: session.account, privateKey: keySet?.privateKey)
        preference.setEndToEndPublicKey(account: session.account, publicKey: keySet?.publicKey)
        preference.setEndToEndPassphrase(account: session.account, passphrase: keySet?.passphrase)
        preference.setEndToEndServerKeyStale(account: session.account, stale: serverKeyStale)
    }

    /// Replaces a stale local key set with the key set currently published by
    /// the server. All remote values are fetched and cryptographically checked
    /// before any active Keychain value is replaced.
    func updateChangedServerKey() async throws {
        nkLog(tag: global.logTagE2EE, message: "Changed server-key reconciliation started.")
        let capabilities = await NKCapabilities.shared.getCapabilities(for: session.account)
        options = networkingE2EE.getOptions(account: session.account, capabilities: capabilities)

        let serverPublicKeyResult = await NextcloudKit.shared.getE2EEPublicKeyAsync(
            account: session.account,
            options: options
        )

        guard serverPublicKeyResult.error == .success,
              let serverPublicKey = serverPublicKeyResult.publicKey,
              !serverPublicKey.isEmpty else {
            throw serverPublicKeyResult.error == .success ? NKError.invalidData : serverPublicKeyResult.error
        }

        let certificateResult = await NextcloudKit.shared.getE2EECertificateAsync(
            account: session.account,
            options: options
        )

        if certificateResult.error.errorCode == global.errorResourceNotFound {
            nkLog(tag: global.logTagE2EE, message: "No server user certificate found; starting E2EE setup.")
            try await start()
            return
        }

        guard certificateResult.error == .success,
              let certificate = certificateResult.certificate,
              !certificate.isEmpty else {
            throw certificateResult.error == .success ? NKError.invalidData : certificateResult.error
        }

        let privateKeyResult = await NextcloudKit.shared.getE2EEPrivateKeyAsync(
            account: session.account,
            options: options
        )
        guard privateKeyResult.error == .success,
              let privateKeyCipher = privateKeyResult.privateKey,
              !privateKeyCipher.isEmpty else {
            throw privateKeyResult.error == .success ? NKError.invalidData : privateKeyResult.error
        }

        let passphrase = try await requestPassphraseAsync(
            title: NSLocalizedString("_e2ee_server_key_changed_title_", comment: ""),
            message: NSLocalizedString("_e2ee_server_key_changed_", comment: "")
        )
        guard let privateKeyData = endToEndEncryption?.decryptPrivateKey(
            privateKeyCipher,
            passphrase: passphrase
        ),
        let decodedPrivateKeyData = Data(base64Encoded: privateKeyData),
        let privateKey = String(data: decodedPrivateKeyData, encoding: .utf8),
        !privateKey.isEmpty else {
            throw NKError(
                errorCode: global.errorInternalError,
                errorDescription: NSLocalizedString("_e2ee_setup_passphrase_error_", comment: "")
            )
        }

        guard let endToEndEncryption,
              endToEndEncryption.verifyCertificate(certificate, publicKey: serverPublicKey) else {
            throw NKError(
                errorCode: global.errorInternalError,
                errorDescription: NSLocalizedString("_e2ee_setup_verify_publickey_", comment: "")
            )
        }

        try verifyPrivateKey(privateKey, matches: certificate)

        // The new set is complete and verified. Only now preserve and replace
        // the previous active values.
        try preference.archiveCurrentEndToEndKeySet(account: session.account)
        preference.setEndToEndCertificate(account: session.account, certificate: certificate)
        preference.setEndToEndPrivateKey(account: session.account, privateKey: privateKey)
        preference.setEndToEndPublicKey(account: session.account, publicKey: serverPublicKey)
        preference.setEndToEndPassphrase(account: session.account, passphrase: passphrase)
        preference.setEndToEndServerKeyStale(account: session.account, stale: false)
        await NCNetworkingE2EE.markServerKeyAsValidated(account: session.account)
        NCManageDatabase.shared.clearTablesE2EE(account: session.account)
        nkLog(tag: global.logTagE2EE, message: "Changed server-key reconciliation completed successfully.")
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
        let results = await NextcloudKit.shared.getE2EECertificateAsync(account: session.account, options: options)

        switch results.error.errorCode {
        case .zero:
            guard let certificate = results.certificate else {
                throw NKError(errorCode: global.errorInternalError,
                              errorDescription: NSLocalizedString("_e2ee_setup_get_certificate_", comment: ""))
            }
            preference.setEndToEndCertificate(account: self.session.account, certificate: certificate)
            self.extractedPublicKey = endToEndEncryption?.extractPublicKey(fromCertificate: certificate)

        case NCGlobal.shared.errorResourceNotFound:
            // Create CSR
            guard let csr = endToEndEncryption?.createCSR(self.session.userId, directory: self.utilityFileSystem.directoryUserData) else {
                throw NKError(errorCode: global.errorInternalError,
                              errorDescription: NSLocalizedString("_e2ee_setup_create_csr_", comment: ""))
            }

            // Get certificate from server
            let results = await NextcloudKit.shared.signE2EECertificateAsync(certificate: csr, account: self.session.account, options: options)
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
            let extractedPublicKey = endToEndEncryption?.extractPublicKey(fromCertificate: certificate)
            guard extractedPublicKey == endToEndEncryption?.generatedPublicKey else {
                throw NKError(
                    errorCode: global.errorInternalError,
                    errorDescription: NSLocalizedString("_e2ee_setup_extract_publickey_", comment: "")
                )
            }
            preference.setEndToEndCertificate(account: self.session.account, certificate: certificate)

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
        let results = await NextcloudKit.shared.getE2EEPrivateKeyAsync(account: self.session.account, options: options)

        switch results.error.errorCode {
        case .zero:
            guard let privateKeyCipher = results.privateKey else {
                throw NKError(
                    errorCode: global.errorInternalError,
                    errorDescription: NSLocalizedString("_e2ee_setup_get_privatekey_", comment: "")
                )
            }

            let passphrase = try await requestPassphraseAsync()

            guard let privateKeyData = endToEndEncryption?.decryptPrivateKey(privateKeyCipher, passphrase: passphrase),
                  let keyData = Data(base64Encoded: privateKeyData),
                  let privateKey = String(data: keyData, encoding: .utf8),
                  let certificate = preference.getEndToEndCertificate(account: session.account)
            else {
                throw NKError(
                    errorCode: global.errorInternalError,
                    errorDescription: NSLocalizedString("_e2ee_setup_passphrase_error_", comment: "")
                )
            }

            try verifyPrivateKey(privateKey, matches: certificate)

            // Save
            preference.setEndToEndPrivateKey(account: session.account, privateKey: privateKey)
            preference.setEndToEndPassphrase(account: session.account, passphrase: passphrase)

            let serverPublicKeyResult = await NextcloudKit.shared.getE2EEPublicKeyAsync(account: self.session.account, options: options)
            guard serverPublicKeyResult.error == .success,
                  let serverPublicKey = serverPublicKeyResult.publicKey
            else {
                throw serverPublicKeyResult.error == .success
                    ? NKError(
                        errorCode: global.errorInternalError,
                        errorDescription: NSLocalizedString("_e2ee_setup_get_publickey_", comment: "")
                    )
                    : serverPublicKeyResult.error
            }

            try verifyCertificate(usingServerPublicKey: serverPublicKey)

            preference.setEndToEndPublicKey(account: self.session.account, publicKey: serverPublicKey)
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
    /// 2. Verifies that the private key belongs to the user certificate
    /// 3. Uploads the encrypted key (cipher) to the server
    /// 4. Stores the plaintext private key and passphrase locally
    /// 5. Fetches and verifies the server public key
    /// 6. Finalizes E2EE setup (clears metadata tables)
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

        guard let privateKeyCipher = endToEndEncryption?.encryptPrivateKey(
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

        guard let privateKeyString,
              let certificate = preference.getEndToEndCertificate(account: session.account) else {
            throw NKError(
                errorCode: global.errorInternalError,
                errorDescription: NSLocalizedString("_e2ee_setup_store_privatekey_", comment: "")
            )
        }

        let privateKey = String(privateKeyString)
        try verifyPrivateKey(privateKey, matches: certificate)

        // Store cipher on server

        let storeResults = await NextcloudKit.shared.storeE2EEPrivateKeyAsync(
            privateKey: privateKeyCipher,
            account: session.account,
            options: options
        )

        switch storeResults.error.errorCode {
        case .zero:
            // Save locally
            preference.setEndToEndPrivateKey(account: session.account, privateKey: privateKey)
            preference.setEndToEndPassphrase(account: session.account, passphrase: e2ePassphrase)

            // Fetch server public key

            let serverPublicKeyResult = await NextcloudKit.shared.getE2EEPublicKeyAsync(account: session.account, options: options)

            guard serverPublicKeyResult.error == .success,
                  let serverPublicKey = serverPublicKeyResult.publicKey
            else {
                throw serverPublicKeyResult.error == .success
                    ? NKError(
                        errorCode: global.errorInternalError,
                        errorDescription: NSLocalizedString("_e2ee_setup_get_publickey_", comment: "")
                    )
                    : serverPublicKeyResult.error
            }

            // Verify

            try verifyCertificate(usingServerPublicKey: serverPublicKey)

            // Finalize

            preference.setEndToEndPublicKey(account: session.account, publicKey: serverPublicKey)
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
    /// - Parameter serverPublicKey: Public key retrieved from the server-key endpoint
    ///
    /// - Throws:
    ///   - `NKError` if certificate is missing or validation fails
    private func verifyCertificate(usingServerPublicKey serverPublicKey: String) throws {
        guard let certificate = preference.getEndToEndCertificate(account: session.account),
              let endToEndEncryption,
              endToEndEncryption.verifyCertificate(certificate, publicKey: serverPublicKey)
        else {
            throw NKError(
                errorCode: global.errorInternalError,
                errorDescription: NSLocalizedString("_e2ee_setup_verify_publickey_", comment: "")
            )
        }
    }

    /// Verifies that a decrypted private key belongs to the supplied user certificate.
    private func verifyPrivateKey(_ privateKey: String, matches certificate: String) throws {
        let certificateSigningRequest = try networkingE2EE.createCertificateSigningRequest(
            privateKeyPEM: privateKey,
            commonName: session.userId
        )

        guard let endToEndEncryption,
              let privateKeyPublicKey = endToEndEncryption.extractPublicKey(
                  fromCertificateSigningRequest: certificateSigningRequest
              ),
              let certificatePublicKey = endToEndEncryption.extractPublicKey(
                  fromCertificate: certificate
              ),
              networkingE2EE.publicKeysMatch(privateKeyPublicKey, certificatePublicKey) else {
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
    private func requestPassphraseAsync(
        title: String = NSLocalizedString("_e2e_passphrase_request_title_", comment: ""),
        message: String = NSLocalizedString("_e2e_passphrase_request_message_", comment: "")
    ) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let alertController = UIAlertController(
                title: title,
                message: message,
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

    /// Renews the end-to-end encryption certificate while preserving
    /// the existing private and public key pair.
    ///
    /// The function:
    /// - retrieves the existing private key,
    /// - creates a new CSR using that key,
    /// - extracts the public key from the CSR,
    /// - removes the current server-side public key,
    /// - requests a newly signed certificate,
    /// - verifies that the returned certificate contains the expected public key,
    /// - stores the renewed certificate locally,
    /// - returns the renewed certificate to the caller.
    ///
    /// - Returns: The newly signed certificate in PEM format.
    ///
    /// - Throws: An error if the private key is missing, CSR creation fails,
    ///   a server request fails, or the returned certificate does not contain
    ///   the expected public key.
    func renewCertificate(password: String?) async throws -> String {
        let capabilities = await NKCapabilities.shared.getCapabilities(for: session.account)
        options = networkingE2EE.getOptions(account: session.account, capabilities: capabilities)

        guard let privateKeyPEM = preference.getEndToEndPrivateKey(account: session.account) else {
            throw NKError(
                errorCode: global.errorInternalError,
                errorDescription: NSLocalizedString(
                    "_e2ee_setup_privatekey_missing_",
                    comment: ""
                )
            )
        }

        let csr = try networkingE2EE.createCertificateSigningRequest(privateKeyPEM: privateKeyPEM, commonName: session.userId)
        guard let csrPublicKey = endToEndEncryption?.extractPublicKey(fromCertificateSigningRequest: csr) else {
            throw NKError(
                errorCode: global.errorInternalError,
                errorDescription: NSLocalizedString(
                    "_e2ee_setup_extract_publickey_",
                    comment: ""
                )
            )
        }

        let deleteError = await NextcloudKit.shared.deleteE2EEPublicKeyAsync(account: session.account, password: password, options: options).error
        guard deleteError == .success else {
            throw deleteError
        }

        let signResult = await NextcloudKit.shared.signE2EECertificateAsync(certificate: csr,
                                                                            account: session.account,
                                                                            options: options)
        guard signResult.error == .success,
              let certificate = signResult.certificate else {
            throw signResult.error == .success
                ? NKError(
                    errorCode: global.errorInternalError,
                    errorDescription: NSLocalizedString(
                        "_e2ee_setup_sign_certificate_",
                        comment: ""
                    )
                )
                : signResult.error
        }

        let extractedPublicKey = endToEndEncryption?.extractPublicKey(fromCertificate: certificate)
        guard extractedPublicKey == csrPublicKey else {
            throw NKError(
                errorCode: global.errorInternalError,
                errorDescription: NSLocalizedString(
                    "_e2ee_setup_extract_publickey_",
                    comment: ""
                )
            )
        }

        // Certificate renewal replaces part of the active key set, so preserve
        // the previous version before updating it.
        try preference.archiveCurrentEndToEndKeySet(account: session.account)
        preference.setEndToEndCertificate(account: session.account, certificate: certificate)

        return certificate
    }
}
