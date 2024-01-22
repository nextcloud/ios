//
//  NCManageDatabase+SecurityGuard.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 17/01/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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

class TableSecurityGuardDiagnostics: Object {

    @Persisted var account = ""
    @Persisted(primaryKey: true) var primaryKey = ""
    @Persisted var issue: String = ""                           // "sync_conflicts", "problems", "virus_detected", "e2ee_errors"
    @Persisted var problemserror: String?
    @Persisted var counter: Int = 0
    @Persisted var oldest: Double

    convenience init(account: String, issue: String, problemserror: String?, date: Date) {
        self.init()

        self.account = account
        self.primaryKey = account + issue + (problemserror ?? "")
        self.issue = issue
        self.problemserror = problemserror
        self.counter = 1
        self.oldest = date.timeIntervalSince1970
     }
}

extension NCManageDatabase {

    func addDiagnostic(account: String, issue: String, problemserror: String? = nil) {

        do {
            let realm = try Realm()
            try realm.write {
                let primaryKey = account + issue + (problemserror ?? "")
                if let result = realm.object(ofType: TableSecurityGuardDiagnostics.self, forPrimaryKey: primaryKey) {
                    result.counter += 1
                    result.oldest = Date().timeIntervalSince1970
                } else {
                    let table = TableSecurityGuardDiagnostics(account: account, issue: issue, problemserror: problemserror, date: Date())
                    realm.add(table)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func getDiagnostics(account: String) -> Results<TableSecurityGuardDiagnostics>? {

        do {
            let realm = try Realm()
            let results = realm.objects(TableSecurityGuardDiagnostics.self).where({
                $0.account == account
            })
            return results
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not access database: \(error)")
        }

        return nil
    }

    func deleteDiagnostic(account: String, issue: String, problemserror: String? = nil) {

        do {
            let realm = try Realm()
            try realm.write {
                let primaryKey = account + issue + (problemserror ?? "")
                if let result = realm.object(ofType: TableSecurityGuardDiagnostics.self, forPrimaryKey: primaryKey) {
                    realm.delete(result)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }
}
