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
import UIKit
import MobileCoreServices

var ocNetworking: OCnetworking?
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

// List
var listUpdateItems = [NSFileProviderItem]()
var listFavoriteIdentifierRank = [String:NSNumber]()
var fileNamePathImport = [String]()

// Metadata Temp for Import
let FILEID_IMPORT_METADATA_TEMP = k_uploadSessionID + "FILE_PROVIDER_EXTENSION"

// Timer for Upload (queue)
var timerUpload: Timer?


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



class FileProvider: NSFileProviderExtension, CCNetworkingDelegate {
    
    var fileManager = FileManager()

    override init() {
        
        super.init()
        
        setupActiveAccount()
        
        verifyUploadQueueInLock()
        
        if #available(iOSApplicationExtension 11.0, *) {
            
            listFavoriteIdentifierRank = NCManageDatabase.sharedInstance.getTableMetadatasDirectoryFavoriteIdentifierRank()
            
            // Timer for upload
            if timerUpload == nil {
                
                timerUpload = Timer.init(timeInterval: TimeInterval(k_timerProcessAutoDownloadUpload), repeats: true, block: { (Timer) in
                    
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
        guard #available(iOS 11, *) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError, userInfo:[:])
        }
        
        var maybeEnumerator: NSFileProviderEnumerator? = nil

        if (containerItemIdentifier == NSFileProviderItemIdentifier.rootContainer) {
            maybeEnumerator = FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier)
        } else if (containerItemIdentifier == NSFileProviderItemIdentifier.workingSet) {
            maybeEnumerator = FileProviderEnumeratorWorkingSet(enumeratedItemIdentifier: containerItemIdentifier)
        } else {
            // determine if the item is a directory or a file
            // - for a directory, instantiate an enumerator of its subitems
            // - for a file, instantiate an enumerator that observes changes to the file
            let item = try self.item(for: containerItemIdentifier)
            
            if item.typeIdentifier == kUTTypeFolder as String {
                maybeEnumerator = FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier)
            } else {
                maybeEnumerator = FileProviderEnumeratorFile(enumeratedItemIdentifier: containerItemIdentifier)
            }
        }
        
        guard let enumerator = maybeEnumerator else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:])
        }
       
        return enumerator
    }
    
    // MARK: - Item

    override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError, userInfo:[:])
        }

        if identifier == .rootContainer {
            
            if let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account = %@ AND serverUrl = %@", account, homeServerUrl)) {
                    
                let metadata = tableMetadata()
                    
                metadata.account = account
                metadata.directory = true
                metadata.directoryID = directory.directoryID
                metadata.fileID = NSFileProviderItemIdentifier.rootContainer.rawValue
                metadata.fileName = NCBrandOptions.sharedInstance.brand
                metadata.fileNameView = NCBrandOptions.sharedInstance.brand
                metadata.typeFile = k_metadataTypeFile_directory
                    
                return FileProviderItem(metadata: metadata, parentItemIdentifier: NSFileProviderItemIdentifier(NSFileProviderItemIdentifier.rootContainer.rawValue))
            }
            
        } else {
            
            let metadata = getTableMetadataFromItemIdentifier(identifier)
            if  metadata != nil {
                let parentItemIdentifier = getParentItemIdentifier(metadata: metadata!)
                if parentItemIdentifier != nil {
                    let item = FileProviderItem(metadata: metadata!, parentItemIdentifier: parentItemIdentifier!)
                    return item
                }
            }
        }
        
        // implement the actual lookup
        throw NSFileProviderError(.noSuchItem)
    }
    
    override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else {
            return nil
        }
            
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
    
    // MARK: - Managing Shared Files
    
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
            
            guard let metadata = getTableMetadataFromItemIdentifier(identifier) else {
                completionHandler(NSFileProviderError(.noSuchItem))
                return
            }
            
            // Upload ?
            if metadata.fileID.contains(k_uploadSessionID) {
                completionHandler(nil)
                return
            }
            
            let tableLocalFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "account = %@ AND fileID = %@", account, metadata.fileID))
            if tableLocalFile != nil {
                localEtag = tableLocalFile!.etag
                localEtagFPE = tableLocalFile!.etagFPE
            }
            
            if (localEtagFPE != "") {
                
                // Verify last version on "Local Table"
                if localEtag != localEtagFPE {
                    if self.copyFile(directoryUser+"/"+metadata.fileID, toPath: url.path) == nil {
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
            _ = self.deleteFile("\(directoryUser)/\(metadata.fileID)")
            _ = self.deleteFile("\(directoryUser)/\(metadata.fileID).ico")

            let task = ocNetworking?.downloadFileNameServerUrl("\(serverUrl)/\(metadata.fileName)", fileNameLocalPath: "\(directoryUser)/\(metadata.fileID)", communication: CCNetworking.shared().sharedOCCommunicationExtensionDownload(metadata.fileName), success: { (lenght, etag, date) in
                
                // copy download file to url
                _ = self.copyFile("\(directoryUser)/\(metadata.fileID)", toPath: url.path)
            
                // update DB Local
                metadata.date = date! as NSDate
                metadata.etag = etag!
                NCManageDatabase.sharedInstance.addLocalFile(metadata: metadata)
                NCManageDatabase.sharedInstance.setLocalFile(fileID: metadata.fileID, date: date! as NSDate, exifDate: nil, exifLatitude: nil, exifLongitude: nil, fileName: nil, etag: etag, etagFPE: etag)
                
                // Update DB Metadata
                _ = NCManageDatabase.sharedInstance.addMetadata(metadata)

                completionHandler(nil)
                    
            }, failure: { (errorMessage, errorCode) in
                completionHandler(NSFileProviderError(.serverUnreachable))
            })
                
            if task != nil {
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
            
            guard let metadata = getTableMetadataFromItemIdentifier(identifier) else {
                return
            }
            
            guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
                return
            }
            
            metadataNet.account = account
            metadataNet.assetLocalIdentifier = FILEID_IMPORT_METADATA_TEMP + metadata.directoryID + fileName
            metadataNet.fileName = fileName
            metadataNet.path = url.path
            metadataNet.selector = selectorUploadFile
            metadataNet.selectorPost = ""
            metadataNet.serverUrl = serverUrl
            metadataNet.session = k_upload_session_extension
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
    }
    
    // MARK: - Accessing Thumbnails
    
    override func fetchThumbnails(for itemIdentifiers: [NSFileProviderItemIdentifier], requestedSize size: CGSize, perThumbnailCompletionHandler: @escaping (NSFileProviderItemIdentifier, Data?, Error?) -> Void, completionHandler: @escaping (Error?) -> Void) -> Progress {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else {
            return Progress(totalUnitCount:0)
        }

        let progress = Progress(totalUnitCount: Int64(itemIdentifiers.count))
        var counterProgress: Int64 = 0
            
        for itemIdentifier in itemIdentifiers {
            
            let metadata = getTableMetadataFromItemIdentifier(itemIdentifier)
            if metadata != nil {
                    
                if (metadata!.typeFile == k_metadataTypeFile_image || metadata!.typeFile == k_metadataTypeFile_video) {
                        
                    let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata!.directoryID)
                    let fileName = CCUtility.returnFileNamePath(fromFileName: metadata!.fileName, serverUrl: serverUrl, activeUrl: accountUrl)
                    let fileNameLocal = metadata!.fileID

                    ocNetworking?.downloadThumbnail(withDimOfThumbnail: "m", fileName: fileName, fileNameLocal: fileNameLocal, success: {

                        do {
                            let url = URL.init(fileURLWithPath: directoryUser+"/"+metadata!.fileID+".ico")
                            let data = try Data.init(contentsOf: url)
                            perThumbnailCompletionHandler(itemIdentifier, data, nil)
                        } catch let error {
                            print("error: \(error)")
                            perThumbnailCompletionHandler(itemIdentifier, nil, NSFileProviderError(.noSuchItem))
                        }
                            
                        counterProgress += 1
                        if (counterProgress == progress.totalUnitCount) {
                            completionHandler(nil)
                        }
                            
                    }, failure: { (errorMessage, errorCode) in

                        perThumbnailCompletionHandler(itemIdentifier, nil, NSFileProviderError(.serverUnreachable))
                            
                        counterProgress += 1
                        if (counterProgress == progress.totalUnitCount) {
                            completionHandler(nil)
                        }
                    })
                        
                } else {
                        
                    counterProgress += 1
                    if (counterProgress == progress.totalUnitCount) {
                        completionHandler(nil)
                    }
                }
            } else {
                counterProgress += 1
                if (counterProgress == progress.totalUnitCount) {
                    completionHandler(nil)
                }
            }
        }
        
        return progress
    }
    
    // MARK: - Actions

    override func createDirectory(withName directoryName: String, inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {

        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else {
            return
        }
        
        guard let tableDirectory = getTableDirectoryFromParentItemIdentifier(parentItemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        let serverUrl = tableDirectory.serverUrl
        
        ocNetworking?.createFolder(directoryName, serverUrl: serverUrl, account: account, success: { (fileID, date) in
    
            let metadata = tableMetadata()
                
            metadata.account = account
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
            
            let parentItemIdentifier = getParentItemIdentifier(metadata: metadataDB)
            if parentItemIdentifier != nil {
                let item = FileProviderItem(metadata: metadataDB, parentItemIdentifier: parentItemIdentifier!)
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
        guard #available(iOS 11, *) else {
            return
        }
        
        DispatchQueue.main.async {
            
            guard let metadata = getTableMetadataFromItemIdentifier(itemIdentifier) else {
                completionHandler(nil)
                return
            }
            
            guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
                completionHandler(nil)
                return
            }
            
            ocNetworking?.deleteFileOrFolder(metadata.fileName, serverUrl: serverUrl, success: {
                
                let fileNamePath = directoryUser + "/" + metadata.fileID
                do {
                    try self.fileManager.removeItem(atPath: fileNamePath)
                } catch let error {
                    print("error: \(error)")
                }
                do {
                    try self.fileManager.removeItem(atPath: fileNamePath + ".ico")
                } catch let error {
                    print("error: \(error)")
                }
                do {
                    try self.fileManager.removeItem(atPath: fileProviderStorageURL!.path + "/" + itemIdentifier.rawValue)
                } catch let error {
                    print("error: \(error)")
                }
                
                if metadata.directory {
                    let dirForDelete = CCUtility.stringAppendServerUrl(serverUrl, addFileName: metadata.fileName)
                    NCManageDatabase.sharedInstance.deleteDirectoryAndSubDirectory(serverUrl: dirForDelete!)
                }
                
                NCManageDatabase.sharedInstance.deleteLocalFile(predicate: NSPredicate(format: "fileID == %@", metadata.fileID))
                NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "fileID == %@", metadata.fileID), clearDateReadDirectoryID: nil)
                
                completionHandler(nil)
                
            }, failure: { (errorMessage, errorCode) in
                
                if errorCode == 404 {
                    completionHandler(nil)
                } else {
                    completionHandler(NSFileProviderError(.serverUnreachable))
                }
            })
        }
    }
    
    override func reparentItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, newName: String?, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else {
            return
        }
        
        guard let itemFrom = try? item(for: itemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        guard let metadataFrom = getTableMetadataFromItemIdentifier(itemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        let fileIDFrom = metadataFrom.fileID
        
        guard let serverUrlFrom = NCManageDatabase.sharedInstance.getServerUrl(metadataFrom.directoryID) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        let fileNameFrom = serverUrlFrom + "/" + itemFrom.filename

        guard let tableDirectoryTo = getTableDirectoryFromParentItemIdentifier(parentItemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        let serverUrlTo = tableDirectoryTo.serverUrl
        let directoryIDTo = NCManageDatabase.sharedInstance.getDirectoryID(serverUrlTo)!
        let fileNameTo = serverUrlTo + "/" + itemFrom.filename
    
        ocNetworking?.moveFileOrFolder(fileNameFrom, fileNameTo: fileNameTo, success: {
            
            if metadataFrom.directory {
                
                NCManageDatabase.sharedInstance.deleteDirectoryAndSubDirectory(serverUrl: serverUrlFrom)
                NCManageDatabase.sharedInstance.moveMetadata(fileName: metadataFrom.fileName, directoryID: metadataFrom.directoryID, directoryIDTo: directoryIDTo)
                _ = NCManageDatabase.sharedInstance.addDirectory(encrypted: false, favorite: false, fileID: nil, permissions: nil, serverUrl: serverUrlTo)
                
            } else {
                NCManageDatabase.sharedInstance.moveMetadata(fileName: metadataFrom.fileName, directoryID: metadataFrom.directoryID, directoryIDTo: directoryIDTo)
            }
            
            guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileID = %@", account, fileIDFrom)) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            
            let parentItemIdentifier = getParentItemIdentifier(metadata: metadata)
            if parentItemIdentifier != nil {
                let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier!)
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
        guard #available(iOS 11, *) else {
            return
        }
        
        guard let metadata = getTableMetadataFromItemIdentifier(itemIdentifier) else {
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
        
        ocNetworking?.moveFileOrFolder(fileNamePathFrom, fileNameTo: fileNamePathTo, success: {
            
            metadata.fileName = itemName
            metadata.fileNameView = itemName
            
            guard let metadata = NCManageDatabase.sharedInstance.addMetadata(metadata) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            
            if metadata.directory {
                
                NCManageDatabase.sharedInstance.setDirectory(serverUrl: fileNamePathFrom, serverUrlTo: fileNamePathTo, etag: nil, fileID: nil, encrypted: directoryTable.e2eEncrypted)

            } else {
                
                let itemIdentifier = getItemIdentifier(metadata: metadata)
                
                _ = self.moveFile(fileProviderStorageURL!.path + "/" + itemIdentifier.rawValue + "/" + fileNameFrom, toPath: fileProviderStorageURL!.path + "/" + itemIdentifier.rawValue + "/" + itemName)
                
                NCManageDatabase.sharedInstance.setLocalFile(fileID: metadata.fileID, date: nil, exifDate: nil, exifLatitude: nil, exifLongitude: nil, fileName: itemName, etag: nil, etagFPE: nil)
            }
            
            let parentItemIdentifier = getParentItemIdentifier(metadata: metadata)
            if parentItemIdentifier != nil {
                let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier!)
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
        guard #available(iOS 11, *) else {
            return
        }
        
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
    
    override func setLastUsedDate(_ lastUsedDate: Date?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        print("[LOG] setLastUsedDate")
        completionHandler(nil, nil)
    }
    
    override func setTagData(_ tagData: Data?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else {
            return
        }
        
        guard let metadata = getTableMetadataFromItemIdentifier(itemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
       
        // Add, Remove (nil)
        NCManageDatabase.sharedInstance.addTag(metadata.fileID, tagIOS: tagData)
        
        let parentItemIdentifier = getParentItemIdentifier(metadata: metadata)
        if parentItemIdentifier != nil {
            let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier!)
            completionHandler(item, nil)
        } else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
        }
        
        NSFileProviderManager.default.signalEnumerator(for: .workingSet, completionHandler: { (error) in
            print("send signal workingSet")
        })
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
        guard #available(iOS 11, *) else {
            return
        }
        
        var size = 0 as Double
        let metadata = tableMetadata()
        let fileCoordinator = NSFileCoordinator()
        var error: NSError?
        
        DispatchQueue.main.async {
            
            guard let tableDirectory = getTableDirectoryFromParentItemIdentifier(parentItemIdentifier) else {
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
            let fileNamePathDirectory = fileProviderStorageURL!.path + "/" + FILEID_IMPORT_METADATA_TEMP + tableDirectory.directoryID + fileName
            
            do {
                try FileManager.default.createDirectory(atPath: fileNamePathDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch  { }
            
            fileCoordinator.coordinate(readingItemAt: fileURL, options: NSFileCoordinator.ReadingOptions.withoutChanges, error: &error) { (url) in
                _ = self.moveFile(url.path, toPath: fileNamePathDirectory + "/" + fileName)

            }
            
            fileURL.stopAccessingSecurityScopedResource()
            
            // ---------------------------------------------------------------------------------
            
            do {
                let attributes = try self.fileManager.attributesOfItem(atPath: fileNamePathDirectory + "/" + fileName)
                size = attributes[FileAttributeKey.size] as! Double
            } catch let error {
                print("error: \(error)")
            }
            
            // Metadata TEMP
            metadata.account = account
            metadata.date = NSDate()
            metadata.directory = false
            metadata.directoryID = tableDirectory.directoryID
            metadata.etag = ""
            metadata.fileID = FILEID_IMPORT_METADATA_TEMP + tableDirectory.directoryID + fileName
            metadata.size = size
            metadata.status = Double(k_metadataStatusHide)
            metadata.fileName = fileURL.lastPathComponent
            metadata.fileNameView = fileURL.lastPathComponent
            CCUtility.insertTypeFileIconName(fileName, metadata: metadata)
            
            if (size > 0) {
                
                let metadataNet = CCMetadataNet()
                
                metadataNet.account = account
                metadataNet.assetLocalIdentifier = FILEID_IMPORT_METADATA_TEMP + tableDirectory.directoryID + fileName
                metadataNet.fileName = fileName
                metadataNet.path = fileNamePathDirectory + "/" + fileName
                metadataNet.selector = selectorUploadFile
                metadataNet.selectorPost = ""
                metadataNet.serverUrl = serverUrl
                metadataNet.session = k_upload_session_extension
                metadataNet.taskStatus = Int(k_taskStatusResume)
                
                _ = NCManageDatabase.sharedInstance.addQueueUpload(metadataNet: metadataNet)
            }
            
            guard let metadataDB = NCManageDatabase.sharedInstance.addMetadata(metadata) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            
            let item = FileProviderItem(metadata: metadataDB, parentItemIdentifier: parentItemIdentifier)
            completionHandler(item, nil)
        }
    }
    
    // --------------------------------------------------------------------------------------------
    //  MARK: - Upload
    // --------------------------------------------------------------------------------------------
    
    func uploadFileSuccessFailure(_ fileName: String!, fileID: String!, assetLocalIdentifier: String!, serverUrl: String!, selector: String!, selectorPost: String!, errorMessage: String!, errorCode: Int) {
        
        NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "fileID = %@", assetLocalIdentifier), clearDateReadDirectoryID: nil)

        if errorCode == 0 {
                
            NCManageDatabase.sharedInstance.deleteQueueUpload(assetLocalIdentifier: assetLocalIdentifier, selector: selector)
            
            if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileID = %@", account, fileID)) {
                
                // Rename directory file
                if fileManager.fileExists(atPath: fileProviderStorageURL!.path + "/" + assetLocalIdentifier) {
                    let itemIdentifier = getItemIdentifier(metadata: metadata)
                    _ = moveFile(fileProviderStorageURL!.path + "/" + assetLocalIdentifier, toPath: fileProviderStorageURL!.path + "/" + itemIdentifier.rawValue)
                }
                
                NCManageDatabase.sharedInstance.setLocalFile(fileID: fileID, date: nil, exifDate: nil, exifLatitude: nil, exifLongitude: nil, fileName: nil, etag: metadata.etag, etagFPE: metadata.etag)
                
                let parentItemIdentifier = getParentItemIdentifier(metadata: metadata)
                if parentItemIdentifier != nil {
                    let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier!)
                    self.refreshEnumerator(identifier: item.itemIdentifier, serverUrl: serverUrl)
                } 
            }
            
        } else {
                
            NCManageDatabase.sharedInstance.unlockQueueUpload(assetLocalIdentifier: assetLocalIdentifier)
        }
        
        uploadFile()
    }
    
    func uploadFile() {
        
        let queueInLock = NCManageDatabase.sharedInstance.getQueueUploadInLock()
        if queueInLock != nil && queueInLock!.count == 0 {
            
            let metadataNetQueue = NCManageDatabase.sharedInstance.lockQueueUpload(selector: selectorUploadFile, withPath: true)
            if  metadataNetQueue != nil {
                
                if self.copyFile(metadataNetQueue!.path, toPath: directoryUser + "/" + metadataNetQueue!.fileName) == nil {
                    
                    CCNetworking.shared().uploadFile(metadataNetQueue!.fileName, serverUrl: metadataNetQueue!.serverUrl, assetLocalIdentifier: metadataNetQueue!.assetLocalIdentifier ,session: metadataNetQueue!.session, taskStatus: metadataNetQueue!.taskStatus, selector: metadataNetQueue!.selector, selectorPost: metadataNetQueue!.selectorPost, errorCode: 0, delegate: self)
                    
                } else {
                    // file not present, delete record Upload Queue
                    NCManageDatabase.sharedInstance.deleteQueueUpload(path: metadataNetQueue!.path)
                }
            }
        }
    }
    
    func verifyUploadQueueInLock() {
        
        let tasks = CCNetworking.shared().getUploadTasksExtensionSession()
        if tasks!.count == 0 {
            let records = NCManageDatabase.sharedInstance.getQueueUpload(predicate: NSPredicate(format: "account = %@ AND selector = %@ AND lock == true AND path != nil", account, selectorUploadFile))
            if records != nil && records!.count > 0 {
                NCManageDatabase.sharedInstance.unlockAllQueueUploadWithPath()
            }
        }
    }
    
    // --------------------------------------------------------------------------------------------
    //  MARK: - User Function
    // --------------------------------------------------------------------------------------------
    
    func refreshEnumerator(identifier: NSFileProviderItemIdentifier, serverUrl: String) {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else {
            return
        }
        
        let item = try? self.item(for: identifier)
        if item != nil {
            var found = false
            for updateItem in listUpdateItems {
                if updateItem.itemIdentifier.rawValue == identifier.rawValue {
                    found = true
                }
            }
            if !found {
                listUpdateItems.append(item!)
            }
        }
        
        if serverUrl == homeServerUrl {
            NSFileProviderManager.default.signalEnumerator(for: .rootContainer, completionHandler: { (error) in
                print("send signal rootContainer")
            })
        } else {
            if let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account = %@ AND serverUrl = %@", account, serverUrl)) {
                if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileID = %@", account, directory.fileID)) {
                    let itemIdentifier = getItemIdentifier(metadata: metadata)
                    NSFileProviderManager.default.signalEnumerator(for: itemIdentifier, completionHandler: { (error) in
                        print("send signal")
                    })
                }
            }
        }
    }
    
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
                
                if NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileNameView = %@ AND directoryID = %@", account, resultFileName, directoryID)) != nil || fileNamePathImport.contains(serverUrl+"/"+resultFileName) {
                    
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

// --------------------------------------------------------------------------------------------
//  MARK: -
// --------------------------------------------------------------------------------------------

func setupActiveAccount() {
    
    guard let activeAccount = NCManageDatabase.sharedInstance.getAccountActive() else {
        return
    }
    
    account = activeAccount.account
    accountUser = activeAccount.user
    accountUserID = activeAccount.userID
    accountPassword = activeAccount.password
    accountUrl = activeAccount.url
    homeServerUrl = CCUtility.getHomeServerUrlActiveUrl(activeAccount.url)
    directoryUser = CCUtility.getDirectoryActiveUser(activeAccount.user, activeUrl: activeAccount.url)
    
    ocNetworking = OCnetworking.init(delegate: nil, metadataNet: nil, withUser: accountUser, withUserID: accountUserID, withPassword: accountPassword, withUrl: accountUrl)
    
    groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.sharedInstance.capabilitiesGroups)
    fileProviderStorageURL = groupURL!.appendingPathComponent(k_assetLocalIdentifierFileProviderStorage)
    
    // Create dir File Provider Storage
    do {
        try FileManager.default.createDirectory(atPath: fileProviderStorageURL!.path, withIntermediateDirectories: true, attributes: nil)
    } catch let error as NSError {
        NSLog("Unable to create directory \(error.debugDescription)")
    }
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
    guard #available(iOS 11, *) else {
         return NSFileProviderItemIdentifier("")
    }
    
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
    guard #available(iOS 11, *) else {
        return nil
    }
    
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
    

