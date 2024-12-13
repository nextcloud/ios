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
    func accountSettingsDidDismiss(tableAccount: tableAccount?, controller: NCMainTabBarController?)
}

/// A model that allows the user to configure the account
class NCAccountSettingsModel: ObservableObject, ViewOnAppearHandling {
    /// AppDelegate
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    /// Root View Controller
    var controller: NCMainTabBarController?
    /// All account
    var tblAccounts: [tableAccount] = []
    /// Delegate
    weak var delegate: NCAccountSettingsModelDelegate?
    /// Token observe tableAccount
    var notificationToken: NotificationToken?
    /// Account now
    @Published var tblAccount: tableAccount?
    /// Index
    @Published var indexActiveAccount: Int = 0
    /// Current alias
    @Published var alias: String = ""
    /// Set true for dismiss the view
    @Published var dismissView = false
    /// DB
    let database = NCManageDatabase.shared

    /// Initialization code to set up the ViewModel with the active account
    init(controller: NCMainTabBarController?, delegate: NCAccountSettingsModelDelegate?) {
        self.controller = controller
        self.delegate = delegate
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            database.previewCreateDB()
        }
        onViewAppear()
        observeTableAccount()
    }

    deinit {
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
        let tableAccounts = database.getAllTableAccount()
        var alias = ""

        for (index, account) in tableAccounts.enumerated() {
            if account.active {
                tblAccount = account
                indexActiveAccount = index
                alias = account.alias
            }
        }

        self.indexActiveAccount = indexActiveAccount
        self.tblAccounts = tableAccounts
        self.tblAccount = tblAccount
        self.alias = alias
    }

    /// Func to get the user display name + alias
    func getUserName() -> String {
        guard let tblAccount else { return "" }
        if alias.isEmpty {
            return tblAccount.displayName
        } else {
            return tblAccount.displayName + " (\(alias))"
        }
    }

    /// Func to set alias
    func setAlias(_ value: String) {
        guard let tblAccount else { return }
        database.setAccountAlias(tblAccount.account, alias: alias)
    }

    /// Function to update the user data
    func getUserStatus() -> (statusImage: UIImage?, statusMessage: String, descriptionMessage: String) {
        guard let tblAccount else { return (UIImage(), "", "") }
        if NCCapabilities.shared.getCapabilities(account: tblAccount.account).capabilityUserStatusEnabled,
           let tableAccount = database.getTableAccount(predicate: NSPredicate(format: "account == %@", tblAccount.account)) {
            return NCUtility().getUserStatus(userIcon: tableAccount.userStatusIcon, userStatus: tableAccount.userStatusStatus, userMessage: tableAccount.userStatusMessage)
        }
        return (nil, "", "")
    }

    /// Is the user an Admin
    func isAdminGroup() -> Bool {
        guard let tblAccount else { return false }
        let groups = database.getAccountGroups(account: tblAccount.account)
        return groups.contains(NCGlobal.shared.groupAdmin)
    }

    /// Function to know the height of "account" data
    func getTableViewHeight() -> CGFloat {
        guard let tblAccount else { return 0 }
        let capabilities = NCCapabilities.shared.getCapabilities(account: tblAccount.account)
        var height: CGFloat = capabilities.capabilityUserStatusEnabled ? 190 : 220
        if capabilities.capabilityUserStatusEnabled,
           let tableAccount = database.getTableAccount(predicate: NSPredicate(format: "account == %@", tblAccount.account)) {
            if !tableAccount.email.isEmpty { height += 30 }
            if !tableAccount.phone.isEmpty { height += 30 }
            if !tableAccount.address.isEmpty { height += 30 }
        }
        if height == 190 { return 170 }
        return height
    }

    /// Function to change account after 1.5 sec of change
    func setAccount(account: String?) {
        guard let account
        else {
            self.tblAccount = nil
            self.alias = ""
            return
        }
        if let tableAccount = database.getTableAccount(predicate: NSPredicate(format: "account == %@", account)) {
            self.tblAccount = tableAccount
            self.alias = tableAccount.alias
        }
    }

    /// Function to delete the current account
    func deleteAccount() {
        if let tblAccount {
            NCAccount().deleteAccount(tblAccount.account) {
                let account = database.getAllTableAccount().first?.account
                setAccount(account: account)
                dismissView = true
            }
        }
    }
}
