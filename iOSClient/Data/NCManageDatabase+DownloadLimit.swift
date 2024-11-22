// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import RealmSwift

///
/// Data model for storing information about download limits of shares.
///
class tableDownloadLimit: Object {
    ///
    /// The number of downloads which already happened.
    ///
    @Persisted
    @objc dynamic var count: Int = 0

    ///
    /// Total number of allowed downloas.
    ///
    @Persisted
    @objc dynamic var limit: Int = 0

    ///
    /// The token identifying the related share.
    ///
    @Persisted(primaryKey: true)
    @objc dynamic var token: String = ""
}

extension NCManageDatabase {
    ///
    /// Create a new download limit object in the database.
    ///
    @discardableResult
    func createDownloadLimit(count: Int, limit: Int, token: String) throws -> tableDownloadLimit? {
        let downloadLimit = tableDownloadLimit()
        downloadLimit.count = count
        downloadLimit.limit = limit
        downloadLimit.token = token

        do {
            let realm = try Realm()

            try realm.write {
                realm.add(downloadLimit, update: .all)
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }

        return downloadLimit
    }

    ///
    /// Delete an existing download limit object identified by the token of its related share.
    ///
    /// - Parameter token: The `token` of the associated ``Nextcloud/tableShare/token``.
    ///
    func deleteDownloadLimit(byShareToken token: String) throws {
        do {
            let realm = try Realm()

            try realm.write {
                let result = realm.objects(tableDownloadLimit.self).filter("token == %@", token)
                realm.delete(result)
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    ///
    /// Retrieve a download limit by the token of the associated ``Nextcloud/tableShare/token``.
    ///
    /// - Parameter token: The `token` of the associated ``tableShare``.
    ///
    func getDownloadLimit(byShareToken token: String) throws -> tableDownloadLimit? {
        do {
            let realm = try Realm()
            let predicate = NSPredicate(format: "token == %@", token)

            guard let result = realm.objects(tableDownloadLimit.self).filter(predicate).first else {
                return nil
            }

            return result
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }

        return nil
    }
}
