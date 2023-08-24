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

        guard let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) else {
            return NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: "_e2e_error_")
        }

        defer {
            Task {
                await NCNetworkingE2EE.shared.unlock(account: metadata.account, serverUrl: metadata.serverUrl)
            }
        }

        let resultsLock = await NCNetworkingE2EE.shared.lock(account: metadata.account, serverUrl: metadata.serverUrl)
        guard resultsLock.error == .success, let e2eToken = resultsLock.e2eToken, let fileId = resultsLock.fileId else { return resultsLock.error }

        let deleteMetadataPlainError = await NCNetworking.shared.deleteMetadataPlain(metadata, customHeader: ["e2e-token": e2eToken])
        guard deleteMetadataPlainError == .success else { return deleteMetadataPlainError }

        let resultsGetE2EEMetadata = await NextcloudKit.shared.getE2EEMetadata(fileId: fileId, e2eToken: e2eToken)
        guard resultsGetE2EEMetadata.error == .success, let e2eMetadata = resultsGetE2EEMetadata.e2eMetadata else {
            return NKError(errorCode: NCGlobal.shared.errorE2EEKeyEncodeMetadata, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
        }

        let resultsDecodeMetadataError = NCEndToEndMetadata().decodeMetadata(e2eMetadata, signature: resultsGetE2EEMetadata.signature, serverUrl: metadata.serverUrl, account: metadata.account, urlBase: metadata.urlBase, userId: metadata.userId, ownerId: metadata.ownerId)
        guard resultsDecodeMetadataError == .success else { return resultsDecodeMetadataError }

        let resultsEncodeMetadata = NCEndToEndMetadata().encodeMetadata(account: metadata.account, serverUrl: metadata.serverUrl, userId: metadata.userId)
        guard resultsEncodeMetadata.error == .success, let e2eMetadata = resultsEncodeMetadata.metadata else { return resultsEncodeMetadata.error }

        let resultsPutE2EEMetadata = await NextcloudKit.shared.putE2EEMetadata(fileId: fileId, e2eToken: e2eToken, e2eMetadata: e2eMetadata, signature: resultsEncodeMetadata.signature, method: "PUT")

        if resultsPutE2EEMetadata.error == .success {
            NCManageDatabase.shared.updateCounterE2eMetadataV2(account: metadata.account, serverUrl: metadata.serverUrl, ocIdServerUrl: directory.ocId, counter: resultsEncodeMetadata.counter)
            NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", metadata.account, metadata.serverUrl, metadata.fileName))
        }

        return resultsPutE2EEMetadata.error
    }
}
