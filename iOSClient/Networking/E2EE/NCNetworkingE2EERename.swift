//
//  NCNetworkingE2EERename.swift
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

class NCNetworkingE2EERename: NSObject {
    public static let shared: NCNetworkingE2EERename = {
        let instance = NCNetworkingE2EERename()
        return instance
    }()

    func rename(metadata: tableMetadata, fileNameNew: String) async -> (NKError) {

        // verify if exists the new fileName
        if NCManageDatabase.shared.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, fileNameNew)) != nil {

            return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_file_already_exists_")

        } else {

            // Lock & Send metadata
            let sendE2EMetadataResults = await
            NCNetworkingE2EE.shared.sendE2EMetadata(account: metadata.account,
                            serverUrl: metadata.serverUrl,
                            fileNameRename: metadata.fileName,
                            fileNameNewRename: fileNameNew,
                            deleteE2eEncryption: nil,
                            urlBase: metadata.urlBase,
                            userId: metadata.userId)

            if sendE2EMetadataResults.error == .success {

                NCManageDatabase.shared.setMetadataFileNameView(serverUrl: metadata.serverUrl, fileName: metadata.fileName, newFileNameView: fileNameNew, account: metadata.account)

                // Move file system
                let atPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + metadata.fileNameView
                let toPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + fileNameNew

                do {
                    try FileManager.default.moveItem(atPath: atPath, toPath: toPath)
                } catch { }
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterRenameFile, userInfo: ["ocId": metadata.ocId, "account": metadata.account])
            }

            // Unlock
            if let tableLock = NCManageDatabase.shared.getE2ETokenLock(account: metadata.account, serverUrl: metadata.serverUrl) {
                await NextcloudKit.shared.lockE2EEFolder(fileId: tableLock.fileId, e2eToken: tableLock.e2eToken, method: "DELETE")
            }
            return sendE2EMetadataResults.error
        }
    }
}
