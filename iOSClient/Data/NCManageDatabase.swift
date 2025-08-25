// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2017 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit
import CoreMedia
import Photos
import CommonCrypto

protocol DateCompareable {
    var dateKey: Date { get }
}

final class NCManageDatabase: @unchecked Sendable {
    static let shared = NCManageDatabase()

    internal let utilityFileSystem = NCUtilityFileSystem()
    internal static let realmQueueKey = DispatchSpecificKey<Void>()
    internal let realmQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "com.nextcloud.realmQueue", qos: .userInitiated)
        queue.setSpecific(key: realmQueueKey, value: ())
        return queue
    }()

    init() {
        let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup)
        let bundleUrl: URL = Bundle.main.bundleURL
        let bundlePathExtension: String = bundleUrl.pathExtension
        let isAppex: Bool = bundlePathExtension == "appex"

        // Disable file protection for directory DB
        if let folderPathURL = dirGroup?.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud) {
            let folderPath = folderPathURL.path
            do {
                try FileManager.default.setAttributes([FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: folderPath)
            } catch {
                nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .error, message: "Realm directory setAttributes error: \(error)")
            }
        }

        // Open Realm
        if isAppex {
            self.openRealmAppex()
        }
    }

    // MARK: -

    func openRealm() {
        let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup)
        let databaseFileUrl = dirGroup?.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud + "/" + databaseName)

        Realm.Configuration.defaultConfiguration = Realm.Configuration(fileURL: databaseFileUrl,
                                                                       schemaVersion: databaseSchemaVersion,
                                                                       migrationBlock: { migration, oldSchemaVersion in
            self.migrationSchema(migration, oldSchemaVersion)
        })

        do {
            let realm = try Realm()
            if let url = realm.configuration.fileURL {
                nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .start, message: "Realm is located at: \(url.path)")
            }
        } catch let error {
            nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .error, message: "Realm open failed: \(error)")
            if let realmURL = databaseFileUrl {
                let filesToDelete = [
                    realmURL,
                    realmURL.appendingPathExtension("lock"),
                    realmURL.appendingPathExtension("note"),
                    realmURL.appendingPathExtension("management")
                ]

                for file in filesToDelete {
                    do {
                        try FileManager.default.removeItem(at: file)
                    } catch { }
                }
            }

            do {
                let realm = try Realm()
                if let url = realm.configuration.fileURL {
                    nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .start, message: "Realm is located at: \(url.path)")
                }
            } catch {
                nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .error, message: "Realm error: \(error)")
            }
        }
    }

    /// Force compacts the Realm database by writing a compacted copy and replacing the original.
    /// Must be called when no Realm instances are open.
    func forceCompactRealm() throws {
        nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .start, message: "Start Compact Realm")

        guard let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup) else {
            throw NSError(domain: "RealmMaintenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "App Group container URL not found"])
        }
        let url = dirGroup.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud + "/" + databaseName)
        let fileManager = FileManager.default
        let compactedURL = url.deletingLastPathComponent()
            .appendingPathComponent(url.lastPathComponent + ".compact.realm")
        let backupURL = url.appendingPathExtension("bak")

        // Write a compacted copy inside an autoreleasepool to ensure file handles are closed
        try autoreleasepool {
            let configuration = Realm.Configuration(fileURL: url,
                                                    schemaVersion: databaseSchemaVersion,
                                                    migrationBlock: { migration, oldSchemaVersion in
                self.migrationSchema(migration, oldSchemaVersion)
            })

            // Writes a compacted copy of the Realm to the given destination
            let realm = try Realm(configuration: configuration)
            try realm.writeCopy(toFile: compactedURL)
        }

        // Atomic-ish swap: old → .bak, compacted → original path
        if fileManager.fileExists(atPath: backupURL.path) {
            try? fileManager.removeItem(at: backupURL)
        }
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.moveItem(at: url, to: backupURL)
        }
        try fileManager.moveItem(at: compactedURL, to: url)
        try? fileManager.removeItem(at: backupURL)
    }

    func openRealmBackground() -> Bool {
        let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup)
        let databaseFileUrl = dirGroup?.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud + "/" + databaseName)

        // now you can read/write in Realm
        #if !EXTENSION
        isSuspendingDatabaseOperation = false
        #endif

        Realm.Configuration.defaultConfiguration = Realm.Configuration(fileURL: databaseFileUrl,
                                                                       schemaVersion: databaseSchemaVersion,
                                                                       migrationBlock: { migration, oldSchemaVersion in
            self.migrationSchema(migration, oldSchemaVersion)
        })

        do {
            let realm = try Realm()
            if let url = realm.configuration.fileURL {
                nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .start, message: "Realm is located at: \(url.path)")
            }
            return true
        } catch {
            nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .error, message: "Realm error: \(error)")
            return false
        }
    }

    private func openRealmAppex() {
        let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup)
        let databaseFileUrl = dirGroup?.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud + "/" + databaseName)
        let bundleUrl: URL = Bundle.main.bundleURL
        var objectTypes: [Object.Type]

        if bundleUrl.lastPathComponent == "File Provider Extension.appex" {
            objectTypes = [
                NCKeyValue.self, tableMetadata.self, tableLocalFile.self,
                tableDirectory.self, tableTag.self, tableAccount.self
            ]
        } else {
            objectTypes = [
                NCKeyValue.self, tableMetadata.self, tableLocalFile.self,
                tableDirectory.self, tableTag.self, tableAccount.self,
                tableCapabilities.self, tableE2eEncryption.self, tableE2eEncryptionLock.self,
                tableE2eMetadata12.self, tableE2eMetadata.self, tableE2eUsers.self,
                tableE2eCounter.self, tableShare.self, tableChunk.self, tableAvatar.self,
                tableDashboardWidget.self, tableDashboardWidgetButton.self,
                NCDBLayoutForView.self, TableSecurityGuardDiagnostics.self
            ]
        }

        let configuration = Realm.Configuration(fileURL: databaseFileUrl, schemaVersion: databaseSchemaVersion, objectTypes: objectTypes)

        realmQueue.async {
            do {
                Realm.Configuration.defaultConfiguration = configuration
                let realm = try Realm()
                if let url = realm.configuration.fileURL {
                    nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .start, message: "Realm is located at: \(url.path)")
                }
            } catch let error {
                nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .error, message: "Realm error: \(error)")
                exit(1)
            }
        }
    }

    func migrationSchema(_ migration: Migration, _ oldSchemaVersion: UInt64) {
        // MANUAL MIGRATIONS (custom logic required)
        if oldSchemaVersion < 365 {
            migration.deleteData(forType: tableMetadata.className())
            migration.enumerateObjects(ofType: tableDirectory.className()) { _, newObject in
                newObject?["etag"] = ""
            }
        }
        if oldSchemaVersion < 383 {
            migration.enumerateObjects(ofType: tableAccount.className()) { oldObject, newObject in
                if let oldDate = oldObject?["autoUploadSinceDate"] as? Date {
                    newObject?["autoUploadOnlyNewSinceDate"] = oldDate
                } else {
                    newObject?["autoUploadOnlyNewSinceDate"] = Date()
                }
                newObject?["autoUploadOnlyNew"] = true
            }
        }
        if oldSchemaVersion < 390 {
            migration.enumerateObjects(ofType: tableCapabilities.className()) { oldObject, newObject in
                if let oldData = oldObject?["jsondata"] as? Data {
                    newObject?["capabilities"] = oldData
                }
            }
        }
        if oldSchemaVersion < 393 {
            migration.enumerateObjects(ofType: tableMetadata.className()) { oldObject, newObject in
                if let oldData = oldObject?["serveUrlFileName"] as? String {
                    newObject?["serverUrlFileName"] = oldData
                }
            }
        }

        // AUTOMATIC MIGRATIONS (Realm handles these internally)
        if oldSchemaVersion < databaseSchemaVersion {
            // Realm automatically handles:
            // -> Added properties with default values or optionals
            // -> Removed properties
            // -> Schema reordering
        }
    }

    private func compactDB(_ totalBytes: Int, _ usedBytes: Int) -> Bool {
        let usedPercentage = (Double(usedBytes) / Double(totalBytes)) * 100
        // Compact the database if more than 25% of the space is free
        let shouldCompact = (usedPercentage < 75.0) && (totalBytes > 100 * 1024 * 1024)

        return shouldCompact
    }

    // MARK: - performRealmRead, performRealmWrite

    @discardableResult
    func performRealmRead<T>(_ block: @escaping (Realm) throws -> T?, sync: Bool = true, completion: ((T?) -> Void)? = nil) -> T? {
        // Skip execution if app is suspending
        #if !EXTENSION
        guard !isSuspendingDatabaseOperation else {
            completion?(nil)
            return nil
        }
        #endif
        let isOnRealmQueue = DispatchQueue.getSpecific(key: NCManageDatabase.realmQueueKey) != nil

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
            realmQueue.async {
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
        #if !EXTENSION
        guard !isSuspendingDatabaseOperation else {
            return
        }
        #endif
        let isOnRealmQueue = DispatchQueue.getSpecific(key: NCManageDatabase.realmQueueKey) != nil

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
            realmQueue.async(execute: executionBlock)
        }
    }

    // MARK: - performRealmRead async/await, performRealmWrite async/await

    func performRealmReadAsync<T>(_ block: @escaping (Realm) throws -> T?) async -> T? {
        // Skip execution if app is suspending
        #if !EXTENSION
        guard !isSuspendingDatabaseOperation else {
            return nil
        }
        #endif

        return await withCheckedContinuation { continuation in
            realmQueue.async {
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
        #if !EXTENSION
        if isSuspendingDatabaseOperation {
            return
        }
        #endif

        await withCheckedContinuation { continuation in
            realmQueue.async {
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

    // MARK: -

    func clearTable(_ table: Object.Type, account: String? = nil) {
        performRealmWrite { realm in
            var results: Results<Object>
            if let account = account {
                results = realm.objects(table).filter("account == %@", account)
            } else {
                results = realm.objects(table)
            }

            realm.delete(results)
        }
    }

    func clearTableAsync(_ table: Object.Type, account: String? = nil) async {
        await performRealmWriteAsync { realm in
            var results: Results<Object>
            if let account = account {
                results = realm.objects(table).filter("account == %@", account)
            } else {
                results = realm.objects(table)
            }

            realm.delete(results)
        }
    }

    func clearDBCache() {
        self.clearTable(tableAvatar.self)
        self.clearTable(tableChunk.self)
        self.clearTable(tableDirectory.self)
        self.clearTable(TableDownloadLimit.self)
        self.clearTable(tableLocalFile.self)
        self.clearTable(tableMetadata.self)
        self.clearTable(tableRecommendedFiles.self)
        self.clearTable(tableShare.self)
    }

    func clearDatabase(account: String) {
        self.clearTable(tableAccount.self, account: account)
        self.clearTable(tableActivity.self, account: account)
        self.clearTable(tableActivityLatestId.self, account: account)
        self.clearTable(tableActivityPreview.self, account: account)
        self.clearTable(tableActivitySubjectRich.self, account: account)
        self.clearTable(tableAutoUploadTransfer.self, account: account)
        self.clearTable(tableAvatar.self)
        self.clearTable(tableCapabilities.self, account: account)
        self.clearTable(tableChunk.self, account: account)
        self.clearTable(tableComments.self, account: account)
        self.clearTable(tableDashboardWidget.self, account: account)
        self.clearTable(tableDashboardWidgetButton.self, account: account)
        self.clearTable(tableDirectory.self, account: account)
        self.clearTable(TableDownloadLimit.self, account: account)
        self.clearTablesE2EE(account: account)
        self.clearTable(tableExternalSites.self, account: account)
        self.clearTable(tableGPS.self, account: nil)
        self.clearTable(TableGroupfolders.self, account: account)
        self.clearTable(TableGroupfoldersGroups.self, account: account)
        self.clearTable(NCDBLayoutForView.self, account: account)
        self.clearTable(tableLocalFile.self, account: account)
        self.clearTable(tableMetadata.self, account: account)
        self.clearTable(tableRecommendedFiles.self, account: account)
        self.clearTable(TableSecurityGuardDiagnostics.self, account: account)
        self.clearTable(tableShare.self, account: account)
        self.clearTable(tableTag.self, account: account)
        self.clearTable(tableTrash.self, account: account)
        self.clearTable(tableVideo.self, account: account)
        self.clearTable(NCKeyValue.self)
    }

    func clearTablesE2EE(account: String?) {
        self.clearTable(tableE2eEncryption.self, account: account)
        self.clearTable(tableE2eEncryptionLock.self, account: account)
        self.clearTable(tableE2eMetadata12.self, account: account)
        self.clearTable(tableE2eMetadata.self, account: account)
        self.clearTable(tableE2eUsers.self, account: account)
        self.clearTable(tableE2eCounter.self, account: account)
    }

    func cleanTablesOcIds(account: String, userId: String, urlBase: String) async {
        let metadatas = await getMetadatasAsync(predicate: NSPredicate(format: "account == %@", account))
        let directories = await getDirectoriesAsync(predicate: NSPredicate(format: "account == %@", account))
        let locals = await getTableLocalFilesAsync(predicate: NSPredicate(format: "account == %@", account))

        let metadatasOcIds = Set(metadatas.map { $0.ocId })
        let directoriesOcIds = Set(directories.map { $0.ocId })
        let localsOcIds = Set(locals.map { $0.ocId })

        let localMissingOcIds = localsOcIds.subtracting(metadatasOcIds)
        let directoriesMissingOcIds = directoriesOcIds.subtracting(metadatasOcIds)

        await withTaskGroup(of: Void.self) { group in
            for ocId in localMissingOcIds {
                group.addTask {
                    await self.deleteLocalFileOcIdAsync(ocId)
                    self.utilityFileSystem.removeFile(atPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId, userId: userId, urlBase: urlBase))
                }
            }
        }

        await withTaskGroup(of: Void.self) { group in
            for ocId in directoriesMissingOcIds {
                group.addTask {
                    await self.deleteDirectoryOcIdAsync(ocId)
                }
            }
        }
    }

    func getThreadConfined(_ object: Object) -> Any {
        return ThreadSafeReference(to: object)
    }

    func putThreadConfined(_ tableRef: ThreadSafeReference<Object>) -> Object? {
        do {
            let realm = try Realm()
            return realm.resolve(tableRef)
        } catch let error as NSError {
            nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .error, message: "Realm could not write to database: \(error)")
        }
        return nil
    }

    func realmRefresh() {
        realmQueue.sync {
            do {
                let realm = try Realm()
                realm.refresh()
            } catch let error as NSError {
                nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .error, message: "Realm could not refresh database: \(error)")
            }
        }
    }

    func sha256Hash(_ input: String) -> String {
        let data = Data(input.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    // MARK: -
    // MARK: Func T

    func fetchPagedResults<T: Object>(ofType type: T.Type, primaryKey: String, recordsPerPage: Int, pageNumber: Int, filter: NSPredicate? = nil, sortedByKeyPath: String? = nil, sortedAscending: Bool = true) -> Results<T>? {
        let startIndex = recordsPerPage * (pageNumber - 1)

        do {
            let realm = try Realm()
            var results = realm.objects(type)

            if let filter, let sortedByKeyPath {
                results = results.filter(filter).sorted(byKeyPath: sortedByKeyPath, ascending: sortedAscending)
            }

            guard startIndex < results.count else {
                return nil
            }
            let pagedResults = results.dropFirst(startIndex).prefix(recordsPerPage)
            let pagedResultsKeys = pagedResults.compactMap { $0.value(forKey: primaryKey) as? String }

            return realm.objects(type).filter("\(primaryKey) IN %@", Array(pagedResultsKeys))
        } catch {
            print("Error opening Realm: \(error)")
            return nil
        }
    }

    // MARK: -
    // MARK: Utils

    func sortedMetadata(layoutForView: NCDBLayoutForView?, account: String, metadatas: [tableMetadata]) async -> [tableMetadata] {
        let layout: NCDBLayoutForView = layoutForView ?? NCDBLayoutForView()
        let directoryOnTop = NCPreferences().getDirectoryOnTop(account: account)
        let favoriteOnTop = NCPreferences().getFavoriteOnTop(account: account)

        let sorted = metadatas.sorted { lhs, rhs in
            if favoriteOnTop, lhs.favorite != rhs.favorite {
                return lhs.favorite && !rhs.favorite
            }

            if directoryOnTop, lhs.directory != rhs.directory {
                return lhs.directory && !rhs.directory
            }

            switch layout.sort {
            case "fileName":
                let result = lhs.fileNameView.localizedStandardCompare(rhs.fileNameView)
                return layout.ascending ? result == .orderedAscending : result == .orderedDescending
            case "date":
                let lhsDate = lhs.date as Date
                let rhsDate = rhs.date as Date
                return layout.ascending ? lhsDate < rhsDate : lhsDate > rhsDate
            case "size":
                return layout.ascending ? lhs.size < rhs.size : lhs.size > rhs.size
            default:
                return true
            }
        }

        return Array(sorted)
    }

    // MARK: -
    // MARK: SWIFTUI PREVIEW

    func previewCreateDB() async {
        // Account
        let account = "marinofaggiana https://cloudtest.nextcloud.com"
        let account2 = "mariorossi https://cloudtest.nextcloud.com"
        await addAccountAsync(account, urlBase: "https://cloudtest.nextcloud.com", user: "marinofaggiana", userId: "marinofaggiana", password: "password")
        await addAccountAsync(account2, urlBase: "https://cloudtest.nextcloud.com", user: "mariorossi", userId: "mariorossi", password: "password")
        let userProfile = NKUserProfile()
        userProfile.displayName = "Marino Faggiana"
        userProfile.address = "Hirschstrasse 26, 70192 Stuttgart, Germany"
        userProfile.phone = "+49 (711) 252 428 - 90"
        userProfile.email = "cloudtest@nextcloud.com"
        await setAccountUserProfileAsync(account: account, userProfile: userProfile)
        let userProfile2 = NKUserProfile()
        userProfile2.displayName = "Mario Rossi"
        userProfile2.email = "cloudtest@nextcloud.com"
        await setAccountUserProfileAsync(account: account2, userProfile: userProfile2)
    }
}

class NCKeyValue: Object {
    @Persisted var key: String = ""
    @Persisted var value: String?
}
