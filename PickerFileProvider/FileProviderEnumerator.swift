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
    let recordForPage = 15
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
        
        if enumeratedItemIdentifier == .workingSet {
            
            items = selectItemWorkingSet()
            
            observer.didEnumerate(items)
            observer.finishEnumerating(upTo: nil)
            return
        }
        
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
            if (items.count == self.recordForPage) {
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
                if let metadataDB = NCManageDatabase.sharedInstance.addMetadatas(metadatas as! [tableMetadata], serverUrl: serverUrl) {
                    items = self.selectItems(numPage: 0, account: self.providerData.account, metadatas: metadataDB)
                    if (items.count > 0) {
                        observer.didEnumerate(items)
                    }
                }
            }
                
            if (items.count == self.recordForPage) {
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
            if (items.count == self.recordForPage) {
                let providerPage = NSFileProviderPage("1".data(using: .utf8)!)
                observer.finishEnumerating(upTo: providerPage)
            } else {
                observer.finishEnumerating(upTo: nil)
            }
        })
    }
    
    func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
        
        guard #available(iOS 11, *) else { return }
    
        // Report the trashed items since last signal
        //
        observer.didDeleteItems(withIdentifiers: fileProviderSignalDeleteItemIdentifier)
        
        // Report the updated items since last signal
        //
        observer.didUpdate(fileProviderSignalUpdateItem)
        
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
        let start = numPage * self.recordForPage + 1
        let stop = start + (self.recordForPage - 1)
        var counter = 0
        
        for metadata in metadatas {
            
            // E2EE Remove
            if metadata.e2eEncrypted || metadata.status == Double(k_metadataStatusHide) || metadata.session != "" {
                continue
            }
            
            counter += 1
            if (counter >= start && counter <= stop) {
                
                if metadata.directory == false {
                    providerData.createFileIdentifierOnFileSystem(metadata: metadata)
                }

                let parentItemIdentifier = providerData.getParentItemIdentifier(metadata: metadata)
                if parentItemIdentifier != nil {
                    let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier!, providerData: providerData)
                    items.append(item)
                }
            }
        }
        
        return items
    }
    
    func selectItemWorkingSet() -> [NSFileProviderItemProtocol] {
        
        var items: [NSFileProviderItemProtocol] = []

        // Tag
        let tags = NCManageDatabase.sharedInstance.getTags(predicate: NSPredicate(format: "account = %@", providerData.account))
        for tag in tags {
            
            if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileID = %@", providerData.account, tag.fileID))  {
                
                if metadata.directory == false {
                    providerData.createFileIdentifierOnFileSystem(metadata: metadata)
                }
                
                let parentItemIdentifier = providerData.getParentItemIdentifier(metadata: metadata)
                if parentItemIdentifier != nil {
                    let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier!, providerData: providerData)
                    items.append(item)
                }
            }
        }
        return items
    }
    
}
