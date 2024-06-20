//
//  NCAccountSettingsModel.swift
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

protocol NCAccountSettingsModelDelegate: AnyObject {
    func accountSettingsDismiss()
}

/// A model that allows the user to configure the account
class NCAccountSettingsModel: ObservableObject, ViewOnAppearHandling {
    /// AppDelegate
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    /// Root View Controller
    var controller: NCMainTabBarController?
    /// All account
    var accounts: [tableAccount] = []
    /// Timer change account
    var timerChanheAccount: Timer?
    /// Account now active
    @Published var tableAccount: tableAccount?
    /// Index
    @Published var indexActiveAccount: Int = 0
    /// Current alias
    @Published var alias: String = ""
    /// State to control
    @Published var accountRequest: Bool = false
    /// Set true for dismiss the view
    @Published var dismissView = false

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

    /// Internal use
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

    /// Func to get the user display name + alias
    func getUserName() -> String {
        guard let tableAccount else { return "" }
        NCManageDatabase.shared.setAccountAlias(tableAccount.account, alias: alias)
        if alias.isEmpty {
            return tableAccount.displayName
        } else {
            return tableAccount.displayName + " (\(alias))"
        }
    }

    /// Function to update the user data
    func getUserStatus() -> (statusImage: UIImage, statusMessage: String, descriptionMessage: String) {
        guard let tableAccount else { return (UIImage(), "", "") }
        if NCGlobal.shared.capabilityUserStatusEnabled,
           let tableAccount = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", tableAccount.account)) {
            return NCUtility().getUserStatus(userIcon: tableAccount.userStatusIcon, userStatus: tableAccount.userStatusStatus, userMessage: tableAccount.userStatusMessage)
        }
        return (UIImage(), "", "")
    }

    /// Function to know the height of "account" data
    func getTableViewHeight() -> CGFloat {
        guard let tableAccount else { return 0 }
        var height: CGFloat = 190
        if NCGlobal.shared.capabilityUserStatusEnabled,
           let tableAccount = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", tableAccount.account)) {
            if !tableAccount.email.isEmpty { height += 30 }
            if !tableAccount.phone.isEmpty { height += 30 }
            if !tableAccount.address.isEmpty { height += 30 }
        }
        if height == 190 { return 170 }
        return height
    }

    /// Function to change account
    func setAccount(account: String) {
        if let tableAccount = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", account)), self.tableAccount?.account != tableAccount.account {
            self.tableAccount = tableAccount
            self.alias = tableAccount.alias
            /// Change active account
            timerChanheAccount?.invalidate()
            timerChanheAccount = Timer.scheduledTimer(timeInterval: 1.5, target: self, selector: #selector(changeAccount), userInfo: nil, repeats: false)
        }
    }

    @objc func changeAccount() {
        if let tableAccount = self.tableAccount {
            self.appDelegate.changeAccount(tableAccount.account, userProfile: nil)
        }
    }

    /// Function to delete the current account
    func deleteAccount() {
        if let tableAccount {
            appDelegate.deleteAccount(tableAccount.account, wipe: false)
            if let tableAccount = NCManageDatabase.shared.getAllAccount().first {
                appDelegate.changeAccount(tableAccount.account, userProfile: nil)
            } else {
                dismissView = true
                appDelegate.openLogin(selector: NCGlobal.shared.introLogin, openLoginWeb: false)
            }
            onViewAppear()
        }
    }
}
