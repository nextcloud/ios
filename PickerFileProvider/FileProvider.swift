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
var groupURL: URL?

class FileProvider: NSFileProviderExtension {
    
    var uploading = [String]()
    
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
        
        if #available(iOSApplicationExtension 11.0, *) {
            
            // Only iOS 11
            
        } else {
            
            NSFileCoordinator().coordinate(writingItemAt: self.documentStorageURL, options: [], error: nil, byAccessor: { newURL in
                try? FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: true, attributes: nil)
            })
        }
    }
    
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
                    
                    if (!metadata.directory) {
                        
                        let identifierPathUrl = groupURL!.appendingPathComponent("File Provider Storage").appendingPathComponent(metadata.fileID)
                        let toPath = "\(identifierPathUrl.path)/\(metadata.fileNameView)"
                        let atPath = "\(directoryUser)/\(metadata.fileID)"
                            
                        if !FileManager.default.fileExists(atPath: toPath) {

                            try? FileManager.default.createDirectory(atPath: identifierPathUrl.path, withIntermediateDirectories: true, attributes: nil)
        
                            if FileManager.default.fileExists(atPath: atPath) {
                                try? FileManager.default.copyItem(atPath: atPath, toPath: toPath)
                            } else {
                                FileManager.default.createFile(atPath: toPath, contents: nil, attributes: nil)
                            }
                        }
                    }
                    
                    return FileProviderItem(metadata: metadata, serverUrl: directory.serverUrl)
                }
            }
        }
        
        // TODO: implement the actual lookup
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
                completionHandler(error)
            }
            
        } else {
            
            let fileName = url.lastPathComponent
            let placeholderURL = NSFileProviderExtension.placeholderURL(for: self.documentStorageURL.appendingPathComponent(fileName))
            let fileSize = 0
            let metadata = [AnyHashable(URLResourceKey.fileSizeKey): fileSize]
            do {
                try NSFileProviderExtension.writePlaceholder(at: placeholderURL, withMetadata: metadata as! [URLResourceKey : Any])
            } catch {
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
            } catch {
                print("Error: \(error)")
                completionHandler(NSFileProviderError(.noSuchItem))
            }
            
            // Do not exists
            if fileSize == 0 {
                
                let pathComponents = url.pathComponents
                let identifier = pathComponents[pathComponents.count - 2]
                
                guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileID = %@", account, identifier)) else {
                    completionHandler(NSFileProviderError(.noSuchItem))
                    return
                }
                
                guard let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account = %@ AND directoryID = %@", account, metadata.directoryID)) else {
                    completionHandler(NSFileProviderError(.noSuchItem))
                    return
                }
                
                _ = ocNetworking?.downloadFileNameServerUrl("\(directory.serverUrl)/\(metadata.fileName)", fileNameLocalPath: "\(directoryUser)/\(metadata.fileID)", success: { (lenght) in
                    
                    if (lenght > 0) {
                        
                        // copy download file to url
                        try? FileManager.default.removeItem(atPath: url.path)
                        try? FileManager.default.copyItem(atPath: "\(directoryUser)/\(metadata.fileID)", toPath: url.path)
                        // create thumbnail
                        CCGraphics.createNewImage(from: metadata.fileID, directoryUser: directoryUser, fileNameTo: metadata.fileID, extension: (metadata.fileNameView as NSString).pathExtension, size: "m", imageForUpload: false, typeFile: metadata.typeFile, writePreview: true, optimizedFileName: CCUtility.getOptimizedPhoto())
                    
                        NCManageDatabase.sharedInstance.addLocalFile(metadata: metadata)
                        if (metadata.typeFile == k_metadataTypeFile_image) {
                            CCExifGeo.sharedInstance().setExifLocalTableEtag(metadata, directoryUser: directoryUser, activeAccount: account)
                        }
                    }
                    
                    completionHandler(nil)
                    
                }, failure: { (message, errorCode) in
                    completionHandler(NSFileProviderError(.serverUnreachable))
                })
                
            } else {
                
                // Exists
                completionHandler(nil)
            }
            
        } else {
            
            guard let fileData = try? Data(contentsOf: url) else {
                completionHandler(nil)
                return
            }
            do {
                _ = try fileData.write(to: url, options: NSData.WritingOptions())
                completionHandler(nil)
            } catch let error as NSError {
                print("error writing file to URL")
                completionHandler(error)
            }
        }
    }
    
    override func itemChanged(at url: URL) {
        
        if #available(iOSApplicationExtension 11.0, *) {
            
            let fileSize = (try! FileManager.default.attributesOfItem(atPath: url.path)[FileAttributeKey.size] as! NSNumber).uint64Value
            NSLog("[LOG] Item changed at URL %@ %lu", url as NSURL, fileSize)
            if (fileSize == 0) {
                return
            }
            
            let fileName = url.lastPathComponent
            let pathComponents = url.pathComponents
            assert(pathComponents.count > 2)
            let identifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])

            if (uploading.contains(identifier.rawValue) == true) {
                return
            }
            
            if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileID = %@", account, identifier.rawValue))  {
                
                guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
                    return
                }
                
                uploading.append(identifier.rawValue)
                
                _ =  ocNetworking?.uploadFileNameServerUrl(serverUrl+"/"+fileName, fileNameLocalPath: url.path, success: { (fileID, etag, date) in
                    
                    let toPath = "\(directoryUser)/\(metadata.fileID)"

                    try? FileManager.default.removeItem(atPath: toPath)
                    try? FileManager.default.copyItem(atPath:  url.path, toPath: toPath)
                    // create thumbnail
                    CCGraphics.createNewImage(from: metadata.fileID, directoryUser: directoryUser, fileNameTo: metadata.fileID, extension: (metadata.fileNameView as NSString).pathExtension, size: "m", imageForUpload: false, typeFile: metadata.typeFile, writePreview: true, optimizedFileName: CCUtility.getOptimizedPhoto())
                    
                    metadata.date = date! as NSDate
                  
                    do {
                        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                        metadata.size = attributes[FileAttributeKey.size] as! Double
                    } catch {
                    }
                    
                    guard let metadataDB = NCManageDatabase.sharedInstance.addMetadata(metadata) else {
                        return
                    }
                    
                    // item
                    _ = FileProviderItem(metadata: metadataDB, serverUrl: serverUrl)
                    
                    //
                    self.uploading = self.uploading.filter() { $0 != identifier.rawValue }
                    
                    // Refresh UI
                    self.refreshCurrentEnumerator(serverUrl: serverUrl)
                
                }, failure: { (message, errorCode) in
                    
                    self.uploading = self.uploading.filter() { $0 != identifier.rawValue }
                })
            }
            
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
                do {
                    try FileManager.default.removeItem(atPath: destinationDirectoryUser)
                } catch _ {
                    print("file do not exists")
                }
                
                do {
                    try FileManager.default.copyItem(atPath: url.path, toPath: destinationDirectoryUser)
                } catch _ {
                    print("file do not exists")
                    self.stopProvidingItem(at: url)
                    return
                }
                
                // Prepare for send Metadata
                metadata!.sessionID = uploadID
                metadata!.session = k_upload_session
                metadata!.sessionTaskIdentifier = Int(k_taskIdentifierWaitStart)
                _ = NCManageDatabase.sharedInstance.updateMetadata(metadata!)
                
            } else {
                
                // New
                let directoryUser = CCUtility.getDirectoryActiveUser(account.user, activeUrl: account.url)
                let destinationDirectoryUser = "\(directoryUser!)/\(fileName)"
                
                do {
                    try FileManager.default.removeItem(atPath: destinationDirectoryUser)
                } catch _ {
                    print("file do not exists")
                }
                do {
                    try FileManager.default.copyItem(atPath: url.path, toPath: destinationDirectoryUser)
                } catch _ {
                    print("file do not exists")
                    self.stopProvidingItem(at: url)
                    return
                }
                
                CCNetworking.shared().uploadFile(fileName, serverUrl: serverUrl, session: k_upload_session, taskStatus: Int(k_taskStatusResume), selector: nil, selectorPost: nil, errorCode: 0, delegate: self)
            }
            
            self.stopProvidingItem(at: url)
        }
    }
    
    override func stopProvidingItem(at url: URL) {
        // Called after the last claim to the file has been released. At this point, it is safe for the file provider to remove the content file.
        // Care should be taken that the corresponding placeholder file stays behind after the content file has been deleted.
        
        // Called after the last claim to the file has been released. At this point, it is safe for the file provider to remove the content file.
        
        // TODO: look up whether the file has local changes
        let fileHasLocalChanges = false
        
        if !fileHasLocalChanges {
            // remove the existing file to free up space
            do {
                _ = try FileManager.default.removeItem(at: url)
            } catch {
                // Handle error
            }
            
            // write out a placeholder to facilitate future property lookups
            self.providePlaceholder(at: url, completionHandler: { error in
                // TODO: handle any error, do any necessary cleanup
            })
        }
    }
    
    // MARK: - Actions
    
    /* TODO: implement the actions for items here
     each of the actions follows the same pattern:
     - make a note of the change in the local model
     - schedule a server request as a background task to inform the server of the change
     - call the completion block with the modified item in its post-modification state
     */
    
    // MARK: - Enumeration
    
    override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {
        
        let maybeEnumerator = FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier)
        
        return maybeEnumerator
    }
    
    override func fetchThumbnails(for itemIdentifiers: [NSFileProviderItemIdentifier], requestedSize size: CGSize, perThumbnailCompletionHandler: @escaping (NSFileProviderItemIdentifier, Data?, Error?) -> Void, completionHandler: @escaping (Error?) -> Void) -> Progress {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else {
            return Progress(totalUnitCount:0)
        }

        let progress = Progress(totalUnitCount: Int64(itemIdentifiers.count))
        var counterProgress: Int64 = 0
            
        for item in itemIdentifiers {
                
            if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileID = %@", account, item.rawValue))  {
                    
                if (metadata.typeFile == k_metadataTypeFile_image || metadata.typeFile == k_metadataTypeFile_video) {
                        
                    let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID)
                    let fileName = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: serverUrl, activeUrl: accountUrl)
                    let fileNameLocal = metadata.fileID

                    ocNetworking?.downloadThumbnail(withDimOfThumbnail: "m", fileName: fileName, fileNameLocal: fileNameLocal, success: {

                        do {
                            let url = URL.init(fileURLWithPath: "\(directoryUser)/\(item.rawValue).ico")
                            let data = try Data.init(contentsOf: url)
                            perThumbnailCompletionHandler(item, data, nil)
                        } catch {
                            perThumbnailCompletionHandler(item, nil, NSFileProviderError(.noSuchItem))
                        }
                            
                        counterProgress += 1
                        if (counterProgress == progress.totalUnitCount) {
                            completionHandler(nil)
                        }
                            
                    }, failure: { (message, errorCode) in

                        perThumbnailCompletionHandler(item, nil, NSFileProviderError(.serverUnreachable))
                            
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
    
    override func createDirectory(withName directoryName: String, inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {

        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else {
            return
        }
        
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
                
            guard let newTableDirectory = NCManageDatabase.sharedInstance.addDirectory(encrypted: false, favorite: false, fileID: fileID, permissions: nil, serverUrl: serverUrl+"/"+directoryName) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
                
            let metadata = tableMetadata()
                
            metadata.account = account
            metadata.directory = true
            metadata.directoryID = newTableDirectory.directoryID
            metadata.fileID = fileID!
            metadata.fileName = directoryName
            metadata.fileNameView = directoryName
            metadata.typeFile = k_metadataTypeFile_directory
                
            let item = FileProviderItem(metadata: metadata, serverUrl: serverUrl)
                
            completionHandler(item, nil)
                
        }, failure: { (message, errorCode) in
            completionHandler(nil, NSFileProviderError(.serverUnreachable))
        })
    }
    
    override func deleteItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (Error?) -> Void) {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else {
            return
        }
        
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
            try? FileManager.default.removeItem(atPath: fileNamePath)
            try? FileManager.default.removeItem(atPath: fileNamePath + ".ico")
            
            if metadata.directory {
                let dirForDelete = CCUtility.stringAppendServerUrl(serverUrl, addFileName: metadata.fileName)
                NCManageDatabase.sharedInstance.deleteDirectoryAndSubDirectory(serverUrl: dirForDelete!)
            }
            
            NCManageDatabase.sharedInstance.deleteLocalFile(predicate: NSPredicate(format: "fileID == %@", metadata.fileID))
            NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "fileID == %@", metadata.fileID), clearDateReadDirectoryID: nil)
            
            completionHandler(nil)
            
        }, failure: { (error, errorCode) in
            completionHandler(NSFileProviderError(.serverUnreachable))
        })
    }
    
    override func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else {
            return
        }
        
        let fileName = fileURL.lastPathComponent
        let fileCoordinator = NSFileCoordinator()
        var error: NSError?
        var directoryPredicate: NSPredicate
            
        if parentItemIdentifier == .rootContainer {
            directoryPredicate = NSPredicate(format: "account = %@ AND serverUrl = %@", account, homeServerUrl)
        } else {
            directoryPredicate = NSPredicate(format: "account = %@ AND fileID = %@", account, parentItemIdentifier.rawValue)
        }
            
        guard let directoryParent = NCManageDatabase.sharedInstance.getTableDirectory(predicate: directoryPredicate) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
            
        if fileURL.startAccessingSecurityScopedResource() == false {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
            
        let fileNameLocalPath = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileURL.lastPathComponent)!
            
        fileCoordinator.coordinate(readingItemAt: fileURL, options: NSFileCoordinator.ReadingOptions.withoutChanges, error: &error) { (url) in
                
            do {
                try FileManager.default.removeItem(atPath: fileNameLocalPath.path)
            } catch _ {
                print("file do not exists")
            }
                
            do {
                try FileManager.default.copyItem(atPath: url.path, toPath: fileNameLocalPath.path)
            } catch _ {
                print("file do not exists")
            }
        }
            
        fileURL.stopAccessingSecurityScopedResource()

        _ = ocNetworking?.uploadFileNameServerUrl(directoryParent.serverUrl+"/"+fileName, fileNameLocalPath: fileNameLocalPath.path, success: { (fileID, etag, date) in
                
            let metadata = tableMetadata()
                
            metadata.account = account
            metadata.date = date! as NSDate
            metadata.directory = false
            metadata.directoryID = directoryParent.directoryID
            metadata.etag = etag!
            metadata.fileID = fileID!
            metadata.fileName = fileName
            metadata.fileNameView = fileName

            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                metadata.size = attributes[FileAttributeKey.size] as! Double
            } catch {
            }
                
            CCUtility.insertTypeFileIconName(fileName, metadata: metadata)
                
            guard let metadataDB = NCManageDatabase.sharedInstance.addMetadata(metadata) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }

            // Copy on ItemIdentifier path
            let identifierPathUrl = groupURL!.appendingPathComponent("File Provider Storage").appendingPathComponent(metadata.fileID)
            let toPath = "\(identifierPathUrl.path)/\(metadata.fileNameView)"
                
            if !FileManager.default.fileExists(atPath: identifierPathUrl.path) {
                do {
                    try FileManager.default.createDirectory(atPath: identifierPathUrl.path, withIntermediateDirectories: true, attributes: nil)
                } catch let error {
                    print("error creating filepath: \(error)")
                }
            }
                
            try? FileManager.default.removeItem(atPath: toPath)
            try? FileManager.default.copyItem(atPath:  fileNameLocalPath.path, toPath: toPath)

            // add item
            let item = FileProviderItem(metadata: metadataDB, serverUrl: directoryParent.serverUrl)
                
            completionHandler(item, nil)

        }, failure: { (message, errorCode) in
            completionHandler(nil, NSFileProviderError(.serverUnreachable))
        })
    }
    
    // --------------------------------------------------------------------------------------------
    //  MARK: - User Function
    // --------------------------------------------------------------------------------------------

    
    func refreshCurrentEnumerator(serverUrl: String) {
        
        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else {
            return
        }
        
        if serverUrl == homeServerUrl {
            NSFileProviderManager.default.signalEnumerator(for: .rootContainer, completionHandler: { (error) in
                print("send signal rootContainer")
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
}
