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
        super.init()

        let session = fileProviderData.shared.session
        let homeServer = NCUtilityFileSystem().getHomeServer(session: session)

        if enumeratedItemIdentifier == .rootContainer {
            serverUrl = homeServer
        } else if let metadata = providerUtility.getTableMetadataFromItemIdentifier(enumeratedItemIdentifier) {
            if metadata.fileName == NextcloudKit.shared.nkCommonInstance.rootFileName {
                serverUrl = homeServer
            } else {
                serverUrl = metadata.serverUrlFileName
            }
        }
    }

    func invalidate() { }

    /// Enumerates regular file or folder contents or the Working Set
    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        Task {
            var items: [NSFileProviderItemProtocol] = []

            if enumeratedItemIdentifier == .workingSet {
                var itemIdentifierMetadata: [NSFileProviderItemIdentifier: tableMetadata] = [:]

                if let tags = await database.getTagsAsync(predicate: NSPredicate(format: "account == %@", fileProviderData.shared.session.account)) {
                    for tag in tags {
                        guard let metadata = await database.getMetadataFromOcIdAsync(tag.ocId) else { continue }
                        itemIdentifierMetadata[providerUtility.getItemIdentifier(metadata: metadata)] = metadata
                    }
                }

                fileProviderData.shared.listFavoriteIdentifierRank = await database.getTableMetadatasDirectoryFavoriteIdentifierRankAsync(account: fileProviderData.shared.session.account)
                for (identifier, _) in fileProviderData.shared.listFavoriteIdentifierRank {
                    guard let metadata = await database.getMetadataFromOcIdAsync(identifier) else { continue }
                    itemIdentifierMetadata[providerUtility.getItemIdentifier(metadata: metadata)] = metadata
                }

                for (_, metadata) in itemIdentifierMetadata {
                    if let parentItemIdentifier = await providerUtility.getParentItemIdentifierAsync(account: metadata.account, serverUrl: metadata.serverUrl) {
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
                if let stringPage = String(data: page.rawValue, encoding: .utf8), let intPage = Int(stringPage) {
                    pageNumber = intPage
                }

                let (metadatas, isPaginated) = await fetchItemsForPage(serverUrl: serverUrl, pageNumber: pageNumber)

                if let metadatas {
                    for metadata in metadatas where !metadata.e2eEncrypted && (metadata.session.isEmpty || metadata.session == NCNetworking.shared.sessionUploadBackgroundExt) {
                        if let parentItemIdentifier = await providerUtility.getParentItemIdentifierAsync(account: metadata.account, serverUrl: metadata.serverUrl) {
                            let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
                            items.append(item)
                        }
                    }
                }

                observer.didEnumerate(items)

                if let metadatas, isPaginated, metadatas.count == self.recordsPerPage {
                    let nextPage = NSFileProviderPage("\(pageNumber + 1)".data(using: .utf8)!)
                    observer.finishEnumerating(upTo: nextPage)
                } else {
                    observer.finishEnumerating(upTo: nil)
                }
            }
        }
    }

    func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
        Task {
            let signalRegistry = FileProviderSignalRegistry.shared
            let isWorkingSet = enumeratedItemIdentifier == .workingSet

            // Consume and collect changes
            let itemsToDelete = await signalRegistry.consumeDeletions(isWorkingSet: isWorkingSet)
            let itemsToUpdate = await signalRegistry.consumeUpdates(isWorkingSet: isWorkingSet)

            if !itemsToDelete.isEmpty {
                observer.didDeleteItems(withIdentifiers: itemsToDelete)
            }

            if !itemsToUpdate.isEmpty {
                observer.didUpdate(itemsToUpdate)
            }

            let newAnchorData = ISO8601DateFormatter().string(from: Date()).data(using: .utf8)!
            observer.finishEnumeratingChanges(upTo: NSFileProviderSyncAnchor(newAnchorData), moreComing: false)
        }
    }

    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        let data = "\(self.anchor)".data(using: .utf8)
        completionHandler(NSFileProviderSyncAnchor(data!))
    }

    func fetchItemsForPage(serverUrl: String, pageNumber: Int) async -> (metadatas: [tableMetadata]?, isPaginated: Bool) {
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
        let showHiddenFiles = NCKeychain().getShowHiddenFiles(account: fileProviderData.shared.session.account)
        let options = NKRequestOptions(paginate: true,
                                       paginateToken: self.paginateToken,
                                       paginateOffset: offset,
                                       paginateCount: paginateCount,
                                       queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        print("PAGINATE OFFSET: \(offset) COUNT: \(paginateCount) TOTAL: \(self.paginatedTotal)")

        let resultsRead = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrl,
                                                                          depth: "1",
                                                                          showHiddenFiles: showHiddenFiles,
                                                                          account: fileProviderData.shared.session.account,
                                                                          options: options)

        if let headers = resultsRead.responseData?.response?.allHeaderFields as? [String: String] {
            let normalizedHeaders = Dictionary(uniqueKeysWithValues: headers.map { ($0.key.lowercased(), $0.value) })
            isPaginated = Bool(normalizedHeaders["x-nc-paginate"] ?? "false") ?? false
            self.paginateToken = normalizedHeaders["x-nc-paginate-token"]
            self.paginatedTotal = Int(normalizedHeaders["x-nc-paginate-total"] ?? "0") ?? 0
        }

        if resultsRead.error == .success, let files = resultsRead.files {
            if pageNumber == 0 {
                await self.database.deleteMetadataAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND status == %d AND fileName != %@", fileProviderData.shared.session.account, serverUrl, NCGlobal.shared.metadataStatusNormal, NextcloudKit.shared.nkCommonInstance.rootFileName))
                serverUrlMetadataFolder = serverUrl
            }

            let (metadataFolder, metadatas) = await self.database.convertFilesToMetadatasAsync(files, serverUrlMetadataFolder: serverUrlMetadataFolder)

            // FOLDER
            if serverUrlMetadataFolder != nil {
                await self.database.addMetadataAsync(metadataFolder)
                await self.database.addDirectoryAsync(e2eEncrypted: metadataFolder.e2eEncrypted,
                                                      favorite: metadataFolder.favorite,
                                                      ocId: metadataFolder.ocId,
                                                      fileId: metadataFolder.fileId,
                                                      etag: metadataFolder.etag,
                                                      permissions: metadataFolder.permissions,
                                                      richWorkspace: metadataFolder.richWorkspace,
                                                      serverUrl: serverUrl,
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
                    await self.database.addDirectoryAsync(e2eEncrypted: metadata.e2eEncrypted,
                                                          favorite: metadata.favorite,
                                                          ocId: metadata.ocId,
                                                          fileId: metadata.fileId,
                                                          etag: metadata.etag,
                                                          permissions: metadata.permissions,
                                                          richWorkspace: metadata.richWorkspace,
                                                          serverUrl: serverUrl,
                                                          account: metadata.account)
                }
            }

            return(metadatas, isPaginated)

        } else {
            if isPaginated {

                return (nil, isPaginated)

            } else {

                let metadatas = await self.database.getMetadatasAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", fileProviderData.shared.session.account, serverUrl))

                return (metadatas, isPaginated)
            }
        }
    }
}
