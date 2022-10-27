//
//  IntentHandler.swift
//  WidgetDashboardIntentHandler
//
//  Created by Marino Faggiana on 08/10/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//

import Intents
import RealmSwift

class IntentHandler: INExtension, DashboardIntentHandling, LockscreenIntentHandling {

    // MARK: - Lockscreen

    // Account

    func provideAccountsOptionsCollection(for intent: LockscreenIntent, with completion: @escaping (INObjectCollection<AccountsLockscreen>?, Error?) -> Void) {

        var accounts: [AccountsLockscreen] = []
        let results = NCManageDatabase.shared.getAllAccount()

        accounts.append(AccountsLockscreen(identifier: "active", display: NSLocalizedString("_account_active_", comment: "")))

        if results.isEmpty {
            return completion(nil, nil)
        } else if results.count == 1 {
            return completion(INObjectCollection(items: accounts), nil)
        }
        for result in results {
            let display = (result.alias.isEmpty) ? result.account : result.alias
            let account = AccountsLockscreen(identifier: result.account, display: display)
            accounts.append(account)
        }

        completion(INObjectCollection(items: accounts), nil)
    }

    func defaultAccounts(for intent: LockscreenIntent) -> AccountsLockscreen? {

        if NCManageDatabase.shared.getActiveAccount() == nil {
            return nil
        } else {
            return AccountsLockscreen(identifier: "active", display: NSLocalizedString("_account_active_", comment: ""))
        }
    }

    // MARK: - Dashboard

    // Application

    func provideApplicationsOptionsCollection(for intent: DashboardIntent, with completion: @escaping (INObjectCollection<Applications>?, Error?) -> Void) {

        var applications: [Applications] = []

        guard let account = NCManageDatabase.shared.getActiveAccount() else {
            return completion(nil, nil)
        }

        let results = NCManageDatabase.shared.getDashboardWidgetApplications(account: account.account)
        for result in results {
            let application = Applications(identifier: result.id, display: result.title)
            applications.append(application)
        }

        completion(INObjectCollection(items: applications), nil)
    }

    func defaultApplications(for intent: DashboardIntent) -> Applications? {

        guard let account = NCManageDatabase.shared.getActiveAccount() else {
            return nil
        }
        if let result = NCManageDatabase.shared.getDashboardWidgetApplications(account: account.account).first {
            return Applications(identifier: result.id, display: result.title)
        }
        return nil
    }

    // Account

    func provideAccountsOptionsCollection(for intent: DashboardIntent, with completion: @escaping (INObjectCollection<AccountsDashboard>?, Error?) -> Void) {

        var accounts: [AccountsDashboard] = []
        let results = NCManageDatabase.shared.getAllAccount()

        accounts.append(AccountsDashboard(identifier: "active", display: NSLocalizedString("_account_active_", comment: "")))

        if results.isEmpty {
            return completion(nil, nil)
        } else if results.count == 1 {
            return completion(INObjectCollection(items: accounts), nil)
        }
        for result in results {
            let display = (result.alias.isEmpty) ? result.account : result.alias
            let account = AccountsDashboard(identifier: result.account, display: display)
            accounts.append(account)
        }

        completion(INObjectCollection(items: accounts), nil)
    }

    func defaultAccounts(for intent: DashboardIntent) -> AccountsDashboard? {

        if NCManageDatabase.shared.getActiveAccount() == nil {
            return nil
        } else {
            return AccountsDashboard(identifier: "active", display: NSLocalizedString("_account_active_", comment: ""))
        }
    }
}
