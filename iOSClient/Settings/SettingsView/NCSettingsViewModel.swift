//
//  NCSettingsViewModel.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 05/03/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation

protocol NCSettingsViewModelProtocol: ObservableObject, AccountUpdateHandling, ViewOnAppearHandling {
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

class NCSettingsViewModel: NCSettingsViewModelProtocol {
    
    /// Keychain access
    var keychain = NCKeychain()
    
    @Published var enableTouchID: Bool = false
    @Published var lockScreen: Bool = false
    @Published var privacyScreen: Bool = false
    @Published var resetWrongAttempts: Bool = false
    @Published var configLink: String? = "https://shared02.opsone-cloud.ch/\(String(describing: NCManageDatabase.shared.getActiveAccount()?.urlBase))\(NCBrandOptions.shared.mobileconfig)"
    
    @Published var isE2EEEnable: Bool = NCGlobal.shared.capabilityE2EEEnabled
    @Published var versionE2EE: String = NCGlobal.shared.capabilityE2EEApiVersion
    
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
        enableTouchID = keychain.touchFaceID
        lockScreen = keychain.requestPasscodeAtStart
        privacyScreen = keychain.privacyScreenEnabled
        resetWrongAttempts = keychain.resetAppCounterFail
        copyrightYear = getCurrentYear()
    }
    
    // MARK: - Settings Update Methods
    
    /// Function to update Touch ID / Face ID setting
    func updateTouchIDSetting() {
        keychain.touchFaceID = enableTouchID
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
