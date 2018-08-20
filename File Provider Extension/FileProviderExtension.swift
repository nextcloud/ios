//
//  FileProviderExtension.swift
//  Files
//
//  Created by Marino Faggiana on 26/03/18.
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

/* -----------------------------------------------------------------------------------------------------------------------------------------------
                                                            STRUCT item
   -----------------------------------------------------------------------------------------------------------------------------------------------
 
 
    itemIdentifier = NSFileProviderItemIdentifier.rootContainer.rawValue            --> root
    parentItemIdentifier = NSFileProviderItemIdentifier.rootContainer.rawValue      --> root
 
                                    ↓
 
    itemIdentifier = metadata.fileID (ex. 00ABC1)                                   --> func getItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier
    parentItemIdentifier = NSFileProviderItemIdentifier.rootContainer.rawValue      --> func getParentItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier?
 
                                    ↓

    itemIdentifier = metadata.fileID (ex. 00CCC)                                    --> func getItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier
    parentItemIdentifier = parent itemIdentifier (00ABC1)                           --> func getParentItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier?
 
                                    ↓
 
    itemIdentifier = metadata.fileID (ex. 000DD)                                    --> func getItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier
    parentItemIdentifier = parent itemIdentifier (00CCC)                            --> func getParentItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier?
 
   -------------------------------------------------------------------------------------------------------------------------------------------- */

class FileProviderExtension: NSFileProviderExtension, CCNetworkingDelegate {
    
    var providerData = FileProviderData()

    var outstandingDownloadTasks = [URL: URLSessionTask]()
    
    lazy var fileCoordinator: NSFileCoordinator = {
        
        let fileCoordinator = NSFileCoordinator()
        fileCoordinator.purposeIdentifier = NSFileProviderManager.default.providerIdentifier
        return fileCoordinator
    }()
    
    override init() {
        
        super.init()
        
        // Create directory File Provider Storage
        CCUtility.getDirectoryProviderStorage()
        
        // Setup account
        _ = providerData.setupActiveAccount()
        
        // Upload Imnport Document
        self.uploadFileImportDocument()
    }
    
    // MARK: - Enumeration
    
    override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {
        
        var maybeEnumerator: NSFileProviderEnumerator? = nil
        
        // Check account
        if (containerItemIdentifier != NSFileProviderItemIdentifier.workingSet) {
            if providerData.setupActiveAccount() == false {
                throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.notAuthenticated.rawValue, userInfo:[:])
            }
        }

        if (containerItemIdentifier == NSFileProviderItemIdentifier.rootContainer) {
            maybeEnumerator = FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier, providerData: providerData)
        } else if (containerItemIdentifier == NSFileProviderItemIdentifier.workingSet) {
            maybeEnumerator = FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier, providerData: providerData)
        } else {
            // determine if the item is a directory or a file
            // - for a directory, instantiate an enumerator of its subitems
            // - for a file, instantiate an enumerator that observes changes to the file
            let item = try self.item(for: containerItemIdentifier)
            
            if item.typeIdentifier == kUTTypeFolder as String {
                maybeEnumerator = FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier, providerData: providerData)
            } else {
                maybeEnumerator = FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier, providerData: providerData)
            }
        }
        
        guard let enumerator = maybeEnumerator else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:])
        }
       
        return enumerator
    }
    
    // MARK: - Item

    override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
        
        if identifier == .rootContainer {
            
            if let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", providerData.account, providerData.homeServerUrl)) {
                    
                let metadata = tableMetadata()
                    
                metadata.account = providerData.account
                metadata.directory = true
                metadata.directoryID = directory.directoryID
                metadata.fileID = NSFileProviderItemIdentifier.rootContainer.rawValue
                metadata.fileName = ""
                metadata.fileNameView = ""
                metadata.typeFile = k_metadataTypeFile_directory
                    
                return FileProviderItem(metadata: metadata, parentItemIdentifier: NSFileProviderItemIdentifier(NSFileProviderItemIdentifier.rootContainer.rawValue), providerData: providerData)
            }
            
        } else {
            
            guard let metadata = providerData.getTableMetadataFromItemIdentifier(identifier) else {
                throw NSFileProviderError(.noSuchItem)
            }
            
            guard let parentItemIdentifier = providerData.getParentItemIdentifier(metadata: metadata) else {
                throw NSFileProviderError(.noSuchItem)
            }
            
            let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier, providerData: providerData)
            return item
        }
        
        throw NSFileProviderError(.noSuchItem)
    }
    
    override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
        
        // resolve the given identifier to a file on disk
        guard let item = try? item(for: identifier) else {
            return nil
        }
            
        // in this implementation, all paths are structured as <base storage directory>/<item identifier>/<item file name>
            
        let manager = NSFileProviderManager.default
        var url = manager.documentStorageURL.appendingPathComponent(identifier.rawValue, isDirectory: true)
            
        if item.typeIdentifier == (kUTTypeFolder as String) {
            url = url.appendingPathComponent(item.filename, isDirectory:true)
        } else {
            url = url.appendingPathComponent(item.filename, isDirectory:false)
        }
            
        return url
    }
    
    override func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
        
        // resolve the given URL to a persistent identifier using a database
        let pathComponents = url.pathComponents
        
        // exploit the fact that the path structure has been defined as
        // <base storage directory>/<item identifier>/<item file name> above
        assert(pathComponents.count > 2)
        
        let itemIdentifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
        return itemIdentifier
    }
    
    // MARK: -
    
    override func providePlaceholder(at url: URL, completionHandler: @escaping (Error?) -> Void) {

        guard let identifier = persistentIdentifierForItem(at: url) else {
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }

        do {
            let fileProviderItem = try item(for: identifier)
            let placeholderURL = NSFileProviderManager.placeholderURL(for: url)
            try NSFileProviderManager.writePlaceholder(at: placeholderURL,withMetadata: fileProviderItem)
            completionHandler(nil)
        } catch let error {
            print("error: \(error)")
            completionHandler(error)
        }
    }

    override func startProvidingItem(at url: URL, completionHandler: @escaping ((_ error: Error?) -> Void)) {
        
        let pathComponents = url.pathComponents
        let identifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
            
        // Check account
        if providerData.setupActiveAccount() == false {
            completionHandler(NSFileProviderError(.notAuthenticated))
            return
        }
            
        guard let metadata = providerData.getTableMetadataFromItemIdentifier(identifier) else {
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }
            
        // Error ? reUpload when touch
        if metadata.status == k_metadataStatusUploadError && metadata.session == k_upload_session_extension {
            
            if metadata.session == k_upload_session_extension {
                self.reUpload(metadata)
            }
                
            completionHandler(nil)
            return
        }
            
        // is Upload [Office 365 !!!]
        if metadata.fileID.contains(metadata.directoryID + metadata.fileName) {
            completionHandler(nil)
            return
        }
            
        let tableLocalFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "fileID == %@", metadata.fileID))
        if tableLocalFile != nil && CCUtility.fileProviderStorageExists(metadata.fileID, fileNameView: metadata.fileNameView) {
            completionHandler(nil)
            return
        }
            
        guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }
                        
        let ocNetworking = OCnetworking.init(delegate: nil, metadataNet: nil, withUser: providerData.accountUser, withUserID: providerData.accountUserID, withPassword: providerData.accountPassword, withUrl: providerData.accountUrl)
        let task = ocNetworking?.downloadFileNameServerUrl(serverUrl + "/" + metadata.fileName, fileNameLocalPath: url.path, communication: CCNetworking.shared().sharedOCCommunicationExtensionDownload(), success: { (lenght, etag, date) in
                
            // remove Task
            self.outstandingDownloadTasks.removeValue(forKey: url)
            
            // update DB Local
            metadata.date = date! as NSDate
            metadata.etag = etag!
            NCManageDatabase.sharedInstance.addLocalFile(metadata: metadata)
            NCManageDatabase.sharedInstance.setLocalFile(fileID: metadata.fileID, date: date! as NSDate, exifDate: nil, exifLatitude: nil, exifLongitude: nil, fileName: nil, etag: etag)
            
            // Update DB Metadata
            _ = NCManageDatabase.sharedInstance.addMetadata(metadata)

            completionHandler(nil)
            return
                    
        }, failure: { (errorMessage, errorCode) in
                
            // remove task
            self.outstandingDownloadTasks.removeValue(forKey: url)
            
            if errorCode == Int(CFNetworkErrors.cfurlErrorCancelled.rawValue) {
                completionHandler(NSFileProviderError(.noSuchItem))
            } else {
                completionHandler(NSFileProviderError(.serverUnreachable))
            }
            return
        })
            
        // Add and register task
        if task != nil {
            outstandingDownloadTasks[url] = task
            NSFileProviderManager.default.register(task!, forItemWithIdentifier: NSFileProviderItemIdentifier(identifier.rawValue)) { (error) in }
        }
    }
    
    override func itemChanged(at url: URL) {
        
        let pathComponents = url.pathComponents

        assert(pathComponents.count > 2)

        let itemIdentifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
        let fileName = pathComponents[pathComponents.count - 1]
        
        uploadFileItemChanged(for: itemIdentifier, fileName: fileName, url: url)
    }
    
    override func stopProvidingItem(at url: URL) {
        // Called after the last claim to the file has been released. At this point, it is safe for the file provider to remove the content file.
        // Care should be taken that the corresponding placeholder file stays behind after the content file has been deleted.
        
        // Called after the last claim to the file has been released. At this point, it is safe for the file provider to remove the content file.
        
        // look up whether the file has local changes
        let fileHasLocalChanges = false
        
        if !fileHasLocalChanges {
            // remove the existing file to free up space
            do {
                _ = try providerData.fileManager.removeItem(at: url)
            } catch let error {
                print("error: \(error)")
            }
            
            // write out a placeholder to facilitate future property lookups
            self.providePlaceholder(at: url, completionHandler: { error in
                // handle any error, do any necessary cleanup
            })
        }
        
        // Download task
        if let downloadTask = outstandingDownloadTasks[url] {
            downloadTask.cancel()
            outstandingDownloadTasks.removeValue(forKey: url)
        }
    }

}
