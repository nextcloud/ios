//
//  NCManageDatabase+Account.swift
//  Nextcloud
//
//  Created by Henrik Storch on 30.11.21.
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
import RealmSwift
import NextcloudKit

class tableAccount: Object, NCUserBaseUrl {

    @objc dynamic var account = ""
    @objc dynamic var active: Bool = false
    @objc dynamic var address = ""
    @objc dynamic var alias = ""
    @objc dynamic var autoUpload: Bool = false
    @objc dynamic var autoUploadCreateSubfolder: Bool = false
    @objc dynamic var autoUploadSubfolderGranularity: Int64 = 1
    @objc dynamic var autoUploadDirectory = ""
    @objc dynamic var autoUploadFileName = ""
    @objc dynamic var autoUploadFull: Bool = false
    @objc dynamic var autoUploadImage: Bool = false
    @objc dynamic var autoUploadVideo: Bool = false
    @objc dynamic var autoUploadWWAnPhoto: Bool = false
    @objc dynamic var autoUploadWWAnVideo: Bool = false
    @objc dynamic var backend = ""
    @objc dynamic var backendCapabilitiesSetDisplayName: Bool = false
    @objc dynamic var backendCapabilitiesSetPassword: Bool = false
    @objc dynamic var businessSize: String = ""
    @objc dynamic var businessType = ""
    @objc dynamic var city = ""
    @objc dynamic var country = ""
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
    @objc dynamic var role = ""
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
    @objc dynamic var zip = ""

    // HC
    @objc dynamic var hcIsTrial: Bool = false
    @objc dynamic var hcTrialExpired: Bool = false
    @objc dynamic var hcTrialRemainingSec: Int64 = 0
    @objc dynamic var hcTrialEndTime: NSDate?
    @objc dynamic var hcAccountRemoveExpired: Bool = false
    @objc dynamic var hcAccountRemoveRemainingSec: Int64 = 0
    @objc dynamic var hcAccountRemoveTime: NSDate?
    @objc dynamic var hcNextGroupExpirationGroup = ""
    @objc dynamic var hcNextGroupExpirationGroupExpired: Bool = false
    @objc dynamic var hcNextGroupExpirationExpiresTime: NSDate?
    @objc dynamic var hcNextGroupExpirationExpires = ""

    override static func primaryKey() -> String {
        return "account"
    }
}

extension NCManageDatabase {

    @objc func addAccount(_ account: String, urlBase: String, user: String, password: String) {

        let realm = try! Realm()

        do {
            try realm.write {
                let addObject = tableAccount()

                addObject.account = account

                // Brand
                if NCBrandOptions.shared.use_default_auto_upload {

                    addObject.autoUpload = true
                    addObject.autoUploadImage = true
                    addObject.autoUploadVideo = true
                    addObject.autoUploadWWAnVideo = true
                }

                CCUtility.setPassword(account, password: password)

                addObject.urlBase = urlBase
                addObject.user = user
                addObject.userId = user

                realm.add(addObject, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func updateAccount(_ account: tableAccount) {

        let realm = try! Realm()

        do {
            try realm.write {
                realm.add(account, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func deleteAccount(_ account: String) {

        let realm = try! Realm()

        do {
            try realm.write {
                let result = realm.objects(tableAccount.self).filter("account == %@", account)
                realm.delete(result)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func getActiveAccount() -> tableAccount? {

        let realm = try! Realm()

        guard let result = realm.objects(tableAccount.self).filter("active == true").first else {
            return nil
        }

        return tableAccount.init(value: result)
    }

    @objc func getAccounts() -> [String]? {

        let realm = try! Realm()

        let results = realm.objects(tableAccount.self).sorted(byKeyPath: "account", ascending: true)

        if results.count > 0 {
            return Array(results.map { $0.account })
        }

        return nil
    }

    @objc func getAccount(predicate: NSPredicate) -> tableAccount? {

        let realm = try! Realm()

        guard let result = realm.objects(tableAccount.self).filter(predicate).first else {
            return nil
        }

        return tableAccount.init(value: result)
    }

    @objc func getAllAccount() -> [tableAccount] {

        let realm = try! Realm()

        let sorted = [SortDescriptor(keyPath: "active", ascending: false), SortDescriptor(keyPath: "user", ascending: true)]
        let results = realm.objects(tableAccount.self).sorted(by: sorted)

        return Array(results.map { tableAccount.init(value: $0) })
    }

    @objc func getAllAccountOrderAlias() -> [tableAccount] {

        let realm = try! Realm()

        let sorted = [SortDescriptor(keyPath: "active", ascending: false), SortDescriptor(keyPath: "alias", ascending: true), SortDescriptor(keyPath: "user", ascending: true)]
        let results = realm.objects(tableAccount.self).sorted(by: sorted)

        return Array(results.map { tableAccount.init(value: $0) })
    }

    @objc func getAccountAutoUploadFileName() -> String {

        let realm = try! Realm()

        guard let result = realm.objects(tableAccount.self).filter("active == true").first else {
            return ""
        }

        if result.autoUploadFileName.count > 0 {
            return result.autoUploadFileName
        } else {
            return NCBrandOptions.shared.folderDefaultAutoUpload
        }
    }

    @objc func getAccountAutoUploadDirectory(urlBase: String, userId: String, account: String) -> String {

        let realm = try! Realm()

        guard let result = realm.objects(tableAccount.self).filter("active == true").first else {
            return ""
        }

        if result.autoUploadDirectory.count > 0 {
            // FIX change webdav -> /dav/files/
            if result.autoUploadDirectory.contains("/webdav") {
                return NCUtilityFileSystem.shared.getHomeServer(urlBase: urlBase, userId: userId)
            } else {
                return result.autoUploadDirectory
            }
        } else {
            return NCUtilityFileSystem.shared.getHomeServer(urlBase: urlBase, userId: userId)
        }
    }

    @objc func getAccountAutoUploadPath(urlBase: String, userId: String, account: String) -> String {

        let cameraFileName = self.getAccountAutoUploadFileName()
        let cameraDirectory = self.getAccountAutoUploadDirectory(urlBase: urlBase, userId: userId, account: account)

        let folderPhotos = CCUtility.stringAppendServerUrl(cameraDirectory, addFileName: cameraFileName)!

        return folderPhotos
    }

    @objc func getAccountAutoUploadSubfolderGranularity() -> Int64 {

        let realm = try! Realm()

        guard let result = realm.objects(tableAccount.self).filter("active == true").first else {
            return 1
        }

        return result.autoUploadSubfolderGranularity
    }
    
    @discardableResult
    @objc func setAccountActive(_ account: String) -> tableAccount? {

        let realm = try! Realm()
        var accountReturn = tableAccount()

        do {
            try realm.write {

                let results = realm.objects(tableAccount.self)
                for result in results {
                    if result.account == account {
                        result.active = true
                        accountReturn = result
                    } else {
                        result.active = false
                    }
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
            return nil
        }

        return tableAccount.init(value: accountReturn)
    }

    @objc func removePasswordAccount(_ account: String) {

        let realm = try! Realm()

        do {
            try realm.write {

                if let result = realm.objects(tableAccount.self).filter("account == %@", account).first {
                    result.password = "********"
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func setAccountAutoUploadProperty(_ property: String, state: Bool) {

        let realm = try! Realm()

        do {
            try realm.write {
                if let result = realm.objects(tableAccount.self).filter("active == true").first {
                    if (tableAccount().objectSchema.properties.contains { $0.name == property }) {
                        result[property] = state
                    }
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func setAccountAutoUploadGranularity(_ property: String, state: Int64) {

        let realm = try! Realm()

        do {
            try realm.write {
                if let result = realm.objects(tableAccount.self).filter("active == true").first {
                    result.autoUploadSubfolderGranularity = state
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func setAccountAutoUploadFileName(_ fileName: String?) {

        let realm = try! Realm()

        do {
            try realm.write {
                if let result = realm.objects(tableAccount.self).filter("active == true").first {
                    if let fileName = fileName {
                        result.autoUploadFileName = fileName
                    } else {
                        result.autoUploadFileName = self.getAccountAutoUploadFileName()
                    }
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func setAccountAutoUploadDirectory(_ serverUrl: String?, urlBase: String, userId: String, account: String) {

        let realm = try! Realm()

        do {
            try realm.write {
                if let result = realm.objects(tableAccount.self).filter("active == true").first {
                    if let serverUrl = serverUrl {
                        result.autoUploadDirectory = serverUrl
                    } else {
                        result.autoUploadDirectory = self.getAccountAutoUploadDirectory(urlBase: urlBase, userId: userId, account: account)
                    }
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func setAccountUserProfile(account: String, userProfile: NKUserProfile) -> tableAccount? {

        let realm = try! Realm()

        do {
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
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }

        if let result = realm.objects(tableAccount.self).filter("account == %@", account).first {
            return tableAccount.init(value: result)
        } else {
            return nil
        }
    }

    @objc func setAccountMediaPath(_ path: String, account: String) {

        let realm = try! Realm()
        do {
            try realm.write {
                if let result = realm.objects(tableAccount.self).filter("account == %@", account).first {
                    result.mediaPath = path
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func setAccountUserStatus(userStatusClearAt: NSDate?, userStatusIcon: String?, userStatusMessage: String?, userStatusMessageId: String?, userStatusMessageIsPredefined: Bool, userStatusStatus: String?, userStatusStatusIsUserDefined: Bool, account: String) {

        let realm = try! Realm()
        do {
            try realm.write {
                if let result = realm.objects(tableAccount.self).filter("account == %@", account).first {
                    result.userStatusClearAt = userStatusClearAt
                    result.userStatusIcon = userStatusIcon
                    result.userStatusMessage = userStatusMessage
                    result.userStatusMessageId = userStatusMessageId
                    result.userStatusMessageIsPredefined = userStatusMessageIsPredefined
                    result.userStatusStatus = userStatusStatus
                    result.userStatusStatusIsUserDefined = userStatusStatusIsUserDefined
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func setAccountAlias(_ alias: String?) {

        let realm = try! Realm()
        let alias = alias?.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try realm.write {
                if let result = realm.objects(tableAccount.self).filter("active == true").first {
                    if let alias = alias {
                        result.alias = alias
                    } else {
                        result.alias = ""
                    }
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }
}
