//
//  FileProviderExtension+Actions.swift
//  PickerFileProvider
//
//  Created by Marino Faggiana on 28/05/18.
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

extension FileProviderExtension {

    override func createDirectory(withName directoryName: String, inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else { return }
        
        // Check account
        if providerData.setupActiveAccount() == false {
            completionHandler(nil, NSFileProviderError(.notAuthenticated))
            return
        }
        
        guard let tableDirectory = providerData.getTableDirectoryFromParentItemIdentifier(parentItemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        let serverUrl = tableDirectory.serverUrl
        
        let ocNetworking = OCnetworking.init(delegate: nil, metadataNet: nil, withUser: providerData.accountUser, withUserID: providerData.accountUserID, withPassword: providerData.accountPassword, withUrl: providerData.accountUrl)
        ocNetworking?.createFolder(directoryName, serverUrl: serverUrl, account: providerData.account, success: { (fileID, date) in
            
            let metadata = tableMetadata()
            
            metadata.account = self.providerData.account
            metadata.directory = true
            metadata.directoryID = NCManageDatabase.sharedInstance.getDirectoryID(serverUrl)!
            metadata.fileID = fileID!
            metadata.fileName = directoryName
            metadata.fileNameView = directoryName
            metadata.typeFile = k_metadataTypeFile_directory
            
            // METADATA
            guard let metadataDB = NCManageDatabase.sharedInstance.addMetadata(metadata) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            
            // DIRECTORY
            guard let _ = NCManageDatabase.sharedInstance.addDirectory(encrypted: false, favorite: false, fileID: fileID!, permissions: nil, serverUrl: serverUrl + "/" + directoryName) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            
            let parentItemIdentifier = self.providerData.getParentItemIdentifier(metadata: metadataDB)
            if parentItemIdentifier != nil {
                let item = FileProviderItem(metadata: metadataDB, parentItemIdentifier: parentItemIdentifier!, providerData: self.providerData)
                completionHandler(item, nil)
            } else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
            }
            
        }, failure: { (errorMessage, errorCode) in
            completionHandler(nil, NSFileProviderError(.serverUnreachable))
        })
    }
    
    override func deleteItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (Error?) -> Void) {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else { return }
        
        // Check account
        if providerData.setupActiveAccount() == false {
            completionHandler(NSFileProviderError(.notAuthenticated))
            return
        }
        
        guard let metadata = self.providerData.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }
            
        guard let parentItemIdentifier = self.providerData.getParentItemIdentifier(metadata: metadata) else {
            completionHandler( NSFileProviderError(.noSuchItem))
            return
        }
        
        deleteFile(withIdentifier: itemIdentifier, parentItemIdentifier: parentItemIdentifier, metadata: metadata)

        // return immediately
        fileProviderSignalDeleteItemIdentifier.append(itemIdentifier)
        self.signalEnumerator(for: [parentItemIdentifier, .workingSet])
        
        completionHandler(nil)
    }
    
    override func reparentItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, newName: String?, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else { return }
        
        // Check account
        if providerData.setupActiveAccount() == false {
            completionHandler(nil, NSFileProviderError(.notAuthenticated))
            return
        }
        
        guard let itemFrom = try? item(for: itemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        guard let metadataFrom = providerData.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        let fileIDFrom = metadataFrom.fileID
        
        guard let serverUrlFrom = NCManageDatabase.sharedInstance.getServerUrl(metadataFrom.directoryID) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        let fileNameFrom = serverUrlFrom + "/" + itemFrom.filename
        
        guard let tableDirectoryTo = providerData.getTableDirectoryFromParentItemIdentifier(parentItemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        let serverUrlTo = tableDirectoryTo.serverUrl
        let directoryIDTo = NCManageDatabase.sharedInstance.getDirectoryID(serverUrlTo)!
        let fileNameTo = serverUrlTo + "/" + itemFrom.filename
        
        let ocNetworking = OCnetworking.init(delegate: nil, metadataNet: nil, withUser: providerData.accountUser, withUserID: providerData.accountUserID, withPassword: providerData.accountPassword, withUrl: providerData.accountUrl)
        ocNetworking?.moveFileOrFolder(fileNameFrom, fileNameTo: fileNameTo, success: {
            
            if metadataFrom.directory {
                
                NCManageDatabase.sharedInstance.deleteDirectoryAndSubDirectory(serverUrl: serverUrlFrom)
                NCManageDatabase.sharedInstance.moveMetadata(fileName: metadataFrom.fileName, directoryID: metadataFrom.directoryID, directoryIDTo: directoryIDTo)
                _ = NCManageDatabase.sharedInstance.addDirectory(encrypted: false, favorite: false, fileID: nil, permissions: nil, serverUrl: serverUrlTo)
                
            } else {
                NCManageDatabase.sharedInstance.moveMetadata(fileName: metadataFrom.fileName, directoryID: metadataFrom.directoryID, directoryIDTo: directoryIDTo)
            }
            
            guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileID = %@", self.providerData.account, fileIDFrom)) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            
            let parentItemIdentifier = self.providerData.getParentItemIdentifier(metadata: metadata)
            if parentItemIdentifier != nil {
                let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier!, providerData: self.providerData)
                completionHandler(item, nil)
            } else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
            }
            
        }, failure: { (errorMessage, errorCode) in
            completionHandler(nil, NSFileProviderError(.serverUnreachable))
        })
    }
    
    override func renameItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toName itemName: String, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else { return }
        
        // Check account
        if providerData.setupActiveAccount() == false {
            completionHandler(nil, NSFileProviderError(.notAuthenticated))
            return
        }
        
        guard let metadata = providerData.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        guard let directoryTable = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "serverUrl = %@", serverUrl)) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        let fileNameFrom = metadata.fileNameView
        let fileNamePathFrom = serverUrl + "/" + fileNameFrom
        let fileNamePathTo = serverUrl + "/" + itemName
        
        let ocNetworking = OCnetworking.init(delegate: nil, metadataNet: nil, withUser: providerData.accountUser, withUserID: providerData.accountUserID, withPassword: providerData.accountPassword, withUrl: providerData.accountUrl)
        ocNetworking?.moveFileOrFolder(fileNamePathFrom, fileNameTo: fileNamePathTo, success: {
            
            // Rename metadata
            guard let metadata = NCManageDatabase.sharedInstance.renameMetadata(fileNameTo: itemName, fileID: metadata.fileID) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            
            if metadata.directory {
                
                NCManageDatabase.sharedInstance.setDirectory(serverUrl: fileNamePathFrom, serverUrlTo: fileNamePathTo, etag: nil, fileID: nil, encrypted: directoryTable.e2eEncrypted)
                
            } else {
                
                let itemIdentifier = self.providerData.getItemIdentifier(metadata: metadata)
                
                _ = self.moveFile(self.providerData.fileProviderStorageURL!.path + "/" + itemIdentifier.rawValue + "/" + fileNameFrom, toPath: self.providerData.fileProviderStorageURL!.path + "/" + itemIdentifier.rawValue + "/" + itemName)
                
                NCManageDatabase.sharedInstance.setLocalFile(fileID: metadata.fileID, date: nil, exifDate: nil, exifLatitude: nil, exifLongitude: nil, fileName: itemName, etag: nil, etagFPE: nil)
            }
            
            let parentItemIdentifier = self.providerData.getParentItemIdentifier(metadata: metadata)
            if parentItemIdentifier != nil {
                let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier!, providerData: self.providerData)
                completionHandler(item, nil)
            } else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
            }
            
        }, failure: { (errorMessage, errorCode) in
            completionHandler(nil, NSFileProviderError(.serverUnreachable))
        })
    }
    
    override func setFavoriteRank(_ favoriteRank: NSNumber?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else { return }
        
        completionHandler(nil, nil)
        
        /*
         guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileID = %@", account, itemIdentifier.rawValue)) else {
         completionHandler(nil, NSFileProviderError(.noSuchItem))
         return
         }
         guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
         completionHandler(nil, NSFileProviderError(.noSuchItem))
         return
         }
         
         // Refresh Favorite Identifier Rank
         listFavoriteIdentifierRank = NCManageDatabase.sharedInstance.getTableMetadatasDirectoryFavoriteIdentifierRank()
         
         if favoriteRank == nil {
         listFavoriteIdentifierRank.removeValue(forKey: itemIdentifier.rawValue)
         } else {
         let rank = listFavoriteIdentifierRank[itemIdentifier.rawValue]
         if rank == nil {
         listFavoriteIdentifierRank[itemIdentifier.rawValue] = favoriteRank//NSNumber(value: Int64(newRank))
         }
         favorite = true
         }
         
         // Call the completion handler before performing any network activity or other long-running tasks. Defer these tasks to the background
         let item = FileProviderItem(metadata: metadata, serverUrl: serverUrl)
         completionHandler(item, nil)
         
         // Change Status ? Call API Nextcloud Network
         if (favorite == true && metadata.favorite == false) || (favorite == false && metadata.favorite == true) {
         
         DispatchQueue(label: "com.nextcloud", qos: .background, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil).async {
         
         //NSString *fileOrFolderPath = [CCUtility returnFileNamePathFromFileName:fileName serverUrl:serverUrl activeUrl:_activeUrl];
         
         ocNetworking?.settingFavorite(metadata.fileName, serverUrl: serverUrl, favorite: favorite, success: {
         
         // Change DB
         metadata.favorite = favorite
         _ = NCManageDatabase.sharedInstance.addMetadata(metadata)
         
         // Refresh Favorite Identifier Rank
         listFavoriteIdentifierRank = NCManageDatabase.sharedInstance.getTableMetadatasDirectoryFavoriteIdentifierRank()
         
         // Refresh Item
         self.refreshEnumerator(identifier: itemIdentifier, serverUrl: serverUrl)
         
         }, failure: { (errorMessage, errorCode) in
         print("errorMessage")
         })
         }
         }
         */
    }
    
    override func setTagData(_ tagData: Data?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else { return }
        
        guard let metadata = providerData.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        // Add, Remove (nil)
        NCManageDatabase.sharedInstance.addTag(metadata.fileID, tagIOS: tagData)
        
        let parentItemIdentifier = providerData.getParentItemIdentifier(metadata: metadata)
        if parentItemIdentifier != nil {
            
            let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier!, providerData: providerData)
            
            fileProviderSignalUpdateItem.append(item)
            signalEnumerator(for: [item.parentItemIdentifier, .workingSet])
            
            completionHandler(item, nil)
            
        } else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
        }
    }
    
    /*
     override func trashItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
     print("[LOG] trashitem")
     completionHandler(nil, nil)
     }
     
     override func untrashItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier?, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
     print("[LOG] untrashitem")
     completionHandler(nil, nil)
     }
     */
    
    override func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else { return }
        
        var size = 0 as Double
        let metadata = tableMetadata()
        let fileCoordinator = NSFileCoordinator()
        var error: NSError?
        
        DispatchQueue.main.async {
            
            guard let tableDirectory = self.providerData.getTableDirectoryFromParentItemIdentifier(parentItemIdentifier) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            let serverUrl = tableDirectory.serverUrl
            
            // --------------------------------------------- Copy file here with security access
            
            if fileURL.startAccessingSecurityScopedResource() == false {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            
            let fileName = self.createFileName(fileURL.lastPathComponent, directoryID: tableDirectory.directoryID, serverUrl: serverUrl)
            let fileNamePathDirectory = self.providerData.fileProviderStorageURL!.path + "/" + self.FILEID_IMPORT_METADATA_TEMP + tableDirectory.directoryID + fileName
            
            do {
                try FileManager.default.createDirectory(atPath: fileNamePathDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch  { }
            
            fileCoordinator.coordinate(readingItemAt: fileURL, options: NSFileCoordinator.ReadingOptions.withoutChanges, error: &error) { (url) in
                _ = self.moveFile(url.path, toPath: fileNamePathDirectory + "/" + fileName)
                
            }
            
            fileURL.stopAccessingSecurityScopedResource()
            
            do {
                let attributes = try self.fileManager.attributesOfItem(atPath: fileNamePathDirectory + "/" + fileName)
                size = attributes[FileAttributeKey.size] as! Double
                let typeFile = attributes[FileAttributeKey.type] as! FileAttributeType
                if typeFile == FileAttributeType.typeDirectory {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                    return
                }
            } catch {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            
            // ---------------------------------------------------------------------------------
            
            // Metadata TEMP
            metadata.account = self.providerData.account
            metadata.date = NSDate()
            metadata.directory = false
            metadata.directoryID = tableDirectory.directoryID
            metadata.etag = ""
            metadata.fileID = self.FILEID_IMPORT_METADATA_TEMP + tableDirectory.directoryID + fileName
            metadata.size = size
            metadata.status = Double(k_metadataStatusHide)
            metadata.fileName = fileURL.lastPathComponent
            metadata.fileNameView = fileURL.lastPathComponent
            CCUtility.insertTypeFileIconName(fileName, metadata: metadata)
            
            if (size > 0) {
                
                let metadataNet = CCMetadataNet()
                
                metadataNet.account = self.providerData.account
                metadataNet.assetLocalIdentifier = self.FILEID_IMPORT_METADATA_TEMP + tableDirectory.directoryID + fileName
                metadataNet.fileName = fileName
                metadataNet.path = fileNamePathDirectory + "/" + fileName
                metadataNet.selector = selectorUploadFile
                metadataNet.selectorPost = ""
                metadataNet.serverUrl = serverUrl
                metadataNet.session = k_upload_session_extension
                metadataNet.sessionError = ""
                metadataNet.sessionID = ""
                metadataNet.taskStatus = Int(k_taskStatusResume)
                
                _ = NCManageDatabase.sharedInstance.addQueueUpload(metadataNet: metadataNet)
            }
            
            guard let metadataDB = NCManageDatabase.sharedInstance.addMetadata(metadata) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            
            let item = FileProviderItem(metadata: metadataDB, parentItemIdentifier: parentItemIdentifier, providerData: self.providerData)
            completionHandler(item, nil)
        }
    }
    
}
