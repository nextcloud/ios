//
//  NCManageDatabase+Problems.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 15/03/22.
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

class tableProblems: Object {

    @Persisted var account = ""
    @Persisted(primaryKey: true) var primaryKey = ""
    @Persisted var selector: String = ""
    @Persisted var count: Int = 1
    @Persisted var oldest: Double = 0
}

extension NCManageDatabase {

    func addProblem(account: String, selector: String, error: NKError) {

        do {
            let realm = try Realm()
            let primaryKey = account + selector
            try realm.write {
                if let result = realm.objects(tableProblems.self).filter("primaryKey == %@", primaryKey).first {
                    result.count += 1
                    result.oldest = Date().timeIntervalSince1970
                    realm.add(result, update: .all)
                } else {
                    let result = tableProblems()
                    result.primaryKey = primaryKey
                    result.oldest = Date().timeIntervalSince1970
                    realm.add(result, update: .all)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func deleteProblem(account: String, selector: String) {

        do {
            let realm = try Realm()
            let primaryKey = account + selector
            try realm.write {
                let result = realm.objects(tableProblems.self).filter("primaryKey == %@", primaryKey)
                realm.delete(result)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func getProblems(account: String) -> Results<tableProblems>? {

        do {
            let realm = try Realm()
            realm.refresh()
            return realm.objects(tableProblems.self).filter("account == %@", account)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not access database: \(error)")
        }

        return nil
    }

    func deleteProblems(account: String) {

        do {
            let realm = try Realm()
            try realm.write {
                let result = realm.objects(tableProblems.self).filter("account == %@", account)
                realm.delete(result)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }
}
