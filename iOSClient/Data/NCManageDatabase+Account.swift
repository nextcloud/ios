//
//  NCManageDatabase+Account.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 13/11/23.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
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

class tableAccount: Object {
    @objc dynamic var account = ""
    @objc dynamic var active: Bool = false
    @objc dynamic var address = ""
    @objc dynamic var alias = ""
    @objc dynamic var autoUpload: Bool = false
    @objc dynamic var autoUploadCreateSubfolder: Bool = false
    @objc dynamic var autoUploadSubfolderGranularity: Int = NCGlobal.shared.subfolderGranularityMonthly
    @objc dynamic var autoUploadDirectory = ""
    @objc dynamic var autoUploadFileName = ""
    @objc dynamic var autoUploadFull: Bool = false
    @objc dynamic var autoUploadImage: Bool = false
    @objc dynamic var autoUploadVideo: Bool = false
    @objc dynamic var autoUploadFavoritesOnly: Bool = false
    @objc dynamic var autoUploadWWAnPhoto: Bool = false
    @objc dynamic var autoUploadWWAnVideo: Bool = false
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
    @objc dynamic var password = ""
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
}

extension NCManageDatabase {
    func addAccount(_ account: String, urlBase: String, user: String, userId: String, password: String) {
        do {
            let realm = try Realm()
            try realm.write {
                if let result = realm.objects(tableAccount.self).filter("account == %@", account).first {
                    realm.delete(result)
                }
                let tableAccount = tableAccount()
                tableAccount.account = account
                NCKeychain().setPassword(account: account, password: password)
                tableAccount.urlBase = urlBase
                tableAccount.user = user
                tableAccount.userId = userId
                realm.add(tableAccount, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func updateAccount(_ account: tableAccount) {
        do {
            let realm = try Realm()
            try realm.write {
                realm.add(account, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func getActiveTableAccount() -> tableAccount? {
        do {
            let realm = try Realm()
            guard let result = realm.objects(tableAccount.self).filter("active == true").first else { return nil }
            return tableAccount.init(value: result)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getTableAccount(account: String) -> tableAccount? {
        do {
            let realm = try Realm()
            guard let result = realm.objects(tableAccount.self).filter("account == %@", account).first else { return nil }
            return tableAccount.init(value: result)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getAccounts() -> [String]? {
        do {
            let realm = try Realm()
            let results = realm.objects(tableAccount.self).sorted(byKeyPath: "account", ascending: true)
            if !results.isEmpty {
                return Array(results.map { $0.account })
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getTableAccount(predicate: NSPredicate) -> tableAccount? {
        do {
            let realm = try Realm()
            guard let result = realm.objects(tableAccount.self).filter(predicate).first else { return nil }
            return tableAccount.init(value: result)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getAllTableAccount() -> [tableAccount] {
        do {
            let realm = try Realm()
            let sorted = [SortDescriptor(keyPath: "active", ascending: false), SortDescriptor(keyPath: "user", ascending: true)]
            let results = realm.objects(tableAccount.self).sorted(by: sorted)
            return Array(results.map { tableAccount.init(value: $0) })
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return []
    }

    func getAllAccountOrderAlias() -> [tableAccount] {
        do {
            let realm = try Realm()
            let sorted = [SortDescriptor(keyPath: "active", ascending: false), SortDescriptor(keyPath: "alias", ascending: true), SortDescriptor(keyPath: "user", ascending: true)]
            let results = realm.objects(tableAccount.self).sorted(by: sorted)
            return Array(results.map { tableAccount.init(value: $0) })
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return []
    }

    func getAccountAutoUploadFileName() -> String {
        do {
            let realm = try Realm()
            guard let result = realm.objects(tableAccount.self).filter("active == true").first else { return "" }
            if result.autoUploadFileName.isEmpty {
                return NCBrandOptions.shared.folderDefaultAutoUpload
            } else {
                return result.autoUploadFileName
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return ""
    }

    func getAccountAutoUploadDirectory(session: NCSession.Session) -> String {
        do {
            let realm = try Realm()
            guard let result = realm.objects(tableAccount.self).filter("active == true").first else { return "" }
            if result.autoUploadDirectory.isEmpty {
                return utilityFileSystem.getHomeServer(session: session)
            } else {
                // FIX change webdav -> /dav/files/
                if result.autoUploadDirectory.contains("/webdav") {
                    return utilityFileSystem.getHomeServer(session: session)
                } else {
                    return result.autoUploadDirectory
                }
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return ""
    }

    func getAccountAutoUploadPath(session: NCSession.Session) -> String {
        let cameraFileName = self.getAccountAutoUploadFileName()
        let cameraDirectory = self.getAccountAutoUploadDirectory(session: session)
        let folderPhotos = utilityFileSystem.stringAppendServerUrl(cameraDirectory, addFileName: cameraFileName)
        return folderPhotos
    }

    func getAccountAutoUploadSubfolderGranularity() -> Int {
        do {
            let realm = try Realm()
            guard let result = realm.objects(tableAccount.self).filter("active == true").first else { return NCGlobal.shared.subfolderGranularityMonthly }
            return result.autoUploadSubfolderGranularity
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return NCGlobal.shared.subfolderGranularityMonthly
    }

    func setAccountActive(_ account: String) {
        do {
            let realm = try Realm()
            try realm.write {
                let results = realm.objects(tableAccount.self)
                for result in results {
                    if result.account == account {
                        result.active = true
                    } else {
                        result.active = false
                    }
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func setAccountAutoUploadProperty(_ property: String, state: Bool) {
        do {
            let realm = try Realm()
            try realm.write {
                if let result = realm.objects(tableAccount.self).filter("active == true").first {
                    if (tableAccount().objectSchema.properties.contains { $0.name == property }) {
                        result[property] = state
                    }
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func setAccountAutoUploadGranularity(_ property: String, state: Int) {
        do {
            let realm = try Realm()
            try realm.write {
                if let result = realm.objects(tableAccount.self).filter("active == true").first {
                    result.autoUploadSubfolderGranularity = state
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func setAccountAutoUploadFileName(_ fileName: String) {
        do {
            let realm = try Realm()
            try realm.write {
                if let result = realm.objects(tableAccount.self).filter("active == true").first {
                    result.autoUploadFileName = fileName
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func setAccountAutoUploadDirectory(_ serverUrl: String?, session: NCSession.Session) {
        do {
            let realm = try Realm()
            try realm.write {
                if let result = realm.objects(tableAccount.self).filter("active == true").first {
                    if let serverUrl = serverUrl {
                        result.autoUploadDirectory = serverUrl
                    } else {
                        result.autoUploadDirectory = self.getAccountAutoUploadDirectory(session: session)
                    }
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func setAccountUserProfile(account: String, userProfile: NKUserProfile) {
        do {
            let realm = try Realm()
            try realm.write {
                if let result = realm.objects(tableAccount.self).filter("account == %@", account).first {
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
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func setAccountMediaPath(_ path: String, account: String) {
        do {
            let realm = try Realm()
            try realm.write {
                if let result = realm.objects(tableAccount.self).filter("account == %@", account).first {
                    result.mediaPath = path
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func setAccountUserStatus(userStatusClearAt: Date?, userStatusIcon: String?, userStatusMessage: String?, userStatusMessageId: String?, userStatusMessageIsPredefined: Bool, userStatusStatus: String?, userStatusStatusIsUserDefined: Bool, account: String) {
        do {
            let realm = try Realm()
            try realm.write {
                if let result = realm.objects(tableAccount.self).filter("account == %@", account).first {
                    result.userStatusClearAt = userStatusClearAt as? NSDate
                    result.userStatusIcon = userStatusIcon
                    result.userStatusMessage = userStatusMessage
                    result.userStatusMessageId = userStatusMessageId
                    result.userStatusMessageIsPredefined = userStatusMessageIsPredefined
                    result.userStatusStatus = userStatusStatus
                    result.userStatusStatusIsUserDefined = userStatusStatusIsUserDefined
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func setAccountAlias(_ account: String, alias: String) {
        let alias = alias.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let realm = try Realm()
            try realm.write {
                if let result = realm.objects(tableAccount.self).filter("account == %@", account).first {
                    result.alias = alias
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func getAccountGroups(account: String) -> [String] {
        do {
            let realm = try Realm()
            if let result = realm.objects(tableAccount.self).filter("account == %@", account).first {
                return result.groups.components(separatedBy: ",")
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return []
    }
}
