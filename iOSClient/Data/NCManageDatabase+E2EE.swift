//
//  NCManageDatabase+E2EE.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 23/01/23.
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
import RealmSwift
import NextcloudKit
import SwiftyJSON

class tableE2eEncryption: Object {

    @objc dynamic var account = ""
    @objc dynamic var authenticationTag: String = ""
    @objc dynamic var blob = "files"
    @objc dynamic var fileName = ""
    @objc dynamic var fileNameIdentifier = ""
    @objc dynamic var fileNamePath = ""
    @objc dynamic var key = ""
    @objc dynamic var initializationVector = ""
    @objc dynamic var metadataKey = ""
    @objc dynamic var metadataKeyFiledrop = ""
    @objc dynamic var metadataKeyIndex: Int = 0
    @objc dynamic var metadataVersion: Double = 0
    @objc dynamic var mimeType = ""
    @objc dynamic var serverUrl = ""

    override static func primaryKey() -> String {
        return "fileNamePath"
    }
}

class tableE2eEncryptionLock: Object {

    @objc dynamic var account = ""
    @objc dynamic var date = NSDate()
    @objc dynamic var fileId = ""
    @objc dynamic var serverUrl = ""
    @objc dynamic var e2eToken = ""

    override static func primaryKey() -> String {
        return "fileId"
    }
}

class tableE2eMetadata: Object {

    @Persisted(primaryKey: true) var serverUrl = ""
    @Persisted var account = ""
    @Persisted var metadataKey = ""
    @Persisted var version: Double = 0
}

extension NCManageDatabase {

    // MARK: -
    // MARK: Table e2e Encryption

    @objc func addE2eEncryption(_ e2e: tableE2eEncryption) {

        let realm = try! Realm()

        do {
            try realm.write {
                realm.add(e2e, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func deleteE2eEncryption(predicate: NSPredicate) {

        let realm = try! Realm()

        do {
            try realm.write {

                let results = realm.objects(tableE2eEncryption.self).filter(predicate)
                realm.delete(results)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func getE2eEncryption(predicate: NSPredicate) -> tableE2eEncryption? {

        let realm = try! Realm()

        guard let result = realm.objects(tableE2eEncryption.self).filter(predicate).sorted(byKeyPath: "metadataKeyIndex", ascending: false).first else {
            return nil
        }

        return tableE2eEncryption.init(value: result)
    }

    @objc func getE2eEncryptions(predicate: NSPredicate) -> [tableE2eEncryption]? {

        guard self.getActiveAccount() != nil else {
            return nil
        }

        let realm = try! Realm()

        let results: Results<tableE2eEncryption>

        results = realm.objects(tableE2eEncryption.self).filter(predicate)

        if results.count > 0 {
            return Array(results.map { tableE2eEncryption.init(value: $0) })
        } else {
            return nil
        }
    }

    @objc func renameFileE2eEncryption(serverUrl: String, fileNameIdentifier: String, newFileName: String, newFileNamePath: String) {

        guard let activeAccount = self.getActiveAccount() else {
            return
        }

        let realm = try! Realm()

        realm.beginWrite()

        guard let result = realm.objects(tableE2eEncryption.self).filter("account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", activeAccount.account, serverUrl, fileNameIdentifier).first else {
            realm.cancelWrite()
            return
        }

        let object = tableE2eEncryption.init(value: result)

        realm.delete(result)

        object.fileName = newFileName
        object.fileNamePath = newFileNamePath

        realm.add(object)

        do {
            try realm.commitWrite()
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    // MARK: -
    // MARK: Table e2e Encryption Lock

    @objc func getE2ETokenLock(account: String, serverUrl: String) -> tableE2eEncryptionLock? {

        let realm = try! Realm()

        guard let result = realm.objects(tableE2eEncryptionLock.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).first else {
            return nil
        }

        return tableE2eEncryptionLock.init(value: result)
    }

    @objc func getE2EAllTokenLock(account: String) -> [tableE2eEncryptionLock] {

        let realm = try! Realm()

        let results = realm.objects(tableE2eEncryptionLock.self).filter("account == %@", account)

        if results.count > 0 {
            return Array(results.map { tableE2eEncryptionLock.init(value: $0) })
        } else {
            return []
        }
    }

    @objc func setE2ETokenLock(account: String, serverUrl: String, fileId: String, e2eToken: String) {

        let realm = try! Realm()

        do {
            try realm.write {
                let addObject = tableE2eEncryptionLock()

                addObject.account = account
                addObject.fileId = fileId
                addObject.serverUrl = serverUrl
                addObject.e2eToken = e2eToken

                realm.add(addObject, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func deleteE2ETokenLock(account: String, serverUrl: String) {

        let realm = try! Realm()

        do {
            try realm.write {
                if let result = realm.objects(tableE2eEncryptionLock.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).first {
                    realm.delete(result)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    // MARK: -
    // MARK: Table e2ee Metadata

    func getE2eMetadata(account: String, serverUrl: String) -> tableE2eMetadata? {

        let realm = try! Realm()

        guard let result = realm.objects(tableE2eMetadata.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).first else {
            return nil
        }

        return tableE2eMetadata.init(value: result)
    }

    func setE2eMetadata(account: String, serverUrl: String, metadataKey: String, version: Double) {

        let realm = try! Realm()

        do {
            try realm.write {
                let addObject = tableE2eMetadata()

                addObject.account = account
                addObject.metadataKey = metadataKey
                addObject.serverUrl = serverUrl
                addObject.version = version

                realm.add(addObject, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }
}
