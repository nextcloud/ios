// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import RealmSwift

///
/// Data model for storing information about download limits of shares.
///
class TableDownloadLimit: Object {
    ///
    /// Required primary key for identifiying a specific object.
    ///
    @Persisted(primaryKey: true)
    var id: String

    ///
    /// User account required for namespacing.
    ///
    @Persisted
    var account: String = ""

    ///
    /// The number of downloads which already happened.
    ///
    @Persisted
    var count: Int = 0

    ///
    /// Total number of allowed downloads.
    ///
    @Persisted
    var limit: Int = 0

    ///
    /// The token identifying the related share.
    ///
    @Persisted
    var token: String = ""
}

extension NCManageDatabase {
    ///
    /// Consolidated implementation of formatting for the primary key value.
    ///
    private func formatId(by account: String, token: String) -> String {
        "\(account) \(token)"
    }

    // MARK: - Realm write

    ///
    /// Create a new download limit object in the database.
    ///
    @discardableResult
    func createDownloadLimit(account: String, count: Int, limit: Int, token: String) -> TableDownloadLimit {
        let downloadLimit = TableDownloadLimit()

        downloadLimit.id = formatId(by: account, token: token)
        downloadLimit.account = account
        downloadLimit.count = count
        downloadLimit.limit = limit
        downloadLimit.token = token

        performRealmWrite { realm in
            realm.add(downloadLimit, update: .all)
        }

        return downloadLimit
    }

    /// Asynchronously creates or updates a `TableDownloadLimit` object in Realm for the given account and token.
    ///
    /// - Parameters:
    ///   - account: The account identifier.
    ///   - count: The current download count.
    ///   - limit: The maximum allowed download count.
    ///   - token: A unique token used for identifying the limit record.
    /// - Returns: The attached `TableDownloadLimit` object stored in Realm.
    func createDownloadLimitAsync(account: String, count: Int, limit: Int, token: String) async {
        let id = formatId(by: account, token: token)
        let downloadLimit = TableDownloadLimit()
        downloadLimit.id = id
        downloadLimit.account = account
        downloadLimit.count = count
        downloadLimit.limit = limit
        downloadLimit.token = token

        await performRealmWriteAsync { realm in
            // Add or update the download limit object in Realm
            realm.add(downloadLimit, update: .all)
        }
    }

    ///
    /// Delete an existing download limit object identified by the token of its related share.
    ///
    /// - Parameters:
    ///     - account: The unique account identifier to namespace the limit.
    ///     - token: The `token` of the associated ``Nextcloud/tableShare/token``.
    ///
    func deleteDownloadLimit(byAccount account: String, shareToken token: String, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            if let object = realm.object(ofType: TableDownloadLimit.self, forPrimaryKey: self.formatId(by: account, token: token)) {
                realm.delete(object)
            }
        }
    }

    ///
    /// Delete an existing download limit object identified by the token of its related share.
    ///
    /// - Parameters:
    ///     - account: The unique account identifier to namespace the limit.
    ///     - token: The `token` of the associated ``Nextcloud/tableShare/token``.
    ///
    func deleteDownloadLimitAsync(byAccount account: String, shareToken token: String) async {
        await performRealmWriteAsync { realm in
            if let object = realm.object(ofType: TableDownloadLimit.self, forPrimaryKey: self.formatId(by: account, token: token)) {
                realm.delete(object)
            }
        }
    }

    // MARK: - Realm read

    ///
    /// Retrieve a download limit by the token of the associated ``Nextcloud/tableShare/token``.
    ///
    /// - Parameters:
    ///     - account: The unique account identifier to namespace the limit.
    ///     - token: The `token` of the associated ``tableShare``.
    ///
    func getDownloadLimit(byAccount account: String, shareToken token: String) throws -> TableDownloadLimit? {
        var limit: TableDownloadLimit?
        performRealmRead { realm in
            limit = realm.object(ofType: TableDownloadLimit.self, forPrimaryKey: self.formatId(by: account, token: token))
        }
        return limit
    }
}
