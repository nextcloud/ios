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
    internal func synchronization(account: String, serverUrl: String, metadatasInDownload: [tableMetadata]?) async {
        let startDate = Date()
        let showHiddenFiles = NCKeychain().getShowHiddenFiles(account: account)
        let options = NKRequestOptions(timeout: 300, taskDescription: NCGlobal.shared.taskDescriptionSynchronization, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        var metadatasDirectory: [tableMetadata] = []
        var metadatasDownload: [tableMetadata] = []

        let results = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrl, depth: "infinity", showHiddenFiles: showHiddenFiles, account: account, options: options)

        if results.error == .success, let files = results.files {
            for file in files {
                if file.directory {
                    metadatasDirectory.append(self.database.convertFileToMetadata(file, isDirectoryE2EE: false))
                } else if await isFileDifferent(ocId: file.ocId, fileName: file.fileName, etag: file.etag, metadatasInDownload: metadatasInDownload) {
                    metadatasDownload.append(self.database.convertFileToMetadata(file, isDirectoryE2EE: false))

                    nkLog(tag: self.global.logTagSync, emonji: .start, message: "File download: \(file.serverUrl)/\(file.fileName)")
                }
            }

            self.database.addMetadatas(metadatasDirectory, sync: false)
            self.database.addDirectories(metadatas: metadatasDirectory, sync: false)
            self.database.setMetadatasSessionInWaitDownload(metadatas: metadatasDownload,
                                                            session: self.sessionDownloadBackground,
                                                            selector: self.global.selectorSynchronizationOffline)
            await self.database.setDirectorySynchronizationDateAsync(serverUrl: serverUrl, account: account)
        } else {
            nkLog(tag: self.global.logTagSync, emonji: .error, message: "Synchronization \(serverUrl), \(results.error.errorCode)")
        }
    }

    internal func isFileDifferent(ocId: String, fileName: String, etag: String, metadatasInDownload: [tableMetadata]?) async -> Bool {
        let match = metadatasInDownload?.contains { $0.ocId == ocId } ?? false
        if match {
            return false
        }

        let localFile = await self.database.getTableLocalFileAsync(predicate: NSPredicate(format: "ocId == %@", ocId))
        let fileNamePath = self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId, fileNameView: fileName)
        let size = await self.utilityFileSystem.fileSizeAsync(atPath: fileNamePath)
        let isDifferent = (localFile?.etag != etag) || size == 0

        return isDifferent
    }
}
