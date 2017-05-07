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
                let records = realm.objects(DBActivity.self).filter("idActivity = \(activity.idActivity)")
                if (records.count > 0) {
                    continue
                }
                
                // Add new Activity
                let dbActivity = DBActivity()
                
                dbActivity.account = account
                dbActivity.date = activity.date
                dbActivity.idActivity = Double(activity.idActivity)
                dbActivity.link = activity.link
                dbActivity.note = activity.subject
                dbActivity.type = k_activityTypeInfo

                realm.add(dbActivity)
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
            let dbActivity = DBActivity()

            if (account != nil) {
                dbActivity.account = account!
            }
            
            dbActivity.action = action
            dbActivity.file = file
            dbActivity.fileID = fileID
            dbActivity.note = noteReplacing
            dbActivity.selector = selector
            dbActivity.type = type
            dbActivity.verbose = verbose

            realm.add(dbActivity)
        }
    }
    
    func getAllTableActivityWithPredicate(_ predicate : NSPredicate) -> [DBActivity] {
        
        let realm = try! Realm()

        let results = realm.objects(DBActivity.self).filter(predicate).sorted(byKeyPath: "date", ascending: false)
        
        return Array(results)
    }
    
    //MARK: -
}
