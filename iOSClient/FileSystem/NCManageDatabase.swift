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
}
