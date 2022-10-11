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

        let collection = INObjectCollection(items: applications)
        completion(collection, nil)
    }
}
