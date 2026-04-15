// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

/// Represents a trash item stored in Realm.
///
/// Each object corresponds to a file or folder in the Nextcloud trashbin,
/// associated with a specific account.
///
/// The `identifier` is used as primary key and is built from:
/// `account + "|" + fileName`, where `fileName` includes the `.dXXXXX` suffix,
/// making each item unique.
///
/// - `fileName`: name of the file in trash (includes `.dXXXXX`)
/// - `trashbinFileName`: original file name before deletion
/// - `trashbinOriginalLocation`: original path before deletion
/// - `classFile`: type of file (e.g. "image", "video", "document")
///
/// This model replaces the legacy `tableTrash` schema.
typealias tableTrash = tableTrashV2
class tableTrashV2: Object {
    // Primary key: unique per account + trash item
    @Persisted(primaryKey: true) var identifier: String

    @Persisted var account: String = ""
    @Persisted var classFile: String = ""
    @Persisted var contentType: String = ""
    @Persisted var date: Date = Date()
    @Persisted var directory: Bool = false
    @Persisted var fileId: String = ""
    @Persisted var fileName: String = ""
    @Persisted var filePath: String = ""
    @Persisted var hasPreview: Bool = false
    @Persisted var iconName: String = ""
    @Persisted var size: Int64 = 0
    @Persisted var trashbinFileName: String = ""
    @Persisted var trashbinOriginalLocation: String = ""
    @Persisted var trashbinDeletionTime: Date = Date()
}

extension NCManageDatabase {

    // MARK: - Realm write

    /// Adds a list of `NKTrash` items to the Realm database, associated with the given account.
    /// This function creates new `tableTrash` objects and inserts or updates them in the Realm, wrapped in an async write operation.
    /// - Parameters:
    ///   - account: The account string used to associate each trash item.
    ///   - items: An array of `NKTrash` items to be added to the database.
    func addTrashAsync(items: [NKTrash], account: String) async {
        let itemsFiltered = filterOutVideosMatchingImages(items)

        await core.performRealmWriteAsync { realm in

            // Delete all existing trash items for this account.
            let existingItems = realm.objects(tableTrash.self)
                .where { $0.account == account }
            realm.delete(existingItems)

            itemsFiltered.forEach { trash in
                let object = tableTrash()

                object.identifier = "\(account)|\(trash.fileName)"
                object.account = account
                object.contentType = trash.contentType
                object.date = trash.date
                object.directory = trash.directory
                object.fileId = trash.fileId
                object.fileName = trash.fileName
                object.filePath = trash.filePath
                object.hasPreview = trash.hasPreview
                object.iconName = trash.iconName
                object.size = trash.size
                object.trashbinDeletionTime = trash.trashbinDeletionTime
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

        core.performRealmWrite { realm in
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

        core.performRealmWrite { realm in
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

        await core.performRealmWriteAsync { realm in
            let results = realm.objects(tableTrash.self).filter(predicate)
            realm.delete(results)
        }
    }

    // MARK: - Realm read

    func getTableTrash(fileId: String, account: String) -> tableTrash? {
        core.performRealmRead { realm in
            realm.objects(tableTrash.self)
                .filter("account == %@ AND fileId == %@", account, fileId)
                .first
                .map { tableTrash(value: $0) }
        }
    }

    /// Asynchronously retrieves sorted trash results by filePath and account.
    /// - Returns: A `Results<tableTrash>` collection, or `nil` if Realm fails to open.
    func getTableTrashAsync(filePath: String, account: String) async -> [tableTrash] {
        await core.performRealmReadAsync { realm in
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
        await core.performRealmReadAsync { realm in
            return realm.objects(tableTrash.self)
                .filter("account == %@ AND fileId == %@", account, fileId)
                .first
                .map { tableTrash(value: $0) }
        }
    }

    // MARK: - helpers

    /// Filters out video items that have a matching image counterpart based on a shared trash suffix.
    ///
    /// This function is designed to handle Live Photo pairs in the trash, where both the image
    /// (e.g., `.jpg`) and the video (e.g., `.mov`) share the same suffix (e.g., `.d123456`).
    ///
    /// The logic works as follows:
    /// - Extract all suffixes from items classified as `image`.
    /// - Build a set of these suffixes for fast lookup.
    /// - Iterate through all items:
    ///   - Keep all non-video items.
    ///   - For video items, extract their suffix and check if it exists in the image suffix set.
    ///   - If a match is found, the video is considered part of a Live Photo pair and is excluded.
    ///
    /// - Parameter items: An array of `NKTrash` items to filter.
    /// - Returns: A filtered array where videos paired with images are removed.
    func filterOutVideosMatchingImages(_ items: [NKTrash]) -> [NKTrash] {
        // Collect suffixes from image items.
        let imageSuffixes: Set<String> = Set(
            items.compactMap { item in
                guard item.classFile == "image" else { return nil }
                return trashSuffix(from: item.fileName)
            }
        )

        // Remove videos whose suffix matches any image suffix.
        return items.filter { item in
            guard item.classFile == "video" else {
                return true
            }

            guard let suffix = trashSuffix(from: item.fileName) else {
                return true
            }

            return !imageSuffixes.contains(suffix)
        }
    }

    /// Extracts the suffix component from a trash file name.
    ///
    /// The suffix is defined as the substring after the last dot (`.`) in the file name.
    /// This is typically used to identify related files in the trash (e.g., Live Photo pairs),
    /// where files share a common suffix such as `d123456`.
    ///
    /// Examples:
    /// - `file.jpg.d123456` → `d123456`
    /// - `video.mov.d987654` → `d987654`
    ///
    /// If the file name does not contain a dot or the suffix is empty, the function returns `nil`.
    ///
    /// - Parameter fileName: The full file name string.
    /// - Returns: The extracted suffix, or `nil` if not available.
    func trashSuffix(from fileName: String) -> String? {
        guard let lastDot = fileName.lastIndex(of: ".") else {
            return nil
        }

        let suffix = String(fileName[fileName.index(after: lastDot)...])
        return suffix.isEmpty ? nil : suffix
    }
}
