//
//  NCManageDatabase.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/05/17.
//  Copyright © 2017 Marino Faggiana. All rights reserved.
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

import RealmSwift
import NCCommunication
import SwiftyJSON

class NCManageDatabase: NSObject {
    @objc static let sharedInstance: NCManageDatabase = {
        let instance = NCManageDatabase()
        return instance
    }()
    
    override init() {
        
        let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.sharedInstance.capabilitiesGroups)
        let databaseFilePath = dirGroup?.appendingPathComponent("\(k_appDatabaseNextcloud)/\(k_databaseDefault)")

        let bundleUrl: URL = Bundle.main.bundleURL
        let bundlePathExtension: String = bundleUrl.pathExtension
        let isAppex: Bool = bundlePathExtension == "appex"
        
        if isAppex {
            
            // App Extension config
            
            let config = Realm.Configuration(
                fileURL: dirGroup?.appendingPathComponent("\(k_appDatabaseNextcloud)/\(k_databaseDefault)"),
                schemaVersion: UInt64(k_databaseSchemaVersion),
                objectTypes: [tableMetadata.self, tableLocalFile.self, tableDirectory.self, tableTag.self, tableAccount.self, tableCapabilities.self]
            )
            
            Realm.Configuration.defaultConfiguration = config
            
        } else {
            
            // App config

            let configCompact = Realm.Configuration(
                
                fileURL: databaseFilePath,
                schemaVersion: UInt64(k_databaseSchemaVersion),
                
                migrationBlock: { migration, oldSchemaVersion in
                    
                    if oldSchemaVersion < 41 {
                        migration.deleteData(forType: tableActivity.className())
                        migration.deleteData(forType: tableMetadata.className())
                        migration.deleteData(forType: tableDirectory.className())
                    }
                    
                    if oldSchemaVersion < 61 {
                        migration.deleteData(forType: tableShare.className())
                    }
                    
                    if oldSchemaVersion < 74 {
                        
                        migration.enumerateObjects(ofType: tableLocalFile.className()) { oldObject, newObject in
                            newObject!["ocId"] = oldObject!["fileID"]
                        }
                        
                        migration.enumerateObjects(ofType: tableTrash.className()) { oldObject, newObject in
                            newObject!["fileId"] = oldObject!["fileID"]
                        }
                        
                        migration.enumerateObjects(ofType: tableTag.className()) { oldObject, newObject in
                            newObject!["ocId"] = oldObject!["fileID"]
                        }
                        
                        migration.enumerateObjects(ofType: tableE2eEncryptionLock.className()) { oldObject, newObject in
                            newObject!["ocId"] = oldObject!["fileID"]
                        }
                    }
                    
                    if oldSchemaVersion < 78 {
                        migration.deleteData(forType: tableActivity.className())
                        migration.deleteData(forType: tableActivityPreview.className())
                        migration.deleteData(forType: tableActivitySubjectRich.className())
                        migration.deleteData(forType: tableComments.className())
                        migration.deleteData(forType: tableDirectory.className())
                        migration.deleteData(forType: tableMetadata.className())
                        migration.deleteData(forType: tableMedia.className())
                        migration.deleteData(forType: tableE2eEncryptionLock.className())
                        migration.deleteData(forType: tableTag.className())
                        migration.deleteData(forType: tableTrash.className())
                    }
                    
                    if oldSchemaVersion < 87 {
                        migration.deleteData(forType: tableActivity.className())
                        migration.deleteData(forType: tableActivityPreview.className())
                        migration.deleteData(forType: tableActivitySubjectRich.className())
                        migration.deleteData(forType: tableCapabilities.className())
                        migration.deleteData(forType: tableComments.className())
                        migration.deleteData(forType: tableDirectEditingCreators.className())
                        migration.deleteData(forType: tableDirectEditingEditors.className())
                        migration.deleteData(forType: tableDirectory.className())
                        migration.deleteData(forType: tableE2eEncryptionLock.className())
                        migration.deleteData(forType: tableExternalSites.className())
                        migration.deleteData(forType: tableGPS.className())
                        migration.deleteData(forType: tableShare.className())
                        migration.deleteData(forType: tableTag.className())
                        migration.deleteData(forType: tableTrash.className())
                    }
                    
                    if oldSchemaVersion < 95 {
                        migration.deleteData(forType: tableE2eEncryptionLock.className())
                        migration.deleteData(forType: tableDirectory.className())
                        migration.deleteData(forType: tableMetadata.className())
                    }
                    
                    if oldSchemaVersion < 104 {
                        migration.deleteData(forType: tableCapabilities.className())
                    }
                    
                }, shouldCompactOnLaunch: { totalBytes, usedBytes in
                    
                    // totalBytes refers to the size of the file on disk in bytes (data + free space)
                    // usedBytes refers to the number of bytes used by data in the file
                    
                    // Compact if the file is over 100MB in size and less than 50% 'used'
                    let oneHundredMB = 100 * 1024 * 1024
                    return (totalBytes > oneHundredMB) && (Double(usedBytes) / Double(totalBytes)) < 0.5
                }
            )
            
            do {
                _ = try Realm(configuration: configCompact)
            } catch {
                if let databaseFilePath = databaseFilePath {
                    do {
                        #if !EXTENSION
                        NCContentPresenter.shared.messageNotification("_error_", description: "_database_corrupt_", delay: TimeInterval(k_dismissAfterSecondLong), type: NCContentPresenter.messageType.info, errorCode: 0)
                        #endif
                        try FileManager.default.removeItem(at: databaseFilePath)
                    } catch {}
                }
            }
                        
            let config = Realm.Configuration(
                fileURL: dirGroup?.appendingPathComponent("\(k_appDatabaseNextcloud)/\(k_databaseDefault)"),
                schemaVersion: UInt64(k_databaseSchemaVersion)
            )
            
            Realm.Configuration.defaultConfiguration = config
        }
        
        // Verify Database, if corrupr remove it
        do {
            let _ = try Realm()
        } catch {
            if let databaseFilePath = databaseFilePath {
                do {
                    #if !EXTENSION
                    NCContentPresenter.shared.messageNotification("_error_", description: "_database_corrupt_", delay: TimeInterval(k_dismissAfterSecondLong), type: NCContentPresenter.messageType.info, errorCode: 0)
                    #endif
                    try FileManager.default.removeItem(at: databaseFilePath)
                } catch {}
            }
        }
        
        // Open Real
        _ = try! Realm()
    }
    
    //MARK: -
    //MARK: Utility Database

    @objc func clearTable(_ table : Object.Type, account: String?) {
        
        let results : Results<Object>
        
        let realm = try! Realm()

        realm.beginWrite()
        
        if let account = account {
            results = realm.objects(table).filter("account == %@", account)
        } else {
            results = realm.objects(table)
        }
        
        realm.delete(results)

        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func clearDatabase(account: String?, removeAccount: Bool) {
        
        self.clearTable(tableActivity.self, account: account)
        self.clearTable(tableActivityPreview.self, account: account)
        self.clearTable(tableActivitySubjectRich.self, account: account)
        self.clearTable(tableCapabilities.self, account: account)
        self.clearTable(tableComments.self, account: account)
        self.clearTable(tableDirectEditingCreators.self, account: account)
        self.clearTable(tableDirectEditingEditors.self, account: account)
        self.clearTable(tableDirectory.self, account: account)
        self.clearTable(tableE2eEncryption.self, account: account)
        self.clearTable(tableE2eEncryptionLock.self, account: account)
        self.clearTable(tableExternalSites.self, account: account)
        self.clearTable(tableGPS.self, account: nil)
        self.clearTable(tableLocalFile.self, account: account)
        self.clearTable(tableMedia.self, account: account)
        self.clearTable(tableMetadata.self, account: account)
        self.clearTable(tablePhotoLibrary.self, account: account)
        self.clearTable(tableShare.self, account: account)
        self.clearTable(tableTag.self, account: account)
        self.clearTable(tableTrash.self, account: account)
        
        if removeAccount {
            self.clearTable(tableAccount.self, account: account)
        }
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
                print("[LOG] Could not write to database: ", error)
            }
        }
    }
    
    @objc func getThreadConfined(_ object: Object) -> Any {
     
        // id tradeReference = [[NCManageDatabase sharedInstance] getThreadConfined:metadata];
        return ThreadSafeReference(to: object)
    }
    
    @objc func putThreadConfined(_ tableRef: Any) -> Object? {
        
        //tableMetadata *metadataThread = (tableMetadata *)[[NCManageDatabase sharedInstance] putThreadConfined:tradeReference];
        let realm = try! Realm()
        
        return realm.resolve(tableRef as! ThreadSafeReference<Object>)
    }
    
    @objc func isTableInvalidated(_ object: Object) -> Bool {
     
        return object.isInvalidated
    }
    
    //MARK: -
    //MARK: Table Account
    
    @objc func addAccount(_ account: String, url: String, user: String, password: String) {

        let realm = try! Realm()

        realm.beginWrite()
            
        let addObject = tableAccount()
            
        addObject.account = account
        
        // Brand
        if NCBrandOptions.sharedInstance.use_default_auto_upload {
                
            addObject.autoUpload = true
            addObject.autoUploadImage = true
            addObject.autoUploadVideo = true

            addObject.autoUploadWWAnVideo = true
        }
        
        CCUtility.setPassword(account, password: password)
    
        addObject.url = url
        addObject.user = user
        addObject.userID = user
        
        realm.add(addObject)
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func updateAccount(_ account: tableAccount) {
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                realm.add(account, update: .all)
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func deleteAccount(_ account: String) {
        
        let realm = try! Realm()

        realm.beginWrite()

        let result = realm.objects(tableAccount.self).filter("account == %@", account)
        realm.delete(result)
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }

    @objc func getAccountActive() -> tableAccount? {
        
        let realm = try! Realm()
        realm.refresh()
        
        guard let result = realm.objects(tableAccount.self).filter("active == true").first else {
            return nil
        }
        
        return tableAccount.init(value: result)
    }

    @objc func getAccounts() -> [String]? {
        
        let realm = try! Realm()
        realm.refresh()
        
        let results = realm.objects(tableAccount.self).sorted(byKeyPath: "account", ascending: true)
        
        if results.count > 0 {
            return Array(results.map { $0.account })
        }
        
        return nil
    }
    
    @objc func getAccount(predicate: NSPredicate) -> tableAccount? {
        
        let realm = try! Realm()
        realm.refresh()
        
        if let result = realm.objects(tableAccount.self).filter(predicate).first {
            return tableAccount.init(value: result)
        }
        
        return nil
    }
    
    @objc func getAllAccount() -> [tableAccount] {
        
        let realm = try! Realm()
        realm.refresh()
        
        let results = realm.objects(tableAccount.self)
        
        return Array(results.map { tableAccount.init(value:$0) })
    }
    
    @objc func getAccountAutoUploadFileName() -> String {
        
        let realm = try! Realm()
        realm.refresh()
        
        guard let result = realm.objects(tableAccount.self).filter("active == true").first else {
            return ""
        }
        
        if result.autoUploadFileName.count > 0 {
            return result.autoUploadFileName
        } else {
            return NCBrandOptions.sharedInstance.folderDefaultAutoUpload
        }
    }
    
    @objc func getAccountAutoUploadDirectory(_ activeUrl : String) -> String {
        
        let realm = try! Realm()
        realm.refresh()
        
        guard let result = realm.objects(tableAccount.self).filter("active == true").first else {
            return ""
        }
        
        if result.autoUploadDirectory.count > 0 {
            return result.autoUploadDirectory
        } else {
            return CCUtility.getHomeServerUrlActiveUrl(activeUrl)
        }
    }

    @objc func getAccountAutoUploadPath(_ activeUrl : String) -> String {
        
        let cameraFileName = self.getAccountAutoUploadFileName()
        let cameraDirectory = self.getAccountAutoUploadDirectory(activeUrl)
     
        let folderPhotos = CCUtility.stringAppendServerUrl(cameraDirectory, addFileName: cameraFileName)!
        
        return folderPhotos
    }
    
    @objc func setAccountActive(_ account: String) -> tableAccount? {
        
        let realm = try! Realm()

        var activeAccount = tableAccount()
        
        do {
            try realm.write {
            
                let results = realm.objects(tableAccount.self)

                for result in results {
                
                    if result.account == account {
                    
                        result.active = true
                        activeAccount = result
                    
                    } else {
                    
                        result.active = false
                    }
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return nil
        }
        
        return tableAccount.init(value: activeAccount)
    }
    
    @objc func removePasswordAccount(_ account: String) {
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                
                guard let result = realm.objects(tableAccount.self).filter("account == %@", account).first else {
                    return
                }
                
                result.password = "********"
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }

    @objc func setAccountAutoUploadProperty(_ property: String, state: Bool) {
        
        let realm = try! Realm()

        realm.beginWrite()

        guard let result = realm.objects(tableAccount.self).filter("active == true").first else {
            realm.cancelWrite()
            return
        }
        
        if (tableAccount().objectSchema.properties.contains { $0.name == property }) {
            
            result[property] = state
            
            do {
                try realm.commitWrite()
            } catch let error {
                print("[LOG] Could not write to database: ", error)
            }
        } else {
            print("[LOG] property not found")
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
            print("[LOG] Could not write to database: ", error)
        }
    }

    @objc func setAccountAutoUploadDirectory(_ serverUrl: String?, activeUrl: String) {
        
        let realm = try! Realm()

        do {
            try realm.write {
                
                if let result = realm.objects(tableAccount.self).filter("active == true").first {
                    
                    if let serverUrl = serverUrl {
                        
                        result.autoUploadDirectory = serverUrl
                        
                    } else {
                        
                        result.autoUploadDirectory = self.getAccountAutoUploadDirectory(activeUrl)
                    }
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func setAccountUserProfile(_ userProfile: NCUserProfile) -> tableAccount? {
     
        let realm = try! Realm()

        var returnAccount = tableAccount()

        do {
            guard let activeAccount = self.getAccountActive() else {
                return nil
            }
            
            try realm.write {
                
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
                result.userID = userProfile.userID
                result.webpage = userProfile.webpage
                
                returnAccount = result
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
        
        return tableAccount.init(value: returnAccount)
    }
    
    @objc func setAccountUserProfileHC(businessSize: String, businessType: String, city: String, company: String, country: String, role: String, zip: String) -> tableAccount? {
     
        let realm = try! Realm()

        var returnAccount = tableAccount()

        do {
            guard let activeAccount = self.getAccountActive() else {
                return nil
            }
            
            try realm.write {
                
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
            print("[LOG] Could not write to database: ", error)
        }
        
        return tableAccount.init(value: returnAccount)
    }
    
    #if !EXTENSION
    @objc func setAccountHCFeatures(_ features: HCFeatures) -> tableAccount? {
        
        let realm = try! Realm()
        
        var returnAccount = tableAccount()

        do {
            guard let activeAccount = self.getAccountActive() else {
                return nil
            }
            
            try realm.write {
                
                guard let result = realm.objects(tableAccount.self).filter("account == %@", activeAccount.account).first else {
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
    
    @objc func setAccountDateSearchContentTypeImageVideo(_ date: Date) {
        
        guard let activeAccount = self.getAccountActive() else {
            return
        }
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                
                guard let result = realm.objects(tableAccount.self).filter("account == %@", activeAccount.account).first else {
                    return
                }
                
                result.dateSearchContentTypeImageVideo = date
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    //MARK: -
    //MARK: Table Activity

    #if !EXTENSION
    @objc func addActivity(_ listOfActivity: [OCActivity], account: String) {
    
        let realm = try! Realm()

        do {
            try realm.write {
            
                for activity in listOfActivity {
                    
                    let addObjectActivity = tableActivity()
                    
                    addObjectActivity.account = account
                    addObjectActivity.idActivity = activity.idActivity
                    addObjectActivity.idPrimaryKey = account + String(activity.idActivity)
            
                    if let date = activity.date {
                        addObjectActivity.date = date as NSDate
                    }
                    
                    addObjectActivity.app = activity.app
                    addObjectActivity.type = activity.type
                    addObjectActivity.user = activity.user
                    addObjectActivity.subject = activity.subject
                    
                    if activity.subject_rich.count > 0 {
                        addObjectActivity.subjectRich = activity.subject_rich[0] as? String ?? ""
                        if activity.subject_rich.count > 1 {
                            if let dict = activity.subject_rich[1] as? [String:AnyObject] {
                                for (key, value) in dict {
                                    let addObjectActivitySubjectRich = tableActivitySubjectRich()
                                    if let dict = value as? [String:AnyObject] {
                                        addObjectActivitySubjectRich.account = account
                                        switch dict["id"] {
                                        case is String:
                                            addObjectActivitySubjectRich.id = dict["id"] as? String ?? ""
                                        case is Int:
                                            addObjectActivitySubjectRich.id = String(dict["id"] as? Int ?? 0)
                                        default: addObjectActivitySubjectRich.id = ""
                                        }
                                        addObjectActivitySubjectRich.name = dict["name"] as? String ?? ""
                                        addObjectActivitySubjectRich.idPrimaryKey = account + String(activity.idActivity) + addObjectActivitySubjectRich.id + addObjectActivitySubjectRich.name
                                        addObjectActivitySubjectRich.key = key
                                        addObjectActivitySubjectRich.idActivity = activity.idActivity
                                        addObjectActivitySubjectRich.link = dict["link"] as? String ?? ""
                                        addObjectActivitySubjectRich.path = dict["path"] as? String ?? ""
                                        addObjectActivitySubjectRich.type = dict["type"] as? String ?? ""

                                        realm.add(addObjectActivitySubjectRich, update: .all)
                                    }
                                }
                            }
                        }
                    }
                    
                    if activity.previews.count > 0 {
                        for case let activityPreview as [String:AnyObject] in activity.previews {
                            let addObjectActivityPreview = tableActivityPreview()
                            addObjectActivityPreview.account = account
                            addObjectActivityPreview.idActivity = activity.idActivity
                            addObjectActivityPreview.fileId = activityPreview["fileId"] as? Int ?? 0
                            addObjectActivityPreview.idPrimaryKey = account + String(activity.idActivity) + String(addObjectActivityPreview.fileId)
                            addObjectActivityPreview.source = activityPreview["source"] as? String ?? ""
                            addObjectActivityPreview.link = activityPreview["link"] as? String ?? ""
                            addObjectActivityPreview.mimeType = activityPreview["mimeType"] as? String ?? ""
                            addObjectActivityPreview.view = activityPreview["view"] as? String ?? ""
                            addObjectActivityPreview.isMimeTypeIcon = activityPreview["isMimeTypeIcon"] as? Bool ?? false
                            
                            realm.add(addObjectActivityPreview, update: .all)
                        }
                    }
                    
                    addObjectActivity.icon = activity.icon
                    addObjectActivity.link = activity.link
                    addObjectActivity.message = activity.message
                    addObjectActivity.objectType = activity.object_type
                    addObjectActivity.objectId = activity.object_id
                    addObjectActivity.objectName = activity.object_name
                    
                    realm.add(addObjectActivity, update: .all)
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    #endif
    
    func getActivity(predicate: NSPredicate, filterFileId: String?) -> (all: [tableActivity], filter: [tableActivity]) {
        
        let realm = try! Realm()
        realm.refresh()
        
        let results = realm.objects(tableActivity.self).filter(predicate).sorted(byKeyPath: "idActivity", ascending: false)
        let allActivity = Array(results.map { tableActivity.init(value:$0) })
        if filterFileId != nil {
            var resultsFilter = [tableActivity]()
            for result in results {
                let resultsActivitySubjectRich = realm.objects(tableActivitySubjectRich.self).filter("account == %@ && idActivity == %d", result.account, result.idActivity)
                for resultActivitySubjectRich in resultsActivitySubjectRich {
                    if filterFileId!.contains(resultActivitySubjectRich.id) && resultActivitySubjectRich.key == "file" {
                        resultsFilter.append(result)
                        break
                    }
                }
            }
            return(all: allActivity, filter: Array(resultsFilter.map { tableActivity.init(value:$0) }))
        } else {
            return(all: allActivity, filter: allActivity)
        }
    }
    
    @objc func getActivitySubjectRich(account: String, idActivity: Int, key: String) -> tableActivitySubjectRich? {
        
        let realm = try! Realm()
        realm.refresh()
        
        let results = realm.objects(tableActivitySubjectRich.self).filter("account == %@ && idActivity == %d && key == %@", account, idActivity, key).first
        
        return results.map { tableActivitySubjectRich.init(value:$0) }
    }
    
    @objc func getActivitySubjectRich(account: String, idActivity: Int, id: String) -> tableActivitySubjectRich? {
        
        let realm = try! Realm()
        realm.refresh()
        
        let results = realm.objects(tableActivitySubjectRich.self).filter("account == %@ && idActivity == %d && id == %@", account, idActivity, id).first
        
        return results.map { tableActivitySubjectRich.init(value:$0) }
    }
    
    @objc func getActivityPreview(account: String, idActivity: Int, orderKeysId: [String]) -> [tableActivityPreview] {
        
        let realm = try! Realm()
        realm.refresh()
        
        var results = [tableActivityPreview]()
        
        for id in orderKeysId {
            if let result = realm.objects(tableActivityPreview.self).filter("account == %@ && idActivity == %d && fileId == %d", account, idActivity, Int(id) ?? 0).first {
                results.append(result)
            }
        }
        
        return results
    }
    
    @objc func getActivityLastIdActivity(account: String) -> Int {
        
        let realm = try! Realm()
        realm.refresh()
        
        if let entities = realm.objects(tableActivity.self).filter("account == %@", account).max(by: { $0.idActivity < $1.idActivity }) {
            return entities.idActivity
        }
        
        return 0
    }
    
    //MARK: -
    //MARK: Table Capabilities
    
    @objc func addCapabilitiesJSon(_ data: Data, account: String) {
                           
        let realm = try! Realm()

        realm.beginWrite()
               
        let addObject = tableCapabilities()
                       
        addObject.account = account
        addObject.jsondata = data
      
        realm.add(addObject, update: .all)
               
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func getCapabilitiesServerString(account: String, elements: Array<String>) -> String? {

        let realm = try! Realm()
        realm.refresh()
        
        guard let result = realm.objects(tableCapabilities.self).filter("account == %@", account).first else {
            return nil
        }
        guard let jsondata = result.jsondata else {
            return nil
        }
        
        let json = JSON(jsondata)
        return json[elements].string
    }
    
    @objc func getCapabilitiesServerInt(account: String, elements: Array<String>) -> Int {

        let realm = try! Realm()
        realm.refresh()
        
        guard let result = realm.objects(tableCapabilities.self).filter("account == %@", account).first else {
            return 0
        }
        guard let jsondata = result.jsondata else {
            return 0
        }
        
        let json = JSON(jsondata)
        return json[elements].intValue
    }
    
    @objc func getCapabilitiesServerBool(account: String, elements: Array<String>, exists: Bool) -> Bool {

        let realm = try! Realm()
        realm.refresh()
        
        guard let result = realm.objects(tableCapabilities.self).filter("account == %@", account).first else {
            return false
        }
        guard let jsondata = result.jsondata else {
            return false
        }
        
        let json = JSON(jsondata)
        if exists {
            return json[elements].exists()
        } else {
            return json[elements].boolValue
        }        
    }
    
    @objc func getCapabilitiesServerArray(account: String, elements: Array<String>) -> [String]? {

        let realm = try! Realm()
        var resultArray = [String]()
        realm.refresh()
        
        guard let result = realm.objects(tableCapabilities.self).filter("account == %@", account).first else {
            return nil
        }
        guard let jsondata = result.jsondata else {
            return nil
        }
        
        let json = JSON(jsondata)
       
        if let results = json[elements].array {
            for result in results {
                resultArray.append(result.string ?? "")
            }
            return resultArray
        }
        
        return nil
    }
    
    //MARK: -
    //MARK: Table Comments
    
    #if !EXTENSION
    @objc func addComments(_ listOfComments: [NCComments], account: String, objectId: String) {
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                
                let results = realm.objects(tableComments.self).filter("account == %@ AND objectId == %@", account, objectId)
                realm.delete(results)
                
                for comment in listOfComments {
                    
                    let addObject = tableComments()
                    
                    addObject.account = account
                    addObject.actorDisplayName = comment.actorDisplayName
                    addObject.actorId = comment.actorId
                    addObject.actorType = comment.actorType
                    addObject.creationDateTime = comment.creationDateTime as NSDate
                    addObject.isUnread = comment.isUnread
                    addObject.message = comment.message
                    addObject.messageID = comment.messageID
                    addObject.objectId = comment.objectId
                    addObject.objectType = comment.objectType
                    addObject.verb = comment.verb
                    
                    realm.add(addObject, update: .all)
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    #endif
    
    @objc func getComments(account: String, objectId: String) -> [tableComments] {
        
        let realm = try! Realm()
        realm.refresh()
        
        let results = realm.objects(tableComments.self).filter("account == %@ AND objectId == %@", account, objectId).sorted(byKeyPath: "creationDateTime", ascending: false)
        
        return Array(results.map { tableComments.init(value:$0) })
    }
    
    //MARK: -
    //MARK: Table Direct Editing
    
    @objc func addDirectEditing(account: String, editors: [NCEditorDetailsEditors], creators: [NCEditorDetailsCreators]) {
        
        let realm = try! Realm()

        do {
            try realm.write {
            
                let resultsCreators = realm.objects(tableDirectEditingCreators.self).filter("account == %@", account)
                realm.delete(resultsCreators)
                
                let resultsEditors = realm.objects(tableDirectEditingEditors.self).filter("account == %@", account)
                realm.delete(resultsEditors)
                
                for creator in creators {
                    
                    let addObject = tableDirectEditingCreators()
                    
                    addObject.account = account
                    addObject.editor = creator.editor
                    addObject.ext = creator.ext
                    addObject.identifier = creator.identifier
                    addObject.mimetype = creator.mimetype
                    addObject.name = creator.name
                    addObject.templates = creator.templates
                    
                    realm.add(addObject)
                }
                
                for editor in editors {
                    
                    let addObject = tableDirectEditingEditors()
                    
                    addObject.account = account
                    for mimeType in editor.mimetypes {
                        addObject.mimetypes.append(mimeType)
                    }
                    addObject.name = editor.name
                    if editor.name.lowercased() == "onlyoffice" {
                        addObject.editor = "onlyoffice"
                    } else if editor.name.lowercased() == "nextcloud text" {
                        addObject.editor = "text"
                    }
                    for mimeType in editor.optionalMimetypes {
                        addObject.optionalMimetypes.append(mimeType)
                    }
                    addObject.secure = editor.secure
                    
                    realm.add(addObject)
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func getDirectEditingCreators(account: String) -> [tableDirectEditingCreators]? {
        
        let realm = try! Realm()
        let results = realm.objects(tableDirectEditingCreators.self).filter("account == %@", account)
        
        if (results.count > 0) {
            return Array(results.map { tableDirectEditingCreators.init(value:$0) })
        } else {
            return nil
        }
    }
    
    @objc func getDirectEditingCreators(predicate: NSPredicate) -> [tableDirectEditingCreators]? {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableDirectEditingCreators.self).filter(predicate)
        
        if (results.count > 0) {
            return Array(results.map { tableDirectEditingCreators.init(value:$0) })
        } else {
            return nil
        }
    }
    
    @objc func getDirectEditingEditors(account: String) -> [tableDirectEditingEditors]? {
        
        let realm = try! Realm()
        let results = realm.objects(tableDirectEditingEditors.self).filter("account == %@", account)
        
        if (results.count > 0) {
            return Array(results.map { tableDirectEditingEditors.init(value:$0) })
        } else {
            return nil
        }
    }
    
    //MARK: -
    //MARK: Table Directory
    
    @discardableResult
    @objc func addDirectory(encrypted: Bool, favorite: Bool, ocId: String, fileId: String, etag: String?, permissions: String?, serverUrl: String, richWorkspace: String?, account: String) -> tableDirectory? {
        
        let realm = try! Realm()
        realm.beginWrite()
        
        var addObject = tableDirectory()
        
        let result = realm.objects(tableDirectory.self).filter("ocId == %@", ocId).first
        if result != nil {
            addObject = result!
        } else {
            addObject.ocId = ocId
        }
        addObject.account = account
        addObject.e2eEncrypted = encrypted
        addObject.favorite = favorite
        addObject.fileId = fileId
        if let etag = etag {
            addObject.etag = etag
        }
        if let permissions = permissions {
            addObject.permissions = permissions
        }
        if let richWorkspace = richWorkspace {
            addObject.richWorkspace = richWorkspace
        }
        addObject.serverUrl = serverUrl
        
        realm.add(addObject, update: .all)
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return nil
        }
    
        return tableDirectory.init(value: addObject)
    }
    
    @objc func deleteDirectoryAndSubDirectory(serverUrl: String, account: String) {
        
        let realm = try! Realm()
        realm.refresh()
        
        let results = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl BEGINSWITH %@", account, serverUrl)
        
        // Delete table Metadata & LocalFile
        for result in results {
            
            self.deleteMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", result.account, result.serverUrl))
            self.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", result.ocId))
        }
        
        // Delete table Dirrectory
        do {
            try realm.write {
                realm.delete(results)
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func setDirectory(serverUrl: String, serverUrlTo: String?, etag: String?, ocId: String?, fileId: String?, encrypted: Bool, richWorkspace: String?, account: String) {
        
        let realm = try! Realm()

        do {
            try realm.write {
            
                guard let result = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).first else {
                    return
                }
                
                let directory = tableDirectory.init(value: result)
                
                realm.delete(result)
                
                directory.e2eEncrypted = encrypted
                if let etag = etag {
                    directory.etag = etag
                }
                if let ocId = ocId {
                    directory.ocId = ocId
                }
                if let fileId = fileId {
                    directory.fileId = fileId
                }
                if let serverUrlTo = serverUrlTo {
                    directory.serverUrl = serverUrlTo
                }
                if let richWorkspace = richWorkspace {
                    directory.richWorkspace = richWorkspace
                }
                
                realm.add(directory, update: .all)
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func clearDateRead(serverUrl: String, account: String) {
        
        let realm = try! Realm()

        do {
            try realm.write {

                var predicate = NSPredicate()
            
                predicate = NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)
                
                guard let result = realm.objects(tableDirectory.self).filter(predicate).first else {
                    return
                }
                
                result.dateReadDirectory = nil
                result.etag = ""
                realm.add(result, update: .all)
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func getTableDirectory(predicate: NSPredicate) -> tableDirectory? {
        
        let realm = try! Realm()
        realm.refresh()

        guard let result = realm.objects(tableDirectory.self).filter(predicate).first else {
            return nil
        }
        
        return tableDirectory.init(value: result)
    }
    
    @objc func getTablesDirectory(predicate: NSPredicate, sorted: String, ascending: Bool) -> [tableDirectory]? {
        
        let realm = try! Realm()
        realm.refresh()

        let results = realm.objects(tableDirectory.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)
        
        if (results.count > 0) {
            return Array(results.map { tableDirectory.init(value:$0) })
        } else {
            return nil
        }
    }
    
    @objc func setDateReadDirectory(serverUrl: String, account: String) {
        
        let realm = try! Realm()

        realm.beginWrite()

        guard let result = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).first else {
            realm.cancelWrite()
            return
        }
            
        result.dateReadDirectory = NSDate()
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func renameDirectory(ocId: String, serverUrl: String) {
        
        let realm = try! Realm()
        
        realm.beginWrite()
        
        guard let result = realm.objects(tableDirectory.self).filter("ocId == %@", ocId).first else {
            realm.cancelWrite()
            return
        }
        
        result.serverUrl = serverUrl
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func setClearAllDateReadDirectory() {
        
        let realm = try! Realm()

        do {
            try realm.write {
            
                let results = realm.objects(tableDirectory.self)

                for result in results {
                    result.dateReadDirectory = nil;
                    result.etag = ""
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func setDirectory(serverUrl: String, offline: Bool, account: String) {
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                
                guard let result = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).first else {
                    realm.cancelWrite()
                    return
                }
                
                result.offline = offline
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func setDirectory(ocId: String, serverUrl: String, richWorkspace: String, account: String) {
        
        let realm = try! Realm()
        realm.beginWrite()
        
        var addObject = tableDirectory()
        
        let result = realm.objects(tableDirectory.self).filter("ocId == %@", ocId).first
        if result != nil {
            addObject = result!
        } else {
            addObject.ocId = ocId
        }
        addObject.account = account
        addObject.richWorkspace = richWorkspace
        addObject.serverUrl = serverUrl
        
        realm.add(addObject, update: .all)
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }

    //MARK: -
    //MARK: Table e2e Encryption
    
    @objc func addE2eEncryption(_ e2e: tableE2eEncryption) -> Bool {

        guard self.getAccountActive() != nil else {
            return false
        }
        
        let realm = try! Realm()

        do {
            try realm.write {
                realm.add(e2e, update: .all)
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return false
        }
        
        return true
    }
    
    @objc func deleteE2eEncryption(predicate: NSPredicate) {
        
        guard self.getAccountActive() != nil else {
            return
        }
        
        let realm = try! Realm()

        do {
            try realm.write {
                
                let results = realm.objects(tableE2eEncryption.self).filter(predicate)
                realm.delete(results)
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func getE2eEncryption(predicate: NSPredicate) -> tableE2eEncryption? {
        
        guard self.getAccountActive() != nil else {
            return nil
        }
        
        let realm = try! Realm()
        realm.refresh()
        
        guard let result = realm.objects(tableE2eEncryption.self).filter(predicate).sorted(byKeyPath: "metadataKeyIndex", ascending: false).first else {
            return nil
        }
        
        return tableE2eEncryption.init(value: result)
    }
    
    @objc func getE2eEncryptions(predicate: NSPredicate) -> [tableE2eEncryption]? {
        
        guard self.getAccountActive() != nil else {
            return nil
        }
        
        let realm = try! Realm()
        realm.refresh()
        
        let results : Results<tableE2eEncryption>
        
        results = realm.objects(tableE2eEncryption.self).filter(predicate)
        
        if (results.count > 0) {
            return Array(results.map { tableE2eEncryption.init(value:$0) })
        } else {
            return nil
        }
    }
    
    @objc func renameFileE2eEncryption(serverUrl: String, fileNameIdentifier: String, newFileName: String, newFileNamePath: String) {
        
        guard let tableAccount = self.getAccountActive() else {
            return
        }
        
        let realm = try! Realm()

        realm.beginWrite()

        guard let result = realm.objects(tableE2eEncryption.self).filter("account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", tableAccount.account, serverUrl, fileNameIdentifier).first else {
            realm.cancelWrite()
            return 
        }
        
        let object = tableE2eEncryption.init(value: result)
        
        realm.delete(result)

        object.fileName = newFileName
        object.fileNamePath = newFileNamePath

        realm.add(object)

        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return
        }
        
        return
    }
    
    //MARK: -
    //MARK: Table e2e Encryption Lock
    
    @objc func getE2ETokenLock(serverUrl: String) -> tableE2eEncryptionLock? {
        
        guard let tableAccount = self.getAccountActive() else {
            return nil
        }
        
        let realm = try! Realm()
        realm.refresh()
            
        guard let result = realm.objects(tableE2eEncryptionLock.self).filter("account == %@ AND serverUrl == %@", tableAccount.account, serverUrl).first else {
            return nil
        }
        
        return tableE2eEncryptionLock.init(value: result)
    }
    
    @objc func setE2ETokenLock(serverUrl: String, fileId: String, e2eToken: String) {
        
        guard let tableAccount = self.getAccountActive() else {
            return
        }
            
        let realm = try! Realm()

        realm.beginWrite()
        
        let addObject = tableE2eEncryptionLock()
                
        addObject.account = tableAccount.account
        addObject.fileId = fileId
        addObject.serverUrl = serverUrl
        addObject.e2eToken = e2eToken
                
        realm.add(addObject, update: .all)
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func deteleE2ETokenLock(serverUrl: String) {
        
        guard let tableAccount = self.getAccountActive() else {
            return
        }
            
        let realm = try! Realm()

        realm.beginWrite()

        guard let result = realm.objects(tableE2eEncryptionLock.self).filter("account == %@ AND serverUrl == %@", tableAccount.account, serverUrl).first else {
            return
        }
            
        realm.delete(result)
            
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }

    //MARK: -
    //MARK: Table External Sites
    
    #if !EXTENSION
    @objc func addExternalSites(_ externalSites: OCExternalSites, account: String) {
        
        let realm = try! Realm()

        do {
            try realm.write {
            
                let addObject = tableExternalSites()
            
                addObject.account = account
                addObject.idExternalSite = externalSites.idExternalSite
                addObject.icon = externalSites.icon
                addObject.lang = externalSites.lang
                addObject.name = externalSites.name
                addObject.url = externalSites.url
                addObject.type = externalSites.type
           
                realm.add(addObject)
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    #endif
    
    @objc func deleteExternalSites(account: String) {
        
        let realm = try! Realm()

        do {
            try realm.write {
            
                let results = realm.objects(tableExternalSites.self).filter("account == %@", account)
                realm.delete(results)
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func getAllExternalSites(account: String) -> [tableExternalSites]? {
        
        let realm = try! Realm()
        realm.refresh()
        
        let results = realm.objects(tableExternalSites.self).filter("account == %@", account).sorted(byKeyPath: "idExternalSite", ascending: true)
        
        return Array(results)
    }

    //MARK: -
    //MARK: Table GPS
    
    @objc func addGeocoderLocation(_ location: String, placemarkAdministrativeArea: String, placemarkCountry: String, placemarkLocality: String, placemarkPostalCode: String, placemarkThoroughfare: String, latitude: String, longitude: String) {

        let realm = try! Realm()

        realm.beginWrite()

        // Verify if exists
        guard realm.objects(tableGPS.self).filter("latitude == %@ AND longitude == %@", latitude, longitude).first == nil else {
            realm.cancelWrite()
            return
        }
        
        // Add new GPS
        let addObject = tableGPS()
            
        addObject.latitude = latitude
        addObject.location = location
        addObject.longitude = longitude
        addObject.placemarkAdministrativeArea = placemarkAdministrativeArea
        addObject.placemarkCountry = placemarkCountry
        addObject.placemarkLocality = placemarkLocality
        addObject.placemarkPostalCode = placemarkPostalCode
        addObject.placemarkThoroughfare = placemarkThoroughfare
            
        realm.add(addObject)
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func getLocationFromGeoLatitude(_ latitude: String, longitude: String) -> String? {
        
        let realm = try! Realm()
        realm.refresh()
        
        guard let result = realm.objects(tableGPS.self).filter("latitude == %@ AND longitude == %@", latitude, longitude).first else {
            return nil
        }
        
        return result.location
    }

    //MARK: -
    //MARK: Table LocalFile
    
    @objc func addLocalFile(metadata: tableMetadata) -> tableLocalFile? {
        
        let realm = try! Realm()
        let addObject = tableLocalFile()

        do {
            try realm.write {
            
                addObject.account = metadata.account
                addObject.date = metadata.date
                addObject.etag = metadata.etag
                addObject.exifDate = NSDate()
                addObject.exifLatitude = "-1"
                addObject.exifLongitude = "-1"
                addObject.ocId = metadata.ocId
                addObject.fileName = metadata.fileName
                addObject.size = metadata.size
            
                realm.add(addObject, update: .all)
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return nil
        }
        
        return tableLocalFile.init(value: addObject)
    }
    
    @objc func deleteLocalFile(predicate: NSPredicate) {
        
        let realm = try! Realm()

        do {
            try realm.write {

                let results = realm.objects(tableLocalFile.self).filter(predicate)
                realm.delete(results)
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func setLocalFile(ocId: String, date: NSDate?, exifDate: NSDate?, exifLatitude: String?, exifLongitude: String?, fileName: String?, etag: String?) {
        
        let realm = try! Realm()

        do {
            try realm.write {
                
                guard let result = realm.objects(tableLocalFile.self).filter("ocId == %@", ocId).first else {
                    realm.cancelWrite()
                    return
                }
                
                if let date = date {
                    result.date = date
                }
                if let exifDate = exifDate {
                    result.exifDate = exifDate
                }
                if let exifLatitude = exifLatitude {
                    result.exifLatitude = exifLatitude
                }
                if let exifLongitude = exifLongitude {
                    result.exifLongitude = exifLongitude
                }
                if let fileName = fileName {
                    result.fileName = fileName
                }
                if let etag = etag {
                    result.etag = etag
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func getTableLocalFile(predicate: NSPredicate) -> tableLocalFile? {
        
        let realm = try! Realm()
        realm.refresh()
        
        guard let result = realm.objects(tableLocalFile.self).filter(predicate).first else {
            return nil
        }

        return tableLocalFile.init(value: result)
    }
    
    @objc func getTableLocalFiles(predicate: NSPredicate, sorted: String, ascending: Bool) -> [tableLocalFile]? {
        
        let realm = try! Realm()
        realm.refresh()
        
        let results = realm.objects(tableLocalFile.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)
        
        if (results.count > 0) {
            return Array(results.map { tableLocalFile.init(value:$0) })
        } else {
            return nil
        }
    }
    
    @objc func setLocalFile(ocId: String, offline: Bool) {
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                
                guard let result = realm.objects(tableLocalFile.self).filter("ocId == %@", ocId).first else {
                    realm.cancelWrite()
                    return
                }
                
                result.offline = offline
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }

    //MARK: -
    //MARK: Table Metadata
    
    @objc func initNewMetadata(_ metadata: tableMetadata) -> tableMetadata {
        return tableMetadata.init(value: metadata)
    }
    
    @objc func convertNCFileToMetadata(_ file: NCFile, isEncrypted: Bool, account: String) -> tableMetadata {
        
        let metadata = tableMetadata()
        
        metadata.account = account
        metadata.commentsUnread = file.commentsUnread
        metadata.contentType = file.contentType
        metadata.creationDate = file.creationDate
        metadata.date = file.date
        metadata.directory = file.directory
        metadata.e2eEncrypted = file.e2eEncrypted
        metadata.etag = file.etag
        metadata.favorite = file.favorite
        metadata.fileId = file.fileId
        metadata.fileName = file.fileName
        metadata.fileNameView = file.fileName
        metadata.hasPreview = file.hasPreview
        metadata.iconName = file.iconName
        metadata.mountType = file.mountType
        metadata.ocId = file.ocId
        metadata.ownerId = file.ownerId
        metadata.ownerDisplayName = file.ownerDisplayName
        metadata.permissions = file.permissions
        metadata.quotaUsedBytes = file.quotaUsedBytes
        metadata.quotaAvailableBytes = file.quotaAvailableBytes
        metadata.richWorkspace = file.richWorkspace
        metadata.resourceType = file.resourceType
        metadata.serverUrl = file.serverUrl
        metadata.size = file.size
        metadata.typeFile = file.typeFile
        
        // E2EE find the fileName for fileNameView
        if isEncrypted || metadata.e2eEncrypted {
            if let tableE2eEncryption = NCManageDatabase.sharedInstance.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", account, file.serverUrl, file.fileName)) {
                metadata.fileNameView = tableE2eEncryption.fileName
                let results = NCCommunicationCommon.shared.getInternalContenType(fileName: metadata.fileNameView, contentType: file.contentType, directory: file.directory)
                metadata.contentType = results.contentType
                metadata.iconName = results.iconName
                metadata.typeFile = results.typeFile
            }
        }
        
        return metadata
    }
    
    @objc func convertNCFilesToMetadatas(_ files: [NCFile], useMetadataFolder: Bool, account: String, completion: @escaping (_ metadataFolder: tableMetadata,_ metadatasFolder: [tableMetadata], _ metadatas: [tableMetadata])->())  {
    
        var counter: Int = 0
        var isEncrypted: Bool = false
        var listServerUrl = [String:Bool]()
        
        var metadataFolder = tableMetadata()
        var metadataFolders = [tableMetadata]()
        var metadatas = [tableMetadata]()

        for file in files {
                        
            if let key = listServerUrl[file.serverUrl] {
                isEncrypted = key
            } else {
                isEncrypted = CCUtility.isFolderEncrypted(file.serverUrl, e2eEncrypted: file.e2eEncrypted, account: account)
                listServerUrl[file.serverUrl] = isEncrypted
            }
            
            let metadata = convertNCFileToMetadata(file, isEncrypted: isEncrypted, account: account)
            
            if counter == 0 && useMetadataFolder {
                metadataFolder = tableMetadata.init(value: metadata)
            } else {
                metadatas.append(metadata)
                if metadata.directory {
                    metadataFolders.append(metadata)
                }
            }
            
            counter += 1
        }
        
        completion(metadataFolder, metadataFolders, metadatas)
    }
    
    @objc func createMetadata(account: String, fileName: String, ocId: String, serverUrl: String, url: String, contentType: String) -> tableMetadata {
        
        let metadata = tableMetadata()
        let results = NCCommunicationCommon.shared.getInternalContenType(fileName: fileName, contentType: contentType, directory: false)
        
        metadata.account = account
        metadata.contentType = results.contentType
        metadata.date = Date() as NSDate
        metadata.iconName = results.iconName
        metadata.ocId = ocId
        metadata.fileName = fileName
        metadata.fileNameView = fileName
        metadata.serverUrl = serverUrl
        metadata.typeFile = results.typeFile
        metadata.url = url
        return metadata
    }
    
    @discardableResult
    @objc func addMetadata(_ metadata: tableMetadata) -> tableMetadata? {
            
        let serverUrl = metadata.serverUrl
        let account = metadata.account
        
        let realm = try! Realm()

        do {
            try realm.write {
                realm.add(metadata, update: .all)
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return nil
        }
        
        self.setDateReadDirectory(serverUrl: serverUrl, account: account)
        
        return tableMetadata.init(value: metadata)
    }
    
    @discardableResult
    @objc func addMetadatas(_ metadatas: [tableMetadata]) -> [tableMetadata]? {
        
        var directoryToClearDate = [String:String]()

        let realm = try! Realm()

        do {
            try realm.write {
                for metadata in metadatas {
                    directoryToClearDate[metadata.serverUrl] = metadata.account
                    realm.add(metadata, update: .all)
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return nil
        }
        
        for (serverUrl, account) in directoryToClearDate {
            self.setDateReadDirectory(serverUrl: serverUrl, account: account)
        }
        
        return Array(metadatas.map { tableMetadata.init(value:$0) })
    }

    @objc func addMetadatas(files: [NCFile]?, account: String) {
    
        guard let files = files else { return }
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                for file in files {
                    
                    let metadata = tableMetadata()
                    
                    metadata.account = account
                    metadata.commentsUnread = file.commentsUnread
                    metadata.contentType = file.contentType
                    metadata.date = file.date
                    metadata.directory = file.directory
                    metadata.e2eEncrypted = file.e2eEncrypted
                    metadata.etag = file.etag
                    metadata.favorite = file.favorite
                    metadata.fileId = file.fileId
                    metadata.fileName = file.fileName
                    metadata.fileNameView = file.fileName
                    metadata.hasPreview = file.hasPreview
                    metadata.iconName = file.iconName
                    metadata.mountType = file.mountType
                    metadata.ocId = file.ocId
                    metadata.ownerId = file.ownerId
                    metadata.ownerDisplayName = file.ownerDisplayName
                    metadata.permissions = file.permissions
                    metadata.quotaUsedBytes = file.quotaUsedBytes
                    metadata.quotaAvailableBytes = file.quotaAvailableBytes
                    metadata.resourceType = file.resourceType
                    metadata.serverUrl = file.serverUrl
                    metadata.size = file.size
                    metadata.typeFile = file.typeFile
                    
                    realm.add(metadata, update: .all)
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return
        }        
    }
    
    @objc func deleteMetadata(predicate: NSPredicate) {
        
        var directoryToClearDate = [String:String]()
        
        let realm = try! Realm()

        realm.beginWrite()

        let results = realm.objects(tableMetadata.self).filter(predicate)
        
        for result in results {
            directoryToClearDate[result.serverUrl] = result.account
        }
        
        realm.delete(results)
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return
        }
        
        for (serverUrl, account) in directoryToClearDate {
            self.setDateReadDirectory(serverUrl: serverUrl, account: account)
        }
    }
    
    @discardableResult
    @objc func moveMetadata(ocId: String, serverUrlTo: String) -> tableMetadata? {
        
        var result: tableMetadata?
        let realm = try! Realm()

        do {
            try realm.write {
                result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                if result != nil {
                    result!.serverUrl = serverUrlTo
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return nil
        }
        
        if result == nil {
            return nil
        }
        
        return tableMetadata.init(value: result!)
    }
    
    @objc func addMetadataServerUrl(ocId: String, serverUrl: String) {
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                let results = realm.objects(tableMetadata.self).filter("ocId == %@", ocId)
                for result in results {
                    result.serverUrl = serverUrl
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return
        }
    }
    
    @discardableResult
    @objc func renameMetadata(fileNameTo: String, ocId: String) -> tableMetadata? {
        
        var result: tableMetadata?
        let realm = try! Realm()
        
        do {
            try realm.write {
                result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                if result != nil {
                    result!.fileName = fileNameTo
                    result!.fileNameView = fileNameTo
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return nil
        }
        
        if result == nil {
            return nil
        }
        
        self.setDateReadDirectory(serverUrl: result!.serverUrl, account: result!.account)
        return tableMetadata.init(value: result!)
    }
    
    @objc func updateMetadata(_ metadata: tableMetadata) -> tableMetadata? {
        
        let account = metadata.account
        let serverUrl = metadata.serverUrl
        
        let realm = try! Realm()

        do {
            try realm.write {
                realm.add(metadata, update: .all)
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return nil
        }
        
        self.setDateReadDirectory(serverUrl: serverUrl, account: account)
        
        return tableMetadata.init(value: metadata)
    }
    
    @objc func copyMetadata(_ object: tableMetadata) -> tableMetadata? {
        
        return tableMetadata.init(value: object)
    }
    
    @objc func setMetadataSession(_ session: String?, sessionError: String?, sessionSelector: String?, sessionTaskIdentifier: Int, status: Int, predicate: NSPredicate) {
        
        let realm = try! Realm()

        realm.beginWrite()

        guard let result = realm.objects(tableMetadata.self).filter(predicate).first else {
            realm.cancelWrite()
            return
        }
        
        if let session = session {
            result.session = session
        }
        if let sessionError = sessionError {
            result.sessionError = sessionError
        }
        if let sessionSelector = sessionSelector {
            result.sessionSelector = sessionSelector
        }
        
        result.sessionTaskIdentifier = sessionTaskIdentifier
        result.status = status

        let account = result.account
        let serverUrl = result.serverUrl
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return
        }
        
        // Update Date Read Directory
        self.setDateReadDirectory(serverUrl: serverUrl, account: account)
    }
    
    @objc func setMetadataFavorite(ocId: String, favorite: Bool) {
        
        let realm = try! Realm()

        realm.beginWrite()

        guard let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first else {
            realm.cancelWrite()
            return
        }
        
        result.favorite = favorite

        let account = result.account
        let serverUrl = result.serverUrl
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return
        }
        
        // Update Date Read Directory
        setDateReadDirectory(serverUrl: serverUrl, account: account)
    }
   
    @objc func setMetadataEncrypted(ocId: String, encrypted: Bool) {
           
        let realm = try! Realm()

        realm.beginWrite()

        guard let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first else {
            realm.cancelWrite()
            return
        }
           
        result.e2eEncrypted = encrypted

        let account = result.account
        let serverUrl = result.serverUrl
           
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return
        }
           
        // Update Date Read Directory
        setDateReadDirectory(serverUrl: serverUrl, account: account)
    }
       
    @objc func setMetadataFileNameView(serverUrl: String, fileName: String, newFileNameView: String, account: String) {
        
        let realm = try! Realm()

        realm.beginWrite()

        guard let result = realm.objects(tableMetadata.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@", account, serverUrl, fileName).first else {
            realm.cancelWrite()
            return
        }
                
        result.fileNameView = newFileNameView
        
        let account = result.account
        let serverUrl = result.serverUrl
    
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return
        }
    
        // Update Date Read Directory
        setDateReadDirectory(serverUrl: serverUrl, account: account)
    }
    
    @objc func getMetadata(predicate: NSPredicate) -> tableMetadata? {
        
        let realm = try! Realm()
        realm.refresh()
        
        guard let result = realm.objects(tableMetadata.self).filter(predicate).first else {
            return nil
        }
        
        return tableMetadata.init(value: result)
    }
    
    @objc func getMetadata(predicate: NSPredicate, sorted: String, ascending: Bool) -> tableMetadata? {
        
        let realm = try! Realm()
        realm.refresh()
        
        let results = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)
        
        if (results.count > 0) {
            return tableMetadata.init(value: results[0])
        } else {
            return nil
        }
    }
    
    @objc func getMetadatas(predicate: NSPredicate, sorted: String?, ascending: Bool) -> [tableMetadata]? {
        
        let realm = try! Realm()
        realm.refresh()
        
        let results : Results<tableMetadata>
        
        if let sorted = sorted {
            
            if (tableMetadata().objectSchema.properties.contains { $0.name == sorted }) {
                results = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)
            } else {
                results = realm.objects(tableMetadata.self).filter(predicate)
            }
            
        } else {
            
            results = realm.objects(tableMetadata.self).filter(predicate)
        }
        
        if (results.count > 0) {
            return Array(results.map { tableMetadata.init(value:$0) })
        } else {
            return nil
        }
    }
    
    @objc func getMetadatasViewer(predicate: NSPredicate, sorted: String, ascending: Bool) -> [tableMetadata]? {
        
        let realm = try! Realm()
        realm.refresh()
        
        let results: Results<tableMetadata>
        var finals = [tableMetadata]()
                    
        if (tableMetadata().objectSchema.properties.contains { $0.name == sorted }) {
            results = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)
        } else {
            results = realm.objects(tableMetadata.self).filter(predicate)
        }
        
        // For Live Photo
        var fileNameImages = [String]()
        let filtered = results.filter{ $0.typeFile.contains(k_metadataTypeFile_image) }
        filtered.forEach { print($0)
            let fileName = ($0.fileNameView as NSString).deletingPathExtension
            fileNameImages.append(fileName)
        }
        
        for result in results {
            
            let ext = (result.fileNameView as NSString).pathExtension.uppercased()
            let fileName = (result.fileNameView as NSString).deletingPathExtension
            
            if !(ext == "MOV" && fileNameImages.contains(fileName)) {
                finals.append(result)
            }
        }
        
        if (finals.count > 0) {
            return Array(finals.map { tableMetadata.init(value:$0) })
        } else {
            return nil
        }
    }
    
    @objc func getMetadatas(predicate: NSPredicate, page: Int, limit: Int, sorted: String, ascending: Bool) -> [tableMetadata]? {
        
        let realm = try! Realm()
        realm.refresh()
        
        let results : Results<tableMetadata>
        results = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)
        
        if results.count > 0 {
        
            let nFrom = (page - 1) * limit
            let nTo = nFrom + (limit - 1)
            var metadatas = [tableMetadata]()
            
            for n in nFrom...nTo {
                if n == results.count {
                    break
                }
                let metadata = tableMetadata.init(value: results[n])
                metadatas.append(metadata)
            }
            
            return metadatas
            
        } else {
            
            return nil
        }
    }
    
    @objc func getMetadataAtIndex(predicate: NSPredicate, sorted: String, ascending: Bool, index: Int) -> tableMetadata? {
        
        let realm = try! Realm()
        realm.refresh()
        
        let results = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)
        
        if (results.count > 0  && results.count > index) {
            return tableMetadata.init(value: results[index])
        } else {
            return nil
        }
    }
    
    @objc func getMetadataInSessionFromFileName(_ fileName: String, serverUrl: String, taskIdentifier: Int) -> tableMetadata? {
        
        let realm = try! Realm()
        realm.refresh()
        
        guard let result = realm.objects(tableMetadata.self).filter("serverUrl == %@ AND fileName == %@ AND session != '' AND sessionTaskIdentifier == %d", serverUrl, fileName, taskIdentifier).first else {
            return nil
        }
        
        return tableMetadata.init(value: result)
    }
    
    @objc func getTableMetadatasDirectoryFavoriteIdentifierRank(account: String) -> [String:NSNumber] {
        
        var listIdentifierRank = [String:NSNumber]()

        let realm = try! Realm()
        realm.refresh()
        
        var counter = 10 as Int64
        
        let results = realm.objects(tableMetadata.self).filter("account == %@ AND directory == true AND favorite == true", account).sorted(byKeyPath: "fileNameView", ascending: true)
        
        for result in results {
            counter += 1
            listIdentifierRank[result.ocId] = NSNumber(value: Int64(counter))
        }
        
        return listIdentifierRank
    }
    
    @objc func clearMetadatasUpload(account: String) {
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                
                let results = realm.objects(tableMetadata.self).filter("account == %@ AND (status == %d OR status == %@)", account, k_metadataStatusWaitUpload, k_metadataStatusUploadError)
                realm.delete(results)
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func readMarkerMetadata(account: String, fileId: String) {
        
        let realm = try! Realm()
        
        realm.beginWrite()
        
        let results = realm.objects(tableMetadata.self).filter("account == %@ AND fileId == %@", account, fileId)
        for result in results {
            result.commentsUnread = false
        }
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func getAssetLocalIdentifiersUploaded(account: String, sessionSelector: String) -> [String] {
        
        let realm = try! Realm()
        realm.refresh()
        var assetLocalIdentifiers = [String]()
        
        let results = realm.objects(tableMetadata.self).filter("account == %@ AND assetLocalIdentifier != '' AND deleteAssetLocalIdentifier == true AND sessionSelector == %@", account, sessionSelector)
        for result in results {
            assetLocalIdentifiers.append(result.assetLocalIdentifier)
        }
       
        return assetLocalIdentifiers
    }
    
    @objc func clearAssetLocalIdentifiers(_ assetLocalIdentifiers: [String], account: String) {
        
        let realm = try! Realm()

        do {
            try realm.write {
            
                let results = realm.objects(tableMetadata.self).filter("account == %@ AND assetLocalIdentifier IN %@", account, assetLocalIdentifiers)

                for result in results {
                    result.assetLocalIdentifier = ""
                    result.deleteAssetLocalIdentifier = false
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    //MARK: -
    //MARK: Table Media
 
    @objc func getMedia(predicate: NSPredicate) -> tableMetadata? {
        
        let realm = try! Realm()
        realm.refresh()
        
        guard let result = realm.objects(tableMedia.self).filter(predicate).first else {
            return nil
        }
        
        return tableMetadata.init(value: result)
    }
   
    @objc func getMedias(account: String, predicate: NSPredicate) -> [tableMetadata]? {
        
        let realm = try! Realm()
        realm.refresh()
        
        let sortProperties = [SortDescriptor(keyPath: "date", ascending: false), SortDescriptor(keyPath: "fileNameView", ascending: false)]
        let results = realm.objects(tableMedia.self).filter(predicate).sorted(by: sortProperties)
        if results.count == 0 {
            return nil
        }
                
        var metadatas = [tableMetadata]()
        
        // For Live Photo
        var fileNameImages = [String]()
        let filtered = results.filter{ $0.typeFile.contains(k_metadataTypeFile_image) }
        filtered.forEach { 
            let fileName = ($0.fileNameView as NSString).deletingPathExtension
            fileNameImages.append(fileName)
        }
                
        for result in results {
            let metadata = tableMetadata.init(value: result)
            let ext = (metadata.fileNameView as NSString).pathExtension.uppercased()
            let fileName = (metadata.fileNameView as NSString).deletingPathExtension

            if !(ext == "MOV" && fileNameImages.contains(fileName)) {
                metadatas.append(tableMetadata.init(value: metadata))
            }
        }
      
        return metadatas
    }
    
    @objc func deleteMedia(predicate: NSPredicate) {
                
        let realm = try! Realm()

        realm.beginWrite()

        let results = realm.objects(tableMedia.self).filter(predicate)
        
        realm.delete(results)
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func moveMedia(ocId: String, serverUrlTo: String) {
        
        let realm = try! Realm()

        do {
            try realm.write {
                let result = realm.objects(tableMedia.self).filter("ocId == %@", ocId).first
                if result != nil {
                    result!.serverUrl = serverUrlTo
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    func createTableMedia(_ metadatasSource: [tableMetadata], lteDate: Date, gteDate: Date, account: String) -> (isDifferent: Bool, newInsert: Int) {

        let realm = try! Realm()
        realm.refresh()
        
        var numDelete: Int = 0
        var numInsert: Int = 0
        
        var etagsDelete = [String]()
        var etagsInsert = [String]()
        
        var isDifferent: Bool = false
        var newInsert: Int = 0
        
        do {
            try realm.write {
                
                // DELETE
                let results = realm.objects(tableMedia.self).filter("account == %@ AND date >= %@ AND date <= %@", account, gteDate, lteDate)
                etagsDelete = Array(results.map { $0.etag })
                numDelete = results.count
                
                // INSERT
                let photos = Array(metadatasSource.map { tableMedia.init(value:$0) })
                etagsInsert = Array(photos.map { $0.etag })
                numInsert = photos.count
                
                // CALCULATE DIFFERENT RETURN
                if etagsDelete.count == etagsInsert.count && etagsDelete.sorted() == etagsInsert.sorted() {
                    isDifferent = false
                } else {
                    isDifferent = true
                    newInsert = numInsert - numDelete
                    
                    realm.delete(results)
                    realm.add(photos, update: .all)
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            realm.cancelWrite()
        }
        
        return(isDifferent, newInsert)
    }
    
    @objc func getTableMediaDate(account: String, order: ComparisonResult) -> Date {
        
        let realm = try! Realm()
        realm.refresh()
        
        if let entities = realm.objects(tableMedia.self).filter("account == %@", account).max(by: { $0.date.compare($1.date as Date) == order }) {
            return Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: entities.date as Date)!
        }
        
        return Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: Date())!
    }
    
    @objc func renameMedia(fileNameTo: String, ocId: String) {
        
        var result: tableMedia?
        let realm = try! Realm()
        
        do {
            try realm.write {
                result = realm.objects(tableMedia.self).filter("ocId == %@", ocId).first
                if result != nil {
                    result!.fileName = fileNameTo
                    result!.fileNameView = fileNameTo
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    //MARK: -
    //MARK: Table Photo Library
    
    @objc func addPhotoLibrary(_ assets: [PHAsset], account: String) -> Bool {
        
        let realm = try! Realm()

        if realm.isInWriteTransaction {
            
            print("[LOG] Could not write to database, addPhotoLibrary is already in write transaction")
            return false
            
        } else {
        
            do {
                try realm.write {
                
                    var creationDateString = ""

                    for asset in assets {
                    
                        let addObject = tablePhotoLibrary()
                    
                        addObject.account = account
                        addObject.assetLocalIdentifier = asset.localIdentifier
                        addObject.mediaType = asset.mediaType.rawValue
                    
                        if let creationDate = asset.creationDate {
                            addObject.creationDate = creationDate as NSDate
                            creationDateString = String(describing: creationDate)
                        } else {
                            creationDateString = ""
                        }
                        
                        if let modificationDate = asset.modificationDate {
                            addObject.modificationDate = modificationDate as NSDate
                        }
                        
                        addObject.idAsset = "\(account)\(asset.localIdentifier)\(creationDateString)"

                        realm.add(addObject, update: .all)
                    }
                }
            } catch let error {
                print("[LOG] Could not write to database: ", error)
                return false
            }
        }
        
        return true
    }
    
    @objc func getPhotoLibraryIdAsset(image: Bool, video: Bool, account: String) -> [String]? {
        
        let realm = try! Realm()
        realm.refresh()
        
        var predicate = NSPredicate()
        
        if (image && video) {
         
            predicate = NSPredicate(format: "account == %@ AND (mediaType == %d OR mediaType == %d)", account, PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
            
        } else if (image) {
            
            predicate = NSPredicate(format: "account == %@ AND mediaType == %d", account, PHAssetMediaType.image.rawValue)

        } else if (video) {
            
            predicate = NSPredicate(format: "account == %@ AND mediaType == %d", account, PHAssetMediaType.video.rawValue)
        }
        
        let results = realm.objects(tablePhotoLibrary.self).filter(predicate)
        
        let idsAsset = results.map { $0.idAsset }
        
        return Array(idsAsset)
    }
    
    @objc func getPhotoLibrary(predicate: NSPredicate) -> [tablePhotoLibrary] {
        
        let realm = try! Realm()

        let results = realm.objects(tablePhotoLibrary.self).filter(predicate)
        
        return Array(results.map { tablePhotoLibrary.init(value:$0) })
    }
    
    //MARK: -
    //MARK: Table Share
    
    #if !EXTENSION
    @objc func addShare(account: String, activeUrl: String, items: [OCSharedDto]) -> [tableShare] {
        
        let realm = try! Realm()
        realm.beginWrite()

        for sharedDto in items {
            
            let addObject = tableShare()
            let fullPath = CCUtility.getHomeServerUrlActiveUrl(activeUrl) + "\(sharedDto.path!)"
            let fileName = NSString(string: fullPath).lastPathComponent
            var serverUrl = NSString(string: fullPath).substring(to: (fullPath.count - fileName.count - 1))
            if serverUrl.hasSuffix("/") {
                serverUrl = NSString(string: serverUrl).substring(to: (serverUrl.count - 1))
            }
            
            addObject.account = account
            addObject.displayNameFileOwner = sharedDto.displayNameFileOwner
            addObject.displayNameOwner = sharedDto.displayNameOwner
            if sharedDto.expirationDate > 0 {
                addObject.expirationDate =  Date(timeIntervalSince1970: TimeInterval(sharedDto.expirationDate)) as NSDate
            }
            addObject.fileParent = sharedDto.fileParent
            addObject.fileTarget = sharedDto.fileTarget
            addObject.hideDownload = sharedDto.hideDownload
            addObject.idRemoteShared = sharedDto.idRemoteShared
            addObject.isDirectory = sharedDto.isDirectory
            addObject.itemSource = sharedDto.itemSource
            addObject.label = sharedDto.label
            addObject.mailSend = sharedDto.mailSend
            addObject.mimeType = sharedDto.mimeType
            addObject.note = sharedDto.note
            addObject.path = sharedDto.path
            addObject.permissions = sharedDto.permissions
            addObject.parent = sharedDto.parent
            addObject.sharedDate = Date(timeIntervalSince1970: TimeInterval(sharedDto.sharedDate)) as NSDate
            addObject.shareType = sharedDto.shareType
            addObject.shareWith = sharedDto.shareWith
            addObject.shareWithDisplayName = sharedDto.shareWithDisplayName
            addObject.storage = sharedDto.storage
            addObject.storageID = sharedDto.storageID
            addObject.token = sharedDto.token
            addObject.url = sharedDto.url
            addObject.uidOwner = sharedDto.uidOwner
            addObject.uidFileOwner = sharedDto.uidFileOwner
            
            addObject.fileName = fileName
            addObject.serverUrl = serverUrl
            
            realm.add(addObject, update: .all)
        }
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
        
        return self.getTableShares(account: account)
    }
    #endif
    
    @objc func getTableShares(account: String) -> [tableShare] {
        
        let realm = try! Realm()
        realm.refresh()
        
        let sortProperties = [SortDescriptor(keyPath: "shareType", ascending: false), SortDescriptor(keyPath: "idRemoteShared", ascending: false)]
        let results = realm.objects(tableShare.self).filter("account == %@", account).sorted(by: sortProperties)
        
        return Array(results.map { tableShare.init(value:$0) })
    }
    
    #if !EXTENSION
    func getTableShares(metadata: tableMetadata) -> (firstShareLink: tableShare?,  share: [tableShare]?) {
        
        let realm = try! Realm()
        realm.refresh()
        
        let sortProperties = [SortDescriptor(keyPath: "shareType", ascending: false), SortDescriptor(keyPath: "idRemoteShared", ascending: false)]
        
        let firstShareLink = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@ AND shareType == %d", metadata.account, metadata.serverUrl, metadata.fileName, Int(shareTypeLink.rawValue)).first
        if firstShareLink == nil {
            let results = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, metadata.fileName).sorted(by: sortProperties)
            return(firstShareLink: firstShareLink, share: Array(results.map { tableShare.init(value:$0) }))
        } else {
            let results = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@ AND idRemoteShared != %d", metadata.account, metadata.serverUrl, metadata.fileName, firstShareLink!.idRemoteShared).sorted(by: sortProperties)
            return(firstShareLink: firstShareLink, share: Array(results.map { tableShare.init(value:$0) }))
        }
    }
    #endif
    
    func getTableShare(account: String, idRemoteShared: Int) -> tableShare? {
        
        let realm = try! Realm()
        realm.refresh()
        
        guard let result = realm.objects(tableShare.self).filter("account = %@ AND idRemoteShared = %d", account, idRemoteShared).first else {
            return nil
        }
        
        return tableShare.init(value: result)
    }
    
    @objc func getTableShares(account: String, serverUrl: String) -> [tableShare] {
        
        let realm = try! Realm()
        realm.refresh()
        
        let sortProperties = [SortDescriptor(keyPath: "shareType", ascending: false), SortDescriptor(keyPath: "idRemoteShared", ascending: false)]
        let results = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).sorted(by: sortProperties)

        return Array(results.map { tableShare.init(value:$0) })
    }
    
    @objc func getTableShares(account: String, serverUrl: String, fileName: String) -> [tableShare] {
        
        let realm = try! Realm()
        realm.refresh()
        
        let sortProperties = [SortDescriptor(keyPath: "shareType", ascending: false), SortDescriptor(keyPath: "idRemoteShared", ascending: false)]
        let results = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@", account, serverUrl, fileName).sorted(by: sortProperties)
        
        return Array(results.map { tableShare.init(value:$0) })
    }
    
    @objc func deleteTableShare(account: String, idRemoteShared: Int) {
        
        let realm = try! Realm()
        
        realm.beginWrite()
        
        let result = realm.objects(tableShare.self).filter("account == %@ AND idRemoteShared == %d", account, idRemoteShared)
        realm.delete(result)
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func deleteTableShare(account: String) {
        
        let realm = try! Realm()
        
        realm.beginWrite()
        
        let result = realm.objects(tableShare.self).filter("account == %@", account)
        realm.delete(result)
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    //MARK: -
    //MARK: Table Tag
    
    @objc func addTag(_ ocId: String ,tagIOS: Data?, account: String) {
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                
                // Add new
                let addObject = tableTag()
                    
                addObject.account = account
                addObject.ocId = ocId
                addObject.tagIOS = tagIOS
    
                realm.add(addObject, update: .all)
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func deleteTag(_ ocId: String) {
        
        let realm = try! Realm()
        
        realm.beginWrite()
        
        let result = realm.objects(tableTag.self).filter("ocId == %@", ocId)
        realm.delete(result)
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func getTags(predicate: NSPredicate) -> [tableTag] {
        
        let realm = try! Realm()
        realm.refresh()

        let results = realm.objects(tableTag.self).filter(predicate)
        
        return Array(results.map { tableTag.init(value:$0) })
    }
    
    @objc func getTag(predicate: NSPredicate) -> tableTag? {
        
        let realm = try! Realm()
        realm.refresh()
        
        guard let result = realm.objects(tableTag.self).filter(predicate).first else {
            return nil
        }
        
        return tableTag.init(value: result)
    }
    
    //MARK: -
    //MARK: Table Trash
    
    @objc func addTrashs(_ trashs: [tableTrash]) {
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                for trash in trashs {
                    realm.add(trash, update: .all)
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return
        }
    }
    
    @objc func deleteTrash(filePath: String?, account: String) {
        
        let realm = try! Realm()
        var predicate = NSPredicate()

        realm.beginWrite()
        
        if filePath == nil {
            predicate = NSPredicate(format: "account == %@", account)
        } else {
            predicate = NSPredicate(format: "account == %@ AND filePath == %@", account, filePath!)
        }
        
        let results = realm.objects(tableTrash.self).filter(predicate)
        realm.delete(results)
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func deleteTrash(fileId: String?, account: String) {
        
        let realm = try! Realm()
        var predicate = NSPredicate()
        
        realm.beginWrite()
        
        if fileId == nil {
            predicate = NSPredicate(format: "account == %@", account)
        } else {
            predicate = NSPredicate(format: "account == %@ AND fileId == %@", account, fileId!)
        }
        
        let result = realm.objects(tableTrash.self).filter(predicate)
        realm.delete(result)
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func getTrash(filePath: String, sorted: String, ascending: Bool, account: String) -> [tableTrash]? {
        
        let realm = try! Realm()
        realm.refresh()
        
        let results = realm.objects(tableTrash.self).filter("account == %@ AND filePath == %@", account, filePath).sorted(byKeyPath: sorted, ascending: ascending)

        return Array(results.map { tableTrash.init(value:$0) })
    }
    
    @objc func getTrashItem(fileId: String, account: String) -> tableTrash? {
        
        let realm = try! Realm()
        realm.refresh()
        
        guard let result = realm.objects(tableTrash.self).filter("account == %@ AND fileId == %@", account, fileId).first else {
            return nil
        }
        
        return tableTrash.init(value: result)
    }
    
    //MARK: -
}
