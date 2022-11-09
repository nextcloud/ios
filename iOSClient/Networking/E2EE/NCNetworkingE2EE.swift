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

@objc class NCNetworkingE2EE: NSObject {
    @objc public static let shared: NCNetworkingE2EE = {
        let instance = NCNetworkingE2EE()
        return instance
    }()

    func lock(account: String, serverUrl: String) async -> (directory: tableDirectory?, e2eToken: String?, error: NKError) {

        var e2eToken: String?

        guard let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) else {
            return (nil, nil, NKError())
        }

        if let tableLock = NCManageDatabase.shared.getE2ETokenLock(account: account, serverUrl: serverUrl) {
            e2eToken = tableLock.e2eToken
        }

        let lockE2EEFolderResults = await NextcloudKit.shared.lockE2EEFolder(fileId: directory.fileId, e2eToken: e2eToken, method: "POST")
        if lockE2EEFolderResults.error == .success, let e2eToken = lockE2EEFolderResults.e2eToken {
            NCManageDatabase.shared.setE2ETokenLock(account: account, serverUrl: serverUrl, fileId: directory.fileId, e2eToken: e2eToken)
        }

        return (directory, lockE2EEFolderResults.e2eToken, lockE2EEFolderResults.error)
    }

    @discardableResult
    func unlock(account: String, serverUrl: String) async -> (directory: tableDirectory?, e2eToken: String?, error: NKError) {

        var e2eToken: String?

        guard let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) else {
            return (nil, nil, NKError())
        }

        if let tableLock = NCManageDatabase.shared.getE2ETokenLock(account: account, serverUrl: serverUrl) {
            e2eToken = tableLock.e2eToken
        }

        let lockE2EEFolderResults = await NextcloudKit.shared.lockE2EEFolder(fileId: directory.fileId, e2eToken: e2eToken, method: "DELETE")
        if lockE2EEFolderResults.error == .success {
            NCManageDatabase.shared.deteleE2ETokenLock(account: account, serverUrl: serverUrl)
        }

        return (directory, lockE2EEFolderResults.e2eToken, lockE2EEFolderResults.error)
    }

    func sendE2EMetadata(account: String, serverUrl: String, fileNameRename: String?, fileNameNewRename: String?, deleteE2eEncryption: NSPredicate?, urlBase: String, userId: String, upload: Bool = false) async -> (e2eToken: String?, error: NKError) {

        // Lock
        let lockResults = await lock(account: account, serverUrl: serverUrl)

        if lockResults.error == .success, let e2eToken = lockResults.e2eToken, let directory = lockResults.directory {
            let getE2EEMetadataResults = await  NextcloudKit.shared.getE2EEMetadata(fileId: directory.fileId, e2eToken: e2eToken)

            var method = "POST"
            var e2eMetadataNew: String?

            if getE2EEMetadataResults.error == .success, let e2eMetadata = getE2EEMetadataResults.e2eMetadata {
                if !NCEndToEndMetadata.shared.decoderMetadata(e2eMetadata, privateKey: CCUtility.getEndToEndPrivateKey(account), serverUrl: serverUrl, account: account, urlBase: urlBase, userId: userId) {
                    return (e2eToken, NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: NSLocalizedString("_e2e_error_encode_metadata_", comment: "")))
                }
                method = "PUT"
            }

            // Rename
            if let fileNameRename = fileNameRename, let fileNameNewRename = fileNameNewRename {
                NCManageDatabase.shared.renameFileE2eEncryption(serverUrl: serverUrl, fileNameIdentifier: fileNameRename, newFileName: fileNameNewRename, newFileNamePath: CCUtility.returnFileNamePath(fromFileName: fileNameNewRename, serverUrl: serverUrl, urlBase: urlBase, userId: userId, account: account))
            }

            // Delete
            if let deleteE2eEncryption = deleteE2eEncryption {
                NCManageDatabase.shared.deleteE2eEncryption(predicate: deleteE2eEncryption)
            }

            // Rebuild metadata for send it
            if let tableE2eEncryption = NCManageDatabase.shared.getE2eEncryptions(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) {
                e2eMetadataNew = NCEndToEndMetadata.shared.encoderMetadata(tableE2eEncryption, privateKey: CCUtility.getEndToEndPrivateKey(account), serverUrl: serverUrl)
            } else {
                method = "DELETE"
            }

            // send metadata
            let putE2EEMetadataResults =  await NextcloudKit.shared.putE2EEMetadata(fileId: directory.fileId, e2eToken: e2eToken, e2eMetadata: e2eMetadataNew, method: method)
            if upload {
                return (e2eToken, putE2EEMetadataResults.error)
            } else {
                let unlockResults = await unlock(account: account, serverUrl: serverUrl)
                return (unlockResults.e2eToken, unlockResults.error)
            }
        } else {
            return (lockResults.e2eToken, lockResults.error)
        }
    }
}
