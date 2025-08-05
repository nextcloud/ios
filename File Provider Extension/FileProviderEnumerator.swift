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
    let fileProviderData = FileProviderData.shared
    let providerUtility = fileProviderUtility()
    let database = NCManageDatabase.shared
    var anchor: UInt64 = 0
    // X-NC-PAGINATE
    var recordsPerPage: Int = 100
    var paginateToken: String?
    var paginatedTotal: Int = 0

    init(enumeratedItemIdentifier: NSFileProviderItemIdentifier) {
        self.enumeratedItemIdentifier = enumeratedItemIdentifier
        super.init()

        guard let session = fileProviderData.session else {
            return
        }

        if enumeratedItemIdentifier == .rootContainer {
            self.serverUrl = NCUtilityFileSystem().getHomeServer(session: session)
        } else {
            if let metadata = providerUtility.getTableMetadataFromItemIdentifier(enumeratedItemIdentifier),
               let directorySource = self.database.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
                serverUrl = directorySource.serverUrl + "/" + metadata.fileName
            }
        }
    }

    func invalidate() { }

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        Task {
            var items: [NSFileProviderItemProtocol] = []
            guard let session = fileProviderData.session else {
                return
            }

            // WorkingSet
            if enumeratedItemIdentifier == .workingSet {
                var itemIdentifierMetadata: [NSFileProviderItemIdentifier: tableMetadata] = [:]

                // Tags
                if let tags = await self.database.getTagsAsync(predicate: NSPredicate(format: "account == %@", session.account)) {
                    for tag in tags {
                        guard let metadata = await self.database.getMetadataFromOcIdAsync(tag.ocId) else {
                            continue
                        }
                        itemIdentifierMetadata[providerUtility.getItemIdentifier(metadata: metadata)] = metadata
                    }
                }

                // Favorite
                fileProviderData.listFavoriteIdentifierRank = await self.database.getTableMetadatasDirectoryFavoriteIdentifierRankAsync(account: session.account)
                for (identifier, _) in fileProviderData.listFavoriteIdentifierRank {
                    guard let metadata = await self.database.getMetadataFromOcIdAsync(identifier) else {
                        continue
                    }
                    itemIdentifierMetadata[providerUtility.getItemIdentifier(metadata: metadata)] = metadata
                }

                // Create items
                for (_, metadata) in itemIdentifierMetadata {
                    if let parentItemIdentifier = await providerUtility.getParentItemIdentifierAsync(metadata: metadata) {
                        let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
                        items.append(item)
                    }
                }
                observer.didEnumerate(items)
                observer.finishEnumerating(upTo: nil)

            } else {

                // ServerUrl
                guard let serverUrl = serverUrl else {
                    observer.finishEnumerating(upTo: nil)
                    return
                }
                var pageNumber = 0
                if let stringPage = String(data: page.rawValue, encoding: .utf8),
                   let intPage = Int(stringPage) {
                    pageNumber = intPage
                }

                let (metadatas, isPaginated) = await fetchItemsForPage(serverUrl: serverUrl, pageNumber: pageNumber, account: session.account)

                if let metadatas {
                    for metadata in metadatas {
                        if metadata.e2eEncrypted || (!metadata.session.isEmpty && metadata.session != NCNetworking.shared.sessionUploadBackgroundExt) {
                            continue
                        }
                        if let parentItemIdentifier = await self.providerUtility.getParentItemIdentifierAsync(metadata: metadata) {
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
        if self.enumeratedItemIdentifier == .workingSet {
            for (itemIdentifier, _) in fileProviderData.fileProviderSignalDeleteWorkingSetItemIdentifier {
                itemsDelete.append(itemIdentifier)
            }
            fileProviderData.fileProviderSignalDeleteWorkingSetItemIdentifier.removeAll()
        } else {
            for (itemIdentifier, _) in fileProviderData.fileProviderSignalDeleteContainerItemIdentifier {
                itemsDelete.append(itemIdentifier)
            }
            fileProviderData.fileProviderSignalDeleteContainerItemIdentifier.removeAll()
        }

        // Report the updated items
        if self.enumeratedItemIdentifier == .workingSet {
            for (_, item) in fileProviderData.fileProviderSignalUpdateWorkingSetItem {
                itemsUpdate.append(item)
            }
            fileProviderData.fileProviderSignalUpdateWorkingSetItem.removeAll()
        } else {
            for (_, item) in fileProviderData.fileProviderSignalUpdateContainerItem {
                itemsUpdate.append(item)
            }
            fileProviderData.fileProviderSignalUpdateContainerItem.removeAll()
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

    func fetchItemsForPage(serverUrl: String, pageNumber: Int, account: String) async -> (metadatas: [tableMetadata]?, isPaginated: Bool) {
        var serverUrlMetadataFolder: String?
        var isPaginated: Bool = false
        var paginateCount = recordsPerPage
        if pageNumber == 0 {
            paginateCount += 1
        }
        var offset = pageNumber * recordsPerPage
        if pageNumber > 0 {
            offset += 1
        }
        let showHiddenFiles = NCPreferences().getShowHiddenFiles(account: account)
        let options = NKRequestOptions(paginate: true,
                                       paginateToken: self.paginateToken,
                                       paginateOffset: offset,
                                       paginateCount: paginateCount,
                                       queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        print("PAGINATE OFFSET: \(offset) COUNT: \(paginateCount) TOTAL: \(self.paginatedTotal)")

        let resultsRead = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrl,
                                                                          depth: "1",
                                                                          showHiddenFiles: showHiddenFiles,
                                                                          account: account,
                                                                          options: options)

        if let headers = resultsRead.responseData?.response?.allHeaderFields as? [String: String] {
            let normalizedHeaders = Dictionary(uniqueKeysWithValues: headers.map { ($0.key.lowercased(), $0.value) })
            isPaginated = Bool(normalizedHeaders["x-nc-paginate"] ?? "false") ?? false
            self.paginateToken = normalizedHeaders["x-nc-paginate-token"]
            self.paginatedTotal = Int(normalizedHeaders["x-nc-paginate-total"] ?? "0") ?? 0
        }

        if resultsRead.error == .success, let files = resultsRead.files {
            if pageNumber == 0 {
                await self.database.deleteMetadataAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND status == %d AND fileName != %@", account, serverUrl, NCGlobal.shared.metadataStatusNormal, NextcloudKit.shared.nkCommonInstance.rootFileName))
                serverUrlMetadataFolder = serverUrl
            }

            let (metadataFolder, metadatas) = await self.database.convertFilesToMetadatasAsync(files, serverUrlMetadataFolder: serverUrlMetadataFolder)

            // FOLDER
            if serverUrlMetadataFolder != nil {
                await self.database.addMetadataAsync(metadataFolder)
                await self.database.addDirectoryAsync(serverUrl: serverUrl,
                                                      ocId: metadataFolder.ocId,
                                                      fileId: metadataFolder.fileId,
                                                      etag: metadataFolder.etag,
                                                      permissions: metadataFolder.permissions,
                                                      richWorkspace: metadataFolder.richWorkspace,
                                                      favorite: metadataFolder.favorite,
                                                      account: metadataFolder.account)
            }

            // METADATA
            var metadataToInsert: [tableMetadata] = []
            for metadata in metadatas {
                if await self.database.getMetadataFromOcIdAsync(metadata.ocId) == nil {
                    metadataToInsert.append(metadata)
                }
            }
            await self.database.addMetadatasAsync(metadataToInsert)

            // DIRECTORY
            for metadata in metadatas {
                if metadata.isDirectory {
                    let serverUrl = serverUrl + "/" + metadata.fileName
                    await self.database.addDirectoryAsync(serverUrl: serverUrl,
                                                          ocId: metadata.ocId,
                                                          fileId: metadata.fileId,
                                                          etag: metadata.etag,
                                                          permissions: metadata.permissions,
                                                          richWorkspace: metadata.richWorkspace,
                                                          favorite: metadata.favorite,
                                                          account: metadata.account)
                }
            }

            return(metadatas, isPaginated)

        } else {
            if isPaginated {

                return (nil, isPaginated)

            } else {

                let metadatas = await self.database.getMetadatasAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl))

                return (metadatas, isPaginated)
            }
        }
    }
}
