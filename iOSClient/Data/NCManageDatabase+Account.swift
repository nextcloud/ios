// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

class tableAccount: Object {
    @objc dynamic var account = ""
    @objc dynamic var active: Bool = false
    @objc dynamic var address = ""
    @objc dynamic var alias = ""
    @objc dynamic var autoUploadCreateSubfolder: Bool = false
    @objc dynamic var autoUploadSubfolderGranularity: Int = NCGlobal.shared.subfolderGranularityMonthly
    @objc dynamic var autoUploadDirectory = ""
    @objc dynamic var autoUploadFileName = ""
    @objc dynamic var autoUploadStart: Bool = false
    @objc dynamic var autoUploadImage: Bool = false
    @objc dynamic var autoUploadVideo: Bool = false
    @objc dynamic var autoUploadWWAnPhoto: Bool = false
    @objc dynamic var autoUploadWWAnVideo: Bool = false
    @objc dynamic var autoUploadOnlyNew: Bool = true
    @objc dynamic var autoUploadOnlyNewSinceDate: Date = Date()
    @objc dynamic var backend = ""
    @objc dynamic var backendCapabilitiesSetDisplayName: Bool = false
    @objc dynamic var backendCapabilitiesSetPassword: Bool = false
    @objc dynamic var displayName = ""
    @objc dynamic var email = ""
    @objc dynamic var enabled: Bool = false
    @objc dynamic var groups = ""
    @objc dynamic var language = ""
    @objc dynamic var lastLogin: Int64 = 0
    @objc dynamic var locale = ""
    @objc dynamic var mediaPath = ""
    @objc dynamic var organisation = ""
    @objc dynamic var phone = ""
    @objc dynamic var quota: Int64 = 0
    @objc dynamic var quotaFree: Int64 = 0
    @objc dynamic var quotaRelative: Double = 0
    @objc dynamic var quotaTotal: Int64 = 0
    @objc dynamic var quotaUsed: Int64 = 0
    @objc dynamic var storageLocation = ""
    @objc dynamic var subadmin = ""
    @objc dynamic var twitter = ""
    @objc dynamic var urlBase = ""
    @objc dynamic var user = ""
    @objc dynamic var userId = ""
    @objc dynamic var userStatusClearAt: NSDate?
    @objc dynamic var userStatusIcon: String?
    @objc dynamic var userStatusMessage: String?
    @objc dynamic var userStatusMessageId: String?
    @objc dynamic var userStatusMessageIsPredefined: Bool = false
    @objc dynamic var userStatusStatus: String?
    @objc dynamic var userStatusStatusIsUserDefined: Bool = false
    @objc dynamic var website = ""

    override static func primaryKey() -> String {
        return "account"
    }

    func tableAccountToCodable() -> tableAccountCodable {
        return tableAccountCodable(account: self.account, active: self.active, alias: self.alias, autoUploadCreateSubfolder: self.autoUploadCreateSubfolder, autoUploadSubfolderGranularity: self.autoUploadSubfolderGranularity, autoUploadDirectory: self.autoUploadDirectory, autoUploadFileName: self.autoUploadFileName, autoUploadStart: self.autoUploadStart, autoUploadImage: self.autoUploadImage, autoUploadVideo: self.autoUploadVideo, autoUploadWWAnPhoto: self.autoUploadWWAnPhoto, autoUploadWWAnVideo: self.autoUploadWWAnVideo, user: self.user, userId: self.userId, urlBase: self.urlBase)
    }

    convenience init(codableObject: tableAccountCodable) {
        self.init()
        self.account = codableObject.account
        self.active = codableObject.active
        self.alias = codableObject.alias

        self.autoUploadCreateSubfolder = codableObject.autoUploadCreateSubfolder
        self.autoUploadSubfolderGranularity = codableObject.autoUploadSubfolderGranularity
        self.autoUploadDirectory = codableObject.autoUploadDirectory
        self.autoUploadFileName = codableObject.autoUploadFileName
        self.autoUploadStart = codableObject.autoUploadStart
        self.autoUploadImage = codableObject.autoUploadImage
        self.autoUploadVideo = codableObject.autoUploadVideo
        self.autoUploadWWAnPhoto = codableObject.autoUploadWWAnPhoto
        self.autoUploadWWAnVideo = codableObject.autoUploadWWAnVideo

        self.user = codableObject.user
        self.userId = codableObject.userId
        self.urlBase = codableObject.urlBase
    }
}

struct tableAccountCodable: Codable {
    var account: String
    var active: Bool
    var alias: String

    var autoUploadCreateSubfolder: Bool
    var autoUploadSubfolderGranularity: Int
    var autoUploadDirectory = ""
    var autoUploadFileName: String
    var autoUploadStart: Bool
    var autoUploadImage: Bool
    var autoUploadVideo: Bool
    var autoUploadWWAnPhoto: Bool
    var autoUploadWWAnVideo: Bool

    var user: String
    var userId: String
    var urlBase: String
}

extension NCManageDatabase {

    // MARK: - Automatic backup/restore accounts

    func backupTableAccountToFile() {
        let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup)
        guard let fileURL = dirGroup?.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud + "/" + tableAccountBackup) else {
            return
        }

        do {
            let realm = try Realm()
            var codableObjects: [tableAccountCodable] = []
            let encoder = JSONEncoder()

            encoder.outputFormatting = .prettyPrinted

            for tblAccount in realm.objects(tableAccount.self) {
                if !NCKeychain().getPassword(account: tblAccount.account).isEmpty {
                    let codableObject = tblAccount.tableAccountToCodable()
                    codableObjects.append(codableObject)
                }
            }

            if !codableObjects.isEmpty {
                let jsonData = try encoder.encode(codableObjects)
                try jsonData.write(to: fileURL)
            }
        } catch {
            print("Error: \(error)")
        }
    }

    func restoreTableAccountFromFile() {
        let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup)
        guard let fileURL = dirGroup?.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud + "/" + tableAccountBackup) else {
            return
        }

        NextcloudKit.shared.nkCommonInstance.writeLog("DATABASE: Trying to restore account from backup...")

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] DATABASE: Account restore backup not found at: \(fileURL.path)")
            return
        }

        do {
            let realm = try Realm()
            let jsonData = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let codableObjects = try decoder.decode([tableAccountCodable].self, from: jsonData)

            try realm.write {
                for codableObject in codableObjects {
                    if !NCKeychain().getPassword(account: codableObject.account).isEmpty {
                        let tableAccount = tableAccount(codableObject: codableObject)
                        realm.add(tableAccount)
                    }
                }
            }

            NextcloudKit.shared.nkCommonInstance.writeLog("DATABASE: Account restored")
        } catch {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] DATABASE: Account restore error: \(error)")
        }
    }

    // MARK: - Realm write

    func addAccount(_ account: String, urlBase: String, user: String, userId: String, password: String) {
        performRealmWrite { realm in
            if let existing = realm.object(ofType: tableAccount.self, forPrimaryKey: account) {
                realm.delete(existing)
            }

            // Save password in Keychain
            NCKeychain().setPassword(account: account, password: password)

            let newAccount = tableAccount()

            newAccount.account = account
            newAccount.urlBase = urlBase
            newAccount.user = user
            newAccount.userId = userId

            realm.add(newAccount, update: .all)
        }
    }

    func updateAccountProperty<T>(_ keyPath: ReferenceWritableKeyPath<tableAccount, T>, value: T, account: String) {
        guard let activeAccount = getTableAccount(account: account) else { return }
        activeAccount[keyPath: keyPath] = value
        updateAccount(activeAccount)
    }

    func updateAccount(_ account: tableAccount) {
        performRealmWrite { realm in
            realm.add(account, update: .all)
        }
    }

    func setAccountAlias(_ account: String, alias: String) {
        let alias = alias.trimmingCharacters(in: .whitespacesAndNewlines)

        performRealmWrite { realm in
            if let result = realm.objects(tableAccount.self).filter("account == %@", account).first {
                result.alias = alias
            }
        }
    }

    @discardableResult
    func setAccountActive(_ account: String) -> tableAccount? {
        var tblAccount: tableAccount?

        performRealmWrite { realm in
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

    func setAccountAutoUploadProperty(_ property: String, state: Bool) {
        performRealmWrite { realm in
            if let result = realm.objects(tableAccount.self).filter("active == true").first {
                if (tableAccount().objectSchema.properties.contains { $0.name == property }) {
                    result[property] = state
                }
            }
        }
    }

    func setAccountAutoUploadGranularity(_ property: String, state: Int) {
        performRealmWrite { realm in
            if let result = realm.objects(tableAccount.self).filter("active == true").first {
                result.autoUploadSubfolderGranularity = state
            }
        }
    }

    func setAccountAutoUploadFileName(_ fileName: String) {
        performRealmWrite { realm in
            if let result = realm.objects(tableAccount.self).filter("active == true").first {
                result.autoUploadFileName = fileName
            }
        }
    }

    func setAccountAutoUploadDirectory(_ serverUrl: String, session: NCSession.Session) {
        performRealmWrite { realm in
            if let result = realm.objects(tableAccount.self)
                .filter("active == true")
                .first {
                result.autoUploadDirectory = serverUrl
            }
        }
    }

    func setAutoUploadOnlyNewSinceDate(account: String, date: Date) {
        performRealmWrite { realm in
            if let result = realm.objects(tableAccount.self)
                .filter("acccount == %@", account)
                .first {
                result.autoUploadOnlyNewSinceDate = date
            }
        }
    }

    func setAccountUserProfile(account: String, userProfile: NKUserProfile, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
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

    func setAccountMediaPath(_ path: String, account: String) {
        performRealmWrite { realm in
            if let result = realm.objects(tableAccount.self).filter("account == %@", account).first {
                result.mediaPath = path
            }
        }
    }

    func setAccountUserStatus(userStatusClearAt: Date?,
                              userStatusIcon: String?,
                              userStatusMessage: String?,
                              userStatusMessageId: String?,
                              userStatusMessageIsPredefined: Bool,
                              userStatusStatus: String?,
                              userStatusStatusIsUserDefined: Bool,
                              account: String,
                              sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            if let result = realm.objects(tableAccount.self)
                .filter("account == %@", account)
                .first {
                result.userStatusClearAt = userStatusClearAt as? NSDate
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
        performRealmRead { realm in
            realm.objects(tableAccount.self)
                .filter(predicate)
                .first
                .map { tableAccount(value: $0) }
        }
    }

    func getAllTableAccount() -> [tableAccount] {
        performRealmRead { realm in
            let sorted = [SortDescriptor(keyPath: "active", ascending: false),
                          SortDescriptor(keyPath: "user", ascending: true)]
            let results = realm.objects(tableAccount.self)
                        .sorted(by: sorted)
            return results.map { tableAccount(value: $0) }
        } ?? []
    }

    func getAllAccountOrderAlias() -> [tableAccount] {
        performRealmRead { realm in
            let sorted = [SortDescriptor(keyPath: "active", ascending: false),
                          SortDescriptor(keyPath: "alias", ascending: true),
                          SortDescriptor(keyPath: "user", ascending: true)]
            let results = realm.objects(tableAccount.self).sorted(by: sorted)
            return results.map { tableAccount(value: $0) }
        } ?? []
    }

    func getAccountAutoUploadFileName(account: String) -> String {
        return performRealmRead { realm in
            guard let result = realm.objects(tableAccount.self)
                .filter("account == %@", account)
                .first
            else {
                return NCBrandOptions.shared.folderDefaultAutoUpload
            }
            return result.autoUploadFileName.isEmpty ? NCBrandOptions.shared.folderDefaultAutoUpload : result.autoUploadFileName
        } ?? NCBrandOptions.shared.folderDefaultAutoUpload
    }

    func getAccountAutoUploadDirectory(session: NCSession.Session) -> String {
        return getAccountAutoUploadDirectory(account: session.account, urlBase: session.urlBase, userId: session.userId)
    }

    func getAccountAutoUploadDirectory(account: String, urlBase: String, userId: String) -> String {
        let homeServer = utilityFileSystem.getHomeServer(urlBase: urlBase, userId: userId)

        return performRealmRead { realm in
            realm.objects(tableAccount.self)
                .filter("account == %@", account)
                .first?
                .autoUploadDirectory
        }.flatMap { directory in
            (directory.isEmpty || directory.contains("/webdav")) ? homeServer : directory
        } ?? homeServer
    }

    func getAccountAutoUploadServerUrlBase(session: NCSession.Session) -> String {
        return getAccountAutoUploadServerUrlBase(account: session.account, urlBase: session.urlBase, userId: session.userId)
    }

    func getAccountAutoUploadServerUrlBase(account: String, urlBase: String, userId: String) -> String {
        let cameraFileName = self.getAccountAutoUploadFileName(account: account)
        let cameraDirectory = self.getAccountAutoUploadDirectory(account: account, urlBase: urlBase, userId: userId)
        let folderPhotos = utilityFileSystem.stringAppendServerUrl(cameraDirectory, addFileName: cameraFileName)
        return folderPhotos
    }

    func getAccountAutoUploadSubfolderGranularity() -> Int {
        performRealmRead { realm in
            realm.objects(tableAccount.self)
                .filter("active == true")
                .first?
                .autoUploadSubfolderGranularity
        } ?? NCGlobal.shared.subfolderGranularityMonthly
    }

    func getAccountAutoUploadOnlyNewSinceDate() -> Date? {
        return performRealmRead { realm in
            realm.objects(tableAccount.self)
                .filter("active == true")
                .first?
                .autoUploadOnlyNewSinceDate
        }
    }

    func getActiveTableAccount() -> tableAccount? {
        performRealmRead { realm in
            realm.objects(tableAccount.self)
                .filter("active == true")
                .first
                .map { tableAccount(value: $0) }
        }
    }

    func getTableAccount(account: String) -> tableAccount? {
        performRealmRead { realm in
            realm.objects(tableAccount.self)
                .filter("account == %@", account)
                .first
                .map { tableAccount(value: $0) }
        }
    }

    func getAccounts() -> [String]? {
        performRealmRead { realm in
            let results = realm.objects(tableAccount.self)
                .sorted(byKeyPath: "account", ascending: true)
            return results.map { $0.account }
        }
    }

    func getAccountGroups(account: String) -> [String] {
        return performRealmRead { realm in
            return realm.objects(tableAccount.self)
                .filter("account == %@", account)
                .first?
                .groups
                .components(separatedBy: ",") ?? []
        } ?? []
    }
}
