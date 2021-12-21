//
//  NCManageDatabase+Account.swift
//  Nextcloud
//
//  Created by Henrik Storch on 30.11.21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import Foundation
import RealmSwift
import NCCommunication

extension NCManageDatabase {

    @objc func copyObject(account: tableAccount) -> tableAccount {
        return tableAccount.init(value: account)
    }

    @objc func addAccount(_ account: String, urlBase: String, user: String, password: String) {

        let realm = try! Realm()

        do {
            try realm.safeWrite {
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
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func updateAccount(_ account: tableAccount) {

        let realm = try! Realm()

        do {
            try realm.safeWrite {
                realm.add(account, update: .all)
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func deleteAccount(_ account: String) {

        let realm = try! Realm()

        do {
            try realm.safeWrite {
                let result = realm.objects(tableAccount.self).filter("account == %@", account)

                realm.delete(result)
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
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

    @objc func getAccountAutoUploadDirectory(urlBase: String, account: String) -> String {

        let realm = try! Realm()

        guard let result = realm.objects(tableAccount.self).filter("active == true").first else {
            return ""
        }

        if result.autoUploadDirectory.count > 0 {
            // FIX change webdav -> /dav/files/
            if result.autoUploadDirectory.contains("/webdav") {
                return NCUtilityFileSystem.shared.getHomeServer(account: account)
            } else {
                return result.autoUploadDirectory
            }
        } else {
            return NCUtilityFileSystem.shared.getHomeServer(account: account)
        }
    }

    @objc func getAccountAutoUploadPath(urlBase: String, account: String) -> String {

        let cameraFileName = self.getAccountAutoUploadFileName()
        let cameraDirectory = self.getAccountAutoUploadDirectory(urlBase: urlBase, account: account)

        let folderPhotos = CCUtility.stringAppendServerUrl(cameraDirectory, addFileName: cameraFileName)!

        return folderPhotos
    }

    @discardableResult
    @objc func setAccountActive(_ account: String) -> tableAccount? {

        let realm = try! Realm()
        var accountReturn = tableAccount()

        do {
            try realm.safeWrite {

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
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
            return nil
        }

        return tableAccount.init(value: accountReturn)
    }

    @objc func removePasswordAccount(_ account: String) {

        let realm = try! Realm()

        do {
            try realm.safeWrite {

                if let result = realm.objects(tableAccount.self).filter("account == %@", account).first {
                    result.password = "********"
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func setAccountAutoUploadProperty(_ property: String, state: Bool) {

        let realm = try! Realm()

        do {
            try realm.safeWrite {
                if let result = realm.objects(tableAccount.self).filter("active == true").first {
                    if (tableAccount().objectSchema.properties.contains { $0.name == property }) {
                        result[property] = state
                    }
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func setAccountAutoUploadFileName(_ fileName: String?) {

        let realm = try! Realm()

        do {
            try realm.safeWrite {
                if let result = realm.objects(tableAccount.self).filter("active == true").first {
                    if let fileName = fileName {
                        result.autoUploadFileName = fileName
                    } else {
                        result.autoUploadFileName = self.getAccountAutoUploadFileName()
                    }
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func setAccountAutoUploadDirectory(_ serverUrl: String?, urlBase: String, account: String) {

        let realm = try! Realm()

        do {
            try realm.safeWrite {
                if let result = realm.objects(tableAccount.self).filter("active == true").first {
                    if let serverUrl = serverUrl {
                        result.autoUploadDirectory = serverUrl
                    } else {
                        result.autoUploadDirectory = self.getAccountAutoUploadDirectory(urlBase: urlBase, account: account)
                    }
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func setAccountUserProfile(_ userProfile: NCCommunicationUserProfile) -> tableAccount? {

        let realm = try! Realm()

        var returnAccount = tableAccount()

        do {
            guard let activeAccount = self.getActiveAccount() else {
                return nil
            }

            try realm.safeWrite {

                guard let result = realm.objects(tableAccount.self).filter("account == %@", activeAccount.account).first else {
                    return
                }

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
                result.webpage = userProfile.webpage

                returnAccount = result
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }

        return tableAccount.init(value: returnAccount)
    }

    @objc func setAccountUserProfileHC(businessSize: String, businessType: String, city: String, company: String, country: String, role: String, zip: String) -> tableAccount? {

        let realm = try! Realm()

        var returnAccount = tableAccount()

        do {
            guard let activeAccount = self.getActiveAccount() else {
                return nil
            }

            try realm.safeWrite {

                guard let result = realm.objects(tableAccount.self).filter("account == %@", activeAccount.account).first else {
                    return
                }

                result.businessSize = businessSize
                result.businessType = businessType
                result.city = city
                result.company = company
                result.country = country
                result.role = role
                result.zip = zip

                returnAccount = result
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }

        return tableAccount.init(value: returnAccount)
    }

    /*
    #if !EXTENSION
    @objc func setAccountHCFeatures(_ features: HCFeatures) -> tableAccount? {
        
        let realm = try! Realm()
        
        var returnAccount = tableAccount()

        do {
            guard let account = self.getAccountActive() else {
                return nil
            }
            
            try realm.write {
                
                guard let result = realm.objects(tableAccount.self).filter("account == %@", account.account).first else {
                    return
                }
                
                result.hcIsTrial = features.isTrial
                result.hcTrialExpired = features.trialExpired
                result.hcTrialRemainingSec = features.trialRemainingSec
                if features.trialEndTime > 0 {
                    result.hcTrialEndTime = Date(timeIntervalSince1970: features.trialEndTime) as NSDate
                } else {
                    result.hcTrialEndTime = nil
                }
                
                result.hcAccountRemoveExpired = features.accountRemoveExpired
                result.hcAccountRemoveRemainingSec = features.accountRemoveRemainingSec
                if features.accountRemoveTime > 0 {
                    result.hcAccountRemoveTime = Date(timeIntervalSince1970: features.accountRemoveTime) as NSDate
                } else {
                    result.hcAccountRemoveTime = nil
                }
                
                result.hcNextGroupExpirationGroup = features.nextGroupExpirationGroup
                result.hcNextGroupExpirationGroupExpired = features.nextGroupExpirationGroupExpired
                if features.nextGroupExpirationExpiresTime > 0 {
                    result.hcNextGroupExpirationExpiresTime = Date(timeIntervalSince1970: features.nextGroupExpirationExpiresTime) as NSDate
                } else {
                    result.hcNextGroupExpirationExpiresTime = nil
                }
                result.hcNextGroupExpirationExpires = features.nextGroupExpirationExpires
                
                returnAccount = result
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
        
        return tableAccount.init(value: returnAccount)
    }
    #endif
    */

    @objc func setAccountMediaPath(_ path: String, account: String) {

        let realm = try! Realm()
        do {
            try realm.safeWrite {
                if let result = realm.objects(tableAccount.self).filter("account == %@", account).first {
                    result.mediaPath = path
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func setAccountUserStatus(userStatusClearAt: NSDate?, userStatusIcon: String?, userStatusMessage: String?, userStatusMessageId: String?, userStatusMessageIsPredefined: Bool, userStatusStatus: String?, userStatusStatusIsUserDefined: Bool, account: String) {

        let realm = try! Realm()
        do {
            try realm.safeWrite {
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
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func setAccountAlias(_ alias: String?) {

        let realm = try! Realm()
        let alias = alias?.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try realm.safeWrite {
                if let result = realm.objects(tableAccount.self).filter("active == true").first {
                    if let alias = alias {
                        result.alias = alias
                    } else {
                        result.alias = ""
                    }
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func setAccountColorFiles(lightColorBackground: String, darkColorBackground: String) {

        let realm = try! Realm()

        do {
            try realm.safeWrite {
                if let result = realm.objects(tableAccount.self).filter("active == true").first {
                    result.lightColorBackground = lightColorBackground
                    result.darkColorBackground = darkColorBackground
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
}
