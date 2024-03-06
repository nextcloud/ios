//
//  NCSettingsViewModel.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 05/03/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation

class NCSettingsViewModel: ObservableObject {
    let keychain = NCKeychain()
    
    /// State to control the enable TouchID toggle
    @Published var enableTouchID: Bool
    /// State to control
    @Published var lockScreen: Bool
    /// State to control
    @Published var privacyScreen: Bool
    /// State to control
    @Published var resetWrongAttempts: Bool
    /// String url to download configuration files
    @Published var configLink: String? = "https://shared02.opsone-cloud.ch/\(String(describing: NCManageDatabase.shared.getActiveAccount()?.urlBase))\(NCBrandOptions.shared.mobileconfig)"
    /// State to control the visibility of the acknowledgements view
    @Published var isE2EEEnable: Bool = NCGlobal.shared.capabilityE2EEEnabled
    /// String containing the current version of E2EE
    @Published var versionE2EE: String = NCGlobal.shared.capabilityE2EEApiVersion
        
    init() {
        enableTouchID = keychain.touchFaceID
        lockScreen = keychain.requestPasscodeAtStart
        privacyScreen = keychain.privacyScreenEnabled
        resetWrongAttempts = keychain.resetAppCounterFail
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
    
    func getConfigFiles(){
        let configServer = NCConfigServer()
        configServer.startService(url: URL(string: configLink)!)
    }
}
