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
import UIKit
import RealmSwift
import NextcloudKit

class tableE2eEncryptionLock: Object {
    @Persisted(primaryKey: true) var fileId = ""
    @Persisted var account = ""
    @Persisted var date = Date()
    @Persisted var serverUrl = ""
    @Persisted var e2eToken = ""
}

typealias tableE2eEncryption = tableE2eEncryptionV4
class tableE2eEncryptionV4: Object {
    @Persisted(primaryKey: true) var primaryKey = ""
    @Persisted var account = ""
    @Persisted var authenticationTag: String = ""
    @Persisted var blob = "files"
    @Persisted var fileName = ""
    @Persisted var fileNameIdentifier = ""
    @Persisted var key = ""
    @Persisted var initializationVector = ""
    @Persisted var metadataKey = ""
    @Persisted var metadataKeyIndex: Int = 0
    @Persisted var version: String = ""
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

class tableE2eMetadata12: Object {
    @Persisted(primaryKey: true) var serverUrl = ""
    @Persisted var account = ""
    @Persisted var metadataKey = ""
    @Persisted var version: Double = 0
}

// MARK: -
// MARK: Table V2

typealias tableE2eMetadata = tableE2eMetadataV2
class tableE2eMetadataV2: Object {
    @Persisted(primaryKey: true) var primaryKey = ""
    @Persisted var account = ""
    @Persisted var deleted: Bool = false
    @Persisted var folders = Map<String, String>()
    @Persisted var keyChecksums = List<String>()
    @Persisted var ocIdServerUrl: String = ""
    @Persisted var serverUrl: String = ""
    @Persisted var version: String = NCGlobal.shared.e2eeVersionV20

    convenience init(account: String, ocIdServerUrl: String) {
        self.init()
        self.account = account
        self.ocIdServerUrl = ocIdServerUrl
        self.primaryKey = account + ocIdServerUrl
     }
}

class tableE2eCounter: Object {
    @Persisted(primaryKey: true) var primaryKey: String
    @Persisted var account: String
    @Persisted var counter: Int
    @Persisted var ocIdServerUrl: String

    convenience init(account: String, ocIdServerUrl: String, counter: Int) {
        self.init()
        self.account = account
        self.ocIdServerUrl = ocIdServerUrl
        self.primaryKey = account + ocIdServerUrl
        self.counter = counter
     }
}

class tableE2eUsers: Object {
    @Persisted(primaryKey: true) var primaryKey = ""
    @Persisted var account = ""
    @Persisted var certificate = ""
    @Persisted var encryptedMetadataKey: String?
    @Persisted var metadataKey: Data?
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
    func addE2eEncryptionAsync(_ object: tableE2eEncryption) async {
        await performRealmWriteAsync { realm in
            realm.add(object, update: .all)
        }
    }

    func deleteE2eEncryptionAsync(predicate: NSPredicate) async {
        await performRealmWriteAsync { realm in
            let results = realm.objects(tableE2eEncryption.self)
                .filter(predicate)
            realm.delete(results)
        }
    }

    func getE2eEncryption(predicate: NSPredicate) -> tableE2eEncryption? {
        performRealmRead { realm in
            realm.objects(tableE2eEncryption.self)
                .filter(predicate)
                .sorted(byKeyPath: "metadataKeyIndex", ascending: false)
                .first
                .map { tableE2eEncryption(value: $0) }
        }
    }

    func getE2eEncryptionAsync(predicate: NSPredicate) async -> tableE2eEncryption? {
        await performRealmReadAsync { realm in
            realm.objects(tableE2eEncryption.self)
                .filter(predicate)
                .first
                .map { tableE2eEncryption(value: $0) }
        }
    }

    func getE2eEncryptionsAsync(predicate: NSPredicate) async -> [tableE2eEncryption] {
        await performRealmReadAsync { realm in
            let results = realm.objects(tableE2eEncryption.self)
                .filter(predicate)
            return results.map { tableE2eEncryption(value: $0) }
        } ?? []
    }

    func renameFileE2eEncryptionAsync(account: String, serverUrl: String, fileNameIdentifier: String, newFileName: String, newFileNamePath: String) async {
        await performRealmWriteAsync { realm in
            guard let result = realm.objects(tableE2eEncryption.self)
                .filter("account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", account, serverUrl, fileNameIdentifier)
                .first else { return }

            result.fileName = newFileName

            realm.add(result, update: .all)
        }
    }
    // MARK: -
    // MARK: Table e2e Encryption Lock

    func getE2ETokenLockAsync(account: String, serverUrl: String) async -> tableE2eEncryptionLock? {
        await performRealmReadAsync { realm in
            realm.objects(tableE2eEncryptionLock.self)
                .filter("account == %@ AND serverUrl == %@", account, serverUrl)
                .first
                .map { tableE2eEncryptionLock(value: $0) }
        }
    }

    func getE2EAllTokenLockAsync(account: String) async -> [tableE2eEncryptionLock] {
        await performRealmReadAsync { realm in
            let results = realm.objects(tableE2eEncryptionLock.self)
                .filter("account == %@", account)
            return results.map { tableE2eEncryptionLock(value: $0) }
        } ?? []
    }

    func setE2ETokenLockAsync(account: String, serverUrl: String, fileId: String, e2eToken: String) async {
        await performRealmWriteAsync { realm in
            let object = tableE2eEncryptionLock()
            object.account = account
            object.fileId = fileId
            object.serverUrl = serverUrl
            object.e2eToken = e2eToken

            realm.add(object, update: .all)
        }
    }

    func deleteE2ETokenLockAsync(account: String, serverUrl: String) async {
        await performRealmWriteAsync { realm in
            let results = realm.objects(tableE2eEncryptionLock.self)
                .filter("account == %@ AND serverUrl == %@", account, serverUrl)
            realm.delete(results)
        }
    }

    // MARK: -
    // MARK: V1

    func getE2eMetadataAsync(account: String, serverUrl: String) async -> tableE2eMetadata12? {
        await performRealmReadAsync { realm in
            realm.objects(tableE2eMetadata12.self)
                .filter("account == %@ AND serverUrl == %@", account, serverUrl)
                .first
                .map { tableE2eMetadata12(value: $0) } // detached copy
        }
    }

    func setE2eMetadataAsync(account: String, serverUrl: String, metadataKey: String, version: Double) async {
        await performRealmWriteAsync { realm in
            let object = tableE2eMetadata12()
            object.account = account
            object.metadataKey = metadataKey
            object.serverUrl = serverUrl
            object.version = version
            realm.add(object, update: .all)
        }
    }

    // MARK: -
    // MARK: V2

    func addE2EUsersAsync(account: String,
                          serverUrl: String,
                          ocIdServerUrl: String,
                          userId: String,
                          certificate: String,
                          encryptedMetadataKey: String?,
                          metadataKey: Data?) async {
        await performRealmWriteAsync { realm in
            let object = tableE2eUsers(account: account, ocIdServerUrl: ocIdServerUrl, userId: userId)

            object.certificate = certificate
            object.encryptedMetadataKey = encryptedMetadataKey
            object.metadataKey = metadataKey
            object.serverUrl = serverUrl

            realm.add(object, update: .all)
        }
    }

    func deleteE2EUsersAsync(account: String, ocIdServerUrl: String, userId: String) async {
        await performRealmWriteAsync { realm in
            if let result = realm.objects(tableE2eUsers.self)
                .filter("account == %@ AND ocIdServerUrl == %@ AND userId == %@", account, ocIdServerUrl, userId)
                .first {
                realm.delete(result)
            }
        }
    }

    func getE2EUsersAsync(account: String, ocIdServerUrl: String) async -> [tableE2eUsers] {
        await performRealmReadAsync { realm in
            realm.objects(tableE2eUsers.self)
                .filter("account == %@ AND ocIdServerUrl == %@", account, ocIdServerUrl)
                .map { tableE2eUsers(value: $0) } // detached copy
        } ?? []
    }

    func getE2EUserAsync(account: String, ocIdServerUrl: String, userId: String) async -> tableE2eUsers? {
        await performRealmReadAsync { realm in
            realm.objects(tableE2eUsers.self)
                .filter("account == %@ AND ocIdServerUrl == %@ AND userId == %@", account, ocIdServerUrl, userId)
                .first
                .map { tableE2eUsers(value: $0) } // detached copy
        }
    }

    func getE2eMetadataAsync(account: String, ocIdServerUrl: String) async -> tableE2eMetadata? {
        await performRealmReadAsync { realm in
            realm.objects(tableE2eMetadata.self)
                .filter("account == %@ AND ocIdServerUrl == %@", account, ocIdServerUrl)
                .first
                .map { tableE2eMetadata(value: $0) } // detached copy
        }
    }

    func addE2eMetadataAsync(account: String,
                             serverUrl: String,
                             ocIdServerUrl: String,
                             keyChecksums: [String]?,
                             deleted: Bool,
                             folders: [String: String]?,
                             version: String) async {
        await performRealmWriteAsync { realm in
            let object = tableE2eMetadata(account: account, ocIdServerUrl: ocIdServerUrl)

            if let keyChecksums {
                object.keyChecksums.append(objectsIn: keyChecksums)
            }

            object.deleted = deleted

            if let folders {
                for (key, value) in folders {
                    object.folders[key] = value
                }
            }

            object.serverUrl = serverUrl
            object.version = version

            realm.add(object, update: .all)
        }
    }

    func updateCounterE2eMetadataAsync(account: String, ocIdServerUrl: String, counter: Int) async {
        await performRealmWriteAsync { realm in
            let object = tableE2eCounter(account: account, ocIdServerUrl: ocIdServerUrl, counter: counter)
            realm.add(object, update: .all)
        }
    }

    func getCounterE2eMetadataAsync(account: String, ocIdServerUrl: String) async -> Int? {
        await performRealmReadAsync { realm in
            realm.objects(tableE2eCounter.self)
                .filter("account == %@ AND ocIdServerUrl == %@", account, ocIdServerUrl)
                .first?
                .counter
        }
    }
}
