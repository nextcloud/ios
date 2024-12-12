//
//  NCManageDatabase+UserStatus.swift
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

class tableUserStatus: Object {
    @objc dynamic var account = ""
    @objc dynamic var clearAt: NSDate?
    @objc dynamic var clearAtTime: String?
    @objc dynamic var clearAtType: String?
    @objc dynamic var icon: String?
    @objc dynamic var id: String?
    @objc dynamic var message: String?
    @objc dynamic var predefined: Bool = false
    @objc dynamic var status: String?
    @objc dynamic var userId: String?
}

extension NCManageDatabase {
    func addUserStatus(_ userStatuses: [NKUserStatus], account: String, predefined: Bool) {
        do {
            let realm = try Realm()
            try realm.write {
                let results = realm.objects(tableUserStatus.self).filter("account == %@ AND predefined == %@", account, predefined)
                realm.delete(results)
                for userStatus in userStatuses {
                    let object = tableUserStatus()
                    object.account = account
                    object.clearAt = userStatus.clearAt as? NSDate
                    object.clearAtTime = userStatus.clearAtTime
                    object.clearAtType = userStatus.clearAtType
                    object.icon = userStatus.icon
                    object.id = userStatus.id
                    object.message = userStatus.message
                    object.predefined = userStatus.predefined
                    object.status = userStatus.status
                    object.userId = userStatus.userId
                    realm.add(object)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }
}
