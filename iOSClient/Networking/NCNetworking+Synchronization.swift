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
import JGProgressHUD
import NextcloudKit
import Alamofire

extension NCNetworking {

    func synchronization(account: String,
                         serverUrl: String,
                         add: Bool,
                         completion: @escaping (_ errorCode: Int, _ items: Int) -> Void = { _, _ in }) {
        let startDate = Date()
        let options = NKRequestOptions(timeout: 120, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrl,
                                             depth: "infinity",
                                             showHiddenFiles: NCKeychain().showHiddenFiles,
                                             account: account,
                                             options: options) { resultAccount, files, _, error in
            guard account == resultAccount else { return }
            var metadatasDirectory: [tableMetadata] = []
            var metadatasSynchronizationOffline: [tableMetadata] = []

            if !add {
                if NCManageDatabase.shared.getResultMetadata(predicate: NSPredicate(format: "account == %@ AND sessionSelector == %@ AND (status == %d OR status == %d)", account, NCGlobal.shared.selectorSynchronizationOffline, NCGlobal.shared.metadataStatusWaitDownload, NCGlobal.shared.metadataStatusDownloading)) != nil { return }
            }

            if error == .success {
                for file in files {
                    if file.directory {
                        metadatasDirectory.append(NCManageDatabase.shared.convertFileToMetadata(file, isDirectoryE2EE: false))
                    } else if self.isSynchronizable(ocId: file.ocId, fileName: file.fileName, etag: file.etag) {
                        metadatasSynchronizationOffline.append(NCManageDatabase.shared.convertFileToMetadata(file, isDirectoryE2EE: false))
                    }
                }
                NCManageDatabase.shared.addMetadatas(metadatasDirectory)
                NCManageDatabase.shared.setMetadatasSessionInWaitDownload(metadatas: metadatasSynchronizationOffline,
                                                                          session: NCNetworking.shared.sessionDownloadBackground,
                                                                          selector: NCGlobal.shared.selectorSynchronizationOffline)
                NCManageDatabase.shared.setDirectorySynchronizationDate(serverUrl: serverUrl, account: account)
                let diffDate = Date().timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate
                NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Synchronization \(serverUrl) in \(diffDate)")
                completion(0, metadatasSynchronizationOffline.count)
            } else {
                NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Synchronization \(serverUrl), \(error.errorCode), \(error.description)")
                completion(error.errorCode, metadatasSynchronizationOffline.count)
            }
        }
    }

    @discardableResult
    func synchronization(account: String, serverUrl: String, add: Bool) async -> (errorCode: Int, items: Int) {
        await withUnsafeContinuation({ continuation in
            synchronization(account: account, serverUrl: serverUrl, add: add) { errorCode, items in
                continuation.resume(returning: (errorCode, items))
            }
        })
    }

    func isSynchronizable(ocId: String, fileName: String, etag: String) -> Bool {
        if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId),
           (metadata.status == NCGlobal.shared.metadataStatusDownloading || metadata.status == NCGlobal.shared.metadataStatusWaitDownload) {
            return false
        }
        let localFile = NCManageDatabase.shared.getResultsTableLocalFile(predicate: NSPredicate(format: "ocId == %@", ocId))?.first
        if localFile?.etag != etag || NCUtilityFileSystem().fileProviderStorageSize(ocId, fileNameView: fileName) == 0 {
            return true
        } else {
            return false
        }
    }
}
