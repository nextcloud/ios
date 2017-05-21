//
//  NCManageDatabase.swift
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 06/05/17.
//  Copyright © 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
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

class NCManageDatabase: NSObject {
        
    static let sharedInstance: NCManageDatabase = {
        let instance = NCManageDatabase()
        return instance
    }()
    
    override init() {
        
        let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.sharedInstance.capabilitiesGroups)
        let config = Realm.Configuration(
        
            fileURL: dirGroup?.appendingPathComponent("\(appDatabaseNextcloud)/\(k_databaseDefault)"),
            schemaVersion: 1,
            
            migrationBlock: { migration, oldSchemaVersion in
                // We haven’t migrated anything yet, so oldSchemaVersion == 0
                if (oldSchemaVersion < 1) {
                    // Nothing to do!
                    // Realm will automatically detect new properties and removed properties
                    // And will update the schema on disk automatically
                }
        })

        Realm.Configuration.defaultConfiguration = config
        _ = try! Realm()
    }
    
    //MARK: -
    //MARK: Utility Database

    func clearTable(_ table : Object.Type, account: String?) {
        
        let results : Results<Object>
        let realm = try! Realm()
        
        realm.beginWrite()
        
        if account != nil {
            
            results = realm.objects(table).filter("account = %@", account!)

        } else {
         
            results = realm.objects(table)
        }
    
        realm.delete(results)

        try! realm.commitWrite()
    }
    
    func removeDB() {
        
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
            } catch {
                // handle error
            }
        }
    }
    
    func getThreadConfined(_ table: Object) -> Any {
     
        // id tradeReference = [[NCManageDatabase sharedInstance] getThreadConfined:metadata];
        return ThreadSafeReference(to: table)
    }
    
    func putThreadConfined(_ tableRef: Any) -> Object? {
        
        //tableMetadata *metadataThread = (tableMetadata *)[[NCManageDatabase sharedInstance] putThreadConfined:tradeReference];
        let realm = try! Realm()
        
        return realm.resolve(tableRef as! ThreadSafeReference<Object>)
    }
    
    func isTableInvalidated(_ table: Object) -> Bool {
     
        return table.isInvalidated
    }
    
    //MARK: -
    //MARK: Table Account
    
    func addAccount(_ account: String, url: String, user: String, password: String) {

        let realm = try! Realm()
        
        realm.beginWrite()
            
        let addAccount = tableAccount()
            
        addAccount.account = account
            
        // Brand
        if NCBrandOptions.sharedInstance.use_default_automatic_upload {
                
            addAccount.cameraUpload = true
            addAccount.cameraUploadPhoto = true
            addAccount.cameraUploadVideo = true

            addAccount.cameraUploadWWAnVideo = true
        }
            
        addAccount.password = password
        addAccount.url = url
        addAccount.user = user
            
        realm.add(addAccount)
        
        try! realm.commitWrite()
    }
    
    func addTableAccountOldDB(_ table: TableAccount) {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableAccount.self).filter("account = %@", table.account!)
        if (results.count == 0) {
        
            try! realm.write {
                
                let addAccount = tableAccount()
                
                addAccount.account = table.account!
                if table.active == 1 {
                    addAccount.active = true
                }
                if table.cameraUpload == 1 {
                    addAccount.cameraUpload = true
                }
                if table.cameraUploadBackground == 1 {
                    addAccount.cameraUploadBackground = true
                }
                if table.cameraUploadCreateSubfolder == 1 {
                    addAccount.cameraUploadCreateSubfolder = true
                }
                if table.cameraUploadDatePhoto != nil {
                    addAccount.cameraUploadDatePhoto = table.cameraUploadDatePhoto! as NSDate
                }
                if table.cameraUploadDateVideo != nil {
                    addAccount.cameraUploadDateVideo = table.cameraUploadDateVideo! as NSDate
                }
                if table.cameraUploadFolderName != nil {
                    addAccount.cameraUploadFolderName = table.cameraUploadFolderName!
                }
                if table.cameraUploadFolderPath != nil {
                    addAccount.cameraUploadFolderPath = table.cameraUploadFolderPath!
                }
                if table.cameraUploadFull == 1 {
                    addAccount.cameraUploadFull = true
                }
                if table.cameraUploadPhoto == 1 {
                    addAccount.cameraUploadPhoto = true
                }
                if table.cameraUploadVideo == 1 {
                    addAccount.cameraUploadVideo = true
                }
                if table.cameraUploadWWAnPhoto == 1 {
                    addAccount.cameraUploadWWAnPhoto = true
                }
                if table.cameraUploadWWAnVideo == 1 {
                    addAccount.cameraUploadWWAnVideo = true
                }
                addAccount.password = table.password!
                addAccount.url = table.url!
                addAccount.user = table.user!
                
                realm.add(addAccount)
            }
        }
    }

    func setAccountPassword(_ account: String, password: String) {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableAccount.self).filter("account = %@", account)
        if (results.count > 0) {
            
            try! realm.write {
                results[0].password = password
            }
        }
    }
    
    func deleteAccount(_ account: String) {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableAccount.self).filter("account = %@", account)
        if (results.count > 0) {
            
            try! realm.write {
                realm.delete(results)
            }
        }
    }

    func getAccountActive() -> tableAccount? {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableAccount.self).filter("active = true")
        if (results.count > 0) {
            return results[0]
        } else {
            return nil
        }
    }

    func getAccounts() -> [String] {
        
        let realm = try! Realm()
        let results : Results<tableAccount>
        var accounts = [String]()
        
        results = realm.objects(tableAccount.self).sorted(byKeyPath: "account", ascending: true)
            
        for result in results {
            accounts.append(result.account)
        }

        return Array(accounts)
    }
    
    func getAccountCameraUploadFolderName() -> String {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableAccount.self).filter("active = true")
        if (results.count > 0) {
            
            if results[0].cameraUploadFolderName.characters.count > 0 {
                
                return results[0].cameraUploadFolderName
                
            } else {
                
                return k_folderDefaultCameraUpload
            }
        }
        
        return ""
    }
    
    func getAccountCameraUploadFolderPath(_ activeUrl : String) -> String {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableAccount.self).filter("active = true")
        if (results.count > 0) {
            
            if results[0].cameraUploadFolderPath.characters.count > 0 {
                
                return results[0].cameraUploadFolderPath
                
            } else {
                
                return CCUtility.getHomeServerUrlActiveUrl(activeUrl)
            }
        }
        
        return ""
    }

    func getAccountCameraUploadFolderPathAndName(_ activeUrl : String) -> String {
        
        let cameraFolderName = self.getAccountCameraUploadFolderName()
        let cameraFolderPath = self.getAccountCameraUploadFolderPath(activeUrl)
     
        let folderPhotos = CCUtility.stringAppendServerUrl(cameraFolderPath, addFileName: cameraFolderName)!
        
        return folderPhotos
    }
    
    func setAccountActive(_ account: String) -> tableAccount {
        
        let realm = try! Realm()
        var activeAccount = tableAccount()
        
        let results = realm.objects(tableAccount.self)
        
        try! realm.write {
            
            for result in results {
                
                if result.account == account {
                    
                    result.active = true
                    activeAccount = result
                    
                } else {
                    
                    result.active = false
                }
            }
        }
        
        return activeAccount
    }

    func setAccountCameraStateFiled(_ field: String, state: Bool) {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableAccount.self).filter("active = true")
        if (results.count > 0) {
            try! realm.write {
                
                switch field {
                case "cameraUpload":
                    results[0].cameraUpload = state
                case "cameraUploadBackground":
                    results[0].cameraUploadBackground = state
                case "cameraUploadCreateSubfolder":
                    results[0].cameraUploadCreateSubfolder = state
                case "cameraUploadFull":
                    results[0].cameraUploadFull = state
                case "cameraUploadPhoto":
                    results[0].cameraUploadPhoto = state
                case "cameraUploadVideo":
                    results[0].cameraUploadVideo = state
                case "cameraUploadWWAnPhoto":
                    results[0].cameraUploadWWAnPhoto = state
                case "cameraUploadWWAnVideo":
                    results[0].cameraUploadWWAnVideo = state
                default:
                    print("No founfd field")
                }
            }
        }
    }
    
    func setAccountCameraUploadDateAssetType(_ assetMediaType: PHAssetMediaType, assetDate: NSDate?) {

        let realm = try! Realm()
        
        let results = realm.objects(tableAccount.self).filter("active = true")
        
        try! realm.write {
            if (assetMediaType == PHAssetMediaType.image && results.count > 0) {
                results[0].cameraUploadDatePhoto = assetDate
            }
            if (assetMediaType == PHAssetMediaType.video && results.count > 0) {
                results[0].cameraUploadDateVideo = assetDate
            }
        }
    }
    
    func setAccountCameraUploadFolderName(_ folderName: String?) {
        
        let realm = try! Realm()
        var folderName : String? = folderName
        
        if folderName == nil {
            folderName = self.getAccountCameraUploadFolderName()
        }
        
        let results = realm.objects(tableAccount.self).filter("active = true")
        if (results.count > 0) {
            try! realm.write {
                
                results[0].cameraUploadFolderName = folderName!
            }
        }
    }

    func setAccountCameraUploadFolderPath(_ pathName: String?, activeUrl: String) {
        
        let realm = try! Realm()
        var pathName : String? = pathName
        
        if pathName == nil {
            pathName = self.getAccountCameraUploadFolderPath(activeUrl)
        }
        
        let results = realm.objects(tableAccount.self).filter("active = true")
        if (results.count > 0) {
            try! realm.write {
                
                results[0].cameraUploadFolderPath = pathName!
            }
        }
    }
    
    func setAccountsUserProfile(_ userProfile: OCUserProfile) {
     
        let tblAccount = self.getAccountActive()
        if tblAccount == nil {
            return
        }
        
        let realm = try! Realm()
        
        let results = realm.objects(tableAccount.self).filter("account = %@", tblAccount!.account)
        if (results.count > 0) {

            try! realm.write {
                
                results[0].enabled = userProfile.enabled
                results[0].address = userProfile.address
                results[0].displayName = userProfile.displayName
                results[0].email = userProfile.email
                results[0].phone = userProfile.phone
                results[0].twitter = userProfile.twitter
                results[0].webpage = results[0].webpage
                
                results[0].quota = userProfile.quota
                results[0].quotaFree = userProfile.quotaFree
                results[0].quotaRelative = userProfile.quotaRelative
                results[0].quotaTotal = userProfile.quotaTotal
                results[0].quotaUsed = userProfile.quotaUsed
            }
        }
    }
    
    //MARK: -
    //MARK: Table Activity

    func getActivityWithPredicate(_ predicate: NSPredicate) -> [tableActivity] {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableActivity.self).filter(predicate).sorted(byKeyPath: "date", ascending: false)
        
        return Array(results)
    }

    func addActivityServer(_ listOfActivity: [OCActivity]) {
    
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return
        }
        
        let realm = try! Realm()
        
        try! realm.write {
            
            for activity in listOfActivity {
                
                let results = realm.objects(tableActivity.self).filter("idActivity = %d", activity.idActivity)
                if (results.count > 0) {
                    continue
                }
                
                // Add new Activity
                let addActivity = tableActivity()
                
                addActivity.account = tableAccount!.account
                
                if activity.date != nil {
                    addActivity.date = activity.date! as NSDate
                }
                
                addActivity.idActivity = Double(activity.idActivity)
                addActivity.link = activity.link
                addActivity.note = activity.subject
                addActivity.type = k_activityTypeInfo

                realm.add(addActivity)
            }
        }
    }
    
    func addActivityClient(_ file: String, fileID: String, action: String, selector: String, note: String, type: String, verbose: Bool, activeUrl: String?) {

        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return
        }
        
        var noteReplacing : String = ""
        
        if (activeUrl != nil) {
            noteReplacing = note.replacingOccurrences(of: "\(activeUrl!)\(webDAV)", with: "")
        }
        noteReplacing = note.replacingOccurrences(of: "\(k_domain_session_queue).", with: "")

        let realm = try! Realm()
        
        try! realm.write {

            // Add new Activity
            let addActivity = tableActivity()

            addActivity.account = tableAccount!.account
            addActivity.action = action
            addActivity.file = file
            addActivity.fileID = fileID
            addActivity.note = noteReplacing
            addActivity.selector = selector
            addActivity.type = type
            addActivity.verbose = verbose

            realm.add(addActivity)
        }
    }
    
    //MARK: -
    //MARK: Table Automatic Upload
    
    func addAutomaticUpload(_ metadataNet: CCMetadataNet) -> Bool {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return false
        }
        
        let realm = try! Realm()
            
        let results = realm.objects(tableAutomaticUpload.self).filter("account = %@ AND assetLocalIdentifier = %@", tableAccount!.account, metadataNet.assetLocalIdentifier)
        if (results.count > 0) {
            return false
        }
        
        try! realm.write {
            
            // Add new AutomaticUpload
            let addAutomaticUpload = tableAutomaticUpload()
            
            addAutomaticUpload.account = tableAccount!.account
            addAutomaticUpload.assetLocalIdentifier = metadataNet.assetLocalIdentifier
            addAutomaticUpload.fileName = metadataNet.fileName
            addAutomaticUpload.selector = metadataNet.selector
            if (metadataNet.selectorPost != nil) {
                addAutomaticUpload.selectorPost = metadataNet.selectorPost
            }
            addAutomaticUpload.serverUrl = metadataNet.serverUrl
            addAutomaticUpload.session = metadataNet.session
            addAutomaticUpload.priority = metadataNet.priority
            
            realm.add(addAutomaticUpload)
        }

        return true
    }
    
    func getAutomaticUpload(_ selector: String) -> CCMetadataNet? {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return nil
        }
        
        let realm = try! Realm()
        
        let results = realm.objects(tableAutomaticUpload.self).filter("account = %@ AND selector = %@ AND lock == false", tableAccount!.account, selector)
        if (results.count == 0) {
            return nil
        }

        let metadataNet = CCMetadataNet()
        
        metadataNet.action = actionUploadAsset
        metadataNet.assetLocalIdentifier = results[0].assetLocalIdentifier
        metadataNet.fileName = results[0].fileName
        metadataNet.priority = results[0].priority
        metadataNet.selector = results[0].selector
        metadataNet.selectorPost = results[0].selectorPost
        metadataNet.serverUrl = results[0].serverUrl
        metadataNet.session = results[0].session
        metadataNet.taskStatus = Int(k_taskStatusResume)
        
        // Lock
        try! realm.write {
            results[0].lock = true
        }
        
        return metadataNet
    }
    
    func getLockAutomaticUpload() -> [tableAutomaticUpload]? {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return nil
        }
        
        let realm = try! Realm()
        
        let results = realm.objects(tableAutomaticUpload.self).filter("account = %@ AND lock = true", tableAccount!.account)
        
        return Array(results)
    }

    func unlockAutomaticUpload(_ assetLocalIdentifier: String) {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return
        }
        
        let realm = try! Realm()
        
        let results = realm.objects(tableAutomaticUpload.self).filter("account = %@ AND assetLocalIdentifier = %@", tableAccount!.account, assetLocalIdentifier)
        if (results.count > 0) {
            
            // UnLock
            try! realm.write {
                results[0].lock = false
            }
        }
    }
    
    func deleteAutomaticUpload(_ assetLocalIdentifier: String) {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return
        }

        let realm = try! Realm()

        let results = realm.objects(tableAutomaticUpload.self).filter("account = %@ AND assetLocalIdentifier = %@", tableAccount!.account, assetLocalIdentifier)
        if (results.count > 0) {
            
            try! realm.write {
                realm.delete(results)
            }
        }
    }
    
    func countAutomaticUpload(_ session: String?) -> Int {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return 0
        }

        let realm = try! Realm()
        let results : Results<tableAutomaticUpload>
        
        if (session == nil) {
            
            results = realm.objects(tableAutomaticUpload.self).filter("account = %@", tableAccount!.account)
            
        } else {
            
            results = realm.objects(tableAutomaticUpload.self).filter("account = %@ AND session = %@", tableAccount!.account, session!)
        }
        
        return results.count
    }
    
    //MARK: -
    //MARK: Table Capabilities
    
    func addCapabilities(_ capabilities: OCCapabilities) {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return
        }

        let realm = try! Realm()

        let results = realm.objects(tableCapabilities.self).filter("account = %@", tableAccount!.account)
        
        try! realm.write {
            
            var resultCapabilities = tableCapabilities()
            
            if (results.count > 0) {
                resultCapabilities = results[0]
            }
            
            resultCapabilities.account = tableAccount!.account
            resultCapabilities.themingBackground = capabilities.themingBackground
            resultCapabilities.themingColor = capabilities.themingColor
            resultCapabilities.themingLogo = capabilities.themingLogo
            resultCapabilities.themingName = capabilities.themingName
            resultCapabilities.themingSlogan = capabilities.themingSlogan
            resultCapabilities.themingUrl = capabilities.themingUrl
            resultCapabilities.versionMajor = capabilities.versionMajor
            resultCapabilities.versionMinor = capabilities.versionMinor
            resultCapabilities.versionMicro = capabilities.versionMicro
            resultCapabilities.versionString = capabilities.versionString
            
            if (results.count == 0) {
                realm.add(resultCapabilities)
            }
        }
    }
    
    func getCapabilites() -> tableCapabilities? {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return nil
        }
        
        let realm = try! Realm()

        let results = realm.objects(tableCapabilities.self).filter("account = %@", tableAccount!.account)
        
        if (results.count > 0) {
            return results[0]
        } else {
            return nil
        }
    }
    
    func getServerVersion() -> Int {

        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return 0
        }

        let realm = try! Realm()
        
        let results = realm.objects(tableCapabilities.self).filter("account = %@", tableAccount!.account)

        if (results.count > 0) {
            return results[0].versionMajor
        } else {
            return 0
        }
    }

    //MARK: -
    //MARK: Table Certificates
    
    func addCertificates(_ certificateLocation: String) {
    
        let realm = try! Realm()
        
        try! realm.write {
            
            let addCertificates = tableCertificates()
            
            addCertificates.certificateLocation = certificateLocation
            
            realm.add(addCertificates)
        }
    }
    
    func getCertificatesLocation(_ localCertificatesFolder: String) -> [String] {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableCertificates.self)
    
        var arraycertificatePath = [String]()
    
        for result in results {
            arraycertificatePath.append("\(localCertificatesFolder)\(result.certificateLocation)")
        }
        
        return arraycertificatePath
    }

    //MARK: -
    //MARK: Table External Sites
    
    func addExternalSites(_ externalSites: OCExternalSites) {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return
        }
        
        let realm = try! Realm()

        try! realm.write {
            
            let addExternalSite = tableExternalSites()
            
            addExternalSite.account = tableAccount!.account
            addExternalSite.idExternalSite = externalSites.idExternalSite
            addExternalSite.icon = externalSites.icon
            addExternalSite.lang = externalSites.lang
            addExternalSite.name = externalSites.name
            addExternalSite.url = externalSites.url
            addExternalSite.type = externalSites.type
           
            realm.add(addExternalSite)
        }
    }

    func deleteExternalSites() {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return
        }
        
        let realm = try! Realm()

        let results = realm.objects(tableExternalSites.self).filter("account = %@", tableAccount!.account)
        try! realm.write {
            realm.delete(results)
        }
    }
    
    func getAllExternalSitesWithPredicate(_ predicate: NSPredicate) -> [tableExternalSites] {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableExternalSites.self).filter(predicate).sorted(byKeyPath: "idExternalSite", ascending: true)
        
        return Array(results)
    }

    //MARK: -
    //MARK: Table GPS
    
    func addGeocoderLocation(_ location: String, placemarkAdministrativeArea: String, placemarkCountry: String, placemarkLocality: String, placemarkPostalCode: String, placemarkThoroughfare: String, latitude: String, longitude: String) {

        let realm = try! Realm()

        // Verify if exists
        let results = realm.objects(tableGPS.self).filter("latitude = %@ AND longitude = %@", latitude, longitude)
        if (results.count > 0) {
            return
        }
                
        try! realm.write {
            
            // Add new GPS
            let addGPS = tableGPS()
                
            addGPS.location = location
            addGPS.placemarkAdministrativeArea = placemarkAdministrativeArea
            addGPS.placemarkCountry = placemarkCountry
            addGPS.placemarkLocality = placemarkLocality
            addGPS.placemarkPostalCode = placemarkPostalCode
            addGPS.placemarkThoroughfare = placemarkThoroughfare
            addGPS.latitude = latitude
            addGPS.longitude = longitude
                
            realm.add(addGPS)
        }
    }
    
    func getLocationFromGeoLatitude(_ latitude: String, longitude: String) -> String? {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableGPS.self).filter("latitude = %@ AND longitude = %@", latitude, longitude)
        
        if (results.count == 0) {
            return nil
        } else {
            return results[0].location
        }
    }

    //MARK: -
    //MARK: Table Share
    
    func addShareLink(_ share: String, fileName: String, serverUrl: String) -> [String:String]? {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return nil
        }
        
        let realm = try! Realm()

        // Verify if exists
        let results = realm.objects(tableShare.self).filter("account = %@ AND fileName = %@ AND serverUrl = %@", tableAccount!.account, fileName, serverUrl)
        if (results.count > 0) {
            try! realm.write {
                results[0].shareLink = share;
            }
            
        } else {
        
            // Add new record
            try! realm.write {
            
            let addShare = tableShare()
            
                addShare.account = tableAccount!.account
                addShare.fileName = fileName
                addShare.serverUrl = serverUrl
                addShare.shareLink = share
            
                realm.add(addShare)
            }
        }
        
        return ["\(serverUrl)\(fileName)" : share]
    }

    func addShareUserAndGroup(_ share: String, fileName: String, serverUrl: String) -> [String:String]? {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return nil
        }
        
        let realm = try! Realm()

        // Verify if exists
        let results = realm.objects(tableShare.self).filter("account = %@ AND fileName = %@ AND serverUrl = %@", tableAccount!.account, fileName, serverUrl)
        if (results.count > 0) {
            try! realm.write {
                results[0].shareUserAndGroup = share;
            }
            
        } else {
            
            // Add new record
            try! realm.write {
                
                let addShare = tableShare()
                
                addShare.account = tableAccount!.account
                addShare.fileName = fileName
                addShare.serverUrl = serverUrl
                addShare.shareUserAndGroup = share
                
                realm.add(addShare)
            }
        }
        
        return ["\(serverUrl)\(fileName)" : share]
    }
    
    func unShare(_ share: String, fileName: String, serverUrl: String, sharesLink: [String:String], sharesUserAndGroup: [String:String]) -> [Any]? {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return nil
        }
        
        var sharesLink = sharesLink
        var sharesUserAndGroup = sharesUserAndGroup
        
        let realm = try! Realm()
        
        let results = realm.objects(tableShare.self).filter("account = %@ AND (shareLink CONTAINS %@ OR shareUserAndGroup CONTAINS %@)", tableAccount!.account, share, share)
        if (results.count > 0) {
            
            let result = results[0]
            
            realm.beginWrite()
                
            if (result.shareLink.contains(share)) {
                result.shareLink = ""
            }
                
            if (result.shareUserAndGroup.contains(share)) {
                    
                var shares : [String] = result.shareUserAndGroup.components(separatedBy: ",")
                if let index = shares.index(of:share) {
                    shares.remove(at: index)
                }
                result.shareUserAndGroup = shares.joined(separator: ",")
            }
            
            if (result.shareLink.characters.count > 0) {
                sharesLink.updateValue(result.shareLink, forKey:"\(serverUrl)\(fileName)")
            } else {
                sharesLink.removeValue(forKey: "\(serverUrl)\(fileName)")
            }
            
            if (result.shareUserAndGroup.characters.count > 0) {
                sharesUserAndGroup.updateValue(result.shareUserAndGroup, forKey:"\(serverUrl)\(fileName)")
            } else {
                sharesUserAndGroup.removeValue(forKey: "\(serverUrl)\(fileName)")
            }
            
            if (result.shareLink.characters.count == 0 && result.shareUserAndGroup.characters.count == 0) {
                realm.delete(result)
            }
            try! realm.commitWrite()
        }
        
        return [sharesLink, sharesUserAndGroup]
    }
    
    func removeShareActiveAccount() {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return
        }
        
        let realm = try! Realm()
        
        let results = realm.objects(tableShare.self).filter("account = %@", tableAccount!.account)
        try! realm.write {
            realm.delete(results)
        }
    }
    
    func updateShare(_ items: [String:OCSharedDto], activeUrl: String) -> [Any]? {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return nil
        }
        
        var sharesLink = [String:String]()
        var sharesUserAndGroup = [String:String]()

        self.removeShareActiveAccount()
     
        var itemsLink = [OCSharedDto]()
        var itemsUsersAndGroups = [OCSharedDto]()
        
        for (_, itemOCSharedDto) in items {
            
            if (itemOCSharedDto.shareType == Int(shareTypeLink.rawValue)) {
                itemsLink.append(itemOCSharedDto)
            }
            
            if (itemOCSharedDto.shareWith.characters.count > 0 && (itemOCSharedDto.shareType == Int(shareTypeUser.rawValue) || itemOCSharedDto.shareType == Int(shareTypeGroup.rawValue) || itemOCSharedDto.shareType == Int(shareTypeRemote.rawValue)  )) {
                itemsUsersAndGroups.append(itemOCSharedDto)
            }
        }
        
        // Manage sharesLink

        for itemOCSharedDto in itemsLink {
            
            let fullPath = CCUtility.getHomeServerUrlActiveUrl(activeUrl) + "\(itemOCSharedDto.path!)"
            let fileName = NSString(string: fullPath).lastPathComponent
            var serverUrl = NSString(string: fullPath).substring(to: (fullPath.characters.count - fileName.characters.count - 1))
            
            if serverUrl.hasSuffix("/") {
                serverUrl = NSString(string: serverUrl).substring(to: (serverUrl.characters.count - 1))
            }
            
            if itemOCSharedDto.idRemoteShared > 0 {
                let sharesLinkReturn = self.addShareLink("\(itemOCSharedDto.idRemoteShared)", fileName: fileName, serverUrl: serverUrl)
                if sharesLinkReturn != nil {
                    for (key,value) in sharesLinkReturn! {
                        sharesLink.updateValue(value, forKey:key)
                    }
                }
            }
        }
        
        // Manage sharesUserAndGroup
        
        var paths = [String:[String]]()
        
        for itemOCSharedDto in itemsUsersAndGroups {
            
            if paths[itemOCSharedDto.path] != nil {
                
                var share : [String] = paths[itemOCSharedDto.path]!
                share.append("\(itemOCSharedDto.idRemoteShared)")
                paths[itemOCSharedDto.path] = share
                
            } else {
                
                paths[itemOCSharedDto.path] = ["\(itemOCSharedDto.idRemoteShared)"]
            }
        }
        
        for (path, idsRemoteSharedArray) in paths {
            
            let idsRemoteShared = idsRemoteSharedArray.joined(separator: ",")
            
            print("[LOG] share \(String(describing: idsRemoteShared))")
            
            let fullPath = CCUtility.getHomeServerUrlActiveUrl(activeUrl) + "\(path)"
            let fileName = NSString(string: fullPath).lastPathComponent
            var serverUrl = NSString(string: fullPath).substring(to: (fullPath.characters.count - fileName.characters.count - 1))
            
            if serverUrl.hasSuffix("/") {
                serverUrl = NSString(string: serverUrl).substring(to: (serverUrl.characters.count - 1))
            }
            
            let sharesUserAndGroupReturn = self.addShareUserAndGroup(idsRemoteShared, fileName: fileName, serverUrl: serverUrl)
            if sharesUserAndGroupReturn != nil {
                for (key,value) in sharesUserAndGroupReturn! {
                    sharesUserAndGroup.updateValue(value, forKey:key)
                }
            }
        }
        
        return [sharesLink, sharesUserAndGroup]
    }
    
    func getShares() -> [Any]? {

        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return nil
        }
        
        var sharesLink = [String:String]()
        var sharesUserAndGroup = [String:String]()
        
        let realm = try! Realm()

        let results = realm.objects(tableShare.self).filter("account = %@", tableAccount!.account)
        
        for resultShare in results {
            
            if (resultShare.shareLink.characters.count > 0) {
                sharesLink = [resultShare.shareLink: "\(resultShare.serverUrl)\(resultShare.fileName)"]
            }
            
            if (resultShare.shareUserAndGroup.characters.count > 0) {
                sharesUserAndGroup = [resultShare.shareUserAndGroup: "\(resultShare.serverUrl)\(resultShare.fileName)"]
            }
        }
        
        return [sharesLink, sharesUserAndGroup]
    }
    
    //MARK: -
    //MARK: Table Metadata

    func addMetadata(_ metadata: tableMetadata, activeUrl: String) {

        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return
        }
        
        let cameraFolderName = self.getAccountCameraUploadFolderName()
        let cameraFolderPath = self.getAccountCameraUploadFolderPath(activeUrl)
        let directory = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID)
        
        let realm = try! Realm()
        
        try! realm.write {
            
            if (metadata.realm == nil) {
                let metadataWithIcon = CCUtility.insertTypeFileIconName(metadata, directory: directory, cameraFolderName: cameraFolderName, cameraFolderPath: cameraFolderPath)
                realm.add(metadataWithIcon!, update: true)
            } else {
                realm.add(metadata, update: true)
            }
        }
        
        self.setDateReadDirectory(directoryID: metadata.directoryID)
    }
    
    func deleteMetadata(_ predicate: NSPredicate) {
    
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return
        }
        
        let realm = try! Realm()
        
        let results = realm.objects(tableMetadata.self).filter(predicate)
        
        for result in results {
            self.setDateReadDirectory(directoryID: result.directoryID)
        }
        
        try! realm.write {
            realm.delete(results)
        }
    }
    
    func moveMetadata(_ fileName: String, directoryID: String, directoryIDTo: String) {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return
        }
        
        let realm = try! Realm()
    
        let results = realm.objects(tableMetadata.self).filter("account = %@ AND fileName == %@ AND directoryID == %@", tableAccount!.account, fileName, directoryID)
        
        try! realm.write {
            
            for result in results {
                result.directoryID = directoryIDTo
            }
        }
        
        self.setDateReadDirectory(directoryID: directoryID)
        self.setDateReadDirectory(directoryID: directoryIDTo)
    }
    
    func updateMetadata(_ metadata: tableMetadata, activeUrl: String) {
        
        let cameraFolderName = self.getAccountCameraUploadFolderName()
        let cameraFolderPath = self.getAccountCameraUploadFolderPath(activeUrl)
        let serverUrl = self.getServerUrl(metadata.directoryID)
        
        let metadataWithIcon = CCUtility.insertTypeFileIconName(metadata, directory: serverUrl, cameraFolderName: cameraFolderName, cameraFolderPath: cameraFolderPath)
        
        let realm = try! Realm()
        
        try! realm.write {
            realm.add(metadataWithIcon!, update: true)
        }
        
        self.setDateReadDirectory(directoryID: metadata.directoryID)
    }
    
    func setMetadataSession(_ session: String?, sessionError: String?, sessionSelector: String?, sessionSelectorPost: String?, sessionTaskIdentifier: Int, sessionTaskIdentifierPlist: Int, predicate: NSPredicate) {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return
        }
        
        let realm = try! Realm()
        
        let results = realm.objects(tableMetadata.self).filter(predicate)
        
        try! realm.write {
            
            for result in results {
            
                if session != nil {
                    result.session = session!
                }
                if sessionError != nil {
                    result.sessionError = sessionError!
                }
                if sessionSelector != nil {
                    result.sessionSelector = sessionSelector!
                }
                if sessionSelectorPost != nil {
                    result.sessionSelectorPost = sessionSelectorPost!
                }
                if sessionTaskIdentifier != Int(k_taskIdentifierNULL) {
                    result.sessionTaskIdentifier = sessionTaskIdentifier
                }
                if sessionTaskIdentifierPlist != Int(k_taskIdentifierNULL) {
                    result.sessionTaskIdentifierPlist = sessionTaskIdentifierPlist
                }
                
                self.setDateReadDirectory(directoryID: result.directoryID)
            }
        }
    }
    
    func setMetadataFavorite(_ fileID: String, favorite: Bool) {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return
        }
        
        let realm = try! Realm()
        
        let results = realm.objects(tableMetadata.self).filter("account = %@ AND fileID = %@", tableAccount!.account, fileID)
        
        if (results.count > 0) {
            
            try! realm.write {
                results[0].favorite = favorite
            }
            
            self.setDateReadDirectory(directoryID: results[0].directoryID)
        }
    }

    func getMetadataWithPreficate(_ predicate: NSPredicate) -> tableMetadata? {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return nil
        }
        
        let realm = try! Realm()
        
        let results = realm.objects(tableMetadata.self).filter(predicate)
        
        if (results.count > 0) {
            
            return results[0]
            
        } else {
            
            return nil
        }
    }

    func getMetadatasWithPreficate(_ predicate: NSPredicate, sorted: String?, ascending: Bool) -> [tableMetadata]? {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return nil
        }
        
        let realm = try! Realm()
        let results : Results<tableMetadata>

        if sorted == nil {
            
            results = realm.objects(tableMetadata.self).filter(predicate)
            
        } else {
            
            results = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted!, ascending: ascending)
        }
        
        if (results.count > 0) {
            
            return Array(results)
            
        } else {
            
            return nil
        }
    }
    
    func getMetadataAtIndex(_ predicate: NSPredicate, sorted: String?, ascending: Bool, index: Int) -> tableMetadata? {

        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return nil
        }
        
        let realm = try! Realm()
        
        let results = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted!, ascending: ascending)
        
        if (results.count > 0  && results.count > index) {
            
            return results[index]
            
        } else {
            
            return nil
        }
    }
    
    func getMetadataFromFileName(_ fileName: String, directoryID: String) -> tableMetadata? {
    
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return nil
        }
        
        let realm = try! Realm()
        
        let results = realm.objects(tableMetadata.self).filter("(account = %@) AND (directoryID = %@) AND ((fileName = %@) OR (fileNameData = %@))", tableAccount!.account, directoryID, fileName, fileName)
        
        if (results.count > 0) {

            return results[0]
            
        } else {
            
            return nil
        }
    }
    
    func getTableMetadataDownload() -> [tableMetadata]? {
    
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return nil
        }
        
        let predicate = NSPredicate(format: "(account == %@) AND ((session == %@) || (session == %@)) AND ((sessionTaskIdentifier != %i) OR (sessionTaskIdentifierPlist != %i))", tableAccount!.account, k_download_session, k_download_session_foreground, k_taskIdentifierDone, k_taskIdentifierDone)
        
        return self.getMetadatasWithPreficate(predicate, sorted: nil, ascending: false)
    }
    
    func getTableMetadataDownloadWWan() -> [tableMetadata]? {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return nil
        }
        
        let predicate = NSPredicate(format: "(account == %@) AND (session == %@) AND ((sessionTaskIdentifier != %i) OR (sessionTaskIdentifierPlist != %i))", tableAccount!.account, k_download_session_wwan, k_taskIdentifierDone, k_taskIdentifierDone)
        
        return self.getMetadatasWithPreficate(predicate, sorted: nil, ascending: false)
    }
    
    func getTableMetadataUpload() -> [tableMetadata]? {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return nil
        }
        
        let predicate = NSPredicate(format: "(account == %@) AND ((session == %@) || (session == %@)) AND ((sessionTaskIdentifier != %i) OR (sessionTaskIdentifierPlist != %i))", tableAccount!.account, k_upload_session, k_upload_session_foreground, k_taskIdentifierDone, k_taskIdentifierDone)
        
        return self.getMetadatasWithPreficate(predicate, sorted: nil, ascending: false)
    }

    func getTableMetadataUploadWWan() -> [tableMetadata]? {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return nil
        }
        
        let predicate = NSPredicate(format: "(account == %@) AND (session == %@) AND ((sessionTaskIdentifier != %i) OR (sessionTaskIdentifierPlist != %i))", tableAccount!.account, k_upload_session_wwan, k_taskIdentifierDone, k_taskIdentifierDone)
        
        return self.getMetadatasWithPreficate(predicate, sorted: nil, ascending: false)
    }

    func getRecordsTableMetadataPhotosCameraUpload(_ serverUrl: String) -> [tableMetadata]? {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return nil
        }
        
        let realm = try! Realm()
        
        /*
        var recordsPhotosCameraUpload = [tableMetadata]()
        let tableDirectoryes = CCCoreData.getDirectoryIDsFromBegins(withServerUrl: serverUrl, activeAccount: tableAccount!.account)
        
        for result in tableDirectoryes! {
            
            
        
        }
        */
        
        let directoryID = self.getDirectoryID(serverUrl)
        
        
        let predicate = NSPredicate(format: "(account == %@) AND (directoryID == %@) AND (session == '')AND (type == 'file') AND ((typeFile == %@) OR (typeFile == %@))", tableAccount!.account, directoryID, k_metadataTypeFile_image, k_metadataTypeFile_video)
        
        let sorted = CCUtility.getOrderSettings()
        let ascending = CCUtility.getAscendingSettings()
        
        let results = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted!, ascending: ascending)
        
        if results.count > 0 {
            
            return Array(results)
            
        } else {
            
            return nil
        }
    }

    func copyTableMetadata(_ metadata: tableMetadata) -> tableMetadata {
        
        let copyMetadata = tableMetadata()
        
        copyMetadata.account = metadata.account
        copyMetadata.assetLocalIdentifier = metadata.assetLocalIdentifier
        copyMetadata.cryptated = metadata.cryptated
        copyMetadata.date = metadata.date
        copyMetadata.directory = metadata.directory
        copyMetadata.directoryID = metadata.directoryID
        copyMetadata.errorPasscode = metadata.errorPasscode
        copyMetadata.fileID = metadata.fileID
        copyMetadata.favorite = metadata.favorite
        copyMetadata.fileName = metadata.fileName
        copyMetadata.fileNameData = metadata.fileNameData
        copyMetadata.fileNamePrint = metadata.fileNamePrint
        copyMetadata.iconName = metadata.iconName
        copyMetadata.model = metadata.model
        copyMetadata.nameCurrentDevice = metadata.nameCurrentDevice
        copyMetadata.permissions = metadata.permissions
        copyMetadata.protocolCrypto = metadata.protocolCrypto
        copyMetadata.rev = metadata.rev
        copyMetadata.session = metadata.session
        copyMetadata.sessionError = metadata.sessionError
        copyMetadata.sessionID = metadata.sessionID
        copyMetadata.sessionSelector = metadata.sessionSelector
        copyMetadata.sessionSelectorPost = metadata.sessionSelectorPost
        copyMetadata.sessionTaskIdentifier = metadata.sessionTaskIdentifier
        copyMetadata.sessionTaskIdentifierPlist = metadata.sessionTaskIdentifierPlist
        copyMetadata.size = metadata.size
        copyMetadata.thumbnailExists = metadata.thumbnailExists
        copyMetadata.title = metadata.title
        copyMetadata.type = metadata.type
        copyMetadata.typeFile = metadata.typeFile
        copyMetadata.uuid = metadata.uuid
        
        return copyMetadata
    }
    
    //MARK: -
    //MARK: Table Directory
    
    func addDirectory(serverUrl: String, permissions: String) -> String {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return ""
        }
        
        let realm = try! Realm()
        let results = realm.objects(tableDirectory.self).filter("serverUrl = %@", serverUrl)
        var directoryID: String = ""

        try! realm.write {
            
            if results.count > 0 {
                
                results[0].permissions = permissions
                directoryID = results[0].directoryID
                realm.add(results, update: true)
                
            } else {
                
                let addDirectory = tableDirectory()
                addDirectory.account = tableAccount!.account
                
                directoryID = CCUtility.createRandomString(16)
                addDirectory.directoryID = directoryID
                
                addDirectory.permissions = permissions
                addDirectory.serverUrl = serverUrl
                realm.add(addDirectory, update: true)
            }
        }
        
        return directoryID
    }
    
    func deleteDirectoryAndSubDirectory(serverUrl: String) {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return
        }
        
        let realm = try! Realm()
        
        let results = realm.objects(tableDirectory.self).filter("account = %@ AND serverUrl BEGINSWITH %@", tableAccount!.account, serverUrl)
        
        try! realm.write {
            
            for result in results {
                
                // delete metadata
                self.deleteMetadata(NSPredicate(format: "directoryID = %@", result.directoryID))
                
                /*
                // remove if in session
                if ([recordMetadata.session length] >0) {
                 if (recordMetadata.sessionTaskIdentifier >= 0)
                  [[CCNetworking sharedNetworking] settingSession:recordMetadata.session sessionTaskIdentifier:[recordMetadata.sessionTaskIdentifier integerValue] taskStatus: k_taskStatusCancel];
 
                 if (recordMetadata.sessionTaskIdentifierPlist >= 0)
                  [[CCNetworking sharedNetworking] settingSession:recordMetadata.session sessionTaskIdentifier:[recordMetadata.sessionTaskIdentifierPlist integerValue] taskStatus: k_taskStatusCancel];
 
                 }
                 */
 
                // delete local
                //[self deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (fileID == %@)", activeAccount, recordMetadata.fileID]];

            }
 
            realm.delete(results)
        }
    }

    func renameDirectory(serverUrl: String, serverUrlTo: String) {
    
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return
        }
        
        let realm = try! Realm()
        
        try! realm.write {
            let results = realm.objects(tableDirectory.self).filter("serverUrl = %@", serverUrl)
            
            if results.count > 0 {
                results[0].serverUrl = serverUrlTo
            }
        }
    }
    
    func updateDirectoryFileID(serverUrl: String, fileID: String) {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return
        }
        
        let realm = try! Realm()
        
        try! realm.write {
            
            let results = realm.objects(tableDirectory.self).filter("serverUrl = %@", serverUrl)
            
            if results.count > 0 {
                
                results[0].rev = fileID
            }
        }
    }
    
    func clearDateRead(serverUrl: String?, directoryID: String?) {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return
        }
        
        let realm = try! Realm()
        
        try! realm.write {
            
            var results : Results<tableDirectory>?
            
            if serverUrl != nil {
                results = realm.objects(tableDirectory.self).filter("serverUrl = %@", serverUrl!)
            }
        
            if directoryID != nil {
                results = realm.objects(tableDirectory.self).filter("directoryID = %@", directoryID!)
            }
        
            if results != nil {
                
                if results!.count > 0 {
                
                    results![0].dateReadDirectory = nil
                    results![0].rev = ""
                    realm.add(results!, update: true)
                }
            }
        }
    }

    func getTableDirectory(predicate: NSPredicate) -> tableDirectory? {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return nil
        }
        
        let realm = try! Realm()
        
        let results = realm.objects(tableDirectory.self).filter(predicate)
        
        if (results.count > 0) {
            
            return results[0]
            
        } else {
            
            return nil
        }
    }
    
    func getTablesDirectory(predicate: NSPredicate, sorted: String?, ascending: Bool) -> [tableDirectory]? {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return nil
        }
        
        let realm = try! Realm()
        let results : Results<tableDirectory>
        
        if sorted == nil {
            
            results = realm.objects(tableDirectory.self).filter(predicate)
            
        } else {
            
            results = realm.objects(tableDirectory.self).filter(predicate).sorted(byKeyPath: sorted!, ascending: ascending)
        }
        
        if (results.count > 0) {
            
            return Array(results)
            
        } else {
            
            return nil
        }
    }


    func getDirectoryID(_ serverUrl: String) -> String {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return ""
        }
        
        let realm = try! Realm()
        
        let results = realm.objects(tableDirectory.self).filter("serverUrl = %@", serverUrl)
        if results.count > 0 {
            return results[0].directoryID
        } else {
            return ""
        }
    }

    func getServerUrl(_ directoryID: String) -> String {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return ""
        }
        
        let realm = try! Realm()
        let results = realm.objects(tableDirectory.self).filter("directoryID = %@", directoryID)

        if results.count > 0 {
            return results[0].serverUrl
        } else {
            return ""
        }
    }
    
    func setDateReadDirectory(directoryID: String) {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return
        }
        
        let realm = try! Realm()
        let results = realm.objects(tableDirectory.self).filter("account = %@ AND directoryID = %@", tableAccount!.account, directoryID)

        try! realm.write {
            
            if results.count > 0 {
                return results[0].dateReadDirectory = NSDate()
            }
        }
    }
    
    func setClearAllDateReadDirectory() {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return
        }
        
        let realm = try! Realm()
        let results = realm.objects(tableDirectory.self)//.filter("account = %@", tableAccount!.account)
        
        try! realm.write {
            
            for result in results {
                result.dateReadDirectory = nil;
                result.rev = ""
            }
        }
    }

    func setDirectoryLock(serverUrl: String, lock: Bool) -> Bool {
        
        var update = false

        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return update
        }
        
        let realm = try! Realm()
        
        try! realm.write {
            
            let results = realm.objects(tableDirectory.self).filter("account = %@ AND serverUrl = %@", tableAccount!.account, serverUrl)
            
            if results.count > 0 {
                
                results[0].lock = lock
                update = true
                
            }
        }
        
        return update
    }
    
    func setAllDirectoryUnLock() {
        
        let tableAccount = self.getAccountActive()
        if tableAccount == nil {
            return
        }
        
        let realm = try! Realm()
        let results = realm.objects(tableDirectory.self).filter("account = %@", tableAccount!.account)
        
        try! realm.write {
            
            for result in results {
                result.lock = false;
            }
        }
    }

    func copyTableDirectory(_ table: tableDirectory) -> tableDirectory {
        
        let copyTable = tableDirectory.init(value: table)
        
        
        return copyTable
    }



    //MARK: -
}
