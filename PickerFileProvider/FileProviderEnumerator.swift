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
    let recordForPage = 10
    var serverUrl: String?
    
    init(enumeratedItemIdentifier: NSFileProviderItemIdentifier) {
        
        self.enumeratedItemIdentifier = enumeratedItemIdentifier
        
        // Select ServerUrl
        if #available(iOSApplicationExtension 11.0, *) {

            if (enumeratedItemIdentifier == .rootContainer) {
                serverUrl = homeServerUrl
            } else {
                if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileID = %@", account, enumeratedItemIdentifier.rawValue))  {
                    if let directorySource = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account = %@ AND directoryID = %@", account, metadata.directoryID))  {
                        serverUrl = directorySource.serverUrl + "/" + metadata.fileName
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

        if #available(iOSApplicationExtension 11.0, *) {
            
            // clear list update items
            listUpdateItems.removeAll()
            
            guard let serverUrl = serverUrl else {
                observer.finishEnumerating(upTo: nil)
                return
            }
            
            // Select items from database
            if let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account = %@ AND serverUrl = %@", account, serverUrl))  {
                metadatas = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account = %@ AND directoryID = %@", account, directory.directoryID), sorted: "fileName", ascending: true)
            }
            
            // Calculate current page
            if (page != NSFileProviderPage.initialPageSortedByDate as NSFileProviderPage && page != NSFileProviderPage.initialPageSortedByName as NSFileProviderPage) {
                
                var numPage = Int(String(data: page.rawValue, encoding: .utf8)!)!
                
                if (metadatas != nil) {
                    items = self.selectItems(numPage: numPage, account: account, serverUrl: serverUrl, metadatas: metadatas!)
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
            
            // Read Folder
            ocNetworking?.readFolder(withServerUrl: serverUrl, depth: "1", account: account, success: { (metadatas, metadataFolder, directoryID) in
                
                if (metadatas != nil) {
                    NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "account = %@ AND directoryID = %@ AND session = ''", account, directoryID!), clearDateReadDirectoryID: directoryID!)
                    if let metadataDB = NCManageDatabase.sharedInstance.addMetadatas(metadatas as! [tableMetadata], serverUrl: serverUrl) {
                        items = self.selectItems(numPage: 0, account: account, serverUrl: serverUrl, metadatas: metadataDB)
                        observer.didEnumerate(items)
                    }
                }
                
                if (items.count == self.recordForPage) {
                    let providerPage = NSFileProviderPage("1".data(using: .utf8)!)
                    observer.finishEnumerating(upTo: providerPage)
                } else {
                    observer.finishEnumerating(upTo: nil)
                }
                
            }, failure: { (message, errorCode) in
                
                // select item from database
                if (metadatas != nil) {
                    items = self.selectItems(numPage: 0, account: account, serverUrl: serverUrl, metadatas: metadatas!)
                    observer.didEnumerate(items)
                }
                if (items.count == self.recordForPage) {
                    let providerPage = NSFileProviderPage("1".data(using: .utf8)!)
                    observer.finishEnumerating(upTo: providerPage)
                } else {
                    observer.finishEnumerating(upTo: nil)
                }
            })
            
        } else {
            // < iOS 11
            observer.finishEnumerating(upTo: nil)
        }
    }
    
    func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
        observer.didUpdate(listUpdateItems)
        observer.finishEnumeratingChanges(upTo: anchor, moreComing: false)
    }
    
    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        guard let serverUrl = serverUrl else {
            return
        }
        let anchor = NSFileProviderSyncAnchor(serverUrl.data(using: .utf8)!)
        completionHandler(anchor)
    }
    
    // --------------------------------------------------------------------------------------------
    //  MARK: - User Function
    // --------------------------------------------------------------------------------------------

    func selectItems(numPage: Int, account: String, serverUrl: String, metadatas: [tableMetadata]) -> [NSFileProviderItemProtocol] {
        
        var items: [NSFileProviderItemProtocol] = []
        let start = numPage * self.recordForPage + 1
        let stop = start + (self.recordForPage - 1)
        var counter = 0
        
        for metadata in metadatas {
            counter += 1
            if (counter >= start && counter <= stop) {
                let item = FileProviderItem(metadata: metadata, serverUrl: serverUrl)
                items.append(item)
            }
        }
        
        return items
    }
}
