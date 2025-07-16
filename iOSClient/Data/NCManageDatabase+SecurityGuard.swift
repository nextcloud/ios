// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

class TableSecurityGuardDiagnostics: Object {
    @Persisted var account = ""
    @Persisted(primaryKey: true) var primaryKey = ""
    @Persisted var issue: String = ""
    @Persisted var error: String?
    @Persisted var counter: Int = 0
    @Persisted var oldest: TimeInterval
    @Persisted var id: ObjectId

    convenience init(account: String, issue: String, error: String?, date: Date) {
        self.init()

        self.account = account
        self.primaryKey = account + issue + (error ?? "")
        self.issue = issue
        self.error = error
        self.counter = 1
        self.oldest = date.timeIntervalSince1970
     }
}

extension NCManageDatabase {

    // MARK: - Realm write

    func addDiagnosticAsync(account: String,
                            issue: String,
                            error: String? = nil) async {
        await performRealmWriteAsync { realm in
            let primaryKey = account + issue + (error ?? "")

            if let result = realm.object(ofType: TableSecurityGuardDiagnostics.self, forPrimaryKey: primaryKey) {
                result.counter += 1
                result.oldest = Date().timeIntervalSince1970
            } else {
                let table = TableSecurityGuardDiagnostics(account: account,
                                                          issue: issue,
                                                          error: error,
                                                          date: Date())
                realm.add(table)
            }
        }
    }

    func deleteDiagnosticsAsync(account: String, ids: [ObjectId]) async {
        await performRealmWriteAsync { realm in
            let results = realm.objects(TableSecurityGuardDiagnostics.self)
                .filter("account == %@", account)

            for result in results where ids.contains(result.id) {
                realm.delete(result)
            }
        }
    }

    // MARK: - Realm read

    func existsDiagnosticsAsync(account: String) async -> Bool {
        let exists: Bool? = await performRealmReadAsync { realm in
            let results = realm.objects(TableSecurityGuardDiagnostics.self)
                .filter("account == %@", account)
            return !results.isEmpty
        }
        return exists ?? false
    }

    func getDiagnosticsAsync(account: String) async -> [TableSecurityGuardDiagnostics]? {
        await performRealmReadAsync { realm in
            let results = realm.objects(TableSecurityGuardDiagnostics.self)
                .filter("account == %@", account)
            return results.map { TableSecurityGuardDiagnostics(value: $0) }
        }
    }
}
