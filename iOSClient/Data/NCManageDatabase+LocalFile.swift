//
//  NCManageDatabase+LocalFile.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 01/08/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

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
    // MARK: -
    // MARK: Table LocalFile - return RESULT
    func getTableLocalFile(ocId: String) -> tableLocalFile? {
        do {
            let realm = try Realm()
            return realm.objects(tableLocalFile.self).filter("ocId == %@", ocId).first
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    // MARK: -
    // MARK: Table LocalFile

    func addLocalFile(metadata: tableMetadata, offline: Bool? = nil) {
        do {
            let realm = try Realm()
            try realm.write {
                let addObject = getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) ?? tableLocalFile()
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
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func addLocalFile(account: String, etag: String, ocId: String, fileName: String) {
        do {
            let realm = try Realm()
            try realm.write {
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
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func deleteLocalFileOcId(_ ocId: String?) {
        guard let ocId else { return }

        do {
            let realm = try Realm()
            try realm.write {
                let results = realm.objects(tableLocalFile.self).filter("ocId == %@", ocId)
                realm.delete(results)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func setLocalFile(ocId: String, fileName: String?) {
        do {
            let realm = try Realm()
            try realm.write {
                let result = realm.objects(tableLocalFile.self).filter("ocId == %@", ocId).first
                if let fileName {
                    result?.fileName = fileName
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    @objc func setLocalFile(ocId: String, exifDate: NSDate?, exifLatitude: String, exifLongitude: String, exifLensModel: String?) {
        do {
            let realm = try Realm()
            try realm.write {
                if let result = realm.objects(tableLocalFile.self).filter("ocId == %@", ocId).first {
                    result.exifDate = exifDate
                    result.exifLatitude = exifLatitude
                    result.exifLongitude = exifLongitude
                    if exifLensModel?.count ?? 0 > 0 {
                        result.exifLensModel = exifLensModel
                    }
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func setOffLocalFile(ocId: String) {
        do {
            let realm = try Realm()
            try realm.write {
                let result = realm.objects(tableLocalFile.self).filter("ocId == %@", ocId).first
                result?.offline = false
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func getTableLocalFile(account: String) -> [tableLocalFile] {
        do {
            let realm = try Realm()
            let results = realm.objects(tableLocalFile.self).filter("account == %@", account)
            return Array(results.map { tableLocalFile.init(value: $0) })
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return []
    }

    func getTableLocalFile(predicate: NSPredicate) -> tableLocalFile? {
        do {
            let realm = try Realm()
            guard let result = realm.objects(tableLocalFile.self).filter(predicate).first else { return nil }
            return tableLocalFile.init(value: result)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getResultsTableLocalFile(predicate: NSPredicate) -> Results<tableLocalFile>? {
        do {
            let realm = try Realm()
            return realm.objects(tableLocalFile.self).filter(predicate)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getTableLocalFiles(predicate: NSPredicate, sorted: String, ascending: Bool) -> [tableLocalFile] {
        do {
            let realm = try Realm()
            let results = realm.objects(tableLocalFile.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)
            return Array(results.map { tableLocalFile.init(value: $0) })
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return []
    }

    func getResultsTableLocalFile(predicate: NSPredicate, sorted: String, ascending: Bool) -> Results<tableLocalFile>? {
        do {
            let realm = try Realm()
            return realm.objects(tableLocalFile.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func setLastOpeningDate(metadata: tableMetadata) {
        do {
            let realm = try Realm()
            try realm.write {
                if let result = realm.objects(tableLocalFile.self).filter("ocId == %@", metadata.ocId).first {
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
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }
}
