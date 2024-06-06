//
//  NCManageAccountModel.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/06/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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

/// A model that allows the user to configure the account
class NCManageAccountModel: ObservableObject, ViewOnAppearHandling {
    /// AppDelegate
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    /// Root View Controller
    var controller: NCMainTabBarController?
    /// All account
    var accounts: [tableAccount] = []

    @Published var indexActiveAccount: Int = 0

    /// Initialization code to set up the ViewModel with the active account
    init(controller: NCMainTabBarController?) {
        self.controller = controller
        onViewAppear()
    }

    /// Triggered when the view appears.
    func onViewAppear() {
        accounts = NCManageDatabase.shared.getAllAccount()
        getIndexActiveAccount()
    }

    func getIndexActiveAccount() {
        self.indexActiveAccount = 0
        for (index, item) in accounts.enumerated() {
            if item.active {
                self.indexActiveAccount = index
            }
        }
    }

    func getUserName(account: tableAccount) -> String {
        if account.alias.isEmpty {
            return account.displayName
        } else {
            return account.displayName + " (\(account.alias)"
        }
    }

    func getUserStatus(account: tableAccount) -> (onlineStatus: UIImage?, statusMessage: String?) {
        if NCGlobal.shared.capabilityUserStatusEnabled {
            let status = NCUtility().getUserStatus(userIcon: account.userStatusIcon, userStatus: account.userStatusStatus, userMessage: account.userStatusMessage)
            let image = status.onlineStatus
            let text = status.statusMessage
            return (image, text)
        }
        return (nil, nil)
    }
}
