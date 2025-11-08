// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import RealmSwift

extension NCManageDatabaseFPE {
    func getAllTableAccount() -> [tableAccount] {
        core.performRealmRead { realm in
            let sorted = [SortDescriptor(keyPath: "active", ascending: false),
                          SortDescriptor(keyPath: "user", ascending: true)]
            let results = realm.objects(tableAccount.self)
                        .sorted(by: sorted)
            return results.map { tableAccount(value: $0) }
        } ?? []
    }

    func getActiveTableAccount() -> tableAccount? {
        core.performRealmRead { realm in
            realm.objects(tableAccount.self)
                .filter("active == true")
                .first
                .map { tableAccount(value: $0) }
        }
    }

    func getAllTableAccountAsync() async -> [tableAccount] {
        await core.performRealmReadAsync { realm in
            let sorted = [
                SortDescriptor(keyPath: "active", ascending: false),
                SortDescriptor(keyPath: "user", ascending: true)
            ]
            let results = realm.objects(tableAccount.self)
                               .sorted(by: sorted)
            return results.map { tableAccount(value: $0) } // detached copy
        } ?? []
    }
}
