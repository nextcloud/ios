//
//  FileProviderItem.swift
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

class FileProviderItem: NSObject, NSFileProviderItem {

    // TODO: implement an initializer to create an item from your extension's backing model
    // TODO: implement the accessors to return the values from your extension's backing model

    // Providing Required Properties
    var itemIdentifier: NSFileProviderItemIdentifier                // The item's persistent identifier
    var filename: String = ""                                       // The item's filename
    var typeIdentifier: String = ""                                 // The item's uniform type identifiers
    var capabilities: NSFileProviderItemCapabilities {              // The item's capabilities
        
        if (self.isDirectory) {
            return [ .allowsAddingSubItems, .allowsContentEnumerating, .allowsReading, .allowsDeleting ]
        } else {
            return [ .allowsReading, .allowsDeleting ]
        }
    }
    
    // Managing Content
    var childItemCount: NSNumber?                                   // The number of items contained by this item
    var documentSize: NSNumber?                                     // The document's size, in bytes

    // Specifying Content Location
    var parentItemIdentifier: NSFileProviderItemIdentifier          // The persistent identifier of the item's parent folder
    var isTrashed: Bool = false                                     // A Boolean value that indicates whether an item is in the trash
   
    // Tracking Usage
    var contentModificationDate: Date?                              // The date the item was last modified
    var creationDate: Date?                                         // The date the item was created
    //var lastUsedDate: Date?                                         // The date the item was last used

    // Tracking Versions
    var versionIdentifier: Data?                                    // A data value used to determine when the item changes
    var isMostRecentVersionDownloaded: Bool = false                 // A Boolean value that indicates whether the item is the most recent version downloaded from the server

    // Monitoring File Transfers
    var isUploading: Bool = false                                   // A Boolean value that indicates whether the item is currently uploading to your remote server
    var isUploaded: Bool = true                                     // A Boolean value that indicates whether the item has been uploaded to your remote server
    var uploadingError: Error?                                      // An error that occurred while uploading to your remote server
    
    var isDownloading: Bool = false                                 // A Boolean value that indicates whether the item is currently downloading from your remote server
    var isDownloaded: Bool = true                                   // A Boolean value that indicates whether the item has been downloaded from your remote server
    var downloadingError: Error?                                    // An error that occurred while downloading the item

    var tagData: Data?                                              // Tag
    
    var isDirectory = false;
    
    init(metadata: tableMetadata, serverUrl: String) {
        
        self.contentModificationDate = metadata.date as Date
        self.creationDate = metadata.date as Date
        self.documentSize = NSNumber(value: metadata.size)
        self.filename = metadata.fileNameView
        self.itemIdentifier = NSFileProviderItemIdentifier("\(metadata.fileID)")
        self.isDirectory = metadata.directory

        // parentItemIdentifier
        if #available(iOSApplicationExtension 11.0, *) {
            
            self.parentItemIdentifier = NSFileProviderItemIdentifier.rootContainer
            
            // NOT .rootContainer
            if (serverUrl != homeServerUrl) {
                if let directoryParent = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account = %@ AND directoryID = %@", metadata.account, metadata.directoryID))  {
                    if let metadataParent = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "account = %@ AND fileID = %@", metadata.account, directoryParent.fileID))  {
                        self.parentItemIdentifier = NSFileProviderItemIdentifier(metadataParent.fileID)
                    }
                }
            }
            
        } else {
            // < iOS 11
            self.parentItemIdentifier = NSFileProviderItemIdentifier("")
        }
        
        // typeIdentifier
        if let fileType = CCUtility.insertTypeFileIconName(metadata.fileNameView, metadata: metadata) {
            self.typeIdentifier = fileType 
        }
        self.versionIdentifier = metadata.etag.data(using: .utf8)
        
        // Verify file exists on cache
        if (!metadata.directory) {
            
            let identifierPathUrl = groupURL!.appendingPathComponent("File Provider Storage").appendingPathComponent(metadata.fileID)
            let filePath = "\(identifierPathUrl.path)/\(metadata.fileNameView)"
            var fileSize = 0 as Double
            
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
                fileSize = attributes[FileAttributeKey.size] as! Double
            } catch let error {
                print("error: \(error)")
            }
            
            if fileSize == 0 {
                self.isDownloaded = false
                self.isMostRecentVersionDownloaded = false
            } else {
                self.isDownloaded = true
                self.isMostRecentVersionDownloaded = true
            }
        }
        
        // Tag
        if let tableTag = NCManageDatabase.sharedInstance.getTag(predicate: NSPredicate(format: "account = %@ AND fileID = %@", metadata.account, metadata.fileID)) {
            tagData = tableTag.tagIOS.data(using: .utf8)
        }
    }
}
