// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Aditya Tyagi
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import SwiftUI
import LocalAuthentication
import NextcloudKit

class NCSettingsModel: ObservableObject, ViewOnAppearHandling {
    // Keychain access
    var keychain = NCPreferences()
    // State to control the lock on/off section
    @Published var isLockActive: Bool = false
    // State to control the enable TouchID toggle
    @Published var enableTouchID: Bool = false
    // State to control
    @Published var lockScreen: Bool = false
    // State to control
    @Published var privacyScreen: Bool = false
    // State to control
    @Published var resetWrongAttempts: Bool = false
    // Request account on start
    @Published var accountRequest: Bool = false
    // Root View Controller
    @Published var controller: NCMainTabBarController?
    // Footer
    var footerApp = ""
    var footerServer = ""
    var footerSlogan = ""
    // Get session
    @MainActor
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
        let capabilities = NCNetworking.shared.capabilities[self.controller?.account ?? ""] ?? NKCapabilities.Capabilities()
        isLockActive = (keychain.passcode != nil)
        enableTouchID = keychain.touchFaceID
        lockScreen = !keychain.requestPasscodeAtStart
        privacyScreen = keychain.privacyScreenEnabled
        resetWrongAttempts = keychain.resetAppCounterFail
        accountRequest = keychain.accountRequest
        footerApp = String(format: NCBrandOptions.shared.textCopyrightNextcloudiOS, NCUtility().getVersionBuild()) + "\n\n"
        footerServer = String(format: NCBrandOptions.shared.textCopyrightNextcloudServer, capabilities.serverVersion) + "\n"
        footerSlogan = capabilities.themingName + " - " + capabilities.themingSlogan + "\n\n"
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
