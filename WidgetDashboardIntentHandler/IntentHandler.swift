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

    override func handler(for intent: INIntent) -> Any {
        // This is the default implementation.  If you want different objects to handle different intents,
        // you can override this and return the handler you want for that particular intent.

        guard let account = NCManageDatabase.shared.getActiveAccount() else {
            return self
        }


        return self
    }

    func provideCategoryOptionsCollection(for intent: DashboardIntentHandling, with completion: @escaping (INObjectCollection<Applications>?, Error?) -> Void) {

        let eventCategory = Applications(identifier: "ciao", display: "ciao")
        let collection = INObjectCollection(items: [eventCategory])

        completion(collection, nil)
    }
}
