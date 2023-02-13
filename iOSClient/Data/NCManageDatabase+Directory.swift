//
//  NCManageDatabase+Directory.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 26/11/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
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
import RealmSwift
import NextcloudKit

class tableDirectory: Object {

    @objc dynamic var account = ""
    @objc dynamic var colorFolder: String?
    @objc dynamic var e2eEncrypted: Bool = false
    @objc dynamic var etag = ""
    @objc dynamic var favorite: Bool = false
    @objc dynamic var fileId = ""
    @objc dynamic var ocId = ""
    @objc dynamic var offline: Bool = false
    @objc dynamic var permissions = ""
    @objc dynamic var richWorkspace: String?
    @objc dynamic var serverUrl = ""

    override static func primaryKey() -> String {
        return "ocId"
    }
}

extension NCManageDatabase {

    func addDirectory(encrypted: Bool, favorite: Bool, ocId: String, fileId: String, etag: String? = nil, permissions: String? = nil, serverUrl: String, account: String) {

        let realm = try! Realm()

        do {
            try realm.write {
                var addObject = tableDirectory()
                let result = realm.objects(tableDirectory.self).filter("ocId == %@", ocId).first

                if result != nil {
                    addObject = result!
                } else {
                    addObject.ocId = ocId
                }

                addObject.account = account
                addObject.e2eEncrypted = encrypted
                addObject.favorite = favorite
                addObject.fileId = fileId
                if let etag = etag {
                    addObject.etag = etag
                }
                if let permissions = permissions {
                    addObject.permissions = permissions
                }
                addObject.serverUrl = serverUrl

                realm.add(addObject, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func deleteDirectoryAndSubDirectory(serverUrl: String, account: String) {

        let realm = try! Realm()

        let results = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl BEGINSWITH %@", account, serverUrl)

        // Delete table Metadata & LocalFile
        for result in results {

            self.deleteMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", result.account, result.serverUrl))
            self.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", result.ocId))
        }

        // Delete table Dirrectory
        do {
            try realm.write {
                realm.delete(results)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func setDirectory(serverUrl: String, serverUrlTo: String? = nil, etag: String? = nil, ocId: String? = nil, fileId: String? = nil, encrypted: Bool, richWorkspace: String? = nil, account: String) {

        let realm = try! Realm()

        do {
            try realm.write {

                guard let result = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).first else {
                    return
                }

                let directory = tableDirectory.init(value: result)

                realm.delete(result)

                directory.e2eEncrypted = encrypted
                if let etag = etag {
                    directory.etag = etag
                }
                if let ocId = ocId {
                    directory.ocId = ocId
                }
                if let fileId = fileId {
                    directory.fileId = fileId
                }
                if let serverUrlTo = serverUrlTo {
                    directory.serverUrl = serverUrlTo
                }
                if let richWorkspace = richWorkspace {
                    directory.richWorkspace = richWorkspace
                }

                realm.add(directory, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func getTableDirectory(predicate: NSPredicate) -> tableDirectory? {

        let realm = try! Realm()

        guard let result = realm.objects(tableDirectory.self).filter(predicate).first else {
            return nil
        }

        return tableDirectory.init(value: result)
    }

    func getTablesDirectory(predicate: NSPredicate, sorted: String, ascending: Bool) -> [tableDirectory]? {

        let realm = try! Realm()

        let results = realm.objects(tableDirectory.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)

        if results.count > 0 {
            return Array(results.map { tableDirectory.init(value: $0) })
        } else {
            return nil
        }
    }

    func renameDirectory(ocId: String, serverUrl: String) {

        let realm = try! Realm()

        do {
            try realm.write {
                let result = realm.objects(tableDirectory.self).filter("ocId == %@", ocId).first
                result?.serverUrl = serverUrl
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func setDirectory(serverUrl: String, offline: Bool, account: String) {

        let realm = try! Realm()

        do {
            try realm.write {
                let result = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).first
                result?.offline = offline
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    @discardableResult
    func setDirectory(serverUrl: String, richWorkspace: String?, account: String) -> tableDirectory? {

        let realm = try! Realm()
        var result: tableDirectory?

        do {
            try realm.write {
                result = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).first
                result?.richWorkspace = richWorkspace
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }

        if let result = result {
            return tableDirectory.init(value: result)
        } else {
            return nil
        }
    }

    @discardableResult
    func setDirectory(serverUrl: String, colorFolder: String?, account: String) -> tableDirectory? {

        let realm = try! Realm()
        var result: tableDirectory?

        do {
            try realm.write {
                result = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).first
                result?.colorFolder = colorFolder
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }

        if let result = result {
            return tableDirectory.init(value: result)
        } else {
            return nil
        }
    }
}
