// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

class tableTag: Object {
    @objc dynamic var account = ""
    @objc dynamic var ocId = ""
    @objc dynamic var tagIOS: Data?

    override static func primaryKey() -> String {
        return "ocId"
    }
}

extension NCManageDatabase {

    // MARK: - Realm write

    func addTag(_ ocId: String, tagIOS: Data?, account: String) {
        performRealmWrite { realm in
            let addObject = tableTag()
            addObject.account = account
            addObject.ocId = ocId
            addObject.tagIOS = tagIOS
            realm.add(addObject, update: .all)
        }
    }

    func deleteTag(_ ocId: String) {
        performRealmWrite { realm in
            let results = realm.objects(tableTag.self)
                .filter("ocId == %@", ocId)
            realm.delete(results)
        }
    }

    // MARK: - Realm read

    func getTags(predicate: NSPredicate) -> [tableTag] {
        var tags: [tableTag] = []
        performRealmRead { realm in
            let results = realm.objects(tableTag.self)
                .filter(predicate)
            tags = results.compactMap { tableTag(value: $0) }
        }
        return tags
    }

    func getTag(predicate: NSPredicate) -> tableTag? {
        var tag: tableTag?
        performRealmRead { realm in
            tag = realm.objects(tableTag.self)
                .filter(predicate)
                .first.map {
                    tableTag(value: $0)
                }
        }
        return tag
    }
}
