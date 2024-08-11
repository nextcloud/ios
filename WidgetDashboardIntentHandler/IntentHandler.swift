//
//  IntentHandler.swift
//  WidgetDashboardIntentHandler
//
//  Created by Marino Faggiana on 08/10/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
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
        var applications: [Applications] = []
        var activeTableAccount: tableAccount?

        let accountIdentifier: String = intent.accounts?.identifier ?? "active"
        if accountIdentifier == "active" {
            activeTableAccount = NCManageDatabase.shared.getActiveTableAccount()
        } else {
            activeTableAccount = NCManageDatabase.shared.getTableAccount(predicate: NSPredicate(format: "account == %@", accountIdentifier))
        }

        guard let activeTableAccount else {
            return completion(nil, nil)
        }

        let results = NCManageDatabase.shared.getDashboardWidgetApplications(account: activeTableAccount.account)
        for result in results {
            let application = Applications(identifier: result.id, display: result.title)
            applications.append(application)
        }

        completion(INObjectCollection(items: applications), nil)
    }

    func defaultApplications(for intent: DashboardIntent) -> Applications? {
        guard let account = NCManageDatabase.shared.getActiveTableAccount() else {
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
