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
import NextcloudKit

class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
    var enumeratedItemIdentifier: NSFileProviderItemIdentifier
    var serverUrl: String?
    let fpUtility = fileProviderUtility()

    init(enumeratedItemIdentifier: NSFileProviderItemIdentifier) {
        self.enumeratedItemIdentifier = enumeratedItemIdentifier

        // Select ServerUrl
        if enumeratedItemIdentifier == .rootContainer {
            serverUrl = fileProviderData.shared.homeServerUrl
        } else {
            let metadata = fpUtility.getTableMetadataFromItemIdentifier(enumeratedItemIdentifier)
            if metadata != nil {
                if let directorySource = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata!.account, metadata!.serverUrl)) {
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

        /*** WorkingSet ***/
        if enumeratedItemIdentifier == .workingSet {
            var itemIdentifierMetadata: [NSFileProviderItemIdentifier: tableMetadata] = [:]

            // ***** Tags *****
            let tags = NCManageDatabase.shared.getTags(predicate: NSPredicate(format: "account == %@", fileProviderData.shared.account))
            for tag in tags {

                guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(tag.ocId)  else { continue }
                fpUtility.createocIdentifierOnFileSystem(metadata: metadata)
                itemIdentifierMetadata[fpUtility.getItemIdentifier(metadata: metadata)] = metadata
            }

            // ***** Favorite *****
            fileProviderData.shared.listFavoriteIdentifierRank = NCManageDatabase.shared.getTableMetadatasDirectoryFavoriteIdentifierRank(account: fileProviderData.shared.account)
            for (identifier, _) in fileProviderData.shared.listFavoriteIdentifierRank {

                guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(identifier) else { continue }
                itemIdentifierMetadata[fpUtility.getItemIdentifier(metadata: metadata)] = metadata
            }

            // create items
            for (_, metadata) in itemIdentifierMetadata {
                let parentItemIdentifier = fpUtility.getParentItemIdentifier(metadata: metadata)
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

            if page == NSFileProviderPage.initialPageSortedByDate as NSFileProviderPage || page == NSFileProviderPage.initialPageSortedByName as NSFileProviderPage {
                self.readFileOrFolder(serverUrl: serverUrl) { metadatas in
                    self.completeObserver(observer, numPage: 1, metadatas: metadatas)
                }
            } else {
                let numPage = Int(String(data: page.rawValue, encoding: .utf8)!)!
                completeObserver(observer, numPage: numPage, metadatas: nil)
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

        let data = "\(fileProviderData.shared.currentAnchor)".data(using: .utf8)
        observer.finishEnumeratingChanges(upTo: NSFileProviderSyncAnchor(data!), moreComing: false)
    }

    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        let data = "\(fileProviderData.shared.currentAnchor)".data(using: .utf8)
        completionHandler(NSFileProviderSyncAnchor(data!))
    }

    // --------------------------------------------------------------------------------------------
    // MARK: - User Function + Network
    // --------------------------------------------------------------------------------------------

    func completeObserver(_ observer: NSFileProviderEnumerationObserver, numPage: Int, metadatas: [tableMetadata]?) {
        var numPage = numPage
        var items: [NSFileProviderItemProtocol] = []

        if metadatas != nil {
            for metadata in metadatas! {
                if metadata.e2eEncrypted || (!metadata.session.isEmpty && metadata.session != NCNetworking.shared.sessionUploadBackgroundExtension) { continue }
                fpUtility.createocIdentifierOnFileSystem(metadata: metadata)
                let parentItemIdentifier = fpUtility.getParentItemIdentifier(metadata: metadata)
                if parentItemIdentifier != nil {
                    let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier!)
                    items.append(item)
                }
            }
            observer.didEnumerate(items)
        }

        if items.count == fileProviderData.shared.itemForPage {
            numPage += 1
            let providerPage = NSFileProviderPage("\(numPage)".data(using: .utf8)!)
            observer.finishEnumerating(upTo: providerPage)
        } else {
            observer.finishEnumerating(upTo: nil)
        }
    }

    func readFileOrFolder(serverUrl: String, completionHandler: @escaping (_ metadatas: [tableMetadata]?) -> Void) {
        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrl, depth: "1", showHiddenFiles: NCKeychain().showHiddenFiles) { account, files, _, error in
            if error == .success {
                DispatchQueue.global().async {
                    NCManageDatabase.shared.convertFilesToMetadatas(files, useFirstAsMetadataFolder: true) { metadataFolder, metadatas in
                        /// FOLDER
                        NCManageDatabase.shared.addMetadata(metadataFolder)
                        NCManageDatabase.shared.addDirectory(e2eEncrypted: metadataFolder.e2eEncrypted, favorite: metadataFolder.favorite, ocId: metadataFolder.ocId, fileId: metadataFolder.fileId, etag: metadataFolder.etag, permissions: metadataFolder.permissions, richWorkspace: metadataFolder.richWorkspace, serverUrl: serverUrl, account: metadataFolder.account)
                        /// FILES
                        let predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND status == %d", account, serverUrl, NCGlobal.shared.metadataStatusNormal)
                        NCManageDatabase.shared.updateMetadatas(metadatas, predicate: predicate)
                        let metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", fileProviderData.shared.account, serverUrl), sorted: "fileName", ascending: true)
                        completionHandler(metadatas)
                    }
                }
            } else {
                let metadatas = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", fileProviderData.shared.account, serverUrl), sorted: "fileName", ascending: true)
                completionHandler(metadatas)
            }
        }
    }
}
