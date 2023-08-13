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

    @Persisted(primaryKey: true) var fileId = ""
    @Persisted var account = ""
    @Persisted var date = Date()
    @Persisted var serverUrl = ""
    @Persisted var e2eToken = ""
}

class tableE2eEncryption: Object {

    @Persisted(primaryKey: true) var primaryKey = ""
    @Persisted var account = ""
    @Persisted var authenticationTag: String = ""
    @Persisted var blob = "files"
    @Persisted var fileName = ""
    @Persisted var fileNameIdentifier = ""
    @Persisted var key = ""
    @Persisted var initializationVector = ""
    @Persisted var metadataKey = ""
    @Persisted var metadataKeyFiledrop = ""
    @Persisted var metadataKeyIndex: Int = 0
    @Persisted var metadataVersion: Double = 0
    @Persisted var mimeType = ""
    @Persisted var ocIdServerUrl: String = ""
    @Persisted var serverUrl = ""

    convenience init(account: String, ocIdServerUrl: String, fileNameIdentifier: String) {
        self.init()
        self.primaryKey = account + ocIdServerUrl + fileNameIdentifier
        self.account = account
        self.ocIdServerUrl = ocIdServerUrl
        self.fileNameIdentifier = fileNameIdentifier
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

    @Persisted(primaryKey: true) var primaryKey = ""
    @Persisted var account = ""
    @Persisted var counter: Int = 0
    @Persisted var deleted: Bool = false
    @Persisted var folders = Map<String, String>()
    @Persisted var keyChecksums = List<String>()
    @Persisted var ocIdServerUrl: String = ""
    @Persisted var serverUrl: String = ""
    @Persisted var version: String = "2.0"

    convenience init(account: String, ocIdServerUrl: String) {
        self.init()
        self.account = account
        self.ocIdServerUrl = ocIdServerUrl
        self.primaryKey = account + ocIdServerUrl
     }
}

class tableE2eUsersV2: Object {

    @Persisted(primaryKey: true) var primaryKey = ""
    @Persisted var account = ""
    @Persisted var certificate = ""
    @Persisted var encryptedFiledropKey: String?
    @Persisted var encryptedMetadataKey: String?
    @Persisted var decryptedFiledropKey: Data?
    @Persisted var decryptedMetadataKey: Data?
    @Persisted var filedropKey: String?
    @Persisted var metadataKey: String?
    @Persisted var ocIdServerUrl: String = ""
    @Persisted var serverUrl: String = ""
    @Persisted var userId = ""

    convenience init(account: String, ocIdServerUrl: String, userId: String) {
        self.init()
        self.primaryKey = account + ocIdServerUrl + userId
        self.account = account
        self.ocIdServerUrl = ocIdServerUrl
        self.userId = userId
     }
}

extension NCManageDatabase {

    // MARK: -
    // MARK: tableE2eEncryption

    @objc func addE2eEncryption(_ object: tableE2eEncryption) {

        do {
            let realm = try Realm()
            try realm.write {
                realm.add(object, update: .all)
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

    @objc func getE2eEncryptions(predicate: NSPredicate) -> [tableE2eEncryption] {

        do {
            let realm = try Realm()
            realm.refresh()
            let results: Results<tableE2eEncryption>
            results = realm.objects(tableE2eEncryption.self).filter(predicate)
            return Array(results.map { tableE2eEncryption.init(value: $0) })
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not access database: \(error)")
        }

        return []
    }

    @objc func renameFileE2eEncryption(account: String, serverUrl: String, fileNameIdentifier: String, newFileName: String, newFileNamePath: String) {

        do {
            let realm = try Realm()
            realm.refresh()
            try realm.write {
                guard let result = realm.objects(tableE2eEncryption.self).filter("account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", account, serverUrl, fileNameIdentifier).first else { return }
                result.fileName = newFileName
                realm.add(result, update: .all)
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
                let object = tableE2eEncryptionLock()
                object.account = account
                object.fileId = fileId
                object.serverUrl = serverUrl
                object.e2eToken = e2eToken
                realm.add(object, update: .all)
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
                let object = tableE2eMetadata()
                object.account = account
                object.metadataKey = metadataKey
                object.serverUrl = serverUrl
                object.version = version
                realm.add(object, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    // MARK: -
    // MARK: V2

    func addE2EUsersV2(account: String,
                       serverUrl: String,
                       ocIdServerUrl: String,
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
                let object = tableE2eUsersV2.init(account: account, ocIdServerUrl: ocIdServerUrl, userId: userId)
                object.certificate = certificate
                object.encryptedFiledropKey = encryptedFiledropKey
                object.encryptedMetadataKey = encryptedMetadataKey
                object.decryptedFiledropKey = decryptedFiledropKey
                object.decryptedMetadataKey = decryptedMetadataKey
                object.filedropKey = filedropKey
                object.metadataKey = metadataKey
                object.serverUrl = serverUrl
                realm.add(object, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func getE2EUsersV2(account: String, ocIdServerUrl: String) -> Results<tableE2eUsersV2>? {

        do {
            let realm = try Realm()
            realm.refresh()
            return realm.objects(tableE2eUsersV2.self).filter("account == %@ AND ocIdServerUrl == %@", account, ocIdServerUrl)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not access database: \(error)")
        }

        return nil
    }

    func getE2EUsersV2(account: String, ocIdServerUrl: String, userId: String) -> tableE2eUsersV2? {

        do {
            let realm = try Realm()
            realm.refresh()
            return realm.objects(tableE2eUsersV2.self).filter("account == %@ && ocIdServerUrl == %@ AND userId == %@", account, ocIdServerUrl, userId).first
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not access database: \(error)")
        }

        return nil
    }

    func getE2eMetadataV2(account: String, ocIdServerUrl: String) -> tableE2eMetadataV2? {

        do {
            let realm = try Realm()
            realm.refresh()
            return realm.objects(tableE2eMetadataV2.self).filter("account == %@ && ocIdServerUrl == %@", account, ocIdServerUrl).first
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not access database: \(error)")
        }

        return nil
    }

    func incrementCounterE2eMetadataV2(account: String, serverUrl: String, ocIdServerUrl: String, version: String) -> tableE2eMetadataV2? {

        do {
            let realm = try Realm()
            try realm.write {
                if let result = realm.objects(tableE2eMetadataV2.self).filter("account == %@ && ocIdServerUrl == %@", account, ocIdServerUrl).first {
                    result.counter += 1
                } else {
                    let object = tableE2eMetadataV2.init(account: account, ocIdServerUrl: ocIdServerUrl)
                    object.serverUrl = serverUrl
                    object.counter = 1
                    object.version = version
                    realm.add(object, update: .all)
                }
            }
            return realm.objects(tableE2eMetadataV2.self).filter("account == %@ && ocIdServerUrl == %@", account, ocIdServerUrl).first
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }

        return nil
    }

    func addE2eMetadataV2(account: String, serverUrl: String, ocIdServerUrl: String, keyChecksums: [String]?, deleted: Bool, counter: Int, folders: [String: String]?, version: String) {

        do {
            let realm = try Realm()
            try realm.write {
                let object = tableE2eMetadataV2.init(account: account, ocIdServerUrl: ocIdServerUrl)
                if let keyChecksums {
                    object.keyChecksums.append(objectsIn: keyChecksums)
                }
                object.deleted = deleted
                object.counter = counter
                let foldersDictionary = object.folders
                if let folders {
                    for folder in folders {
                        foldersDictionary[folder.key] = folder.value
                    }
                }
                object.serverUrl = serverUrl
                object.version = version
                realm.add(object, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }
}
