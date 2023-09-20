//
//  NCNetworkingE2EE.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 05/05/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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

class NCNetworkingE2EE: NSObject {
    public static let shared: NCNetworkingE2EE = {
        let instance = NCNetworkingE2EE()
        return instance
    }()

    func getRoute() -> String {
        let e2eeRouteV1 = "v1"
        let e2eeRouteV2 = "v2"
        return (NCGlobal.shared.capabilityE2EEApiVersion == NCGlobal.shared.e2eeVersionV20) ? e2eeRouteV1 : e2eeRouteV1
    }

    func isInUpload(account: String, serverUrl: String) -> Bool {

        let counter = NCManageDatabase.shared.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND (status == %d OR status == %d OR status == %d)", account, serverUrl, NCGlobal.shared.metadataStatusWaitUpload, NCGlobal.shared.metadataStatusInUpload, NCGlobal.shared.metadataStatusUploading)).count

        return counter > 0 ? true : false
    }

    func generateRandomIdentifier() -> String {

        var UUID = NSUUID().uuidString
        UUID = "E2EE" + UUID.replacingOccurrences(of: "-", with: "")
        return UUID
    }

    func uploadMetadata(account: String, serverUrl: String, userId: String, addUserId: String? = nil, removeUserId: String? = nil) async -> NKError {

        var addCertificate: String?
        var method = "POST"
        guard let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) else {
            return NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: "_e2e_error_")
        }

        if let addUserId {
            let results = await NextcloudKit.shared.getE2EECertificate(user: addUserId)
            if results.error == .success, let certificateUser = results.certificateUser {
                addCertificate = certificateUser
            } else {
                return results.error
            }
        }

        // LOCK
        //
        let resultsLock = await lock(account: account, serverUrl: serverUrl)
        guard resultsLock.error == .success, let e2eToken = resultsLock.e2eToken, let fileId = resultsLock.fileId else {
            return resultsLock.error
        }

        // METHOD
        //
        let resultsGetE2EEMetadata = await NextcloudKit.shared.getE2EEMetadata(fileId: fileId, e2eToken: e2eToken, route: getRoute())
        if resultsGetE2EEMetadata.error == .success {
            method = "PUT"
        } else if resultsGetE2EEMetadata.error.errorCode != NCGlobal.shared.errorResourceNotFound {
            return resultsGetE2EEMetadata.error
        }

        // UPLOAD METADATA
        //
        let uploadMetadataError = await uploadMetadata(account: account,
                                                       serverUrl: serverUrl,
                                                       ocIdServerUrl: directory.ocId,
                                                       fileId: fileId,
                                                       userId: userId,
                                                       e2eToken: e2eToken,
                                                       method: method,
                                                       addUserId: addUserId,
                                                       addCertificate: addCertificate,
                                                       removeUserId: removeUserId)
        guard uploadMetadataError == .success else {
            await unlock(account: account, serverUrl: serverUrl)
            return uploadMetadataError
        }

        // UNLOCK
        //
        await unlock(account: account, serverUrl: serverUrl)

        return NKError()
    }

    func downloadMetadata(account: String,
                          serverUrl: String,
                          urlBase: String,
                          userId: String,
                          fileId: String,
                          e2eToken: String) async -> NKError {

        let resultsGetE2EEMetadata = await NextcloudKit.shared.getE2EEMetadata(fileId: fileId, e2eToken: e2eToken, route: getRoute())
        guard resultsGetE2EEMetadata.error == .success, let e2eMetadata = resultsGetE2EEMetadata.e2eMetadata else {
            return resultsGetE2EEMetadata.error
        }

        let resultsDecodeMetadataError = NCEndToEndMetadata().decodeMetadata(e2eMetadata, signature: resultsGetE2EEMetadata.signature, serverUrl: serverUrl, account: account, urlBase: urlBase, userId: userId)
        guard resultsDecodeMetadataError == .success else {
            return resultsDecodeMetadataError
        }

        return NKError()
    }

    func uploadMetadata(account: String,
                        serverUrl: String,
                        ocIdServerUrl: String,
                        fileId: String,
                        userId: String,
                        e2eToken: String,
                        method: String,
                        addUserId: String? = nil,
                        addCertificate: String? = nil,
                        removeUserId: String? = nil) async -> NKError {

        let resultsEncodeMetadata = NCEndToEndMetadata().encodeMetadata(account: account, serverUrl: serverUrl, userId: userId, addUserId: addUserId, addCertificate: addCertificate, removeUserId: removeUserId)
        guard resultsEncodeMetadata.error == .success, let e2eMetadata = resultsEncodeMetadata.metadata else {
            return resultsEncodeMetadata.error
        }

        let putE2EEMetadataResults = await NextcloudKit.shared.putE2EEMetadata(fileId: fileId, e2eToken: e2eToken, e2eMetadata: e2eMetadata, signature: resultsEncodeMetadata.signature, method: method, route: getRoute())
        guard putE2EEMetadataResults.error == .success else {
            return putE2EEMetadataResults.error
        }

        // COUNTER
        //
        if NCGlobal.shared.capabilityE2EEApiVersion == NCGlobal.shared.e2eeVersionV20 {
            NCManageDatabase.shared.updateCounterE2eMetadata(account: account, ocIdServerUrl: ocIdServerUrl, counter: resultsEncodeMetadata.counter)
        }

        return NKError()
    }

    func lock(account: String, serverUrl: String) async -> (fileId: String?, e2eToken: String?, error: NKError) {

        var e2eToken: String?
        var e2eCounter = "0"

        guard let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) else {
            return (nil, nil, NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: "_e2e_error_"))
        }

        if let tableLock = NCManageDatabase.shared.getE2ETokenLock(account: account, serverUrl: serverUrl) {
            e2eToken = tableLock.e2eToken
        }

        if NCGlobal.shared.capabilityE2EEApiVersion == NCGlobal.shared.e2eeVersionV20, var counter = NCManageDatabase.shared.getCounterE2eMetadata(account: account, ocIdServerUrl: directory.ocId) {
            counter += 1
            e2eCounter = "\(counter)"
        }

        let resultsLockE2EEFolder = await NextcloudKit.shared.lockE2EEFolder(fileId: directory.fileId, e2eToken: e2eToken, e2eCounter: e2eCounter, method: "POST", route: getRoute())
        if resultsLockE2EEFolder.error == .success, let e2eToken = resultsLockE2EEFolder.e2eToken {
            NCManageDatabase.shared.setE2ETokenLock(account: account, serverUrl: serverUrl, fileId: directory.fileId, e2eToken: e2eToken)
        }

        return (directory.fileId, resultsLockE2EEFolder.e2eToken, resultsLockE2EEFolder.error)
    }

    func unlock(account: String, serverUrl: String) async {

        guard let tableLock = NCManageDatabase.shared.getE2ETokenLock(account: account, serverUrl: serverUrl) else {
            return
        }

        let resultsLockE2EEFolder = await NextcloudKit.shared.lockE2EEFolder(fileId: tableLock.fileId, e2eToken: tableLock.e2eToken, e2eCounter: nil, method: "DELETE", route: getRoute())
        if resultsLockE2EEFolder.error == .success {
            NCManageDatabase.shared.deleteE2ETokenLock(account: account, serverUrl: serverUrl)
        }

        return
    }

    func unlockAll(account: String) {

        guard CCUtility.isEnd(toEndEnabled: account) else { return }

        Task {
            for result in NCManageDatabase.shared.getE2EAllTokenLock(account: account) {
                let resultsLockE2EEFolder = await NextcloudKit.shared.lockE2EEFolder(fileId: result.fileId, e2eToken: result.e2eToken, e2eCounter: nil, method: "DELETE", route: getRoute())
                if resultsLockE2EEFolder.error == .success {
                    NCManageDatabase.shared.deleteE2ETokenLock(account: account, serverUrl: result.serverUrl)
                }
            }
        }
    }
}
