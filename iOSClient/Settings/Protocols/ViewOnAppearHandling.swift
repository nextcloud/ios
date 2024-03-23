//
//  ViewOnAppearHandling.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 17/03/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation

/// A protocol defining methods to handle view appearance events.
protocol ViewOnAppearHandling {
    /// Triggered when the view appears.
    func onViewAppear()
}

/// A protocol defining methods to handle account updates.
protocol AccountUpdateHandling {
    /// Updates the account information.
    func updateAccount()
}
