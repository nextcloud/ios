//
//  NCSettingsViewModel.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 05/03/24.
//  Created by Marino Faggiana on 30/05/24.
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
import SwiftUI
import LocalAuthentication

class NCSettingsModel: ObservableObject, ViewOnAppearHandling {
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
    /// Request account on start
    @Published var accountRequest: Bool = false
    /// Root View Controller
    @Published var controller: NCMainTabBarController?
    /// Footer
    var footerApp = ""
    var footerServer = ""
    var footerSlogan = ""
    /// Get session
    var session: NCSession.Session {
        NCSession.shared.getSession(controller: controller)
    }

    var changePasscode = false

    /// Initializes the view model with default values.
    init(controller: NCMainTabBarController?) {
        self.controller = controller
        onViewAppear()
    }

    /// Triggered when the view appears.
    func onViewAppear() {
        let capabilities = NCCapabilities.shared.getCapabilities(account: self.controller?.account)
        isLockActive = (keychain.passcode != nil)
        enableTouchID = keychain.touchFaceID
        lockScreen = !keychain.requestPasscodeAtStart
        privacyScreen = keychain.privacyScreenEnabled
        resetWrongAttempts = keychain.resetAppCounterFail
        accountRequest = keychain.accountRequest
        footerApp = String(format: NCBrandOptions.shared.textCopyrightNextcloudiOS, NCUtility().getVersionApp(withBuild: true)) + "\n\n"
        footerServer = String(format: NCBrandOptions.shared.textCopyrightNextcloudServer, capabilities.capabilityServerVersion) + "\n"
        footerSlogan = capabilities.capabilityThemingName + " - " + capabilities.capabilityThemingSlogan + "\n\n"
    }

    // MARK: - All functions

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
        let session = NCSession.shared.getSession(controller: controller)
        let configLink = session.urlBase + NCBrandOptions.shared.mobileconfig
        let configServer = NCConfigServer()
        if let url = URL(string: configLink) {
            configServer.startService(url: url, account: session.account)
        }
    }

    /// Function to update Account request on start
    func updateAccountRequest() {
        keychain.accountRequest = accountRequest
    }
}
