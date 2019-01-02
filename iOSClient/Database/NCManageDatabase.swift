//
//  NCManageDatabase.swift
//  Nextcloud iOS
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

class NCManageDatabase: NSObject {
        
    @objc static let sharedInstance: NCManageDatabase = {
        let instance = NCManageDatabase()
        return instance
    }()
    
    override init() {
        
        let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.sharedInstance.capabilitiesGroups)
        
        let configCompact = Realm.Configuration(
            
            fileURL: dirGroup?.appendingPathComponent("\(k_appDatabaseNextcloud)/\(k_databaseDefault)"),
            
            shouldCompactOnLaunch: { totalBytes, usedBytes in
            // totalBytes refers to the size of the file on disk in bytes (data + free space)
            // usedBytes refers to the number of bytes used by data in the file
            
            // Compact if the file is over 100MB in size and less than 50% 'used'
            let oneHundredMB = 100 * 1024 * 1024
            return (totalBytes > oneHundredMB) && (Double(usedBytes) / Double(totalBytes)) < 0.5
        })
        
        do {
            // Realm is compacted on the first open if the configuration block conditions were met.
            _ = try Realm(configuration: configCompact)
        } catch {
            // handle error compacting or opening Realm
        }
        
        let config = Realm.Configuration(
        
            fileURL: dirGroup?.appendingPathComponent("\(k_appDatabaseNextcloud)/\(k_databaseDefault)"),
            schemaVersion: 37,
            
            // 10 : Version 2.18.0
            // 11 : Version 2.18.2
            // 12 : Version 2.19.0.5
            // 13 : Version 2.19.0.14
            // 14 : Version 2.19.0.xx
            // 15 : Version 2.19.2
            // 16 : Version 2.20.2
            // 17 : Version 2.20.4
            // 18 : Version 2.20.6
            // 19 : Version 2.20.7
            // 20 : Version 2.21.0
            // 21 : Version 2.21.0.3
            // 22 : Version 2.21.0.9
            // 23 : Version 2.21.0.15
            // 24 : Version 2.21.2.5
            // 25 : Version 2.21.3.1
            // 26 : Version 2.22.0.4
            // 27 : Version 2.22.0.7
            // 28 : Version 2.22.3.5
            // 29 : Version 2.22.5.2
            // 30 : Version 2.22.6.0
            // 31 : Version 2.22.6.3
            // 32 : Version 2.22.6.10
            // 33 : Version 2.22.7.1
            // 34 : Version 2.22.8.14
            // 35 : Version 2.22.8.14
            // 36 : Version 2.22.8.14
            // 37 : Version 2.22.8.14

            migrationBlock: { migration, oldSchemaVersion in
                // We haven’t migrated anything yet, so oldSchemaVersion == 0
                /*
                if (oldSchemaVersion < 37) {
                    migration.enumerateObjects(ofType: tableMetadata.className()) { oldObject, newObject in
                        let account = oldObject!["account"] as! String
                        let serverUrl = oldObject!["serverUrl"] as! String
                        let fileName = oldObject!["fileName"] as! String
                        newObject!["metadataID"] = CCUtility.createMetadataID(fromAccount: account, serverUrl: serverUrl, fileName: fileName)
                    }
                    
                    migration.enumerateObjects(ofType: tablePhotos.className()) { oldObject, newObject in
                        let account = oldObject!["account"] as! String
                        let serverUrl = oldObject!["serverUrl"] as! String
                        let fileName = oldObject!["fileName"] as! String
                        newObject!["metadataID"] = CCUtility.createMetadataID(fromAccount: account, serverUrl: serverUrl, fileName: fileName)
                    }
                }
                */
        })

        Realm.Configuration.defaultConfiguration = config
        _ = try! Realm()
    }
    
    //MARK: -
    //MARK: Utility Database

    @objc func clearTable(_ table : Object.Type, account: String?) {
        
        let results : Results<Object>
        
        let realm = try! Realm()

        realm.beginWrite()
        
        if let account = account {
            results = realm.objects(table).filter("account = %@", account)
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
    
    @objc func getThreadConfined(_ table: Object) -> Any {
     
        // id tradeReference = [[NCManageDatabase sharedInstance] getThreadConfined:metadata];
        return ThreadSafeReference(to: table)
    }
    
    @objc func putThreadConfined(_ tableRef: Any) -> Object? {
        
        //tableMetadata *metadataThread = (tableMetadata *)[[NCManageDatabase sharedInstance] putThreadConfined:tradeReference];
        let realm = try! Realm()
        
        return realm.resolve(tableRef as! ThreadSafeReference<Object>)
    }
    
    @objc func isTableInvalidated(_ table: Object) -> Bool {
     
        return table.isInvalidated
    }
    
    //MARK: -
    //MARK: Table Account
    
    @objc func addAccount(_ account: String, url: String, user: String, password: String, loginFlow: Bool) {

        let realm = try! Realm()

        realm.beginWrite()
            
        let addObject = tableAccount()
            
        addObject.account = account
        addObject.loginFlow = loginFlow
            
        // Brand
        if NCBrandOptions.sharedInstance.use_default_auto_upload {
                
            addObject.autoUpload = true
            addObject.autoUploadImage = true
            addObject.autoUploadVideo = true

            addObject.autoUploadWWAnVideo = true
        }
            
        addObject.password = password
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
    
    @objc func setAccountPassword(_ account: String, password: String) -> tableAccount? {
        
        let realm = try! Realm()

        realm.beginWrite()

        guard let result = realm.objects(tableAccount.self).filter("account = %@", account).first else {
            realm.cancelWrite()
            return nil
        }
        
        result.password = password
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return nil
        }
        
        return result
    }
    
    @objc func deleteAccount(_ account: String) {
        
        let realm = try! Realm()

        realm.beginWrite()

        guard let result = realm.objects(tableAccount.self).filter("account = %@", account).first else {
            realm.cancelWrite()
            return
        }
        
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
        
        guard let result = realm.objects(tableAccount.self).filter("active = true").first else {
            return nil
        }
        
        return result
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
    
    @objc func getAccountAutoUploadFileName() -> String {
        
        let realm = try! Realm()
        realm.refresh()
        
        guard let result = realm.objects(tableAccount.self).filter("active = true").first else {
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
        
        guard let result = realm.objects(tableAccount.self).filter("active = true").first else {
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
        
        return activeAccount
    }

    @objc func setAccountAutoUploadProperty(_ property: String, state: Bool) {
        
        let realm = try! Realm()

        realm.beginWrite()

        guard let result = realm.objects(tableAccount.self).filter("active = true").first else {
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
                
                if let result = realm.objects(tableAccount.self).filter("active = true").first {
                    
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
                
                if let result = realm.objects(tableAccount.self).filter("active = true").first {
                    
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
    
    @objc func setAccountUserProfile(_ userProfile: OCUserProfile) -> tableAccount? {
     
        guard let activeAccount = self.getAccountActive() else {
            return nil
        }
        
        let realm = try! Realm()

        do {
            try realm.write {
                
                guard let result = realm.objects(tableAccount.self).filter("account = %@", activeAccount.account).first else {
                    return
                }
                
                // Update userID
                if userProfile.id.count == 0 { // for old config.
                    result.userID = result.user
                } else {
                    result.userID = userProfile.id
                }
                
                result.enabled = userProfile.enabled
                result.address = userProfile.address
                result.displayName = userProfile.displayName
                result.email = userProfile.email
                result.phone = userProfile.phone
                result.twitter = userProfile.twitter
                result.webpage = userProfile.webpage
                
                result.quota = userProfile.quota
                result.quotaFree = userProfile.quotaFree
                result.quotaRelative = userProfile.quotaRelative
                result.quotaTotal = userProfile.quotaTotal
                result.quotaUsed = userProfile.quotaUsed
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
        
        return activeAccount
    }
    
    @objc func setAccountDateSearchContentTypeImageVideo(_ date: Date) {
        
        guard let activeAccount = self.getAccountActive() else {
            return
        }
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                
                guard let result = realm.objects(tableAccount.self).filter("account = %@", activeAccount.account).first else {
                    return
                }
                
                result.dateSearchContentTypeImageVideo = date
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func getAccountStartDirectoryMediaTabView(_ homeServerUrl: String) -> String {
        
        guard let activeAccount = self.getAccountActive() else {
            return ""
        }
        
        let realm = try! Realm()
        realm.refresh()

        guard let result = realm.objects(tableAccount.self).filter("account = %@", activeAccount.account).first else {
            return ""
        }
        
        if result.startDirectoryPhotosTab == "" {
            
            self.setAccountStartDirectoryMediaTabView(homeServerUrl)
            return homeServerUrl
            
        } else {
            return result.startDirectoryPhotosTab
        }
    }
    
    @objc func setAccountStartDirectoryMediaTabView(_ directory: String) {
        
        guard let activeAccount = self.getAccountActive() else {
            return
        }
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                
                guard let result = realm.objects(tableAccount.self).filter("account = %@", activeAccount.account).first else {
                    return
                }
                
                result.startDirectoryPhotosTab = directory
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    //MARK: -
    //MARK: Table Activity

    @objc func getActivity(predicate: NSPredicate) -> [tableActivity] {
        
        let realm = try! Realm()
        realm.refresh()
        
        let results = realm.objects(tableActivity.self).filter(predicate).sorted(byKeyPath: "date", ascending: false)
        
        return Array(results.map { tableActivity.init(value:$0) })
    }

    @objc func addActivityServer(_ listOfActivity: [OCActivity], account: String) {
    
        let realm = try! Realm()

        do {
            try realm.write {
            
                for activity in listOfActivity {
                    
                    if realm.objects(tableActivity.self).filter("idActivity = %d", activity.idActivity).first == nil {
                        
                        // Add new Activity
                        let addObject = tableActivity()
                
                        addObject.account = account
                
                        if let date = activity.date {
                            addObject.date = date as NSDate
                        }
                        
                        addObject.idActivity = Double(activity.idActivity)
                        addObject.link = activity.link
                        addObject.note = activity.subject
                        addObject.type = k_activityTypeInfo

                        realm.add(addObject)
                    }
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func addActivityClient(_ file: String, fileID: String, action: String, selector: String, note: String, type: String, verbose: Bool, activeUrl: String?) {

        guard let tableAccount = self.getAccountActive() else {
            return
        }
        
        var noteReplacing : String = ""
        
        if let activeUrl = activeUrl {
            noteReplacing = note.replacingOccurrences(of: "\(activeUrl)\(k_webDAV)", with: "")
        }
        
        noteReplacing = note.replacingOccurrences(of: "\(k_domain_session_queue).", with: "")

        let realm = try! Realm()

        if realm.isInWriteTransaction {
        
            print("[LOG] Could not write to database, addActivityClient is already in write transaction")
            
        } else {
            
            do {
                try realm.write {
                
                    // Add new Activity
                    let addObject = tableActivity()
                
                    addObject.account = tableAccount.account
                    addObject.action = action
                    addObject.file = file
                    addObject.fileID = fileID
                    addObject.note = noteReplacing
                    addObject.selector = selector
                    addObject.type = type
                    addObject.verbose = verbose
                
                    realm.add(addObject)
                }
            } catch let error {
                print("[LOG] Could not write to database: ", error)
            }
        }
        
        print("[LOG] " + note)
    }
    
    //MARK: -
    //MARK: Table Capabilities
    
    @objc func addCapabilities(_ capabilities: OCCapabilities, account: String) {
        
        let realm = try! Realm()

        do {
            try realm.write {
            
                let result = realm.objects(tableCapabilities.self).filter("account = %@", account).first

                var resultCapabilities = tableCapabilities()
            
                if let result = result {
                    resultCapabilities = result
                }
                
                resultCapabilities.account = account
                resultCapabilities.themingBackground = capabilities.themingBackground
                resultCapabilities.themingBackgroundDefault = capabilities.themingBackgroundDefault
                resultCapabilities.themingBackgroundPlain = capabilities.themingBackgroundPlain
                resultCapabilities.themingColor = capabilities.themingColor
                resultCapabilities.themingColorElement = capabilities.themingColorElement
                resultCapabilities.themingColorText = capabilities.themingColorText
                resultCapabilities.themingLogo = capabilities.themingLogo
                resultCapabilities.themingName = capabilities.themingName
                resultCapabilities.themingSlogan = capabilities.themingSlogan
                resultCapabilities.themingUrl = capabilities.themingUrl
                resultCapabilities.versionMajor = capabilities.versionMajor
                resultCapabilities.versionMinor = capabilities.versionMinor
                resultCapabilities.versionMicro = capabilities.versionMicro
                resultCapabilities.versionString = capabilities.versionString
                resultCapabilities.endToEndEncryption = capabilities.isEndToEndEncryptionEnabled
                resultCapabilities.endToEndEncryptionVersion = capabilities.endToEndEncryptionVersion
                resultCapabilities.richdocumentsMimetypes.removeAll()
                for mimeType in capabilities.richdocumentsMimetypes {
                    resultCapabilities.richdocumentsMimetypes.append(mimeType as! String)
                }
                resultCapabilities.richdocumentsDirectEditing = capabilities.richdocumentsDirectEditing
                
                if result == nil {
                    realm.add(resultCapabilities)
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func getCapabilites(account: String) -> tableCapabilities? {
        
        let realm = try! Realm()
        realm.refresh()
        
        return realm.objects(tableCapabilities.self).filter("account = %@", account).first
    }
    
    @objc func getServerVersion(account: String) -> Int {

        let realm = try! Realm()
        realm.refresh()
        
        guard let result = realm.objects(tableCapabilities.self).filter("account = %@", account).first else {
            return 0
        }

        return result.versionMajor
    }

    @objc func getEndToEndEncryptionVersion(account: String) -> Float {
        
        let realm = try! Realm()
        realm.refresh()
        
        guard let result = realm.objects(tableCapabilities.self).filter("account = %@", account).first else {
            return 0
        }
        
        return Float(result.endToEndEncryptionVersion)!
    }
    
    @objc func compareServerVersion(_ versionCompare: String, account: String) -> Int {
        
        let realm = try! Realm()

        guard let capabilities = realm.objects(tableCapabilities.self).filter("account = %@", account).first else {
            return -1
        }
        
        let versionServer = capabilities.versionString
        
        var v1 = versionServer.split(separator:".").map { Int(String($0)) }
        var v2 = versionCompare.split(separator:".").map { Int(String($0)) }
        
        var result = 0
        for i in 0..<max(v1.count,v2.count) {
            let left = i >= v1.count ? 0 : v1[i]
            let right = i >= v2.count ? 0 : v2[i]
            
            if (left == right) {
                result = 0
            } else if left! > right! {
                return 1
            } else if right! > left! {
                return -1
            }
        }
        return result
    }
    
    @objc func getRichdocumentsMimetypes(account: String) -> [String]? {
        
        let realm = try! Realm()
        realm.refresh()
        
        guard let result = realm.objects(tableCapabilities.self).filter("account = %@", account).first else {
            return nil
        }
        
        return Array(result.richdocumentsMimetypes)
    }
    
    //MARK: -
    //MARK: Table Certificates
    
    @objc func addCertificates(_ certificateLocation: String) {
    
        let realm = try! Realm()

        do {
            try realm.write {

                let addObject = tableCertificates()
            
                addObject.certificateLocation = certificateLocation
            
                realm.add(addObject)
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func getCertificatesLocation(_ localCertificatesFolder: String) -> [String] {
        
        let realm = try! Realm()
        realm.refresh()
        
        let results = realm.objects(tableCertificates.self)
    
        return Array(results.map { "\(localCertificatesFolder)/\($0.certificateLocation)" })
    }
    
    //MARK: -
    //MARK: Table Directory
    
    @objc func addDirectory(encrypted: Bool, favorite: Bool, fileID: String?, etag: String?, permissions: String?, serverUrl: String, account: String) -> tableDirectory? {
        
        let realm = try! Realm()
        realm.beginWrite()
        
        var addObject = tableDirectory()
        
        let result = realm.objects(tableDirectory.self).filter("account = %@ AND serverUrl = %@", account, serverUrl).first
        if result != nil {
            addObject = result!
        } else {
            addObject.directoryID = CCUtility.createDirectoyID(fromAccount: account, serverUrl: serverUrl)
        }
        
        addObject.account = account
        addObject.e2eEncrypted = encrypted
        addObject.favorite = favorite
        if let etag = etag {
            addObject.etag = etag
        }
        if let fileID = fileID {
            addObject.fileID = fileID
        }
        if let permissions = permissions {
            addObject.permissions = permissions
        }
        addObject.serverUrl = serverUrl
        
        realm.add(addObject, update: true)
        
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
        
        let results = realm.objects(tableDirectory.self).filter("account = %@ AND serverUrl BEGINSWITH %@", account, serverUrl)
        
        // Delete table Metadata & LocalFile
        for result in results {
            
            self.deleteMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", result.account, result.serverUrl))
            self.deleteLocalFile(predicate: NSPredicate(format: "fileID == %@", result.fileID))
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
    
    @objc func setDirectory(serverUrl: String, serverUrlTo: String?, etag: String?, fileID: String?, encrypted: Bool, account: String) {
        
        let realm = try! Realm()

        do {
            try realm.write {
            
                guard let result = realm.objects(tableDirectory.self).filter("account = %@ AND serverUrl = %@", account, serverUrl).first else {
                    return
                }
                
                let directory = tableDirectory.init(value: result)
                
                realm.delete(result)
                
                directory.e2eEncrypted = encrypted
                if let etag = etag {
                    directory.etag = etag
                }
                if let fileID = fileID {
                    directory.fileID = fileID
                }
                if let serverUrlTo = serverUrlTo {
                    directory.serverUrl = serverUrlTo
                }
                directory.directoryID = CCUtility.createDirectoyID(fromAccount: account, serverUrl: directory.serverUrl)
                
                realm.add(directory, update: true)
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
                realm.add(result, update: true)
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
    
    @objc func setDirectoryLock(serverUrl: String, lock: Bool, account: String) -> Bool {
        
        let realm = try! Realm()

        var update = false
        
        do {
            try realm.write {
            
                guard let result = realm.objects(tableDirectory.self).filter("account = %@ AND serverUrl = %@", account, serverUrl).first else {
                    realm.cancelWrite()
                    return
                }
                
                result.lock = lock
                update = true
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return false
        }
        
        return update
    }
    
    @objc func setAllDirectoryUnLock(account: String) {
        
        let realm = try! Realm()

        do {
            try realm.write {
            
                let results = realm.objects(tableDirectory.self).filter("account = %@", account)

                for result in results {
                    result.lock = false;
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
                
                guard let result = realm.objects(tableDirectory.self).filter("account = %@ AND serverUrl = %@", account, serverUrl).first else {
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
    //MARK: Table e2e Encryption
    
    @objc func addE2eEncryption(_ e2e: tableE2eEncryption) -> Bool {

        guard self.getAccountActive() != nil else {
            return false
        }
        
        let realm = try! Realm()

        do {
            try realm.write {
                realm.add(e2e, update: true)
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

        guard let result = realm.objects(tableE2eEncryption.self).filter("account = %@ AND serverUrl = %@ AND fileNameIdentifier = %@", tableAccount.account, serverUrl, fileNameIdentifier).first else {
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
            
        guard let result = realm.objects(tableE2eEncryptionLock.self).filter("account = %@ AND serverUrl = %@", tableAccount.account, serverUrl).first else {
            return nil
        }
        
        return tableE2eEncryptionLock.init(value: result)
    }
    
    @objc func setE2ETokenLock(serverUrl: String, fileID: String, token: String) {
        
        guard let tableAccount = self.getAccountActive() else {
            return
        }
            
        let realm = try! Realm()

        realm.beginWrite()
        
        let addObject = tableE2eEncryptionLock()
                
        addObject.account = tableAccount.account
        addObject.fileID = fileID
        addObject.serverUrl = serverUrl
        addObject.token = token
                
        realm.add(addObject, update: true)
        
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

        guard let result = realm.objects(tableE2eEncryptionLock.self).filter("account = %@ AND serverUrl = %@", tableAccount.account, serverUrl).first else {
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

    @objc func deleteExternalSites(account: String) {
        
        let realm = try! Realm()

        do {
            try realm.write {
            
                let results = realm.objects(tableExternalSites.self).filter("account = %@", account)

                realm.delete(results)
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func getAllExternalSites(account: String) -> [tableExternalSites]? {
        
        let realm = try! Realm()
        realm.refresh()
        
        let results = realm.objects(tableExternalSites.self).filter("account = %@", account).sorted(byKeyPath: "idExternalSite", ascending: true)
        
        return Array(results)
    }

    //MARK: -
    //MARK: Table GPS
    
    @objc func addGeocoderLocation(_ location: String, placemarkAdministrativeArea: String, placemarkCountry: String, placemarkLocality: String, placemarkPostalCode: String, placemarkThoroughfare: String, latitude: String, longitude: String) {

        let realm = try! Realm()

        realm.beginWrite()

        // Verify if exists
        guard realm.objects(tableGPS.self).filter("latitude = %@ AND longitude = %@", latitude, longitude).first == nil else {
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
        
        guard let result = realm.objects(tableGPS.self).filter("latitude = %@ AND longitude = %@", latitude, longitude).first else {
            return nil
        }
        
        return result.location
    }

    //MARK: -
    //MARK: Table LocalFile
    
    @objc func addLocalFile(metadata: tableMetadata) {
        
        let realm = try! Realm()

        do {
            try realm.write {
            
                let addObject = tableLocalFile()
            
                addObject.account = metadata.account
                addObject.date = metadata.date
                addObject.etag = metadata.etag
                addObject.exifDate = NSDate()
                addObject.exifLatitude = "-1"
                addObject.exifLongitude = "-1"
                addObject.fileID = metadata.fileID
                addObject.fileName = metadata.fileName
                addObject.size = metadata.size
            
                realm.add(addObject, update: true)
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
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
    
    @objc func setLocalFile(fileID: String, date: NSDate?, exifDate: NSDate?, exifLatitude: String?, exifLongitude: String?, fileName: String?, etag: String?) {
        
        let realm = try! Realm()

        do {
            try realm.write {
                
                guard let result = realm.objects(tableLocalFile.self).filter("fileID = %@", fileID).first else {
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
    
    @objc func setLocalFile(fileID: String, offline: Bool) {
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                
                guard let result = realm.objects(tableLocalFile.self).filter("fileID = %@", fileID).first else {
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
    
    @objc func addMetadata(_ metadata: tableMetadata) -> tableMetadata? {
            
        if metadata.isInvalidated {
            return nil
        }
        
        let serverUrl = metadata.serverUrl
        let account = metadata.account
        
        let realm = try! Realm()

        do {
            try realm.write {
                realm.add(metadata, update: true)
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return nil
        }
        
        self.setDateReadDirectory(serverUrl: serverUrl, account: account)
        
        if metadata.isInvalidated {
            return nil
        }
        
        return tableMetadata.init(value: metadata)
    }
    
    @objc func addMetadatas(_ metadatas: [tableMetadata]) -> [tableMetadata]? {
        
        var directoryToClearDate = [String:String]()

        let realm = try! Realm()

        do {
            try realm.write {
                for metadata in metadatas {
                    directoryToClearDate[metadata.serverUrl] = metadata.account
                    realm.add(metadata, update: true)
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
    
    @objc func moveMetadata(fileID: String, serverUrlTo: String) {
        
        let realm = try! Realm()

        do {
            try realm.write {
            
                let results = realm.objects(tableMetadata.self).filter("fileID == %@", fileID)
        
                for result in results {
                    result.serverUrl = serverUrlTo
                    result.metadataID = CCUtility.createMetadataID(fromAccount: result.account, serverUrl: serverUrlTo, fileNameView: result.fileNameView, directory: result.directory)
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return
        }        
    }
    
    @objc func addMetadataServerUrl(fileID: String, serverUrl: String) {
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                
                let results = realm.objects(tableMetadata.self).filter("fileID == %@", fileID)
                
                for result in results {
                    result.serverUrl = serverUrl
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return
        }
    }
    
    @objc func renameMetadata(fileNameTo: String, fileID: String) -> tableMetadata? {
        
        var result :tableMetadata?
        let realm = try! Realm()
        
        do {
            try realm.write {
                
                result = realm.objects(tableMetadata.self).filter("fileID == %@", fileID).first
                if result != nil {
                    result!.fileName = fileNameTo
                    result!.fileNameView = fileNameTo
                    result!.metadataID = CCUtility.createMetadataID(fromAccount: result!.account, serverUrl: result!.serverUrl, fileNameView: fileNameTo, directory: result!.directory)
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
                realm.add(metadata, update: true)
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return nil
        }
        
        self.setDateReadDirectory(serverUrl: serverUrl, account: account)
        
        return tableMetadata.init(value: metadata)
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
    
    @objc func setMetadataFavorite(fileID: String, favorite: Bool) {
        
        let realm = try! Realm()

        realm.beginWrite()

        guard let result = realm.objects(tableMetadata.self).filter("fileID == %@", fileID).first else {
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
        
        let results = realm.objects(tableMetadata.self).filter("account = %@ AND directory = true AND favorite = true", account).sorted(byKeyPath: "fileNameView", ascending: true)
        
        for result in results {
            counter += 1
            listIdentifierRank[result.fileID] = NSNumber(value: Int64(counter))
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
    
    @objc func initNewMetadata(_ metadata: tableMetadata) -> tableMetadata {
        return tableMetadata.init(value: metadata)
    }
    
    //MARK: -
    //MARK: Table Photos
    @objc func getTablePhotos(addMetadatasFromUpload: [tableMetadata], account: String) -> [tableMetadata]? {

        let realm = try! Realm()
        realm.refresh()

        let predicate = NSPredicate(format: "account == %@", account)
        let results = realm.objects(tablePhotos.self).filter(predicate).sorted(byKeyPath: "date", ascending: false)

        if (results.count > 0) {
            var returnMetadatas = Array(results.map { tableMetadata.init(value:$0) })
            for metadata in addMetadatasFromUpload {
                let result = realm.objects(tablePhotos.self).filter("fileID == %@", metadata.fileID).first
                if result == nil {
                    returnMetadatas.append(metadata)
                }
            }
            return returnMetadatas
        } else {
            return nil
        }
    }
    
    @objc func getTablePhoto(predicate: NSPredicate) -> tableMetadata? {
        
        let realm = try! Realm()
        realm.refresh()
        
        guard let result = realm.objects(tablePhotos.self).filter(predicate).first else {
            return nil
        }
        
        return tableMetadata.init(value: result)
    }
    
    @objc func createTablePhotos(_ metadatas: [tableMetadata], account: String) {

        let realm = try! Realm()
        realm.refresh()
        
        do {
            try realm.write {
                // DELETE ALL
                let results = realm.objects(tablePhotos.self).filter("account = %@", account)
                realm.delete(results)
                // INSERT ALL
                let photos = Array(metadatas.map { tablePhotos.init(value:$0) })
                realm.add(photos, update: true)
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            realm.cancelWrite()
        }
    }
    
    @objc func deletePhotos(fileID: String) {
        
        let realm = try! Realm()
        
        realm.beginWrite()
        
        let results = realm.objects(tablePhotos.self).filter("fileID = %@", fileID)
        
        realm.delete(results)
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return
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

                        realm.add(addObject, update: true)
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
         
            predicate = NSPredicate(format: "account == %@ AND (mediaType == %i OR mediaType == %i)", account, PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
            
        } else if (image) {
            
            predicate = NSPredicate(format: "account == %@ AND mediaType == %i", account, PHAssetMediaType.image.rawValue)

        } else if (video) {
            
            predicate = NSPredicate(format: "account == %@ AND mediaType == %i", account, PHAssetMediaType.video.rawValue)
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
    
    @objc func addShareLink(_ share: String, fileName: String, serverUrl: String, account: String) -> [String:String]? {
        
        let realm = try! Realm()

        realm.beginWrite()

        // Verify if exists
        let result = realm.objects(tableShare.self).filter("account = %@ AND fileName = %@ AND serverUrl = %@", account, fileName, serverUrl).first
        
        if result != nil {
            
            result?.shareLink = share
            
        } else {
        
            // Add new
            let addObject = tableShare()
            
            addObject.account = account
            addObject.fileName = fileName
            addObject.serverUrl = serverUrl
            addObject.shareLink = share
            
            realm.add(addObject)
        }
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return nil
        }

        return ["\(serverUrl)\(fileName)" : share]
    }

    @objc func addShareUserAndGroup(_ share: String, fileName: String, serverUrl: String, account: String) -> [String:String]? {
        
        let realm = try! Realm()

        realm.beginWrite()

        // Verify if exists
        let result = realm.objects(tableShare.self).filter("account = %@ AND fileName = %@ AND serverUrl = %@", account, fileName, serverUrl).first
        
        if result != nil {
            
            result?.shareUserAndGroup = share
            
        } else {
            
            // Add new
            let addObject = tableShare()
                
            addObject.account = account
            addObject.fileName = fileName
            addObject.serverUrl = serverUrl
            addObject.shareUserAndGroup = share
                
            realm.add(addObject)
        }
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return nil
        }
        
        return ["\(serverUrl)\(fileName)" : share]
    }
    
    @objc func unShare(_ share: String, fileName: String, serverUrl: String, sharesLink: [String:String], sharesUserAndGroup: [String:String], account: String) -> [Any]? {
        
        var sharesLink = sharesLink
        var sharesUserAndGroup = sharesUserAndGroup
        
        let realm = try! Realm()

        realm.beginWrite()

        let results = realm.objects(tableShare.self).filter("account = %@ AND (shareLink CONTAINS %@ OR shareUserAndGroup CONTAINS %@)", account, share, share)
        
        if (results.count > 0) {
            
            let result = results[0]
            
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
            
            if (result.shareLink.count > 0) {
                sharesLink.updateValue(result.shareLink, forKey:"\(serverUrl)\(fileName)")
            } else {
                sharesLink.removeValue(forKey: "\(serverUrl)\(fileName)")
            }
            
            if (result.shareUserAndGroup.count > 0) {
                sharesUserAndGroup.updateValue(result.shareUserAndGroup, forKey:"\(serverUrl)\(fileName)")
            } else {
                sharesUserAndGroup.removeValue(forKey: "\(serverUrl)\(fileName)")
            }
            
            if (result.shareLink.count == 0 && result.shareUserAndGroup.count == 0) {
                realm.delete(result)
            }
        }
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return nil
        }

        return [sharesLink, sharesUserAndGroup]
    }
    
    @objc func removeShareActiveAccount(account: String) {
        
        let realm = try! Realm()

        do {
            try realm.write {
            
                let results = realm.objects(tableShare.self).filter("account = %@", account)

                realm.delete(results)
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func updateShare(_ items: [String:OCSharedDto], activeUrl: String, account: String) -> [Any]? {
        
        var sharesLink = [String:String]()
        var sharesUserAndGroup = [String:String]()

        self.removeShareActiveAccount(account: account)
     
        var itemsLink = [OCSharedDto]()
        var itemsUsersAndGroups = [OCSharedDto]()
        
        for (_, itemOCSharedDto) in items {
            
            if (itemOCSharedDto.shareType == Int(shareTypeLink.rawValue)) {
                itemsLink.append(itemOCSharedDto)
            }
            
            if (itemOCSharedDto.shareWith.count > 0 && (itemOCSharedDto.shareType == Int(shareTypeUser.rawValue) || itemOCSharedDto.shareType == Int(shareTypeGroup.rawValue) || itemOCSharedDto.shareType == Int(shareTypeRemote.rawValue)  )) {
                itemsUsersAndGroups.append(itemOCSharedDto)
            }
        }
        
        // Manage sharesLink

        for itemOCSharedDto in itemsLink {
            
            let fullPath = CCUtility.getHomeServerUrlActiveUrl(activeUrl) + "\(itemOCSharedDto.path!)"
            let fileName = NSString(string: fullPath).lastPathComponent
            var serverUrl = NSString(string: fullPath).substring(to: (fullPath.count - fileName.count - 1))
            
            if serverUrl.hasSuffix("/") {
                serverUrl = NSString(string: serverUrl).substring(to: (serverUrl.count - 1))
            }
            
            if itemOCSharedDto.idRemoteShared > 0 {
                let sharesLinkReturn = self.addShareLink("\(itemOCSharedDto.idRemoteShared)", fileName: fileName, serverUrl: serverUrl, account: account)
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
            var serverUrl = NSString(string: fullPath).substring(to: (fullPath.count - fileName.count - 1))
            
            if serverUrl.hasSuffix("/") {
                serverUrl = NSString(string: serverUrl).substring(to: (serverUrl.count - 1))
            }
            
            let sharesUserAndGroupReturn = self.addShareUserAndGroup(idsRemoteShared, fileName: fileName, serverUrl: serverUrl, account: account)
            if sharesUserAndGroupReturn != nil {
                for (key,value) in sharesUserAndGroupReturn! {
                    sharesUserAndGroup.updateValue(value, forKey:key)
                }
            }
        }
        
        return [sharesLink, sharesUserAndGroup]
    }
    
    @objc func getShares(account: String) -> [Any]? {

        var sharesLink = [String:String]()
        var sharesUserAndGroup = [String:String]()
        
        let realm = try! Realm()

        let results = realm.objects(tableShare.self).filter("account = %@", account)
        
        for resultShare in results {
            
            if (resultShare.shareLink.count > 0) {
                sharesLink = [resultShare.shareLink: "\(resultShare.serverUrl)\(resultShare.fileName)"]
            }
            
            if (resultShare.shareUserAndGroup.count > 0) {
                sharesUserAndGroup = [resultShare.shareUserAndGroup: "\(resultShare.serverUrl)\(resultShare.fileName)"]
            }
        }
        
        return [sharesLink, sharesUserAndGroup]
    }
    
    @objc func getTableShares(account: String) -> [tableShare]? {
        
        let realm = try! Realm()
        realm.refresh()
        
        let results = realm.objects(tableShare.self).filter("account = %@", account).sorted(byKeyPath: "fileName", ascending: true)
        
        return Array(results)
    }

    //MARK: -
    //MARK: Table Tag
    
    @objc func addTag(_ fileID: String ,tagIOS: Data?, account: String) {
        
        let realm = try! Realm()
        
        do {
            try realm.write {
                
                // Add new
                let addObject = tableTag()
                    
                addObject.account = account
                addObject.fileID = fileID
                addObject.tagIOS = tagIOS
    
                realm.add(addObject, update: true)
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func deleteTag(_ fileID: String) {
        
        let realm = try! Realm()
        
        realm.beginWrite()
        
        guard let result = realm.objects(tableTag.self).filter("fileID == %@", fileID).first else {
            realm.cancelWrite()
            return
        }
        
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
                    realm.add(trash, update: true)
                }
            }
        } catch let error {
            print("[LOG] Could not write to database: ", error)
            return
        }
    }
    
    @objc func deleteTrash(filePath: String, account: String) {
        
        let realm = try! Realm()
        
        realm.beginWrite()
        
        let results = realm.objects(tableTrash.self).filter("account = %@ AND filePath = %@", account, filePath)
        realm.delete(results)
        
        do {
            try realm.commitWrite()
        } catch let error {
            print("[LOG] Could not write to database: ", error)
        }
    }
    
    @objc func deleteTrash(fileID: String?, account: String) {
        
        let realm = try! Realm()
        var predicate = NSPredicate()
        
        realm.beginWrite()
        
        if fileID == nil {
            
            predicate = NSPredicate(format: "account == %@", account)
            
        } else {
            
            predicate = NSPredicate(format: "account = %@ AND fileID = %@", account, fileID!)
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
        
        let results = realm.objects(tableTrash.self).filter("account = %@ AND filePath = %@", account, filePath).sorted(byKeyPath: sorted, ascending: ascending)

        return Array(results.map { tableTrash.init(value:$0) })
    }
    
    @objc func getTrashItem(fileID: String, account: String) -> tableTrash? {
        
        let realm = try! Realm()
        realm.refresh()
        
        guard let result = realm.objects(tableTrash.self).filter("account = %@ AND fileID = %@", account, fileID).first else {
            return nil
        }
        
        return tableTrash.init(value: result)
    }
    
    //MARK: -
}
