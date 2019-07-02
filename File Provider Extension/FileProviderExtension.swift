//
//  FileProviderExtension.swift
//  Files
//
//  Created by Marino Faggiana on 26/03/18.
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
        
        // Upload Imnport Document
        self.uploadFileImportDocument()
    }
    
    // MARK: - Enumeration
    
    override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {
        
        var maybeEnumerator: NSFileProviderEnumerator? = nil
        
        // Check account
        if (containerItemIdentifier != NSFileProviderItemIdentifier.workingSet) {
            
#if targetEnvironment(simulator)
            
            if containerItemIdentifier == NSFileProviderItemIdentifier.rootContainer && self.domain?.identifier.rawValue == nil {
                throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.notAuthenticated.rawValue, userInfo:[:])
            } else if self.domain?.identifier.rawValue != nil {
                if fileProviderData.sharedInstance.setupActiveAccount(domain: self.domain?.identifier.rawValue) == false {
                    throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.notAuthenticated.rawValue, userInfo:[:])
                }
            } else {
                if fileProviderData.sharedInstance.setupActiveAccount(itemIdentifier: containerItemIdentifier) == false {
                    throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.notAuthenticated.rawValue, userInfo:[:])
                }
            }
#else
            if fileProviderData.sharedInstance.setupActiveAccount(domain: nil) == false {
                throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.notAuthenticated.rawValue, userInfo:[:])
            }
#endif            
        }

        if (containerItemIdentifier == NSFileProviderItemIdentifier.rootContainer) {
            maybeEnumerator = FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier)
        } else if (containerItemIdentifier == NSFileProviderItemIdentifier.workingSet) {
            maybeEnumerator = FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier)
        } else {
            // determine if the item is a directory or a file
            // - for a directory, instantiate an enumerator of its subitems
            // - for a file, instantiate an enumerator that observes changes to the file
            let item = try self.item(for: containerItemIdentifier)
            
            if item.typeIdentifier == kUTTypeFolder as String {
                maybeEnumerator = FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier)
            } else {
                maybeEnumerator = FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier)
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
            
            let metadata = tableMetadata()
            
            metadata.account = fileProviderData.sharedInstance.account
            metadata.directory = true
            metadata.fileID = NSFileProviderItemIdentifier.rootContainer.rawValue
            metadata.fileName = ""
            metadata.fileNameView = ""
            metadata.serverUrl = fileProviderData.sharedInstance.homeServerUrl
            metadata.typeFile = k_metadataTypeFile_directory
            
            return FileProviderItem(metadata: metadata, parentItemIdentifier: NSFileProviderItemIdentifier(NSFileProviderItemIdentifier.rootContainer.rawValue))
            
        } else {
            
            guard let metadata = fileProviderUtility.sharedInstance.getTableMetadataFromItemIdentifier(identifier) else {
                throw NSFileProviderError(.noSuchItem)
            }
            
            guard let parentItemIdentifier = fileProviderUtility.sharedInstance.getParentItemIdentifier(metadata: metadata, homeServerUrl: fileProviderData.sharedInstance.homeServerUrl) else {
                throw NSFileProviderError(.noSuchItem)
            }
            
            let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
            return item
        }
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
            
        guard let metadata = fileProviderUtility.sharedInstance.getTableMetadataFromItemIdentifier(identifier) else {
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
        if metadata.fileID == CCUtility.createMetadataID(fromAccount: metadata.account, serverUrl: metadata.serverUrl, fileNameView: metadata.fileNameView, directory: false)! {
            completionHandler(nil)
            return
        }
            
        let tableLocalFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "fileID == %@", metadata.fileID))
        if tableLocalFile != nil && CCUtility.fileProviderStorageExists(metadata.fileID, fileNameView: metadata.fileNameView) {
            completionHandler(nil)
            return
        }
        
        let task = OCNetworking.sharedManager().download(withAccount: metadata.account, fileNameServerUrl: metadata.serverUrl + "/" + metadata.fileName, fileNameLocalPath: url.path, encode: true, communication: OCNetworking.sharedManager()?.sharedOCCommunicationExtensionDownload(), completion: { (account, lenght, etag, date, message, errorCode) in
            
            if errorCode == 0 && account == metadata.account {

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
                
            } else {
                
                // remove task
                self.outstandingDownloadTasks.removeValue(forKey: url)
                
                if errorCode == Int(CFNetworkErrors.cfurlErrorCancelled.rawValue) {
                    completionHandler(NSFileProviderError(.noSuchItem))
                } else {
                    completionHandler(NSFileProviderError(.serverUnreachable))
                }
                return
            }
            
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
                _ = try fileProviderUtility.sharedInstance.fileManager.removeItem(at: url)
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
