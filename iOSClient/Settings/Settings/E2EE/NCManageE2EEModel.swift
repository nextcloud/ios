//
//  NCManageE2EEModel.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 30/05/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import UIKit
import SwiftUI
import NextcloudKit
import TOPasscodeViewController
import LocalAuthentication

class NCManageE2EE: NSObject, ObservableObject, ViewOnAppearHandling, NCEndToEndInitializeDelegate, TOPasscodeViewControllerDelegate {
    let endToEndInitialize = NCEndToEndInitialize()
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    var passcodeType = ""

    @Published var controller: UITabBarController?
    @Published var isEndToEndEnabled: Bool = false
    @Published var statusOfService: String = NSLocalizedString("_status_in_progress_", comment: "")

    init(controller: UITabBarController?) {
        super.init()
        self.controller = controller
        endToEndInitialize.delegate = self
        onViewAppear()
    }

    /// Triggered when the view appears.
    func onViewAppear() {
        isEndToEndEnabled = NCKeychain().isEndToEndEnabled(account: appDelegate.account)
        if isEndToEndEnabled {
            statusOfService = NSLocalizedString("_status_e2ee_configured_", comment: "")
        } else {
            endToEndInitialize.statusOfService { error in
                if error == .success {
                    self.statusOfService = NSLocalizedString("_status_e2ee_on_server_", comment: "")
                } else {
                    self.statusOfService = NSLocalizedString("_status_e2ee_not_setup_", comment: "")
                }
            }
        }
    }

    // MARK: - Delegate

    func endToEndInitializeSuccess(metadata: tableMetadata?) {
        isEndToEndEnabled = true
    }

    // MARK: - Passcode

    @objc func requestPasscodeType(_ passcodeType: String) {
        let laContext = LAContext()
        var error: NSError?

        let passcodeViewController = TOPasscodeViewController(passcodeType: .sixDigits, allowCancel: true)
        passcodeViewController.delegate = self
        passcodeViewController.keypadButtonShowLettering = false
        if NCKeychain().touchFaceID, laContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            if error == nil {
                if laContext.biometryType == .faceID {
                    passcodeViewController.biometryType = .faceID
                    passcodeViewController.allowBiometricValidation = true
                } else if laContext.biometryType == .touchID {
                    passcodeViewController.biometryType = .touchID
                }
                passcodeViewController.allowBiometricValidation = true
                passcodeViewController.automaticallyPromptForBiometricValidation = true
            }
        }

        self.passcodeType = passcodeType
        controller?.present(passcodeViewController, animated: true)
    }

    @objc func correctPasscode() {
        switch self.passcodeType {
        case "startE2E":
            endToEndInitialize.initEndToEndEncryption(viewController: controller, metadata: nil)
        case "readPassphrase":
            if let e2ePassphrase = NCKeychain().getEndToEndPassphrase(account: appDelegate.account) {
                print("[INFO]Passphrase: " + e2ePassphrase)
                let message = "\n" + NSLocalizedString("_e2e_settings_the_passphrase_is_", comment: "") + "\n\n\n" + e2ePassphrase
                let alertController = UIAlertController(title: NSLocalizedString("_info_", comment: ""), message: message, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_copy_passphrase_", comment: ""), style: .default, handler: { _ in
                    UIPasteboard.general.string = e2ePassphrase
                }))
                controller?.present(alertController, animated: true)
            }
        case "removeLocallyEncryption":
            let alertController = UIAlertController(title: NSLocalizedString("_e2e_settings_remove_", comment: ""), message: NSLocalizedString("_e2e_settings_remove_message_", comment: ""), preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_remove_", comment: ""), style: .default, handler: { _ in
                NCKeychain().clearAllKeysEndToEnd(account: self.appDelegate.account)
                self.isEndToEndEnabled = NCKeychain().isEndToEndEnabled(account: self.appDelegate.account)
            }))
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .default, handler: { _ in }))
            controller?.present(alertController, animated: true)
        default:
            break
        }
    }

    func passcodeViewController(_ passcodeViewController: TOPasscodeViewController, isCorrectCode code: String) -> Bool {
        if code == NCKeychain().passcode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.correctPasscode()
            }
            return true
        } else {
            return false
        }
    }

    func didPerformBiometricValidationRequest(in passcodeViewController: TOPasscodeViewController) {
        LAContext().evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: NCBrandOptions.shared.brand) { success, _ in
            if success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    passcodeViewController.dismiss(animated: true)
                    self.correctPasscode()
                }
            }
        }
    }

    func didTapCancel(in passcodeViewController: TOPasscodeViewController) {
        passcodeViewController.dismiss(animated: true)
    }
}
