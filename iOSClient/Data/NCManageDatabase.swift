//
//  NCManageDatabase.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/05/17.
//  Copyright © 2017 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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

import UIKit
import RealmSwift
import NextcloudKit
import CoreMedia
import Photos
import CommonCrypto

protocol DateCompareable {
    var dateKey: Date { get }
}

class NCManageDatabase: NSObject {
    @objc static let shared: NCManageDatabase = {
        let instance = NCManageDatabase()
        return instance
    }()
    let utilityFileSystem = NCUtilityFileSystem()

    override init() {
        func migrationSchema(_ migration: Migration, _ oldSchemaVersion: UInt64) {
            if oldSchemaVersion < 365 {
                migration.deleteData(forType: tableMetadata.className())
                migration.enumerateObjects(ofType: tableDirectory.className()) { _, newObject in
                    newObject?["etag"] = ""
                }
            }
            if oldSchemaVersion < 375 {
                // nothing
            }
        }

        func compactDB(_ totalBytes: Int, _ usedBytes: Int) -> Bool {
            let usedPercentage = (Double(usedBytes) / Double(totalBytes)) * 100
            /// Compact the database if more than 25% of the space is free
            let shouldCompact = (usedPercentage < 75.0) && (totalBytes > 100 * 1024 * 1024)

            return shouldCompact
        }
        var realm: Realm?
        let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup)
        let databaseFileUrlPath = dirGroup?.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud + "/" + databaseName)
        let bundleUrl: URL = Bundle.main.bundleURL
        let bundlePathExtension: String = bundleUrl.pathExtension
        let bundleFileName: String = (bundleUrl.path as NSString).lastPathComponent
        let isAppex: Bool = bundlePathExtension == "appex"
        var objectTypesAppex = [NCKeyValue.self,
                                tableMetadata.self,
                                tableLocalFile.self,
                                tableDirectory.self,
                                tableTag.self,
                                tableAccount.self,
                                tableCapabilities.self,
                                tablePhotoLibrary.self,
                                tableE2eEncryption.self,
                                tableE2eEncryptionLock.self,
                                tableE2eMetadata12.self,
                                tableE2eMetadata.self,
                                tableE2eUsers.self,
                                tableE2eCounter.self,
                                tableShare.self,
                                tableChunk.self,
                                tableAvatar.self,
                                tableDashboardWidget.self,
                                tableDashboardWidgetButton.self,
                                NCDBLayoutForView.self,
                                TableSecurityGuardDiagnostics.self]

        // Disable file protection for directory DB
        // https://docs.mongodb.com/realm/sdk/ios/examples/configure-and-open-a-realm/#std-label-ios-open-a-local-realm
        if let folderPathURL = dirGroup?.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud) {
            let folderPath = folderPathURL.path
            do {
                try FileManager.default.setAttributes([FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: folderPath)
            } catch {
                print("Dangerous error")
            }
        }

        if isAppex {
            if bundleFileName == "File Provider Extension.appex" {
                objectTypesAppex = [NCKeyValue.self,
                                    tableMetadata.self,
                                    tableLocalFile.self,
                                    tableDirectory.self,
                                    tableTag.self,
                                    tableAccount.self,
                                    tableCapabilities.self,
                                    tableE2eEncryption.self]
            }
            do {
                Realm.Configuration.defaultConfiguration =
                Realm.Configuration(fileURL: databaseFileUrlPath,
                                    schemaVersion: databaseSchemaVersion,
                                    migrationBlock: { migration, oldSchemaVersion in
                                        migrationSchema(migration, oldSchemaVersion)
                                    }, shouldCompactOnLaunch: { totalBytes, usedBytes in
                                        compactDB(totalBytes, usedBytes)
                                    }, objectTypes: objectTypesAppex)
                realm = try Realm()
                if let realm, let url = realm.configuration.fileURL {
                    print("Realm is located at: \(url)")
                }
            } catch let error {
                NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] DATABASE ERROR: \(error.localizedDescription)")
            }
        } else {
            do {
                Realm.Configuration.defaultConfiguration =
                Realm.Configuration(fileURL: databaseFileUrlPath,
                                    schemaVersion: databaseSchemaVersion,
                                    migrationBlock: { migration, oldSchemaVersion in
                                        migrationSchema(migration, oldSchemaVersion)
                                    }, shouldCompactOnLaunch: { totalBytes, usedBytes in
                                        compactDB(totalBytes, usedBytes)
                                    })
                realm = try Realm()
                if let realm, let url = realm.configuration.fileURL {
                    print("Realm is located at: \(url)")
                }
            } catch let error {
                NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] DATABASE ERROR: \(error.localizedDescription)")
            }
        }
    }

    // MARK: -
    // MARK: Utility Database

    func clearTable(_ table: Object.Type, account: String? = nil) {
        do {
            let realm = try Realm()
            try realm.write {
                var results: Results<Object>
                if let account = account {
                    results = realm.objects(table).filter("account == %@", account)
                } else {
                    results = realm.objects(table)
                }

                realm.delete(results)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func clearDatabase(account: String? = nil, removeAccount: Bool = false) {
        if removeAccount {
            self.clearTable(tableAccount.self, account: account)
        }

        self.clearTable(tableActivity.self, account: account)
        self.clearTable(tableActivityLatestId.self, account: account)
        self.clearTable(tableActivityPreview.self, account: account)
        self.clearTable(tableActivitySubjectRich.self, account: account)
        self.clearTable(tableAvatar.self)
        self.clearTable(tableCapabilities.self, account: account)
        self.clearTable(tableChunk.self, account: account)
        self.clearTable(tableComments.self, account: account)
        self.clearTable(tableDashboardWidget.self, account: account)
        self.clearTable(tableDashboardWidgetButton.self, account: account)
        self.clearTable(tableDirectEditingCreators.self, account: account)
        self.clearTable(tableDirectEditingEditors.self, account: account)
        self.clearTable(tableDirectory.self, account: account)
        self.clearTablesE2EE(account: account)
        self.clearTable(tableExternalSites.self, account: account)
        self.clearTable(tableGPS.self, account: nil)
        self.clearTable(TableGroupfolders.self, account: account)
        self.clearTable(TableGroupfoldersGroups.self, account: account)
        self.clearTable(tableLocalFile.self, account: account)
        self.clearTable(tableMetadata.self, account: account)
        self.clearTable(tablePhotoLibrary.self, account: account)
        self.clearTable(tableShare.self, account: account)
        self.clearTable(TableSecurityGuardDiagnostics.self, account: account)
        self.clearTable(tableTag.self, account: account)
        self.clearTable(tableTrash.self, account: account)
        self.clearTable(tableUserStatus.self, account: account)
        self.clearTable(tableVideo.self, account: account)
        self.clearTable(tableRecommendedFiles.self, account: account)
    }

    func clearTablesE2EE(account: String?) {
        self.clearTable(tableE2eEncryption.self, account: account)
        self.clearTable(tableE2eEncryptionLock.self, account: account)
        self.clearTable(tableE2eMetadata12.self, account: account)
        self.clearTable(tableE2eMetadata.self, account: account)
        self.clearTable(tableE2eUsers.self, account: account)
        self.clearTable(tableE2eCounter.self, account: account)
    }

    func getThreadConfined(_ object: Object) -> Any {
        return ThreadSafeReference(to: object)
    }

    func putThreadConfined(_ tableRef: ThreadSafeReference<Object>) -> Object? {
        do {
            let realm = try Realm()
            return realm.resolve(tableRef)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
        return nil
    }

    func realmRefresh() {
        do {
            let realm = try Realm()
            realm.refresh()
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not refresh database: \(error)")
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
    // MARK: SWIFTUI PREVIEW

    func previewCreateDB() {
        /// Account
        let account = "marinofaggiana https://cloudtest.nextcloud.com"
        let account2 = "mariorossi https://cloudtest.nextcloud.com"
        addAccount(account, urlBase: "https://cloudtest.nextcloud.com", user: "marinofaggiana", userId: "marinofaggiana", password: "password")
        addAccount(account2, urlBase: "https://cloudtest.nextcloud.com", user: "mariorossi", userId: "mariorossi", password: "password")
        let userProfile = NKUserProfile()
        userProfile.displayName = "Marino Faggiana"
        userProfile.address = "Hirschstrasse 26, 70192 Stuttgart, Germany"
        userProfile.phone = "+49 (711) 252 428 - 90"
        userProfile.email = "cloudtest@nextcloud.com"
        setAccountUserProfile(account: account, userProfile: userProfile)
        let userProfile2 = NKUserProfile()
        userProfile2.displayName = "Mario Rossi"
        userProfile2.email = "cloudtest@nextcloud.com"
        setAccountUserProfile(account: account2, userProfile: userProfile2)
    }
}

class NCKeyValue: Object {
    @Persisted var key: String = ""
    @Persisted var value: String?
}
