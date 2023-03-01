//
//  IntentHandler.swift
//  WidgetDashboardIntentHandler
//
//  Created by Marino Faggiana on 08/10/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//

import Intents
import RealmSwift

class IntentHandler: INExtension, DashboardIntentHandling, AccountIntentHandling {

    // MARK: - Account

    // Account

    func provideAccountsOptionsCollection(for intent: AccountIntent, with completion: @escaping (INObjectCollection<Accounts>?, Error?) -> Void) {

        var accounts: [Accounts] = []
        let results = NCManageDatabase.shared.getAllAccount()

        accounts.append(Accounts(identifier: "active", display: "Active account"))

        if results.isEmpty {
            return completion(nil, nil)
        } else if results.count == 1 {
            return completion(INObjectCollection(items: accounts), nil)
        }
        for result in results {
            let display = (result.alias.isEmpty) ? result.account : result.alias
            let account = Accounts(identifier: result.account, display: display)
            accounts.append(account)
        }

        completion(INObjectCollection(items: accounts), nil)
    }

    func defaultAccounts(for intent: AccountIntent) -> Accounts? {

        if NCManageDatabase.shared.getActiveAccount() == nil {
            return nil
        } else {
            return Accounts(identifier: "active", display: "Active account")
        }
    }

    // MARK: - Dashboard

    // Application

    func provideApplicationsOptionsCollection(for intent: DashboardIntent, with completion: @escaping (INObjectCollection<Applications>?, Error?) -> Void) {

        var applications: [Applications] = []
        var account: tableAccount?

        let accountIdentifier: String = intent.accounts?.identifier ?? "active"
        if accountIdentifier == "active" {
            account = NCManageDatabase.shared.getActiveAccount()
        } else {
            account = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", accountIdentifier))
        }

        guard let account = account else {
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

    func provideAccountsOptionsCollection(for intent: DashboardIntent, with completion: @escaping (INObjectCollection<Accounts>?, Error?) -> Void) {

        var accounts: [Accounts] = []
        let results = NCManageDatabase.shared.getAllAccount()

        accounts.append(Accounts(identifier: "active", display: "Active account"))

        if results.isEmpty {
            return completion(nil, nil)
        } else if results.count == 1 {
            return completion(INObjectCollection(items: accounts), nil)
        }
        for result in results {
            let display = (result.alias.isEmpty) ? result.account : result.alias
            let account = Accounts(identifier: result.account, display: display)
            accounts.append(account)
        }

        completion(INObjectCollection(items: accounts), nil)
    }

    func defaultAccounts(for intent: DashboardIntent) -> Accounts? {

        if NCManageDatabase.shared.getActiveAccount() == nil {
            return nil
        } else {
            return Accounts(identifier: "active", display: "Active account")
        }
    }
}
