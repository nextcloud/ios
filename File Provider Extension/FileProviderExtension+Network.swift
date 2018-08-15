//
//  FileProviderExtension+Network.swift
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

    // --------------------------------------------------------------------------------------------
    //  MARK: - Delete
    // --------------------------------------------------------------------------------------------
    
    func deleteFile(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, parentItemIdentifier: NSFileProviderItemIdentifier, metadata: tableMetadata, serverUrl: String) {
        
        let ocNetworking = OCnetworking.init(delegate: nil, metadataNet: nil, withUser: providerData.accountUser, withUserID: providerData.accountUserID, withPassword: providerData.accountPassword, withUrl: providerData.accountUrl)
        ocNetworking?.deleteFileOrFolder(metadata.fileName, serverUrl: serverUrl, completion: { (message, errorCode) in
            
            if errorCode == 0 || errorCode == 404 {
                self.deleteFileSystem(for: metadata, serverUrl: serverUrl, itemIdentifier: itemIdentifier)
            }
        })
    }
    
    func deleteFileSystem(for metadata: tableMetadata, serverUrl: String, itemIdentifier: NSFileProviderItemIdentifier) {
        
        let fileNamePath = CCUtility.getDirectoryProviderStorageFileID(itemIdentifier.rawValue)!
        do {
            try self.providerData.fileManager.removeItem(atPath: fileNamePath)
        } catch let error {
            print("error: \(error)")
        }
        
        if metadata.directory {
            let dirForDelete = CCUtility.stringAppendServerUrl(serverUrl, addFileName: metadata.fileName)
            NCManageDatabase.sharedInstance.deleteDirectoryAndSubDirectory(serverUrl: dirForDelete!)
        }
        
        NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "fileID == %@", metadata.fileID), clearDateReadDirectoryID: nil)
        NCManageDatabase.sharedInstance.deleteLocalFile(predicate: NSPredicate(format: "fileID == %@", metadata.fileID))
    }
    
    // --------------------------------------------------------------------------------------------
    //  MARK: - Favorite
    // --------------------------------------------------------------------------------------------
    
    func settingFavorite(_ favorite: Bool, withIdentifier itemIdentifier: NSFileProviderItemIdentifier, parentItemIdentifier: NSFileProviderItemIdentifier, metadata: tableMetadata) {
        
        guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
            return
        }
        
        let fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: serverUrl, activeUrl: self.providerData.accountUrl)

        let ocNetworking = OCnetworking.init(delegate: nil, metadataNet: nil, withUser: providerData.accountUser, withUserID: providerData.accountUserID, withPassword: providerData.accountPassword, withUrl: providerData.accountUrl)
        ocNetworking?.settingFavorite(fileNamePath, favorite: favorite, completion: { (message, errorCode) in
            if errorCode == 0 {
                // Change DB
                metadata.favorite = favorite
                _ = NCManageDatabase.sharedInstance.addMetadata(metadata)
            } else {
                // Errore, remove from listFavoriteIdentifierRank
                self.providerData.listFavoriteIdentifierRank.removeValue(forKey: itemIdentifier.rawValue)
                
                let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier, providerData: self.providerData)
                
                self.providerData.queueTradeSafe.sync(flags: .barrier) {
                    self.providerData.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
                    self.providerData.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
                }
                
                self.providerData.signalEnumerator(for: [item.parentItemIdentifier, .workingSet])
            }
        })
    }
    
    // --------------------------------------------------------------------------------------------
    //  MARK: - Upload
    // --------------------------------------------------------------------------------------------
    
    func uploadStart(_ fileID: String!, account: String!, task: URLSessionUploadTask!, serverUrl: String!) {
        
        guard let metadataUpload = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "fileID == %@", fileID)) else {
            return
        }
        
        metadataUpload.status = Int(k_metadataStatusUploading)
        guard let metadata = NCManageDatabase.sharedInstance.addMetadata(metadataUpload) else {
            return
        }
        
        guard let parentItemIdentifier = providerData.getParentItemIdentifier(metadata: metadata) else {
            return
        }
        
        let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier, providerData: providerData)

        // Register for bytesSent
        NSFileProviderManager.default.register(task, forItemWithIdentifier: NSFileProviderItemIdentifier(item.itemIdentifier.rawValue)) { (error) in }
        
        providerData.queueTradeSafe.sync(flags: .barrier) {
            self.providerData.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
            self.providerData.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
        }
        
        self.providerData.signalEnumerator(for: [item.parentItemIdentifier, .workingSet])
    }
    
    func uploadFileSuccessFailure(_ fileName: String!, fileID: String!, assetLocalIdentifier: String!, serverUrl: String!, selector: String!, errorMessage: String!, errorCode: Int) {
                
        guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "fileID == %@", fileID)) else {
            return
        }
        
        guard let parentItemIdentifier = providerData.getParentItemIdentifier(metadata: metadata) else {
            return
        }
        
        // OK
        if errorCode == 0 {
            
            // Remove temp fileID = directoryID + fileName
            providerData.queueTradeSafe.sync(flags: .barrier) {
                let itemIdentifier = NSFileProviderItemIdentifier(metadata.directoryID+fileName)
                self.providerData.fileProviderSignalDeleteContainerItemIdentifier[itemIdentifier] = itemIdentifier
                self.providerData.fileProviderSignalDeleteWorkingSetItemIdentifier[itemIdentifier] = itemIdentifier
            }
            
            // Recreate ico
            CCGraphics.createNewImage(from: fileName, fileID: fileID, extension: NSString(string: fileName).pathExtension, filterGrayScale: false, typeFile: metadata.typeFile, writeImage: true)
            
            // remove session data
            metadata.session = ""
            metadata.sessionSelector = ""
            let metadata = NCManageDatabase.sharedInstance.addMetadata(metadata)
            
            let item = FileProviderItem(metadata: metadata!, parentItemIdentifier: parentItemIdentifier, providerData: providerData)

            providerData.queueTradeSafe.sync(flags: .barrier) {
                self.providerData.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
                self.providerData.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
            }
            
            uploadFileImportDocument()
            
        } else {
        
            // Error
            
            metadata.status = Int(k_metadataStatusUploadError)
            let metadata = NCManageDatabase.sharedInstance.addMetadata(metadata)
            
            let item = FileProviderItem(metadata: metadata!, parentItemIdentifier: parentItemIdentifier, providerData: providerData)
            
            providerData.queueTradeSafe.sync(flags: .barrier) {
                providerData.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
                providerData.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
            }
        }
        
        self.providerData.signalEnumerator(for: [parentItemIdentifier, .workingSet])
    }
    
    func uploadFileImportDocument() {
        
        let tableMetadatas = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND session == %@ AND (status == %d OR status == %d)", providerData.account, k_upload_session_extension, k_metadataStatusInUpload, k_metadataStatusUploading), sorted: "fileName", ascending: true)
        
        if (tableMetadatas == nil || (tableMetadatas!.count < Int(k_maxConcurrentOperationUpload))) {
            
            guard let metadataForUpload = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account == %@ AND session == %@ AND status == %d", providerData.account, k_upload_session_extension, k_metadataStatusWaitUpload)) else {
                return
            }
            
            CCNetworking.shared().delegate = self
            CCNetworking.shared().uploadFile(metadataForUpload, taskStatus: Int(k_taskStatusResume))
        }
    }
    
    func uploadFileItemChanged(for itemIdentifier: NSFileProviderItemIdentifier, fileName: String, url: URL) {
        
        var itemIdentifierForUpload = itemIdentifier
        
        // Is itemIdentifier = directoryID+fileName [Apple Works and ... ?]
        if itemIdentifier.rawValue.contains(fileName) && providerData.fileExists(atPath: CCUtility.getDirectoryProviderStorage()+"/"+itemIdentifier.rawValue) {
            let directoryID = itemIdentifier.rawValue.replacingOccurrences(of: fileName, with: "")
            guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "directoryID == %@ AND fileName == %@", directoryID, fileName)) else {
                return
            }
            itemIdentifierForUpload = providerData.getItemIdentifier(metadata: metadata)
            _ = providerData.moveFile(CCUtility.getDirectoryProviderStorage()+"/"+itemIdentifier.rawValue, toPath: CCUtility.getDirectoryProviderStorage()+"/"+itemIdentifierForUpload.rawValue)
        }
        
        guard let metadata = providerData.getTableMetadataFromItemIdentifier(itemIdentifierForUpload) else {
            return
        }
        
        metadata.session = k_upload_session_extension
        metadata.sessionSelector = selectorUploadFile
        metadata.status = Int(k_metadataStatusWaitUpload)

        guard let metadataForUpload = NCManageDatabase.sharedInstance.addMetadata(metadata) else {
            return
        }
        
        CCNetworking.shared().delegate = self
        CCNetworking.shared().uploadFile(metadataForUpload, taskStatus: Int(k_taskStatusResume))
    }
    
    func reUpload(_ metadata: tableMetadata) {
        
        metadata.status = Int(k_metadataStatusWaitUpload)
        let metadataForUpload = NCManageDatabase.sharedInstance.addMetadata(metadata)
        
        CCNetworking.shared().delegate = self
        CCNetworking.shared().uploadFile(metadataForUpload, taskStatus: Int(k_taskStatusResume))
    }
}
