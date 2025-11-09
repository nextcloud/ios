// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
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
    func addTagAsunc(_ ocId: String, tagIOS: Data?, account: String) async {
        await core.performRealmWriteAsync { realm in
            let addObject = tableTag()
            addObject.account = account
            addObject.ocId = ocId
            addObject.tagIOS = tagIOS
            realm.add(addObject, update: .all)
        }
    }

    func getTagsAsync(predicate: NSPredicate) async -> [tableTag]? {
        await core.performRealmReadAsync { realm in
            let results = realm.objects(tableTag.self)
                .filter(predicate)
            return results.compactMap { tableTag(value: $0) }
        }
    }

    func getTags(predicate: NSPredicate) -> [tableTag]? {
        core.performRealmRead { realm in
            let results = realm.objects(tableTag.self)
                .filter(predicate)
            return results.compactMap { tableTag(value: $0) }
        }
    }

    func getTagAsync(predicate: NSPredicate) async -> tableTag? {
        await core.performRealmReadAsync { realm in
            return realm.objects(tableTag.self)
                .filter(predicate)
                .first.map { tableTag(value: $0) }
        }
    }

    func getTag(predicate: NSPredicate) -> tableTag? {
        var tag: tableTag?
        core.performRealmRead { realm in
            tag = realm.objects(tableTag.self)
                .filter(predicate)
                .first.map {
                    tableTag(value: $0)
                }
        }
        return tag
    }
}
