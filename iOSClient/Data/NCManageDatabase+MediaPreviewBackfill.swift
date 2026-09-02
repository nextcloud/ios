// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

final class tableMediaPreviewBackfill: Object {
    @Persisted(primaryKey: true) var key: String = ""

    @Persisted var account: String
    @Persisted var ocId: String

    convenience init(account: String, ocId: String) {
        self.init()

        self.key = "\(account)-\(ocId)"
        self.account = account
        self.ocId = ocId
    }
}

extension NCManageDatabase {

    // MARK: - Media preview backfill Realm read

    func getFailedMediaPreviewOcIdsAsync(account: String) async -> Set<String> {
        await core.performRealmReadAsync { realm in
            let results = realm.objects(tableMediaPreviewBackfill.self)
                .where {
                    $0.account == account
                }

            return Set(results.map(\.ocId))
        } ?? []
    }

    // MARK: - Media preview backfill Realm write

    func addMediaPreviewBackfillFailureAsync(account: String, ocId: String) async {
        await core.performRealmWriteAsync { realm in
            let item = tableMediaPreviewBackfill()
            item.key = "\(account)-\(ocId)"
            item.account = account
            item.ocId = ocId

            realm.add(item, update: .modified)
        }
    }
}
