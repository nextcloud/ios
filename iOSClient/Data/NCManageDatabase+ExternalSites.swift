// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

class tableExternalSites: Object {
    @objc dynamic var account = ""
    @objc dynamic var icon = ""
    @objc dynamic var idExternalSite: Int = 0
    @objc dynamic var lang = ""
    @objc dynamic var name = ""
    @objc dynamic var type = ""
    @objc dynamic var url = ""
}

extension NCManageDatabase {

    // MARK: - Realm Write

    func addExternalSites(_ externalSite: NKExternalSite, account: String, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            let addObject = tableExternalSites()
            addObject.account = account
            addObject.idExternalSite = externalSite.idExternalSite
            addObject.icon = externalSite.icon
            addObject.lang = externalSite.lang
            addObject.name = externalSite.name
            addObject.url = externalSite.url
            addObject.type = externalSite.type
            realm.add(addObject)
        }
    }

    /// Asynchronously adds a new external site entry to the Realm database for the specified account.
    /// - Parameters:
    ///   - externalSite: The `NKExternalSite` model containing the site data.
    ///   - account: The account to which the site belongs.
    func addExternalSitesAsync(_ externalSite: NKExternalSite, account: String) async {
        await performRealmWriteAsync { realm in
            let addObject = tableExternalSites()
            addObject.account = account
            addObject.idExternalSite = externalSite.idExternalSite
            addObject.icon = externalSite.icon
            addObject.lang = externalSite.lang
            addObject.name = externalSite.name
            addObject.url = externalSite.url
            addObject.type = externalSite.type
            realm.add(addObject)
        }
    }

    func deleteExternalSites(account: String, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            let results = realm.objects(tableExternalSites.self).filter("account == %@", account)
            realm.delete(results)
        }
    }

    /// Asynchronously deletes all `tableExternalSites` entries for a given account from the Realm database.
    /// - Parameter account: The account identifier whose external sites should be deleted.
    func deleteExternalSitesAsync(account: String) async {
        await performRealmWriteAsync { realm in
            let results = realm.objects(tableExternalSites.self)
                .filter("account == %@", account)
            realm.delete(results)
        }
    }

    // MARK: - Realm Read

    func getAllExternalSites(account: String) -> [tableExternalSites]? {
        performRealmRead { realm in
            let results = realm.objects(tableExternalSites.self)
                .filter("account == %@", account)
                .sorted(byKeyPath: "idExternalSite", ascending: true)

            return results.isEmpty ? nil : results.map { tableExternalSites(value: $0) }
        }
    }
}
