// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

/// Protocol for know when the Account Settings has dimissed
protocol NCAccountSettingsModelDelegate: AnyObject {
    func accountSettingsDidDismiss(tblAccount: tableAccount?, controller: NCMainTabBarController?)
}

/// A model that allows the user to configure the account
class NCAccountSettingsModel: ObservableObject, ViewOnAppearHandling {
    // AppDelegate
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    // Root View Controller
    var controller: NCMainTabBarController?
    // All account
    var tblAccounts: [tableAccount] = []
    // Delegate
    weak var delegate: NCAccountSettingsModelDelegate?
    // Token observe tableAccount
    var notificationToken: NotificationToken?
    // Account now
    @Published var tblAccount: tableAccount?
    // Index
    @Published var indexActiveAccount: Int = 0
    // Current alias
    @Published var alias: String = ""
    // Set true for dismiss the view
    @Published var dismissView = false
    // DB
    let database = NCManageDatabase.shared

    /// Initialization code to set up the ViewModel with the active account
    init(controller: NCMainTabBarController?, delegate: NCAccountSettingsModelDelegate?) {
        self.controller = controller
        self.delegate = delegate
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            Task {
                await self.database.previewCreateDB()
            }
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
        Task {
            await database.setAccountAliasAsync(tblAccount.account, alias: alias)
        }
    }

    /// Function to update the user data
    func getUserStatus() -> (statusImage: UIImage?, statusImageColor: UIColor, statusMessage: String, descriptionMessage: String) {
        guard let tblAccount,
              let capabilities = NCNetworking.shared.capabilities[tblAccount.account] else {
            return (UIImage(), .black, "", "")
        }
        if capabilities.userStatusEnabled,
           let tableAccount = database.getTableAccount(predicate: NSPredicate(format: "account == %@", tblAccount.account)) {
            return NCUtility().getUserStatus(userIcon: tableAccount.userStatusIcon, userStatus: tableAccount.userStatusStatus, userMessage: tableAccount.userStatusMessage)
        }
        return (nil, .black, "", "")
    }

    /// Is the user an Admin
    func isAdminGroup() -> Bool {
        guard let tblAccount else { return false }
#if DEBUG
        return true
#else
        let groups = database.getAccountGroups(account: tblAccount.account)
        return groups.contains(NCGlobal.shared.groupAdmin)
#endif
    }

    /// Function to know the height of "account" data
    func getTableViewHeight() -> CGFloat {
        guard let tblAccount,
              let capabilities = NCNetworking.shared.capabilities[tblAccount.account] else {
            return 0
        }
        var height: CGFloat = capabilities.userStatusEnabled ? 190 : 220
        if capabilities.userStatusEnabled,
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
        Task { @MainActor in
            if let tblAccount {
                await NCAccount().deleteAccount(tblAccount.account)
                let account = database.getAllTableAccount().first?.account
                setAccount(account: account)
                dismissView = true
            }
        }
    }
}
