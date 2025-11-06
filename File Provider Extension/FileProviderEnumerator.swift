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
    var anchor: UInt64 = 0

    // X-NC-PAGINATE
    var recordsPerPage: Int = 10
    // X-NC-PAGINATE

    var paginateToken: String?
    var paginatedTotal: Int = 0

    init(enumeratedItemIdentifier: NSFileProviderItemIdentifier) {
        self.enumeratedItemIdentifier = enumeratedItemIdentifier
        super.init()

        guard let session = FileProviderData.shared.session else {
            return
        }

        if enumeratedItemIdentifier == .rootContainer {
            self.serverUrl = NCUtilityFileSystem().getHomeServer(session: session)
        } else {
            if let metadata = fileProviderUtility().getTableMetadataFromItemIdentifier(enumeratedItemIdentifier),
               let directorySource = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
                serverUrl = NCUtilityFileSystem().createServerUrl(serverUrl: directorySource.serverUrl, fileName: metadata.fileName)
            }
        }
    }

    func invalidate() { }

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        Task {
            var items: [NSFileProviderItemProtocol] = []
            guard let session = FileProviderData.shared.session else {
                return
            }

            // WorkingSet
            if enumeratedItemIdentifier == .workingSet {
                var itemIdentifierMetadata: [NSFileProviderItemIdentifier: tableMetadata] = [:]

                // Tags
                if let tags = await NCManageDatabase.shared.getTagsAsync(predicate: NSPredicate(format: "account == %@", session.account)) {
                    for tag in tags {
                        guard let metadata = await NCManageDatabase.shared.getMetadataFromOcIdAsync(tag.ocId) else {
                            continue
                        }
                        itemIdentifierMetadata[fileProviderUtility().getItemIdentifier(metadata: metadata)] = metadata
                    }
                }

                // Favorite
                FileProviderData.shared.listFavoriteIdentifierRank = await NCManageDatabase.shared.getTableMetadatasDirectoryFavoriteIdentifierRankAsync(account: session.account)
                for (identifier, _) in FileProviderData.shared.listFavoriteIdentifierRank {
                    guard let metadata = await NCManageDatabase.shared.getMetadataFromOcIdAsync(identifier) else {
                        continue
                    }
                    itemIdentifierMetadata[fileProviderUtility().getItemIdentifier(metadata: metadata)] = metadata
                }

                // Create items
                for (_, metadata) in itemIdentifierMetadata {
                    if let parentItemIdentifier = await fileProviderUtility().getParentItemIdentifierAsync(metadata: metadata) {
                        let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
                        items.append(item)
                    }
                }
                observer.didEnumerate(items)
                observer.finishEnumerating(upTo: nil)

            } else {
                guard let serverUrl = serverUrl else {
                    observer.finishEnumerating(upTo: nil)
                    return
                }
                var pageNumber = 0
                if let stringPage = String(data: page.rawValue, encoding: .utf8),
                   let intPage = Int(stringPage) {
                    pageNumber = intPage
                }

                let (items, isPaginated) = await fetchItemsForPage(session: session,
                                                                   serverUrl: serverUrl,
                                                                   pageNumber: pageNumber)
                observer.didEnumerate(items)

                if !items.isEmpty,
                    isPaginated,
                    items.count == self.recordsPerPage {
                    pageNumber += 1
                    let data = Data("\(self.anchor)".utf8)
                    let providerPage = NSFileProviderPage(data)
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
        if self.enumeratedItemIdentifier == .workingSet {
            for (itemIdentifier, _) in FileProviderData.shared.fileProviderSignalDeleteWorkingSetItemIdentifier {
                itemsDelete.append(itemIdentifier)
            }
            FileProviderData.shared.fileProviderSignalDeleteWorkingSetItemIdentifier.removeAll()
        } else {
            for (itemIdentifier, _) in FileProviderData.shared.fileProviderSignalDeleteContainerItemIdentifier {
                itemsDelete.append(itemIdentifier)
            }
            FileProviderData.shared.fileProviderSignalDeleteContainerItemIdentifier.removeAll()
        }

        // Report the updated items
        if self.enumeratedItemIdentifier == .workingSet {
            for (_, item) in FileProviderData.shared.fileProviderSignalUpdateWorkingSetItem {
                itemsUpdate.append(item)
            }
            FileProviderData.shared.fileProviderSignalUpdateWorkingSetItem.removeAll()
        } else {
            for (_, item) in FileProviderData.shared.fileProviderSignalUpdateContainerItem {
                itemsUpdate.append(item)
            }
            FileProviderData.shared.fileProviderSignalUpdateContainerItem.removeAll()
        }

        observer.didDeleteItems(withIdentifiers: itemsDelete)
        observer.didUpdate(itemsUpdate)

        let data = Data("\(self.anchor)".utf8)
        observer.finishEnumeratingChanges(upTo: NSFileProviderSyncAnchor(data), moreComing: false)
    }

    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        let data = Data("\(self.anchor)".utf8)
        completionHandler(NSFileProviderSyncAnchor(data))
    }

    func fetchItemsForPage(session: NCSession.Session, serverUrl: String, pageNumber: Int) async -> (items: [NSFileProviderItem], isPaginated: Bool) {
        let homeServerUrl = NCUtilityFileSystem().getHomeServer(urlBase: session.urlBase, userId: session.userId)
        let predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND status == %d", session.account, serverUrl, NCGlobal.shared.metadataStatusNormal)

        func getItemsFromDatabase() async -> [NSFileProviderItem] {
            var items: [NSFileProviderItem] = []
            let directoryServerUrl = await NCManageDatabase.shared.getTableDirectoryAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl))
            let parentItemIdentifier = await fileProviderUtility().getParentItemIdentifierAsync(session: session, directory: directoryServerUrl)
            guard let parentItemIdentifier,
                  let metadatas = await NCManageDatabase.shared.getResultsMetadatasAsync(predicate: predicate) else {
                return []
            }
            for metadata in metadatas {
                // Not include root filename
                //
                if metadata.fileName == NextcloudKit.shared.nkCommonInstance.rootFileName {
                    continue
                }
                let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
                items.append(item)
            }

            return items
        }

        if pageNumber == 0 {
            // Read root directory
            //
            let resultsDirectory = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrl, depth: "0", account: session.account)
            guard resultsDirectory.error == .success else {
                let items = await getItemsFromDatabase()
                return (items, false)
            }

            // Check etag
            //
            if let file = resultsDirectory.files?.first,
               let directory = await NCManageDatabase.shared.getTableDirectoryAsync(ocId: file.ocId),
               file.etag == directory.etag {
                let items = await getItemsFromDatabase()
                return (items, false)
            }
        }

        var isPaginated: Bool = false
        var paginateCount = recordsPerPage
        if pageNumber == 0 {
            paginateCount += 1
        }
        var offset = pageNumber * recordsPerPage
        if pageNumber > 0 {
            offset += 1
        }
        let showHiddenFiles = NCPreferences().getShowHiddenFiles(account: session.account)
        let options = NKRequestOptions(paginate: true,
                                       paginateToken: self.paginateToken,
                                       paginateOffset: offset,
                                       paginateCount: paginateCount,
                                       queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        print("PAGINATE OFFSET: \(offset) COUNT: \(paginateCount) TOTAL: \(self.paginatedTotal)")

        // Read folder metadata
        //
        let resultsRead = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrl,
                                                                          depth: "1",
                                                                          showHiddenFiles: showHiddenFiles,
                                                                          account: session.account,
                                                                          options: options)
        // Header for paginate
        //
        if let headers = resultsRead.responseData?.response?.allHeaderFields as? [String: String] {
            let normalizedHeaders = Dictionary(uniqueKeysWithValues: headers.map { ($0.key.lowercased(), $0.value) })
            isPaginated = Bool(normalizedHeaders["x-nc-paginate"] ?? "false") ?? false
            self.paginateToken = normalizedHeaders["x-nc-paginate-token"]
            self.paginatedTotal = Int(normalizedHeaders["x-nc-paginate-total"] ?? "0") ?? 0
        }

        if resultsRead.error == .success, let files = resultsRead.files {
            var items: [NSFileProviderItem] = []
            var parentItemIdentifier: NSFileProviderItemIdentifier?
            if pageNumber == 0 {
                await NCManageDatabase.shared.deleteMetadataAsync(predicate: predicate)
            }

            // Parent Item Identifier
            //
            if serverUrl == homeServerUrl {
                parentItemIdentifier = NSFileProviderItemIdentifier(NSFileProviderItemIdentifier.rootContainer.rawValue)
            } else {
                let filtered = files.filter { file in
                    let serverUrlFileName = NCUtilityFileSystem().createServerUrl(serverUrl: file.serverUrl, fileName: file.fileName)
                    return serverUrlFileName == serverUrl
                }
                if let file = filtered.first {
                    parentItemIdentifier = NSFileProviderItemIdentifier(file.ocId)
                }
            }
            // Must have parentItemIdentifier
            //
            guard let parentItemIdentifier else {
                return ([], false)
            }

            for file in files {
                let metadata = await NCManageDatabase.shared.convertFileToMetadataAsync(file, isDirectoryE2EE: false)
                await NCManageDatabase.shared.addMetadataAsync(metadata)
                if metadata.directory {
                    await NCManageDatabase.shared.createDirectory(metadata: metadata, withEtag: false)
                }
                // Not include root filename
                //
                if metadata.fileName == NextcloudKit.shared.nkCommonInstance.rootFileName {
                    continue
                }
                autoreleasepool {
                    let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
                    items.append(item)
                }
            }

            return (items, isPaginated)
        } else {
            let items = await getItemsFromDatabase()
            return (items, false)
        }
    }
}
