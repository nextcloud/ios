//
//  FileProviderData.swift
//  Files
//
//  Created by Marino Faggiana on 27/05/18.
//  Copyright © 2018 TWS. All rights reserved.
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

import FileProvider

class FileProviderData: NSObject {
    
    var fileManager = FileManager()
    
    var account = ""
    var accountUser = ""
    var accountUserID = ""
    var accountPassword = ""
    var accountUrl = ""
    var homeServerUrl = ""
        
    // Max item for page
    let itemForPage = 20

    // List of etag for serverUrl
    var listServerUrlEtag = [String:String]()
    
    // Anchor
    var currentAnchor: UInt64 = 0

    // Rank favorite
    var listFavoriteIdentifierRank = [String:NSNumber]()
    
    // Queue for trade-safe
    let queueTradeSafe = DispatchQueue(label: "com.nextcloud.fileproviderextension.tradesafe", attributes: .concurrent)

    // Item for signalEnumerator
    var fileProviderSignalDeleteContainerItemIdentifier = [NSFileProviderItemIdentifier:NSFileProviderItemIdentifier]()
    var fileProviderSignalUpdateContainerItem = [NSFileProviderItemIdentifier:FileProviderItem]()
    var fileProviderSignalDeleteWorkingSetItemIdentifier = [NSFileProviderItemIdentifier:NSFileProviderItemIdentifier]()
    var fileProviderSignalUpdateWorkingSetItem = [NSFileProviderItemIdentifier:FileProviderItem]()
    
    // UserDefaults
    var ncUserDefaults = UserDefaults(suiteName: NCBrandOptions.sharedInstance.capabilitiesGroups)
    
    // MARK: - 
    
    func setupActiveAccount() -> Bool {
        
        if CCUtility.getDisableFilesApp() {
            return false
        }
        
        guard let activeAccount = NCManageDatabase.sharedInstance.getAccountActive() else {
            return false
        }
        
        if account == "" {
            queueTradeSafe.sync(flags: .barrier) {
                account = activeAccount.account
                accountUser = activeAccount.user
                accountUserID = activeAccount.userID
                accountPassword = activeAccount.password
                accountUrl = activeAccount.url
                homeServerUrl = CCUtility.getHomeServerUrlActiveUrl(activeAccount.url)
            }
        } else if account != activeAccount.account {
            assert(false, "change user")
        }
        
        CCNetworking.shared().settingAccount()
        
        return true
    }
    
    // MARK: -
    
    func getAccountFromItemIdentifier(_ itemIdentifier: NSFileProviderItemIdentifier) -> String? {
        
        let fileID = itemIdentifier.rawValue
        return NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "fileID == %@", fileID))?.account
    }
    
    func getTableMetadataFromItemIdentifier(_ itemIdentifier: NSFileProviderItemIdentifier) -> tableMetadata? {
        
        let fileID = itemIdentifier.rawValue
        return NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "fileID == %@", fileID))
    }

    func getItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier {
        
        return NSFileProviderItemIdentifier(metadata.fileID)
    }
    
    func createFileIdentifierOnFileSystem(metadata: tableMetadata) {
        
        let itemIdentifier = getItemIdentifier(metadata: metadata)
        
        if metadata.directory {
            CCUtility.getDirectoryProviderStorageFileID(itemIdentifier.rawValue)
        } else {
            CCUtility.getDirectoryProviderStorageFileID(itemIdentifier.rawValue, fileNameView: metadata.fileNameView)
        }
    }
    
    func getParentItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier? {
        
        if let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "directoryID == %@", metadata.directoryID))  {
            if directory.serverUrl == homeServerUrl {
                return NSFileProviderItemIdentifier(NSFileProviderItemIdentifier.rootContainer.rawValue)
            } else {
                // get the metadata.FileID of parent Directory
                if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "fileID == %@", directory.fileID))  {
                    let identifier = getItemIdentifier(metadata: metadata)
                    return identifier
                }
            }
        }
        
        return nil
    }
    
    func getTableDirectoryFromParentItemIdentifier(_ parentItemIdentifier: NSFileProviderItemIdentifier) -> tableDirectory? {
        
        var predicate: NSPredicate
        
        if parentItemIdentifier == .rootContainer {
            
            predicate = NSPredicate(format: "account == %@ AND serverUrl == %@", account, homeServerUrl)
            
        } else {
            
            guard let metadata = getTableMetadataFromItemIdentifier(parentItemIdentifier) else {
                return nil
            }
            predicate = NSPredicate(format: "fileID == %@", metadata.fileID)
        }
        
        guard let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: predicate) else {
            return nil
        }
        
        return directory
    }
    
    // MARK: -
    
    func updateFavoriteForWorkingSet() {
        
        var updateWorkingSet = false
        let oldListFavoriteIdentifierRank = listFavoriteIdentifierRank
        listFavoriteIdentifierRank = NCManageDatabase.sharedInstance.getTableMetadatasDirectoryFavoriteIdentifierRank()
        
        // (ADD)
        for (identifier, _) in listFavoriteIdentifierRank {
            
            if !oldListFavoriteIdentifierRank.keys.contains(identifier) {
                
                guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "fileID == %@", identifier)) else {
                    continue
                }
                guard let parentItemIdentifier = getParentItemIdentifier(metadata: metadata) else {
                    continue
                }
                
                let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier, providerData: self)
                queueTradeSafe.sync(flags: .barrier) {
                    fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
                }
                updateWorkingSet = true
            }
        }
        
        // (REMOVE)
        for (identifier, _) in oldListFavoriteIdentifierRank {
            
            if !listFavoriteIdentifierRank.keys.contains(identifier) {
                
                guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "fileID == %@", identifier)) else {
                    continue
                }
                
                let itemIdentifier = getItemIdentifier(metadata: metadata)
                queueTradeSafe.sync(flags: .barrier) {
                    fileProviderSignalDeleteWorkingSetItemIdentifier[itemIdentifier] = itemIdentifier
                }
                updateWorkingSet = true
            }
        }
        
        if updateWorkingSet {
            signalEnumerator(for: [.workingSet])
        }
    }
    
    // MARK: -

    // Convinent method to signal the enumeration for containers.
    //
    func signalEnumerator(for containerItemIdentifiers: [NSFileProviderItemIdentifier]) {
                
        currentAnchor += 1
        
        for containerItemIdentifier in containerItemIdentifiers {
            
            NSFileProviderManager.default.signalEnumerator(for: containerItemIdentifier) { error in
                if let error = error {
                    print("SignalEnumerator for \(containerItemIdentifier) returned error: \(error)")
                }
            }
        }
    }
    
    // MARK: -
    
    func copyFile(_ atPath: String, toPath: String) -> Error? {
        
        var errorResult: Error?
        
        if !fileManager.fileExists(atPath: atPath) {
            return NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError, userInfo:[:])
        }
        
        do {
            try fileManager.removeItem(atPath: toPath)
        } catch let error {
            print("error: \(error)")
        }
        do {
            try fileManager.copyItem(atPath: atPath, toPath: toPath)
        } catch let error {
            errorResult = error
        }
        
        return errorResult
    }
    
    func moveFile(_ atPath: String, toPath: String) -> Error? {
        
        var errorResult: Error?
        
        if atPath == toPath {
            return nil
        }
                
        if !fileManager.fileExists(atPath: atPath) {
            return NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError, userInfo:[:])
        }
        
        do {
            try fileManager.removeItem(atPath: toPath)
        } catch let error {
            print("error: \(error)")
        }
        do {
            try fileManager.moveItem(atPath: atPath, toPath: toPath)
        } catch let error {
            errorResult = error
        }
        
        return errorResult
    }
    
    func deleteFile(_ atPath: String) -> Error? {
        
        var errorResult: Error?
        
        do {
            try fileManager.removeItem(atPath: atPath)
        } catch let error {
            errorResult = error
        }
        
        return errorResult
    }
    
    func fileExists(atPath: String) -> Bool {
        return fileManager.fileExists(atPath: atPath)
    }
}
