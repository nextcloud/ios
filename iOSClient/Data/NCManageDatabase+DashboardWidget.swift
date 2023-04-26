//
//  NCManageDatabase+DashboardWidget.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 09/09/22.
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

import Foundation
import RealmSwift
import NextcloudKit

class tableDashboardWidget: Object {

    @Persisted(primaryKey: true) var index = ""
    @Persisted var account = ""
    @Persisted var id = ""
    @Persisted var title = ""
    @Persisted var order: Int = 0
    @Persisted var iconClass: String?
    @Persisted var iconUrl: String?
    @Persisted var widgetUrl: String?
    @Persisted var itemIconsRound: Bool = false
}

class tableDashboardWidgetButton: Object {

    @Persisted(primaryKey: true) var index = ""
    @Persisted var account = ""
    @Persisted var id = ""
    @Persisted var type = ""
    @Persisted var text = ""
    @Persisted var link = ""
}

extension NCManageDatabase {

    func getDashboardWidget(account: String, id: String) -> (tableDashboardWidget?, [tableDashboardWidgetButton]?) {
     
        let realm = try! Realm()
        guard let resultDashboard = realm.objects(tableDashboardWidget.self).filter("account == %@ AND id == %@", account, id).first else {
            return (nil, nil)
        }
        let resultsButton = realm.objects(tableDashboardWidgetButton.self).filter("account == %@ AND id == %@", account, id).sorted(byKeyPath: "type", ascending: true)
        
        return (tableDashboardWidget.init(value: resultDashboard), Array(resultsButton.map { tableDashboardWidgetButton.init(value: $0) }))
    }

    func getDashboardWidgetApplications(account: String) -> [tableDashboardWidget] {

        let realm = try! Realm()
        let sortProperties = [SortDescriptor(keyPath: "order", ascending: true), SortDescriptor(keyPath: "title", ascending: true)]
        let results = realm.objects(tableDashboardWidget.self).filter("account == %@", account).sorted(by: sortProperties)

        return Array(results.map { tableDashboardWidget.init(value: $0) })
    }
    
    func addDashboardWidget(account: String, dashboardWidgets: [NCCDashboardWidget]) {
        
        let realm = try! Realm()

        do {
            try realm.write {
                
                let resultDashboard = realm.objects(tableDashboardWidget.self).filter("account == %@", account)
                realm.delete(resultDashboard)
                
                let resultDashboardButton = realm.objects(tableDashboardWidgetButton.self).filter("account == %@", account)
                realm.delete(resultDashboardButton)
                
                for widget in dashboardWidgets {
                    
                    let addObject = tableDashboardWidget()
                    
                    addObject.index = account + " " + widget.id
                    addObject.account = account
                    addObject.id = widget.id
                    addObject.title = widget.title
                    addObject.order = widget.order
                    addObject.iconClass = widget.iconClass
                    addObject.iconUrl = widget.iconUrl
                    addObject.widgetUrl = widget.widgetUrl
                    addObject.itemIconsRound = widget.itemIconsRound

                    if let buttons = widget.button {
                        for button in buttons {
                            
                            let addObject = tableDashboardWidgetButton()
                            
                            addObject.account = account
                            addObject.id = widget.id
                            addObject.type = button.type
                            addObject.text = button.text
                            addObject.link = button.link
                            addObject.index = account + " " + widget.id + " " + button.type
                            
                            realm.add(addObject, update: .all)
                        }
                    }
                    
                    realm.add(addObject, update: .all)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }
}
