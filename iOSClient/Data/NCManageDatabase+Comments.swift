//
//  NCManageDatabase+Comments.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 13/11/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
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
    func addComments(_ comments: [NKComments], account: String, objectId: String) {
        do {
            let realm = try Realm()
            try realm.write {
                let results = realm.objects(tableComments.self).filter("account == %@ AND objectId == %@", account, objectId)
                realm.delete(results)
                for comment in comments {
                    let object = tableComments()
                    object.account = account
                    object.actorDisplayName = comment.actorDisplayName
                    object.actorId = comment.actorId
                    object.actorType = comment.actorType
                    object.creationDateTime = comment.creationDateTime as NSDate
                    object.isUnread = comment.isUnread
                    object.message = comment.message
                    object.messageId = comment.messageId
                    object.objectId = comment.objectId
                    object.objectType = comment.objectType
                    object.path = comment.path
                    object.verb = comment.verb
                    realm.add(object, update: .all)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func getComments(account: String, objectId: String) -> [tableComments] {
        do {
            let realm = try Realm()
            let results = realm.objects(tableComments.self).filter("account == %@ AND objectId == %@", account, objectId).sorted(byKeyPath: "creationDateTime", ascending: false)
            return Array(results.map(tableComments.init))
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return []
    }
}
