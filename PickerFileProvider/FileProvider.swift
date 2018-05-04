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
var importDocumentURL: URL?
var changeDocumentURL: URL?

// List
var listUpdateItems = [NSFileProviderItem]()
var listFavoriteIdentifierRank = [String:NSNumber]()

class FileProvider: NSFileProviderExtension {
    
    var listUpload = [String:URLSessionTask]()
    
    override init() {
        
        super.init()
        
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
        importDocumentURL = groupURL!.appendingPathComponent(k_assetLocalIdentifierFileProviderStorage).appendingPathComponent(k_fileProviderStorageImportDocument)
        changeDocumentURL = groupURL!.appendingPathComponent(k_assetLocalIdentifierFileProviderStorage).appendingPathComponent(k_fileProviderStorageChangeDocument)

        // Create dir File Provider Storage
        do {
            try FileManager.default.createDirectory(atPath: fileProviderStorageURL!.path, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            NSLog("Unable to create directory \(error.debugDescription)")
        }
        
        // Create dir for Upload
        do {
            try FileManager.default.createDirectory(atPath: importDocumentURL!.path, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            NSLog("Unable to create directory \(error.debugDescription)")
        }
        
        // Create dir for change document
        do {
            try FileManager.default.createDirectory(atPath: changeDocumentURL!.path, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            NSLog("Unable to create directory \(error.debugDescription)")
        }
        
        if #available(iOSApplicationExtension 11.0, *) {
            
            // Only iOS 11
            
            listUpdateItems.removeAll()
            listFavoriteIdentifierRank = NCManageDatabase.sharedInstance.getTableMetadatasDirectoryFavoriteIdentifierRank()
            
        } else {
            
            NSFileCoordinator().coordinate(writingItemAt: self.documentStorageURL, options: [], error: nil, byAccessor: { newURL in
                do {
                    try FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: true, attributes: nil)
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
                metadata.fileID = identifier.rawValue
                metadata.fileName = NCBrandOptions.sharedInstance.brand
                metadata.fileNameView = NCBrandOptions.sharedInstance.brand
                metadata.typeFile = k_metadataTypeFile_directory
                    
                return FileProviderItem(metadata: metadata, serverUrl: homeServerUrl)
            }
            
        } else {
        
            if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileID = %@", account, identifier.rawValue))  {
                if let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account = %@ AND directoryID = %@", account, metadata.directoryID)) {
                    return FileProviderItem(metadata: metadata, serverUrl: directory.serverUrl)
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

            var fileSize : UInt64 = 0

            do {
                let attr = try FileManager.default.attributesOfItem(atPath: url.path)
                fileSize = attr[FileAttributeKey.size] as! UInt64
            } catch let error {
                print("Error: \(error)")
            }
            
            if fileSize > 0 {
                completionHandler(nil)
                return
            }
            
            //let fileName = url.lastPathComponent
            let pathComponents = url.pathComponents
            let identifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
            //let changeDocumentPath = changeDocumentURL!.path + "/" + fileName
            
            guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileID = %@", account, identifier.rawValue)) else {
                completionHandler(NSFileProviderError(.noSuchItem))
                return
            }
            
            guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
                completionHandler(NSFileProviderError(.noSuchItem))
                return
            }
            
            let task = ocNetworking?.downloadFileNameServerUrl("\(serverUrl)/\(metadata.fileName)", fileNameLocalPath: "\(directoryUser)/\(metadata.fileID)", communication: CCNetworking.shared().sharedOCCommunicationExtensionDownload(metadata.fileName), success: { (lenght) in
                    
                NCManageDatabase.sharedInstance.addLocalFile(metadata: metadata)
                    
                // copy download file to url
                _ = self.copyFile("\(directoryUser)/\(metadata.fileID)", toPath: url.path)
                completionHandler(nil)
                    
            }, failure: { (errorMessage, errorCode) in
                completionHandler(NSFileProviderError(.serverUnreachable))
            })
                
            if task != nil {
                NSFileProviderManager.default.register(task!, forItemWithIdentifier: NSFileProviderItemIdentifier(identifier.rawValue)) { (error) in
                    print("Registe download task")
                }
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
            let changeDocumentPath = changeDocumentURL!.path + "/" + fileName
            let importDocumentPath = importDocumentURL!.path + "/" + fileName
            let metadataNet = CCMetadataNet()

            assert(pathComponents.count > 2)
            let identifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
            
            guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileID = %@", account, identifier.rawValue))  else {
                return
            }
            
            guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
                return
            }
            
            // Refresh
            self.refreshEnumerator(identifier: identifier, serverUrl: serverUrl)
            
            // Copy file to Change Document & if exists on Import Document
            _ = self.copyFile(url.path, toPath: changeDocumentPath)
            if FileManager.default.fileExists(atPath: importDocumentPath) {
                _ = self.copyFile(url.path, toPath: importDocumentPath)
            }
                
            metadataNet.account = account
            metadataNet.assetLocalIdentifier = k_assetLocalIdentifierFileProviderStorage + identifier.rawValue
            metadataNet.fileName = fileName
            metadataNet.path = changeDocumentPath
            metadataNet.selector = selectorUploadFile
            metadataNet.selectorPost = ""
            metadataNet.serverUrl = serverUrl
            metadataNet.session = k_upload_session
            metadataNet.taskStatus = Int(k_taskStatusResume)
                
            _ = NCManageDatabase.sharedInstance.addQueueUpload(metadataNet: metadataNet)
                
            // Upload
            self.uploadCloud(fileName, serverUrl: serverUrl, fileNameLocalPath: changeDocumentPath, metadata: metadata, identifier: identifier)

        } else {
            
            let fileSize = (try! FileManager.default.attributesOfItem(atPath: url.path)[FileAttributeKey.size] as! NSNumber).uint64Value
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
                _ = try FileManager.default.removeItem(at: url)
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
                
            if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileID = %@", account, itemIdentifier.rawValue))  {
                    
                if (metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video) {
                        
                    let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID)
                    let fileName = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: serverUrl, activeUrl: accountUrl)
                    let fileNameLocal = metadata.fileID

                    ocNetworking?.downloadThumbnail(withDimOfThumbnail: "m", fileName: fileName, fileNameLocal: fileNameLocal, success: {

                        do {
                            let url = URL.init(fileURLWithPath: "\(directoryUser)/\(itemIdentifier.rawValue).ico")
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
        
        // clear list update items
        listUpdateItems.removeAll()
        
        var serverUrl = ""
        
        if parentItemIdentifier == .rootContainer {
            
            serverUrl = homeServerUrl
            
        } else {
            
            guard let directoryParent = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account = %@ AND fileID = %@", account, parentItemIdentifier.rawValue)) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            
            serverUrl = directoryParent.serverUrl
        }
        
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
            
            let item = FileProviderItem(metadata: metadataDB, serverUrl: serverUrl)
                
            completionHandler(item, nil)
            
        }, failure: { (errorMessage, errorCode) in
            completionHandler(nil, NSFileProviderError(.serverUnreachable))
        })
    }
    
    override func deleteItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (Error?) -> Void) {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else {
            return
        }
        
        // clear list update items
        listUpdateItems.removeAll()
        
        guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileID = %@", account, itemIdentifier.rawValue)) else {
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }
        
        guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }
        
        ocNetworking?.deleteFileOrFolder(metadata.fileName, serverUrl: serverUrl, success: {
            
            let fileNamePath = directoryUser + "/" + metadata.fileID
            do {
                try FileManager.default.removeItem(atPath: fileNamePath)
            } catch let error {
                print("error: \(error)")
            }
            do {
                try FileManager.default.removeItem(atPath: fileNamePath + ".ico")
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
    
    override func renameItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toName itemName: String, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else {
            return
        }
        
        // clear list update items
        listUpdateItems.removeAll()
        
        guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileID = %@", account, itemIdentifier.rawValue)) else {
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
        
        // resolve the given identifier to a file on disk
        guard let item = try? item(for: itemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        let fileName = serverUrl + "/" + item.filename
        let fileNameTo = serverUrl + "/" + itemName
        
        ocNetworking?.moveFileOrFolder(fileName, fileNameTo: fileNameTo, success: {
            
            metadata.fileName = itemName
            metadata.fileNameView = itemName
            
            guard let metadata = NCManageDatabase.sharedInstance.addMetadata(metadata) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            
            if metadata.directory {
                
                NCManageDatabase.sharedInstance.setDirectory(serverUrl: fileName, serverUrlTo: fileNameTo, etag: nil, fileID: nil, encrypted: directoryTable.e2eEncrypted)

            } else {
                
                NCManageDatabase.sharedInstance.setLocalFile(fileID: metadata.fileID, date: nil, exifDate: nil, exifLatitude: nil, exifLongitude: nil, fileName: itemName)
            }
            
            completionHandler(item, nil)
            
        }, failure: { (errorMessage, errorCode) in
            completionHandler(nil, NSFileProviderError(.serverUnreachable))
        })
        
        print("[LOG] rename")
        completionHandler(nil, nil)
    }
    
    override func setFavoriteRank(_ favoriteRank: NSNumber?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {

        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else {
            return
        }
        
        var favorite = false
        
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
                let newRank = listFavoriteIdentifierRank.count + 1
                listFavoriteIdentifierRank[itemIdentifier.rawValue] = NSNumber(value: Int64(newRank))
            }
            favorite = true
        }
        
        // Call the completion handler before performing any network activity or other long-running tasks. Defer these tasks to the background
        let item = FileProviderItem(metadata: metadata, serverUrl: serverUrl)
        completionHandler(item, nil)
        
        // Change Status ? Call API Nextcloud Network
        if (favorite == true && metadata.favorite == false) || (favorite == false && metadata.favorite == true) {
         
            DispatchQueue(label: "com.nextcloud", qos: .background, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil).async {
                
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
                
        // Add, Remove (nil)
        NCManageDatabase.sharedInstance.addTag(itemIdentifier.rawValue, tagIOS: tagData)
        
        guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileID = %@", account, itemIdentifier.rawValue))  else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        let item = FileProviderItem(metadata: metadata, serverUrl: serverUrl)
        
        completionHandler(item, nil)
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
        
        var fileName = fileURL.lastPathComponent
        let fileCoordinator = NSFileCoordinator()
        var error: NSError?
        var directoryPredicate: NSPredicate
        var size = 0 as Double
        var fileNamePathUpload: URL?

        if parentItemIdentifier == .rootContainer {
            directoryPredicate = NSPredicate(format: "account = %@ AND serverUrl = %@", account, homeServerUrl)
        } else {
            directoryPredicate = NSPredicate(format: "account = %@ AND fileID = %@", account, parentItemIdentifier.rawValue)
        }
            
        guard let directoryParent = NCManageDatabase.sharedInstance.getTableDirectory(predicate: directoryPredicate) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        let serverUrl = directoryParent.serverUrl
        
        // --------------------------------------------- Copy file here
        
        if fileURL.startAccessingSecurityScopedResource() == false {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        
        // exists with same name ? add + 1
        if NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileNameView = %@ AND directoryID = %@", account, fileName, directoryParent.directoryID)) != nil {
            
            var name = NSString(string: fileName).deletingPathExtension
            let ext = NSString(string: fileName).pathExtension
            
            let characters = Array(name)
            
            if characters.count < 2 {
                fileName = name + " " + "1" + "." + ext
            } else {
                let space = characters[characters.count-2]
                let numChar = characters[characters.count-1]
                var num = Int(String(numChar))
                if (space == " " && num != nil) {
                    name = String(name.dropLast())
                    num = num! + 1
                    fileName = name + "\(num!)" + "." + ext
                } else {
                    fileName = name + " " + "1" + "." + ext
                }
            }
        }
        
        let fileNameLocalPath = importDocumentURL!.appendingPathComponent(fileName)
        
        fileCoordinator.coordinate(readingItemAt: fileURL, options: NSFileCoordinator.ReadingOptions.withoutChanges, error: &error) { (url) in
            _ = self.copyFile( url.path, toPath: fileNameLocalPath.path)
        }
            
        fileURL.stopAccessingSecurityScopedResource()
        
        // ------------------------------------------------------------

        // ---------------------------------------------- Create file 0
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileNameLocalPath.path)
            size = attributes[FileAttributeKey.size] as! Double
        } catch let error {
            print("error: \(error)")
        }
        
        // Upload file 0 len
        if (size == 0) {
            fileNamePathUpload = fileNameLocalPath
        } else {
            fileNamePathUpload = importDocumentURL!.appendingPathComponent(fileName+".000")
            do {
                try FileManager.default.removeItem(atPath: fileNamePathUpload!.path)
            } catch let error {
                print("error: \(error)")
            }
            FileManager.default.createFile(atPath: fileNamePathUpload!.path, contents: nil, attributes: nil)
        }
        
        // ------------------------------------------------------------
    
        // upload
        _ = ocNetworking?.uploadFileNameServerUrl(serverUrl+"/"+fileName, fileNameLocalPath: fileNamePathUpload?.path, communication: CCNetworking.shared().sharedOCCommunication(), success: { (fileID, etag, date) in
                
            let metadata = tableMetadata()
                
            metadata.account = account
            metadata.date = date! as NSDate
            metadata.directory = false
            metadata.directoryID = directoryParent.directoryID
            metadata.etag = etag!
            metadata.fileID = fileID!
            metadata.fileName = fileName
            metadata.fileNameView = fileName
            metadata.size = 0

            CCUtility.insertTypeFileIconName(fileName, metadata: metadata)
                
            guard let metadataDB = NCManageDatabase.sharedInstance.addMetadata(metadata) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            
            // Create dir <base storage directory>/<item identifier>
            do {
                try FileManager.default.createDirectory(atPath: fileProviderStorageURL!.appendingPathComponent(metadata.fileID).path, withIntermediateDirectories: true, attributes: nil)
            } catch let error {
                print("error: \(error)")
            }
             // copy <base storage directory>/<item identifier>/<item file name>
            _ = self.copyFile(fileNameLocalPath.path, toPath: "\(fileProviderStorageURL!.appendingPathComponent(metadata.fileID).path)/\(metadata.fileNameView)")
            
            // add item
            let item = FileProviderItem(metadata: metadataDB, serverUrl: serverUrl)
            
            // add queue upload if size > 0
            if (size > 0) {
                
                let metadataNet = CCMetadataNet()
                
                metadataNet.account = account
                metadataNet.assetLocalIdentifier = k_assetLocalIdentifierFileProviderStorage + fileID!
                metadataNet.fileName = fileName
                metadataNet.path = importDocumentURL!.path + "/" + metadata.fileNameView
                metadataNet.selector = selectorUploadFile
                metadataNet.selectorPost = ""
                metadataNet.serverUrl = serverUrl
                metadataNet.session = k_upload_session
                metadataNet.taskStatus = Int(k_taskStatusResume)
                
                _ = NCManageDatabase.sharedInstance.addQueueUpload(metadataNet: metadataNet)
            }
            
            if (size > 0) { // MICROSOFT 365 
                self.refreshEnumerator(identifier: item.itemIdentifier, serverUrl: serverUrl)
            }
            completionHandler(item, nil)

        }, failure: { (errorMessage, errorCode) in
            completionHandler(nil, NSFileProviderError(.serverUnreachable))
        })
    }
    
    // --------------------------------------------------------------------------------------------
    //  MARK: - User Function
    // --------------------------------------------------------------------------------------------
    
    func uploadCloud(_ fileName: String, serverUrl: String, fileNameLocalPath: String, metadata: tableMetadata, identifier: NSFileProviderItemIdentifier) {
        
        if let task = listUpload[identifier.rawValue] {
            task.cancel()
        }
        
        let task = ocNetworking?.uploadFileNameServerUrl(serverUrl+"/"+fileName, fileNameLocalPath: fileNameLocalPath, communication: CCNetworking.shared().sharedOCCommunicationExtensionUpload(fileName), success: { (fileID, etag, date) in
            
            // Remove file on queueUpload
            NCManageDatabase.sharedInstance.deleteQueueUpload(path: fileNameLocalPath)
            // Remove from dictionary
            self.listUpload.removeValue(forKey: identifier.rawValue)
            
            metadata.date = date! as NSDate
            
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileNameLocalPath)
                metadata.size = attributes[FileAttributeKey.size] as! Double
            } catch let error {
                print("error: \(error)")
            }
            
            _ = NCManageDatabase.sharedInstance.addMetadata(metadata)
            
            // Remove file *changeDocument
            _ = self.deleteFile(fileNameLocalPath)
            
            // Refresh
            self.refreshEnumerator(identifier: identifier, serverUrl: serverUrl)
            
        }, failure: { (errorMessage, errorCode) in
            // Remove from dictionary
            self.listUpload.removeValue(forKey: identifier.rawValue)
            // Refresh
            self.refreshEnumerator(identifier: identifier, serverUrl: serverUrl)
        })
        
        if (task != nil) {
            listUpload[identifier.rawValue] = task
            if #available(iOSApplicationExtension 11.0, *) {
                NSFileProviderManager.default.register(task!, forItemWithIdentifier: identifier) { (error) in
                    print("Registe download task")
                }
            }
        }        
    }
    
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
        } else if serverUrl == "WorkingSet" {
            NSFileProviderManager.default.signalEnumerator(for: .workingSet, completionHandler: { (error) in
                print("send signal workingSet")
            })
        } else {
            if let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account = %@ AND serverUrl = %@", account, serverUrl)) {
                let itemDirectory = NSFileProviderItemIdentifier(directory.fileID)
                NSFileProviderManager.default.signalEnumerator(for: itemDirectory, completionHandler: { (error) in
                    print("send signal")
                })
            }
        }
    }
    
    func copyFile(_ atPath: String, toPath: String) -> Error? {
        
        var errorResult: Error?
        
        do {
            try FileManager.default.removeItem(atPath: toPath)
        } catch let error {
            print("error: \(error)")
        }
        do {
            try FileManager.default.copyItem(atPath: atPath, toPath: toPath)
        } catch let error {
            errorResult = error
        }
        
        return errorResult
    }
    
    func deleteFile(_ atPath: String) -> Error? {
        
        var errorResult: Error?
        
        do {
            try FileManager.default.removeItem(atPath: atPath)
        } catch let error {
            errorResult = error
        }
        
        return errorResult
    }
}
