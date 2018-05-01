//
//  FileProviderEnumeratorWorkingSet.swift
//  PickerFileProvider
//
//  Created by Marino Faggiana on 30/04/18.
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

class FileProviderEnumeratorWorkingSet: NSObject, NSFileProviderEnumerator {
    
    var enumeratedItemIdentifier: NSFileProviderItemIdentifier
    
    init(enumeratedItemIdentifier: NSFileProviderItemIdentifier) {
        self.enumeratedItemIdentifier = enumeratedItemIdentifier
        super.init()
    }
    
    func invalidate() {
    }
    
    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        
        var items: [NSFileProviderItemProtocol] = []
        
        // Tag
        let tags = NCManageDatabase.sharedInstance.getTags(predicate: NSPredicate(format: "account = %@", account))
        for tag in tags {
            
            if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileID = %@", account, tag.fileID))  {
                
                guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
                    continue
                }
                
                let item = FileProviderItem(metadata: metadata, serverUrl: serverUrl)
                items.append(item)
            }
        }
        
        // Favorite
        let metadatas = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account = %@ AND favorite = true", account), sorted: "fileName", ascending: true)
        if metadatas != nil {
            for metadata in metadatas! {
            
                guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
                    continue
                }
                
                let item = FileProviderItem(metadata: metadata, serverUrl: serverUrl)
                items.append(item)
            }
        }
        
        observer.didEnumerate(items)
        observer.finishEnumerating(upTo: nil)
    }
    
    func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
        if updateItem != nil {
            observer.didUpdate([updateItem!])
        }
        observer.finishEnumeratingChanges(upTo: anchor, moreComing: false)
    }
    
    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        let anchor = NSFileProviderSyncAnchor("WorkingSet".data(using: .utf8)!)
        completionHandler(anchor)
    }
}
