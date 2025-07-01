// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import FileProvider
import NextcloudKit

extension FileProviderExtension {
    override func createDirectory(withName directoryName: String, inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        Task {
            guard let tableDirectory = await providerUtility.getTableDirectoryFromParentItemIdentifierAsync(parentItemIdentifier, account: fileProviderData.session.account, homeServerUrl: utilityFileSystem.getHomeServer(session: fileProviderData.session)) else {
                return completionHandler(nil, NSFileProviderError(.noSuchItem))
            }
            let account = fileProviderData.session.account
            let directoryName = utilityFileSystem.createFileName(directoryName, serverUrl: tableDirectory.serverUrl, account: account)
            let serverUrlFileName = tableDirectory.serverUrl + "/" + directoryName
            let showHiddenFiles = NCKeychain().getShowHiddenFiles(account: account)

            let resultsCreateFolder = await NextcloudKit.shared.createFolderAsync(serverUrlFileName: serverUrlFileName, account: account)

            if resultsCreateFolder.error == .success {
                let resultsReadFile = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrlFileName, depth: "0", showHiddenFiles: showHiddenFiles, account: account)

                if resultsReadFile.error == .success, let file = resultsReadFile.files?.first {
                    let isDirectoryEncrypted = await self.utilityFileSystem.isDirectoryE2EEAsync(file: file)
                    let metadata = await self.database.convertFileToMetadataAsync(file, isDirectoryE2EE: isDirectoryEncrypted)

                    await self.database.addDirectoryAsync(e2eEncrypted: false,
                                                          favorite: false,
                                                          ocId: file.ocId,
                                                          fileId: metadata.fileId,
                                                          etag: metadata.etag,
                                                          permissions: metadata.permissions,
                                                          serverUrl: serverUrlFileName,
                                                          account: metadata.account)

                    await self.database.addMetadataAsync(metadata)

                    let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)

                    completionHandler(item, nil)
                    return

                } else {

                    completionHandler(nil, NSFileProviderError(.serverUnreachable))
                    return

                }
            } else {

                completionHandler(nil, NSFileProviderError(.filenameCollision))
                return

            }
        }
    }

    override func deleteItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (Error?) -> Void) {
        Task {
            guard let metadata = await providerUtility.getTableMetadataFromItemIdentifierAsync(itemIdentifier) else {
                completionHandler(NSFileProviderError(.noSuchItem))
                return
            }
            let ocId = metadata.ocId
            let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
            let isDirectory = metadata.directory
            let serverUrl = metadata.serverUrl
            let fileName = metadata.fileName
            let account = metadata.account

            let resultsDelete = await NextcloudKit.shared.deleteFileOrFolderAsync(serverUrlFileName: serverUrlFileName, account: account)

            if resultsDelete.error == .success {
                let fileNamePath = self.utilityFileSystem.getDirectoryProviderStorageOcId(itemIdentifier.rawValue)

                do {
                    try self.providerUtility.fileManager.removeItem(atPath: fileNamePath)
                } catch let error {
                    print("error: \(error)")
                }

                if isDirectory {
                    let dirForDelete = self.utilityFileSystem.stringAppendServerUrl(serverUrl, addFileName: fileName)
                    await self.database.deleteDirectoryAndSubDirectoryAsync(serverUrl: dirForDelete, account: account)
                }

                await self.database.deleteMetadataOcIdAsync(ocId)
                await self.database.deleteLocalFileOcIdAsync(ocId)

                completionHandler(nil)
                return

            } else {

                completionHandler(NSFileProviderError(.serverUnreachable))
                return
            }
        }
    }

    override func reparentItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, newName: String?, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        Task {
            guard let itemFrom = try? item(for: itemIdentifier),
                  let metadataFrom = await providerUtility.getTableMetadataFromItemIdentifierAsync(itemIdentifier) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            let ocIdFrom = metadataFrom.ocId
            let serverUrlFrom = metadataFrom.serverUrl
            let fileNameFrom = serverUrlFrom + "/" + itemFrom.filename
            let account = metadataFrom.account

            guard let tableDirectoryTo = await providerUtility.getTableDirectoryFromParentItemIdentifierAsync(parentItemIdentifier, account: account, homeServerUrl: utilityFileSystem.getHomeServer(session: fileProviderData.session)) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }

            let serverUrlTo = tableDirectoryTo.serverUrl
            var fileNameTo = serverUrlTo + "/" + itemFrom.filename
            if let newName {
                fileNameTo = serverUrlTo + "/" + newName
            }

            let resultsMove = await NextcloudKit.shared.moveFileOrFolderAsync(serverUrlFileNameSource: fileNameFrom, serverUrlFileNameDestination: fileNameTo, overwrite: true, account: metadataFrom.account)

            if resultsMove.error == .success {
                if metadataFrom.directory {
                    await self.database.deleteDirectoryAndSubDirectoryAsync(serverUrl: serverUrlFrom, account: account)
                    await self.database.renameDirectoryAsync(ocId: ocIdFrom, serverUrl: serverUrlTo)
                }
                await self.database.moveMetadataAsync(ocId: ocIdFrom, serverUrlTo: serverUrlTo)

                guard let metadata = await self.database.getMetadataFromOcIdAsync(ocIdFrom) else {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                    return
                }

                let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)

                completionHandler(item, nil)
                return

            } else {
                
                completionHandler(nil, NSFileProviderError(.noSuchItem, userInfo: [NSLocalizedDescriptionKey: resultsMove.error.errorDescription, NSLocalizedFailureReasonErrorKey: ""]))
                return
            }
        }
    }

    override func renameItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toName itemName: String, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        Task {
            guard let metadata = await providerUtility.getTableMetadataFromItemIdentifierAsync(itemIdentifier) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            let fileNameFrom = metadata.fileNameView
            let fileNamePathFrom = metadata.serverUrl + "/" + fileNameFrom
            let fileNamePathTo = metadata.serverUrl + "/" + itemName
            let ocId = metadata.ocId

            let resultsMove = await NextcloudKit.shared.moveFileOrFolderAsync(serverUrlFileNameSource: fileNamePathFrom, serverUrlFileNameDestination: fileNamePathTo, overwrite: false, account: metadata.account)

            if resultsMove.error == .success {
                await self.database.renameMetadataAsync(fileNameNew: itemName, ocId: ocId)
                await self.database.setMetadataServeUrlFileNameStatusNormalAsync(ocId: ocId)

                guard let metadata = await self.database.getMetadataFromOcIdAsync(ocId),
                      let parentItemIdentifier = await self.providerUtility.getParentItemIdentifierAsync(metadata: metadata) else {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                    return
                }

                let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)

                completionHandler(item, nil)
                return

            } else if resultsMove.error.errorCode == NCGlobal.shared.errorBadRequest {

                completionHandler(nil, NSFileProviderError(.noSuchItem, userInfo: [NSLocalizedDescriptionKey: resultsMove.error.errorDescription, NSLocalizedFailureReasonErrorKey: ""]))
                return

            } else {

                completionHandler(nil, NSFileProviderError(.serverUnreachable))
                return

            }
        }
    }

    override func setFavoriteRank(_ favoriteRank: NSNumber?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        Task {
            guard let metadata = await providerUtility.getTableMetadataFromItemIdentifierAsync(itemIdentifier) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            var favorite = false
            let ocId = metadata.ocId

            if favoriteRank == nil {
                fileProviderData.listFavoriteIdentifierRank.removeValue(forKey: itemIdentifier.rawValue)
            } else {
                if fileProviderData.listFavoriteIdentifierRank[itemIdentifier.rawValue] == nil {
                    fileProviderData.listFavoriteIdentifierRank[itemIdentifier.rawValue] = favoriteRank
                }
                favorite = true
            }

            if (favorite == true && !metadata.favorite) || (!favorite && metadata.favorite) {
                let fileNamePath = utilityFileSystem.getFileNamePath(metadata.fileName, serverUrl: metadata.serverUrl, session: fileProviderData.session)
                let resultsFavorite = await  NextcloudKit.shared.setFavoriteAsync(fileName: fileNamePath, favorite: favorite, account: metadata.account)

                if resultsFavorite.error == .success {
                    guard let metadata = await self.database.getMetadataFromOcIdAsync(ocId) else {
                        completionHandler(nil, NSFileProviderError(.noSuchItem))
                        return
                    }

                    // Change DB
                    metadata.favorite = favorite
                    await self.database.addMetadataAsync(metadata)

                    let item = await fileProviderData.signalEnumerator(ocId: metadata.ocId, type: .workingSet)

                    completionHandler(item, nil)
                    return

                } else {
                    guard let metadata = await self.database.getMetadataFromOcIdAsync(ocId) else {
                        completionHandler(nil, NSFileProviderError(.noSuchItem))
                        return
                    }

                    // Errore, remove from listFavoriteIdentifierRank
                    fileProviderData.listFavoriteIdentifierRank.removeValue(forKey: itemIdentifier.rawValue)

                    let item = await fileProviderData.signalEnumerator(ocId: metadata.ocId, type: .workingSet)

                    completionHandler(item, NSFileProviderError(.serverUnreachable))
                    return
                }
            }
        }
    }

    override func setTagData(_ tagData: Data?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        Task {
            guard let metadataForTag = await providerUtility.getTableMetadataFromItemIdentifierAsync(itemIdentifier) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            let ocId = metadataForTag.ocId
            let account = metadataForTag.account

            await self.database.addTagAsunc(ocId, tagIOS: tagData, account: account)

            let item = await fileProviderData.signalEnumerator(ocId: ocId, type: .workingSet)

            completionHandler(item, nil)
        }
    }

    override func setLastUsedDate(_ lastUsedDate: Date?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {

        Task {
            guard let metadata = await providerUtility.getTableMetadataFromItemIdentifierAsync(itemIdentifier),
                  let parentItemIdentifier = await providerUtility.getParentItemIdentifierAsync(metadata: metadata) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }

            let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)

            completionHandler(item, nil)
        }
    }
}
