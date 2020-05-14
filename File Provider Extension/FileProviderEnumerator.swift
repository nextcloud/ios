//
//  FileProviderEnumerator.swift
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
import NCCommunication

class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
    
    var enumeratedItemIdentifier: NSFileProviderItemIdentifier
    var serverUrl: String?
    
    init(enumeratedItemIdentifier: NSFileProviderItemIdentifier) {
        
        self.enumeratedItemIdentifier = enumeratedItemIdentifier
        
        // Select ServerUrl
        if (enumeratedItemIdentifier == .rootContainer) {
            serverUrl = fileProviderData.sharedInstance.homeServerUrl
        } else {
            
            let metadata = fileProviderUtility.sharedInstance.getTableMetadataFromItemIdentifier(enumeratedItemIdentifier)
            if metadata != nil  {
                if let directorySource = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata!.account, metadata!.serverUrl))  {
                    serverUrl = directorySource.serverUrl + "/" + metadata!.fileName
                }
            }
        }
        
        super.init()
    }

    func invalidate() {
       
    }

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        
        var items: [NSFileProviderItemProtocol] = []
        
        /*** WorkingSet ***/
        if enumeratedItemIdentifier == .workingSet {
            
            var itemIdentifierMetadata = [NSFileProviderItemIdentifier:tableMetadata]()
            
            // ***** Tags *****
            let tags = NCManageDatabase.sharedInstance.getTags(predicate: NSPredicate(format: "account == %@", fileProviderData.sharedInstance.account))
            for tag in tags {
                
                guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "ocId == %@", tag.ocId))  else { continue }
                fileProviderUtility.sharedInstance.createocIdentifierOnFileSystem(metadata: metadata)
                itemIdentifierMetadata[fileProviderUtility.sharedInstance.getItemIdentifier(metadata: metadata)] = metadata
            }
            
            // ***** Favorite *****
            fileProviderData.sharedInstance.listFavoriteIdentifierRank = NCManageDatabase.sharedInstance.getTableMetadatasDirectoryFavoriteIdentifierRank(account: fileProviderData.sharedInstance.account)
            for (identifier, _) in fileProviderData.sharedInstance.listFavoriteIdentifierRank {
                
                guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "ocId == %@", identifier)) else { continue }
                itemIdentifierMetadata[fileProviderUtility.sharedInstance.getItemIdentifier(metadata: metadata)] = metadata
            }
            
            // create items
            for (_, metadata) in itemIdentifierMetadata {
                let parentItemIdentifier = fileProviderUtility.sharedInstance.getParentItemIdentifier(metadata: metadata, homeServerUrl: fileProviderData.sharedInstance.homeServerUrl)
                if parentItemIdentifier != nil {
                    let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier!)
                    items.append(item)
                }
            }
            
            observer.didEnumerate(items)
            observer.finishEnumerating(upTo: nil)
            
        } else {
        
        /*** ServerUrl ***/
            
            let isPaginationEnabled = false
            
            guard let serverUrl = serverUrl else {
                observer.finishEnumerating(upTo: nil)
                return
            }
            
            if (page == NSFileProviderPage.initialPageSortedByDate as NSFileProviderPage || page == NSFileProviderPage.initialPageSortedByName as NSFileProviderPage) {
                
                if isPaginationEnabled {
                                    
                    self.readFolder(serverUrl: serverUrl, page: 1, limit: fileProviderData.sharedInstance.itemForPage) { (metadatas) in
                        self.completeObserver(observer, numPage: 1, metadatas: metadatas)
                    }
                    
                } else {
                    
                    readFileOrFolder(serverUrl: serverUrl) {
                        let metadatas = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", fileProviderData.sharedInstance.account, serverUrl), page: 1, limit: fileProviderData.sharedInstance.itemForPage, sorted: "fileName", ascending: true)
                        
                        self.completeObserver(observer, numPage: 1, metadatas: metadatas)
                    }
                    
                    // Update the WorkingSet -> Favorite
                    fileProviderData.sharedInstance.updateFavoriteForWorkingSet()
                }
                
            } else {
                
                let numPage = Int(String(data: page.rawValue, encoding: .utf8)!)!

                if isPaginationEnabled {

                    self.readFolder(serverUrl: serverUrl, page: 1, limit: fileProviderData.sharedInstance.itemForPage) { (metadatas) in
                        self.completeObserver(observer, numPage: 1, metadatas: metadatas)
                    }
                    
                } else {
            
                    let metadatas = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", fileProviderData.sharedInstance.account, serverUrl), page: numPage, limit: fileProviderData.sharedInstance.itemForPage, sorted: "fileName", ascending: true)
                    
                    completeObserver(observer, numPage: numPage, metadatas: metadatas)
                }
            }
        }
    }
    
    func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
        
        var itemsDelete = [NSFileProviderItemIdentifier]()
        var itemsUpdate = [FileProviderItem]()
        
        // Report the deleted items
        //
        if self.enumeratedItemIdentifier == .workingSet {
            for (itemIdentifier, _) in fileProviderData.sharedInstance.fileProviderSignalDeleteWorkingSetItemIdentifier {
                itemsDelete.append(itemIdentifier)
            }
            fileProviderData.sharedInstance.fileProviderSignalDeleteWorkingSetItemIdentifier.removeAll()
        } else {
            for (itemIdentifier, _) in fileProviderData.sharedInstance.fileProviderSignalDeleteContainerItemIdentifier {
                itemsDelete.append(itemIdentifier)
            }
            fileProviderData.sharedInstance.fileProviderSignalDeleteContainerItemIdentifier.removeAll()
        }
        
        // Report the updated items
        //
        if self.enumeratedItemIdentifier == .workingSet {
            for (_, item) in fileProviderData.sharedInstance.fileProviderSignalUpdateWorkingSetItem {
                itemsUpdate.append(item)
            }
            fileProviderData.sharedInstance.fileProviderSignalUpdateWorkingSetItem.removeAll()
        } else {
            for (_, item) in fileProviderData.sharedInstance.fileProviderSignalUpdateContainerItem {
                itemsUpdate.append(item)
            }
            fileProviderData.sharedInstance.fileProviderSignalUpdateContainerItem.removeAll()
        }
        
        observer.didDeleteItems(withIdentifiers: itemsDelete)
        observer.didUpdate(itemsUpdate)
        
        let data = "\(fileProviderData.sharedInstance.currentAnchor)".data(using: .utf8)
        observer.finishEnumeratingChanges(upTo: NSFileProviderSyncAnchor(data!), moreComing: false)
    }
    
    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        let data = "\(fileProviderData.sharedInstance.currentAnchor)".data(using: .utf8)
        completionHandler(NSFileProviderSyncAnchor(data!))
    }
    
    // --------------------------------------------------------------------------------------------
    //  MARK: - User Function + Network
    // --------------------------------------------------------------------------------------------

    func completeObserver(_ observer: NSFileProviderEnumerationObserver, numPage: Int, metadatas: [tableMetadata]?) {
            
        var numPage = numPage
        var items: [NSFileProviderItemProtocol] = []

        if (metadatas != nil) {
            
            for metadata in metadatas! {
                    
                if metadata.e2eEncrypted || (metadata.session != "" && metadata.session != k_upload_session_extension) { continue }
                    
                fileProviderUtility.sharedInstance.createocIdentifierOnFileSystem(metadata: metadata)
                        
                let parentItemIdentifier = fileProviderUtility.sharedInstance.getParentItemIdentifier(metadata: metadata, homeServerUrl: fileProviderData.sharedInstance.homeServerUrl)
                if parentItemIdentifier != nil {
                    let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier!)
                    items.append(item)
                }
            }
            observer.didEnumerate(items)
        }
        
        if (items.count == fileProviderData.sharedInstance.itemForPage) {
            numPage += 1
            let providerPage = NSFileProviderPage("\(numPage)".data(using: .utf8)!)
            observer.finishEnumerating(upTo: providerPage)
        } else {
            observer.finishEnumerating(upTo: nil)
        }
    }
        
    func readFileOrFolder(serverUrl: String, completionHandler: @escaping () -> Void) {
        
        NCCommunication.sharedInstance.readFileOrFolder(serverUrlFileName: serverUrl, depth: "0", showHiddenFiles: CCUtility.getShowHiddenFiles(), customUserAgent: nil, addCustomHeaders: nil, account: fileProviderData.sharedInstance.account, completionHandler: { (account, files, errorCode, errorDescription) in
            
            var needReadFolder = true
        
            if let tableDirectory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) {
                if errorCode == 0 && files != nil && files!.count == 1 {
                    if tableDirectory.etag == files![0].etag {
                        needReadFolder = false
                    }
                }
            }
            
            if needReadFolder {

                NCCommunication.sharedInstance.readFileOrFolder(serverUrlFileName: serverUrl, depth: "1", showHiddenFiles: CCUtility.getShowHiddenFiles(), customUserAgent: nil, addCustomHeaders: nil, account: fileProviderData.sharedInstance.account, completionHandler: { (account, files, errorCode, errorDescription) in
                    
                    if errorCode == 0 && files != nil {
                        
                       let fileFolder = files![0]
                                                
                        // Add directory
                        NCManageDatabase.sharedInstance.addDirectory(encrypted: fileFolder.e2eEncrypted, favorite: fileFolder.favorite, ocId: fileFolder.ocId, fileId: fileFolder.fileId, etag: fileFolder.etag, permissions: fileFolder.permissions, serverUrl: serverUrl, richWorkspace: fileFolder.richWorkspace, account: account)
                        
                        // Save status transfer metadata
                        let metadatasInDownload = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND (status == %d OR status == %d OR status == %d OR status == %d)", account, serverUrl, k_metadataStatusWaitDownload, k_metadataStatusInDownload, k_metadataStatusDownloading, k_metadataStatusDownloadError), sorted: nil, ascending: false)
                        
                        let metadatasInUpload = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND (status == %d OR status == %d OR status == %d OR status == %d)", account, serverUrl, k_metadataStatusWaitUpload, k_metadataStatusInUpload, k_metadataStatusUploading, k_metadataStatusUploadError), sorted: nil, ascending: false)

                        // Delete metadata
                        NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND status == %d", account, serverUrl, k_metadataStatusNormal))

                        // Add metadata
                        NCManageDatabase.sharedInstance.addMetadatas(files: files, account: account)
                         
                        if metadatasInDownload != nil {
                            NCManageDatabase.sharedInstance.addMetadatas(metadatasInDownload!)
                        }
                        if metadatasInUpload != nil {
                            NCManageDatabase.sharedInstance.addMetadatas(metadatasInUpload!)
                        }
                    }
                    completionHandler()
                })
            } else {
                completionHandler()
            }
        })
    }
    
    func readFolder(serverUrl: String, page: Int, limit: Int, completionHandler: @escaping (_ metadatas: [tableMetadata]?) -> Void) {
        
        let offset = (page - 1) * limit
        let serverUrl = fileProviderData.sharedInstance.accountUrl
        var fileNamePath = "/"
        
        if serverUrl != fileProviderData.sharedInstance.accountUrl {
            fileNamePath = CCUtility.returnPathfromServerUrl(serverUrl, activeUrl: fileProviderData.sharedInstance.accountUrl)!
        }
        
        NCCommunication.sharedInstance.iosHelper(serverUrl: serverUrl, fileNamePath: fileNamePath, offset: offset, limit: limit, customUserAgent: nil, addCustomHeaders: nil, account: fileProviderData.sharedInstance.account) { (account, files, errorCode, errorDescription) in
            
             if errorCode == 0 && files != nil  && files!.count >= 1 {
                                
                NCManageDatabase.sharedInstance.convertNCFilesToMetadatas(files!, useMetadataFolder: true, account: account) { (metadataFolder, metadatasFolder, metadatas) in
                    
                    // Prepare DB
                    if offset == 0 {
                        NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND status == %d", account, serverUrl, k_metadataStatusNormal))
                        NCManageDatabase.sharedInstance.setDateReadDirectory(serverUrl: serverUrl, account: account)
                        let metadatasInDownload = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND (status == %d OR status == %d OR status == %d OR status == %d)", account, serverUrl, k_metadataStatusWaitDownload, k_metadataStatusInDownload, k_metadataStatusDownloading, k_metadataStatusDownloadError), sorted: nil, ascending: false)
                        let metadatasInUpload = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND (status == %d OR status == %d OR status == %d OR status == %d)", account, serverUrl, k_metadataStatusWaitUpload, k_metadataStatusInUpload, k_metadataStatusUploading, k_metadataStatusUploadError), sorted: nil, ascending: false)
                        if metadatasInDownload != nil {
                            NCManageDatabase.sharedInstance.addMetadatas(metadatasInDownload!)
                        }
                        if metadatasInUpload != nil {
                            NCManageDatabase.sharedInstance.addMetadatas(metadatasInUpload!)
                        }
                    }
                    
                    NCManageDatabase.sharedInstance.addMetadatas(metadatas)
                }
            }
            
            let metadatas = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", fileProviderData.sharedInstance.account, serverUrl), page: page, limit: fileProviderData.sharedInstance.itemForPage, sorted: "fileName", ascending: true)
            
            completionHandler(metadatas)
        }
    }
    
}
