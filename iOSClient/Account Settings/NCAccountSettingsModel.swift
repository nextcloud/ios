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
import RealmSwift

/// Protocol for know when the Account Settings has dimissed
protocol NCAccountSettingsModelDelegate: AnyObject {
    func accountSettingsDidDismiss(tableAccount: tableAccount?)
}

/// A model that allows the user to configure the account
class NCAccountSettingsModel: ObservableObject, ViewOnAppearHandling {
    /// AppDelegate
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    /// Root View Controller
    var controller: NCMainTabBarController?
    /// All account
    var accounts: [tableAccount] = []
    /// Delegate
    weak var delegate: NCAccountSettingsModelDelegate?
    /// Timer change user
    var timerChangeAccount: Timer?
    /// Token observe tableAccount
    var notificationToken: NotificationToken?
    /// Account now active
    @Published var activeAccount: tableAccount?
    /// Index
    @Published var indexActiveAccount: Int = 0
    /// Current alias
    @Published var alias: String = ""
    /// Set true for dismiss the view
    @Published var dismissView = false

    /// Initialization code to set up the ViewModel with the active account
    init(controller: NCMainTabBarController?, delegate: NCAccountSettingsModelDelegate?) {
        self.controller = controller
        self.delegate = delegate
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            NCManageDatabase.shared.previewCreateDB()
        }
        onViewAppear()
        observeTableAccount()
    }

    deinit {
        timerChangeAccount?.invalidate()
        timerChangeAccount = nil
        notificationToken?.invalidate()
        notificationToken = nil
    }

    /// Reload the view when change the tableAccount
    func observeTableAccount() {
        do {
            let realm = try Realm()
            let results = realm.objects(tableAccount.self)
            notificationToken = results.observe { [weak self] (changes: RealmCollectionChange) in
                switch changes {
                case .initial:
                    break
                case .update:
                    DispatchQueue.main.async {
                        self?.objectWillChange.send()
                    }
                case .error:
                    break
                }
            }
        } catch let error as NSError {
            NSLog("Could not access database: ", error)
        }
    }

    /// Triggered when the view appears.
    func onViewAppear() {
        var indexActiveAccount = 0
        let accounts = NCManageDatabase.shared.getAllAccount()
        var activeAccount = NCManageDatabase.shared.getActiveAccount()
        var alias = ""

        for (index, account) in accounts.enumerated() {
            if account.active {
                activeAccount = account
                indexActiveAccount = index
                alias = account.alias
            }
        }

        self.indexActiveAccount = indexActiveAccount
        self.accounts = accounts
        self.activeAccount = activeAccount
        self.alias = alias
    }

    /// Func to get the user display name + alias
    func getUserName() -> String {
        guard let activeAccount else { return "" }
        if alias.isEmpty {
            return activeAccount.displayName
        } else {
            return activeAccount.displayName + " (\(alias))"
        }
    }

    /// Func to set alias
    func setAlias(_ value: String) {
        guard let activeAccount else { return }
        NCManageDatabase.shared.setAccountAlias(activeAccount.account, alias: alias)
    }

    /// Function to update the user data
    func getUserStatus() -> (statusImage: UIImage?, statusMessage: String, descriptionMessage: String) {
        guard let activeAccount else { return (UIImage(), "", "") }
        if NCGlobal.shared.capabilityUserStatusEnabled,
           let tableAccount = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", activeAccount.account)) {
            return NCUtility().getUserStatus(userIcon: tableAccount.userStatusIcon, userStatus: tableAccount.userStatusStatus, userMessage: tableAccount.userStatusMessage)
        }
        return (nil, "", "")
    }

    /// Is the user an Admin
    func isAdminGroup() -> Bool {
        guard let activeAccount else { return false }
        let groups = NCManageDatabase.shared.getAccountGroups(account: activeAccount.account)
        return groups.contains(NCGlobal.shared.groupAdmin)
    }

    /// Function to know the height of "account" data
    func getTableViewHeight() -> CGFloat {
        guard let activeAccount else { return 0 }
        var height: CGFloat = NCGlobal.shared.capabilityUserStatusEnabled ? 190 : 220
        if NCGlobal.shared.capabilityUserStatusEnabled,
           let tableAccount = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", activeAccount.account)) {
            if !tableAccount.email.isEmpty { height += 30 }
            if !tableAccount.phone.isEmpty { height += 30 }
            if !tableAccount.address.isEmpty { height += 30 }
        }
        if height == 190 { return 170 }
        return height
    }

    /// Function to change account after 1.5 sec of change
    func setAccount(account: String) {
        if let tableAccount = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", account)), self.activeAccount?.account != tableAccount.account {
            self.activeAccount = tableAccount
            self.alias = tableAccount.alias
            /// Change active account
            timerChangeAccount?.invalidate()
            timerChangeAccount = Timer.scheduledTimer(timeInterval: 1.5, target: self, selector: #selector(changeAccount), userInfo: nil, repeats: false)

        }
    }

    @objc func changeAccount() {
        if let activeAccount {
            self.appDelegate.changeAccount(activeAccount.account, userProfile: nil) { }
        }
    }

    /// Function to delete the current account
    func deleteAccount() {
        if let activeAccount {
            appDelegate.deleteAccount(activeAccount.account)
            if let account = NCManageDatabase.shared.getAllAccount().first?.account {
                appDelegate.changeAccount(account, userProfile: nil) {
                    onViewAppear()
                }
            } else {
                dismissView = true
                appDelegate.openLogin(selector: NCGlobal.shared.introLogin, openLoginWeb: false)
            }
        }
    }
}
