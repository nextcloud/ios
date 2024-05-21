//
//  NCSettingsViewModel.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 05/03/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  Author Aditya Tyagi <adityagi02@yahoo.com>
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

import Foundation
import UIKit
import Combine
import SwiftUI
import TOPasscodeViewController
import LocalAuthentication

class NCSettingsModel: ObservableObject, AccountUpdateHandling, ViewOnAppearHandling {
    /// Keychain access
    var keychain = NCKeychain()
    /// State to control the lock on/off section
    @Published var isLockActive: Bool = false
    /// State to control the enable TouchID toggle
    @Published var enableTouchID: Bool = false
    /// State to control
    @Published var lockScreen: Bool = false
    /// State to control
    @Published var privacyScreen: Bool = false
    /// State to control
    @Published var resetWrongAttempts: Bool = false
    /// String url to download configuration files
    @Published var configLink: String? = "https://shared02.opsone-cloud.ch/\(String(describing: NCManageDatabase.shared.getActiveAccount()?.urlBase))\(NCBrandOptions.shared.mobileconfig)"
    /// State to control the visibility of the acknowledgements view
    var isE2EEEnable: Bool = NCGlobal.shared.capabilityE2EEEnabled
    /// String containing the current version of E2EE
    @Published var versionE2EE: String = NCGlobal.shared.capabilityE2EEApiVersion

    // MARK: - String Values for View
    var appVersion: String = NCUtility().getVersionApp(withBuild: true)
    /// String representing the current year to be shown
    @Published var copyrightYear: String = ""
    var serverVersion: String = NCGlobal.shared.capabilityServerVersion
    var themingName: String = NCGlobal.shared.capabilityThemingName
    var themingSlogan: String = NCGlobal.shared.capabilityThemingSlogan
    /// Initializes the view model with default values.
    init() {
        onViewAppear()
    }
    /// Updates the account information.
    func updateAccount() {
        self.keychain = NCKeychain()
    }
    /// Triggered when the view appears.
    func onViewAppear() {
        isLockActive = (keychain.passcode != nil)
        enableTouchID = keychain.touchFaceID
        lockScreen = !keychain.requestPasscodeAtStart
        privacyScreen = keychain.privacyScreenEnabled
        resetWrongAttempts = keychain.resetAppCounterFail
        copyrightYear = getCurrentYear()
    }
    // MARK: - Settings Update Methods
    /// Function to update Touch ID / Face ID setting
    func updateTouchIDSetting() {
        keychain.touchFaceID = enableTouchID
    }
    /// Function to update Lock Screen setting
    func updateLockScreenSetting() {
        keychain.requestPasscodeAtStart = !lockScreen
    }
    /// Function to update Privacy Screen setting
    func updatePrivacyScreenSetting() {
        keychain.privacyScreenEnabled = privacyScreen
    }
    /// Function to update Reset Wrong Attempts setting
    func updateResetWrongAttemptsSetting() {
        keychain.resetAppCounterFail = resetWrongAttempts
    }
    /// This function initiates a service call to download the configuration files
    /// using the URL provided in the `configLink` property.
    func getConfigFiles() {
        let configServer = NCConfigServer()
        configServer.startService(url: URL(string: configLink)!)
    }
    /// This function gets the current year as a string.
    /// and returns it as a string value.
    func getCurrentYear() -> String {
        return String(Calendar.current.component(.year, from: Date()))
    }
}

struct PasscodeView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        let laContext = LAContext()
        var error: NSError?
        if NCKeychain().passcode != nil {
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
        var parent: PasscodeView
        init(_ parent: PasscodeView) {
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
                                passcodeViewController.dismiss(animated: true) {
                                    self.parent.isPresented = false
                                }
                            }
                        }
                    }
                }
            }
        }

        func passcodeSettingsViewController(_ passcodeSettingsViewController: TOPasscodeSettingsViewController, didChangeToNewPasscode passcode: String, of type: TOPasscodeType) {
            NCKeychain().passcode = passcode
            passcodeSettingsViewController.dismiss(animated: true) {
                self.parent.isPresented = false
            }
        }

        func didTapCancel(in passcodeViewController: TOPasscodeViewController) {
            passcodeViewController.dismiss(animated: true) {
                self.parent.isPresented = false
            }
        }

        func passcodeViewController(_ passcodeViewController: TOPasscodeViewController, isCorrectCode code: String) -> Bool {
            if code == NCKeychain().passcode {
                NCKeychain().passcode = nil
                return true
            }
            return false
        }
    }
}
