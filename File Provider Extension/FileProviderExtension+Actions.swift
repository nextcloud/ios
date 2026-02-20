// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import FileProvider
import NextcloudKit

extension FileProviderExtension {
    override func createDirectory(withName directoryName: String, inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        Task {
            let utilityFileSystem = NCUtilityFileSystem()
            guard let session = FileProviderData.shared.session,
                  let tableDirectory = await fileProviderUtility().getTableDirectoryFromParentItemIdentifierAsync(parentItemIdentifier, account: session.account, homeServerUrl: utilityFileSystem.getHomeServer(session: session)) else {
                return completionHandler(nil, NSFileProviderError(.noSuchItem))
            }
            let account = session.account
            let fileNameFolder = fileProviderUtility().createFileName(directoryName, serverUrl: tableDirectory.serverUrl, account: account)
            let serverUrlFileName = utilityFileSystem.createServerUrl(serverUrl: tableDirectory.serverUrl, fileName: fileNameFolder)
            let showHiddenFiles = NCPreferences().getShowHiddenFiles(account: account)

            let resultsCreateFolder = await NextcloudKit.shared.createFolderAsync(serverUrlFileName: serverUrlFileName, account: account)

            if resultsCreateFolder.error == .success {
                let resultsReadFile = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrlFileName, depth: "0", showHiddenFiles: showHiddenFiles, account: account)

                if resultsReadFile.error == .success, let file = resultsReadFile.files?.first {
                    let metadata = await NCManageDatabaseCreateMetadata().convertFileToMetadataAsync(file)
                    await NCManageDatabase.shared.createDirectory(metadata: metadata)

                    NCUtilityFileSystem().getDirectoryProviderStorageOcId(metadata.ocId, fileName: metadata.fileName, userId: metadata.userId, urlBase: metadata.urlBase)

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
            guard let metadata = await fileProviderUtility().getTableMetadataFromItemIdentifierAsync(itemIdentifier) else {
                completionHandler(NSFileProviderError(.noSuchItem))
                return
            }
            let utilityFileSystem = NCUtilityFileSystem()
            let ocId = metadata.ocId
            let serverUrlFileName = utilityFileSystem.createServerUrl(serverUrl: metadata.serverUrl, fileName: metadata.fileName)
            let isDirectory = metadata.directory
            let serverUrl = metadata.serverUrl
            let fileName = metadata.fileName
            let account = metadata.account

            let resultsDelete = await NextcloudKit.shared.deleteFileOrFolderAsync(serverUrlFileName: serverUrlFileName, account: account)

            if resultsDelete.error == .success {
                let fileNamePath = utilityFileSystem.getDirectoryProviderStorageOcId(itemIdentifier.rawValue, userId: metadata.userId, urlBase: metadata.urlBase)

                do {
                    try fileProviderUtility().fileManager.removeItem(atPath: fileNamePath)
                } catch let error {
                    print("error: \(error)")
                }

                if isDirectory {
                    let dirForDelete = utilityFileSystem.createServerUrl(serverUrl: serverUrl, fileName: fileName)
                    await NCManageDatabase.shared.deleteDirectoryAndSubDirectoryAsync(serverUrl: dirForDelete, account: account)
                }

                await NCManageDatabase.shared.deleteMetadataAsync(id: ocId)
                await NCManageDatabase.shared.deleteLocalFileAsync(id: ocId)

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
                  let metadataFrom = await fileProviderUtility().getTableMetadataFromItemIdentifierAsync(itemIdentifier) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            let utilityFileSystem = NCUtilityFileSystem()
            let ocIdFrom = metadataFrom.ocId
            let serverUrlFrom = metadataFrom.serverUrl
            let fileNameFrom = utilityFileSystem.createServerUrl(serverUrl: serverUrlFrom, fileName: itemFrom.filename)
            let account = metadataFrom.account

            guard let tableDirectoryTo = await fileProviderUtility().getTableDirectoryFromParentItemIdentifierAsync(parentItemIdentifier, account: account, homeServerUrl: utilityFileSystem.getHomeServer(urlBase: metadataFrom.urlBase, userId: metadataFrom.userId)) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }

            let serverUrlTo = tableDirectoryTo.serverUrl
            var fileNameTo = utilityFileSystem.createServerUrl(serverUrl: serverUrlTo, fileName: itemFrom.filename)
            if let newName {
                fileNameTo = utilityFileSystem.createServerUrl(serverUrl: serverUrlTo, fileName: newName)
            }

            let resultsMove = await NextcloudKit.shared.moveFileOrFolderAsync(serverUrlFileNameSource: fileNameFrom, serverUrlFileNameDestination: fileNameTo, overwrite: true, account: metadataFrom.account)

            if resultsMove.error == .success {
                if metadataFrom.directory {
                    await NCManageDatabase.shared.deleteDirectoryAndSubDirectoryAsync(serverUrl: serverUrlFrom, account: account)
                    await NCManageDatabase.shared.renameDirectoryAsync(ocId: ocIdFrom, serverUrl: serverUrlTo)
                }
                await NCManageDatabase.shared.moveMetadataAsync(ocId: ocIdFrom, serverUrlTo: serverUrlTo)

                guard let metadata = await NCManageDatabase.shared.getMetadataFromOcIdAsync(ocIdFrom) else {
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
            guard let metadata = await fileProviderUtility().getTableMetadataFromItemIdentifierAsync(itemIdentifier) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            let utilityFileSystem = NCUtilityFileSystem()
            let fileNameFrom = metadata.fileNameView
            let fileNamePathFrom = utilityFileSystem.createServerUrl(serverUrl: metadata.serverUrl, fileName: fileNameFrom)
            let fileNamePathTo = utilityFileSystem.createServerUrl(serverUrl: metadata.serverUrl, fileName: itemName)
            let ocId = metadata.ocId

            let resultsMove = await NextcloudKit.shared.moveFileOrFolderAsync(serverUrlFileNameSource: fileNamePathFrom, serverUrlFileNameDestination: fileNamePathTo, overwrite: false, account: metadata.account)

            if resultsMove.error == .success {
                await NCManageDatabase.shared.renameMetadata(fileNameNew: itemName, ocId: ocId)
                await NCManageDatabase.shared.setMetadataServerUrlFileNameStatusNormalAsync(ocId: ocId)

                guard let metadata = await NCManageDatabase.shared.getMetadataFromOcIdAsync(ocId),
                      let parentItemIdentifier = await fileProviderUtility().getParentItemIdentifierAsync(metadata: metadata) else {
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
            guard let metadata = await fileProviderUtility().getTableMetadataFromItemIdentifierAsync(itemIdentifier) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            var favorite = false
            let ocId = metadata.ocId

            if favoriteRank == nil {
                FileProviderData.shared.listFavoriteIdentifierRank.removeValue(forKey: itemIdentifier.rawValue)
            } else {
                if FileProviderData.shared.listFavoriteIdentifierRank[itemIdentifier.rawValue] == nil {
                    FileProviderData.shared.listFavoriteIdentifierRank[itemIdentifier.rawValue] = favoriteRank
                }
                favorite = true
            }

            if (favorite == true && !metadata.favorite) || (!favorite && metadata.favorite) {
                let fileNamePath = NCUtilityFileSystem().getRelativeFilePath(metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId)
                let resultsFavorite = await  NextcloudKit.shared.setFavoriteAsync(fileName: fileNamePath, favorite: favorite, account: metadata.account)

                if resultsFavorite.error == .success {
                    guard let metadata = await NCManageDatabase.shared.getMetadataFromOcIdAsync(ocId) else {
                        completionHandler(nil, NSFileProviderError(.noSuchItem))
                        return
                    }

                    // Change DB
                    metadata.favorite = favorite
                    await NCManageDatabase.shared.addMetadataAsync(metadata)

                    let item = await FileProviderData.shared.signalEnumerator(ocId: metadata.ocId, type: .workingSet)

                    completionHandler(item, nil)
                    return

                } else {
                    guard let metadata = await NCManageDatabase.shared.getMetadataFromOcIdAsync(ocId) else {
                        completionHandler(nil, NSFileProviderError(.noSuchItem))
                        return
                    }

                    // Errore, remove from listFavoriteIdentifierRank
                    FileProviderData.shared.listFavoriteIdentifierRank.removeValue(forKey: itemIdentifier.rawValue)

                    let item = await FileProviderData.shared.signalEnumerator(ocId: metadata.ocId, type: .workingSet)

                    completionHandler(item, NSFileProviderError(.serverUnreachable))
                    return
                }
            }
        }
    }

    override func setTagData(_ tagData: Data?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        Task {
            guard let metadataForTag = await fileProviderUtility().getTableMetadataFromItemIdentifierAsync(itemIdentifier) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }
            let ocId = metadataForTag.ocId
            let account = metadataForTag.account

            await NCManageDatabase.shared.addTagAsunc(ocId, tagIOS: tagData, account: account)

            let item = await FileProviderData.shared.signalEnumerator(ocId: ocId, type: .workingSet)

            completionHandler(item, nil)
        }
    }

    override func setLastUsedDate(_ lastUsedDate: Date?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {

        Task {
            guard let metadata = await fileProviderUtility().getTableMetadataFromItemIdentifierAsync(itemIdentifier),
                  let parentItemIdentifier = await fileProviderUtility().getParentItemIdentifierAsync(metadata: metadata) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }

            let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)

            completionHandler(item, nil)
        }
    }
}
