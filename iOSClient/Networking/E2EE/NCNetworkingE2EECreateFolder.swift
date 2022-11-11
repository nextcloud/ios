//
//  NCNetworkingE2EECreateFolder.swift
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

class NCNetworkingE2EECreateFolder: NSObject {
    public static let shared: NCNetworkingE2EECreateFolder = {
        let instance = NCNetworkingE2EECreateFolder()
        return instance
    }()

    func createFolder(fileName: String, serverUrl: String, account: String, urlBase: String, userId: String) async -> (NKError) {

        var fileNameFolder = CCUtility.removeForbiddenCharactersServer(fileName)!
        var serverUrlFileName = ""
        var fileNameIdentifier = ""

        fileNameFolder = NCUtilityFileSystem.shared.createFileName(fileNameFolder, serverUrl: serverUrl, account: account)
        if fileNameFolder.isEmpty {
            return NKError()
        }
        fileNameIdentifier = NCNetworkingE2EE.shared.generateRandomIdentifier()
        serverUrlFileName = serverUrl + "/" + fileNameIdentifier

        // Lock
        let lockResults = await NCNetworkingE2EE.shared.lock(account: account, serverUrl: serverUrl)

        if lockResults.error == .success, let e2eToken = lockResults.e2eToken {

            let options = NKRequestOptions(customHeader: ["e2e-token": e2eToken])
            let createFolderResults = await NextcloudKit.shared.createFolder(serverUrlFileName: serverUrlFileName, options: options)

            if createFolderResults.error == .success {
                guard let fileId = NCUtility.shared.ocIdToFileId(ocId: createFolderResults.ocId) else {
                    // unlock
                    if let tableLock = NCManageDatabase.shared.getE2ETokenLock(account: account, serverUrl: serverUrl) {
                        await NextcloudKit.shared.lockE2EEFolder(fileId: tableLock.fileId, e2eToken: tableLock.e2eToken, method: "DELETE")
                    }
                    return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "Error convert ocId")
                }

                // Mark folder as E2EE
                let markE2EEFolderResults = await NextcloudKit.shared.markE2EEFolder(fileId: fileId, delete: false)

                if markE2EEFolderResults.error == .success {

                    let sendE2EMetadataResults = await createE2Ee(account: account, fileNameFolder: fileNameFolder, fileNameIdentifier: fileNameIdentifier, serverUrl: serverUrl, urlBase: urlBase, userId: userId)

                    // Unlock
                    if let tableLock = NCManageDatabase.shared.getE2ETokenLock(account: account, serverUrl: serverUrl) {
                        await NextcloudKit.shared.lockE2EEFolder(fileId: tableLock.fileId, e2eToken: tableLock.e2eToken, method: "DELETE")
                    }

                    if sendE2EMetadataResults.error == .success, let ocId = createFolderResults.ocId {
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterCreateFolder, userInfo: ["ocId": ocId, "serverUrl": serverUrl, "account": account, "e2ee": true])
                    }

                    return sendE2EMetadataResults.error

                } else {

                    // Unlock
                    if let tableLock = NCManageDatabase.shared.getE2ETokenLock(account: account, serverUrl: serverUrl) {
                        await NextcloudKit.shared.lockE2EEFolder(fileId: tableLock.fileId, e2eToken: tableLock.e2eToken, method: "DELETE")
                    }

                    return markE2EEFolderResults.error
                }
            } else {
                return createFolderResults.error
            }
        } else {
            return lockResults.error
        }
    }

    private func createE2Ee(account: String, fileNameFolder: String, fileNameIdentifier: String, serverUrl: String, urlBase: String, userId: String) async -> (e2eToken: String?, error: NKError) {

        var key: NSString?
        var initializationVector: NSString?
        let object = tableE2eEncryption()

        NCEndToEndEncryption.sharedManager()?.encryptkey(&key, initializationVector: &initializationVector)
        object.account = account
        object.authenticationTag = nil
        object.fileName = fileNameFolder
        object.fileNameIdentifier = fileNameIdentifier
        object.fileNamePath = ""
        object.key = key! as String
        object.initializationVector = initializationVector! as String
        if let result = NCManageDatabase.shared.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) {
            object.metadataKey = result.metadataKey
            object.metadataKeyIndex = result.metadataKeyIndex
        } else {
            object.metadataKey = (NCEndToEndEncryption.sharedManager()?.generateKey(16)?.base64EncodedString(options: []))! as String // AES_KEY_128_LENGTH
            object.metadataKeyIndex = 0
        }
        object.mimeType = "httpd/unix-directory"
        object.serverUrl = serverUrl
        object.version = 1
        NCManageDatabase.shared.addE2eEncryption(object)

        // Send metadata
        return await NCNetworkingE2EE.shared.sendE2EMetadata(account: account, serverUrl: serverUrl, fileNameRename: nil, fileNameNewRename: nil, deleteE2eEncryption: nil, urlBase: urlBase, userId: userId)
    }

    func createFolderAndMarkE2EE(fileName: String, serverUrl: String) async -> NKError {

        let serverUrlFileName = serverUrl + "/" + fileName
        let createFolderResults = await NextcloudKit.shared.createFolder(serverUrlFileName: serverUrlFileName)
        if createFolderResults.error != .success { return createFolderResults.error }

        let readFileOrFolderResults = await NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0")
        if readFileOrFolderResults.error == .success, let file = readFileOrFolderResults.files.first {

            let metadata = NCManageDatabase.shared.convertNCFileToMetadata(file, isEncrypted: false, account: readFileOrFolderResults.account)
            NCManageDatabase.shared.addMetadata(metadata)

            NCManageDatabase.shared.addDirectory(encrypted: false, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, etag: nil, permissions: metadata.permissions, serverUrl: serverUrlFileName, account: metadata.account)

            let markE2EEFolderResults = await NextcloudKit.shared.markE2EEFolder(fileId: metadata.fileId, delete: false)
            if markE2EEFolderResults.error != .success { return markE2EEFolderResults.error }

            NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl))

            NCManageDatabase.shared.setDirectory(serverUrl: serverUrlFileName, serverUrlTo: nil, etag: nil, ocId: nil, fileId: nil, encrypted: true, richWorkspace: nil, account: metadata.account)

            NCManageDatabase.shared.setMetadataEncrypted(ocId: metadata.ocId, encrypted: true)

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeStatusFolderE2EE, userInfo: ["serverUrl": serverUrlFileName])

            return markE2EEFolderResults.error
        } else {
            return readFileOrFolderResults.error
        }
    }
}
