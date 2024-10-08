//
//  NCDisplayModel.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 30/05/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import SwiftUI

class NCDisplayModel: ObservableObject, ViewOnAppearHandling {
    /// Keychain access
    var keychain = NCKeychain()
    /// Root View Controller
    @Published var controller: NCMainTabBarController?
    /// State variable for enabling the automatic appreance
    @Published var appearanceAutomatic: Bool = false

    /// State variable for keeping the screen on or off during file transfering 
    @Published var screenAwakeState = AwakeMode.off {
        didSet {
            keychain.screenAwakeMode = screenAwakeState
        }
    }

    /// Get session
    var session: NCSession.Session {
        NCSession.shared.getSession(controller: controller)
    }

    /// Initializes the view model with default values.
    init(controller: NCMainTabBarController?) {
        self.controller = controller
        onViewAppear()
    }

    /// Triggered when the view appears.
    func onViewAppear() {
        appearanceAutomatic = keychain.appearanceAutomatic
        screenAwakeState = keychain.screenAwakeMode
    }

    // MARK: - All functions

    /// Update window(s)  style
    func userInterfaceStyle(_ style: UIUserInterfaceStyle) {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        keychain.appearanceInterfaceStyle = style
        for windowScene in windowScenes {
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }

    /// Updates the value of `appearanceAutomatic` in the keychain.
    func updateAppearanceAutomatic() {
        keychain.appearanceAutomatic = appearanceAutomatic
        if appearanceAutomatic {
            userInterfaceStyle(.unspecified)
        }
    }
}
