// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

class tableComments: Object, DateCompareable {
    var dateKey: Date { creationDateTime as Date }

    @objc dynamic var account = ""
    @objc dynamic var actorDisplayName = ""
    @objc dynamic var actorId = ""
    @objc dynamic var actorType = ""
    @objc dynamic var creationDateTime = NSDate()
    @objc dynamic var isUnread: Bool = false
    @objc dynamic var message = ""
    @objc dynamic var messageId = ""
    @objc dynamic var objectId = ""
    @objc dynamic var objectType = ""
    @objc dynamic var path = ""
    @objc dynamic var verb = ""

    override static func primaryKey() -> String {
        return "messageId"
    }
}

extension NCManageDatabase {

    // MARK: - Realm write

    func addComments(_ comments: [NKComments], account: String, objectId: String) {
        performRealmWrite { realm in
            let existing = realm.objects(tableComments.self)
                .filter("account == %@ AND objectId == %@", account, objectId)
            realm.delete(existing)

            let newComments = comments.map { comment -> tableComments in
                let obj = tableComments()
                obj.account = account
                obj.actorDisplayName = comment.actorDisplayName
                obj.actorId = comment.actorId
                obj.actorType = comment.actorType
                obj.creationDateTime = comment.creationDateTime as NSDate
                obj.isUnread = comment.isUnread
                obj.message = comment.message
                obj.messageId = comment.messageId
                obj.objectId = comment.objectId
                obj.objectType = comment.objectType
                obj.path = comment.path
                obj.verb = comment.verb
                return obj
            }

            realm.add(newComments, update: .all)
        }
    }

    // MARK: - Realm read

    func getComments(account: String, objectId: String) -> [tableComments] {
        performRealmRead { realm in
           let results = realm.objects(tableComments.self)
               .filter("account == %@ AND objectId == %@", account, objectId)
               .sorted(byKeyPath: "creationDateTime", ascending: false)
           return results.map(tableComments.init)
       } ?? []
    }
}
