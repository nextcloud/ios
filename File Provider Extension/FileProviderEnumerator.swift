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
        var metadatasFromDB: [tableMetadata]?
        
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
            
            guard let serverUrl = serverUrl else {
                observer.finishEnumerating(upTo: nil)
                return
            }
            
            // Select items from database
            metadatasFromDB = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", fileProviderData.sharedInstance.account, serverUrl), sorted: "fileName", ascending: true)
            
            // Calculate current page
            if (page != NSFileProviderPage.initialPageSortedByDate as NSFileProviderPage && page != NSFileProviderPage.initialPageSortedByName as NSFileProviderPage) {
                
                var numPage = Int(String(data: page.rawValue, encoding: .utf8)!)!
                
                if (metadatasFromDB != nil) {
                    items = self.selectItems(numPage: numPage, account: fileProviderData.sharedInstance.account, metadatas: metadatasFromDB!)
                    observer.didEnumerate(items)
                }
                if (items.count == fileProviderData.sharedInstance.itemForPage) {
                    numPage += 1
                    let providerPage = NSFileProviderPage("\(numPage)".data(using: .utf8)!)
                    observer.finishEnumerating(upTo: providerPage)
                } else {
                    observer.finishEnumerating(upTo: nil)
                }
                return
            }
            
            // Update the WorkingSet -> Favorite
            fileProviderData.sharedInstance.updateFavoriteForWorkingSet()
            
            // Read
            var fileName: String?
            var serverUrlForFileName = fileProviderData.sharedInstance.homeServerUrl
            
            if serverUrl != fileProviderData.sharedInstance.homeServerUrl {
                fileName = (serverUrl as NSString).lastPathComponent
                serverUrlForFileName = (serverUrl as NSString).deletingLastPathComponent
            }
            
            // +++ TEST +++
            /*
            OCNetworking.sharedManager()?.search(withAccount: fileProviderData.sharedInstance.account, folder: serverUrl, fileName:"", dateLastModified: nil, numberOfItem: 2, completion: { (account, metadatas, message, errorCode) in
                print(message ?? "NO MESSAGE")
            })
            */
            // ++++++++++++
            
            OCNetworking.sharedManager().readFile(withAccount: fileProviderData.sharedInstance.account, serverUrl: serverUrlForFileName, fileName: fileName, completion: { (account, metadata, message, errorCode) in

                if errorCode == 0 && account == fileProviderData.sharedInstance.account {
                    
                    if fileProviderData.sharedInstance.listServerUrlEtag[serverUrl] == nil || fileProviderData.sharedInstance.listServerUrlEtag[serverUrl] != metadata!.etag || metadatasFromDB == nil {
                        
                        OCNetworking.sharedManager().readFolder(withAccount: fileProviderData.sharedInstance.account, serverUrl: serverUrl, depth: "1", completion: { (account, metadatas, metadataFolder, message, errorCode) in
                            
                            if errorCode == 0 && account == fileProviderData.sharedInstance.account {
                                
                                if metadataFolder != nil {
                                    // Update directory etag
                                    NCManageDatabase.sharedInstance.setDirectory(serverUrl: serverUrl, serverUrlTo: nil, etag: metadataFolder!.etag, ocId: metadataFolder!.ocId, encrypted: metadataFolder!.e2eEncrypted, account: fileProviderData.sharedInstance.account)
                                    // Save etag for this serverUrl
                                    fileProviderData.sharedInstance.listServerUrlEtag[serverUrl] = metadataFolder!.etag
                                }
                                
                                if metadatas != nil {
                                    
                                    NCManageDatabase.sharedInstance.deleteMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND (status == %d OR status == %d)", fileProviderData.sharedInstance.account, serverUrl, k_metadataStatusNormal, k_metadataStatusHide))
                                    
                                    NCManageDatabase.sharedInstance.setDateReadDirectory(serverUrl: serverUrl, account: fileProviderData.sharedInstance.account)
                                    
                                    let metadatasInDownload = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND (status == %d OR status == %d OR status == %d OR status == %d)", fileProviderData.sharedInstance.account, serverUrl, k_metadataStatusWaitDownload, k_metadataStatusInDownload, k_metadataStatusDownloading, k_metadataStatusDownloadError), sorted: nil, ascending: false)
                                    
                                    _ = NCManageDatabase.sharedInstance.addMetadatas(metadatas as! [tableMetadata])
                                    if metadatasInDownload != nil {
                                        _ = NCManageDatabase.sharedInstance.addMetadatas(metadatasInDownload!)
                                    }
                                }
                                
                                metadatasFromDB = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", fileProviderData.sharedInstance.account, serverUrl), sorted: "fileName", ascending: true)
                                
                                self.selectFirstPageItems(metadatasFromDB, observer: observer)
                                
                            } else if errorCode != 0 {
                                
                                self.selectFirstPageItems(metadatasFromDB, observer: observer)
                            }
                        })
                        
                    } else {
                        
                        self.selectFirstPageItems(metadatasFromDB, observer: observer)
                    }
                    
                } else {
                    self.selectFirstPageItems(metadatasFromDB, observer: observer)
                }
            })
        }
    }
    
    func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
            
        var itemsDelete = [NSFileProviderItemIdentifier]()
        var itemsUpdate = [FileProviderItem]()
        
        // Report the deleted items
        //
        if enumeratedItemIdentifier == .workingSet {
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
        if enumeratedItemIdentifier == .workingSet {
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
    //  MARK: - User Function
    // --------------------------------------------------------------------------------------------

    func selectFirstPageItems(_ metadatas: [tableMetadata]?, observer: NSFileProviderEnumerationObserver) {
        
        var items: [NSFileProviderItemProtocol] = []
        
        if (metadatas != nil) {
            items = self.selectItems(numPage: 0, account: fileProviderData.sharedInstance.account, metadatas: metadatas!)
            observer.didEnumerate(items)
        }
        if (items.count == fileProviderData.sharedInstance.itemForPage) {
            let providerPage = NSFileProviderPage("1".data(using: .utf8)!)
            observer.finishEnumerating(upTo: providerPage)
        } else {
            observer.finishEnumerating(upTo: nil)
        }
    }
    
    func selectItems(numPage: Int, account: String, metadatas: [tableMetadata]) -> [NSFileProviderItemProtocol] {
        
        var items: [NSFileProviderItemProtocol] = []
        let start = numPage * fileProviderData.sharedInstance.itemForPage + 1
        let stop = start + (fileProviderData.sharedInstance.itemForPage - 1)
        var counter = 0
        
        autoreleasepool {
            
            for metadata in metadatas {
                
                // E2EE Remove
                if metadata.e2eEncrypted || metadata.status == Int(k_metadataStatusHide) || (metadata.session != "" && metadata.session != k_download_session_extension && metadata.session != k_upload_session_extension) { continue }
                
                counter += 1
                if (counter >= start && counter <= stop) {
                    
                    fileProviderUtility.sharedInstance.createocIdentifierOnFileSystem(metadata: metadata)
                    
                    let parentItemIdentifier = fileProviderUtility.sharedInstance.getParentItemIdentifier(metadata: metadata, homeServerUrl: fileProviderData.sharedInstance.homeServerUrl)
                    if parentItemIdentifier != nil {
                        let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier!)
                        items.append(item)
                    }
                }
            }
        }
        return items
    }
}
