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
    @Published var enableTouchFaceID: Bool = false
    // State to control
    @Published var lockScreen: Bool = false
    // State to control
    @Published var privacyScreen: Bool = false
    // State to control
    @Published var resetWrongAttempts: Bool = false
    // State to control the auto upload status indicator
    @Published var autoUploadStart: Bool = false
    // State to control the auto upload queue count
    @Published var autoUploadCount: Int = 0
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
        enableTouchFaceID = keychain.touchFaceID
        lockScreen = !keychain.requestPasscodeAtStart
        privacyScreen = keychain.privacyScreenEnabled
        resetWrongAttempts = keychain.resetAppCounterFail
        autoUploadStart = NCManageDatabase.shared.getTableAccount(account: session.account)?.autoUploadStart ?? false
        if !autoUploadStart {
            autoUploadCount = 0
        }
        accountRequest = keychain.accountRequest
        footerApp = String(format: NCBrandOptions.shared.textCopyrightNextcloudiOS, NCUtility().getVersionBuild()) + "\n\n"
        footerServer = String(format: NCBrandOptions.shared.textCopyrightNextcloudServer, capabilities.serverVersion) + "\n"
        footerSlogan = capabilities.themingName + " - " + capabilities.themingSlogan + "\n\n"
    }

    var autoUploadCountMessage: String {
        return String.localizedStringWithFormat(NSLocalizedString("_focused_auto_upload_items_left_", comment: ""), autoUploadCount)
    }

    // MARK: - All functions

    @MainActor
    func pollAutoUploadCount() async {
        guard autoUploadStart else {
            autoUploadCount = 0
            return
        }

        let account = session.account
        let urlBase = session.urlBase
        let userId = session.userId
        let autoUploadServerUrlBase = await NCManageDatabase.shared.getAccountAutoUploadServerUrlBaseAsync(account: account,
                                                                                                           urlBase: urlBase,
                                                                                                           userId: userId)

        while autoUploadStart && !Task.isCancelled {
            let transfersSuccess = await NCNetworking.shared.metadataTranfersSuccess.getAll()
            autoUploadCount = await NCManageDatabase.shared.countAutoUploadMetadatasAsync(account: account,
                                                                                          autoUploadServerUrlBase: autoUploadServerUrlBase,
                                                                                          transfersSuccess: transfersSuccess)
            try? await Task.sleep(for: .seconds(2))
        }
    }

    /// Function to update Touch ID / Face ID setting
    func updateTouchIDSetting() {
        keychain.touchFaceID = enableTouchFaceID
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
        let configServer = NCConfigServer(controller: self.controller)
        if let url = URL(string: configLink) {
            configServer.startService(url: url, account: session.account)
        }
    }

    /// Function to update Account request on start
    func updateAccountRequest() {
        keychain.accountRequest = accountRequest
    }
}
