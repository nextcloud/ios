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
import UIKit
import NextcloudKit
import Alamofire

class NCNetworkingE2EE: NSObject {
    let database = NCManageDatabase.shared
    let e2EEApiVersion1 = "v1"
    let e2EEApiVersion2 = "v2"

    func isInUpload(account: String, serverUrl: String) -> Bool {
        let counter = self.database.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND (status == %d OR status == %d)",
                                                                        account,
                                                                        serverUrl,
                                                                        NCGlobal.shared.metadataStatusWaitUpload,
                                                                        NCGlobal.shared.metadataStatusUploading)).count

        return counter > 0 ? true : false
    }

    func generateRandomIdentifier() -> String {
        var UUID = NSUUID().uuidString
        UUID = "E2EE" + UUID.replacingOccurrences(of: "-", with: "")
        return UUID
    }

    func getOptions(account: String) -> NKRequestOptions {
        let version = NCCapabilities.shared.getCapabilities(account: account).capabilityE2EEApiVersion == NCGlobal.shared.e2eeVersionV20 ? e2EEApiVersion2 : e2EEApiVersion1
        return NKRequestOptions(version: version)
    }

    // MARK: -

    func getMetadata(fileId: String,
                     e2eToken: String?,
                     account: String,
                     completion: @escaping (_ account: String, _ version: String?, _ e2eMetadata: String?, _ signature: String?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        switch NCCapabilities.shared.getCapabilities(account: account).capabilityE2EEApiVersion {
        case NCGlobal.shared.e2eeVersionV11, NCGlobal.shared.e2eeVersionV12:
            NextcloudKit.shared.getE2EEMetadata(fileId: fileId, e2eToken: e2eToken, account: account, options: NKRequestOptions(version: e2EEApiVersion1)) { account, e2eMetadata, signature, data, error in
                return completion(account, self.e2EEApiVersion1, e2eMetadata, signature, data, error)
            }
        case NCGlobal.shared.e2eeVersionV20:
            var options = NKRequestOptions(version: e2EEApiVersion2)
            NextcloudKit.shared.getE2EEMetadata(fileId: fileId, e2eToken: e2eToken, account: account, options: options) { account, e2eMetadata, signature, data, error in
                if error == .success {
                    return completion(account, self.e2EEApiVersion2, e2eMetadata, signature, data, error)
                } else if error.errorCode == NCGlobal.shared.errorResourceNotFound {
                    return completion(account, self.e2EEApiVersion2, e2eMetadata, signature, data, error)
                } else {
                    options = NKRequestOptions(version: self.e2EEApiVersion1)
                    NextcloudKit.shared.getE2EEMetadata(fileId: fileId, e2eToken: e2eToken, account: account, options: options) { account, e2eMetadata, signature, data, error in
                        completion(account, self.e2EEApiVersion1, e2eMetadata, signature, data, error)
                    }
                }
            }
        default:
            completion("", "", nil, nil, nil, NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "version e2ee not available"))
        }
    }

    func getMetadata(fileId: String,
                     e2eToken: String?,
                     account: String) async -> (account: String, version: String?, e2eMetadata: String?, signature: String?, responseData: AFDataResponse<Data>?, error: NKError) {
        await withUnsafeContinuation({ continuation in
            getMetadata(fileId: fileId, e2eToken: e2eToken, account: account) { account, version, e2eMetadata, signature, responseData, error in
                continuation.resume(returning: (account: account, version: version, e2eMetadata: e2eMetadata, signature: signature, responseData: responseData, error: error))
            }
        })
    }

    // MARK: -

    func uploadMetadata(serverUrl: String,
                        addUserId: String? = nil,
                        removeUserId: String? = nil,
                        updateVersionV1V2: Bool = false,
                        account: String) async -> NKError {
        var addCertificate: String?
        var method = "POST"
        let session = NCSession.shared.getSession(account: account)
        guard let directory = self.database.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl)) else {
            return NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: "_e2e_error_")
        }

        if let addUserId {
            let results = await NextcloudKit.shared.getE2EECertificate(user: addUserId, account: session.account, options: NCNetworkingE2EE().getOptions(account: account))
            if results.error == .success, let certificateUser = results.certificateUser {
                addCertificate = certificateUser
            } else {
                return results.error
            }
        }

        // LOCK
        //
        let resultsLock = await lock(account: session.account, serverUrl: serverUrl)
        guard resultsLock.error == .success, let e2eToken = resultsLock.e2eToken, let fileId = resultsLock.fileId else {
            return resultsLock.error
        }

        // METHOD
        //
        if updateVersionV1V2 {
            method = "PUT"
        } else {
            let resultsGetE2EEMetadata = await getMetadata(fileId: fileId, e2eToken: e2eToken, account: session.account)
            if resultsGetE2EEMetadata.error == .success {
                method = "PUT"
            } else if resultsGetE2EEMetadata.error.errorCode != NCGlobal.shared.errorResourceNotFound {
                return resultsGetE2EEMetadata.error
            }
        }

        // UPLOAD METADATA
        //
        let uploadMetadataError = await uploadMetadata(serverUrl: serverUrl,
                                                       ocIdServerUrl: directory.ocId,
                                                       fileId: fileId,
                                                       e2eToken: e2eToken,
                                                       method: method,
                                                       addUserId: addUserId,
                                                       addCertificate: addCertificate,
                                                       removeUserId: removeUserId,
                                                       session: session)

        guard uploadMetadataError == .success else {
            await unlock(account: session.account, serverUrl: serverUrl)
            return uploadMetadataError
        }

        // UNLOCK
        //
        await unlock(account: session.account, serverUrl: serverUrl)

        return NKError()
    }

    func uploadMetadata(serverUrl: String,
                        ocIdServerUrl: String,
                        fileId: String,
                        e2eToken: String,
                        method: String,
                        addUserId: String? = nil,
                        addCertificate: String? = nil,
                        removeUserId: String? = nil,
                        session: NCSession.Session) async -> NKError {
        let resultsEncodeMetadata = NCEndToEndMetadata().encodeMetadata(serverUrl: serverUrl, addUserId: addUserId, addCertificate: addCertificate, removeUserId: removeUserId, session: session)
        guard resultsEncodeMetadata.error == .success,
              let e2eMetadata = resultsEncodeMetadata.metadata else {
            // Client Diagnostic
            self.database.addDiagnostic(account: session.account, issue: NCGlobal.shared.diagnosticIssueE2eeErrors)
            return resultsEncodeMetadata.error
        }

        let putE2EEMetadataResults = await NextcloudKit.shared.putE2EEMetadata(fileId: fileId, e2eToken: e2eToken, e2eMetadata: e2eMetadata, signature: resultsEncodeMetadata.signature, method: method, account: session.account, options: NCNetworkingE2EE().getOptions(account: session.account))
        guard putE2EEMetadataResults.error == .success else {
            return putE2EEMetadataResults.error
        }

        // COUNTER
        //
        if NCCapabilities.shared.getCapabilities(account: session.account).capabilityE2EEApiVersion == NCGlobal.shared.e2eeVersionV20 {
            self.database.updateCounterE2eMetadata(account: session.account, ocIdServerUrl: ocIdServerUrl, counter: resultsEncodeMetadata.counter)
        }

        return NKError()
    }

    // MARK: -

    func downloadMetadata(serverUrl: String,
                          fileId: String,
                          e2eToken: String,
                          session: NCSession.Session) async -> NKError {
        let resultsGetE2EEMetadata = await getMetadata(fileId: fileId, e2eToken: e2eToken, account: session.account)
        guard resultsGetE2EEMetadata.error == .success, let e2eMetadata = resultsGetE2EEMetadata.e2eMetadata else {
            return resultsGetE2EEMetadata.error
        }

        let resultsDecodeMetadataError = NCEndToEndMetadata().decodeMetadata(e2eMetadata, signature: resultsGetE2EEMetadata.signature, serverUrl: serverUrl, session: session)
        guard resultsDecodeMetadataError == .success else {
            // Client Diagnostic
            self.database.addDiagnostic(account: session.account, issue: NCGlobal.shared.diagnosticIssueE2eeErrors)
            return resultsDecodeMetadataError
        }

        return NKError()
    }

    // MARK: -

    func lock(account: String,
              serverUrl: String) async -> (fileId: String?, e2eToken: String?, error: NKError) {
        var e2eToken: String?
        var e2eCounter = "1"
        guard let directory = self.database.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) else {
            return (nil, nil, NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: "_e2e_error_"))
        }

        if let tableLock = self.database.getE2ETokenLock(account: account, serverUrl: serverUrl) {
            e2eToken = tableLock.e2eToken
        }

        if NCCapabilities.shared.getCapabilities(account: account).capabilityE2EEApiVersion == NCGlobal.shared.e2eeVersionV20,
           var counter = self.database.getCounterE2eMetadata(account: account, ocIdServerUrl: directory.ocId) {
            counter += 1
            e2eCounter = "\(counter)"
        }

        let resultsLockE2EEFolder = await NextcloudKit.shared.lockE2EEFolder(fileId: directory.fileId, e2eToken: e2eToken, e2eCounter: e2eCounter, method: "POST", account: account, options: NCNetworkingE2EE().getOptions(account: account))
        if resultsLockE2EEFolder.error == .success, let e2eToken = resultsLockE2EEFolder.e2eToken {
            self.database.setE2ETokenLock(account: account, serverUrl: serverUrl, fileId: directory.fileId, e2eToken: e2eToken)
        }

        return (directory.fileId, resultsLockE2EEFolder.e2eToken, resultsLockE2EEFolder.error)
    }

    func unlock(account: String, serverUrl: String) async {
        guard let tableLock = self.database.getE2ETokenLock(account: account, serverUrl: serverUrl) else {
            return
        }

        let resultsLockE2EEFolder = await NextcloudKit.shared.lockE2EEFolder(fileId: tableLock.fileId, e2eToken: tableLock.e2eToken, e2eCounter: nil, method: "DELETE", account: account, options: NCNetworkingE2EE().getOptions(account: account))
        if resultsLockE2EEFolder.error == .success {
            self.database.deleteE2ETokenLock(account: account, serverUrl: serverUrl)
        }

        return
    }

    func unlockAll(account: String) {
        guard NCKeychain().isEndToEndEnabled(account: account) else { return }

        Task {
            for result in self.database.getE2EAllTokenLock(account: account) {
                let resultsLockE2EEFolder = await NextcloudKit.shared.lockE2EEFolder(fileId: result.fileId, e2eToken: result.e2eToken, e2eCounter: nil, method: "DELETE", account: account, options: NCNetworkingE2EE().getOptions(account: account))
                if resultsLockE2EEFolder.error == .success {
                    self.database.deleteE2ETokenLock(account: account, serverUrl: result.serverUrl)
                }
            }
        }
    }
}
