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

import UIKit
import FileProvider
import RealmSwift
import NextcloudKit

class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
    var enumeratedItemIdentifier: NSFileProviderItemIdentifier
    var serverUrl: String?
    let providerUtility = fileProviderUtility()
    var recordsPerPage: Int = 20
    var anchor: UInt64 = 0

    init(enumeratedItemIdentifier: NSFileProviderItemIdentifier) {
        self.enumeratedItemIdentifier = enumeratedItemIdentifier
        if enumeratedItemIdentifier == .rootContainer {
            serverUrl = fileProviderData.shared.homeServerUrl
        } else {
            if let metadata = providerUtility.getTableMetadataFromItemIdentifier(enumeratedItemIdentifier),
               let directorySource = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
                serverUrl = directorySource.serverUrl + "/" + metadata.fileName

            }
        }
        super.init()
    }

    func invalidate() { }

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        var items: [NSFileProviderItemProtocol] = []
        /// WorkingSet
        if enumeratedItemIdentifier == .workingSet {
            var itemIdentifierMetadata: [NSFileProviderItemIdentifier: tableMetadata] = [:]
            /// Tags
            let tags = NCManageDatabase.shared.getTags(predicate: NSPredicate(format: "account == %@", fileProviderData.shared.account))
            for tag in tags {
                guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(tag.ocId)  else { continue }
                itemIdentifierMetadata[providerUtility.getItemIdentifier(metadata: metadata)] = metadata
            }
            /// Favorite
            fileProviderData.shared.listFavoriteIdentifierRank = NCManageDatabase.shared.getTableMetadatasDirectoryFavoriteIdentifierRank(account: fileProviderData.shared.account)
            for (identifier, _) in fileProviderData.shared.listFavoriteIdentifierRank {
                guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(identifier) else { continue }
                itemIdentifierMetadata[providerUtility.getItemIdentifier(metadata: metadata)] = metadata
            }
            /// Create items
            for (_, metadata) in itemIdentifierMetadata {
                if let parentItemIdentifier = providerUtility.getParentItemIdentifier(metadata: metadata) {
                    let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
                    items.append(item)
                }
            }
            observer.didEnumerate(items)
            observer.finishEnumerating(upTo: nil)
        } else {
            /// ServerUrl
            guard let serverUrl = serverUrl else {
                observer.finishEnumerating(upTo: nil)
                return
            }
            var pageNumber = 1
            if let stringPage = String(data: page.rawValue, encoding: .utf8),
               let intPage = Int(stringPage) {
                pageNumber = intPage
            }

            self.fetchItemsForPage(serverUrl: serverUrl, pageNumber: pageNumber) { metadatas in
                if let metadatas {
                    for metadata in metadatas {
                        if metadata.e2eEncrypted || (!metadata.session.isEmpty && metadata.session != NCNetworking.shared.sessionUploadBackgroundExtension) {
                            continue
                        }
                        if let parentItemIdentifier = self.providerUtility.getParentItemIdentifier(metadata: metadata) {
                            let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
                            items.append(item)
                        }
                    }
                }

                observer.didEnumerate(items)

                if let metadatas,
                    metadatas.count == self.recordsPerPage {
                    pageNumber += 1
                    let providerPage = NSFileProviderPage("\(pageNumber)".data(using: .utf8)!)
                    observer.finishEnumerating(upTo: providerPage)
                } else {
                    observer.finishEnumerating(upTo: nil)
                }
            }
        }
    }

    func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
        var itemsDelete: [NSFileProviderItemIdentifier] = []
        var itemsUpdate: [FileProviderItem] = []
        // Report the deleted items
        //
        if self.enumeratedItemIdentifier == .workingSet {
            for (itemIdentifier, _) in fileProviderData.shared.fileProviderSignalDeleteWorkingSetItemIdentifier {
                itemsDelete.append(itemIdentifier)
            }
            fileProviderData.shared.fileProviderSignalDeleteWorkingSetItemIdentifier.removeAll()
        } else {
            for (itemIdentifier, _) in fileProviderData.shared.fileProviderSignalDeleteContainerItemIdentifier {
                itemsDelete.append(itemIdentifier)
            }
            fileProviderData.shared.fileProviderSignalDeleteContainerItemIdentifier.removeAll()
        }
        // Report the updated items
        //
        if self.enumeratedItemIdentifier == .workingSet {
            for (_, item) in fileProviderData.shared.fileProviderSignalUpdateWorkingSetItem {
                itemsUpdate.append(item)
            }
            fileProviderData.shared.fileProviderSignalUpdateWorkingSetItem.removeAll()
        } else {
            for (_, item) in fileProviderData.shared.fileProviderSignalUpdateContainerItem {
                itemsUpdate.append(item)
            }
            fileProviderData.shared.fileProviderSignalUpdateContainerItem.removeAll()
        }

        observer.didDeleteItems(withIdentifiers: itemsDelete)
        observer.didUpdate(itemsUpdate)

        let data = "\(self.anchor)".data(using: .utf8)
        observer.finishEnumeratingChanges(upTo: NSFileProviderSyncAnchor(data!), moreComing: false)
    }

    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        let data = "\(self.anchor)".data(using: .utf8)
        completionHandler(NSFileProviderSyncAnchor(data!))
    }

    func fetchItemsForPage(serverUrl: String, pageNumber: Int, completionHandler: @escaping (_ metadatas: Results<tableMetadata>?) -> Void) {
        let predicate = NSPredicate(format: "account == %@ AND serverUrl == %@", fileProviderData.shared.account, serverUrl)

        if pageNumber == 1 {
            NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrl, depth: "1", showHiddenFiles: NCKeychain().showHiddenFiles, account: fileProviderData.shared.account) { _, files, _, error in
                if error == .success {
                    NCManageDatabase.shared.convertFilesToMetadatas(files, useFirstAsMetadataFolder: true) { metadataFolder, metadatas in
                        /// FOLDER
                        NCManageDatabase.shared.addMetadata(metadataFolder)
                        NCManageDatabase.shared.addDirectory(e2eEncrypted: metadataFolder.e2eEncrypted, favorite: metadataFolder.favorite, ocId: metadataFolder.ocId, fileId: metadataFolder.fileId, etag: metadataFolder.etag, permissions: metadataFolder.permissions, richWorkspace: metadataFolder.richWorkspace, serverUrl: serverUrl, account: metadataFolder.account)
                        /// FILES
                        NCManageDatabase.shared.deleteMetadata(predicate: predicate)
                        NCManageDatabase.shared.addMetadatas(metadatas)
                    }
                }
                let resultsMetadata = NCManageDatabase.shared.fetchPagedResults(ofType: tableMetadata.self, primaryKey: "ocId", recordsPerPage: self.recordsPerPage, pageNumber: pageNumber, filter: predicate, sortedByKeyPath: "fileName")
                completionHandler(resultsMetadata)
            }
        } else {
            let resultsMetadata = NCManageDatabase.shared.fetchPagedResults(ofType: tableMetadata.self, primaryKey: "ocId", recordsPerPage: recordsPerPage, pageNumber: pageNumber, filter: predicate, sortedByKeyPath: "fileName")
            completionHandler(resultsMetadata)
        }
    }
}
