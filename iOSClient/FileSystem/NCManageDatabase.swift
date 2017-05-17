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
        var config = Realm.Configuration()
        
        config.fileURL = dirGroup?.appendingPathComponent("\(appDatabaseNextcloud)/\(k_databaseDefault)")
        
        Realm.Configuration.defaultConfiguration = config
    }
    
    //MARK: -
    //MARK: Utility Database

    func clearTable(_ table : Object.Type, account: String?) {
        
        let results : Results<Object>
        let realm = try! Realm()
        
        if (account != nil) {
            
            results = realm.objects(table).filter("account = %@", account!)

        } else {
         
            results = realm.objects(table)
        }
    
        try! realm.write {
            realm.delete(results)
        }
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
    
    //MARK: -
    //MARK: Table Account
    
    func addAccount(_ account: String, url: String, user: String, password: String) {

        let realm = try! Realm()
        
        try! realm.write {
            
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
        }
    }
    
    func addTableAccountOldDB(_ table: TableAccount) {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableAccount.self).filter("account = %@", table.account!)
        if (results.count == 0) {
        
            try! realm.write {
                
                let addAccount = tableAccount()
                
                
                
                
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

    func getAccounts(_ account: String?) -> [tableAccount] {
        
        let realm = try! Realm()
        let results : Results<tableAccount>
            
        if account == nil {
            
            results = realm.objects(tableAccount.self).sorted(byKeyPath: "account", ascending: true)
            
        } else {
            
            results = realm.objects(tableAccount.self).filter("account = %@", account!).sorted(byKeyPath: "account", ascending: true)
        }
        
        return Array(results)
    }
    
    func getAccountsCameraUploadFolderName(_ activeUrl : String?) -> String {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableAccount.self).filter("active = true")
        if (results.count > 0) {
            
            if results[0].cameraUploadFolderName.characters.count > 0 {
                
                if activeUrl == nil {
                    
                    return results[0].cameraUploadFolderName
                    
                } else {
                    
                    return results[0].cameraUploadFolderPath
                }
                
            } else {
                
                if activeUrl == nil {
                    
                    return k_folderDefaultCameraUpload
                    
                } else {
                    
                    return CCUtility.getHomeServerUrlActiveUrl(activeUrl!)
                }
            }
        }
        
        return ""
    }

    func getAccountsCameraUploadFolderPath(_ activeUrl : String) -> String {
        
        let cameraFolderName = self.getAccountsCameraUploadFolderName(nil)
        let cameraFolderPath = self.getAccountsCameraUploadFolderName(activeUrl)
     
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

    func setAccountCameraStateFiled(field: String, state: Bool) {
        
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
    
    func setAccountsCameraUploadDateAssetType(assetMediaType: PHAssetMediaType, assetDate: NSDate?) {

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
    
    func setAccountsCameraUploadFolderName(folderName: String?) {
        
        let realm = try! Realm()
        var folderName : String? = folderName
        
        if folderName == nil {
            folderName = self.getAccountsCameraUploadFolderName(nil)
        }
        
        let results = realm.objects(tableAccount.self).filter("active = true")
        if (results.count > 0) {
            try! realm.write {
                
                results[0].cameraUploadFolderName = folderName!
            }
        }
    }

    func setAccountsCameraUploadFolderPath(pathName: String?, activeUrl: String) {
        
        let realm = try! Realm()
        var pathName : String? = pathName
        
        if pathName == nil {
            pathName = self.getAccountsCameraUploadFolderPath(activeUrl)
        }
        
        let results = realm.objects(tableAccount.self).filter("active = true")
        if (results.count > 0) {
            try! realm.write {
                
                results[0].cameraUploadFolderPath = pathName!
            }
        }
    }
    
    func setAccountsUserProfile(_ account: String, userProfile: OCUserProfile) {
     
        let realm = try! Realm()
        
        let results = realm.objects(tableAccount.self).filter("account = %@", account)
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

    func addActivityServer(_ listOfActivity: [OCActivity], account: String) {
    
        let realm = try! Realm()
        
        try! realm.write {
            
            for activity in listOfActivity {
                
                let results = realm.objects(tableActivity.self).filter("idActivity = %d", activity.idActivity)
                if (results.count > 0) {
                    continue
                }
                
                // Add new Activity
                let addActivity = tableActivity()
                
                addActivity.account = account
                
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
    
    func addActivityClient(_ file: String, fileID: String, action: String, selector: String, note: String, type: String, verbose: Bool, account: String?, activeUrl: String?) {

        var noteReplacing : String = ""
        
        if (activeUrl != nil) {
            noteReplacing = note.replacingOccurrences(of: "\(activeUrl!)\(webDAV)", with: "")
        }
        noteReplacing = note.replacingOccurrences(of: "\(k_domain_session_queue).", with: "")

        let realm = try! Realm()
        
        try! realm.write {

            // Add new Activity
            let addActivity = tableActivity()

            if (account != nil) {
                addActivity.account = account!
            }
            
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
    
    func addAutomaticUpload(_ metadataNet: CCMetadataNet, account: String) -> Bool {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableAutomaticUpload.self).filter("account = %@ AND assetLocalIdentifier = %@", account, metadataNet.assetLocalIdentifier)
        if (results.count > 0) {
            return false
        }
        
        try! realm.write {
            
            // Add new AutomaticUpload
            let addAutomaticUpload = tableAutomaticUpload()
            
            addAutomaticUpload.account = account
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
    
    func getAutomaticUploadForAccount(_ account: String, selector: String) -> CCMetadataNet? {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableAutomaticUpload.self).filter("account = %@ AND selector = %@ AND lock == false", account, selector)
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
    
    func getLockAutomaticUploadForAccount(_ account: String) -> [tableAutomaticUpload] {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableAutomaticUpload.self).filter("account = %@ AND lock = true", account)
        
        return Array(results)
    }

    func unlockAutomaticUploadForAccount(_ account: String, assetLocalIdentifier: String) {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableAutomaticUpload.self).filter("account = %@ AND assetLocalIdentifier = %@", account, assetLocalIdentifier)
        if (results.count > 0) {
            
            // UnLock
            try! realm.write {
                results[0].lock = false
            }
        }
    }
    
    func deleteAutomaticUploadForAccount(_ account: String, assetLocalIdentifier: String) {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableAutomaticUpload.self).filter("account = %@ AND assetLocalIdentifier = %@", account, assetLocalIdentifier)
        if (results.count > 0) {
            
            try! realm.write {
                realm.delete(results)
            }
        }
    }
    
    func countAutomaticUploadForAccount(_ account: String, session: String?) -> Int {
        
        let realm = try! Realm()
        let results : Results<tableAutomaticUpload>
        
        if (session == nil) {
            
            results = realm.objects(tableAutomaticUpload.self).filter("account = %@", account)
            
        } else {
            
            results = realm.objects(tableAutomaticUpload.self).filter("account = %@ AND session = %@", account, session!)
        }
        
        return results.count
    }
    
    //MARK: -
    //MARK: Table Capabilities
    
    func addCapabilities(_ capabilities: OCCapabilities, account: String) {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableCapabilities.self).filter("account = %@", account)
        
        try! realm.write {
            
            var resultCapabilities = tableCapabilities()
            
            if (results.count > 0) {
                resultCapabilities = results[0]
            }
            
            resultCapabilities.account = account
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
    
    func getCapabilitesForAccount(_ account: String) -> tableCapabilities? {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableCapabilities.self).filter("account = %@", account)
        
        if (results.count > 0) {
            return results[0]
        } else {
            return nil
        }
    }
    
    func getServerVersionAccount(_ account: String) -> Int {

        let realm = try! Realm()

        let results = realm.objects(tableCapabilities.self).filter("account = %@", account)

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
    
    func addExternalSites(_ externalSites: OCExternalSites, account: String) {
        
        let realm = try! Realm()
        
        try! realm.write {
            
            let addExternalSite = tableExternalSites()
            
            addExternalSite.account = account
            addExternalSite.idExternalSite = externalSites.idExternalSite
            addExternalSite.icon = externalSites.icon
            addExternalSite.lang = externalSites.lang
            addExternalSite.name = externalSites.name
            addExternalSite.url = externalSites.url
            addExternalSite.type = externalSites.type
           
            realm.add(addExternalSite)
        }
    }

    func deleteExternalSitesForAccount(_ account: String) {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableExternalSites.self).filter("account = %@", account)
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
    
    func addShareLink(_ share: String, fileName: String, serverUrl: String, account: String) -> [String:String] {
        
        let realm = try! Realm()
        
        // Verify if exists
        let results = realm.objects(tableShare.self).filter("account = %@ AND fileName = %@ AND serverUrl = %@", account, fileName, serverUrl)
        if (results.count > 0) {
            try! realm.write {
                results[0].shareLink = share;
            }
            
        } else {
        
            // Add new record
            try! realm.write {
            
            let addShare = tableShare()
            
                addShare.account = account
                addShare.fileName = fileName
                addShare.serverUrl = serverUrl
                addShare.shareLink = share
            
                realm.add(addShare)
            }
        }
        
        return ["\(serverUrl)\(fileName)" : share]
    }

    func addShareUserAndGroup(_ share: String, fileName: String, serverUrl: String, account: String) -> [String:String] {
        
        let realm = try! Realm()
        
        // Verify if exists
        let results = realm.objects(tableShare.self).filter("account = %@ AND fileName = %@ AND serverUrl = %@", account, fileName, serverUrl)
        if (results.count > 0) {
            try! realm.write {
                results[0].shareUserAndGroup = share;
            }
            
        } else {
            
            // Add new record
            try! realm.write {
                
                let addShare = tableShare()
                
                addShare.account = account
                addShare.fileName = fileName
                addShare.serverUrl = serverUrl
                addShare.shareUserAndGroup = share
                
                realm.add(addShare)
            }
        }
        
        return ["\(serverUrl)\(fileName)" : share]
    }
    
    func unShare(_ share: String, fileName: String, serverUrl: String, sharesLink: [String:String], sharesUserAndGroup: [String:String], account: String) -> [Any] {
        
        var sharesLink = sharesLink
        var sharesUserAndGroup = sharesUserAndGroup
        
        let realm = try! Realm()
        
        let results = realm.objects(tableShare.self).filter("account = %@ AND (shareLink CONTAINS %@ OR shareUserAndGroup CONTAINS %@)", account, share, share)
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
    
    func removeShareActiveAccount(_ account: String) {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableShare.self).filter("account = %@", account)
        try! realm.write {
            realm.delete(results)
        }
    }
    
    func updateShare(_ items: [String:OCSharedDto], account: String, activeUrl: String) -> [Any] {
        
        var sharesLink = [String:String]()
        var sharesUserAndGroup = [String:String]()

        self.removeShareActiveAccount(account)
     
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
                let sharesLinkReturn = self.addShareLink("\(itemOCSharedDto.idRemoteShared)", fileName: fileName, serverUrl: serverUrl, account: account)
                for (key,value) in sharesLinkReturn {
                    sharesLink.updateValue(value, forKey:key)
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
            
            let sharesUserAndGroupReturn = self.addShareUserAndGroup(idsRemoteShared, fileName: fileName, serverUrl: serverUrl, account: account)
            for (key,value) in sharesUserAndGroupReturn {
                sharesUserAndGroup.updateValue(value, forKey:key)
            }
        }
        
        return [sharesLink, sharesUserAndGroup]
    }
    
    func getSharesAccount(_ account: String) -> [Any] {

        var sharesLink = [String:String]()
        var sharesUserAndGroup = [String:String]()
        
        let realm = try! Realm()

        let results = realm.objects(tableShare.self).filter("account = %@", account)
        
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
}
