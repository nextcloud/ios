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

class FileProvider: NSFileProviderExtension, CCNetworkingDelegate {

    lazy var networkingOperationQueue: OperationQueue = {
        
        var queue = OperationQueue()
        queue.name = k_queue
        queue.maxConcurrentOperationCount = 10
        
        return queue
    }()

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
        
        guard let result = NCManageDatabase.sharedInstance.getAccountActive() else {
            return
        }
        
        let fileName = url.lastPathComponent
        let directoryUser = CCUtility.getDirectoryActiveUser(result.user, activeUrl: result.url)
        let destinationURLDirectoryUser = URL(string: "file://\(directoryUser!)/\(fileName)".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)!
        var serverUrl = CCUtility.getHomeServerUrlActiveUrl(result.url)

        // copy sourceURL on directoryUser
        do {
            try FileManager.default.removeItem(at: destinationURLDirectoryUser)
        } catch _ {
            print("file do not exists")
        }
        
        do {
            try FileManager.default.copyItem(at: url, to: destinationURLDirectoryUser)
        } catch _ {
            print("file do not exists")
            return
        }

        // Get serverUrl
        if let fileID = CCUtility.getFileIDPicker() {
            if let metadata = NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "fileID == %@", fileID)) {
                if metadata.fileName == fileName {
                    serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID)
                }
            }
        }
        
        // verifica se esiste già in coda
        
        if NCManageDatabase.sharedInstance.getMetadata(predicate: NSPredicate(format: "fileName == %@ AND serverUrl == %@ AND session == %@", fileName, serverUrl!, k_upload_session_foreground)) == nil {
            
            CCNetworking.shared().settingDelegate(self)
            CCNetworking.shared().uploadFile(fileName, serverUrl: serverUrl, cryptated: false, onlyPlist: false, session: k_upload_session_foreground, taskStatus: Int(k_taskStatusSuspend), selector: nil, selectorPost: nil, errorCode: 0, delegate: self)
        }
        
        self.stopProvidingItem(at: url)
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
    
    // UTILITY //
    
    func appGroupContainerURL() -> URL? {
        
        guard let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.sharedInstance.capabilitiesGroups) else {
                return nil
        }
        
        let storagePathUrl = groupURL.appendingPathComponent("File Provider Storage")
        let storagePath = storagePathUrl.path
        
        if !FileManager.default.fileExists(atPath: storagePath) {
            do {
                try FileManager.default.createDirectory(atPath: storagePath, withIntermediateDirectories: false, attributes: nil)
            } catch let error {
                print("error creating filepath: \(error)")
                return nil
            }
        }
        
        return storagePathUrl
    }


}
