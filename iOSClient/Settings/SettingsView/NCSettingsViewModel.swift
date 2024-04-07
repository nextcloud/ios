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

protocol NCSettingsVMRepresentable: ObservableObject, AccountUpdateHandling, ViewOnAppearHandling, NCSelectDelegate {
    
    var isLockActive: Bool { get set }
    /// State to control the enable TouchID toggle
    var enableTouchID: Bool { get set }
    /// State to control
    var lockScreen: Bool { get set }
    /// State to control
    var privacyScreen: Bool { get set }
    /// State to control
    var resetWrongAttempts: Bool { get set }
    /// String url to download configuration files
    var configLink: String? { get }
    
    /// State to control the visibility of the acknowledgements view
    var isE2EEEnable: Bool { get }
    /// String containing the current version of E2EE
    var versionE2EE: String { get }
    
    /// String representing the current year to be shown
    var copyrightYear: String { get }
    
    func updateAccount()
    func updateTouchIDSetting()
    func updatePrivacyScreenSetting()
    func updateResetWrongAttemptsSetting()
    func getConfigFiles()
}

class NCSettingsViewModel: NCSettingsVMRepresentable {
    
    /// Keychain access
    var keychain = NCKeychain()
        
    @Published var serverUrl: String = ""

    @Published var isLockActive: Bool = false
    @Published var enableTouchID: Bool = false
    @Published var lockScreen: Bool = false
    @Published var privacyScreen: Bool = false
    @Published var resetWrongAttempts: Bool = false
    @Published var configLink: String? = "https://shared02.opsone-cloud.ch/\(String(describing: NCManageDatabase.shared.getActiveAccount()?.urlBase))\(NCBrandOptions.shared.mobileconfig)"
    
    @Published var isE2EEEnable: Bool = NCGlobal.shared.capabilityE2EEEnabled
    @Published var versionE2EE: String = NCGlobal.shared.capabilityE2EEApiVersion
    @Published var passcode: String = ""

    // MARK: - String Values for View
    var appVersion: String = NCUtility().getVersionApp(withBuild: true)
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
        passcode = keychain.passcode ?? ""
        serverUrl = AppDelegate().activeServerUrl
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
    
    // MARK: NCSelectDelegate
    
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], indexPath: [IndexPath], overwrite: Bool, copy: Bool, move: Bool) {

        if let serverUrl = serverUrl {
            self.serverUrl = serverUrl
        }
    }
}

struct PasscodeView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @Binding var passcode: String
    
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
            return passcodeViewController
        } else {
            let passcodeSettingsViewController = TOPasscodeSettingsViewController()
            passcodeSettingsViewController.hideOptionsButton = true
            passcodeSettingsViewController.requireCurrentPasscode = false
            passcodeSettingsViewController.passcodeType = .sixDigits
            return passcodeSettingsViewController
        }
    }
    
    func makeUIViewController(context: Context) -> TOPasscodeViewController {
        let passcodeViewController = TOPasscodeViewController(passcodeType: .sixDigits, allowCancel: false)
        passcodeViewController.delegate = context.coordinator
        return passcodeViewController
    }
    
    func updateUIViewController(_ uiViewController: TOPasscodeViewController, context: Context) {
        // Update the view controller if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, TOPasscodeViewControllerDelegate {
        var parent: PasscodeView
        
        init(_ parent: PasscodeView) {
            self.parent = parent
        }
        
        func passcodeViewController(_ passcodeViewController: TOPasscodeViewController, isCorrectCode code: String) -> Bool {
            if code == NCKeychain().passcode {
                NCKeychain().passcode = nil
                parent.passcode = code
                return true
            }
            return false
        }
        
        func didPerformBiometricValidationRequest(in passcodeViewController: TOPasscodeViewController) {
            let context = LAContext()
            var error: NSError?
            
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: NCBrandOptions.shared.brand) { success, error in
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
    }
}
