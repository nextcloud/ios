// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Intents
import RealmSwift

class IntentHandler: INExtension, DashboardIntentHandling, AccountIntentHandling {

    // MARK: - Account

    func provideAccountsOptionsCollection(for intent: AccountIntent, with completion: @escaping (INObjectCollection<Accounts>?, Error?) -> Void) {
        var accounts: [Accounts] = []
        let results = NCManageDatabase.shared.getAllTableAccount()

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
        if NCManageDatabase.shared.getActiveTableAccount() == nil {
            return nil
        } else {
            return Accounts(identifier: "active", display: "Active account")
        }
    }

    // MARK: - Dashboard

    // Application
    func provideApplicationsOptionsCollection(for intent: DashboardIntent, with completion: @escaping (INObjectCollection<Applications>?, Error?) -> Void) {
        guard let account = dashboardAccount(for: intent) else {
            completion(nil, nil)
            return
        }

        let applications = NCManageDatabase.shared.getDashboardWidgetApplications(account: account.account).map {
            Applications(identifier: $0.id, display: $0.title)
        }
        completion(INObjectCollection(items: applications), nil)
    }

    func defaultApplications(for intent: DashboardIntent) -> Applications? {
        guard let account = dashboardAccount(for: intent),
              let module = NCManageDatabase.shared.getDashboardWidgetApplications(account: account.account).first else { return nil }

        return Applications(identifier: module.id, display: module.title)
    }

    private func dashboardAccount(for intent: DashboardIntent) -> tableAccount? {
        let database = NCManageDatabase.shared
        let accountIdentifier = intent.accounts?.identifier ?? "active"
        return accountIdentifier == "active"
            ? database.getActiveTableAccount()
            : database.getTableAccount(account: accountIdentifier)
    }

    // Account
    func provideAccountsOptionsCollection(for intent: DashboardIntent, with completion: @escaping (INObjectCollection<Accounts>?, Error?) -> Void) {
        var accounts: [Accounts] = []
        let results = NCManageDatabase.shared.getAllTableAccount()

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
        if NCManageDatabase.shared.getActiveTableAccount() == nil {
            return nil
        } else {
            return Accounts(identifier: "active", display: "Active account")
        }
    }
}
