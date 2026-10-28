// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import SwiftUI
import NextcloudKit

@MainActor
class NCManageE2EE: NSObject, ObservableObject, ViewOnAppearHandling {

    let preference = NCPreferences()
    let networkingE2EE = NCNetworkingE2EE()
    let global = NCGlobal()

    @Published var controller: NCMainTabBarController?
    @Published var isEndToEndEnabled: Bool = false
    @Published var statusOfService: String = NSLocalizedString("_status_in_progress_", comment: "")
    @Published var navigateBack: Bool = false
    @Published var certificateValidity: NCNetworkingE2EE.X509CertificateValidity?

    var session: NCSession.Session {
        NCSession.shared.getSession(controller: controller)
    }

    var capabilities: NKCapabilities.Capabilities {
        NCNetworking.shared.capabilities[session.account] ?? NKCapabilities.Capabilities()
    }

    var windowScene: UIWindowScene? {
        SceneManager.shared.getWindowScene(controller: controller)
    }

    init(controller: NCMainTabBarController?) {
        super.init()
        self.controller = controller
        onViewAppear()
    }

    /// Triggered when the view appears.
    func onViewAppear() {
        if capabilities.e2EEEnabled {
            isEndToEndEnabled = preference.isEndToEndEnabled(account: session.account)
            if isEndToEndEnabled {
                if let certificate = preference.getEndToEndCertificate(account: session.account) {
                    self.certificateValidity = networkingE2EE.getX509CertificateValidity(from: certificate)
                }
                if preference.isEndToEndServerKeyStale(account: session.account) {
                    statusOfService = NSLocalizedString("_e2ee_server_key_changed_", comment: "")
                } else {
                    statusOfService = NSLocalizedString("_status_e2ee_configured_", comment: "")
                }
            } else {
                let options = networkingE2EE.getOptions(account: session.account, capabilities: capabilities)
                NextcloudKit.shared.getE2EECertificate(account: session.account, options: options) { _ in
                } completion: { _, _, _, _, error in
                    if error == .success {
                        self.statusOfService = NSLocalizedString("_status_e2ee_on_server_", comment: "")
                    } else {
                        self.statusOfService = NSLocalizedString("_status_e2ee_not_setup_", comment: "")
                    }
                }
            }
        } else {
            navigateBack = true
        }
    }

    @MainActor
    func renewCertificate(password: String?) async {
        do {
            let e2ee = NCEndToEndSetup(controller: controller)
            let certificate = try await e2ee.renewCertificate(password: password)
            self.certificateValidity = networkingE2EE.getX509CertificateValidity(from: certificate)
            await showInfoBanner(windowScene: windowScene,
                                 text: "_e2e_renew_certificate_success_")
        } catch let error as NKError {
            if error.errorCode == NSUserCancelledError {
                return
            }
            await showErrorBanner(
                windowScene: windowScene,
                error: error
            )
        } catch {
            await showErrorBanner(
                windowScene: windowScene,
                error: NKError(error: error)
            )
        }
    }

    // MARK: - Delegate

    func endToEndInitializeSuccess(metadata: tableMetadata?) {
        isEndToEndEnabled = true
    }

    // MARK: - Passcode

    /// Authenticate before performing the selected E2EE action, including in Debug builds.
    @objc func requestPasscodeType(_ passcodeType: String) {
        guard let presenter = controller?.topMostViewController() else { return }
        let account = session.account
        NCPasscodeView.present(from: presenter, allowCancel: true) { [weak self] result in
            guard let self else { return }
            switch result {
            case .authenticated:
                guard self.session.account == account,
                      NCManageDatabase.shared.getTableAccount(account: account) != nil else { return }
                self.performAuthenticatedAction(passcodeType)
            case .reset:
                (UIApplication.shared.delegate as? AppDelegate)?.resetApplication()
            case .cancelled, .configured, .disabled:
                break
            }
        }
    }

    private func performAuthenticatedAction(_ passcodeType: String) {
        switch passcodeType {
        case "startE2E":
            Task {
                do {
                    let e2ee = NCEndToEndSetup(controller: controller)
                    try await e2ee.start()
                    isEndToEndEnabled = true
                } catch let error as NKError {
                    if error.errorCode == NSUserCancelledError {
                        return
                    }
                    await showErrorBanner(
                        windowScene: windowScene,
                        error: error
                    )
                } catch {
                    await showErrorBanner(
                        windowScene: windowScene,
                        error: NKError(error: error)
                    )
                }
            }
        case "readPassphrase":
            if let e2ePassphrase = NCPreferences().getEndToEndPassphrase(account: session.account) {
                let message = "\n" + NSLocalizedString("_e2e_settings_the_passphrase_is_", comment: "") + "\n\n\n" + e2ePassphrase
                let alertController = UIAlertController(title: NSLocalizedString("_info_", comment: ""), message: message, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_copy_passphrase_", comment: ""), style: .default, handler: { _ in
                    UIPasteboard.general.string = e2ePassphrase
                }))
                controller?.topMostViewController().present(alertController, animated: true)
            }
        case "removeLocallyEncryption":
            let alertController = UIAlertController(title: NSLocalizedString("_e2e_settings_remove_", comment: ""), message: NSLocalizedString("_e2e_settings_remove_message_", comment: ""), preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_remove_", comment: ""), style: .default, handler: { _ in
                NCPreferences().clearAllKeysEndToEnd(account: self.session.account)
                self.isEndToEndEnabled = NCPreferences().isEndToEndEnabled(account: self.session.account)
            }))
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .default, handler: { _ in }))
            controller?.topMostViewController().present(alertController, animated: true)
        default:
            break
        }
    }
}
