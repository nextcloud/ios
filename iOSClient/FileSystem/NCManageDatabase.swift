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

    func clearDB(_ table : Object.Type, account: String?) {
        
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
    
    func getAllTableActivityWithPredicate(_ predicate: NSPredicate) -> [tableActivity] {
        
        let realm = try! Realm()

        let results = realm.objects(tableActivity.self).filter(predicate).sorted(byKeyPath: "date", ascending: false)
        
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
