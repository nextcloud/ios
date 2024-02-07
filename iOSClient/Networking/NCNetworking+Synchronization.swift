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
                         completion: @escaping () -> Void = {}) {

        let startDate = Date()

        NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrl,
                                             depth: "infinity",
                                             showHiddenFiles: NCKeychain().showHiddenFiles,
                                             options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { _, files, _, error in

            if error == .success {
                NCManageDatabase.shared.convertFilesToMetadatas(files, useMetadataFolder: true) { _, _, metadatas in
                    for metadata in metadatas {
                        if metadata.directory {
                            NCManageDatabase.shared.addMetadata(metadata)
                        } else if selector == NCGlobal.shared.selectorSynchronizationOffline, metadata.isSynchronizable {
                            NCManageDatabase.shared.setMetadataSessionInWaitDownload(ocId: metadata.ocId,
                                                                                     session: NCNetworking.shared.sessionDownloadBackground,
                                                                                     selector: selector,
                                                                                     addMetadata: metadata)
                        }

                    }
                    let diffDate = Date().timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate
                    NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Synchronization " + serverUrl + " in \(diffDate)")
                    completion()
                }
            } else {
                NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Synchronization " + serverUrl + ", \(error.description)")
                completion()
            }
        }
    }

    func synchronization(account: String, serverUrl: String, selector: String) async {

        await withUnsafeContinuation({ continuation in
            synchronization(account: account, serverUrl: serverUrl, selector: selector) {
                continuation.resume(returning: ())
            }
        })
    }
}
