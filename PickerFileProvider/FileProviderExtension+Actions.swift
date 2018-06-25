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
                
                self.providerData.queueTradeSafe.sync(flags: .barrier) {
                    self.providerData.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
                    self.providerData.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
                }

                self.providerData.signalEnumerator(for: [item.parentItemIdentifier, .workingSet])

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
        
        guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
            return
        }
        
        deleteFile(withIdentifier: itemIdentifier, parentItemIdentifier: parentItemIdentifier, metadata: metadata, serverUrl: serverUrl)
       
        // return immediately
        providerData.queueTradeSafe.sync(flags: .barrier) {
            providerData.fileProviderSignalDeleteContainerItemIdentifier[itemIdentifier] = itemIdentifier
            providerData.fileProviderSignalDeleteWorkingSetItemIdentifier[itemIdentifier] = itemIdentifier
        }

        self.providerData.signalEnumerator(for: [parentItemIdentifier, .workingSet])

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
            
            guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "fileID == %@", fileIDFrom)) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            
            let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier, providerData: self.providerData)
            
            self.providerData.queueTradeSafe.sync(flags: .barrier) {
                self.providerData.fileProviderSignalUpdateContainerItem[itemIdentifier] = item
                self.providerData.fileProviderSignalUpdateWorkingSetItem[itemIdentifier] = item
            }

            self.providerData.signalEnumerator(for: [parentItemIdentifier, .workingSet])

            completionHandler(item, nil)
            
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
        
        guard let directoryTable = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "serverUrl == %@", serverUrl)) else {
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
                
                _ = self.providerData.moveFile(self.providerData.fileProviderStorageURL!.path + "/" + itemIdentifier.rawValue + "/" + fileNameFrom, toPath: self.providerData.fileProviderStorageURL!.path + "/" + itemIdentifier.rawValue + "/" + itemName)
                
                NCManageDatabase.sharedInstance.setLocalFile(fileID: metadata.fileID, date: nil, exifDate: nil, exifLatitude: nil, exifLongitude: nil, fileName: itemName, etag: nil)
            }
            
            guard let parentItemIdentifier = self.providerData.getParentItemIdentifier(metadata: metadata) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            
            let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier, providerData: self.providerData)
            
            self.providerData.queueTradeSafe.sync(flags: .barrier) {
                self.providerData.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
                self.providerData.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
            }

            self.providerData.signalEnumerator(for: [item.parentItemIdentifier, .workingSet])

            completionHandler(item, nil)
            
        }, failure: { (errorMessage, errorCode) in
            completionHandler(nil, NSFileProviderError(.serverUnreachable))
        })
    }
    
    override func setFavoriteRank(_ favoriteRank: NSNumber?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        
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
        
        guard let parentItemIdentifier = providerData.getParentItemIdentifier(metadata: metadata) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        var favorite = false
        if favoriteRank == nil {
            providerData.listFavoriteIdentifierRank.removeValue(forKey: itemIdentifier.rawValue)
        } else {
            let rank = providerData.listFavoriteIdentifierRank[itemIdentifier.rawValue]
            if rank == nil {
                providerData.listFavoriteIdentifierRank[itemIdentifier.rawValue] = favoriteRank
            }
            favorite = true
        }
        
        let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier, providerData: providerData)
        
        providerData.queueTradeSafe.sync(flags: .barrier) {
            providerData.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
            providerData.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
        }

        providerData.signalEnumerator(for: [item.parentItemIdentifier, .workingSet])

        completionHandler(item, nil)
        
        if (favorite == true && metadata.favorite == false) || (favorite == false && metadata.favorite == true) {
            settingFavorite(favorite, withIdentifier: itemIdentifier, parentItemIdentifier: parentItemIdentifier, metadata: metadata)
        }
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
        
        guard let parentItemIdentifier = providerData.getParentItemIdentifier(metadata: metadata) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier, providerData: providerData)
        
        providerData.queueTradeSafe.sync(flags: .barrier) {
            providerData.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
            providerData.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
        }
        
        providerData.signalEnumerator(for: [item.parentItemIdentifier, .workingSet])
        
        completionHandler(item, nil)
    }
    
    override func setLastUsedDate(_ lastUsedDate: Date?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else { return }
        
        guard let metadata = providerData.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        guard let parentItemIdentifier = providerData.getParentItemIdentifier(metadata: metadata) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier, providerData: providerData)
        item.lastUsedDate = lastUsedDate

        completionHandler(item, nil)
    }
    
    override func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else { return }
        
        DispatchQueue.main.async {
            
            autoreleasepool {
            
                var size = 0 as Double
                let metadata = tableMetadata()
                var error: NSError?
            
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
            
                // typefile directory ? (NOT PERMITTED)
                do {
                    let attributes = try self.providerData.fileManager.attributesOfItem(atPath: fileURL.path)
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
            
                let fileName = self.createFileName(fileURL.lastPathComponent, directoryID: tableDirectory.directoryID, serverUrl: serverUrl)
                let fileNamePathDirectory = self.providerData.fileProviderStorageURL!.path + "/" + tableDirectory.directoryID + fileName
            
                do {
                    try FileManager.default.createDirectory(atPath: fileNamePathDirectory, withIntermediateDirectories: true, attributes: nil)
                } catch  { }
            
                self.fileCoordinator.coordinate(readingItemAt: fileURL, options: .withoutChanges, error: &error) { (url) in
                    _ = self.providerData.moveFile(url.path, toPath: fileNamePathDirectory + "/" + fileName)
                }
            
                fileURL.stopAccessingSecurityScopedResource()
            
                // ---------------------------------------------------------------------------------
            
                // Metadata TEMP
                metadata.account = self.providerData.account
                metadata.assetLocalIdentifier = tableDirectory.directoryID + fileName
                metadata.date = NSDate()
                metadata.directory = false
                metadata.directoryID = tableDirectory.directoryID
                metadata.etag = ""
                metadata.fileID = tableDirectory.directoryID + fileName
                metadata.fileName = fileName
                metadata.fileNameView = fileName
                metadata.size = size
                metadata.status = Int(k_metadataStatusHide)
               
                CCUtility.insertTypeFileIconName(fileName, metadata: metadata)

                if (size > 0) {
                    
                    metadata.session = k_upload_session_extension
                    metadata.sessionSelector = selectorUploadFile
                    metadata.sessionSelectorPost = self.providerData.selectorPostImportDocument
                    metadata.status = Int(k_metadataStatusWaitUpload)
                }
                
                guard let metadataDB = NCManageDatabase.sharedInstance.addMetadata(metadata) else {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                    return
                }
                            
                let item = FileProviderItem(metadata: metadataDB, parentItemIdentifier: parentItemIdentifier, providerData: self.providerData)
            
                completionHandler(item, nil)

                self.uploadFileImportDocument()            
            }
        }
    }
    
    func createFileName(_ fileName: String, directoryID: String, serverUrl: String) -> String {
        
        var resultFileName = fileName
        
        providerData.queueTradeSafe.sync {
            
            var exitLoop = false
            
            while exitLoop == false {
                
                if NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account == %@ AND fileNameView == %@ AND directoryID == %@", providerData.account, resultFileName, directoryID)) != nil {
                    
                    var name = NSString(string: resultFileName).deletingPathExtension
                    let ext = NSString(string: resultFileName).pathExtension
                    
                    let characters = Array(name)
                    
                    if characters.count < 2 {
                        resultFileName = name + " " + "1" + "." + ext
                    } else {
                        let space = characters[characters.count-2]
                        let numChar = characters[characters.count-1]
                        var num = Int(String(numChar))
                        if (space == " " && num != nil) {
                            name = String(name.dropLast())
                            num = num! + 1
                            resultFileName = name + "\(num!)" + "." + ext
                        } else {
                            resultFileName = name + " " + "1" + "." + ext
                        }
                    }
                    
                } else {
                    exitLoop = true
                }
            }
        }
        
        return resultFileName
    }
    
}
