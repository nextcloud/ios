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

import UIKit
import OpenSSL
import NextcloudKit
import CFNetwork
import Alamofire

class NCNetworkingE2EE: NSObject {
    public static let shared: NCNetworkingE2EE = {
        let instance = NCNetworkingE2EE()
        return instance
    }()

    func generateRandomIdentifier() -> String {

        var UUID = NSUUID().uuidString
        UUID = "E2EE" + UUID.replacingOccurrences(of: "-", with: "")
        return UUID
    }

    func uploadMetadata(account: String, serverUrl: String, userId: String, addUserId: String?) async -> (NKError) {

        var error = NKError()
        var addCertificate: String?

        if let addUserId {
            let results = await NextcloudKit.shared.getE2EECertificate(user: addUserId)
            if results.error == .success, let certificateUser = results.certificateUser {
                addCertificate = certificateUser
            } else {
                return results.error
            }
        }

        let encoderResults = NCEndToEndMetadata().encoderMetadata(account: account, serverUrl: serverUrl, userId: userId, addUserId: addUserId, addCertificate: addCertificate)

        guard let metadata = encoderResults.metadata, let signature = encoderResults.signature else {
            return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: NSLocalizedString("_e2e_error_encode_metadata_", comment: ""))
        }

        let results = await NCNetworkingE2EE.shared.lock(account: account, serverUrl: serverUrl)
        error = results.error

        if error == .success, let e2eToken = results.e2eToken, let fileId = results.fileId {

            let results = await NextcloudKit.shared.putE2EEMetadata(fileId: fileId, e2eToken: e2eToken, e2eMetadata: metadata, signature: signature, method: "PUT")
            error = results.error
        }

        await NCNetworkingE2EE.shared.unlock(account: account, serverUrl: serverUrl)

        return error
    }

    func lock(account: String, serverUrl: String) async -> (fileId: String?, e2eToken: String?, error: NKError) {

        var e2eToken: String?
        let e2EEApiVersion = NCGlobal.shared.capabilityE2EEApiVersion
        var e2eCounter = "0"

        guard let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) else {
            return (nil, nil, NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_e2e_error_lock_"))
        }

        if let tableLock = NCManageDatabase.shared.getE2ETokenLock(account: account, serverUrl: serverUrl) {
            e2eToken = tableLock.e2eToken
        }

        if e2EEApiVersion == NCGlobal.shared.e2eeVersion20, let result = NCManageDatabase.shared.getE2eMetadataV2(account: account, ocIdServerUrl: directory.ocId) {
            e2eCounter = "\(result.counter)"
        }

        let lockE2EEFolderResults = await NextcloudKit.shared.lockE2EEFolder(fileId: directory.fileId, e2eToken: e2eToken, e2eCounter: e2eCounter, method: "POST")
        if lockE2EEFolderResults.error == .success, let e2eToken = lockE2EEFolderResults.e2eToken {
            NCManageDatabase.shared.setE2ETokenLock(account: account, serverUrl: serverUrl, fileId: directory.fileId, e2eToken: e2eToken)
        }

        return (directory.fileId, lockE2EEFolderResults.e2eToken, lockE2EEFolderResults.error)
    }

    func unlock(account: String, serverUrl: String) async -> () {

        guard let tableLock = NCManageDatabase.shared.getE2ETokenLock(account: account, serverUrl: serverUrl) else {
            return
        }

        let lockE2EEFolderResults = await NextcloudKit.shared.lockE2EEFolder(fileId: tableLock.fileId, e2eToken: tableLock.e2eToken, e2eCounter: nil, method: "DELETE")
        if lockE2EEFolderResults.error == .success {
            NCManageDatabase.shared.deleteE2ETokenLock(account: account, serverUrl: serverUrl)
        }

        return
    }

    func unlockAll(account: String) {
        guard CCUtility.isEnd(toEndEnabled: account) else { return }

        Task {
            for result in NCManageDatabase.shared.getE2EAllTokenLock(account: account) {
                let lockE2EEFolderResults = await NextcloudKit.shared.lockE2EEFolder(fileId: result.fileId, e2eToken: result.e2eToken, e2eCounter: nil, method: "DELETE")
                if lockE2EEFolderResults.error == .success {
                    NCManageDatabase.shared.deleteE2ETokenLock(account: account, serverUrl: result.serverUrl)
                }
            }
        }
    }
}
