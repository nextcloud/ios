//
//  SetupPasscodeView.swift
//  Nextcloud
//
//  Created by Milen Pivchev on 28.11.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI
import LocalAuthentication

struct SetupPasscodeView: UIViewControllerRepresentable {
    @Binding var isLockActive: Bool
    var changePasscode = false

    func makeUIViewController(context: Context) -> UIViewController {
        let laContext = LAContext()
        var error: NSError?
        if NCKeychain().passcode != nil, !changePasscode {
            let passcodeViewController = TOPasscodeViewController(passcodeType: .sixDigits, allowCancel: true)
            passcodeViewController.keypadButtonShowLettering = false
            if NCKeychain().touchFaceID && laContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                if error == nil {
                    if laContext.biometryType == .faceID {
                        passcodeViewController.biometryType = .faceID
                        passcodeViewController.allowBiometricValidation = true
                        passcodeViewController.automaticallyPromptForBiometricValidation = true
                    } else if laContext.biometryType == .touchID {
                        passcodeViewController.biometryType = .touchID
                        passcodeViewController.allowBiometricValidation = true
                        passcodeViewController.automaticallyPromptForBiometricValidation = true
                    } else {
                        print("No Biometric support")
                    }
                }
            }
            passcodeViewController.delegate = context.coordinator
            return passcodeViewController
        } else if changePasscode {
            let passcodeSettingsViewController = TOPasscodeSettingsViewController()
            passcodeSettingsViewController.hideOptionsButton = true
            passcodeSettingsViewController.requireCurrentPasscode = true
            passcodeSettingsViewController.passcodeType = .sixDigits
            passcodeSettingsViewController.delegate = context.coordinator
            return passcodeSettingsViewController
        } else {
            let passcodeSettingsViewController = TOPasscodeSettingsViewController()
            passcodeSettingsViewController.hideOptionsButton = true
            passcodeSettingsViewController.requireCurrentPasscode = false
            passcodeSettingsViewController.passcodeType = .sixDigits
            passcodeSettingsViewController.delegate = context.coordinator
            return passcodeSettingsViewController
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
                                NCKeychain().passcode = nil
                                passcodeViewController.dismiss(animated: true)
                            }
                        }
                    }
                }
            }
        }

        func passcodeSettingsViewController(_ passcodeSettingsViewController: TOPasscodeSettingsViewController, didChangeToNewPasscode passcode: String, of type: TOPasscodeType) {
            NCKeychain().passcode = passcode
            self.parent.isLockActive = true
            passcodeSettingsViewController.dismiss(animated: true)
        }

        func didTapCancel(in passcodeViewController: TOPasscodeViewController) {
            passcodeViewController.dismiss(animated: true)
        }

        func passcodeViewController(_ passcodeViewController: TOPasscodeViewController, isCorrectCode code: String) -> Bool {
            if code == NCKeychain().passcode {
                self.parent.isLockActive = false
                NCKeychain().passcode = nil
                return true
            }
            return false
        }

        func passcodeSettingsViewController(_ passcodeSettingsViewController: TOPasscodeSettingsViewController, didAttemptCurrentPasscode passcode: String) -> Bool {
            // verify here if the code is correct
            return true
        }
    }
}
