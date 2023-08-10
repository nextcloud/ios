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

// MARK: -
// MARK: Table V1, V1.2

class tableE2eMetadata: Object {

    @Persisted(primaryKey: true) var serverUrl = ""
    @Persisted var account = ""
    @Persisted var metadataKey = ""
    @Persisted var version: Double = 0
}

// MARK: -
// MARK: Table V2

class tableE2eMetadataV2: Object {

    @Persisted(primaryKey: true) var accountServerUrl = ""
    @Persisted var keyChecksums = List<String>()
    @Persisted var folders = Map<String, String>()
    @Persisted var deleted: Bool = false
    @Persisted var counter: Int = 0
    @Persisted var version: String = "2.0"
}

class tableE2eUsersV2: Object {

    @Persisted(primaryKey: true) var accountServerUrlUserId = ""
    @Persisted var certificate = ""
    @Persisted var encryptedFiledropKey: String?
    @Persisted var encryptedMetadataKey: String?
    @Persisted var decryptedFiledropKey: Data?
    @Persisted var decryptedMetadataKey: Data?
    @Persisted var filedropKey: String?
    @Persisted var metadataKey: String?
    @Persisted var serverUrl = ""
    @Persisted var userId = ""
}

extension NCManageDatabase {

    // MARK: -
    // MARK: tableE2eEncryption

    @objc func addE2eEncryption(_ e2e: tableE2eEncryption) {

        do {
            let realm = try Realm()
            try realm.write {
                realm.add(e2e, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func deleteE2eEncryption(predicate: NSPredicate) {

        do {
            let realm = try Realm()
            try realm.write {
                let results = realm.objects(tableE2eEncryption.self).filter(predicate)
                realm.delete(results)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func getE2eEncryption(predicate: NSPredicate) -> tableE2eEncryption? {

        do {
            let realm = try Realm()
            realm.refresh()
            guard let result = realm.objects(tableE2eEncryption.self).filter(predicate).sorted(byKeyPath: "metadataKeyIndex", ascending: false).first else { return nil }
            return tableE2eEncryption.init(value: result)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not access database: \(error)")
        }

        return nil
    }

    @objc func getE2eEncryptions(predicate: NSPredicate) -> [tableE2eEncryption]? {

        guard self.getActiveAccount() != nil else { return nil }

        do {
            let realm = try Realm()
            realm.refresh()
            let results: Results<tableE2eEncryption>
            results = realm.objects(tableE2eEncryption.self).filter(predicate)
            if results.isEmpty {
                return nil
            } else {
                return Array(results.map { tableE2eEncryption.init(value: $0) })
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not access database: \(error)")
        }

        return nil
    }

    @objc func renameFileE2eEncryption(serverUrl: String, fileNameIdentifier: String, newFileName: String, newFileNamePath: String) {

        guard let activeAccount = self.getActiveAccount() else { return }

        do {
            let realm = try Realm()
            try realm.write {
                guard let result = realm.objects(tableE2eEncryption.self).filter("account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", activeAccount.account, serverUrl, fileNameIdentifier).first else { return }
                let object = tableE2eEncryption.init(value: result)
                realm.delete(result)
                object.fileName = newFileName
                object.fileNamePath = newFileNamePath
                realm.add(object)
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    // MARK: -
    // MARK: Table e2e Encryption Lock

    @objc func getE2ETokenLock(account: String, serverUrl: String) -> tableE2eEncryptionLock? {

        do {
            let realm = try Realm()
            realm.refresh()
            guard let result = realm.objects(tableE2eEncryptionLock.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).first else { return nil }
            return tableE2eEncryptionLock.init(value: result)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not access database: \(error)")
        }

        return nil
    }

    @objc func getE2EAllTokenLock(account: String) -> [tableE2eEncryptionLock] {

        do {
            let realm = try Realm()
            realm.refresh()
            let results = realm.objects(tableE2eEncryptionLock.self).filter("account == %@", account)
            if results.isEmpty {
                return []
            } else {
                return Array(results.map { tableE2eEncryptionLock.init(value: $0) })
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not access database: \(error)")
        }

        return []
    }

    @objc func setE2ETokenLock(account: String, serverUrl: String, fileId: String, e2eToken: String) {

        do {
            let realm = try Realm()
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

        do {
            let realm = try Realm()
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
    // MARK: V1

    func getE2eMetadata(account: String, serverUrl: String) -> tableE2eMetadata? {

        do {
            let realm = try Realm()
            realm.refresh()
            guard let result = realm.objects(tableE2eMetadata.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).first else { return nil }
            return tableE2eMetadata.init(value: result)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not access database: \(error)")
        }

        return nil
    }

    func setE2eMetadata(account: String, serverUrl: String, metadataKey: String, version: Double) {

        do {
            let realm = try Realm()
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

    // MARK: -
    // MARK: V2

    func setE2EUsersV2(account: String,
                       serverUrl: String,
                       userId: String,
                       certificate: String,
                       encryptedFiledropKey: String?,
                       encryptedMetadataKey: String?,
                       decryptedFiledropKey: Data?,
                       decryptedMetadataKey: Data?,
                       filedropKey: String?,
                       metadataKey: String?) {

        do {
            let realm = try Realm()
            try realm.write {
                let addObject = tableE2eUsersV2()
                addObject.accountServerUrlUserId = account + serverUrl + userId
                addObject.certificate = certificate
                addObject.encryptedFiledropKey = encryptedFiledropKey
                addObject.encryptedMetadataKey = encryptedMetadataKey
                addObject.decryptedFiledropKey = decryptedFiledropKey
                addObject.decryptedMetadataKey = decryptedMetadataKey
                addObject.filedropKey = filedropKey
                addObject.metadataKey = metadataKey
                addObject.serverUrl = serverUrl
                addObject.userId = userId
                realm.add(addObject, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func getE2EUsersV2(account: String, serverUrl: String, userId: String) -> tableE2eUsersV2? {

        do {
            let realm = try Realm()
            realm.refresh()
            return realm.objects(tableE2eUsersV2.self).filter("accountServerUrlUserId == %@", account + serverUrl + userId).first
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not access database: \(error)")
        }

        return nil
    }

    func deleteE2EUsersV2(account: String, serverUrl: String) {

        do {
            let realm = try Realm()
            try realm.write {
                let results = realm.objects(tableE2eEncryption.self).filter("account == %@ AND serverUrl == %@", account, serverUrl)
                realm.delete(results)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func getE2eMetadataV2(account: String, serverUrl: String) -> tableE2eMetadataV2? {

        do {
            let realm = try Realm()
            realm.refresh()
            return realm.objects(tableE2eMetadataV2.self).filter("accountServerUrl == %@", account + serverUrl).first
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not access database: \(error)")
        }

        return nil
    }

    func setE2eMetadataV2(account: String, serverUrl: String, keyChecksums: [String]?, deleted: Bool, counter: Int, folders: [String: String]?, version: String) {

        do {
            let realm = try Realm()
            try realm.write {
                let addObject = tableE2eMetadataV2()
                addObject.accountServerUrl = account + serverUrl
                if let keyChecksums {
                    addObject.keyChecksums.append(objectsIn: keyChecksums)
                }
                addObject.deleted = deleted
                addObject.counter = counter
                let foldersDictionary = addObject.folders
                if let folders {
                    for folder in folders {
                        foldersDictionary[folder.key] = folder.value
                    }
                }
                addObject.version = version
                realm.add(addObject, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func deleteE2eMetadataV2(account: String, serverUrl: String) {

        do {
            let realm = try Realm()
            try realm.write {
                let results = realm.objects(tableE2eMetadataV2.self).filter("accountServerUrl == %@", account + serverUrl)
                realm.delete(results)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }
}
