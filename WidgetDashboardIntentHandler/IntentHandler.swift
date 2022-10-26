//
//  IntentHandler.swift
//  WidgetDashboardIntentHandler
//
//  Created by Marino Faggiana on 08/10/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//

import Intents
import RealmSwift

class IntentHandler: INExtension, DashboardIntentHandling {

    // Application

    func provideApplicationsOptionsCollection(for intent: DashboardIntent, with completion: @escaping (INObjectCollection<Applications>?, Error?) -> Void) {

        var applications: [Applications] = []

        guard let account = NCManageDatabase.shared.getActiveAccount() else {
            completion(nil, nil)
            return
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
        accounts.append(Accounts(identifier: "active", display: NSLocalizedString("_account_active_", comment: "")))

        let results = NCManageDatabase.shared.getAllAccount()
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
            return Accounts(identifier: "active", display: NSLocalizedString("_account_active_", comment: ""))
        }
    }
}
