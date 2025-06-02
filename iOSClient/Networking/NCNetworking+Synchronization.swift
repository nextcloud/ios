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
    func synchronization(account: String, serverUrl: String, add: Bool) async {
        let startDate = Date()
        let showHiddenFiles = NCKeychain().getShowHiddenFiles(account: account)
        let options = NKRequestOptions(timeout: 120, taskDescription: NCGlobal.shared.taskDescriptionSynchronization, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        var metadatasDirectory: [tableMetadata] = []
        var metadatasDownload: [tableMetadata] = []

        let results = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrl, depth: "infinity", showHiddenFiles: showHiddenFiles, account: account, options: options)
        guard account == results.account else {
            return
        }

        if !add {
            if await self.database.getResultMetadataAsync(predicate: NSPredicate(format: "account == %@ AND sessionSelector == %@ AND (status == %d OR status == %d)",
                                                                                 account,
                                                                                 self.global.selectorSynchronizationOffline,
                                                                                 self.global.metadataStatusWaitDownload,
                                                                                 self.global.metadataStatusDownloading)) != nil {
                return
            }
        }

        if results.error == .success, let files = results.files {
            for file in files {
                if file.directory {
                    metadatasDirectory.append(self.database.convertFileToMetadata(file, isDirectoryE2EE: false))
                } else if await isSynchronizable(ocId: file.ocId, fileName: file.fileName, etag: file.etag) {
                    metadatasDownload.append(self.database.convertFileToMetadata(file, isDirectoryE2EE: false))
                }
            }

            let diffDate = Date().timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Synchronization \(serverUrl) in \(diffDate)")

            self.database.addMetadatas(metadatasDirectory, sync: false)
            self.database.addDirectories(metadatas: metadatasDirectory, sync: false)
            self.database.setMetadatasSessionInWaitDownload(metadatas: metadatasDownload,
                                                            session: self.sessionDownloadBackground,
                                                            selector: self.global.selectorSynchronizationOffline)
            await self.database.setDirectorySynchronizationDateAsync(serverUrl: serverUrl, account: account)
        } else {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Synchronization \(serverUrl), \(results.error.errorCode)")
        }

    }

    func isSynchronizable(ocId: String, fileName: String, etag: String) async -> Bool {
        if let metadata = await self.database.getMetadataFromOcIdAsync(ocId),
           metadata.status == self.global.metadataStatusDownloading || metadata.status == self.global.metadataStatusWaitDownload {
            return false
        }

        let localFile = await self.database.getTableLocalFileAsync(predicate: NSPredicate(format: "ocId == %@", ocId))
        let needsSync = (localFile?.etag != etag) || (NCUtilityFileSystem().fileProviderStorageSize(ocId, fileNameView: fileName) == 0)

        return needsSync
    }
}
