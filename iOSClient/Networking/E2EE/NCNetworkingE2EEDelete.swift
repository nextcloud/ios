//
//  NCNetworkingE2EEDelete.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 09/11/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
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
import OpenSSL
import NextcloudKit
import CFNetwork
import Alamofire
import Foundation

@objc class NCNetworkingE2EEDelete: NSObject {
    @objc public static let shared: NCNetworkingE2EEDelete = {
        let instance = NCNetworkingE2EEDelete()
        return instance
    }()

    func delete(metadata: tableMetadata) async -> (NKError) {

        // Lock
        let lockResults = await NCNetworkingE2EE.shared.lock(account: metadata.account, serverUrl: metadata.serverUrl)

        if lockResults.error == .success, let e2eToken = lockResults.e2eToken {

            let deleteE2eEncryption = NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", metadata.account, metadata.serverUrl, metadata.fileName)
            let errorDeleteMetadataPlain = await NCNetworking.shared.deleteMetadataPlain(metadata, customHeader: ["e2e-token": e2eToken])
            let home = NCUtilityFileSystem.shared.getHomeServer(urlBase: metadata.urlBase, userId: metadata.userId)
            var error = errorDeleteMetadataPlain

            if metadata.serverUrl != home {

                // Send metadata
                let sendE2EMetadataResults = await
                    NCNetworkingE2EE.shared.sendE2EMetadata(account: metadata.account,
                                                            serverUrl: metadata.serverUrl,
                                                            fileNameRename: nil,
                                                            fileNameNewRename: nil,
                                                            deleteE2eEncryption: deleteE2eEncryption,
                                                            urlBase: metadata.urlBase,
                                                            userId: metadata.userId)

                error = sendE2EMetadataResults.error
            }

            // Unlock
            if let tableLock = NCManageDatabase.shared.getE2ETokenLock(account: metadata.account, serverUrl: metadata.serverUrl) {
                await NextcloudKit.shared.lockE2EEFolder(fileId: tableLock.fileId, e2eToken: tableLock.e2eToken, method: "DELETE")
            }

            return error

        } else {
            return lockResults.error
        }
    }
}
