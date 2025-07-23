// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import FileProvider
import RealmSwift
import NextcloudKit

class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
    var enumeratedItemIdentifier: NSFileProviderItemIdentifier
    var serverUrl: String?
    let providerUtility = fileProviderUtility()
    let database = NCManageDatabase.shared
    var anchor: UInt64 = 0
    // X-NC-PAGINATE
    var recordsPerPage: Int = 100
    var paginateToken: String?
    var paginatedTotal: Int = 0

    init(enumeratedItemIdentifier: NSFileProviderItemIdentifier) {
        self.enumeratedItemIdentifier = enumeratedItemIdentifier
        if enumeratedItemIdentifier == .rootContainer {
            serverUrl = NCUtilityFileSystem().getHomeServer(session: fileProviderData.shared.session)
        } else {
            if let metadata = providerUtility.getTableMetadataFromItemIdentifier(enumeratedItemIdentifier),
               let directorySource = self.database.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
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
            let tags = self.database.getTags(predicate: NSPredicate(format: "account == %@", fileProviderData.shared.session.account)) ?? []
            for tag in tags {
                guard let metadata = self.database.getMetadataFromOcId(tag.ocId)  else { continue }
                itemIdentifierMetadata[providerUtility.getItemIdentifier(metadata: metadata)] = metadata
            }
            /// Favorite
            fileProviderData.shared.listFavoriteIdentifierRank = self.database.getTableMetadatasDirectoryFavoriteIdentifierRank(account: fileProviderData.shared.session.account)
            for (identifier, _) in fileProviderData.shared.listFavoriteIdentifierRank {
                guard let metadata = self.database.getMetadataFromOcId(identifier) else { continue }
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
            var pageNumber = 0
            if let stringPage = String(data: page.rawValue, encoding: .utf8),
               let intPage = Int(stringPage) {
                pageNumber = intPage
            }

            self.fetchItemsForPage(serverUrl: serverUrl, pageNumber: pageNumber) { metadatas, isPaginated in
                if let metadatas {
                    for metadata in metadatas {
                        if metadata.e2eEncrypted || (!metadata.session.isEmpty && metadata.session != NCNetworking.shared.sessionUploadBackgroundExt) {
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
                   isPaginated,
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

    func fetchItemsForPage(serverUrl: String, pageNumber: Int, completion: @escaping (_ metadatas: [tableMetadata]?, _ isPaginated: Bool) -> Void) {
        var isPaginated: Bool = false
        var paginateCount = recordsPerPage
        if pageNumber == 0 {
            paginateCount += 1
        }
        var offset = pageNumber * recordsPerPage
        if pageNumber > 0 {
            offset += 1
        }
        let options = NKRequestOptions(paginate: true,
                                       paginateToken: self.paginateToken,
                                       paginateOffset: offset,
                                       paginateCount: paginateCount,
                                       queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        print("PAGINATE OFFSET: \(offset) COUNT: \(paginateCount) TOTAL: \(self.paginatedTotal)")

        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrl, depth: "1", showHiddenFiles: true, account: fileProviderData.shared.session.account, options: options) { _, files, responseData, error in
            if let headers = responseData?.response?.allHeaderFields as? [String: String] {
                let normalizedHeaders = Dictionary(uniqueKeysWithValues: headers.map { ($0.key.lowercased(), $0.value) })
                isPaginated = Bool(normalizedHeaders["x-nc-paginate"] ?? "false") ?? false
                self.paginateToken = normalizedHeaders["x-nc-paginate-token"]
                self.paginatedTotal = Int(normalizedHeaders["x-nc-paginate-total"] ?? "0") ?? 0
            }

            if error == .success, let files {
                if pageNumber == 0 {
                    self.database.deleteMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName != %@", fileProviderData.shared.session.account, serverUrl, NextcloudKit.shared.nkCommonInstance.rootFileName))
                    self.database.convertFilesToMetadatas(files, capabilities: NCNetworking.shared.capabilities[fileProviderData.shared.session.account], serverUrlMetadataFolder: serverUrl) { metadataFolder, metadatas in
                        // FOLDER
                        if let metadataFolder {
                            self.database.addMetadata(metadataFolder)
                            self.database.addDirectory(e2eEncrypted: metadataFolder.e2eEncrypted, favorite: metadataFolder.favorite, ocId: metadataFolder.ocId, fileId: metadataFolder.fileId, etag: metadataFolder.etag, permissions: metadataFolder.permissions, richWorkspace: metadataFolder.richWorkspace, serverUrl: serverUrl, account: metadataFolder.account)
                        }
                        // FILES
                        self.database.addMetadatas(metadatas)
                        completion(metadatas, isPaginated)
                    }
                } else {

                }

            } else {
                if isPaginated {
                    completion(nil, isPaginated)
                } else {
                    let metadatas = self.database.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", fileProviderData.shared.session.account, serverUrl))
                    completion(metadatas, isPaginated)
                }
            }
        }
    }
}
