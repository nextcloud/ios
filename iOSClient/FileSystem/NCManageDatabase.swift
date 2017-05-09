//
//  NCManageDatabase.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/05/17.
//  Copyright © 2017 TWS. All rights reserved.
//

import RealmSwift

class NCManageDatabase: NSObject {
        
    static let sharedInstance: NCManageDatabase = {
        let instance = NCManageDatabase()
        return instance
    }()
    
    override init() {
        
        let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: k_capabilitiesGroups)
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
            
            results = realm.objects(table).filter("account = '\(account!)'")

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
    //MARK: Table Activity

    func addActivityServer(_ listOfActivity: [OCActivity], account: String) {
    
        let realm = try! Realm()
        
        try! realm.write {
            
            for activity in listOfActivity {
                
                // Verify
                let results = realm.objects(tableActivity.self).filter("idActivity = \(activity.idActivity)")
                if (results.count > 0) {
                    continue
                }
                
                // Add new Activity
                let addActivity = tableActivity()
                
                addActivity.account = account
                addActivity.date = activity.date
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
    
    func getAllActivityWithPredicate(_ predicate: NSPredicate) -> [tableActivity] {
        
        let realm = try! Realm()

        let results = realm.objects(tableActivity.self).filter(predicate).sorted(byKeyPath: "date", ascending: false)
        
        return Array(results)
    }
    
    //MARK: -
    //MARK: Table Automatic Upload
    
    func addAutomaticUpload(_ metadataNet: CCMetadataNet, account: String) -> Bool {
        
        let realm = try! Realm()
        
        // Verify if exists
        let results = realm.objects(tableAutomaticUpload.self).filter("account = '\(account)' AND assetLocalIdentifier = '\(metadataNet.assetLocalIdentifier)'")
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
        
        // Verify if exists
        let results = realm.objects(tableAutomaticUpload.self).filter("account = '\(account)' AND selector = '\(selector)' AND (lock == false)")
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
        
        // Lock True
        try! realm.write {
            results[0].lock = true
        }
        
        return metadataNet
    }
    
    func getAllLockAutomaticUploadForAccount(_ account: String) -> [tableAutomaticUpload] {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableAutomaticUpload.self).filter("account = '\(account)' AND (lock = true)")
        
        return Array(results)
    }

    func unlockAutomaticUploadForAccount(_ account: String, assetLocalIdentifier: String) {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableAutomaticUpload.self).filter("account = '\(account)' AND (assetLocalIdentifier = '\(assetLocalIdentifier)')")
        if (results.count > 0) {
            
            // Lock False
            try! realm.write {
                results[0].lock = false
            }
        }
    }
    
    func deleteAutomaticUploadForAccount(_ account: String, assetLocalIdentifier: String) {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableAutomaticUpload.self).filter("account = '\(account)' AND (assetLocalIdentifier = '\(assetLocalIdentifier)')")
        if (results.count > 0) {
            
            try! realm.write {
                realm.delete(results)
            }
        }
    }
    
    func countAutomaticUploadForAccount(_ account: String, selector: String?) -> Int {
        
        let realm = try! Realm()
        let results : Results<tableAutomaticUpload>
        
        if (selector == nil) {
            
            results = realm.objects(tableAutomaticUpload.self).filter("account = '\(account)'")
            
        } else {
            
            results = realm.objects(tableAutomaticUpload.self).filter("account = '\(account)' AND (selector = '\(selector!)')")
        }
        
        return results.count
    }
    
    //MARK: -
    //MARK: Table Capabilities
    
    func addCapabilities(_ capabilities: OCCapabilities, account: String) {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableCapabilities.self).filter("account = '\(account)'")
        
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
        
        let results = realm.objects(tableCapabilities.self).filter("account = '\(account)'")
        
        if (results.count > 0) {
            return results[0]
        } else {
            return nil
        }
    }
    
    func getServerVersionAccount(_ account: String) -> Int {

        let realm = try! Realm()

        let results = realm.objects(tableCapabilities.self).filter("account = '\(account)'")

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
    
    func getAllCertificatesLocation(_ localCertificatesFolder: String) -> [String] {
        
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

    func deleteAllExternalSitesForAccount(_ account: String) {
        
        let realm = try! Realm()
        
        let results = realm.objects(tableExternalSites.self).filter("account = '\(account)'")
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
        let results = realm.objects(tableGPS.self).filter("latitude = '\(latitude)' AND longitude = '\(longitude)'")
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
        
        let results = realm.objects(tableGPS.self).filter("latitude = '\(latitude)' AND longitude = '\(longitude)'")
        
        if (results.count == 0) {
            return nil
        } else {
            return results[0].location
        }
    }

    //MARK: -
}
