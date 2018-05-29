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

// Timer for Upload (queue)
var timerUpload: Timer?

// Item for signalEnumerator
var fileProviderSignalDeleteItemIdentifier = [NSFileProviderItemIdentifier:NSFileProviderItemIdentifier]()
var fileProviderSignalUpdateItem = [NSFileProviderItemIdentifier:FileProviderItem]()

// Rank favorite
var listFavoriteIdentifierRank = [String:NSNumber]()

var currentAnchor: UInt64 = 0
var fileNamePathImport = [String]()

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
    
    var fileManager = FileManager()
    var providerData = FileProviderData()

    var outstandingDownloadTasks = [URL: URLSessionTask]()

    // Metadata Temp for Import
    let FILEID_IMPORT_METADATA_TEMP = k_uploadSessionID + "FILE_PROVIDER_EXTENSION"
    
    override init() {
        
        super.init()
        
        _ = providerData.setupActiveAccount()
        
        verifyUploadQueueInLock()
        
        if #available(iOSApplicationExtension 11.0, *) {
                        
            // Timer for upload
            if timerUpload == nil {
                
                timerUpload = Timer.init(timeInterval: TimeInterval(k_timerProcessAutoDownloadUpload), repeats: true, block: { (Timer) in
                    
                    // new upload
                    self.uploadFile()
                })
                
                RunLoop.main.add(timerUpload!, forMode: .defaultRunLoopMode)
            }
            
        } else {
            
            NSFileCoordinator().coordinate(writingItemAt: self.documentStorageURL, options: [], error: nil, byAccessor: { newURL in
                do {
                    try fileManager.createDirectory(at: newURL, withIntermediateDirectories: true, attributes: nil)
                } catch let error {
                    print("error: \(error)")
                }
            })
        }
    }
    
    // MARK: - Enumeration
    
    override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else { throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError, userInfo:[:]) }
        
        // update workingset
        self.updateWorkingSet()
        
        var maybeEnumerator: NSFileProviderEnumerator? = nil

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
    
    // Convinent method to signal the enumeration for containers.
    //
    func signalEnumerator(for containerItemIdentifiers: [NSFileProviderItemIdentifier]) {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else { return }
        
        currentAnchor += 1

        for containerItemIdentifier in containerItemIdentifiers {
            
            NSFileProviderManager.default.signalEnumerator(for: containerItemIdentifier) { error in
                if let error = error {
                    print("SignalEnumerator for \(containerItemIdentifier) returned error: \(error)")
                }
            }
        }
    }
    
    // MARK: - WorkingSet
    
    func updateWorkingSet() {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else { return }
        
        var updateItemsWorkingSet = [NSFileProviderItemIdentifier:FileProviderItem]()
        
        // ***** Tags *****

        // ***** Favorite *****
        
        listFavoriteIdentifierRank = NCManageDatabase.sharedInstance.getTableMetadatasDirectoryFavoriteIdentifierRank()

        // (ADD)
        for (identifier, _) in listFavoriteIdentifierRank {
            
            guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileID = %@", providerData.account, identifier)) else {
                continue
            }
            
            guard let parentItemIdentifier = providerData.getParentItemIdentifier(metadata: metadata) else {
                continue
            }
            
            let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier, providerData: providerData)
        
            updateItemsWorkingSet[item.itemIdentifier] = item
        }
        // (REMOVE)
        let metadatas = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account = %@ AND directory = true AND favorite = false", providerData.account), sorted: "fileName", ascending: true)
        if (metadatas != nil && metadatas!.count > 0) {
            for metadata in metadatas! {
                guard let parentItemIdentifier = providerData.getParentItemIdentifier(metadata: metadata) else {
                    continue
                }
                
                let itemIdentifier = providerData.getItemIdentifier(metadata: metadata)
                listFavoriteIdentifierRank.removeValue(forKey: itemIdentifier.rawValue)
                let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier, providerData: providerData)
                
                updateItemsWorkingSet[item.itemIdentifier] = item
            }
        }
        
        // Update workingSet
        for (itemIdentifier, item) in updateItemsWorkingSet {
            fileProviderSignalUpdateItem[itemIdentifier] = item
            self.signalEnumerator(for: [.workingSet])
        }
    }
    
    // MARK: - Item

    override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else { throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError, userInfo:[:]) }
        
        if identifier == .rootContainer {
            
            if let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account = %@ AND serverUrl = %@", providerData.account, providerData.homeServerUrl)) {
                    
                let metadata = tableMetadata()
                    
                metadata.account = providerData.account
                metadata.directory = true
                metadata.directoryID = directory.directoryID
                metadata.fileID = NSFileProviderItemIdentifier.rootContainer.rawValue
                metadata.fileName = NCBrandOptions.sharedInstance.brand
                metadata.fileNameView = NCBrandOptions.sharedInstance.brand
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
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else { return nil }
            
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
        
        if #available(iOSApplicationExtension 11.0, *) {

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
            
        } else {
            
            let fileName = url.lastPathComponent
            let placeholderURL = NSFileProviderExtension.placeholderURL(for: self.documentStorageURL.appendingPathComponent(fileName))
            let fileSize = 0
            let metadata = [AnyHashable(URLResourceKey.fileSizeKey): fileSize]
            do {
                try NSFileProviderExtension.writePlaceholder(at: placeholderURL, withMetadata: metadata as! [URLResourceKey : Any])
            } catch let error {
                print("error: \(error)")
            }
            completionHandler(nil)
        }
    }

    override func startProvidingItem(at url: URL, completionHandler: @escaping ((_ error: Error?) -> Void)) {
        
        if #available(iOSApplicationExtension 11.0, *) {

            let pathComponents = url.pathComponents
            let identifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
            var fileSize = 0 as Double
            var localEtag = ""
            var localEtagFPE = ""
            
            // Check account
            if providerData.setupActiveAccount() == false {
                completionHandler(NSFileProviderError(.notAuthenticated))
                return
            }
            
            guard let metadata = providerData.getTableMetadataFromItemIdentifier(identifier) else {
                completionHandler(NSFileProviderError(.noSuchItem))
                return
            }
            
            // Upload ?
            if metadata.fileID.contains(k_uploadSessionID) {
                completionHandler(nil)
                return
            }
            
            let tableLocalFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "account = %@ AND fileID = %@", providerData.account, metadata.fileID))
            if tableLocalFile != nil {
                localEtag = tableLocalFile!.etag
                localEtagFPE = tableLocalFile!.etagFPE
            }
            
            if (localEtagFPE != "") {
                
                // Verify last version on "Local Table"
                if localEtag != localEtagFPE {
                    if self.copyFile(providerData.directoryUser+"/"+metadata.fileID, toPath: url.path) == nil {
                        NCManageDatabase.sharedInstance.setLocalFile(fileID: metadata.fileID, date: nil, exifDate: nil, exifLatitude: nil, exifLongitude: nil, fileName: nil, etag: nil, etagFPE: localEtag)
                    }
                }
                
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: url.path)
                    fileSize = attributes[FileAttributeKey.size] as! Double
                } catch let error {
                    print("error: \(error)")
                }
                
                if (fileSize > 0) {
                    completionHandler(nil)
                    return
                }
            }
            
            guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
                completionHandler(NSFileProviderError(.noSuchItem))
                return
            }
            
            // delete prev file + ico on Directory User
            _ = self.deleteFile("\(providerData.directoryUser)/\(metadata.fileID)")
            _ = self.deleteFile("\(providerData.directoryUser)/\(metadata.fileID).ico")

            let ocNetworking = OCnetworking.init(delegate: nil, metadataNet: nil, withUser: providerData.accountUser, withUserID: providerData.accountUserID, withPassword: providerData.accountPassword, withUrl: providerData.accountUrl)
            let task = ocNetworking?.downloadFileNameServerUrl("\(serverUrl)/\(metadata.fileName)", fileNameLocalPath: "\(providerData.directoryUser)/\(metadata.fileID)", communication: CCNetworking.shared().sharedOCCommunicationExtensionDownload(metadata.fileName), success: { (lenght, etag, date) in
                
                // remove Task
                self.outstandingDownloadTasks.removeValue(forKey: url)

                // copy download file to url
                _ = self.copyFile("\(self.providerData.directoryUser)/\(metadata.fileID)", toPath: url.path)
            
                // update DB Local
                metadata.date = date! as NSDate
                metadata.etag = etag!
                NCManageDatabase.sharedInstance.addLocalFile(metadata: metadata)
                NCManageDatabase.sharedInstance.setLocalFile(fileID: metadata.fileID, date: date! as NSDate, exifDate: nil, exifLatitude: nil, exifLongitude: nil, fileName: nil, etag: etag, etagFPE: etag)
                
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
                
        } else {
            
            guard let fileData = try? Data(contentsOf: url) else {
                completionHandler(nil)
                return
            }
            do {
                _ = try fileData.write(to: url, options: NSData.WritingOptions())
                completionHandler(nil)
            } catch let error {
                print("error: \(error)")
                completionHandler(error)
            }
        }
    }
    
    override func itemChanged(at url: URL) {
        
        if #available(iOSApplicationExtension 11.0, *) {
            
            let fileName = url.lastPathComponent
            let pathComponents = url.pathComponents
            let metadataNet = CCMetadataNet()

            assert(pathComponents.count > 2)
            let identifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
            
            guard let metadata = providerData.getTableMetadataFromItemIdentifier(identifier) else {
                return
            }
            
            guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
                return
            }
            
            metadataNet.account = providerData.account
            metadataNet.assetLocalIdentifier = FILEID_IMPORT_METADATA_TEMP + metadata.directoryID + fileName
            metadataNet.fileName = fileName
            metadataNet.path = url.path
            metadataNet.selector = selectorUploadFile
            metadataNet.selectorPost = ""
            metadataNet.serverUrl = serverUrl
            metadataNet.session = k_upload_session_extension
            metadataNet.sessionError = ""
            metadataNet.sessionID = ""
            metadataNet.taskStatus = Int(k_taskStatusResume)
                
            _ = NCManageDatabase.sharedInstance.addQueueUpload(metadataNet: metadataNet)
            
            self.uploadFile()
            
        } else {
            
            let fileSize = (try! fileManager.attributesOfItem(atPath: url.path)[FileAttributeKey.size] as! NSNumber).uint64Value
            NSLog("[LOG] Item changed at URL %@ %lu", url as NSURL, fileSize)
            
            guard let account = NCManageDatabase.sharedInstance.getAccountActive() else {
                self.stopProvidingItem(at: url)
                return
            }
            guard let fileName = CCUtility.getFileNameExt() else {
                self.stopProvidingItem(at: url)
                return
            }
            // -------> Fix : Clear FileName for twice Office 365
            CCUtility.setFileNameExt("")
            // --------------------------------------------------
            if (fileName != url.lastPathComponent) {
                self.stopProvidingItem(at: url)
                return
            }
            guard let serverUrl = CCUtility.getServerUrlExt() else {
                self.stopProvidingItem(at: url)
                return
            }
            guard let directoryID = NCManageDatabase.sharedInstance.getDirectoryID(serverUrl) else {
                self.stopProvidingItem(at: url)
                return
            }
            
            let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "fileName == %@ AND directoryID == %@", fileName, directoryID))
            if metadata != nil {
                
                // Update
                let uploadID = k_uploadSessionID + CCUtility.createRandomString(16)
                let directoryUser = CCUtility.getDirectoryActiveUser(account.user, activeUrl: account.url)
                let destinationDirectoryUser = "\(directoryUser!)/\(uploadID)"
                
                // copy sourceURL on directoryUser
                _ = self.copyFile(url.path, toPath: destinationDirectoryUser)
                
                // Prepare for send Metadata
                metadata!.sessionID = uploadID
                metadata!.session = k_upload_session
                metadata!.sessionTaskIdentifier = Int(k_taskIdentifierWaitStart)
                _ = NCManageDatabase.sharedInstance.updateMetadata(metadata!)
                
            } else {
                
                // New
                let directoryUser = CCUtility.getDirectoryActiveUser(account.user, activeUrl: account.url)
                let destinationDirectoryUser = "\(directoryUser!)/\(fileName)"
                
                _ = self.copyFile(url.path, toPath: destinationDirectoryUser)

                CCNetworking.shared().uploadFile(fileName, serverUrl: serverUrl, assetLocalIdentifier: nil, session: k_upload_session, taskStatus: Int(k_taskStatusResume), selector: nil, selectorPost: nil, errorCode: 0, delegate: self)
            }

            self.stopProvidingItem(at: url)
        }
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
                _ = try fileManager.removeItem(at: url)
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
    
    // --------------------------------------------------------------------------------------------
    //  MARK: - User Function
    // --------------------------------------------------------------------------------------------
    
    func copyFile(_ atPath: String, toPath: String) -> Error? {
        
        var errorResult: Error?
        
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
    
    func createFileName(_ fileName: String, directoryID: String, serverUrl: String) -> String {
    
        let serialQueue = DispatchQueue(label: "queueCreateFileName")
        var resultFileName = fileName

        serialQueue.sync {
            
            var exitLoop = false
            
            while exitLoop == false {
                
                if NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileNameView = %@ AND directoryID = %@", providerData.account, resultFileName, directoryID)) != nil || fileNamePathImport.contains(serverUrl+"/"+resultFileName) {
                    
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
        
            // add fileNamePathImport
            fileNamePathImport.append(serverUrl+"/"+resultFileName)
        }
        
        return resultFileName
    }
}
