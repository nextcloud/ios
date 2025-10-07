// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

class tableLocalFile: Object {
    @objc dynamic var account = ""
    @objc dynamic var etag = ""
    @objc dynamic var exifDate: NSDate?
    @objc dynamic var exifLatitude = ""
    @objc dynamic var exifLongitude = ""
    @objc dynamic var exifLensModel: String?
    @objc dynamic var favorite: Bool = false
    @objc dynamic var fileName = ""
    @objc dynamic var ocId = ""
    @objc dynamic var offline: Bool = false
    @objc dynamic var lastOpeningDate = NSDate()

    override static func primaryKey() -> String {
        return "ocId"
    }
}

extension NCManageDatabase {

    // MARK: - Realm Write

    /// Adds or updates multiple local file entries corresponding to the given metadata array.
    /// Uses async Realm read + single write transaction. Assumes `tableLocalFile` has a primary key.
    /// - Parameters:
    ///   - metadatas: Array of `tableMetadata` to map into `tableLocalFile`.
    ///   - offline: Optional override for the `offline` flag applied to all items.
    func addLocalFilesAsync(metadatas: [tableMetadata], offline: Bool? = nil) async {
        guard !metadatas.isEmpty else {
            return
        }

        // Extract ocIds for efficient lookup
        let ocIds = metadatas.compactMap { $0.ocId }
        guard !ocIds.isEmpty else {
            return
        }

        // Preload existing entries to avoid creating duplicates
        let existingMap: [String: tableLocalFile] = await performRealmReadAsync { realm in
                let existing = realm.objects(tableLocalFile.self)
                    .filter(NSPredicate(format: "ocId IN %@", ocIds))
                return Dictionary(uniqueKeysWithValues:
                    existing.map { ($0.ocId, tableLocalFile(value: $0)) } // detached copy via value init
                )
            } ?? [:]

        await performRealmWriteAsync { realm in
            for metadata in metadatas {
                // Reuse existing object or create a new one
                let local = existingMap[metadata.ocId] ?? tableLocalFile()

                local.account = metadata.account
                local.etag = metadata.etag
                local.exifDate = NSDate()
                local.exifLatitude = "-1"
                local.exifLongitude = "-1"
                local.ocId = metadata.ocId
                local.fileName = metadata.fileName

                if let offline {
                    local.offline = offline
                }

                realm.add(local, update: .all)
            }
        }
    }

    func addLocalFile(account: String, etag: String, ocId: String, fileName: String) {
        performRealmWrite { realm in
           let addObject = tableLocalFile()
           addObject.account = account
           addObject.etag = etag
           addObject.exifDate = NSDate()
           addObject.exifLatitude = "-1"
           addObject.exifLongitude = "-1"
           addObject.ocId = ocId
           addObject.fileName = fileName
           realm.add(addObject, update: .all)
       }
    }

    func deleteLocalFileAsync(id: String?) async {
        guard let id else { return }

        await performRealmWriteAsync { realm in
            let results = realm.objects(tableLocalFile.self)
                .filter("ocId == %@", id)
            realm.delete(results)
        }
    }

    func setLocalFile(ocId: String, exifDate: NSDate?, exifLatitude: String, exifLongitude: String, exifLensModel: String?) {
        performRealmWrite { realm in
            if let result = realm.objects(tableLocalFile.self)
                .filter("ocId == %@", ocId)
                .first {
                result.exifDate = exifDate
                result.exifLatitude = exifLatitude
                result.exifLongitude = exifLongitude
                if let lensModel = exifLensModel, !lensModel.isEmpty {
                    result.exifLensModel = lensModel
                }
            }
        }
    }

    func setOffLocalFileAsync(ocId: String) async {
        await performRealmWriteAsync { realm in
            if let result = realm.objects(tableLocalFile.self)
                .filter("ocId == %@", ocId)
                .first {
                result.offline = false
            }
        }
    }

    func setLocalFileLastOpeningDateAsync(metadata: tableMetadata) async {
        await performRealmWriteAsync { realm in
            if let result = realm.objects(tableLocalFile.self)
                .filter("ocId == %@", metadata.ocId)
                .first {
                result.lastOpeningDate = NSDate()
            } else {
                let addObject = tableLocalFile()
                addObject.account = metadata.account
                addObject.etag = metadata.etag
                addObject.exifDate = NSDate()
                addObject.exifLatitude = "-1"
                addObject.exifLongitude = "-1"
                addObject.ocId = metadata.ocId
                addObject.fileName = metadata.fileName
                realm.add(addObject, update: .all)
            }
        }
    }

    // MARK: - Realm Read

    func getTableLocalFilesAsync(predicate: NSPredicate, sorted: String = "fileName", ascending: Bool = true) async -> [tableLocalFile] {
        await performRealmReadAsync { realm in
            realm.objects(tableLocalFile.self)
                .filter(predicate)
                .sorted(byKeyPath: sorted, ascending: ascending)
                .map { tableLocalFile(value: $0) }
        } ?? []
    }

    func getTableLocalFile(predicate: NSPredicate) -> tableLocalFile? {
        return performRealmRead { realm in
            realm.objects(tableLocalFile.self)
                .filter(predicate)
                .first
                .map { tableLocalFile(value: $0) }
        }
    }

    func getTableLocalFileAsync(predicate: NSPredicate) async -> tableLocalFile? {
        await performRealmReadAsync { realm in
            realm.objects(tableLocalFile.self)
                .filter(predicate)
                .first
                .map { tableLocalFile(value: $0) }
        }
    }

    func getTableLocal(predicate: NSPredicate,
                       completion: @escaping (_ localFile: tableLocalFile?) -> Void) {
        performRealmRead({ realm in
            return realm.objects(tableLocalFile.self)
                .filter(predicate)
                .first
        }, sync: false) { result in
            let detachedResult = result.map { tableLocalFile(value: $0) }
            let deliver: () -> Void = {
                completion(detachedResult)
            }

            DispatchQueue.main.async(execute: deliver)
        }
    }

    func getResultTableLocalFile(ocId: String) -> tableLocalFile? {
        return performRealmRead { realm in
            realm.objects(tableLocalFile.self)
                .filter("ocId == %@", ocId)
                .first
        }
    }
}
