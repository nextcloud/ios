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

    func addTagAsunc(_ ocId: String, tagIOS: Data?, account: String) async {
        await performRealmWriteAsync { realm in
            let addObject = tableTag()
            addObject.account = account
            addObject.ocId = ocId
            addObject.tagIOS = tagIOS
            realm.add(addObject, update: .all)
        }
    }

    // MARK: - Realm read

    /// Asynchronously fetch an array of tableTag objects matching a predicate.
    func getTagsAsync(predicate: NSPredicate) async -> [tableTag]? {
        await performRealmReadAsync { realm in
            let results = realm.objects(tableTag.self)
                .filter(predicate)
            return results.compactMap { tableTag(value: $0) }
        }
    }

    func getTags(predicate: NSPredicate) -> [tableTag]? {
        performRealmRead { realm in
            let results = realm.objects(tableTag.self)
                .filter(predicate)
            return results.compactMap { tableTag(value: $0) }
        }
    }

    /// Asynchronously fetch a single tableTag object matching a predicate.
    func getTagAsync(predicate: NSPredicate) async -> tableTag? {
        await performRealmReadAsync { realm in
            return realm.objects(tableTag.self)
                .filter(predicate)
                .first.map { tableTag(value: $0) }
        }
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
