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
        let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup)
        let databaseFileUrlPath = dirGroup?.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud + "/" + databaseName)

        if let databaseFilePath = databaseFileUrlPath?.path {
            if FileManager.default.fileExists(atPath: databaseFilePath) {
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] DATABASE FOUND in " + databaseFilePath)
            } else {
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] DATABASE NOT FOUND in " + databaseFilePath)
            }
        }

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

        do {
            _ = try Realm(configuration: Realm.Configuration(
                fileURL: databaseFileUrlPath,
                schemaVersion: databaseSchemaVersion,
                migrationBlock: { migration, oldSchemaVersion in
                    if oldSchemaVersion < 354 {
                        migration.deleteData(forType: NCDBLayoutForView.className())
                    }
                }, shouldCompactOnLaunch: { totalBytes, usedBytes in
                    // totalBytes refers to the size of the file on disk in bytes (data + free space)
                    // usedBytes refers to the number of bytes used by data in the file
                    // Compact if the file is over 100MB in size and less than 50% 'used'
                    let oneHundredMB = 100 * 1024 * 1024
                    return (totalBytes > oneHundredMB) && (Double(usedBytes) / Double(totalBytes)) < 0.5
                }
            ))
        } catch let error {
            if let databaseFileUrlPath = databaseFileUrlPath {
                do {
#if !EXTENSION
                    let nkError = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: error.localizedDescription)
                    NCContentPresenter().showError(error: nkError, priority: .max)
#endif
                    NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] DATABASE ERROR: \(error.localizedDescription)")
                    try FileManager.default.removeItem(at: databaseFileUrlPath)
                } catch {}
            }
        }

        Realm.Configuration.defaultConfiguration = Realm.Configuration(
            fileURL: dirGroup?.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud + "/" + databaseName),
            schemaVersion: databaseSchemaVersion
        )

        // Verify Database, if corrupt remove it
        do {
            _ = try Realm()
        } catch let error {
            if let databaseFileUrlPath = databaseFileUrlPath {
                do {
#if !EXTENSION
                    let nkError = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: error.localizedDescription)
                    NCContentPresenter().showError(error: nkError, priority: .max)
#endif
                    NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] DATABASE ERROR: \(error.localizedDescription)")
                    try FileManager.default.removeItem(at: databaseFileUrlPath)
                } catch { }
            }
        }

        do {
            _ = try Realm()
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not open database: \(error)")
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

    func clearDatabase(account: String?, removeAccount: Bool) {
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
    }

    func clearTablesE2EE(account: String?) {
        self.clearTable(tableE2eEncryption.self, account: account)
        self.clearTable(tableE2eEncryptionLock.self, account: account)
        self.clearTable(tableE2eMetadata12.self, account: account)
        self.clearTable(tableE2eMetadata.self, account: account)
        self.clearTable(tableE2eUsers.self, account: account)
        self.clearTable(tableE2eCounter.self, account: account)
    }

    @objc func removeDB() {
        let realmURL = Realm.Configuration.defaultConfiguration.fileURL!
        let realmURLs = [
            realmURL,
            realmURL.appendingPathExtension("lock"),
            realmURL.appendingPathExtension("note"),
            realmURL.appendingPathExtension("management")
        ]

        for URL in realmURLs {
            do {
                try FileManager.default.removeItem(at: URL)
            } catch let error {
                NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
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
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
        return nil
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
        NCManageDatabase.shared.addAccount(account, urlBase: "https://cloudtest.nextcloud.com", user: "marinofaggiana", userId: "marinofaggiana", password: "password")
        NCManageDatabase.shared.addAccount(account2, urlBase: "https://cloudtest.nextcloud.com", user: "mariorossi", userId: "mariorossi", password: "password")
        let userProfile = NKUserProfile()
        userProfile.displayName = "Marino Faggiana"
        userProfile.address = "Hirschstrasse 26, 70192 Stuttgart, Germany"
        userProfile.phone = "+49 (711) 252 428 - 90"
        userProfile.email = "cloudtest@nextcloud.com"
        NCManageDatabase.shared.setAccountUserProfile(account: account, userProfile: userProfile)
        let userProfile2 = NKUserProfile()
        userProfile2.displayName = "Mario Rossi"
        userProfile2.email = "cloudtest@nextcloud.com"
        NCManageDatabase.shared.setAccountUserProfile(account: account2, userProfile: userProfile2)
    }
}
