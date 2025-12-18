// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import RealmSwift
import NextcloudKit

// Global flag used to control Realm write/read operations
var isSuspendingDatabaseOperation: Bool = false

final class NCManageDatabaseCore {
    static let realmQueueKey = DispatchSpecificKey<Void>()

    let realmQueue: DispatchQueue

    init() {
        let queue = DispatchQueue(label: "com.nextcloud.realmQueue", qos: .userInitiated)
        queue.setSpecific(key: NCManageDatabaseCore.realmQueueKey, value: ())
        self.realmQueue = queue
    }

    func migrationSchema(_ migration: Migration, _ oldSchemaVersion: UInt64) {
        //
        // MANUAL MIGRATIONS (custom logic required)
        //

        if oldSchemaVersion < 390 {
            migration.enumerateObjects(ofType: tableCapabilities.className()) { oldObject, newObject in
                if let schema = oldObject?.objectSchema,
                   schema["jsondata"] != nil,
                   let oldData = oldObject?["jsondata"] as? Data {
                    newObject?["capabilities"] = oldData
                }
            }
        }

        if oldSchemaVersion < 393 {
            migration.enumerateObjects(ofType: tableMetadata.className()) { oldObject, newObject in
                if let schema = oldObject?.objectSchema,
                   schema["serveUrlFileName"] != nil,
                   let oldData = oldObject?["serveUrlFileName"] as? String {
                    newObject?["serverUrlFileName"] = oldData
                }
            }
        }

        if oldSchemaVersion < 373 {
            // Fix from version 6.2.5
        } else if oldSchemaVersion < 403 {
            migration.enumerateObjects(ofType: tableAccount.className()) { oldObject, newObject in
                let onlyNew = oldObject?["autoUploadOnlyNew"] as? Bool ?? false
                if onlyNew {
                    let oldDate = oldObject?["autoUploadOnlyNewSinceDate"] as? Date
                    newObject?["autoUploadSinceDate"] = oldDate
                } else {
                    newObject?["autoUploadSinceDate"] = nil
                }
            }
        }

        // AUTOMATIC MIGRATIONS (Realm handles these internally)
        if oldSchemaVersion < databaseSchemaVersion {
            migration.enumerateObjects(ofType: tableDirectory.className()) { _, newObject in
                newObject?["etag"] = ""
            }
        }
    }

    // MARK: - performRealmRead, performRealmWrite

    @discardableResult
    func performRealmRead<T>(_ block: @escaping (Realm) throws -> T?, sync: Bool = true, completion: ((T?) -> Void)? = nil) -> T? {
        // Skip execution if app is suspending
        guard !isSuspendingDatabaseOperation else {
            completion?(nil)
            return nil
        }
        let isOnRealmQueue = DispatchQueue.getSpecific(key: NCManageDatabaseCore.realmQueueKey) != nil

        if sync {
            if isOnRealmQueue {
                // Avoid deadlock if already inside the queue
                do {
                    let realm = try Realm()
                    return try block(realm)
                } catch {
                    nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .error, message: "Realm read error (sync, reentrant): \(error)")
                    return nil
                }
            } else {
                return realmQueue.sync {
                    do {
                        let realm = try Realm()
                        return try block(realm)
                    } catch {
                        nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .error, message: "Realm read error (sync): \(error)")
                        return nil
                    }
                }
            }
        } else {
            realmQueue.async(qos: .userInitiated, flags: .enforceQoS) {
                autoreleasepool {
                    do {
                        let realm = try Realm()
                        let result = try block(realm)
                        completion?(result)
                    } catch {
                        nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .error, message: "Realm read error (async): \(error)")
                        completion?(nil)
                    }
                }
            }
            return nil
        }
    }

    func performRealmWrite(sync: Bool = true, _ block: @escaping (Realm) throws -> Void) {
        // Skip execution if app is suspending
        guard !isSuspendingDatabaseOperation else {
            return
        }
        let isOnRealmQueue = DispatchQueue.getSpecific(key: NCManageDatabaseCore.realmQueueKey) != nil

        let executionBlock: @Sendable () -> Void = {
            autoreleasepool {
                do {
                    let realm = try Realm()
                    try realm.write {
                        try block(realm)
                    }
                } catch {
                    nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .error, message: "Realm write error: \(error)")
                }
            }
        }

        if sync {
            if isOnRealmQueue {
                // Avoid deadlock
                executionBlock()
            } else {
                realmQueue.sync(execute: executionBlock)
            }
        } else {
            realmQueue.async(qos: .userInitiated, flags: .enforceQoS, execute: executionBlock)
        }
    }

    // MARK: - performRealmRead async/await, performRealmWrite async/await

    func performRealmReadAsync<T>(_ block: @escaping (Realm) throws -> T?) async -> T? {
        // Skip execution if app is suspending
        guard !isSuspendingDatabaseOperation else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            realmQueue.async(qos: .userInitiated, flags: .enforceQoS) {
                autoreleasepool {
                    do {
                        let realm = try Realm()
                        let result = try block(realm)
                        continuation.resume(returning: result)
                    } catch {
                        nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .error, message: "Realm read async error: \(error)")
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }

    func performRealmWriteAsync(_ block: @escaping (Realm) throws -> Void) async {
        // Skip execution if app is suspending
        guard !isSuspendingDatabaseOperation else {
            return
        }

        await withCheckedContinuation { continuation in
            realmQueue.async(qos: .userInitiated, flags: .enforceQoS) {
                autoreleasepool {
                    do {
                        let realm = try Realm()
                        try realm.write {
                            try block(realm)
                        }
                    } catch {
                        nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .error, message: "Realm write async error: \(error)")
                    }
                    continuation.resume()
                }
            }
        }
    }
}

class NCKeyValue: Object {
    @Persisted var key: String = ""
    @Persisted var value: String?
}
