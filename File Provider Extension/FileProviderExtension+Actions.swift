//
//  FileProviderExtension+Actions.swift
//  PickerFileProvider
//
//  Created by Marino Faggiana on 28/05/18.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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

import FileProvider

extension FileProviderExtension {

    override func createDirectory(withName directoryName: String, inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        
        guard let tableDirectory = fileProviderUtility.sharedInstance.getTableDirectoryFromParentItemIdentifier(parentItemIdentifier, account: fileProviderData.sharedInstance.account, homeServerUrl: fileProviderData.sharedInstance.homeServerUrl) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        let serverUrl = tableDirectory.serverUrl
        
        OCNetworking.sharedManager().createFolder(withAccount: fileProviderData.sharedInstance.account, serverUrl: serverUrl, fileName: directoryName, completion: { (account, fileID, date, message, errorCode) in
            
            if errorCode == 0 && account == fileProviderData.sharedInstance.account {
                
                let metadata = tableMetadata()
                
                metadata.account = account!
                metadata.directory = true
                metadata.fileID = fileID!
                metadata.fileName = directoryName
                metadata.fileNameView = directoryName
                metadata.serverUrl = serverUrl
                metadata.typeFile = k_metadataTypeFile_directory
                
                // METADATA
                guard let metadataDB = NCManageDatabase.sharedInstance.addMetadata(metadata) else {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                    return
                }
                
                // DIRECTORY
                guard let _ = NCManageDatabase.sharedInstance.addDirectory(encrypted: false, favorite: false, fileID: fileID!, permissions: nil, serverUrl: serverUrl + "/" + directoryName, account: account!) else {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                    return
                }
                
                let parentItemIdentifier = fileProviderUtility.sharedInstance.getParentItemIdentifier(metadata: metadataDB, homeServerUrl: fileProviderData.sharedInstance.homeServerUrl)
                if parentItemIdentifier != nil {
                    
                    let item = FileProviderItem(metadata: metadataDB, parentItemIdentifier: parentItemIdentifier!)
                    fileProviderData.sharedInstance.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
                    fileProviderData.sharedInstance.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
                    fileProviderData.sharedInstance.signalEnumerator(for: [item.parentItemIdentifier, .workingSet])
                    
                    completionHandler(item, nil)
                    
                } else {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                }
            } else {
                completionHandler(nil, NSFileProviderError(.serverUnreachable))
            }
        })
    }
    
    override func deleteItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (Error?) -> Void) {
        
        guard let metadata = fileProviderUtility.sharedInstance.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }
            
        guard let parentItemIdentifier = fileProviderUtility.sharedInstance.getParentItemIdentifier(metadata: metadata, homeServerUrl: fileProviderData.sharedInstance.homeServerUrl) else {
            completionHandler( NSFileProviderError(.noSuchItem))
            return
        }
        
        deleteFile(withIdentifier: itemIdentifier, parentItemIdentifier: parentItemIdentifier, metadata: metadata)
       
        // return immediately
        fileProviderData.sharedInstance.fileProviderSignalDeleteContainerItemIdentifier[itemIdentifier] = itemIdentifier
        fileProviderData.sharedInstance.fileProviderSignalDeleteWorkingSetItemIdentifier[itemIdentifier] = itemIdentifier
        fileProviderData.sharedInstance.signalEnumerator(for: [parentItemIdentifier, .workingSet])

        completionHandler(nil)
    }
    
    override func reparentItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, newName: String?, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        
        guard let itemFrom = try? item(for: itemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        guard let metadataFrom = fileProviderUtility.sharedInstance.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        let fileIDFrom = metadataFrom.fileID
        let serverUrlFrom = metadataFrom.serverUrl
        let fileNameFrom = serverUrlFrom + "/" + itemFrom.filename
        
        guard let tableDirectoryTo = fileProviderUtility.sharedInstance.getTableDirectoryFromParentItemIdentifier(parentItemIdentifier, account: fileProviderData.sharedInstance.account, homeServerUrl: fileProviderData.sharedInstance.homeServerUrl) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        let serverUrlTo = tableDirectoryTo.serverUrl
        let fileNameTo = serverUrlTo + "/" + itemFrom.filename
        
        OCNetworking.sharedManager().moveFileOrFolder(withAccount:  metadataFrom.account, fileName: fileNameFrom, fileNameTo: fileNameTo, completion: { (account, message, errorCode) in
            
            if errorCode == 0 && account == metadataFrom.account {
                
                if metadataFrom.directory {
                    NCManageDatabase.sharedInstance.deleteDirectoryAndSubDirectory(serverUrl: serverUrlFrom, account: account!)
                    _ = NCManageDatabase.sharedInstance.addDirectory(encrypted: false, favorite: false, fileID: nil, permissions: nil, serverUrl: serverUrlTo, account: account!)
                }
                
                NCManageDatabase.sharedInstance.moveMetadata(fileID: fileIDFrom, serverUrlTo: serverUrlTo)
                
                guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "fileID == %@", fileIDFrom)) else {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                    return
                }
                
                let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
                fileProviderData.sharedInstance.fileProviderSignalUpdateContainerItem[itemIdentifier] = item
                fileProviderData.sharedInstance.fileProviderSignalUpdateWorkingSetItem[itemIdentifier] = item
                fileProviderData.sharedInstance.signalEnumerator(for: [parentItemIdentifier, .workingSet])
                
                completionHandler(item, nil)
                
            } else {
                completionHandler(nil, NSFileProviderError(.serverUnreachable))
            }
        })
    }
    
    override func renameItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toName itemName: String, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        
        guard let metadata = fileProviderUtility.sharedInstance.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        guard let directoryTable = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        let fileNameFrom = metadata.fileNameView
        let fileNamePathFrom = metadata.serverUrl + "/" + fileNameFrom
        let fileNamePathTo = metadata.serverUrl + "/" + itemName
        
        OCNetworking.sharedManager().moveFileOrFolder(withAccount: metadata.account, fileName: fileNamePathFrom, fileNameTo: fileNamePathTo, completion: { (account, message, errorCode) in
            
            if errorCode == 0 && account == metadata.account {
                
                // Rename metadata
                guard let metadata = NCManageDatabase.sharedInstance.renameMetadata(fileNameTo: itemName, fileID: metadata.fileID) else {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                    return
                }
                
                if metadata.directory {
                    
                    NCManageDatabase.sharedInstance.setDirectory(serverUrl: fileNamePathFrom, serverUrlTo: fileNamePathTo, etag: nil, fileID: nil, encrypted: directoryTable.e2eEncrypted, account: account!)
                    
                } else {
                    
                    let itemIdentifier = fileProviderUtility.sharedInstance.getItemIdentifier(metadata: metadata)
                    
                    // rename file
                    _ = fileProviderUtility.sharedInstance.moveFile(CCUtility.getDirectoryProviderStorageFileID(itemIdentifier.rawValue, fileNameView: fileNameFrom), toPath: CCUtility.getDirectoryProviderStorageFileID(itemIdentifier.rawValue, fileNameView: itemName))
                    _ = fileProviderUtility.sharedInstance.moveFile(CCUtility.getDirectoryProviderStorageIconFileID(itemIdentifier.rawValue, fileNameView: fileNameFrom), toPath: CCUtility.getDirectoryProviderStorageIconFileID(itemIdentifier.rawValue, fileNameView: itemName))
                    
                    NCManageDatabase.sharedInstance.setLocalFile(fileID: metadata.fileID, date: nil, exifDate: nil, exifLatitude: nil, exifLongitude: nil, fileName: itemName, etag: nil)
                }
                
                guard let parentItemIdentifier = fileProviderUtility.sharedInstance.getParentItemIdentifier(metadata: metadata, homeServerUrl: fileProviderData.sharedInstance.homeServerUrl) else {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                    return
                }
                
                let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
                fileProviderData.sharedInstance.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
                fileProviderData.sharedInstance.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
                fileProviderData.sharedInstance.signalEnumerator(for: [item.parentItemIdentifier, .workingSet])
                
                completionHandler(item, nil)
            } else {
                completionHandler(nil, NSFileProviderError(.serverUnreachable))
            }
        })
    }
    
    override func setFavoriteRank(_ favoriteRank: NSNumber?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        
        guard let metadata = fileProviderUtility.sharedInstance.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        guard let parentItemIdentifier = fileProviderUtility.sharedInstance.getParentItemIdentifier(metadata: metadata, homeServerUrl: fileProviderData.sharedInstance.homeServerUrl) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        var favorite = false
        if favoriteRank == nil {
            fileProviderData.sharedInstance.listFavoriteIdentifierRank.removeValue(forKey: itemIdentifier.rawValue)
        } else {
            let rank = fileProviderData.sharedInstance.listFavoriteIdentifierRank[itemIdentifier.rawValue]
            if rank == nil {
                fileProviderData.sharedInstance.listFavoriteIdentifierRank[itemIdentifier.rawValue] = favoriteRank
            }
            favorite = true
        }
        
        let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
        fileProviderData.sharedInstance.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
        fileProviderData.sharedInstance.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
        fileProviderData.sharedInstance.signalEnumerator(for: [item.parentItemIdentifier, .workingSet])

        completionHandler(item, nil)
        
        if (favorite == true && metadata.favorite == false) || (favorite == false && metadata.favorite == true) {
            settingFavorite(favorite, withIdentifier: itemIdentifier, parentItemIdentifier: parentItemIdentifier, metadata: metadata)
        }
    }
    
    override func setTagData(_ tagData: Data?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        
        guard let metadata = fileProviderUtility.sharedInstance.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        // Add, Remove (nil)
        NCManageDatabase.sharedInstance.addTag(metadata.fileID, tagIOS: tagData, account: metadata.account)
        
        guard let parentItemIdentifier = fileProviderUtility.sharedInstance.getParentItemIdentifier(metadata: metadata, homeServerUrl: fileProviderData.sharedInstance.homeServerUrl) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
        fileProviderData.sharedInstance.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
        fileProviderData.sharedInstance.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
        fileProviderData.sharedInstance.signalEnumerator(for: [item.parentItemIdentifier, .workingSet])
        
        completionHandler(item, nil)
    }
    
    override func setLastUsedDate(_ lastUsedDate: Date?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        
        guard let metadata = fileProviderUtility.sharedInstance.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        guard let parentItemIdentifier = fileProviderUtility.sharedInstance.getParentItemIdentifier(metadata: metadata, homeServerUrl: fileProviderData.sharedInstance.homeServerUrl) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
        item.lastUsedDate = lastUsedDate

        completionHandler(item, nil)
    }
    
    override func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
                
        DispatchQueue.main.async {
            
            autoreleasepool {
            
                var size = 0 as Double
                let metadata = tableMetadata()
                var error: NSError?
            
                guard let tableDirectory = fileProviderUtility.sharedInstance.getTableDirectoryFromParentItemIdentifier(parentItemIdentifier, account: fileProviderData.sharedInstance.account, homeServerUrl: fileProviderData.sharedInstance.homeServerUrl) else {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                    return
                }
            
                // --------------------------------------------- Copy file here with security access
            
                if fileURL.startAccessingSecurityScopedResource() == false {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                    return
                }
            
                // typefile directory ? (NOT PERMITTED)
                do {
                    let attributes = try fileProviderUtility.sharedInstance.fileManager.attributesOfItem(atPath: fileURL.path)
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
            
                let fileName = NCUtility.sharedInstance.createFileName(fileURL.lastPathComponent, serverUrl: tableDirectory.serverUrl, account: fileProviderData.sharedInstance.account)
                let fileID = CCUtility.createMetadataID(fromAccount: fileProviderData.sharedInstance.account, serverUrl: tableDirectory.serverUrl, fileNameView: fileName, directory: false)!
            
                self.fileCoordinator.coordinate(readingItemAt: fileURL, options: .withoutChanges, error: &error) { (url) in
                    _ = fileProviderUtility.sharedInstance.moveFile(url.path, toPath: CCUtility.getDirectoryProviderStorageFileID(fileID, fileNameView: fileName))
                }
            
                fileURL.stopAccessingSecurityScopedResource()
            
                // ---------------------------------------------------------------------------------
            
                // Metadata TEMP
                metadata.account = fileProviderData.sharedInstance.account
                metadata.date = NSDate()
                metadata.directory = false
                metadata.etag = ""
                metadata.fileID = fileID
                metadata.fileName = fileName
                metadata.fileNameView = fileName
                metadata.serverUrl = tableDirectory.serverUrl
                metadata.size = size
                metadata.status = Int(k_metadataStatusHide)
               
                CCUtility.insertTypeFileIconName(fileName, metadata: metadata)

                if (size > 0) {
                    
                    metadata.session = k_upload_session_extension
                    metadata.sessionSelector = selectorUploadFile
                    metadata.status = Int(k_metadataStatusWaitUpload)
                }
                
                guard let metadataDB = NCManageDatabase.sharedInstance.addMetadata(metadata) else {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                    return
                }
                            
                let item = FileProviderItem(metadata: metadataDB, parentItemIdentifier: parentItemIdentifier)
            
                completionHandler(item, nil)

                self.uploadFileImportDocument()            
            }
        }
    }
}
