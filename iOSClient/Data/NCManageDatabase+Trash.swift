// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

class tableTrash: Object {
    @objc dynamic var account = ""
    @objc dynamic var classFile = ""
    @objc dynamic var contentType = ""
    @objc dynamic var date = NSDate()
    @objc dynamic var directory: Bool = false
    @objc dynamic var fileId = ""
    @objc dynamic var fileName = ""
    @objc dynamic var filePath = ""
    @objc dynamic var hasPreview: Bool = false
    @objc dynamic var iconName = ""
    @objc dynamic var size: Int64 = 0
    @objc dynamic var trashbinFileName = ""
    @objc dynamic var trashbinOriginalLocation = ""
    @objc dynamic var trashbinDeletionTime = NSDate()

    override static func primaryKey() -> String {
        return "fileId"
    }
}

extension NCManageDatabase {

    // MARK: - Realm write

    func addTrash(account: String, items: [NKTrash]) {
        performRealmWrite { realm in
            items.forEach { trash in
                let object = tableTrash()
                object.account = account
                object.contentType = trash.contentType
                object.date = trash.date as NSDate
                object.directory = trash.directory
                object.fileId = trash.fileId
                object.fileName = trash.fileName
                object.filePath = trash.filePath
                object.hasPreview = trash.hasPreview
                object.iconName = trash.iconName
                object.size = trash.size
                object.trashbinDeletionTime = trash.trashbinDeletionTime as NSDate
                object.trashbinFileName = trash.trashbinFileName
                object.trashbinOriginalLocation = trash.trashbinOriginalLocation
                object.classFile = trash.classFile
                realm.add(object, update: .all)
            }
        }
    }

    func deleteTrash(filePath: String?, account: String) {
        let predicate: NSPredicate
        if let filePath {
            predicate = NSPredicate(format: "account == %@ AND filePath == %@", account, filePath)
        } else {
            predicate = NSPredicate(format: "account == %@", account)
        }

        performRealmWrite { realm in
            let results = realm.objects(tableTrash.self).filter(predicate)
            realm.delete(results)
        }
    }

    func deleteTrash(fileId: String?, account: String) {
        let predicate: NSPredicate
        if let fileId {
            predicate = NSPredicate(format: "account == %@ AND fileId == %@", account, fileId)
        } else {
            predicate = NSPredicate(format: "account == %@", account)
        }

        performRealmWrite { realm in
            let results = realm.objects(tableTrash.self).filter(predicate)
            realm.delete(results)
        }
    }

    /// Asynchronously deletes `tableTrash` objects matching the given `fileId` and `account`.
    /// - Parameters:
    ///   - fileId: Optional file ID to filter the trash entries. If `nil`, all entries for the account will be deleted.
    ///   - account: The account associated with the trash entries.
    func deleteTrashAsync(fileId: String?, account: String) async {
        let predicate: NSPredicate
        if let fileId {
            predicate = NSPredicate(format: "account == %@ AND fileId == %@", account, fileId)
        } else {
            predicate = NSPredicate(format: "account == %@", account)
        }

        await performRealmWriteAsync { realm in
            let results = realm.objects(tableTrash.self).filter(predicate)
            realm.delete(results)
        }
    }

    // MARK: - Realm read

    func getTableTrash(fileId: String, account: String) -> tableTrash? {
        performRealmRead { realm in
            realm.objects(tableTrash.self)
                .filter("account == %@ AND fileId == %@", account, fileId)
                .first
                .map { tableTrash(value: $0) }
        }
    }

    /// Asynchronously retrieves sorted trash results by filePath and account.
    /// - Returns: A `Results<tableTrash>` collection, or `nil` if Realm fails to open.
    func getTableTrashAsync(filePath: String, account: String) async -> [tableTrash] {
        await performRealmReadAsync { realm in
            let results = realm.objects(tableTrash.self)
                .filter("account == %@ AND filePath == %@", account, filePath)
                .sorted(byKeyPath: "trashbinDeletionTime", ascending: false)
            return results.map { tableTrash(value: $0) }
        } ?? []
    }

    /// Asynchronously retrieves the first `tableTrash` object matching the given `fileId` and `account`.
    /// - Parameters:
    ///   - fileId: The ID of the file to search for.
    ///   - account: The account associated with the file.
    /// - Returns: The matching `tableTrash` object, or `nil` if not found.
    func getTableTrashAsync(fileId: String, account: String) async -> tableTrash? {
        await performRealmReadAsync { realm in
            return realm.objects(tableTrash.self)
                .filter("account == %@ AND fileId == %@", account, fileId)
                .first
                .map { tableTrash(value: $0) }
        }
    }
}
