// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

extension NCManageDatabase {

    // MARK: - Automatic backup/restore accounts

    /// Asynchronously backs up all `tableAccount` entries with non-empty passwords to a JSON file inside the app group container.
    /// If Realm initialization or access crashes, the error is logged and the operation is aborted safely.
    func backupTableAccountToFileAsync() async {
        guard let groupDirectory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup) else {
            nkLog(error: "App group directory not found")
            return
        }

        let backupDirectory = groupDirectory.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud)
        let fileURL = backupDirectory.appendingPathComponent(tableAccountBackup)

        await withCheckedContinuation { continuation in
            core.realmQueue.async {
                autoreleasepool {
                    do {
                        try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

                        let realm = try Realm()

                        var codableObjects: [tableAccountCodable] = []

                        for tblAccount in realm.objects(tableAccount.self) {
                            let account = tblAccount.account
                            if account.isEmpty { continue }

                            let password = NCPreferences().getPassword(account: account)
                            if !password.isEmpty {
                                codableObjects.append(tblAccount.tableAccountToCodable())
                            }
                        }

                        if !codableObjects.isEmpty {
                            let encoder = JSONEncoder()
                            encoder.outputFormatting = .prettyPrinted
                            let jsonData = try encoder.encode(codableObjects)
                            try jsonData.write(to: fileURL)
                        }

                    } catch {
                        nkLog(error: "Failed to backup tableAccount: \(error)")
                    }

                    continuation.resume()
                }
            }
        }
    }

    func restoreTableAccountFromFile() {
        let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup)
        guard let fileURL = dirGroup?.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud + "/" + tableAccountBackup) else {
            return
        }

        nkLog(debug: "Trying to restore account from backup...")

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            return
        }

        do {
            let realm = try Realm()
            let jsonData = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let codableObjects = try decoder.decode([tableAccountCodable].self, from: jsonData)

            try realm.write {
                for codableObject in codableObjects {
                    if !NCPreferences().getPassword(account: codableObject.account).isEmpty {
                        let tableAccount = tableAccount(codableObject: codableObject)
                        realm.add(tableAccount, update: .all)
                    }
                }
            }

            nkLog(debug: "Account restored successfully")
        } catch {
            nkLog(error: "Account restore error: \(error)")
        }
    }

    // MARK: - Realm write

    func addAccountAsync(_ account: String, urlBase: String, user: String, userId: String, password: String) async {
        await core.performRealmWriteAsync { realm in
            if let existing = realm.object(ofType: tableAccount.self, forPrimaryKey: account) {
                realm.delete(existing)
            }

            // Save password in Keychain
            NCPreferences().setPassword(account: account, password: password)

            let newAccount = tableAccount()

            newAccount.account = account
            newAccount.urlBase = urlBase
            newAccount.user = user
            newAccount.userId = userId

            realm.add(newAccount, update: .all)
        }
    }

    /// Asynchronously updates a specific property of a `tableAccount` object identified by account name.
    /// - Parameters:
    ///   - keyPath: A writable key path to the property to modify.
    ///   - value: The new value to assign to the property.
    ///   - account: The account identifier.
    func updateAccountPropertyAsync<T>(_ keyPath: ReferenceWritableKeyPath<tableAccount, T>, value: T, account: String) async {
        await core.performRealmWriteAsync { realm in
            guard let original = realm.objects(tableAccount.self)
                .filter("account == %@", account)
                .first else {
                return
            }

            // Clone and update
            let detached = tableAccount(value: original)
            detached[keyPath: keyPath] = value

            // Persist update
            realm.add(detached, update: .all)
        }
    }

    func setAccountAliasAsync(_ account: String, alias: String) async {
        let alias = alias.trimmingCharacters(in: .whitespacesAndNewlines)

        await core.performRealmWriteAsync { realm in
            if let result = realm.objects(tableAccount.self).filter("account == %@", account).first {
                result.alias = alias
            }
        }
    }

    @discardableResult
    func setAccountActiveAsync(_ account: String) async -> tableAccount? {
        var tblAccount: tableAccount?

        await core.performRealmWriteAsync { realm in
            let results = realm.objects(tableAccount.self)
            for result in results {
                if result.account == account {
                    result.active = true
                    tblAccount = tableAccount(value: result)
                } else {
                    result.active = false
                }
            }
        }
        return tblAccount
    }

    func setAccountAutoUploadFileNameAsync(_ fileName: String) async {
        await core.performRealmWriteAsync { realm in
            if let result = realm.objects(tableAccount.self).filter("active == true").first {
                result.autoUploadFileName = fileName
            }
        }
    }

    func setAccountAutoUploadDirectoryAsync(_ serverUrl: String, session: NCSession.Session) async {
        await core.performRealmWriteAsync { realm in
            if let result = realm.objects(tableAccount.self)
                .filter("active == true")
                .first {
                result.autoUploadDirectory = serverUrl
            }
        }
    }

    /// Asynchronously sets the user profile properties for a specific account in the Realm database.
    /// - Parameters:
    ///   - account: The account identifier.
    ///   - userProfile: A `NKUserProfile` instance containing updated user profile data.
    ///   - async: Whether the Realm write should be executed asynchronously (default is true).
    func setAccountUserProfileAsync(account: String, userProfile: NKUserProfile) async {
        await core.performRealmWriteAsync { realm in
            if let result = realm.objects(tableAccount.self)
                .filter("account == %@", account)
                .first {
                result.address = userProfile.address
                result.backend = userProfile.backend
                result.backendCapabilitiesSetDisplayName = userProfile.backendCapabilitiesSetDisplayName
                result.backendCapabilitiesSetPassword = userProfile.backendCapabilitiesSetPassword
                result.displayName = userProfile.displayName
                result.email = userProfile.email
                result.enabled = userProfile.enabled
                result.groups = userProfile.groups.joined(separator: ",")
                result.language = userProfile.language
                result.lastLogin = userProfile.lastLogin
                result.locale = userProfile.locale
                result.organisation = userProfile.organisation
                result.phone = userProfile.phone
                result.quota = userProfile.quota
                result.quotaFree = userProfile.quotaFree
                result.quotaRelative = userProfile.quotaRelative
                result.quotaTotal = userProfile.quotaTotal
                result.quotaUsed = userProfile.quotaUsed
                result.storageLocation = userProfile.storageLocation
                result.subadmin = userProfile.subadmin.joined(separator: ",")
                result.twitter = userProfile.twitter
                result.userId = userProfile.userId
                result.website = userProfile.website
            }
        }
    }

    func setAccountMediaPathAsync(_ path: String, account: String) async {
        await core.performRealmWriteAsync { realm in
            if let result = realm.objects(tableAccount.self).filter("account == %@", account).first {
                result.mediaPath = path
            }
        }
    }

    func setAccountUserStatusAsync(userStatusClearAt: Date?,
                                   userStatusIcon: String?,
                                   userStatusMessage: String?,
                                   userStatusMessageId: String?,
                                   userStatusMessageIsPredefined: Bool,
                                   userStatusStatus: String?,
                                   userStatusStatusIsUserDefined: Bool,
                                   account: String) async {
        await core.performRealmWriteAsync { realm in
            if let result = realm.objects(tableAccount.self)
                .filter("account == %@", account)
                .first {
                result.userStatusClearAt = userStatusClearAt as NSDate?
                result.userStatusIcon = userStatusIcon
                result.userStatusMessage = userStatusMessage
                result.userStatusMessageId = userStatusMessageId
                result.userStatusMessageIsPredefined = userStatusMessageIsPredefined
                result.userStatusStatus = userStatusStatus
                result.userStatusStatusIsUserDefined = userStatusStatusIsUserDefined
            }
        }
    }
    // MARK: - Realm Read

    func getTableAccount(predicate: NSPredicate) -> tableAccount? {
        core.performRealmRead { realm in
            realm.objects(tableAccount.self)
                .filter(predicate)
                .first
                .map { tableAccount(value: $0) }
        }
    }

    /// Asynchronously retrieves the first `tableAccount` matching the given predicate.
    /// - Parameter predicate: The NSPredicate used to filter the `tableAccount` objects.
    /// - Returns: A copy of the first matching `tableAccount`, or `nil` if none is found.
    func getTableAccountAsync(predicate: NSPredicate) async -> tableAccount? {
        await core.performRealmReadAsync { realm in
            realm.objects(tableAccount.self)
                .filter(predicate)
                .first
                .map { tableAccount(value: $0) }
        }
    }

    /// Asynchronously retrieves `tableAccount` matching the given predicate.
    /// - Parameter predicate: The NSPredicate used to filter the `tableAccount` objects.
    /// - Returns: A copy of matching `tableAccount`, or `nil` if none is found.
    func getTableAccountsAsync(predicate: NSPredicate) async -> [tableAccount] {
        await core.performRealmReadAsync { realm in
            realm.objects(tableAccount.self)
                .filter(predicate)
                .sorted(byKeyPath: "active", ascending: false)
                .map { tableAccount(value: $0) }
        } ?? []
    }

    func getAllTableAccount() -> [tableAccount] {
        core.performRealmRead { realm in
            let sorted = [SortDescriptor(keyPath: "active", ascending: false),
                          SortDescriptor(keyPath: "user", ascending: true)]
            let results = realm.objects(tableAccount.self)
                        .sorted(by: sorted)
            return results.map { tableAccount(value: $0) }
        } ?? []
    }

    func getAllTableAccountAsync() async -> [tableAccount] {
        await core.performRealmReadAsync { realm in
            let sorted = [
                SortDescriptor(keyPath: "active", ascending: false),
                SortDescriptor(keyPath: "user", ascending: true)
            ]
            let results = realm.objects(tableAccount.self)
                               .sorted(by: sorted)
            return results.map { tableAccount(value: $0) } // detached copy
        } ?? []
    }

    func getAllAccountOrderAlias() -> [tableAccount] {
        core.performRealmRead { realm in
            let sorted = [SortDescriptor(keyPath: "active", ascending: false),
                          SortDescriptor(keyPath: "alias", ascending: true),
                          SortDescriptor(keyPath: "user", ascending: true)]
            let results = realm.objects(tableAccount.self).sorted(by: sorted)
            return results.map { tableAccount(value: $0) }
        } ?? []
    }

    /// Reads all accounts ordered by active descending, alias ascending, and user ascending.
    func getAllAccountOrderAliasAsync() async -> [tableAccount] {
        await core.performRealmReadAsync { realm in
            let sorted = [
                SortDescriptor(keyPath: "active", ascending: false),
                SortDescriptor(keyPath: "alias", ascending: true),
                SortDescriptor(keyPath: "user", ascending: true)
            ]
            let results = realm.objects(tableAccount.self).sorted(by: sorted)
            return results.map { tableAccount(value: $0) }
        } ?? []
    }

    func getAccountAutoUploadFileName(account: String) -> String {
        return core.performRealmRead { realm in
            guard let result = realm.objects(tableAccount.self)
                .filter("account == %@", account)
                .first
            else {
                return NCBrandOptions.shared.folderDefaultAutoUpload
            }
            return result.autoUploadFileName.isEmpty ? NCBrandOptions.shared.folderDefaultAutoUpload : result.autoUploadFileName
        } ?? NCBrandOptions.shared.folderDefaultAutoUpload
    }

    func getAccountAutoUploadFileNameAsync(account: String) async -> String {
        let result: String? = await core.performRealmReadAsync { realm in
            guard let record = realm.objects(tableAccount.self)
                .filter("account == %@", account)
                .first
            else {
                return nil
            }

            return record.autoUploadFileName.isEmpty ? nil : record.autoUploadFileName
        }

        return result ?? NCBrandOptions.shared.folderDefaultAutoUpload
    }

    func getAccountAutoUploadDirectory(account: String, urlBase: String, userId: String) -> String {
        let homeServer = utilityFileSystem.getHomeServer(urlBase: urlBase, userId: userId)

        return core.performRealmRead { realm in
            realm.objects(tableAccount.self)
                .filter("account == %@", account)
                .first?
                .autoUploadDirectory
        }.flatMap { directory in
            (directory.isEmpty || directory.contains("/webdav")) ? homeServer : directory
        } ?? homeServer
    }

    func getAccountAutoUploadDirectoryAsync(account: String, urlBase: String, userId: String) async -> String {
        let homeServer = utilityFileSystem.getHomeServer(urlBase: urlBase, userId: userId)

        let directory: String? = await core.performRealmReadAsync { realm in
            realm.objects(tableAccount.self)
                .filter("account == %@", account)
                .first?
                .autoUploadDirectory
        }

        return directory.flatMap { dir in
            (dir.isEmpty || dir.contains("/webdav")) ? homeServer : dir
        } ?? homeServer
    }

    func getAccountAutoUploadServerUrlBase(session: NCSession.Session) -> String {
        return getAccountAutoUploadServerUrlBase(account: session.account, urlBase: session.urlBase, userId: session.userId)
    }

    func getAccountAutoUploadServerUrlBaseAsync(session: NCSession.Session) async -> String {
        return await getAccountAutoUploadServerUrlBaseAsync(account: session.account, urlBase: session.urlBase, userId: session.userId)
    }

    func getAccountAutoUploadServerUrlBase(account: String, urlBase: String, userId: String) -> String {
        let cameraFileName = self.getAccountAutoUploadFileName(account: account)
        let cameraDirectory = self.getAccountAutoUploadDirectory(account: account, urlBase: urlBase, userId: userId)
        let folderPhotos = utilityFileSystem.createServerUrl(serverUrl: cameraDirectory, fileName: cameraFileName)
        return folderPhotos
    }

    func getAccountAutoUploadServerUrlBaseAsync(account: String, urlBase: String, userId: String) async -> String {
        let cameraFileName = await self.getAccountAutoUploadFileNameAsync(account: account)
        let cameraDirectory = await self.getAccountAutoUploadDirectoryAsync(account: account, urlBase: urlBase, userId: userId)
        let folderPhotos = utilityFileSystem.createServerUrl(serverUrl: cameraDirectory, fileName: cameraFileName)
        return folderPhotos
    }

    func getAccountAutoUploadSubfolderGranularity() -> Int {
        core.performRealmRead { realm in
            realm.objects(tableAccount.self)
                .filter("active == true")
                .first?
                .autoUploadSubfolderGranularity
        } ?? NCGlobal.shared.subfolderGranularityMonthly
    }

    func getAccountAutoUploadSubfolderGranularityAsync() async -> Int {
        await core.performRealmReadAsync { realm in
            realm.objects(tableAccount.self)
                .filter("active == true")
                .first?
                .autoUploadSubfolderGranularity
        } ?? NCGlobal.shared.subfolderGranularityMonthly
    }

    func getActiveTableAccount() -> tableAccount? {
        core.performRealmRead { realm in
            realm.objects(tableAccount.self)
                .filter("active == true")
                .first
                .map { tableAccount(value: $0) }
        }
    }

    func getActiveTableAccountAsync() async -> tableAccount? {
        await core.performRealmReadAsync { realm in
            realm.objects(tableAccount.self)
                .filter("active == true")
                .first
                .map { tableAccount(value: $0) }
        }
    }

    func getTableAccount(account: String) -> tableAccount? {
        core.performRealmRead { realm in
            realm.objects(tableAccount.self)
                .filter("account == %@", account)
                .first
                .map { tableAccount(value: $0) }
        }
    }

    func getTableAccountAsync(account: String) async -> tableAccount? {
        await core.performRealmReadAsync { realm in
            realm.objects(tableAccount.self)
                .filter("account == %@", account)
                .first
                .map { tableAccount(value: $0) }
        }
    }

    func getAccounts() -> [String]? {
        core.performRealmRead { realm in
            let results = realm.objects(tableAccount.self)
                .sorted(byKeyPath: "account", ascending: true)
            return results.map { $0.account }
        }
    }

    func getAccountsAsync() async -> [String]? {
        await core.performRealmReadAsync { realm in
            realm.objects(tableAccount.self)
                .sorted(byKeyPath: "account", ascending: true)
                .map { $0.account }
        }
    }

    func getAccountGroups(account: String) -> [String] {
        return core.performRealmRead { realm in
            return realm.objects(tableAccount.self)
                .filter("account == %@", account)
                .first?
                .groups
                .components(separatedBy: ",") ?? []
        } ?? []
    }
}
