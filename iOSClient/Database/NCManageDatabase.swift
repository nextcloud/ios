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
                objectTypes: [tableMetadata.self, tableLocalFile.self, tableDirectory.self, tableTag.self, tableAccount.self, tableCapabilities.self, tableE2eEncryption.self]
            )
            
            Realm.Configuration.defaultConfiguration = config
            
        } else {
            
            // App config

            let configCompact = Realm.Configuration(
                
                fileURL: databaseFilePath,
                schemaVersion: UInt64(k_databaseSchemaVersion),
                
                migrationBlock: { migration, oldSchemaVersion in
                                        
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
                    
                    if oldSchemaVersion < 87 {
                        migration.deleteData(forType: tableActivity.className())
                        migration.deleteData(forType: tableActivityPreview.className())
                        migration.deleteData(forType: tableActivitySubjectRich.className())
                        migration.deleteData(forType: tableDirectEditingCreators.className())
                        migration.deleteData(forType: tableDirectEditingEditors.className())
                        migration.deleteData(forType: tableExternalSites.className())
                        migration.deleteData(forType: tableGPS.className())
                        migration.deleteData(forType: tableShare.className())
                        migration.deleteData(forType: tableTag.className())
                        migration.deleteData(forType: tableTrash.className())
                    }
                    
                    if oldSchemaVersion < 120 {
                        migration.deleteData(forType: tableE2eEncryptionLock.className())
                        migration.deleteData(forType: tableCapabilities.className())
                        migration.deleteData(forType: tableComments.className())
                        migration.deleteData(forType: tableDirectory.className())
                    }
                    
                    if oldSchemaVersion < 134 {
                        migration.deleteData(forType: tableShare.className())
                        migration.deleteData(forType: tableDirectEditingCreators.className())
                        migration.deleteData(forType: tableDirectEditingEditors.className())
                        migration.deleteData(forType: tableExternalSites.className())
                    }
                    
                    if oldSchemaVersion < 139 {
                        migration.deleteData(forType: tableMetadata.className())
                    }
                    
                    if oldSchemaVersion < 141 {
                        migration.enumerateObjects(ofType: tableAccount.className()) { oldObject, newObject in
                            newObject!["urlBase"] = oldObject!["url"]
                        }
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
                        NCContentPresenter.shared.messageNotification("_error_", description: "_database_corrupt_", delay: TimeInterval(k_dismissAfterSecondLong), type: NCContentPresenter.messageType.info, errorCode: Int(k_CCErrorInternalError), forced: true)
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
                    NCContentPresenter.shared.messageNotification("_error_", description: "_database_corrupt_", delay: TimeInterval(k_dismissAfterSecondLong), type: NCContentPresenter.messageType.info, errorCode: Int(k_CCErrorInternalError), forced: true)
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
        
        let realm = try! Realm()

        do {
            try realm.safeWrite {
                var results : Results<Object>

                if let account = account {
                    results = realm.objects(table).filter("account == %@", account)
                } else {
                    results = realm.objects(table)
                }
           
                realm.delete(results)
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
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
                NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
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
                if NCBrandOptions.sharedInstance.use_default_auto_upload {
                        
                    addObject.autoUpload = true
                    addObject.autoUploadImage = true
                    addObject.autoUploadVideo = true
                    addObject.autoUploadWWAnVideo = true
                }
                
                CCUtility.setPassword(account, password: password)
                
                addObject.urlBase = urlBase
                addObject.user = user
                addObject.userID = user
           
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

    @objc func getAccountActive() -> tableAccount? {
        
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
        
        let results = realm.objects(tableAccount.self)
        
        return Array(results.map { tableAccount.init(value:$0) })
    }
    
    @objc func getAccountAutoUploadFileName() -> String {
        
        let realm = try! Realm()
        
        guard let result = realm.objects(tableAccount.self).filter("active == true").first else {
            return ""
        }
        
        if result.autoUploadFileName.count > 0 {
            return result.autoUploadFileName
        } else {
            return NCBrandOptions.sharedInstance.folderDefaultAutoUpload
        }
    }
    
    @objc func getAccountAutoUploadDirectory(urlBase : String, account: String) -> String {
        
        let realm = try! Realm()
        
        guard let result = realm.objects(tableAccount.self).filter("active == true").first else {
            return ""
        }
        
        if result.autoUploadDirectory.count > 0 {
            return result.autoUploadDirectory
        } else {
            return NCUtility.shared.getHomeServer(urlBase: urlBase, account: account)
        }
    }

    @objc func getAccountAutoUploadPath(urlBase : String, account: String) -> String {
        
        let cameraFileName = self.getAccountAutoUploadFileName()
        let cameraDirectory = self.getAccountAutoUploadDirectory(urlBase: urlBase, account: account)
     
        let folderPhotos = CCUtility.stringAppendServerUrl(cameraDirectory, addFileName: cameraFileName)!
        
        return folderPhotos
    }
    
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
            guard let account = self.getAccountActive() else {
                return nil
            }
            
            try realm.safeWrite {
                
                guard let result = realm.objects(tableAccount.self).filter("account == %@", account.account).first else {
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
                result.userID = userProfile.userId
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
            guard let account = self.getAccountActive() else {
                return nil
            }
            
            try realm.safeWrite {
                
                guard let result = realm.objects(tableAccount.self).filter("account == %@", account.account).first else {
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
    
    //MARK: -
    //MARK: Table Activity

    @objc func addActivity(_ activities: [NCCommunicationActivity], account: String) {
    
        let realm = try! Realm()

        do {
            try realm.write {
            
                for activity in activities {
                    
                    let addObjectActivity = tableActivity()
                    
                    addObjectActivity.account = account
                    addObjectActivity.idActivity = activity.idActivity
                    addObjectActivity.idPrimaryKey = account + String(activity.idActivity)
                    addObjectActivity.date = activity.date
                    addObjectActivity.app = activity.app
                    addObjectActivity.type = activity.type
                    addObjectActivity.user = activity.user
                    addObjectActivity.subject = activity.subject
                    
                    if let subject_rich = activity.subject_rich {
                        if let json = JSON(subject_rich).array {
                            addObjectActivity.subjectRich = json[0].stringValue
                            if json.count > 1 {
                                if let dict = json[1].dictionary {
                                    for (key, value) in dict {
                                        let addObjectActivitySubjectRich = tableActivitySubjectRich()
                                        let dict = value as JSON
                                        addObjectActivitySubjectRich.account = account
                                        if dict["id"].intValue > 0 {
                                            addObjectActivitySubjectRich.id = String(dict["id"].intValue)
                                        } else {
                                            addObjectActivitySubjectRich.id = dict["id"].stringValue
                                        }
                                        addObjectActivitySubjectRich.name = dict["name"].stringValue
                                        addObjectActivitySubjectRich.idPrimaryKey = account + String(activity.idActivity) + addObjectActivitySubjectRich.id + addObjectActivitySubjectRich.name
                                        addObjectActivitySubjectRich.key = key
                                        addObjectActivitySubjectRich.idActivity = activity.idActivity
                                        addObjectActivitySubjectRich.link = dict["link"].stringValue
                                        addObjectActivitySubjectRich.path = dict["path"].stringValue
                                        addObjectActivitySubjectRich.type = dict["type"].stringValue

                                        realm.add(addObjectActivitySubjectRich, update: .all)
                                    }
                                }
                            }
                        }
                    }
                    
                    if let previews = activity.previews {
                        if let json = JSON(previews).array {
                            for preview in json {
                                let addObjectActivityPreview = tableActivityPreview()
                                
                                addObjectActivityPreview.account = account
                                addObjectActivityPreview.idActivity = activity.idActivity
                                addObjectActivityPreview.fileId = preview["fileId"].intValue
                                addObjectActivityPreview.idPrimaryKey = account + String(activity.idActivity) + String(addObjectActivityPreview.fileId)
                                addObjectActivityPreview.source = preview["source"].stringValue
                                addObjectActivityPreview.link = preview["link"].stringValue
                                addObjectActivityPreview.mimeType = preview["mimeType"].stringValue
                                addObjectActivityPreview.view = preview["view"].stringValue
                                addObjectActivityPreview.isMimeTypeIcon = preview["isMimeTypeIcon"].boolValue
                                
                                realm.add(addObjectActivityPreview, update: .all)
                            }
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
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    func getActivity(predicate: NSPredicate, filterFileId: String?) -> (all: [tableActivity], filter: [tableActivity]) {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableActivity.self).filter(predicate).sorted(byKeyPath: "idActivity", ascending: false)
        let allActivity = Array(results.map { tableActivity.init(value:$0) })
        if filterFileId != nil {
            var resultsFilter: [tableActivity] = []
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
        
        let results = realm.objects(tableActivitySubjectRich.self).filter("account == %@ && idActivity == %d && key == %@", account, idActivity, key).first
        
        return results.map { tableActivitySubjectRich.init(value:$0) }
    }
    
    @objc func getActivitySubjectRich(account: String, idActivity: Int, id: String) -> tableActivitySubjectRich? {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableActivitySubjectRich.self).filter("account == %@ && idActivity == %d && id == %@", account, idActivity, id).first
        
        return results.map { tableActivitySubjectRich.init(value:$0) }
    }
    
    @objc func getActivityPreview(account: String, idActivity: Int, orderKeysId: [String]) -> [tableActivityPreview] {
        
        let realm = try! Realm()
        
        var results: [tableActivityPreview] = []
        
        for id in orderKeysId {
            if let result = realm.objects(tableActivityPreview.self).filter("account == %@ && idActivity == %d && fileId == %d", account, idActivity, Int(id) ?? 0).first {
                results.append(result)
            }
        }
        
        return results
    }
    
    @objc func getActivityLastIdActivity(account: String) -> Int {
        
        let realm = try! Realm()
        
        if let entities = realm.objects(tableActivity.self).filter("account == %@", account).max(by: { $0.idActivity < $1.idActivity }) {
            return entities.idActivity
        }
        
        return 0
    }
    
    //MARK: -
    //MARK: Table Capabilities
    
    @objc func addCapabilitiesJSon(_ data: Data, account: String) {
                           
        let realm = try! Realm()

        do {
            try realm.safeWrite {
                let addObject = tableCapabilities()
                
                addObject.account = account
                addObject.jsondata = data
                
                realm.add(addObject, update: .all)
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func getCapabilities(account: String) -> String? {
                           
        let realm = try! Realm()
               
        guard let result = realm.objects(tableCapabilities.self).filter("account == %@", account).first else {
            return nil
        }
        guard let jsondata = result.jsondata else {
            return nil
        }
               
        let json = JSON(jsondata)
        
        return json.rawString()?.replacingOccurrences(of: "\\/", with: "/")
    }
    
    @objc func getCapabilitiesServerString(account: String, elements: Array<String>) -> String? {

        let realm = try! Realm()
        
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
        var resultArray: [String] = []
        
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
    
    @objc func addComments(_ comments: [NCCommunicationComments], account: String, objectId: String) {
        
        let realm = try! Realm()
        
        do {
            try realm.safeWrite {
                
                let results = realm.objects(tableComments.self).filter("account == %@ AND objectId == %@", account, objectId)
                realm.delete(results)
                
                for comment in comments {
                    
                    let object = tableComments()
                    
                    object.account = account
                    object.actorDisplayName = comment.actorDisplayName
                    object.actorId = comment.actorId
                    object.actorType = comment.actorType
                    object.creationDateTime = comment.creationDateTime as NSDate
                    object.isUnread = comment.isUnread
                    object.message = comment.message
                    object.messageId = comment.messageId
                    object.objectId = comment.objectId
                    object.objectType = comment.objectType
                    object.path = comment.path
                    object.verb = comment.verb
                    
                    realm.add(object, update: .all)
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func getComments(account: String, objectId: String) -> [tableComments] {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableComments.self).filter("account == %@ AND objectId == %@", account, objectId).sorted(byKeyPath: "creationDateTime", ascending: false)
        
        return Array(results.map { tableComments.init(value:$0) })
    }
    
    //MARK: -
    //MARK: Table Direct Editing
    
    @objc func addDirectEditing(account: String, editors: [NCCommunicationEditorDetailsEditors], creators: [NCCommunicationEditorDetailsCreators]) {
        
        let realm = try! Realm()

        do {
            try realm.safeWrite {
            
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
                    if editor.name.lowercased() == k_editor_onlyoffice {
                        addObject.editor = k_editor_onlyoffice
                    } else {
                        addObject.editor = k_editor_text
                    }
                    for mimeType in editor.optionalMimetypes {
                        addObject.optionalMimetypes.append(mimeType)
                    }
                    addObject.secure = editor.secure
                    
                    realm.add(addObject)
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
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
    
    @objc func copyObject(directory: tableDirectory) -> tableDirectory {
        return tableDirectory.init(value: directory)
    }
    
    @objc func addDirectory(encrypted: Bool, favorite: Bool, ocId: String, fileId: String, etag: String? = nil, permissions: String? = nil, serverUrl: String, richWorkspace: String? = nil, creationDate: NSDate? = nil, account: String) {
        
        let realm = try! Realm()

        do {
            try realm.safeWrite {
                var addObject = tableDirectory()
                let result = realm.objects(tableDirectory.self).filter("ocId == %@", ocId).first
            
                if result != nil {
                    addObject = result!
                } else {
                    addObject.ocId = ocId
                }
                
                addObject.account = account
                if let creationDate = creationDate {
                    addObject.creationDate = creationDate
                }
                addObject.e2eEncrypted = encrypted
                addObject.favorite = favorite
                addObject.fileId = fileId
                if let etag = etag {
                    addObject.etag = etag
                }
                if let permissions = permissions {
                    addObject.permissions = permissions
                }
                addObject.richWorkspace = richWorkspace
                addObject.serverUrl = serverUrl
           
                realm.add(addObject, update: .all)
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func deleteDirectoryAndSubDirectory(serverUrl: String, account: String) {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl BEGINSWITH %@", account, serverUrl)
        
        // Delete table Metadata & LocalFile
        for result in results {
            
            self.deleteMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", result.account, result.serverUrl))
            self.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", result.ocId))
        }
        
        // Delete table Dirrectory
        do {
            try realm.safeWrite {
                realm.delete(results)
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func setDirectory(serverUrl: String, serverUrlTo: String? = nil, etag: String? = nil, ocId: String? = nil, fileId: String? = nil, encrypted: Bool, richWorkspace: String? = nil, account: String) {
        
        let realm = try! Realm()

        do {
            try realm.safeWrite {
            
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
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func getTableDirectory(predicate: NSPredicate) -> tableDirectory? {
        
        let realm = try! Realm()

        guard let result = realm.objects(tableDirectory.self).filter(predicate).first else {
            return nil
        }
        
        return tableDirectory.init(value: result)
    }
    
    @objc func getTablesDirectory(predicate: NSPredicate, sorted: String, ascending: Bool) -> [tableDirectory]? {
        
        let realm = try! Realm()

        let results = realm.objects(tableDirectory.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)
        
        if (results.count > 0) {
            return Array(results.map { tableDirectory.init(value:$0) })
        } else {
            return nil
        }
    }
    
    @objc func renameDirectory(ocId: String, serverUrl: String) {
                
        let realm = try! Realm()
                
        do {
            try realm.safeWrite {
                let result = realm.objects(tableDirectory.self).filter("ocId == %@", ocId).first
                result?.serverUrl = serverUrl
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func setDirectory(serverUrl: String, offline: Bool, account: String) {
        
        let realm = try! Realm()
        
        do {
            try realm.safeWrite {
                let result = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).first
                result?.offline = offline
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func setDirectory(richWorkspace: String?, serverUrl: String, account: String) {
        
        let realm = try! Realm()
                
        do {
            try realm.safeWrite {
                let result = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).first
                result?.richWorkspace = richWorkspace
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    //MARK: -
    //MARK: Table e2e Encryption
    
    @objc func addE2eEncryption(_ e2e: tableE2eEncryption) {

        let realm = try! Realm()

        do {
            try realm.safeWrite {
                realm.add(e2e, update: .all)
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func deleteE2eEncryption(predicate: NSPredicate) {
        
        let realm = try! Realm()

        do {
            try realm.safeWrite {
                
                let results = realm.objects(tableE2eEncryption.self).filter(predicate)
                realm.delete(results)
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func getE2eEncryption(predicate: NSPredicate) -> tableE2eEncryption? {
        
        let realm = try! Realm()
        
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
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    //MARK: -
    //MARK: Table e2e Encryption Lock
    
    @objc func getE2ETokenLock(account: String, serverUrl: String) -> tableE2eEncryptionLock? {
        
        let realm = try! Realm()
            
        guard let result = realm.objects(tableE2eEncryptionLock.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).first else {
            return nil
        }
        
        return tableE2eEncryptionLock.init(value: result)
    }
    
    @objc func setE2ETokenLock(account: String, serverUrl: String, fileId: String, e2eToken: String) {
        
        let realm = try! Realm()

        do {
            try realm.safeWrite {
                let addObject = tableE2eEncryptionLock()
            
                addObject.account = account
                addObject.fileId = fileId
                addObject.serverUrl = serverUrl
                addObject.e2eToken = e2eToken
           
                realm.add(addObject, update: .all)
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func deteleE2ETokenLock(account: String, serverUrl: String) {
        
        let realm = try! Realm()

        do {
            try realm.safeWrite {
                if let result = realm.objects(tableE2eEncryptionLock.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).first {
                    realm.delete(result)
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    //MARK: -
    //MARK: Table External Sites
    
    @objc func addExternalSites(_ externalSite: NCCommunicationExternalSite, account: String) {
        
        let realm = try! Realm()

        do {
            try realm.safeWrite {
                let addObject = tableExternalSites()
            
                addObject.account = account
                addObject.idExternalSite = externalSite.idExternalSite
                addObject.icon = externalSite.icon
                addObject.lang = externalSite.lang
                addObject.name = externalSite.name
                addObject.url = externalSite.url
                addObject.type = externalSite.type
           
                realm.add(addObject)
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func deleteExternalSites(account: String) {
        
        let realm = try! Realm()

        do {
            try realm.safeWrite {
                let results = realm.objects(tableExternalSites.self).filter("account == %@", account)
                realm.delete(results)
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func getAllExternalSites(account: String) -> [tableExternalSites]? {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableExternalSites.self).filter("account == %@", account).sorted(byKeyPath: "idExternalSite", ascending: true)
        
        if results.count > 0 {
            return Array(results.map { tableExternalSites.init(value:$0) })
        } else {        
            return nil
        }
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
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func getLocationFromGeoLatitude(_ latitude: String, longitude: String) -> String? {
        
        let realm = try! Realm()
        
        let result = realm.objects(tableGPS.self).filter("latitude == %@ AND longitude == %@", latitude, longitude).first
        return result?.location
    }

    //MARK: -
    //MARK: Table LocalFile
    
    @objc func copyObject(localFile: tableLocalFile) -> tableLocalFile {
        return tableLocalFile.init(value: localFile)
    }
    
    @objc func addLocalFile(metadata: tableMetadata) {
        
        let realm = try! Realm()
        
        do {
            try realm.safeWrite {
            
                let addObject = tableLocalFile()
                
                addObject.account = metadata.account
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
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func deleteLocalFile(predicate: NSPredicate) {
        
        let realm = try! Realm()

        do {
            try realm.safeWrite {
                let results = realm.objects(tableLocalFile.self).filter(predicate)
                realm.delete(results)
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func setLocalFile(ocId: String, fileName: String?, etag: String?) {
        
        let realm = try! Realm()

        do {
            try realm.safeWrite {
                let result = realm.objects(tableLocalFile.self).filter("ocId == %@", ocId).first
                if let fileName = fileName {
                    result?.fileName = fileName
                }
                if let etag = etag {
                    result?.etag = etag
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func getTableLocalFile(predicate: NSPredicate) -> tableLocalFile? {
        
        let realm = try! Realm()
        
        guard let result = realm.objects(tableLocalFile.self).filter(predicate).first else {
            return nil
        }
        
        return tableLocalFile.init(value: result)
    }
    
    @objc func getTableLocalFiles(predicate: NSPredicate, sorted: String, ascending: Bool) -> [tableLocalFile] {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableLocalFile.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)
        return Array(results.map { tableLocalFile.init(value:$0) })
    }
    
    @objc func setLocalFile(ocId: String, offline: Bool) {
        
        let realm = try! Realm()
        
        do {
            try realm.safeWrite {
                let result = realm.objects(tableLocalFile.self).filter("ocId == %@", ocId).first
                result?.offline = offline
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func setLocalFile(ocId: String, lastAccessDate: Date) {
        
        let realm = try! Realm()
        
        do {
            try realm.safeWrite {
                let result = realm.objects(tableLocalFile.self).filter("ocId == %@", ocId).first
                result?.lastAccessDate = lastAccessDate as NSDate
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    //MARK: -
    //MARK: Table Metadata
    
    @objc func copyObject(metadata: tableMetadata) -> tableMetadata {
        return tableMetadata.init(value: metadata)
    }
    
    @objc func convertNCFileToMetadata(_ file: NCCommunicationFile, isEncrypted: Bool, account: String) -> tableMetadata {
        
        let metadata = tableMetadata()
        
        metadata.account = account
        metadata.commentsUnread = file.commentsUnread
        metadata.contentType = file.contentType
        if let date = file.creationDate {
            metadata.creationDate = date
        } else {
            metadata.creationDate = file.date
        }
        metadata.date = file.date
        metadata.directory = file.directory
        metadata.e2eEncrypted = file.e2eEncrypted
        metadata.etag = file.etag
        metadata.ext = file.ext
        metadata.favorite = file.favorite
        metadata.fileId = file.fileId
        metadata.fileName = file.fileName
        metadata.fileNameView = file.fileName
        metadata.fileNameWithoutExt = file.fileNameWithoutExt
        metadata.hasPreview = file.hasPreview
        metadata.iconName = file.iconName
        metadata.livePhoto = file.livePhoto
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
        if let date = file.uploadDate {
            metadata.uploadDate = date
        } else {
            metadata.uploadDate = file.date
        }
        metadata.urlBase = file.urlBase
        
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
    
    @objc func convertNCCommunicationFilesToMetadatas(_ files: [NCCommunicationFile], useMetadataFolder: Bool, account: String, completion: @escaping (_ metadataFolder: tableMetadata,_ metadatasFolder: [tableMetadata], _ metadatas: [tableMetadata])->())  {
    
        var counter: Int = 0
        var isEncrypted: Bool = false
        var listServerUrl: [String: Bool] = [:]
        
        var metadataFolder = tableMetadata()
        var metadataFolders: [tableMetadata] = []
        var metadatas: [tableMetadata] = []

        for file in files {
                        
            if let key = listServerUrl[file.serverUrl] {
                isEncrypted = key
            } else {
                isEncrypted = CCUtility.isFolderEncrypted(file.serverUrl, e2eEncrypted: file.e2eEncrypted, account: account, urlBase: file.urlBase)
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
    
    @objc func createMetadata(account: String, fileName: String, ocId: String, serverUrl: String, urlBase: String, url: String, contentType: String, livePhoto: Bool) -> tableMetadata {
        
        let metadata = tableMetadata()
        let results = NCCommunicationCommon.shared.getInternalContenType(fileName: fileName, contentType: contentType, directory: false)
        
        metadata.account = account
        metadata.contentType = results.contentType
        metadata.creationDate = Date() as NSDate
        metadata.date = Date() as NSDate
        metadata.hasPreview = true
        metadata.iconName = results.iconName
        metadata.etag = ocId
        metadata.ext = (fileName as NSString).pathExtension.lowercased()
        metadata.fileName = fileName
        metadata.fileNameView = fileName
        metadata.fileNameWithoutExt = (fileName as NSString).deletingPathExtension
        metadata.livePhoto = livePhoto
        metadata.ocId = ocId
        metadata.permissions = "RGDNVW"
        metadata.serverUrl = serverUrl
        metadata.typeFile = results.typeFile
        metadata.uploadDate = Date() as NSDate
        metadata.url = url
        metadata.urlBase = urlBase
        
        return metadata
    }
    
    @objc func addMetadata(_ metadata: tableMetadata) {

        let realm = try! Realm()

        do {
            try realm.safeWrite {
                realm.add(metadata, update: .all)
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func addMetadatas(_ metadatas: [tableMetadata]) {
        
        let realm = try! Realm()

        do {
            try realm.safeWrite {
                for metadata in metadatas {
                    realm.add(metadata, update: .all)
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func addMetadatas(files: [NCCommunicationFile]?, account: String) {
    
        guard let files = files else { return }
        
        let realm = try! Realm()
        
        do {
            try realm.safeWrite {
                for file in files {
                    
                    let metadata = tableMetadata()
                    
                    metadata.account = account
                    metadata.commentsUnread = file.commentsUnread
                    metadata.contentType = file.contentType
                    if let date = file.creationDate {
                        metadata.creationDate = date
                    } else {
                        metadata.creationDate = file.date
                    }
                    metadata.date = file.date
                    metadata.directory = file.directory
                    metadata.e2eEncrypted = file.e2eEncrypted
                    metadata.etag = file.etag
                    metadata.ext = file.ext
                    metadata.favorite = file.favorite
                    metadata.fileId = file.fileId
                    metadata.fileName = file.fileName
                    metadata.fileNameView = file.fileName
                    metadata.fileNameWithoutExt = file.fileNameWithoutExt
                    metadata.hasPreview = file.hasPreview
                    metadata.iconName = file.iconName
                    metadata.livePhoto = file.livePhoto
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
                    if let date = file.uploadDate {
                        metadata.uploadDate = date
                    } else {
                        metadata.uploadDate = file.date
                    }
                    metadata.urlBase = file.urlBase
                    
                    realm.add(metadata, update: .all)
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func deleteMetadata(predicate: NSPredicate) {
                
        let realm = try! Realm()
        
        do {
            try realm.safeWrite {
                let results = realm.objects(tableMetadata.self).filter(predicate)
                realm.delete(results)
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func moveMetadata(ocId: String, serverUrlTo: String) {
        
        let realm = try! Realm()

        do {
            try realm.safeWrite {
                if let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first {
                    result.serverUrl = serverUrlTo
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func addMetadataServerUrl(ocId: String, serverUrl: String) {
        
        let realm = try! Realm()
        
        do {
            try realm.safeWrite {
                let results = realm.objects(tableMetadata.self).filter("ocId == %@", ocId)
                for result in results {
                    result.serverUrl = serverUrl
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func addMetadataForAutoUpload(_ metadata: tableMetadata) {

        let realm = try! Realm()
        realm.refresh()
        
        if realm.objects(tableMetadata.self).filter(NSPredicate(format: "account == %@ && serverUrl == %@ && fileName == %@ && session == %@", metadata.account, metadata.serverUrl, metadata.fileName, metadata.session)).first  != nil {
            return
        }

        do {
            try realm.safeWrite {
                realm.add(metadata, update: .all)
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func renameMetadata(fileNameTo: String, ocId: String) {
        
        let realm = try! Realm()
        
        do {
            try realm.safeWrite {
                if let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first {
                    result.fileName = fileNameTo
                    result.fileNameView = fileNameTo
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @discardableResult
    func updateMetadatas(_ metadatas: [tableMetadata], metadatasResult: [tableMetadata], addCompareLivePhoto: Bool = true, addExistsInLocal: Bool = false, addCompareEtagLocal: Bool = false) -> (metadatasUpdate: [tableMetadata], metadatasLocalUpdate: [tableMetadata]) {
        
        let realm = try! Realm()
        var ocIdsUdate : [String] = []
        var ocIdsLocalUdate : [String] = []
        var metadatasUpdate : [tableMetadata] = []
        var metadatasLocalUpdate : [tableMetadata] = []
        
        realm.refresh()
        
        do {
            try realm.safeWrite {
                
                // DELETE
                for metadataResult in metadatasResult {
                    if metadatas.firstIndex(where: { $0.ocId == metadataResult.ocId }) == nil {
                        if let result = realm.objects(tableMetadata.self).filter(NSPredicate(format: "ocId == %@", metadataResult.ocId)).first {
                            realm.delete(result)
                        }
                    }
                }
                
                // UPDATE/NEW
                for metadata in metadatas {
                    
                    if let result = metadatasResult.first(where: { $0.ocId == metadata.ocId }) {
                        // update
                        if result.status == k_metadataStatusNormal && (result.etag != metadata.etag || result.fileNameView != metadata.fileNameView || result.date != metadata.date || result.permissions != metadata.permissions) {
                            ocIdsUdate.append(metadata.ocId)
                            realm.add(metadata, update: .all)
                        } else if result.status == k_metadataStatusNormal && addCompareLivePhoto && result.livePhoto != metadata.livePhoto {
                            ocIdsUdate.append(metadata.ocId)
                            realm.add(metadata, update: .all)
                        }
                    } else {
                        // new
                        ocIdsUdate.append(metadata.ocId)
                        realm.add(metadata, update: .all)
                    }
                    
                    if metadata.directory && !ocIdsUdate.contains(metadata.ocId) {
                        let table = realm.objects(tableDirectory.self).filter(NSPredicate(format: "ocId == %@", metadata.ocId)).first
                        if table?.etag != metadata.etag {
                            ocIdsUdate.append(metadata.ocId)
                        }
                    }
                    
                    // Local
                    if !metadata.directory && (addExistsInLocal || addCompareEtagLocal) {
                        let localFile = realm.objects(tableLocalFile.self).filter(NSPredicate(format: "ocId == %@", metadata.ocId)).first
                        if addCompareEtagLocal && localFile != nil && localFile?.etag != metadata.etag {
                            ocIdsLocalUdate.append(metadata.ocId)
                        }
                        if addExistsInLocal && (localFile == nil || localFile?.etag != metadata.etag) && !ocIdsLocalUdate.contains(metadata.ocId) {
                            ocIdsLocalUdate.append(metadata.ocId)
                        }
                    }
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
        
        for ocId in ocIdsUdate {
            if let result = realm.objects(tableMetadata.self).filter(NSPredicate(format: "ocId == %@", ocId)).first {
                metadatasUpdate.append(tableMetadata.init(value: result))
            }
        }
        
        for ocId in ocIdsLocalUdate {
            if let result = realm.objects(tableMetadata.self).filter(NSPredicate(format: "ocId == %@", ocId)).first {
                metadatasLocalUpdate.append(tableMetadata.init(value: result))
            }
        }
        
        return (metadatasUpdate, metadatasLocalUpdate)
    }
    
    func setMetadataSession(ocId: String, session: String? = nil, sessionError: String? = nil, sessionSelector: String? = nil, sessionTaskIdentifier: Int? = nil, status: Int? = nil, etag: String? = nil, setFavorite: Bool = false) {
            
        let realm = try! Realm()
        realm.refresh()

        do {
            try realm.safeWrite {
                let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                if let session = session {
                    result?.session = session
                }
                if let sessionError = sessionError {
                    result?.sessionError = sessionError
                }
                if let sessionSelector = sessionSelector {
                    result?.sessionSelector = sessionSelector
                }
                if let sessionTaskIdentifier = sessionTaskIdentifier {
                    result?.sessionTaskIdentifier = sessionTaskIdentifier
                }
                if let status = status {
                    result?.status = status
                }
                if let etag = etag {
                    result?.etag = etag
                }
                if setFavorite {
                    result?.favorite = true
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    func setMetadataStatus(ocId: String, status: Int) -> tableMetadata? {
        
        let realm = try! Realm()
        var result: tableMetadata?
        
        do {
            try realm.safeWrite {
                result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                result?.status = status
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
        
        if let result = result {
            return tableMetadata.init(value: result)
        } else {
            return nil
        }
    }
    
    @objc func setMetadataFavorite(ocId: String, favorite: Bool) {
        
        let realm = try! Realm()
        
        do {
            try realm.safeWrite {
                let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                result?.favorite = favorite
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
   
    @objc func setMetadataEncrypted(ocId: String, encrypted: Bool) {
           
        let realm = try! Realm()
        
        do {
            try realm.safeWrite {
                let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                result?.e2eEncrypted = encrypted
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
       
    @objc func setMetadataFileNameView(serverUrl: String, fileName: String, newFileNameView: String, account: String) {
        
        let realm = try! Realm()
        
        do {
            try realm.safeWrite {
                let result = realm.objects(tableMetadata.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@", account, serverUrl, fileName).first
                result?.fileNameView = newFileNameView
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
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
        
        guard let result = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending).first else {
            return nil
        }
        
        return tableMetadata.init(value: result)
    }
    
    @objc func getMetadatasViewer(predicate: NSPredicate, sorted: String, ascending: Bool) -> [tableMetadata]? {
        
        let realm = try! Realm()
        realm.refresh()
        
        let results: Results<tableMetadata>
        var finals: [tableMetadata] = []
                    
        if (tableMetadata().objectSchema.properties.contains { $0.name == sorted }) {
            results = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)
        } else {
            results = realm.objects(tableMetadata.self).filter(predicate)
        }
        
        // For Live Photo
        var fileNameImages: [String] = []
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
    
    @objc func getMetadatas(predicate: NSPredicate, page: Int = 0, limit: Int = 0, sorted: String = "fileName", ascending: Bool = false) -> [tableMetadata] {
        
        let realm = try! Realm()
        realm.refresh()
        var metadatas: [tableMetadata] = []
                
        let results = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)
        
        if results.count > 0 {
            if page == 0 || limit == 0 {
                return Array(results.map { tableMetadata.init(value:$0) })
            } else {
                
                let nFrom = (page - 1) * limit
                let nTo = nFrom + (limit - 1)
                
                for n in nFrom...nTo {
                    if n == results.count {
                        break
                    }
                    metadatas.append(tableMetadata.init(value:results[n]))
                }
            }
        }
        return metadatas
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
    
    @objc func getMetadataFromOcId(_ ocId: String?) -> tableMetadata? {
        
        let realm = try! Realm()
        realm.refresh()
        
        guard let ocId = ocId else { return nil }
        guard let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first else { return nil }
        
        return tableMetadata.init(value: result)
    }
    
    @objc func getTableMetadatasDirectoryFavoriteIdentifierRank(account: String) -> [String: NSNumber] {
        
        var listIdentifierRank: [String: NSNumber] = [:]
        let realm = try! Realm()
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
        realm.refresh()
        
        do {
            try realm.safeWrite {
                
                let results = realm.objects(tableMetadata.self).filter("account == %@ AND (status == %d OR status == %@)", account, k_metadataStatusWaitUpload, k_metadataStatusUploadError)
                realm.delete(results)
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func readMarkerMetadata(account: String, fileId: String) {
        
        let realm = try! Realm()
        
        do {
            try realm.safeWrite {
                let results = realm.objects(tableMetadata.self).filter("account == %@ AND fileId == %@", account, fileId)
                for result in results {
                    result.commentsUnread = false
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func getAssetLocalIdentifiersUploaded(account: String, sessionSelector: String) -> [String] {
        
        let realm = try! Realm()
        realm.refresh()
        
        var assetLocalIdentifiers: [String] = []
        
        let results = realm.objects(tableMetadata.self).filter("account == %@ AND assetLocalIdentifier != '' AND deleteAssetLocalIdentifier == true AND sessionSelector == %@", account, sessionSelector)
        for result in results {
            assetLocalIdentifiers.append(result.assetLocalIdentifier)
        }
       
        return assetLocalIdentifiers
    }
    
    @objc func clearAssetLocalIdentifiers(_ assetLocalIdentifiers: [String], account: String) {
        
        let realm = try! Realm()

        do {
            try realm.safeWrite {
                let results = realm.objects(tableMetadata.self).filter("account == %@ AND assetLocalIdentifier IN %@", account, assetLocalIdentifiers)
                for result in results {
                    result.assetLocalIdentifier = ""
                    result.deleteAssetLocalIdentifier = false
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func isLivePhoto(metadata: tableMetadata) -> tableMetadata? {
           
        let realm = try! Realm()
        realm.refresh()
        
        if !metadata.livePhoto || !CCUtility.getLivePhoto() {
            return nil
        }
        
        guard let result = realm.objects(tableMetadata.self).filter(NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameWithoutExt == %@ AND ocId != %@", metadata.account, metadata.serverUrl, metadata.fileNameWithoutExt, metadata.ocId)).first else {
            return nil
        }
        
        return tableMetadata.init(value: result)
    }
    
    func getMetadatasMedia(predicate: NSPredicate, sort: String, ascending: Bool = false) -> [tableMetadata] {
        
        let realm = try! Realm()
        realm.refresh()
        
        let sortProperties = [SortDescriptor(keyPath: sort, ascending: ascending), SortDescriptor(keyPath: "fileNameView", ascending: false)]
        let results = realm.objects(tableMetadata.self).filter(predicate).sorted(by: sortProperties)
        
        return Array(results.map { tableMetadata.init(value:$0) })
    }
    
    //MARK: -
    //MARK: Table Photo Library
    
    @objc func addPhotoLibrary(_ assets: [PHAsset], account: String) -> Bool {
        
        let realm = try! Realm()

        do {
            try realm.safeWrite {
            
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
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
            return false
        }
        
        return true
    }
    
    @objc func getPhotoLibraryIdAsset(image: Bool, video: Bool, account: String) -> [String]? {
        
        let realm = try! Realm()
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
    
    @objc func addShare(urlBase: String, account: String, shares: [NCCommunicationShare]) {
        
        let realm = try! Realm()
        realm.beginWrite()

        for share in shares {
            
            let addObject = tableShare()
            let fullPath = NCUtility.shared.getHomeServer(urlBase: urlBase, account: account) + share.path
            let serverUrl = CCUtility.deletingLastPathComponent(fromServerUrl: fullPath)!
            let fileName = NSString(string: fullPath).lastPathComponent
                        
            addObject.account = account
            addObject.fileName = fileName
            addObject.serverUrl = serverUrl
            
            addObject.canEdit = share.canEdit
            addObject.canDelete = share.canDelete
            addObject.date = share.date
            addObject.displaynameFileOwner = share.displaynameFileOwner
            addObject.displaynameOwner = share.displaynameOwner
            addObject.expirationDate =  share.expirationDate
            addObject.fileParent = share.fileParent
            addObject.fileSource = share.fileSource
            addObject.fileTarget = share.fileTarget
            addObject.hideDownload = share.hideDownload
            addObject.idShare = share.idShare
            addObject.itemSource = share.itemSource
            addObject.itemType = share.itemType
            addObject.label = share.label
            addObject.mailSend = share.mailSend
            addObject.mimeType = share.mimeType
            addObject.note = share.note
            addObject.parent = share.parent
            addObject.password = share.password
            addObject.path = share.path
            addObject.permissions = share.permissions
            addObject.sendPasswordByTalk = share.sendPasswordByTalk
            addObject.shareType = share.shareType
            addObject.shareWith = share.shareWith
            addObject.shareWithDisplayname = share.shareWithDisplayname
            addObject.storage = share.storage
            addObject.storageId = share.storageId
            addObject.token = share.token
            addObject.uidOwner = share.uidOwner
            addObject.uidFileOwner = share.uidFileOwner
            addObject.url = share.url

            realm.add(addObject, update: .all)
        }
        
        do {
            try realm.commitWrite()
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func getTableShares(account: String) -> [tableShare] {
        
        let realm = try! Realm()
        
        let sortProperties = [SortDescriptor(keyPath: "shareType", ascending: false), SortDescriptor(keyPath: "idShare", ascending: false)]
        let results = realm.objects(tableShare.self).filter("account == %@", account).sorted(by: sortProperties)
        
        return Array(results.map { tableShare.init(value:$0) })
    }
    
    func getTableShares(metadata: tableMetadata) -> (firstShareLink: tableShare?,  share: [tableShare]?) {
        
        let realm = try! Realm()
        
        let sortProperties = [SortDescriptor(keyPath: "shareType", ascending: false), SortDescriptor(keyPath: "idShare", ascending: false)]
        
        let firstShareLink = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@ AND shareType == 3", metadata.account, metadata.serverUrl, metadata.fileName).first
        if firstShareLink == nil {
            let results = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, metadata.fileName).sorted(by: sortProperties)
            return(firstShareLink: firstShareLink, share: Array(results.map { tableShare.init(value:$0) }))
        } else {
            let results = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@ AND idShare != %d", metadata.account, metadata.serverUrl, metadata.fileName, firstShareLink!.idShare).sorted(by: sortProperties)
            return(firstShareLink: firstShareLink, share: Array(results.map { tableShare.init(value:$0) }))
        }
    }
    
    func getTableShare(account: String, idShare: Int) -> tableShare? {
        
        let realm = try! Realm()
        
        guard let result = realm.objects(tableShare.self).filter("account = %@ AND idShare = %d", account, idShare).first else {
            return nil
        }
        
        return tableShare.init(value: result)
    }
    
    @objc func getTableShares(account: String, serverUrl: String) -> [tableShare] {
        
        let realm = try! Realm()
        
        let sortProperties = [SortDescriptor(keyPath: "shareType", ascending: false), SortDescriptor(keyPath: "idShare", ascending: false)]
        let results = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).sorted(by: sortProperties)

        return Array(results.map { tableShare.init(value:$0) })
    }
    
    @objc func getTableShares(account: String, serverUrl: String, fileName: String) -> [tableShare] {
        
        let realm = try! Realm()
        
        let sortProperties = [SortDescriptor(keyPath: "shareType", ascending: false), SortDescriptor(keyPath: "idShare", ascending: false)]
        let results = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@", account, serverUrl, fileName).sorted(by: sortProperties)
        
        return Array(results.map { tableShare.init(value:$0) })
    }
    
    @objc func deleteTableShare(account: String, idShare: Int) {
        
        let realm = try! Realm()
        
        realm.beginWrite()
        
        let result = realm.objects(tableShare.self).filter("account == %@ AND idShare == %d", account, idShare)
        realm.delete(result)
        
        do {
            try realm.commitWrite()
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
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
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    //MARK: -
    //MARK: Table Tag
    
    @objc func addTag(_ ocId: String ,tagIOS: Data?, account: String) {
        
        let realm = try! Realm()
        
        do {
            try realm.safeWrite {
                
                // Add new
                let addObject = tableTag()
                    
                addObject.account = account
                addObject.ocId = ocId
                addObject.tagIOS = tagIOS
    
                realm.add(addObject, update: .all)
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
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
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func getTags(predicate: NSPredicate) -> [tableTag] {
        
        let realm = try! Realm()

        let results = realm.objects(tableTag.self).filter(predicate)
        
        return Array(results.map { tableTag.init(value:$0) })
    }
    
    @objc func getTag(predicate: NSPredicate) -> tableTag? {
        
        let realm = try! Realm()
        
        guard let result = realm.objects(tableTag.self).filter(predicate).first else {
            return nil
        }
        
        return tableTag.init(value: result)
    }
    
    //MARK: -
    //MARK: Table Trash
    
    @objc func addTrash(account: String, items: [NCCommunicationTrash]) {
        
        let realm = try! Realm()
        
        do {
            try realm.safeWrite {
                for trash in items {
                    let object = tableTrash()
                                    
                    object.account = account
                    object.contentType = trash.contentType
                    object.date = trash.date
                    object.directory = trash.directory
                    object.fileId = trash.fileId
                    object.fileName = trash.fileName
                    object.filePath = trash.filePath
                    object.hasPreview = trash.hasPreview
                    object.iconName = trash.iconName
                    object.size = trash.size
                    object.trashbinDeletionTime = trash.trashbinDeletionTime
                    object.trashbinFileName = trash.trashbinFileName
                    object.trashbinOriginalLocation = trash.trashbinOriginalLocation
                    object.typeFile = trash.typeFile
                    
                    realm.add(object, update: .all)
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func deleteTrash(filePath: String?, account: String) {
        
        let realm = try! Realm()
        var predicate = NSPredicate()

        do {
            try realm.safeWrite {
                
                if filePath == nil {
                    predicate = NSPredicate(format: "account == %@", account)
                } else {
                    predicate = NSPredicate(format: "account == %@ AND filePath == %@", account, filePath!)
                }
                
                let result = realm.objects(tableTrash.self).filter(predicate)
                realm.delete(result)
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func deleteTrash(fileId: String?, account: String) {
        
        let realm = try! Realm()
        var predicate = NSPredicate()

        do {
            try realm.safeWrite {
                
                if fileId == nil {
                    predicate = NSPredicate(format: "account == %@", account)
                } else {
                    predicate = NSPredicate(format: "account == %@ AND fileId == %@", account, fileId!)
                }
                
                let result = realm.objects(tableTrash.self).filter(predicate)
                realm.delete(result)
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
    
    @objc func getTrash(filePath: String, sort: String, ascending: Bool, account: String) -> [tableTrash]? {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableTrash.self).filter("account == %@ AND filePath == %@", account, filePath).sorted(byKeyPath: sort, ascending: ascending)

        return Array(results.map { tableTrash.init(value:$0) })
    }
    
    @objc func getTrashItem(fileId: String, account: String) -> tableTrash? {
        
        let realm = try! Realm()
        
        guard let result = realm.objects(tableTrash.self).filter("account == %@ AND fileId == %@", account, fileId).first else {
            return nil
        }
        
        return tableTrash.init(value: result)
    }
    
    //MARK: -
}

extension Realm {
    public func safeWrite(_ block: (() throws -> Void)) throws {
        if isInWriteTransaction {
            try block()
        } else {
            try write(block)
        }
    }
}
