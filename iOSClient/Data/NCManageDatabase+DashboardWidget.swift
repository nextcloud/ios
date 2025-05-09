// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
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

    // MARK: - Realm Write

    func addDashboardWidget(account: String, dashboardWidgets: [NCCDashboardWidget]) {
        performRealmWrite { realm in
            realm.delete(realm.objects(tableDashboardWidget.self).filter("account == %@", account))
            realm.delete(realm.objects(tableDashboardWidgetButton.self).filter("account == %@", account))

            for widget in dashboardWidgets {
                let widgetObject = tableDashboardWidget()
                widgetObject.index = "\(account) \(widget.id)"
                widgetObject.account = account
                widgetObject.id = widget.id
                widgetObject.title = widget.title
                widgetObject.order = widget.order
                widgetObject.iconClass = widget.iconClass
                widgetObject.iconUrl = widget.iconUrl
                widgetObject.widgetUrl = widget.widgetUrl
                widgetObject.itemIconsRound = widget.itemIconsRound

                realm.add(widgetObject, update: .all)

                widget.button?.forEach { button in
                    let buttonObject = tableDashboardWidgetButton()
                    buttonObject.account = account
                    buttonObject.id = widget.id
                    buttonObject.type = button.type
                    buttonObject.text = button.text
                    buttonObject.link = button.link
                    buttonObject.index = "\(account) \(widget.id) \(button.type)"

                    realm.add(buttonObject, update: .all)
                }
            }
        }
    }

    // MARK: - Realm Read

    func getDashboardWidget(account: String, id: String) -> (tableDashboardWidget?, [tableDashboardWidgetButton]?) {
        var widget: tableDashboardWidget?
        var buttons: [tableDashboardWidgetButton]?

        performRealmRead { realm in
            if let result = realm.objects(tableDashboardWidget.self)
                .filter("account == %@ AND id == %@", account, id)
                .first {
                widget = tableDashboardWidget(value: result)
            }

            let resultButtons = realm.objects(tableDashboardWidgetButton.self)
                .filter("account == %@ AND id == %@", account, id)
                .sorted(byKeyPath: "type", ascending: true)

            if !resultButtons.isEmpty {
                buttons = resultButtons.map { tableDashboardWidgetButton(value: $0) }
            }
        }

        return (widget, buttons)
    }

    func getDashboardWidgetApplications(account: String) -> [tableDashboardWidget] {
        performRealmRead { realm in
            realm.objects(tableDashboardWidget.self)
                .filter("account == %@", account)
                .sorted(by: [
                    SortDescriptor(keyPath: "order", ascending: true),
                    SortDescriptor(keyPath: "title", ascending: true)
                ])
                .map { tableDashboardWidget(value: $0) }
        } ?? []
    }
}
