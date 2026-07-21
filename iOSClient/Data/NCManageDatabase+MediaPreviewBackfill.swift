// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

enum MediaPreviewBackfillStatus: Int {
    case pending = 0
    case completed
    case temporarilyFailed
    case permanentlyFailed
}

final class tableMediaPreviewBackfill: Object {
    @Persisted(primaryKey: true) var id: String

    @Persisted var account: String
    @Persisted var ocId: String
    @Persisted var errorCode: Int = 0
    @Persisted var date: Date = Date()

    convenience init(account: String, ocId: String, errorCode: Int) {
        self.init()

        self.id = Self.makeId(account: account, ocId: ocId)
        self.account = account
        self.ocId = ocId
        self.errorCode = errorCode
        self.date = Date()
    }

    static func makeId(account: String, ocId: String) -> String {
        "\(account)|\(ocId)"
    }
}

extension NCManageDatabase {

    // MARK: - Media preview backfill Realm read

    func getMediaPreviewBackfillAsync(account: String, ocId: String) async -> tableMediaPreviewBackfill? {
        await core.performRealmReadAsync { realm in
            let id = tableMediaPreviewBackfill.makeId(account: account, ocId: ocId)

            guard let backfill = realm.object(
                ofType: tableMediaPreviewBackfill.self,
                forPrimaryKey: id
            ) else {
                return nil
            }

            return tableMediaPreviewBackfill(value: backfill)
        }
    }

    func isMediaPreviewBackfillFailedAsync(account: String, ocId: String) async -> Bool {
        await core.performRealmReadAsync { realm in
            realm.object(
                ofType: tableMediaPreviewBackfill.self,
                forPrimaryKey: tableMediaPreviewBackfill.makeId(
                    account: account,
                    ocId: ocId
                )
            ) != nil
        } ?? false
    }

    // MARK: - Media preview backfill Realm write

    func addMediaPreviewBackfillFailureAsync(account: String, ocId: String, errorCode: Int) async {
        await core.performRealmWriteAsync { realm in
            let id = tableMediaPreviewBackfill.makeId(account: account, ocId: ocId)

            if let backfill = realm.object(ofType: tableMediaPreviewBackfill.self, forPrimaryKey: id) {
                backfill.errorCode = errorCode
                backfill.date = Date()
            } else {
                let backfill = tableMediaPreviewBackfill(account: account, ocId: ocId, errorCode: errorCode)
                realm.add(backfill)
            }
        }
    }

    func deleteMediaPreviewBackfillFailureAsync(account: String, ocId: String) async {
        await core.performRealmWriteAsync { realm in
            let id = tableMediaPreviewBackfill.makeId(account: account, ocId: ocId)

            guard let backfill = realm.object(ofType: tableMediaPreviewBackfill.self, forPrimaryKey: id) else {
                return
            }

            realm.delete(backfill)
        }
    }

    func deleteMediaPreviewBackfillFailuresAsync(
        account: String
    ) async {
        await core.performRealmWriteAsync { realm in
            let backfills = realm.objects(tableMediaPreviewBackfill.self)
                .where {
                    $0.account == account
                }

            realm.delete(backfills)
        }
    }
}
