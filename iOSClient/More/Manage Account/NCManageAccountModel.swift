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
    /// Account
    @Published var tableAccount: tableAccount?
    ///
    @Published var indexActiveAccount: Int = 0
    ///
    @Published var alias: String = ""
    ///
    @Published var accountRequest: Bool = false

    /// Initialization code to set up the ViewModel with the active account
    init(controller: NCMainTabBarController?) {
        self.controller = controller
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            NCManageDatabase.shared.previewCreateDB()
        }
        onViewAppear()
    }

    /// Triggered when the view appears.
    func onViewAppear() {
        accounts = NCManageDatabase.shared.getAllAccount()
        accountRequest = NCKeychain().accountRequest
        getIndexActiveAccount()
    }

    ///
    func getIndexActiveAccount() {
        self.indexActiveAccount = 0
        for (index, account) in accounts.enumerated() {
            if account.active {
                self.tableAccount = account
                self.indexActiveAccount = index
                self.alias = account.alias
            }
        }
    }

    ///
    func getUserName() -> String {
        guard let tableAccount else { return "" }
        NCManageDatabase.shared.setAccountAlias(tableAccount.account, alias: alias)
        if alias.isEmpty {
            return tableAccount.displayName
        } else {
            return tableAccount.displayName + " (\(alias))"
        }
    }

    ///
    func getUserStatus() -> (onlineStatus: UIImage?, statusMessage: String?) {
        guard let tableAccount else { return (nil, nil) }
        if NCGlobal.shared.capabilityUserStatusEnabled,
           let tableAccount = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", tableAccount.account)) {
            let status = NCUtility().getUserStatus(userIcon: tableAccount.userStatusIcon, userStatus: tableAccount.userStatusStatus, userMessage: tableAccount.userStatusMessage)
            let image = status.onlineStatus
            let text = status.statusMessage
            return (image, text)
        }
        return (nil, nil)
    }

    ///
    func setAccount(account: String) {
        if let tableAccount = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", account)), self.tableAccount?.account != tableAccount.account {
            self.tableAccount = tableAccount
            self.alias = tableAccount.alias
            /// Change active account
            appDelegate.changeAccount(tableAccount.account, userProfile: nil)
        }
    }

    /// 
    func updateAccountRequest() {
        NCKeychain().accountRequest = accountRequest
    }

    ///
    func deleteAccount() {
        if let tableAccount {
            appDelegate.deleteAccount(tableAccount.account, wipe: false)
            onViewAppear()
        }
    }

    ///
    func addAccount() {
       // appDelegate.openLogin(selector: NCGlobal.shared.introLogin, openLoginWeb: false)
    }
}
