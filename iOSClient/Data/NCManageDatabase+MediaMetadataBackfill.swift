// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

class tableMediaMetadataBackfill: Object {
    @Persisted(primaryKey: true) var account = ""
    @Persisted var offset = 0
    @Persisted var lastRunDate: Date?
    @Persisted var lastCompletedCycleDate: Date?

    convenience init(account: String) {
        self.init()
        self.account = account
    }
}

extension NCManageDatabase {

    // MARK: - Realm read

    func getMediaMetadataBackfillAsync(account: String) async -> tableMediaMetadataBackfill? {
        await core.performRealmReadAsync { realm in
            if let backfill = realm.object(ofType: tableMediaMetadataBackfill.self, forPrimaryKey: account) {
                return tableMediaMetadataBackfill(value: backfill)
            }

            return tableMediaMetadataBackfill(account: account)
        }
    }

    // MARK: - Realm write

    func updateMediaMetadataBackfillAsync(account: String,
                                          offset: Int) async {
        await core.performRealmWriteAsync { realm in
            if let backfill = realm.object(ofType: tableMediaMetadataBackfill.self,
                                           forPrimaryKey: account) {
                backfill.offset = offset
                backfill.lastRunDate = Date()
            } else {
                let backfill = tableMediaMetadataBackfill(account: account)
                backfill.offset = offset
                backfill.lastRunDate = Date()
                realm.add(backfill)
            }
        }
    }

    func completeMediaMetadataBackfillAsync(account: String) async {
        await core.performRealmWriteAsync { realm in
            if let backfill = realm.object(ofType: tableMediaMetadataBackfill.self, forPrimaryKey: account) {
                backfill.offset = 0
                backfill.lastRunDate = Date()
                backfill.lastCompletedCycleDate = Date()
            } else {
                let backfill = tableMediaMetadataBackfill(account: account)
                backfill.offset = 0
                backfill.lastRunDate = Date()
                backfill.lastCompletedCycleDate = Date()
                realm.add(backfill)
            }
        }
    }
}
