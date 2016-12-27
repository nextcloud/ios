//
//  FileProvider.swift
//  PickerFileProvider
//
//  Created by Marino Faggiana on 27/12/16.
//  Copyright © 2016 TWS. All rights reserved.
//

import UIKit

class FileProvider: NSFileProviderExtension {

    var fileCoordinator: NSFileCoordinator {
        let fileCoordinator = NSFileCoordinator()
        fileCoordinator.purposeIdentifier = self.providerIdentifier
        return fileCoordinator
    }
    
    override init() {
        super.init()
        
        self.fileCoordinator.coordinate(writingItemAt: self.documentStorageURL, options: [], error: nil, byAccessor: { newURL in
            // ensure the documentStorageURL actually exists
            do {
                try FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                // Handle error
            }
        })
    }
    
    override func providePlaceholder(at url: URL, completionHandler: ((_ error: Error?) -> Void)?) {
        // Should call writePlaceholderAtURL(_:withMetadata:error:) with the placeholder URL, then call the completion handler with the error if applicable.
        let fileName = url.lastPathComponent
        
        let placeholderURL = NSFileProviderExtension.placeholderURL(for: self.documentStorageURL.appendingPathComponent(fileName))
        
        // TODO: get file size for file at <url> from model
        let fileSize = 0
        let metadata = [AnyHashable(URLResourceKey.fileSizeKey): fileSize]
        do {
            try NSFileProviderExtension.writePlaceholder(at: placeholderURL, withMetadata: metadata)
        } catch {
            // Handle error
        }
        
        completionHandler?(nil)
    }
    
    override func startProvidingItem(at url: URL, completionHandler: ((_ error: Error?) -> Void)?) {
        // Should ensure that the actual file is in the position returned by URLForItemWithIdentifier, then call the completion handler
        
        // TODO: get the contents of file at <url> from model
        let fileData = NSData()
        
        do {
            _ = try fileData.write(to: url, options: [])
        } catch {
            // Handle error
        }
        
        completionHandler?(nil);
    }
    
    
    override func itemChanged(at url: URL) {
        // Called at some point after the file has changed; the provider may then trigger an upload
        
        // TODO: mark file at <url> as needing an update in the model; kick off update process
        NSLog("Item changed at URL %@", url as NSURL)
    }
    
    override func stopProvidingItem(at url: URL) {
        // Called after the last claim to the file has been released. At this point, it is safe for the file provider to remove the content file.
        // Care should be taken that the corresponding placeholder file stays behind after the content file has been deleted.
        
        do {
            _ = try FileManager.default.removeItem(at: url)
        } catch {
            // Handle error
        }
        self.providePlaceholder(at: url, completionHandler: { error in
            // TODO: handle any error, do any necessary cleanup
        })
    }

}
