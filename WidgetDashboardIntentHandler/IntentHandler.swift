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
}
