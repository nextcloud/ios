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
import Alamofire

extension NCNetworking {
    func synchronization(account: String,
                         serverUrl: String,
                         add: Bool,
                         completion: @escaping (_ errorCode: Int, _ num: Int) -> Void = { _, _ in }) {
        let startDate = Date()
        let options = NKRequestOptions(timeout: 120, taskDescription: NCGlobal.shared.taskDescriptionSynchronization, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrl,
                                             depth: "infinity",
                                             showHiddenFiles: NCKeychain().showHiddenFiles,
                                             account: account,
                                             options: options) { resultAccount, files, _, error in
            guard account == resultAccount else { return }
            var metadatasDirectory: [tableMetadata] = []
            var metadatasSynchronizationOffline: [tableMetadata] = []

            if !add {
                if self.database.getResultMetadata(predicate: NSPredicate(format: "account == %@ AND sessionSelector == %@ AND (status == %d OR status == %d)",
                                                                          account,
                                                                          self.global.selectorSynchronizationOffline,
                                                                          self.global.metadataStatusWaitDownload,
                                                                          self.global.metadataStatusDownloading)) != nil { return }
            }

            if error == .success, let files {
                for file in files {
                    if file.directory {
                        metadatasDirectory.append(self.database.convertFileToMetadata(file, isDirectoryE2EE: false))
                    } else if self.isSynchronizable(ocId: file.ocId, fileName: file.fileName, etag: file.etag) {
                        metadatasSynchronizationOffline.append(self.database.convertFileToMetadata(file, isDirectoryE2EE: false))
                    }
                }

                let diffDate = Date().timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Synchronization \(serverUrl) in \(diffDate)")

                self.database.addMetadatas(metadatasDirectory)
                self.database.addDirectories(metadatas: metadatasDirectory)

                self.database.setMetadatasSessionInWaitDownload(metadatas: metadatasSynchronizationOffline,
                                                                session: self.sessionDownloadBackground,
                                                                selector: self.global.selectorSynchronizationOffline)
                self.database.setDirectorySynchronizationDate(serverUrl: serverUrl, account: account)

                completion(0, metadatasSynchronizationOffline.count)
            } else {
                NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Synchronization \(serverUrl), \(error.errorCode)")

                completion(error.errorCode, metadatasSynchronizationOffline.count)
            }
        }
    }

    @discardableResult
    func synchronization(account: String, serverUrl: String, add: Bool) async -> (errorCode: Int, num: Int) {
        await withUnsafeContinuation({ continuation in
            synchronization(account: account, serverUrl: serverUrl, add: add) { errorCode, num in
                continuation.resume(returning: (errorCode, num))
            }
        })
    }

    func isSynchronizable(ocId: String, fileName: String, etag: String) -> Bool {
        if let metadata = self.database.getMetadataFromOcId(ocId),
           metadata.status == self.global.metadataStatusDownloading || metadata.status == self.global.metadataStatusWaitDownload {
            return false
        }
        let localFile = self.database.getResultsTableLocalFile(predicate: NSPredicate(format: "ocId == %@", ocId))?.first
        if localFile?.etag != etag || NCUtilityFileSystem().fileProviderStorageSize(ocId, fileNameView: fileName) == 0 {
            return true
        } else {
            return false
        }
    }
}
