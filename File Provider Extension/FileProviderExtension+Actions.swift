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
        guard let tableDirectory = providerUtility.getTableDirectoryFromParentItemIdentifier(parentItemIdentifier, account: fileProviderData.shared.account, homeServerUrl: fileProviderData.shared.homeServerUrl) else {
            return completionHandler(nil, NSFileProviderError(.noSuchItem))
        }
        let directoryName = utilityFileSystem.createFileName(directoryName, serverUrl: tableDirectory.serverUrl, account: fileProviderData.shared.account)
        let serverUrlFileName = tableDirectory.serverUrl + "/" + directoryName

        NextcloudKit.shared.createFolder(serverUrlFileName: serverUrlFileName, account: fileProviderData.shared.account) { _, ocId, _, error in
            if error == .success {
                NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", showHiddenFiles: NCKeychain().showHiddenFiles, account: fileProviderData.shared.account) { _, files, _, error in
                    if error == .success, let file = files.first {
                        let isDirectoryEncrypted = self.utilityFileSystem.isDirectoryE2EE(file: file)
                        let metadata = NCManageDatabase.shared.convertFileToMetadata(file, isDirectoryE2EE: isDirectoryEncrypted)

                        NCManageDatabase.shared.addDirectory(e2eEncrypted: false, favorite: false, ocId: ocId!, fileId: metadata.fileId, etag: metadata.etag, permissions: metadata.permissions, serverUrl: serverUrlFileName, account: metadata.account)
                        NCManageDatabase.shared.addMetadata(metadata)

                        guard let metadataInsert = NCManageDatabase.shared.getMetadataFromOcId(ocId!),
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

        NextcloudKit.shared.deleteFileOrFolder(serverUrlFileName: serverUrlFileName, account: metadata.account) { account, error in
            if error == .success {
                let fileNamePath = self.utilityFileSystem.getDirectoryProviderStorageOcId(itemIdentifier.rawValue)

                do {
                    try self.providerUtility.fileManager.removeItem(atPath: fileNamePath)
                } catch let error {
                    print("error: \(error)")
                }

                if isDirectory {
                    let dirForDelete = self.utilityFileSystem.stringAppendServerUrl(serverUrl, addFileName: fileName)
                    NCManageDatabase.shared.deleteDirectoryAndSubDirectory(serverUrl: dirForDelete, account: account)
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
        guard let itemFrom = try? item(for: itemIdentifier),
              let metadataFrom = providerUtility.getTableMetadataFromItemIdentifier(itemIdentifier) else {
            return completionHandler(nil, NSFileProviderError(.noSuchItem))
        }
        let ocIdFrom = metadataFrom.ocId
        let serverUrlFrom = metadataFrom.serverUrl
        let fileNameFrom = serverUrlFrom + "/" + itemFrom.filename
        guard let tableDirectoryTo = providerUtility.getTableDirectoryFromParentItemIdentifier(parentItemIdentifier, account: fileProviderData.shared.account, homeServerUrl: fileProviderData.shared.homeServerUrl) else {
            return completionHandler(nil, NSFileProviderError(.noSuchItem))
        }
        let serverUrlTo = tableDirectoryTo.serverUrl
        let fileNameTo = serverUrlTo + "/" + itemFrom.filename

        NextcloudKit.shared.moveFileOrFolder(serverUrlFileNameSource: fileNameFrom, serverUrlFileNameDestination: fileNameTo, overwrite: false, account: metadataFrom.account) { account, error in
            if error == .success {
                if metadataFrom.directory {
                    NCManageDatabase.shared.deleteDirectoryAndSubDirectory(serverUrl: serverUrlFrom, account: account)
                    NCManageDatabase.shared.renameDirectory(ocId: ocIdFrom, serverUrl: serverUrlTo)
                }
                NCManageDatabase.shared.moveMetadata(ocId: ocIdFrom, serverUrlTo: serverUrlTo)

                guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocIdFrom) else {
                    return completionHandler(nil, NSFileProviderError(.noSuchItem))

                }
                let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)

                completionHandler(item, nil)
            } else if error.errorCode == NCGlobal.shared.errorBadRequest {
                completionHandler(nil, NSFileProviderError(.noSuchItem, userInfo: [NSLocalizedDescriptionKey: error.errorDescription, NSLocalizedFailureReasonErrorKey: ""]))
            } else {
                completionHandler(nil, NSFileProviderError(.serverUnreachable))
            }
        }
    }

    override func renameItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toName itemName: String, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        guard let metadata = providerUtility.getTableMetadataFromItemIdentifier(itemIdentifier),
              let directoryTable = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) else {
            return completionHandler(nil, NSFileProviderError(.noSuchItem))
        }
        let fileNameFrom = metadata.fileNameView
        let fileNamePathFrom = metadata.serverUrl + "/" + fileNameFrom
        let fileNamePathTo = metadata.serverUrl + "/" + itemName
        let ocId = metadata.ocId

        NextcloudKit.shared.moveFileOrFolder(serverUrlFileNameSource: fileNamePathFrom, serverUrlFileNameDestination: fileNamePathTo, overwrite: false, account: metadata.account) { account, error in
            if error == .success {
                // Rename metadata
                NCManageDatabase.shared.renameMetadata(fileNameTo: itemName, ocId: ocId)

                guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) else {
                    return completionHandler(nil, NSFileProviderError(.noSuchItem))
                }
                if metadata.directory {
                    NCManageDatabase.shared.setDirectory(serverUrl: fileNamePathFrom, serverUrlTo: fileNamePathTo, encrypted: directoryTable.e2eEncrypted, account: account)
                } else {
                    let itemIdentifier = self.providerUtility.getItemIdentifier(metadata: metadata)
                    self.providerUtility.moveFile(self.utilityFileSystem.getDirectoryProviderStorageOcId(itemIdentifier.rawValue, fileNameView: fileNameFrom), toPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(itemIdentifier.rawValue, fileNameView: itemName))
                    self.providerUtility.moveFile(self.utilityFileSystem.getDirectoryProviderStoragePreviewOcId(itemIdentifier.rawValue, etag: metadata.etag), toPath: self.utilityFileSystem.getDirectoryProviderStoragePreviewOcId(itemIdentifier.rawValue, etag: metadata.etag))
                    self.providerUtility.moveFile(self.utilityFileSystem.getDirectoryProviderStorageIconOcId(itemIdentifier.rawValue, etag: metadata.etag), toPath: self.utilityFileSystem.getDirectoryProviderStorageIconOcId(itemIdentifier.rawValue, etag: metadata.etag))
                    NCManageDatabase.shared.setLocalFile(ocId: ocId, fileName: itemName)
                }

                guard let parentItemIdentifier = self.providerUtility.getParentItemIdentifier(metadata: metadata) else {
                    return completionHandler(nil, NSFileProviderError(.noSuchItem))
                }
                let item = FileProviderItem(metadata: tableMetadata.init(value: metadata), parentItemIdentifier: parentItemIdentifier)
                completionHandler(item, nil)
            } else if error.errorCode == NCGlobal.shared.errorBadRequest  {
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
            let fileNamePath = utilityFileSystem.getFileNamePath(metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId)
            NextcloudKit.shared.setFavorite(fileName: fileNamePath, favorite: favorite, account: metadata.account) { _, error in
                if error == .success {
                    guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) else {
                        return completionHandler(nil, NSFileProviderError(.noSuchItem))
                    }
                    // Change DB
                    metadata.favorite = favorite
                    NCManageDatabase.shared.addMetadata(metadata)
                    /// SIGNAL
                    let item = fileProviderData.shared.signalEnumerator(ocId: metadata.ocId, type: .workingSet)
                    completionHandler(item, nil)
                } else {
                    guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) else {
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

        NCManageDatabase.shared.addTag(ocId, tagIOS: tagData, account: account)
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
