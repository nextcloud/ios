// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import Alamofire

class NCNetworkingE2EE: NSObject {
    let database = NCManageDatabase.shared
    let e2EEApiVersion1 = "v1"
    let e2EEApiVersion2 = "v2"

    func isInUpload(account: String, serverUrl: String) async -> Bool {
        let counter = await self.database.getMetadatasAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND (status == %d OR status == %d)",
                                                                                   account,
                                                                                   serverUrl,
                                                                                   NCGlobal.shared.metadataStatusWaitUpload,
                                                                                   NCGlobal.shared.metadataStatusUploading))?.count ?? 0

        return counter > 0 ? true : false
    }

    func generateRandomIdentifier() -> String {
        var UUID = NSUUID().uuidString
        UUID = "E2EE" + UUID.replacingOccurrences(of: "-", with: "")
        return UUID
    }

    func getOptions(account: String) -> NKRequestOptions {
        let capabilities = NKCapabilities.shared.getCapabilitiesBlocking(for: account)
        let version = capabilities.e2EEApiVersion == NCGlobal.shared.e2eeVersionV20 ? e2EEApiVersion2 : e2EEApiVersion1
        return NKRequestOptions(version: version)
    }

    // MARK: -

    func getMetadata(fileId: String,
                     e2eToken: String?,
                     account: String) async -> (account: String,
                                                version: String?,
                                                e2eMetadata: String?,
                                                signature: String?,
                                                responseData: AFDataResponse<Data>?,
                                                error: NKError) {
        let capabilities = NKCapabilities.shared.getCapabilitiesBlocking(for: account)

        switch capabilities.e2EEApiVersion {
        case NCGlobal.shared.e2eeVersionV11, NCGlobal.shared.e2eeVersionV12:
            let options = NKRequestOptions(version: e2EEApiVersion1)
            let results = await NextcloudKit.shared.getE2EEMetadataAsync(fileId: fileId, e2eToken: e2eToken, account: account, options: options) { task in
                print("Task started:", task)
            }
            return (results.account, self.e2EEApiVersion1, results.e2eMetadata, results.signature, results.responseData, results.error)
        case NCGlobal.shared.e2eeVersionV20:
            var options = NKRequestOptions(version: e2EEApiVersion2)
            let results = await NextcloudKit.shared.getE2EEMetadataAsync(fileId: fileId, e2eToken: e2eToken, account: account, options: options) { task in
                print("Task started:", task)
            }
            if results.error == .success || results.error.errorCode == NCGlobal.shared.errorResourceNotFound {
                return (results.account, self.e2EEApiVersion2, results.e2eMetadata, results.signature, results.responseData, results.error)
            } else {
                options = NKRequestOptions(version: self.e2EEApiVersion1)
                let results = await NextcloudKit.shared.getE2EEMetadataAsync(fileId: fileId, e2eToken: e2eToken, account: account, options: options) { task in
                    print("Task started:", task)
                }
                if results.error == .success || results.error.errorCode == NCGlobal.shared.errorResourceNotFound {
                    return (results.account, self.e2EEApiVersion2, results.e2eMetadata, results.signature, results.responseData, results.error)
                } else {
                    options = NKRequestOptions(version: self.e2EEApiVersion1)
                    let results = await NextcloudKit.shared.getE2EEMetadataAsync(fileId: fileId, e2eToken: e2eToken, account: account, options: options) { task in
                        print("Task started:", task)
                    }
                    return (results.account, self.e2EEApiVersion1, results.e2eMetadata, results.signature, results.responseData, results.error)
                }
            }
        default:
            return ("", "", nil, nil, nil, NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "version e2ee not available"))
        }
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
            let results = await NextcloudKit.shared.getE2EECertificateAsync(user: addUserId, account: session.account, options: NCNetworkingE2EE().getOptions(account: account))
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
        let resultsEncodeMetadata = await NCEndToEndMetadata().encodeMetadata(serverUrl: serverUrl, addUserId: addUserId, addCertificate: addCertificate, removeUserId: removeUserId, session: session)
        guard resultsEncodeMetadata.error == .success,
              let e2eMetadata = resultsEncodeMetadata.metadata else {
            // Client Diagnostic
            await self.database.addDiagnosticAsync(account: session.account, issue: NCGlobal.shared.diagnosticIssueE2eeErrors)
            return resultsEncodeMetadata.error
        }
        let capabilities = NKCapabilities.shared.getCapabilitiesBlocking(for: session.account)

        let putE2EEMetadataResults = await NextcloudKit.shared.putE2EEMetadataAsync(fileId: fileId, e2eToken: e2eToken, e2eMetadata: e2eMetadata, signature: resultsEncodeMetadata.signature, method: method, account: session.account, options: NCNetworkingE2EE().getOptions(account: session.account))
        guard putE2EEMetadataResults.error == .success else {
            return putE2EEMetadataResults.error
        }

        // COUNTER
        //
        if capabilities.e2EEApiVersion == NCGlobal.shared.e2eeVersionV20 {
            await self.database.updateCounterE2eMetadataAsync(account: session.account, ocIdServerUrl: ocIdServerUrl, counter: resultsEncodeMetadata.counter)
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

        let resultsDecodeMetadataError = await NCEndToEndMetadata().decodeMetadata(e2eMetadata, signature: resultsGetE2EEMetadata.signature, serverUrl: serverUrl, session: session)
        guard resultsDecodeMetadataError == .success else {
            // Client Diagnostic
            await self.database.addDiagnosticAsync(account: session.account, issue: NCGlobal.shared.diagnosticIssueE2eeErrors)
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
        let capabilities = NKCapabilities.shared.getCapabilitiesBlocking(for: account)

        if let tableLock = await self.database.getE2ETokenLockAsync(account: account, serverUrl: serverUrl) {
            e2eToken = tableLock.e2eToken
        }

        if capabilities.e2EEApiVersion == NCGlobal.shared.e2eeVersionV20,
           var counter = await self.database.getCounterE2eMetadataAsync(account: account, ocIdServerUrl: directory.ocId) {
            counter += 1
            e2eCounter = "\(counter)"
        }

        let resultsLockE2EEFolder = await NextcloudKit.shared.lockE2EEFolderAsync(fileId: directory.fileId, e2eToken: e2eToken, e2eCounter: e2eCounter, method: "POST", account: account, options: NCNetworkingE2EE().getOptions(account: account))
        if resultsLockE2EEFolder.error == .success, let e2eToken = resultsLockE2EEFolder.e2eToken {
            await self.database.setE2ETokenLockAsync(account: account, serverUrl: serverUrl, fileId: directory.fileId, e2eToken: e2eToken)
        }

        return (directory.fileId, resultsLockE2EEFolder.e2eToken, resultsLockE2EEFolder.error)
    }

    func unlock(account: String, serverUrl: String) async {
        guard let tableLock = await self.database.getE2ETokenLockAsync(account: account, serverUrl: serverUrl) else {
            return
        }

        let resultsLockE2EEFolder = await NextcloudKit.shared.lockE2EEFolderAsync(fileId: tableLock.fileId, e2eToken: tableLock.e2eToken, e2eCounter: nil, method: "DELETE", account: account, options: NCNetworkingE2EE().getOptions(account: account))
        if resultsLockE2EEFolder.error == .success {
            await self.database.deleteE2ETokenLockAsync(account: account, serverUrl: serverUrl)
        }

        return
    }

    func unlockAll(account: String) async {
        guard NCKeychain().isEndToEndEnabled(account: account) else { return }

        let results = await self.database.getE2EAllTokenLockAsync(account: account)
        for result in results {
            let resultsLockE2EEFolder = await NextcloudKit.shared.lockE2EEFolderAsync(fileId: result.fileId, e2eToken: result.e2eToken, e2eCounter: nil, method: "DELETE", account: account, options: NCNetworkingE2EE().getOptions(account: account))
            if resultsLockE2EEFolder.error == .success {
                await self.database.deleteE2ETokenLockAsync(account: account, serverUrl: result.serverUrl)
            }
        }
    }
}
