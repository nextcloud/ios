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
    @Published var controller: UITabBarController?
    /// State variable for enabling the automatic appreance
    @Published var appearanceAutomatic: Bool = false

    /// Initializes the view model with default values.
    init(controller: UITabBarController?) {
        self.controller = controller
        onViewAppear()
    }

    /// Triggered when the view appears.
    func onViewAppear() {
        appearanceAutomatic = keychain.appearanceAutomatic
    }

    // MARK: - All functions

    /// Updates the value of `appearanceAutomatic` in the keychain.
    func updateAppearanceAutomatic() {
        keychain.appearanceAutomatic = appearanceAutomatic
    }
}
