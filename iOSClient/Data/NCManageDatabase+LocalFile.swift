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

    /// - Parameters:
    ///   - metadata: The `tableMetadata` containing file details.
    ///   - offline: Optional flag to mark the file as available offline.
    /// - Returns: Nothing. Realm write is performed asynchronously.
    func addLocalFileAsync(metadata: tableMetadata, offline: Bool? = nil) async {
        // Read (non-blocking): safely detach from Realm thread
        let existing: tableLocalFile? = performRealmRead { realm in
            realm.objects(tableLocalFile.self)
                .filter(NSPredicate(format: "ocId == %@", metadata.ocId))
                .first
                .map { tableLocalFile(value: $0) }
        }

        await performRealmWriteAsync { realm in
            let addObject = existing ?? tableLocalFile()

            addObject.account = metadata.account
            addObject.etag = metadata.etag
            addObject.exifDate = NSDate()
            addObject.exifLatitude = "-1"
            addObject.exifLongitude = "-1"
            addObject.ocId = metadata.ocId
            addObject.fileName = metadata.fileName

            if let offline {
                addObject.offline = offline
            }

            realm.add(addObject, update: .all)
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

    func deleteLocalFileOcIdAsync(_ ocId: String?) async {
        guard let ocId else { return }

        await performRealmWriteAsync { realm in
            let results = realm.objects(tableLocalFile.self)
                .filter("ocId == %@", ocId)
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

    func setLastOpeningDateAsync(metadata: tableMetadata) async {
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

    func getTableLocalFilesAsyncs(predicate: NSPredicate) async -> [tableLocalFile] {
        await performRealmReadAsync { realm in
            realm.objects(tableLocalFile.self)
                .filter(predicate)
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
                       dispatchOnMainQueue: Bool = true,
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

            if dispatchOnMainQueue {
                DispatchQueue.main.async(execute: deliver)
            } else {
                deliver()
            }
        }
    }

    func getTableLocalFiles(predicate: NSPredicate, sorted: String, ascending: Bool) -> [tableLocalFile] {
        return performRealmRead { realm in
            Array(
                realm.objects(tableLocalFile.self)
                    .filter(predicate)
                    .sorted(byKeyPath: sorted, ascending: ascending)
                    .map { tableLocalFile(value: $0) }
            )
        } ?? []
    }

    func getTableLocalFilesAsync(predicate: NSPredicate, sorted: String, ascending: Bool) async -> [tableLocalFile] {
        await performRealmReadAsync { realm in
            realm.objects(tableLocalFile.self)
                .filter(predicate)
                .sorted(byKeyPath: sorted, ascending: ascending)
                .map { tableLocalFile(value: $0) }
        } ?? []
    }

    func getResultTableLocalFile(ocId: String) -> tableLocalFile? {
        return performRealmRead { realm in
            realm.objects(tableLocalFile.self)
                .filter("ocId == %@", ocId)
                .first
        }
    }

    func getTableLocalFileAsync(ocId: String) async -> tableLocalFile? {
        await performRealmReadAsync { realm in
            realm.objects(tableLocalFile.self)
                .filter("ocId == %@", ocId)
                .first
                .map { tableLocalFile(value: $0) }
        }
    }
}
