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
import NCCommunication

extension FileProviderExtension {

    override func createDirectory(withName directoryName: String, inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        
        guard let tableDirectory = fileProviderUtility.sharedInstance.getTableDirectoryFromParentItemIdentifier(parentItemIdentifier, account: fileProviderData.sharedInstance.account, homeServerUrl: fileProviderData.sharedInstance.homeServerUrl) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        let directoryName = NCUtility.shared.createFileName(directoryName, serverUrl: tableDirectory.serverUrl, account: fileProviderData.sharedInstance.account)
        let serverUrlFileName = tableDirectory.serverUrl + "/" + directoryName
        
        NCCommunication.shared.createFolder(serverUrlFileName) { (account, ocId, date, errorCode, errorDescription) in
                        
            if errorCode == 0 {
                
                NCCommunication.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", showHiddenFiles: CCUtility.getShowHiddenFiles()) { (account, files, responseData, errorCode, errorDescription) in
                    
                    if errorCode == 0 && files.count > 0 {
                        
                        let file = files.first!
                        let metadata = NCManageDatabase.sharedInstance.convertNCFileToMetadata(file, isEncrypted: false, account: fileProviderData.sharedInstance.account)
            
                        NCManageDatabase.sharedInstance.addDirectory(encrypted: false, favorite: false, ocId: ocId!, fileId: metadata.fileId, etag: metadata.etag, permissions: metadata.permissions, serverUrl: serverUrlFileName, richWorkspace: metadata.richWorkspace, creationDate: metadata.creationDate, account: metadata.account)
                        NCManageDatabase.sharedInstance.addMetadata(metadata)
                        
                        guard let metadataInsert = NCManageDatabase.sharedInstance.getMetadataFromOcId(ocId!) else {
                            completionHandler(nil, NSFileProviderError(.noSuchItem))
                            return
                        }
                        
                        guard let parentItemIdentifier = fileProviderUtility.sharedInstance.getParentItemIdentifier(metadata: metadataInsert, homeServerUrl: fileProviderData.sharedInstance.homeServerUrl) else {
                            completionHandler(nil, NSFileProviderError(.noSuchItem))
                            return
                        }
                     
                        let item = FileProviderItem(metadata: metadataInsert, parentItemIdentifier: parentItemIdentifier)
                        completionHandler(item, nil)
                        
                    } else {
                        completionHandler(nil, NSFileProviderError(.serverUnreachable))
                    }
                }
                
            } else {
                completionHandler(nil, NSFileProviderError(.serverUnreachable))
            }
        }
    }
    
    override func deleteItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (Error?) -> Void) {
        
        guard let metadata = fileProviderUtility.sharedInstance.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }
        
        let ocId = metadata.ocId
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let isDirectory = metadata.directory
        let serverUrl = metadata.serverUrl;
        let fileName = metadata.fileName;
        
        NCCommunication.shared.deleteFileOrFolder(serverUrlFileName) { (account, errorCode, errorDescription) in
            
            if errorCode == 0 { //|| error == kOCErrorServerPathNotFound {
            
                let fileNamePath = CCUtility.getDirectoryProviderStorageOcId(itemIdentifier.rawValue)!
                do {
                    try fileProviderUtility.sharedInstance.fileManager.removeItem(atPath: fileNamePath)
                } catch let error {
                    print("error: \(error)")
                }
                
                if isDirectory {
                    let dirForDelete = CCUtility.stringAppendServerUrl(serverUrl, addFileName: fileName)
                    NCManageDatabase.sharedInstance.deleteDirectoryAndSubDirectory(serverUrl: dirForDelete!, account: account)
                }
                
                NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocId))
                NCManageDatabase.sharedInstance.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", ocId))
                
                completionHandler(nil)

            } else {
                completionHandler( NSFileProviderError(.serverUnreachable))
            }
        }
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
        
        let ocIdFrom = metadataFrom.ocId
        let serverUrlFrom = metadataFrom.serverUrl
        let fileNameFrom = serverUrlFrom + "/" + itemFrom.filename
        
        guard let tableDirectoryTo = fileProviderUtility.sharedInstance.getTableDirectoryFromParentItemIdentifier(parentItemIdentifier, account: fileProviderData.sharedInstance.account, homeServerUrl: fileProviderData.sharedInstance.homeServerUrl) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        let serverUrlTo = tableDirectoryTo.serverUrl
        let fileNameTo = serverUrlTo + "/" + itemFrom.filename
        
        NCCommunication.shared.moveFileOrFolder(serverUrlFileNameSource: fileNameFrom, serverUrlFileNameDestination: fileNameTo, overwrite: false) { (account, errorCode, errorDescription) in
       
            if errorCode == 0 {
                
                if metadataFrom.directory {
                    NCManageDatabase.sharedInstance.deleteDirectoryAndSubDirectory(serverUrl: serverUrlFrom, account: account)
                    NCManageDatabase.sharedInstance.renameDirectory(ocId: ocIdFrom, serverUrl: serverUrlTo)                    
                }
                
                NCManageDatabase.sharedInstance.moveMetadata(ocId: ocIdFrom, serverUrlTo: serverUrlTo)
                
                guard let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(ocIdFrom) else {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                    return
                }
                
                let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
                completionHandler(item, nil)
                
            } else {
                completionHandler(nil, NSFileProviderError(.serverUnreachable))
            }
        }
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
        let ocId = metadata.ocId
        
        NCCommunication.shared.moveFileOrFolder(serverUrlFileNameSource: fileNamePathFrom, serverUrlFileNameDestination: fileNamePathTo, overwrite: false) { (account, errorCode, errorDescription) in
       
            if errorCode == 0 {
                
                // Rename metadata
                NCManageDatabase.sharedInstance.renameMetadata(fileNameTo: itemName, ocId: ocId)
                
                guard let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(ocId) else {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                    return
                }
                
                if metadata.directory {
                    
                    NCManageDatabase.sharedInstance.setDirectory(serverUrl: fileNamePathFrom, serverUrlTo: fileNamePathTo, etag: nil, ocId: nil, fileId: nil, encrypted: directoryTable.e2eEncrypted, richWorkspace: nil, account: account)
                    
                } else {
                    
                    let itemIdentifier = fileProviderUtility.sharedInstance.getItemIdentifier(metadata: metadata)
                    
                    // rename file
                    _ = fileProviderUtility.sharedInstance.moveFile(CCUtility.getDirectoryProviderStorageOcId(itemIdentifier.rawValue, fileNameView: fileNameFrom), toPath: CCUtility.getDirectoryProviderStorageOcId(itemIdentifier.rawValue, fileNameView: itemName))
                    
                    _ = fileProviderUtility.sharedInstance.moveFile(CCUtility.getDirectoryProviderStoragePreviewOcId(itemIdentifier.rawValue, etag: metadata.etag), toPath: CCUtility.getDirectoryProviderStoragePreviewOcId(itemIdentifier.rawValue, etag: metadata.etag))
                    
                    _ = fileProviderUtility.sharedInstance.moveFile(CCUtility.getDirectoryProviderStorageIconOcId(itemIdentifier.rawValue, etag: metadata.etag), toPath: CCUtility.getDirectoryProviderStorageIconOcId(itemIdentifier.rawValue, etag: metadata.etag))
                    
                    NCManageDatabase.sharedInstance.setLocalFile(ocId: ocId, fileName: itemName, etag: nil)
                }
                
                guard let parentItemIdentifier = fileProviderUtility.sharedInstance.getParentItemIdentifier(metadata: metadata, homeServerUrl: fileProviderData.sharedInstance.homeServerUrl) else {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                    return
                }
                
                let item = FileProviderItem(metadata: metadata.freeze(), parentItemIdentifier: parentItemIdentifier)
                completionHandler(item, nil)
                
            } else {
                completionHandler(nil, NSFileProviderError(.serverUnreachable))
            }
        }
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
        let ocId = metadata.ocId
        
        if favoriteRank == nil {
            fileProviderData.sharedInstance.listFavoriteIdentifierRank.removeValue(forKey: itemIdentifier.rawValue)
        } else {
            let rank = fileProviderData.sharedInstance.listFavoriteIdentifierRank[itemIdentifier.rawValue]
            if rank == nil {
                fileProviderData.sharedInstance.listFavoriteIdentifierRank[itemIdentifier.rawValue] = favoriteRank
            }
            favorite = true
        }
        
        if (favorite == true && metadata.favorite == false) || (favorite == false && metadata.favorite == true) {
            let fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: fileProviderData.sharedInstance.accountUrlBase, account: metadata.account)!
            
            NCCommunication.shared.setFavorite(fileName: fileNamePath, favorite: favorite) { (account, errorCode, errorDescription) in
                
                if errorCode == 0 {
                    
                    guard let metadataTemp = NCManageDatabase.sharedInstance.getMetadataFromOcId(ocId) else {
                        completionHandler(nil, NSFileProviderError(.noSuchItem))
                        return
                    }
                    let metadata = tableMetadata.init(value: metadataTemp)
                    
                    // Change DB
                    metadata.favorite = favorite
                    NCManageDatabase.sharedInstance.addMetadata(metadata)
                    let item = FileProviderItem(metadata: metadata.freeze(), parentItemIdentifier: parentItemIdentifier)
                    
                    fileProviderData.sharedInstance.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
                    fileProviderData.sharedInstance.signalEnumerator(for: [.workingSet])

                    completionHandler(item, nil)
                    
                } else {
                    
                    guard let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(ocId) else {
                        completionHandler(nil, NSFileProviderError(.noSuchItem))
                        return
                    }
                    
                    // Errore, remove from listFavoriteIdentifierRank
                    fileProviderData.sharedInstance.listFavoriteIdentifierRank.removeValue(forKey: itemIdentifier.rawValue)
                    let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
                        
                    fileProviderData.sharedInstance.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
                    fileProviderData.sharedInstance.signalEnumerator(for: [.workingSet])
                                
                    completionHandler(item, NSFileProviderError(.serverUnreachable))
                }
            }
        }
    }
    
    override func setTagData(_ tagData: Data?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        
        guard let metadataForTag = fileProviderUtility.sharedInstance.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        let ocId = metadataForTag.ocId
        let account = metadataForTag.account
        
        // Add, Remove (nil)
        NCManageDatabase.sharedInstance.addTag(ocId, tagIOS: tagData, account: account)
        
        guard let metadata = NCManageDatabase.sharedInstance.getMetadataFromOcId(ocId) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        guard let parentItemIdentifier = fileProviderUtility.sharedInstance.getParentItemIdentifier(metadata: metadata, homeServerUrl: fileProviderData.sharedInstance.homeServerUrl) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
        
        fileProviderData.sharedInstance.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
        fileProviderData.sharedInstance.signalEnumerator(for: [.workingSet])

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
        completionHandler(item, nil)
    }
}
