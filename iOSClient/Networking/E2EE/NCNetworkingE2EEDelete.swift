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

            // Get last metadata
            let results = await NextcloudKit.shared.getE2EEMetadata(fileId: fileId, e2eToken: e2eToken)
            guard results.error == .success, let e2eMetadata = results.e2eMetadata else {
                return NKError(errorCode: NCGlobal.shared.errorE2EEKeyEncodeMetadata, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
            }

            let error = NCEndToEndMetadata().decodeMetadata(e2eMetadata, signature: results.signature, serverUrl: metadata.serverUrl, account: metadata.account, urlBase: metadata.urlBase, userId: metadata.userId, ownerId: metadata.ownerId)
            if error != .success { return error }

            // delete
            NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", metadata.account, metadata.serverUrl, metadata.fileName))

            let resultsEncode = NCEndToEndMetadata().encodeMetadata(account: metadata.account, serverUrl: metadata.serverUrl, userId: metadata.userId)
            guard resultsEncode.error == .success, let e2eMetadata = resultsEncode.metadata else { return resultsEncode.error }

            // Send metadata
            let putE2EEMetadataResults = await NextcloudKit.shared.putE2EEMetadata(fileId: fileId, e2eToken: e2eToken, e2eMetadata: e2eMetadata, signature: resultsEncode.signature, method: "PUT")
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
