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

class NCNetworkingE2EEDelete: NSObject {
    public static let shared: NCNetworkingE2EEDelete = {
        let instance = NCNetworkingE2EEDelete()
        return instance
    }()

    func delete(metadata: tableMetadata) async -> (NKError) {

        var error = NKError()

        func sendE2EMetadata(e2eToken: String, fileId: String) async -> (NKError) {

            var e2eMetadataNew: String?
            var method = "PUT"

            // Get last metadata
            let getE2EEMetadataResults = await NextcloudKit.shared.getE2EEMetadata(fileId: fileId, e2eToken: e2eToken)
            guard getE2EEMetadataResults.error == .success, let e2eMetadata = getE2EEMetadataResults.e2eMetadata, NCEndToEndMetadata.shared.decoderMetadata(e2eMetadata, privateKey: CCUtility.getEndToEndPrivateKey(metadata.account), serverUrl: metadata.serverUrl, account: metadata.account, urlBase: metadata.urlBase, userId: metadata.userId) else {
                    return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: NSLocalizedString("_e2e_error_encode_metadata_", comment: ""))
            }

            // delete
            NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", metadata.account, metadata.serverUrl, metadata.fileName))

            // Rebuild metadata
            if let tableE2eEncryption = NCManageDatabase.shared.getE2eEncryptions(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
                e2eMetadataNew = NCEndToEndMetadata.shared.encoderMetadata(tableE2eEncryption, privateKey: CCUtility.getEndToEndPrivateKey(metadata.account), serverUrl: metadata.serverUrl)
            } else {
                method = "DELETE"
            }

            // Send metadata
            let putE2EEMetadataResults = await NextcloudKit.shared.putE2EEMetadata(fileId: fileId, e2eToken: e2eToken, e2eMetadata: e2eMetadataNew, method: method)
            
            return putE2EEMetadataResults.error
        }

        // ** Lock **
        let lockResults = await NCNetworkingE2EE.shared.lock(account: metadata.account, serverUrl: metadata.serverUrl)

        error = lockResults.error
        if error == .success, let e2eToken = lockResults.e2eToken, let fileId = lockResults.fileId {

            let deleteMetadataPlainError = await NCNetworking.shared.deleteMetadataPlain(metadata, customHeader: ["e2e-token": e2eToken])
            error = deleteMetadataPlainError
            if error == .success {
                let sendE2EMetadataError = await sendE2EMetadata(e2eToken: e2eToken, fileId: fileId)
                error = sendE2EMetadataError
            }
        }

        // ** Unlock **
        await NCNetworkingE2EE.shared.unlock(account: metadata.account, serverUrl: metadata.serverUrl)
        
        return error
    }
}
