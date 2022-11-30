//
//  FileProviderExtension+Actions.swift
//  PickerFileProvider
//
//  Created by Marino Faggiana on 28/05/18.
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

extension FileProviderExtension {

    override func createDirectory(withName directoryName: String, inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {

        guard let tableDirectory = fileProviderUtility.shared.getTableDirectoryFromParentItemIdentifier(parentItemIdentifier, account: fileProviderData.shared.account, homeServerUrl: fileProviderData.shared.homeServerUrl) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }

        let directoryName = NCUtilityFileSystem.shared.createFileName(directoryName, serverUrl: tableDirectory.serverUrl, account: fileProviderData.shared.account)
        let serverUrlFileName = tableDirectory.serverUrl + "/" + directoryName

        NextcloudKit.shared.createFolder(serverUrlFileName: serverUrlFileName) { account, ocId, _, error in

            if error == .success {

                NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", showHiddenFiles: CCUtility.getShowHiddenFiles()) { account, files, _, error in

                    if error == .success && files.count > 0 {

                        let file = files.first!

                        let isDirectoryEncrypted = NCUtility.shared.isDirectoryE2EE(file: file)
                        let metadata = NCManageDatabase.shared.convertFileToMetadata(file, isDirectoryE2EE: isDirectoryEncrypted)

                        NCManageDatabase.shared.addDirectory(encrypted: false, favorite: false, ocId: ocId!, fileId: metadata.fileId, etag: metadata.etag, permissions: metadata.permissions, serverUrl: serverUrlFileName, account: metadata.account)
                        NCManageDatabase.shared.addMetadata(metadata)

                        guard let metadataInsert = NCManageDatabase.shared.getMetadataFromOcId(ocId!) else {
                            completionHandler(nil, NSFileProviderError(.noSuchItem))
                            return
                        }

                        guard let parentItemIdentifier = fileProviderUtility.shared.getParentItemIdentifier(metadata: metadataInsert) else {
                            completionHandler(nil, NSFileProviderError(.noSuchItem))
                            return
                        }

                        let item = FileProviderItem(metadata: metadataInsert, parentItemIdentifier: parentItemIdentifier)
                        completionHandler(item, nil)

                    } else {
                        completionHandler(nil, NSFileProviderError(.serverUnreachable))
                    }
                }

            } else {
                completionHandler(nil, NSFileProviderError(.serverUnreachable))
            }
        }
    }

    override func deleteItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (Error?) -> Void) {

        guard let metadata = fileProviderUtility.shared.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }

        let ocId = metadata.ocId
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let isDirectory = metadata.directory
        let serverUrl = metadata.serverUrl
        let fileName = metadata.fileName

        NextcloudKit.shared.deleteFileOrFolder(serverUrlFileName: serverUrlFileName) { account, error in

            if error == .success { // || error == kOCErrorServerPathNotFound {

                let fileNamePath = CCUtility.getDirectoryProviderStorageOcId(itemIdentifier.rawValue)!
                do {
                    try fileProviderUtility.shared.fileManager.removeItem(atPath: fileNamePath)
                } catch let error {
                    print("error: \(error)")
                }

                if isDirectory {
                    let dirForDelete = CCUtility.stringAppendServerUrl(serverUrl, addFileName: fileName)
                    NCManageDatabase.shared.deleteDirectoryAndSubDirectory(serverUrl: dirForDelete!, account: account)
                }

                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocId))
                NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", ocId))

                completionHandler(nil)

            } else {
                completionHandler(NSFileProviderError(.serverUnreachable))
            }
        }
    }

    override func reparentItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, newName: String?, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {

        guard let itemFrom = try? item(for: itemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }

        guard let metadataFrom = fileProviderUtility.shared.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }

        let ocIdFrom = metadataFrom.ocId
        let serverUrlFrom = metadataFrom.serverUrl
        let fileNameFrom = serverUrlFrom + "/" + itemFrom.filename

        guard let tableDirectoryTo = fileProviderUtility.shared.getTableDirectoryFromParentItemIdentifier(parentItemIdentifier, account: fileProviderData.shared.account, homeServerUrl: fileProviderData.shared.homeServerUrl) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        let serverUrlTo = tableDirectoryTo.serverUrl
        let fileNameTo = serverUrlTo + "/" + itemFrom.filename

        NextcloudKit.shared.moveFileOrFolder(serverUrlFileNameSource: fileNameFrom, serverUrlFileNameDestination: fileNameTo, overwrite: false) { account, error in

            if error == .success {

                if metadataFrom.directory {
                    NCManageDatabase.shared.deleteDirectoryAndSubDirectory(serverUrl: serverUrlFrom, account: account)
                    NCManageDatabase.shared.renameDirectory(ocId: ocIdFrom, serverUrl: serverUrlTo)
                }

                NCManageDatabase.shared.moveMetadata(ocId: ocIdFrom, serverUrlTo: serverUrlTo)

                guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocIdFrom) else {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                    return
                }

                let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
                completionHandler(item, nil)

            } else {
                completionHandler(nil, NSFileProviderError(.serverUnreachable))
            }
        }
    }

    override func renameItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toName itemName: String, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {

        guard let metadata = fileProviderUtility.shared.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }

        guard let directoryTable = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }

        let fileNameFrom = metadata.fileNameView
        let fileNamePathFrom = metadata.serverUrl + "/" + fileNameFrom
        let fileNamePathTo = metadata.serverUrl + "/" + itemName
        let ocId = metadata.ocId

        NextcloudKit.shared.moveFileOrFolder(serverUrlFileNameSource: fileNamePathFrom, serverUrlFileNameDestination: fileNamePathTo, overwrite: false) { account, error in

            if error == .success {

                // Rename metadata
                NCManageDatabase.shared.renameMetadata(fileNameTo: itemName, ocId: ocId)

                guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) else {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                    return
                }

                if metadata.directory {

                    NCManageDatabase.shared.setDirectory(serverUrl: fileNamePathFrom, serverUrlTo: fileNamePathTo, etag: nil, ocId: nil, fileId: nil, encrypted: directoryTable.e2eEncrypted, richWorkspace: nil, account: account)

                } else {

                    let itemIdentifier = fileProviderUtility.shared.getItemIdentifier(metadata: metadata)

                    // rename file
                    _ = fileProviderUtility.shared.moveFile(CCUtility.getDirectoryProviderStorageOcId(itemIdentifier.rawValue, fileNameView: fileNameFrom), toPath: CCUtility.getDirectoryProviderStorageOcId(itemIdentifier.rawValue, fileNameView: itemName))

                    _ = fileProviderUtility.shared.moveFile(CCUtility.getDirectoryProviderStoragePreviewOcId(itemIdentifier.rawValue, etag: metadata.etag), toPath: CCUtility.getDirectoryProviderStoragePreviewOcId(itemIdentifier.rawValue, etag: metadata.etag))

                    _ = fileProviderUtility.shared.moveFile(CCUtility.getDirectoryProviderStorageIconOcId(itemIdentifier.rawValue, etag: metadata.etag), toPath: CCUtility.getDirectoryProviderStorageIconOcId(itemIdentifier.rawValue, etag: metadata.etag))

                    NCManageDatabase.shared.setLocalFile(ocId: ocId, fileName: itemName, etag: nil)
                }

                guard let parentItemIdentifier = fileProviderUtility.shared.getParentItemIdentifier(metadata: metadata) else {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                    return
                }

                let item = FileProviderItem(metadata: tableMetadata.init(value: metadata), parentItemIdentifier: parentItemIdentifier)
                completionHandler(item, nil)

            } else {
                completionHandler(nil, NSFileProviderError(.serverUnreachable))
            }
        }
    }

    override func setFavoriteRank(_ favoriteRank: NSNumber?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {

        guard let metadata = fileProviderUtility.shared.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }

        var favorite = false
        let ocId = metadata.ocId

        if favoriteRank == nil {
            fileProviderData.shared.listFavoriteIdentifierRank.removeValue(forKey: itemIdentifier.rawValue)
        } else {
            let rank = fileProviderData.shared.listFavoriteIdentifierRank[itemIdentifier.rawValue]
            if rank == nil {
                fileProviderData.shared.listFavoriteIdentifierRank[itemIdentifier.rawValue] = favoriteRank
            }
            favorite = true
        }

        if (favorite == true && metadata.favorite == false) || (favorite == false && metadata.favorite == true) {
            let fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId, account: metadata.account)!

            NextcloudKit.shared.setFavorite(fileName: fileNamePath, favorite: favorite) { _, error in

                if error == .success {

                    guard let metadataTemp = NCManageDatabase.shared.getMetadataFromOcId(ocId) else {
                        completionHandler(nil, NSFileProviderError(.noSuchItem))
                        return
                    }
                    let metadata = tableMetadata.init(value: metadataTemp)

                    // Change DB
                    metadata.favorite = favorite
                    NCManageDatabase.shared.addMetadata(metadata)

                    let item = fileProviderData.shared.signalEnumerator(ocId: metadata.ocId)
                    completionHandler(item, nil)

                } else {

                    guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) else {
                        completionHandler(nil, NSFileProviderError(.noSuchItem))
                        return
                    }

                    // Errore, remove from listFavoriteIdentifierRank
                    fileProviderData.shared.listFavoriteIdentifierRank.removeValue(forKey: itemIdentifier.rawValue)

                    let item = fileProviderData.shared.signalEnumerator(ocId: metadata.ocId)
                    completionHandler(item, NSFileProviderError(.serverUnreachable))
                }
            }
        }
    }

    override func setTagData(_ tagData: Data?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {

        guard let metadataForTag = fileProviderUtility.shared.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        let ocId = metadataForTag.ocId
        let account = metadataForTag.account

        // Add, Remove (nil)
        NCManageDatabase.shared.addTag(ocId, tagIOS: tagData, account: account)

        let item = fileProviderData.shared.signalEnumerator(ocId: ocId)
        completionHandler(item, nil)
    }

    override func setLastUsedDate(_ lastUsedDate: Date?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {

        guard let metadata = fileProviderUtility.shared.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }

        guard let parentItemIdentifier = fileProviderUtility.shared.getParentItemIdentifier(metadata: metadata) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }

        let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
        completionHandler(item, nil)
    }
}
