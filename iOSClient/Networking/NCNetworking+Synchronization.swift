//
//  NCNetworking+Synchronization.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 07/02/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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
import NextcloudKit

extension NCNetworking {
    internal func synchronization(account: String, serverUrl: String, userId: String, urlBase: String, metadatasInDownload: [tableMetadata]?) async {
        let showHiddenFiles = NCKeychain().getShowHiddenFiles(account: account)
        let options = NKRequestOptions(timeout: 300, taskDescription: NCGlobal.shared.taskDescriptionSynchronization, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        nkLog(tag: self.global.logTagSync, emoji: .start, message: "Start read infinite folder: \(serverUrl)")

        let results = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrl, depth: "infinity", showHiddenFiles: showHiddenFiles, account: account, options: options)

        if results.error == .success, let files = results.files {
            nkLog(tag: self.global.logTagSync, emoji: .success, message: "Read infinite folder: \(serverUrl)")

            for file in files {
                if file.directory {
<<<<<<< HEAD
                    metadatasDirectory.append(self.database.convertFileToMetadata(file, isDirectoryE2EE: false))
                } else if await isFileDifferent(ocId: file.ocId,
                                                fileName: file.fileName,
                                                etag: file.etag, metadatasInDownload: metadatasInDownload,
                                                userId: userId,
                                                urlBase: urlBase) {
                    metadatasDownload.append(self.database.convertFileToMetadata(file, isDirectoryE2EE: false))
                    nkLog(tag: self.global.logTagSync, emoji: .start, message: "File download: \(file.serverUrl)/\(file.fileName)")
=======
                    let metadata = self.database.convertFileToMetadata(file, isDirectoryE2EE: false)
                    await self.database.addMetadataAsync(metadata)
                    await self.database.addDirectoryAsync(e2eEncrypted: metadata.e2eEncrypted,
                                                          favorite: metadata.favorite,
                                                          ocId: metadata.ocId,
                                                          fileId: metadata.fileId,
                                                          etag: metadata.etag,
                                                          permissions: metadata.permissions,
                                                          richWorkspace: metadata.richWorkspace,
                                                          serverUrl: metadata.serverUrlFileName,
                                                          account: metadata.account)
                } else {
                    if await isFileDifferent(ocId: file.ocId, fileName: file.fileName, etag: file.etag, metadatasInDownload: metadatasInDownload) {
                        let metadata = self.database.convertFileToMetadata(file, isDirectoryE2EE: false)
                        metadata.session = self.sessionDownloadBackground
                        metadata.sessionSelector = NCGlobal.shared.selectorSynchronizationOffline
                        metadata.sessionTaskIdentifier = 0
                        metadata.sessionError = ""
                        metadata.status = NCGlobal.shared.metadataStatusWaitDownload
                        metadata.sessionDate = Date()

                        await self.database.addMetadataAsync(metadata)

                        nkLog(tag: self.global.logTagSync, emoji: .start, message: "File download: \(file.serverUrl)/\(file.fileName)")
                    }
>>>>>>> origin/710-FPE
                }
            }

            await self.database.setDirectorySynchronizationDateAsync(serverUrl: serverUrl, account: account)
        } else {
            nkLog(tag: self.global.logTagSync, emoji: .error, message: "Read infinite folder: \(serverUrl), error: \(results.error.errorCode)")
        }

        nkLog(tag: self.global.logTagSync, emoji: .stop, message: "Stop read infinite folder: \(serverUrl)")
    }

    internal func isFileDifferent(ocId: String,
                                  fileName: String,
                                  etag: String,
                                  metadatasInDownload: [tableMetadata]?,
                                  userId: String,
                                  urlBase: String) async -> Bool {
        let match = metadatasInDownload?.contains { $0.ocId == ocId } ?? false
        if match {
            return false
        }

<<<<<<< HEAD
        let localFile = await self.database.getTableLocalFileAsync(predicate: NSPredicate(format: "ocId == %@", ocId))
        let fileNamePath = self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId, fileNameView: fileName, userId: userId, urlBase: urlBase)
=======
        guard let localFile = await self.database.getTableLocalFileAsync(predicate: NSPredicate(format: "ocId == %@", ocId)) else {
            return true
        }
        let fileNamePath = self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId, fileNameView: fileName)
>>>>>>> origin/710-FPE
        let size = await self.utilityFileSystem.fileSizeAsync(atPath: fileNamePath)
        let isDifferent = (localFile.etag != etag) || size == 0

        return isDifferent
    }
}
