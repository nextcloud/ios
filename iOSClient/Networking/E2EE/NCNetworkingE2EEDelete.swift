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

import Foundation
import NextcloudKit

class NCNetworkingE2EEDelete: NSObject {

    func delete(metadata: tableMetadata) async -> (NKError) {

        let networkingE2EE = NCNetworkingE2EE()

        guard let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) else {
            return NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: "_e2e_error_")
        }

        // LOCK
        //
        let resultsLock = await networkingE2EE.lock(account: metadata.account, serverUrl: metadata.serverUrl)
        guard resultsLock.error == .success, let e2eToken = resultsLock.e2eToken, let fileId = resultsLock.fileId else { return resultsLock.error }

        // DELETE FILE
        //
        let deleteMetadataPlainError = await NCNetworking.shared.deleteMetadataPlain(metadata, customHeader: ["e2e-token": e2eToken])
        guard deleteMetadataPlainError == .success else {
            await NCNetworkingE2EE().unlock(account: metadata.account, serverUrl: metadata.serverUrl)
            return deleteMetadataPlainError
        }

        // GET METADATA + DECODE
        let resultsGetE2EEMetadata = await NextcloudKit.shared.getE2EEMetadata(fileId: fileId, e2eToken: e2eToken)
        guard resultsGetE2EEMetadata.error == .success, let e2eMetadata = resultsGetE2EEMetadata.e2eMetadata else {
            await NCNetworkingE2EE().unlock(account: metadata.account, serverUrl: metadata.serverUrl)
            return NKError(errorCode: NCGlobal.shared.errorE2EEKeyEncodeMetadata, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
        }
        let resultsDecodeMetadataError = NCEndToEndMetadata().decodeMetadata(e2eMetadata, signature: resultsGetE2EEMetadata.signature, serverUrl: metadata.serverUrl, account: metadata.account, urlBase: metadata.urlBase, userId: metadata.userId, ownerId: metadata.ownerId)
        guard resultsDecodeMetadataError == .success else {
            await NCNetworkingE2EE().unlock(account: metadata.account, serverUrl: metadata.serverUrl)
            return resultsDecodeMetadataError
        }

        // DELETE FILE ON E2eEncryption
        NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", metadata.account, metadata.serverUrl, metadata.fileName))

        // ENCODE METADATA
        let resultsEncodeMetadata = NCEndToEndMetadata().encodeMetadata(account: metadata.account, serverUrl: metadata.serverUrl, userId: metadata.userId)
        guard resultsEncodeMetadata.error == .success, let e2eMetadata = resultsEncodeMetadata.metadata else { return resultsEncodeMetadata.error }

        // SEND METADATA
        let resultsPutE2EEMetadata = await NextcloudKit.shared.putE2EEMetadata(fileId: fileId, e2eToken: e2eToken, e2eMetadata: e2eMetadata, signature: resultsEncodeMetadata.signature, method: "PUT")

        // UPDATE COUNTER
        if resultsPutE2EEMetadata.error == .success, NCGlobal.shared.capabilityE2EEApiVersion == NCGlobal.shared.e2eeVersionV20 {
            NCManageDatabase.shared.updateCounterE2eMetadataV2(account: metadata.account, ocIdServerUrl: directory.ocId, counter: resultsEncodeMetadata.counter)
        }

        // UNLOCK
        await NCNetworkingE2EE().unlock(account: metadata.account, serverUrl: metadata.serverUrl)

        return resultsPutE2EEMetadata.error
    }
}
