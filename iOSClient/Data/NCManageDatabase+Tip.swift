//
//  NCManageDatabase+Tip.swift
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

class tableTip: Object {
    @Persisted(primaryKey: true) var tipName = ""
}

extension NCManageDatabase {
    func tipExists(_ tipName: String) -> Bool {
        do {
            let realm = try Realm()
            guard (realm.objects(tableTip.self).where {
                $0.tipName == tipName
            }.first) == nil else {
                return true
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access to database: \(error)")
        }
        return false
    }

    func addTip(_ tipName: String) {
        do {
            let realm = try Realm()
            try realm.write {
                let addObject = tableTip()
                addObject.tipName = tipName
                realm.add(addObject, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }
}
