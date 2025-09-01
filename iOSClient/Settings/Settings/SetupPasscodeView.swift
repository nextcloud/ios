// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Milen Pivchev
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import SwiftUI
import LocalAuthentication
import PopupView

struct SetupPasscodeView: UIViewControllerRepresentable {
    @Binding var isLockActive: Bool
    var changePasscode: Bool = false
    let maxFailedAttempts = 2 // + 1 = 3... The lib failed attempt counter starts at 0. Why? Who knows.

    func makeUIViewController(context: Context) -> UIViewController {
        let laContext = LAContext()
        var error: NSError?
        if !NCPreferences().passcode.isEmptyOrNil, !changePasscode {
            let passcodeVC = TOPasscodeViewController(passcodeType: .sixDigits, allowCancel: true)
            passcodeVC.keypadButtonShowLettering = false

            if NCPreferences().touchFaceID, laContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error), error == nil {
                switch laContext.biometryType {
                case .faceID:
                    passcodeVC.biometryType = .faceID
                case .touchID:
                    passcodeVC.biometryType = .touchID
                default:
                    print("No Biometric support")
                }
                passcodeVC.allowBiometricValidation = true
                passcodeVC.automaticallyPromptForBiometricValidation = true
            }

            passcodeVC.delegate = context.coordinator
            return passcodeVC
        } else {
            let passcodeSettingsVC = TOPasscodeSettingsViewController()
            passcodeSettingsVC.hideOptionsButton = true
            passcodeSettingsVC.requireCurrentPasscode = changePasscode
            passcodeSettingsVC.passcodeType = .sixDigits
            passcodeSettingsVC.delegate = context.coordinator
            return passcodeSettingsVC
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Update the view controller if needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, TOPasscodeSettingsViewControllerDelegate, TOPasscodeViewControllerDelegate {
        var parent: SetupPasscodeView
        init(_ parent: SetupPasscodeView) {
            self.parent = parent
        }

        func didPerformBiometricValidationRequest(in passcodeViewController: TOPasscodeViewController) {
            let context = LAContext()
            var error: NSError?

            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: NCBrandOptions.shared.brand) { success, _ in
                    DispatchQueue.main.async {
                        if success {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                NCPreferences().passcode = nil
                                passcodeViewController.dismiss(animated: true)
                            }
                        }
                    }
                }
            }
        }

        func passcodeSettingsViewController(_ passcodeSettingsViewController: TOPasscodeSettingsViewController, didAttemptCurrentPasscode passcode: String) -> Bool {
            if passcode == NCPreferences().passcode {
                return true
            } else if passcodeSettingsViewController.failedPasscodeAttemptCount == parent.maxFailedAttempts {
                passcodeSettingsViewController.dismiss(animated: true)
                NCContentPresenter().showCustomMessage(message: NSLocalizedString("_too_many_failed_passcode_attempts_error_", comment: ""), type: .error)
            }

            return false
        }

        func passcodeSettingsViewController(_ passcodeSettingsViewController: TOPasscodeSettingsViewController, didChangeToNewPasscode passcode: String, of type: TOPasscodeType) {
            NCPreferences().passcode = passcode
            parent.isLockActive = true
            passcodeSettingsViewController.dismiss(animated: true)
        }

        func didTapCancel(in passcodeViewController: TOPasscodeViewController) {
            passcodeViewController.dismiss(animated: true)
        }

        func passcodeViewController(_ passcodeViewController: TOPasscodeViewController, isCorrectCode passcode: String) -> Bool {
            if passcode == NCPreferences().passcode {
                parent.isLockActive = false
                NCPreferences().passcode = nil
                return true
            }

            return false
        }
    }
}
