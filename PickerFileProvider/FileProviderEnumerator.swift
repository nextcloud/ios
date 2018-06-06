//
//  FileProviderEnumerator.swift
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

class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
    
    var enumeratedItemIdentifier: NSFileProviderItemIdentifier
    var serverUrl: String?
    var providerData: FileProviderData
    
    init(enumeratedItemIdentifier: NSFileProviderItemIdentifier, providerData: FileProviderData) {
        
        self.enumeratedItemIdentifier = enumeratedItemIdentifier
        self.providerData = providerData
        
        // Select ServerUrl
        if #available(iOSApplicationExtension 11.0, *) {

            if (enumeratedItemIdentifier == .rootContainer) {
                serverUrl = providerData.homeServerUrl
            } else {
                
                let metadata = providerData.getTableMetadataFromItemIdentifier(enumeratedItemIdentifier)
                if metadata != nil  {
                    if let directorySource = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account = %@ AND directoryID = %@", providerData.account, metadata!.directoryID))  {
                        serverUrl = directorySource.serverUrl + "/" + metadata!.fileName
                    }
                }
            }
        }
        
        super.init()
    }

    func invalidate() {
        // perform invalidation of server connection if necessary
    }

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        
        var items: [NSFileProviderItemProtocol] = []
        var metadatas: [tableMetadata]?

        /* ONLY iOS 11*/
        guard #available(iOS 11, *) else {
            observer.finishEnumerating(upTo: nil)
            return
        }
        
        /*** WorkingSet ***/
        if enumeratedItemIdentifier == .workingSet {
            
            var itemIdentifierMetadata = [NSFileProviderItemIdentifier:tableMetadata]()
            
            // ***** Tags *****
            let tags = NCManageDatabase.sharedInstance.getTags(predicate: NSPredicate(format: "account = %@", providerData.account))
            for tag in tags {
                
                guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileID = %@", providerData.account, tag.fileID))  else {
                    continue
                }
                
                providerData.createFileIdentifierOnFileSystem(metadata: metadata)
                    
                itemIdentifierMetadata[providerData.getItemIdentifier(metadata: metadata)] = metadata
            }
            
            // ***** Favorite *****
            listFavoriteIdentifierRank = NCManageDatabase.sharedInstance.getTableMetadatasDirectoryFavoriteIdentifierRank()
            for (identifier, _) in listFavoriteIdentifierRank {
             
                guard let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileID = %@", providerData.account, identifier)) else {
                    continue
                }
               
                itemIdentifierMetadata[ providerData.getItemIdentifier(metadata: metadata)] = metadata
            }
            
            // create items
            for (_, metadata) in itemIdentifierMetadata {
                let parentItemIdentifier = providerData.getParentItemIdentifier(metadata: metadata)
                if parentItemIdentifier != nil {
                    let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier!, providerData: providerData)
                    items.append(item)
                }
            }
            
            observer.didEnumerate(items)
            observer.finishEnumerating(upTo: nil)
            
        } else {
        
        /*** ServerUrl ***/
            
            guard let serverUrl = serverUrl else {
                observer.finishEnumerating(upTo: nil)
                return
            }
            
            // Select items from database
            if let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account = %@ AND serverUrl = %@", providerData.account, serverUrl))  {
                metadatas = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account = %@ AND directoryID = %@", providerData.account, directory.directoryID), sorted: "fileName", ascending: true)
            }
            
            // Calculate current page
            if (page != NSFileProviderPage.initialPageSortedByDate as NSFileProviderPage && page != NSFileProviderPage.initialPageSortedByName as NSFileProviderPage) {
                
                var numPage = Int(String(data: page.rawValue, encoding: .utf8)!)!
                
                if (metadatas != nil) {
                    items = self.selectItems(numPage: numPage, account: providerData.account, metadatas: metadatas!)
                    observer.didEnumerate(items)
                }
                if (items.count == providerData.itemForPage) {
                    numPage += 1
                    let providerPage = NSFileProviderPage("\(numPage)".data(using: .utf8)!)
                    observer.finishEnumerating(upTo: providerPage)
                } else {
                    observer.finishEnumerating(upTo: nil)
                }
                return
            }
            
            let ocNetworking = OCnetworking.init(delegate: nil, metadataNet: nil, withUser: providerData.accountUser, withUserID: providerData.accountUserID, withPassword: providerData.accountPassword, withUrl: providerData.accountUrl)
            ocNetworking?.readFolder(serverUrl, depth: "1", account: providerData.account, success: { (metadatas, metadataFolder, directoryID) in
                
                if (metadatas != nil) {
                    NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "account = %@ AND directoryID = %@ AND session = ''", self.providerData.account, directoryID!), clearDateReadDirectoryID: directoryID!)
                    _ = NCManageDatabase.sharedInstance.addMetadatas(metadatas as! [tableMetadata], serverUrl: serverUrl)
                    if let metadataDB = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account = %@ AND directoryID = %@", self.providerData.account, directoryID!), sorted: "fileName", ascending: true) {
                        items = self.selectItems(numPage: 0, account: self.providerData.account, metadatas: metadataDB)
                        if (items.count > 0) {
                            observer.didEnumerate(items)
                        }
                    }
                }
                
                if (items.count == self.providerData.itemForPage) {
                    let providerPage = NSFileProviderPage("1".data(using: .utf8)!)
                    observer.finishEnumerating(upTo: providerPage)
                } else {
                    observer.finishEnumerating(upTo: nil)
                }
                
            }, failure: { (errorMessage, errorCode) in
                
                // select item from database
                if (metadatas != nil) {
                    items = self.selectItems(numPage: 0, account: self.providerData.account, metadatas: metadatas!)
                    observer.didEnumerate(items)
                }
                if (items.count == self.providerData.itemForPage) {
                    let providerPage = NSFileProviderPage("1".data(using: .utf8)!)
                    observer.finishEnumerating(upTo: providerPage)
                } else {
                    observer.finishEnumerating(upTo: nil)
                }
            })
        }
    }
    
    func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
        
        guard #available(iOS 11, *) else { return }
    
        var itemsDelete = [NSFileProviderItemIdentifier]()
        var itemsUpdate = [FileProviderItem]()
        
        // Report the deleted items
        //
        if enumeratedItemIdentifier == .workingSet {
            queueTradeSafe.sync() {
                for (itemIdentifier, _) in fileProviderSignalDeleteWorkingSetItemIdentifier {
                    itemsDelete.append(itemIdentifier)
                }
            }
            queueTradeSafe.sync(flags: .barrier) {
                fileProviderSignalDeleteWorkingSetItemIdentifier.removeAll()
            }
        } else {
            queueTradeSafe.sync() {
                for (itemIdentifier, _) in fileProviderSignalDeleteContainerItemIdentifier {
                    itemsDelete.append(itemIdentifier)
                }
            }
            queueTradeSafe.sync(flags: .barrier) {
                fileProviderSignalDeleteContainerItemIdentifier.removeAll()
            }
        }
            
        // Report the updated items
        //
        if enumeratedItemIdentifier == .workingSet {
            queueTradeSafe.sync() {
                for (itemIdentifier, item) in fileProviderSignalUpdateWorkingSetItem {
                    let account = providerData.getAccountFromItemIdentifier(itemIdentifier)
                    if account != nil && account == providerData.account {
                        itemsUpdate.append(item)
                    } else {
                        itemsDelete.append(itemIdentifier)
                    }
                }
            }
            queueTradeSafe.sync(flags: .barrier) {
                fileProviderSignalUpdateWorkingSetItem.removeAll()
            }
        } else {
            queueTradeSafe.sync(flags: .barrier) {
                for (itemIdentifier, item) in fileProviderSignalUpdateContainerItem {
                    let account = providerData.getAccountFromItemIdentifier(itemIdentifier)
                    if account != nil && account == providerData.account {
                        itemsUpdate.append(item)
                    } else {
                        itemsDelete.append(itemIdentifier)
                    }
                }
            }
            queueTradeSafe.sync(flags: .barrier) {
                fileProviderSignalUpdateContainerItem.removeAll()
            }
        }
            
        observer.didDeleteItems(withIdentifiers: itemsDelete)
        observer.didUpdate(itemsUpdate)
            
        let data = "\(currentAnchor)".data(using: .utf8)
        observer.finishEnumeratingChanges(upTo: NSFileProviderSyncAnchor(data!), moreComing: false)
    }
    
    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        let data = "\(currentAnchor)".data(using: .utf8)
        completionHandler(NSFileProviderSyncAnchor(data!))
    }
    
    // --------------------------------------------------------------------------------------------
    //  MARK: - User Function
    // --------------------------------------------------------------------------------------------

    func selectItems(numPage: Int, account: String, metadatas: [tableMetadata]) -> [NSFileProviderItemProtocol] {
        
        var items: [NSFileProviderItemProtocol] = []
        let start = numPage * providerData.itemForPage + 1
        let stop = start + (providerData.itemForPage - 1)
        var counter = 0
        
        autoreleasepool {
            for metadata in metadatas {
                
                // E2EE Remove
                if metadata.e2eEncrypted || metadata.status == Double(k_metadataStatusHide) || (metadata.session != "" && metadata.session != k_download_session_extension && metadata.session != k_upload_session_extension) {
                    continue
                }
                
                counter += 1
                if (counter >= start && counter <= stop) {
                    
                    providerData.createFileIdentifierOnFileSystem(metadata: metadata)
                    
                    let parentItemIdentifier = providerData.getParentItemIdentifier(metadata: metadata)
                    if parentItemIdentifier != nil {
                        let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier!, providerData: providerData)
                        items.append(item)
                    }
                }
            }
        }
        return items
    }

}
