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

protocol NCAccountSettingsModelDelegate: AnyObject {
    func accountSettingsDidDismiss(tableAccount: tableAccount?)
}

class NCAccountSettingsModel: ObservableObject, ViewOnAppearHandling {
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    var controller: NCMainTabBarController?
    var accounts: [tableAccount] = []
    weak var delegate: NCAccountSettingsModelDelegate?
    var timerChangeAccount: Timer?
    var notificationToken: NotificationToken?
    @Published var activeAccount: tableAccount?
    @Published var indexActiveAccount: Int = 0
    @Published var alias: String = ""
    @Published var dismissView = false

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
                case .error(let error):
                    NSLog("Could not access database: \(error.localizedDescription)")
                }
            }
        } catch let error {
            NSLog("Realm error: \(error.localizedDescription)")
        }
    }

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

    func getUserName() -> String {
        guard let activeAccount = activeAccount else { return "" }
        return alias.isEmpty ? activeAccount.displayName : "\(activeAccount.displayName) (\(alias))"
    }

    func setAlias(_ value: String) {
        guard let activeAccount = activeAccount else { return }
        NCManageDatabase.shared.setAccountAlias(activeAccount.account, alias: alias)
    }

    func getUserStatus() -> (statusImage: UIImage?, statusMessage: String, descriptionMessage: String) {
        guard let activeAccount = activeAccount else { return (nil, "", "") }
        if NCGlobal.shared.capabilityUserStatusEnabled,
           let tableAccount = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", activeAccount.account)) {
            return NCUtility().getUserStatus(userIcon: tableAccount.userStatusIcon, userStatus: tableAccount.userStatusStatus, userMessage: tableAccount.userStatusMessage)
        }
        return (nil, "", "")
    }

    func isAdminGroup() -> Bool {
        guard let activeAccount = activeAccount else { return false }
        let groups = NCManageDatabase.shared.getAccountGroups(account: activeAccount.account)
        return groups.contains(NCGlobal.shared.groupAdmin)
    }

    func getTableViewHeight() -> CGFloat {
        guard let activeAccount = activeAccount else { return 0 }
        var height: CGFloat = NCGlobal.shared.capabilityUserStatusEnabled ? 190 : 220
        if NCGlobal.shared.capabilityUserStatusEnabled,
           let tableAccount = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", activeAccount.account)) {
            if !tableAccount.email.isEmpty { height += 30 }
            if !tableAccount.phone.isEmpty { height += 30 }
            if !tableAccount.address.isEmpty { height += 30 }
        }
        return height == 190 ? 170 : height
    }

    func setAccount(account: String) {
        if let tableAccount = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", account)),
           self.activeAccount?.account != tableAccount.account {
            self.activeAccount = tableAccount
            self.alias = tableAccount.alias
            timerChangeAccount?.invalidate()
            timerChangeAccount = Timer.scheduledTimer(timeInterval: 1.5, target: self, selector: #selector(changeAccount), userInfo: nil, repeats: false)
        }
    }

    @objc func changeAccount() {
        if let activeAccount = activeAccount {
            self.appDelegate.changeAccount(activeAccount.account, userProfile: nil) { }
        }
    }

    func deleteAccount() {
        if let activeAccount = activeAccount {
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
