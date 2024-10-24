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
        guard let tableDirectory = providerUtility.getTableDirectoryFromParentItemIdentifier(parentItemIdentifier, account: fileProviderData.shared.session.account, homeServerUrl: utilityFileSystem.getHomeServer(session: fileProviderData.shared.session)) else {
            return completionHandler(nil, NSFileProviderError(.noSuchItem))
        }
        let directoryName = utilityFileSystem.createFileName(directoryName, serverUrl: tableDirectory.serverUrl, account: fileProviderData.shared.session.account)
        let serverUrlFileName = tableDirectory.serverUrl + "/" + directoryName

        NextcloudKit.shared.createFolder(serverUrlFileName: serverUrlFileName, account: fileProviderData.shared.session.account) { _, ocId, _, _, error in
            if error == .success {
                NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", showHiddenFiles: NCKeychain().showHiddenFiles, account: fileProviderData.shared.session.account) { _, files, _, error in
                    if error == .success, let file = files?.first {
                        let isDirectoryEncrypted = self.utilityFileSystem.isDirectoryE2EE(file: file)
                        let metadata = self.database.convertFileToMetadata(file, isDirectoryE2EE: isDirectoryEncrypted)

                        self.database.addDirectory(e2eEncrypted: false, favorite: false, ocId: ocId!, fileId: metadata.fileId, etag: metadata.etag, permissions: metadata.permissions, serverUrl: serverUrlFileName, account: metadata.account)
                        self.database.addMetadata(metadata)

                        guard let metadataInsert = self.database.getMetadataFromOcId(ocId!),
                              let parentItemIdentifier = self.providerUtility.getParentItemIdentifier(metadata: metadataInsert) else {
                            return completionHandler(nil, NSFileProviderError(.noSuchItem))
                        }
                        let item = FileProviderItem(metadata: metadataInsert, parentItemIdentifier: parentItemIdentifier)
                        completionHandler(item, nil)
                    } else {
                        completionHandler(nil, NSFileProviderError(.serverUnreachable))
                    }
                }
            } else {
                completionHandler(nil, NSFileProviderError(.filenameCollision))
            }
        }
    }

    override func deleteItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (Error?) -> Void) {
        guard let metadata = providerUtility.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            return completionHandler(NSFileProviderError(.noSuchItem))
        }
        let ocId = metadata.ocId
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let isDirectory = metadata.directory
        let serverUrl = metadata.serverUrl
        let fileName = metadata.fileName

        NextcloudKit.shared.deleteFileOrFolder(serverUrlFileName: serverUrlFileName, account: metadata.account) { account, _, error in
            if error == .success {
                let fileNamePath = self.utilityFileSystem.getDirectoryProviderStorageOcId(itemIdentifier.rawValue)

                do {
                    try self.providerUtility.fileManager.removeItem(atPath: fileNamePath)
                } catch let error {
                    print("error: \(error)")
                }

                if isDirectory {
                    let dirForDelete = self.utilityFileSystem.stringAppendServerUrl(serverUrl, addFileName: fileName)
                    self.database.deleteDirectoryAndSubDirectory(serverUrl: dirForDelete, account: account)
                }

                self.database.deleteMetadataOcId(ocId)
                self.database.deleteLocalFileOcId(ocId)
                completionHandler(nil)
            } else {
                completionHandler(NSFileProviderError(.serverUnreachable))
            }
        }
    }

    override func reparentItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, newName: String?, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        guard let itemFrom = try? item(for: itemIdentifier),
              let metadataFrom = providerUtility.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            return completionHandler(nil, NSFileProviderError(.noSuchItem))
        }
        let ocIdFrom = metadataFrom.ocId
        let serverUrlFrom = metadataFrom.serverUrl
        let fileNameFrom = serverUrlFrom + "/" + itemFrom.filename

        guard let tableDirectoryTo = providerUtility.getTableDirectoryFromParentItemIdentifier(parentItemIdentifier, account: fileProviderData.shared.session.account, homeServerUrl: utilityFileSystem.getHomeServer(session: fileProviderData.shared.session)) else {
            return completionHandler(nil, NSFileProviderError(.noSuchItem))
        }
        let serverUrlTo = tableDirectoryTo.serverUrl
        var fileNameTo = serverUrlTo + "/" + itemFrom.filename
        if let newName {
            fileNameTo = serverUrlTo + "/" + newName
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NextcloudKit.shared.moveFileOrFolder(serverUrlFileNameSource: fileNameFrom, serverUrlFileNameDestination: fileNameTo, overwrite: true, account: metadataFrom.account) { account, _, error in
                if error == .success {
                    if metadataFrom.directory {
                        self.database.deleteDirectoryAndSubDirectory(serverUrl: serverUrlFrom, account: account)
                        self.database.renameDirectory(ocId: ocIdFrom, serverUrl: serverUrlTo)
                    }
                    self.database.moveMetadata(ocId: ocIdFrom, serverUrlTo: serverUrlTo)

                    guard let metadata = self.database.getMetadataFromOcId(ocIdFrom) else {
                        return completionHandler(nil, NSFileProviderError(.noSuchItem))

                    }
                    let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)

                    completionHandler(item, nil)
                } else {
                    completionHandler(nil, NSFileProviderError(.noSuchItem, userInfo: [NSLocalizedDescriptionKey: error.errorDescription, NSLocalizedFailureReasonErrorKey: ""]))
                }
            }
        }
    }

    override func renameItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toName itemName: String, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        guard let metadata = providerUtility.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            return completionHandler(nil, NSFileProviderError(.noSuchItem))
        }
        let fileNameFrom = metadata.fileNameView
        let fileNamePathFrom = metadata.serverUrl + "/" + fileNameFrom
        let fileNamePathTo = metadata.serverUrl + "/" + itemName
        let ocId = metadata.ocId

        NextcloudKit.shared.moveFileOrFolder(serverUrlFileNameSource: fileNamePathFrom, serverUrlFileNameDestination: fileNamePathTo, overwrite: false, account: metadata.account) { _, _, error in
            if error == .success {

                self.database.renameMetadata(fileNameNew: itemName, ocId: ocId)
                self.database.setMetadataServeUrlFileNameStatusNormal(ocId: ocId)

                guard let metadata = self.database.getMetadataFromOcId(ocId) else {
                    return completionHandler(nil, NSFileProviderError(.noSuchItem))
                }

                guard let parentItemIdentifier = self.providerUtility.getParentItemIdentifier(metadata: metadata) else {
                    return completionHandler(nil, NSFileProviderError(.noSuchItem))
                }
                let item = FileProviderItem(metadata: tableMetadata.init(value: metadata), parentItemIdentifier: parentItemIdentifier)
                completionHandler(item, nil)
            } else if error.errorCode == NCGlobal.shared.errorBadRequest {
                completionHandler(nil, NSFileProviderError(.noSuchItem, userInfo: [NSLocalizedDescriptionKey: error.errorDescription, NSLocalizedFailureReasonErrorKey: ""]))
            } else {
                completionHandler(nil, NSFileProviderError(.serverUnreachable))
            }
        }
    }

    override func setFavoriteRank(_ favoriteRank: NSNumber?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        guard let metadata = providerUtility.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            return completionHandler(nil, NSFileProviderError(.noSuchItem))
        }
        var favorite = false
        let ocId = metadata.ocId

        if favoriteRank == nil {
            fileProviderData.shared.listFavoriteIdentifierRank.removeValue(forKey: itemIdentifier.rawValue)
        } else {
            if fileProviderData.shared.listFavoriteIdentifierRank[itemIdentifier.rawValue] == nil {
                fileProviderData.shared.listFavoriteIdentifierRank[itemIdentifier.rawValue] = favoriteRank
            }
            favorite = true
        }

        if (favorite == true && metadata.favorite == false) || (favorite == false && metadata.favorite == true) {
            let fileNamePath = utilityFileSystem.getFileNamePath(metadata.fileName, serverUrl: metadata.serverUrl, session: fileProviderData.shared.session)
            NextcloudKit.shared.setFavorite(fileName: fileNamePath, favorite: favorite, account: metadata.account) { _, _, error in
                if error == .success {
                    guard let metadata = self.database.getMetadataFromOcId(ocId) else {
                        return completionHandler(nil, NSFileProviderError(.noSuchItem))
                    }
                    // Change DB
                    metadata.favorite = favorite
                    self.database.addMetadata(metadata)
                    /// SIGNAL
                    let item = fileProviderData.shared.signalEnumerator(ocId: metadata.ocId, type: .workingSet)
                    completionHandler(item, nil)
                } else {
                    guard let metadata = self.database.getMetadataFromOcId(ocId) else {
                        return completionHandler(nil, NSFileProviderError(.noSuchItem))
                    }
                    // Errore, remove from listFavoriteIdentifierRank
                    fileProviderData.shared.listFavoriteIdentifierRank.removeValue(forKey: itemIdentifier.rawValue)
                    /// SIGNAL
                    let item = fileProviderData.shared.signalEnumerator(ocId: metadata.ocId, type: .workingSet)
                    completionHandler(item, NSFileProviderError(.serverUnreachable))
                }
            }
        }
    }

    override func setTagData(_ tagData: Data?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        guard let metadataForTag = providerUtility.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            return completionHandler(nil, NSFileProviderError(.noSuchItem))
        }
        let ocId = metadataForTag.ocId
        let account = metadataForTag.account

        self.database.addTag(ocId, tagIOS: tagData, account: account)
        /// SIGNAL WORKINGSET
        let item = fileProviderData.shared.signalEnumerator(ocId: ocId, type: .workingSet)
        completionHandler(item, nil)
    }

    override func setLastUsedDate(_ lastUsedDate: Date?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        guard let metadata = providerUtility.getTableMetadataFromItemIdentifier(itemIdentifier),
              let parentItemIdentifier = providerUtility.getParentItemIdentifier(metadata: metadata) else {
            return completionHandler(nil, NSFileProviderError(.noSuchItem))
        }
        let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
        completionHandler(item, nil)
    }
}
