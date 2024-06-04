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
    /// AppDelegate
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    /// Keychain access
    var keychain = NCKeychain()
    /// Root View Controller
    @Published var controller: NCMainTabBarController?
    /// State variable for enabling the automatic appreance
    @Published var appearanceAutomatic: Bool = false

    /// Initializes the view model with default values.
    init(controller: NCMainTabBarController?) {
        self.controller = controller
        onViewAppear()
    }

    /// Triggered when the view appears.
    func onViewAppear() {
        appearanceAutomatic = keychain.appearanceAutomatic
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
