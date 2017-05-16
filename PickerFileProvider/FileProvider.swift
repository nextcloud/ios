//
//  FileProvider.swift
//  PickerFileProvider
//
//  Created by Marino Faggiana on 27/12/16.
//  Copyright © 2017 TWS. All rights reserved.
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
        
        guard let fileData = try? Data(contentsOf: url) else {
            // NOTE: you would generate an NSError to supply to the completionHandler
            // here however that is outside of the scope for this tutorial
            completionHandler?(nil)
            return
        }
        
        do {
            _ = try fileData.write(to: url, options: NSData.WritingOptions())
            completionHandler?(nil)
        } catch let error as NSError {
            print("error writing file to URL")
            completionHandler?(error)
        }
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
