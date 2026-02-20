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

    internal let core: NCManageDatabaseCore
    internal let utilityFileSystem = NCUtilityFileSystem()

    init() {
        let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup)
        let bundleUrl: URL = Bundle.main.bundleURL
        let bundlePathExtension: String = bundleUrl.pathExtension
        let isAppex: Bool = bundlePathExtension == "appex"

        self.core = NCManageDatabaseCore()

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
        let configuration = Realm.Configuration(fileURL: databaseFileUrl,
                                                schemaVersion: databaseSchemaVersion,
                                                migrationBlock: { migration, oldSchemaVersion in
            self.core.migrationSchema(migration, oldSchemaVersion)
        })
        Realm.Configuration.defaultConfiguration = configuration

        do {
            let realm = try Realm(configuration: configuration)
            if let url = realm.configuration.fileURL {
                nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .start, message: "Realm is located at: \(url.path)", consoleOnly: true)
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
                    nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .start, message: "Realm is located at: \(url.path)", consoleOnly: true)
                }
            } catch {
                nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .error, message: "Realm error: \(error)")
            }
        }
    }

    @discardableResult
    func openRealmBackground() -> Bool {
        let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup)
        let databaseFileUrl = dirGroup?.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud + "/" + databaseName)
        let configuration = Realm.Configuration(fileURL: databaseFileUrl,
                                                schemaVersion: databaseSchemaVersion,
                                                migrationBlock: { migration, oldSchemaVersion in
            self.core.migrationSchema(migration, oldSchemaVersion)
        })
        Realm.Configuration.defaultConfiguration = configuration

        do {
            let realm = try Realm(configuration: configuration)
            if let url = realm.configuration.fileURL {
                nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .start, message: "Realm is located at: \(url.path)", consoleOnly: true)
            }
            return true
        } catch {
            nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .error, message: "Realm error: \(error)")
            return false
        }
    }

    private func openRealmAppex() {
        guard let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup) else {
            return
        }
        let databaseFileUrl = dirGroup.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud + "/" + databaseName)
        let objectTypes = [
            NCKeyValue.self, tableMetadata.self, tableLocalFile.self,
            tableDirectory.self, tableTag.self, tableAccount.self,
            tableCapabilities.self, tableE2eEncryption.self, tableE2eEncryptionLock.self,
            tableE2eMetadata12.self, tableE2eMetadata.self, tableE2eUsers.self,
            tableE2eCounter.self, tableShare.self, tableChunk.self, tableAvatar.self,
            tableDashboardWidget.self, tableDashboardWidgetButton.self,
            NCDBLayoutForView.self, TableSecurityGuardDiagnostics.self, tableLivePhoto.self
        ]

        do {
            // Migration configuration
            let migrationCfg = Realm.Configuration(fileURL: databaseFileUrl,
                                                   schemaVersion: databaseSchemaVersion,
                                                   migrationBlock: { migration, oldSchemaVersion in
                self.core.migrationSchema(migration, oldSchemaVersion)
            })
            try autoreleasepool {
                _ = try Realm(configuration: migrationCfg)
            }

            // Runtime and default configuration
            let runtimeCfg = Realm.Configuration(fileURL: databaseFileUrl, schemaVersion: databaseSchemaVersion, objectTypes: objectTypes)
            Realm.Configuration.defaultConfiguration = runtimeCfg

            let realm = try Realm(configuration: runtimeCfg)
            if let url = realm.configuration.fileURL {
                nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .start, message: "Realm is located at: \(url.path)", consoleOnly: true)
            }
        } catch let error {
            nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .error, message: "Realm error: \(error)")
            isSuspendingDatabaseOperation = true
        }
    }

    // MARK: -

    /// Forces a Realm flush by refreshing the latest state from disk.
    /// This ensures that the current thread has the most recent version
    /// of all committed transactions.
    func flushRealmAsync() async {
        await withCheckedContinuation { continuation in
            core.realmQueue.async(qos: .utility) {
                autoreleasepool {
                    do {
                        let realm = try Realm()
                        _ = realm.refresh()
                    } catch {
                        nkLog(tag: NCGlobal.shared.logTagDatabase, emoji: .error, message: "Realm flush error: \(error)")
                    }
                    continuation.resume()
                }
            }
        }
    }

    func clearTable(_ table: Object.Type, account: String? = nil) {
        core.performRealmWrite { realm in
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
        await core.performRealmWriteAsync { realm in
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
        self.clearTable(tableExternalSites.self)
        self.clearTable(tableLivePhoto.self)
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
        self.clearTable(tableLivePhoto.self, account: account)
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
                    await self.deleteLocalFileAsync(id: ocId)
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

    func filterAndNormalizeLivePhotos(from metadatas: [tableMetadata]) -> [tableMetadata] {
        // Get all fileIds from the detached metadata list
        let allFileIds: Set<String> = Set(metadatas.map { $0.fileId })

        // Process based on classFile (image vs video) LivePhoto
        let cleanedMetadatas: [tableMetadata] = metadatas.compactMap { metadata in
            let livePhotoFileId = metadata.livePhotoFile
            let hasLivePhotoLink = !livePhotoFileId.isEmpty
            let targetExists = allFileIds.contains(livePhotoFileId)

            switch metadata.classFile {
            case NKTypeClassFile.image.rawValue:
                if hasLivePhotoLink,
                   !targetExists {
                    metadata.livePhotoFile = "" // Clear broken reference
                }
                return metadata

            case NKTypeClassFile.video.rawValue:
                if hasLivePhotoLink,
                   targetExists {
                    return nil // Remove video if it's paired with an existing image
                } else if hasLivePhotoLink,
                          !targetExists {
                    metadata.livePhotoFile = "" // Clear broken reference
                }
                return metadata

            default:
                return metadata
            }
        }

        return cleanedMetadatas
    }

    func filterAndNormalizeLivePhotos(from metadatas: [tableMetadata], completion: @escaping ([tableMetadata]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let normalized = self.filterAndNormalizeLivePhotos(from: metadatas)
            completion(normalized)
        }
    }

    /// Compacts the Realm database by writing a compacted copy and replacing the original.
    /// Must be called when no Realm instances are open.
    func compactRealm() throws {
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
                self.core.migrationSchema(migration, oldSchemaVersion)
            })
            Realm.Configuration.defaultConfiguration = configuration

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

    // MARK: -
    // MARK: SWIFTUI PREVIEW

    func createDBForPreview() async {
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
