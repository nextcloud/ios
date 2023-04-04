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

    func createFolderAndMarkE2EE(fileName: String, serverUrl: String, account: String) async -> NKError {

        if let error = NCNetworkingE2EE.shared.isE2EEVersionWriteable(account: account) {
            return error
        }

        let serverUrlFileName = serverUrl + "/" + fileName
        var error = NKError()

        // CREATE FOLDER
        let createFolderResults = await NextcloudKit.shared.createFolder(serverUrlFileName: serverUrlFileName)
        if createFolderResults.error != .success { return createFolderResults.error }

        let readFileOrFolderResults = await NextcloudKit.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0")
        error = readFileOrFolderResults.error
        if error == .success, let file = readFileOrFolderResults.files.first {

            // MARK AS E2EE
            let markE2EEFolderResults = await NextcloudKit.shared.markE2EEFolder(fileId: file.fileId, delete: false)
            if markE2EEFolderResults.error != .success { return markE2EEFolderResults.error }

            file.e2eEncrypted = true
            let isDirectoryE2EE = NCUtility.shared.isDirectoryE2EE(file: file)
            guard let metadata = NCManageDatabase.shared.addMetadata(NCManageDatabase.shared.convertFileToMetadata(file, isDirectoryE2EE: isDirectoryE2EE)) else {
                return error
            }
            NCManageDatabase.shared.addDirectory(encrypted: true, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, etag: nil, permissions: metadata.permissions, serverUrl: serverUrlFileName, account: metadata.account)
            NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, serverUrlFileName))

            // LOCK
            let lockResults = await NCNetworkingE2EE.shared.lock(account: account, serverUrl: serverUrlFileName)
            if lockResults.error != .success { return lockResults.error }

            let e2eMetadataNew = NCEndToEndMetadata().encoderMetadata([], account: account, serverUrl: serverUrlFileName)
            let putE2EEMetadataResults = await NextcloudKit.shared.putE2EEMetadata(fileId: file.fileId, e2eToken: lockResults.e2eToken!, e2eMetadata: e2eMetadataNew, method: "POST")
            error = putE2EEMetadataResults.error

            // UNLOCK
            await NCNetworkingE2EE.shared.unlock(account: account, serverUrl: serverUrlFileName)

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeStatusFolderE2EE, userInfo: ["serverUrl": serverUrl])
        }

        return error
    }

    func createFolder(fileName: String, serverUrl: String, account: String, urlBase: String, userId: String, withPush: Bool) async -> (NKError) {

        if let error = NCNetworkingE2EE.shared.isE2EEVersionWriteable(account: account) {
            return error
        }
        
        var fileNameFolder = CCUtility.removeForbiddenCharactersServer(fileName)!
        var serverUrlFileName = ""
        var fileNameIdentifier = ""
        var ocId: String?
        var error = NKError()

        fileNameFolder = NCUtilityFileSystem.shared.createFileName(fileNameFolder, serverUrl: serverUrl, account: account)
        if fileNameFolder.isEmpty { return error }
        fileNameIdentifier = NCNetworkingE2EE.shared.generateRandomIdentifier()
        serverUrlFileName = serverUrl + "/" + fileNameIdentifier

        // ** Lock **
        let lockResults = await NCNetworkingE2EE.shared.lock(account: account, serverUrl: serverUrl)

        error = lockResults.error
        if error == .success, let e2eToken = lockResults.e2eToken, let fileIdLock = lockResults.fileId {

            let createFolderResults = await NextcloudKit.shared.createFolder(serverUrlFileName: serverUrlFileName, options: NKRequestOptions(customHeader: ["e2e-token": e2eToken]))
            error = createFolderResults.error
            ocId = createFolderResults.ocId
            if error == .success, let fileId = NCUtility.shared.ocIdToFileId(ocId: ocId) {
                // Mark folder as E2EE
                let markE2EEFolderResults = await NextcloudKit.shared.markE2EEFolder(fileId: fileId, delete: false)
                error = markE2EEFolderResults.error
                if error == .success {
                    error = await createE2Ee(e2eToken: e2eToken, fileIdLock: fileIdLock, account: account, fileNameFolder: fileNameFolder, fileNameIdentifier: fileNameIdentifier, serverUrl: serverUrl, urlBase: urlBase, userId: userId)
                }
            }
        }

        // ** Unlock **
        await NCNetworkingE2EE.shared.unlock(account: account, serverUrl: serverUrl)
        
        if error == .success, let ocId = ocId {
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterCreateFolder, userInfo: ["ocId": ocId, "serverUrl": serverUrl, "account": account, "e2ee": true, "withPush": withPush])
        }
        return error
    }

    private func createE2Ee(e2eToken: String, fileIdLock: String, account: String, fileNameFolder: String, fileNameIdentifier: String, serverUrl: String,  urlBase: String, userId: String) async -> (NKError) {

        var key: NSString?
        var initializationVector: NSString?
        let object = tableE2eEncryption()
        var method = "POST"

        // Get last metadata
        let getE2EEMetadataResults = await NextcloudKit.shared.getE2EEMetadata(fileId: fileIdLock, e2eToken: e2eToken)
        if getE2EEMetadataResults.error == .success, let e2eMetadata = getE2EEMetadataResults.e2eMetadata {
            let result = NCEndToEndMetadata().decoderMetadata(e2eMetadata, serverUrl: serverUrl, account: account, urlBase: urlBase, userId: userId, ownerId: nil)
            if result.error != .success { return result.error }
            method = "PUT"
        }

        // Add new metadata
        NCEndToEndEncryption.sharedManager()?.encodedkey(&key, initializationVector: &initializationVector)
        object.account = account
        object.authenticationTag = ""
        object.fileName = fileNameFolder
        object.fileNameIdentifier = fileNameIdentifier
        object.fileNamePath = ""
        object.key = key! as String
        object.initializationVector = initializationVector! as String
        if let result = NCManageDatabase.shared.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) {
            object.metadataKey = result.metadataKey
            object.metadataKeyIndex = result.metadataKeyIndex
        } else {
            object.metadataKey = (NCEndToEndEncryption.sharedManager()?.generateKey()?.base64EncodedString(options: []))! as String // AES_KEY_128_LENGTH
            object.metadataKeyIndex = 0
        }
        object.mimeType = "httpd/unix-directory"
        object.serverUrl = serverUrl
        NCManageDatabase.shared.addE2eEncryption(object)

        // Rebuild metadata for send it
        guard let tableE2eEncryption = NCManageDatabase.shared.getE2eEncryptions(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)), let e2eMetadataNew = NCEndToEndMetadata().encoderMetadata(tableE2eEncryption, account: account, serverUrl: serverUrl) else {
            return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: NSLocalizedString("_e2e_error_encode_metadata_", comment: ""))
        }

        // send metadata
        let putE2EEMetadataResults =  await NextcloudKit.shared.putE2EEMetadata(fileId: fileIdLock, e2eToken: e2eToken, e2eMetadata: e2eMetadataNew, method: method)
        return putE2EEMetadataResults.error
    }

    func markE2EEFolder(account: String, serverUrl: String, fileId: String, ocId: String) async -> (NKError) {

        let markE2EEFolderResult = await NextcloudKit.shared.markE2EEFolder(fileId: fileId, delete: false)
        if markE2EEFolderResult.error != .success { return markE2EEFolderResult.error }

        NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl))
        NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, serverUrlTo: nil, etag: nil, ocId: nil, fileId: nil, encrypted: true, richWorkspace: nil, account: account)
        NCManageDatabase.shared.setMetadataEncrypted(ocId: ocId, encrypted: true)

        // LOCK
        let lockResults = await NCNetworkingE2EE.shared.lock(account: account, serverUrl: serverUrl)
        if lockResults.error != .success { return lockResults.error }

        let e2eMetadataNew = NCEndToEndMetadata().encoderMetadata([], account: account, serverUrl: serverUrl)
        let putE2EEMetadataResults = await NextcloudKit.shared.putE2EEMetadata(fileId: fileId, e2eToken: lockResults.e2eToken!, e2eMetadata: e2eMetadataNew, method: "POST")
        let error = putE2EEMetadataResults.error

        // UNLOCK
        await NCNetworkingE2EE.shared.unlock(account: account, serverUrl: serverUrl)

        return error
    }
}
