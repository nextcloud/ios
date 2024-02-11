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
                         selector: String,
                         completion: @escaping (_ errorCode: Int, _ items: Int) -> Void = { _, _ in }) {

        let startDate = Date()
        let options = NKRequestOptions(timeout: 240, queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrl,
                                             depth: "infinity",
                                             showHiddenFiles: NCKeychain().showHiddenFiles,
                                             options: options) { resultAccount, files, _, error in

            guard account == resultAccount else { return }
            var metadatasDirectory: [tableMetadata] = []
            var metadatasSynchronizationOffline: [tableMetadata] = []
            var metadatasSynchronizationFavorite: [tableMetadata] = []

            if error == .success {
                NCManageDatabase.shared.convertFilesToMetadatas(files, useMetadataFolder: true) { _, _, metadatas in
                    for metadata in metadatas {
                        if metadata.directory {
                            metadatasDirectory.append(metadata)
                        } else if selector == NCGlobal.shared.selectorSynchronizationOffline, metadata.isSynchronizable {
                            metadatasSynchronizationOffline.append(metadata)
                        } else if selector == NCGlobal.shared.selectorSynchronizationFavorite {
                            metadatasSynchronizationFavorite.append(metadata)
                        }
                    }

                    NCManageDatabase.shared.addMetadatas(metadatasDirectory)
                    NCManageDatabase.shared.setMetadatasSessionInWaitDownload(metadatas: metadatasSynchronizationOffline,
                                                                              session: NCNetworking.shared.sessionDownloadBackground,
                                                                              selector: selector)
                    NCManageDatabase.shared.addMetadatasWithoutUpdate(metadatasSynchronizationFavorite)

                    NCManageDatabase.shared.setDirectorySynchronizationDate(serverUrl: serverUrl, account: account)
                    let diffDate = Date().timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate
                    NextcloudKit.shared.nkCommonInstance.writeLog("[LOG] Synchronization \(serverUrl) in \(diffDate)")
                    completion(0, metadatasSynchronizationOffline.count + metadatasSynchronizationFavorite.count)
                }
            } else {
                NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Synchronization \(serverUrl), \(error.errorCode), \(error.description)")
                completion(error.errorCode, metadatasSynchronizationOffline.count + metadatasSynchronizationFavorite.count)
            }
        }
    }

    @discardableResult
    func synchronization(account: String, serverUrl: String, selector: String) async -> (Int, Int) {

        await withUnsafeContinuation({ continuation in
            synchronization(account: account, serverUrl: serverUrl, selector: selector) { errorCode, items in
                continuation.resume(returning: (errorCode, items))
            }
        })
    }
}
