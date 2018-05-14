//
//  FileProviderItem.swift
//  Files
//
//  Created by Marino Faggiana on 26/03/18.
//  Copyright © 2018 TWS. All rights reserved.
//

import FileProvider

class FileProviderItemNC: NSObject, NSFileProviderItem {

    let metadataDB: tableMetadata
    var itemIdentifier: NSFileProviderItemIdentifier
    
    // TODO: implement an initializer to create an item from your extension's backing model
    // TODO: implement the accessors to return the values from your extension's backing model
    
    var parentItemIdentifier: NSFileProviderItemIdentifier {
        if #available(iOSApplicationExtension 11.0, *) {
            return NSFileProviderItemIdentifier.rootContainer
        } else {
            return NSFileProviderItemIdentifier("")
        }
    }
    
    var capabilities: NSFileProviderItemCapabilities {
        return .allowsAll
    }
    
    var filename: String {
        return metadataDB.fileName
    }
    
    var typeIdentifier: String {
        return metadataDB.typeFile
    }
    
    var documentSize: NSNumber? {
        return 112000
    }
    
    var contentModificationDate: Date? {
        return NSDate() as Date
    }
    
    var creationDate: Date? {
        return NSDate() as Date
    }
    
    init(metadata: tableMetadata, serverUrl: String, ii: NSFileProviderItemIdentifier) {
        metadataDB = metadata
        self.itemIdentifier = ii
    }
}
