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

        var error = NKError()

        func sendE2EMetadata(e2eToken: String, fileId: String) async -> (NKError) {

            // Get last metadata
            let getE2EEMetadataResults = await NextcloudKit.shared.getE2EEMetadata(fileId: fileId, e2eToken: e2eToken)
            guard getE2EEMetadataResults.error == .success, let e2eMetadata = getE2EEMetadataResults.e2eMetadata, NCEndToEndMetadata.shared.decoderMetadata(e2eMetadata, privateKey: CCUtility.getEndToEndPrivateKey(metadata.account), serverUrl: metadata.serverUrl, account: metadata.account, urlBase: metadata.urlBase, userId: metadata.userId) else {
                return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: NSLocalizedString("_e2e_error_encode_metadata_", comment: ""))
            }

            // rename
            NCManageDatabase.shared.renameFileE2eEncryption(serverUrl: metadata.serverUrl, fileNameIdentifier: metadata.fileName, newFileName: fileNameNew, newFileNamePath: CCUtility.returnFileNamePath(fromFileName: fileNameNew, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId, account: metadata.account))

            // Rebuild metadata
            guard let tableE2eEncryption = NCManageDatabase.shared.getE2eEncryptions(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)), let e2eMetadataNew = NCEndToEndMetadata.shared.encoderMetadata(tableE2eEncryption, privateKey: CCUtility.getEndToEndPrivateKey(metadata.account), serverUrl: metadata.serverUrl) else {
                return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: NSLocalizedString("_e2e_error_encode_metadata_", comment: ""))
            }

            // send metadata
            let putE2EEMetadataResults = await NextcloudKit.shared.putE2EEMetadata(fileId: fileId, e2eToken: e2eToken, e2eMetadata: e2eMetadataNew, method: "PUT")
            
            return putE2EEMetadataResults.error
        }

        // verify if exists the new fileName
        if NCManageDatabase.shared.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, fileNameNew)) != nil {
            return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_file_already_exists_")
        }

        // ** Lock **
        let lockResults = await NCNetworkingE2EE.shared.lock(account: metadata.account, serverUrl: metadata.serverUrl)

        error = lockResults.error
        if error == .success, let e2eToken = lockResults.e2eToken, let fileId = lockResults.fileId {

            let sendE2EMetadataError = await sendE2EMetadata(e2eToken: e2eToken, fileId: fileId)
            error = sendE2EMetadataError
            if error == .success {
                NCManageDatabase.shared.setMetadataFileNameView(serverUrl: metadata.serverUrl, fileName: metadata.fileName, newFileNameView: fileNameNew, account: metadata.account)
                // Move file system
                let atPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + metadata.fileNameView
                let toPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + fileNameNew
                do {
                    try FileManager.default.moveItem(atPath: atPath, toPath: toPath)
                } catch { }
            }
        }

        // ** Unlock **
        await NCNetworkingE2EE.shared.unlock(account: metadata.account, serverUrl: metadata.serverUrl)
        
        if error == .success {
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterRenameFile, userInfo: ["ocId": metadata.ocId, "account": metadata.account])
        }

        return error
    }
}
