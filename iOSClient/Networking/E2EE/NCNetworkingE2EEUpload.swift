//
//  NCNetworkingE2EEUpload.swift
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

protocol uploadE2EEDelegate: AnyObject {
    func start()
    func uploadE2EEProgress(_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double)
}

extension uploadE2EEDelegate {
    func start() { }
    func uploadE2EEProgress(_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double) {}
}

class NCNetworkingE2EEUpload: NSObject {
    public static let shared: NCNetworkingE2EEUpload = {
        let instance = NCNetworkingE2EEUpload()
        return instance
    }()

    let errorEncodeMetadata = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: NSLocalizedString("_e2e_error_encode_metadata_", comment: ""))
    let errorCreateEncrypted = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_e2e_error_create_encrypted_")

    func upload(metadata: tableMetadata, uploadE2EEDelegate: uploadE2EEDelegate? = nil) async -> (NKError) {

        var metadata = tableMetadata.init(value: metadata)
        let ocIdTemp = metadata.ocId

        // Create metadata for upload
        if let result = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "serverUrl == %@ AND fileNameView == %@ AND ocId != %@", metadata.serverUrl, metadata.fileNameView, metadata.ocId)) {
            metadata.fileName = result.fileName
        } else {
            metadata.fileName = NCNetworkingE2EE.shared.generateRandomIdentifier()
        }
        metadata.session = NextcloudKit.shared.nkCommonInstance.sessionIdentifierUpload
        metadata.sessionError = ""
        guard let result = NCManageDatabase.shared.addMetadata(metadata) else { return errorCreateEncrypted }
        guard let directory = NCManageDatabase.shared.getTableDirectory(predicate:  NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) else { return errorCreateEncrypted }
        metadata = result

        // ** Lock **
        let lockResults = await NCNetworkingE2EE.shared.lock(account: metadata.account, serverUrl: metadata.serverUrl)

        guard let e2eToken = lockResults.e2eToken, let fileId = lockResults.fileId, lockResults.error == .success else {
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp))
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": ocIdTemp, "error": errorCreateEncrypted])
            return errorCreateEncrypted
        }

        // Send e2e metadata
        let createE2EeError = await createE2Ee(metadata: metadata, e2eToken: e2eToken, ocIdServerUrl: directory.ocId, fileId: fileId)
        guard createE2EeError == .success else {
            // ** Unlock **
            await NCNetworkingE2EE.shared.unlock(account: metadata.account, serverUrl: metadata.serverUrl)

            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp))
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": ocIdTemp, "error": createE2EeError])
            return errorCreateEncrypted
        }

        // Send file
        let sendFileResults = await sendFile(metadata: metadata, e2eToken: e2eToken, uploadE2EEDelegate: uploadE2EEDelegate)

        // ** Unlock **
        await NCNetworkingE2EE.shared.unlock(account: metadata.account, serverUrl: metadata.serverUrl)

        if let afError = sendFileResults.afError, afError.isExplicitlyCancelledError {

            CCUtility.removeFile(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId))
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": ocIdTemp, "error": sendFileResults.error])

        } else if sendFileResults.error == .success, let ocId = sendFileResults.ocId {

            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NCUtilityFileSystem.shared.moveFileInBackground(atPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId), toPath: CCUtility.getDirectoryProviderStorageOcId(ocId))

            metadata.date = sendFileResults.date ?? NSDate()
            metadata.etag = sendFileResults.etag ?? ""
            metadata.ocId = ocId
            metadata.chunk = 0

            metadata.session = ""
            metadata.sessionError = ""
            metadata.sessionTaskIdentifier = 0
            metadata.status = NCGlobal.shared.metadataStatusNormal

            NCManageDatabase.shared.addMetadata(metadata)
            NCManageDatabase.shared.addLocalFile(metadata: metadata)
            NCUtility.shared.createImageFrom(fileNameView: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": ocIdTemp, "error": sendFileResults.error])

        } else {

            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId, session: nil, sessionError: sendFileResults.error.errorDescription, sessionTaskIdentifier: 0, status: NCGlobal.shared.metadataStatusUploadError)
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl, "account": metadata.account, "fileName": metadata.fileName, "ocIdTemp": ocIdTemp, "error": sendFileResults.error])
        }

        return(sendFileResults.error)
    }

    private func createE2Ee(metadata: tableMetadata, e2eToken: String, ocIdServerUrl: String, fileId: String) async -> (NKError) {

        var key: NSString?, initializationVector: NSString?, authenticationTag: NSString?
        let object = tableE2eEncryption()
        var method = "POST"

        if NCEndToEndEncryption.sharedManager()?.encryptFile(metadata.fileNameView, fileNameIdentifier: metadata.fileName, directory: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId), key: &key, initializationVector: &initializationVector, authenticationTag: &authenticationTag) == false {
            return errorCreateEncrypted
        }

        // Get last metadata
        let results = await NextcloudKit.shared.getE2EEMetadata(fileId: fileId, e2eToken: e2eToken)
        if results.error == .success, let e2eMetadata = results.e2eMetadata {
            let error = NCEndToEndMetadata().decoderMetadata(e2eMetadata, signature: results.signature, serverUrl: metadata.serverUrl, account: metadata.account, urlBase: metadata.urlBase, userId: metadata.userId, ownerId: metadata.ownerId)
            if error != .success { return error }
            method = "PUT"
        }

        // [REPLACE]
        NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, metadata.fileNameView))

        // Add new metadata
        if let result = NCManageDatabase.shared.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
            object.metadataKey = result.metadataKey
            object.metadataKeyIndex = result.metadataKeyIndex
        } else {
            let key = NCEndToEndEncryption.sharedManager()?.generateKey() as NSData?
            object.metadataKey = key!.base64EncodedString()
            object.metadataKeyIndex = 0
        }
        object.accountOcIdServerUrlFileNameIdentifier = metadata.account + ocIdServerUrl + metadata.fileName
        object.account = metadata.account
        object.authenticationTag = authenticationTag! as String
        object.fileName = metadata.fileNameView
        object.fileNameIdentifier = metadata.fileName
        object.key = key! as String
        object.initializationVector = initializationVector! as String
        object.mimeType = metadata.contentType
        object.ocIdServerUrl = ocIdServerUrl
        object.serverUrl = metadata.serverUrl
        NCManageDatabase.shared.addE2eEncryption(object)

        let resultEncoder = NCEndToEndMetadata().encoderMetadata(account: metadata.account, serverUrl: metadata.serverUrl, userId: metadata.userId)
        if resultEncoder.metadata == nil {
            return errorEncodeMetadata
        }

        // send metadata
        let putE2EEMetadataResults = await NextcloudKit.shared.putE2EEMetadata(fileId: fileId, e2eToken: e2eToken, e2eMetadata: resultEncoder.metadata, signature: resultEncoder.signature, method: method)
        
        return putE2EEMetadataResults.error
    }

    private func sendFile(metadata: tableMetadata, e2eToken: String, uploadE2EEDelegate: uploadE2EEDelegate? = nil) async -> (ocId: String?, etag: String?, date: NSDate? ,afError: AFError?, error: NKError) {

        if metadata.chunk > 0 {

            return await withCheckedContinuation({ continuation in
                NCNetworking.shared.uploadChunkFile(metadata: metadata, withUploadComplete: false, addCustomHeaders: ["e2e-token": e2eToken]) {
                    uploadE2EEDelegate?.start()
                } progressHandler: { totalBytesExpected, totalBytes, fractionCompleted in
                    uploadE2EEDelegate?.uploadE2EEProgress(totalBytesExpected, totalBytes, fractionCompleted)
                } completion: { account, file, afError, error in
                    continuation.resume(returning: (ocId: file?.ocId, etag: file?.etag, date: file?.date ,afError: afError, error: error))
                }
            })

        } else {

            let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)!
            return await withCheckedContinuation({ continuation in
                NCNetworking.shared.uploadFile(metadata: metadata, fileNameLocalPath: fileNameLocalPath, withUploadComplete: false, addCustomHeaders: ["e2e-token": e2eToken]) {
                    uploadE2EEDelegate?.start()
                } progressHandler: { totalBytesExpected, totalBytes, fractionCompleted in
                    uploadE2EEDelegate?.uploadE2EEProgress(totalBytesExpected, totalBytes, fractionCompleted)
                } completion: { account, ocId, etag, date, size, allHeaderFields, afError, error in
                    continuation.resume(returning: (ocId: ocId, etag: etag, date: date ,afError: afError, error: error))
                }
            })
        }
    }
}
