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
    
    var account = ""
    var accountUser = ""
    var accountUserID = ""
    var accountPassword = ""
    var accountUrl = ""
    var homeServerUrl = ""
    var directoryUser = ""
    
    // Directory
    var groupURL: URL?
    var fileProviderStorageURL: URL?
        
    func setupActiveAccount() -> Bool {
        
        groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.sharedInstance.capabilitiesGroups)
        fileProviderStorageURL = groupURL!.appendingPathComponent(k_assetLocalIdentifierFileProviderStorage)
        
        // Create dir File Provider Storage
        do {
            try FileManager.default.createDirectory(atPath: fileProviderStorageURL!.path, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            NSLog("Unable to create directory \(error.debugDescription)")
        }
        
        guard let activeAccount = NCManageDatabase.sharedInstance.getAccountActive() else {
            return false
        }
        
        account = activeAccount.account
        accountUser = activeAccount.user
        accountUserID = activeAccount.userID
        accountPassword = activeAccount.password
        accountUrl = activeAccount.url
        homeServerUrl = CCUtility.getHomeServerUrlActiveUrl(activeAccount.url)
        directoryUser = CCUtility.getDirectoryActiveUser(activeAccount.user, activeUrl: activeAccount.url)
                
        return true
    }
    
    func getTableMetadataFromItemIdentifier(_ itemIdentifier: NSFileProviderItemIdentifier) -> tableMetadata? {
        
        let fileID = itemIdentifier.rawValue
        return NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileID = %@", account, fileID))
    }

    func getItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier {
        
        return NSFileProviderItemIdentifier(metadata.fileID)
    }
    
    func createFileIdentifierOnFileSystem(metadata: tableMetadata) {
        
        let itemIdentifier = getItemIdentifier(metadata: metadata)
        let identifierPath = fileProviderStorageURL!.path + "/" + itemIdentifier.rawValue
        let fileIdentifier = identifierPath + "/" + metadata.fileName
        
        do {
            try FileManager.default.createDirectory(atPath: identifierPath, withIntermediateDirectories: true, attributes: nil)
        } catch { }
        
        // If do not exists create file with size = 0
        if FileManager.default.fileExists(atPath: fileIdentifier) == false {
            FileManager.default.createFile(atPath: fileIdentifier, contents: nil, attributes: nil)
        }
    }
    
    func getParentItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier? {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else { return NSFileProviderItemIdentifier("") }
        
        if let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account = %@ AND directoryID = %@", account, metadata.directoryID))  {
            if directory.serverUrl == homeServerUrl {
                return NSFileProviderItemIdentifier(NSFileProviderItemIdentifier.rootContainer.rawValue)
            } else {
                // get the metadata.FileID of parent Directory
                if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileID = %@", account, directory.fileID))  {
                    let identifier = getItemIdentifier(metadata: metadata)
                    return identifier
                }
            }
        }
        
        return nil
    }
    
    func getTableDirectoryFromParentItemIdentifier(_ parentItemIdentifier: NSFileProviderItemIdentifier) -> tableDirectory? {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else { return nil }
        
        var predicate: NSPredicate
        
        if parentItemIdentifier == .rootContainer {
            
            predicate = NSPredicate(format: "account = %@ AND serverUrl = %@", account, homeServerUrl)
            
        } else {
            
            guard let metadata = getTableMetadataFromItemIdentifier(parentItemIdentifier) else {
                return nil
            }
            predicate = NSPredicate(format: "account = %@ AND fileID = %@", account, metadata.fileID)
        }
        
        guard let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: predicate) else {
            return nil
        }
        
        return directory
    }
}
