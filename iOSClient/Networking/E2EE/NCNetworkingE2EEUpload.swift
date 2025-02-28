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
    let networkingE2EE = NCNetworkingE2EE()
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let database = NCManageDatabase.shared
    var numChunks: Int = 0

    func upload(metadata: tableMetadata, uploadE2EEDelegate: uploadE2EEDelegate?, controller: UIViewController?) async -> NKError {
        var metadata = metadata
        let session = NCSession.shared.getSession(account: metadata.account)
        let hud = await NCHud(controller?.view)

        if let result = self.database.getMetadata(predicate: NSPredicate(format: "serverUrl == %@ AND fileNameView == %@ AND ocId != %@", metadata.serverUrl, metadata.fileNameView, metadata.ocId)) {
            metadata.fileName = result.fileName
        } else {
            metadata.fileName = networkingE2EE.generateRandomIdentifier()
        }
        metadata.session = NCNetworking.shared.sessionUpload
        metadata.sessionError = ""

        metadata = self.database.addMetadata(metadata)

        guard let directory = self.database.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) else {
            return NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
        }

        func sendE2ee(e2eToken: String, fileId: String) async -> NKError {
            var key: NSString?, initializationVector: NSString?, authenticationTag: NSString?
            var method = "POST"

            // ENCRYPT FILE
            //
            if NCEndToEndEncryption.shared().encryptFile(metadata.fileNameView, fileNameIdentifier: metadata.fileName, directory: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId), key: &key, initializationVector: &initializationVector, authenticationTag: &authenticationTag) == false {
                return NKError(errorCode: NCGlobal.shared.errorE2EEEncryptFile, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
            }
            guard let key = key as? String, let initializationVector = initializationVector as? String else {
                return NKError(errorCode: NCGlobal.shared.errorE2EEEncodedKey, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
            }

            // DOWNLOAD METADATA
            //
            let errorDownloadMetadata = await networkingE2EE.downloadMetadata(serverUrl: metadata.serverUrl, fileId: fileId, e2eToken: e2eToken, session: session)
            if errorDownloadMetadata == .success {
                method = "PUT"
            } else if errorDownloadMetadata.errorCode != NCGlobal.shared.errorResourceNotFound {
                return errorDownloadMetadata
            }

            // CREATE E2E METADATA
            //
            self.database.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, metadata.fileNameView))
            let object = tableE2eEncryption.init(account: metadata.account, ocIdServerUrl: directory.ocId, fileNameIdentifier: metadata.fileName)
            if let results = self.database.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
                object.metadataKey = results.metadataKey
                object.metadataKeyIndex = results.metadataKeyIndex
            } else {
                guard let key = NCEndToEndEncryption.shared().generateKey() as NSData? else {
                    return NKError(errorCode: NCGlobal.shared.errorE2EEGenerateKey, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
                }
                object.metadataKey = key.base64EncodedString()
                object.metadataKeyIndex = 0
            }
            object.authenticationTag = authenticationTag! as String
            object.fileName = metadata.fileNameView
            object.key = key
            object.initializationVector = initializationVector
            object.mimeType = metadata.contentType
            object.serverUrl = metadata.serverUrl
            self.database.addE2eEncryption(object)

            // UPLOAD METADATA
            //
            let uploadMetadataError = await networkingE2EE.uploadMetadata(serverUrl: metadata.serverUrl,
                                                                          ocIdServerUrl: directory.ocId,
                                                                          fileId: fileId,
                                                                          e2eToken: e2eToken,
                                                                          method: method,
                                                                          session: session)

            return uploadMetadataError
        }

        // LOCK
        //
        let resultsLock = await networkingE2EE.lock(account: metadata.account, serverUrl: metadata.serverUrl)
        guard let e2eToken = resultsLock.e2eToken, let fileId = resultsLock.fileId, resultsLock.error == .success else {
            self.database.deleteMetadata(predicate: NSPredicate(format: "ocIdTransfer == %@", metadata.ocIdTransfer))
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile,
                                                        object: nil,
                                                        userInfo: ["ocId": metadata.ocId,
                                                                   "ocIdTransfer": metadata.ocIdTransfer,
                                                                   "session": metadata.session,
                                                                   "serverUrl": metadata.serverUrl,
                                                                   "account": metadata.account,
                                                                   "fileName": metadata.fileName,
                                                                   "error": NKError(errorCode: NCGlobal.shared.errorE2EELock, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))],
                                                        second: 0.5)
            return NKError(errorCode: NCGlobal.shared.errorE2EELock, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
        }

        // HUD ENCRYPTION
        //
        hud.initHud(text: NSLocalizedString("_wait_file_encryption_", comment: ""))

        // SEND NEW METADATA
        //
        let sendE2eeError = await sendE2ee(e2eToken: e2eToken, fileId: fileId)
        guard sendE2eeError == .success else {
            hud.dismiss()
            self.database.deleteMetadata(predicate: NSPredicate(format: "ocIdTransfer == %@", metadata.ocIdTransfer))
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile,
                                                        object: nil,
                                                        userInfo: ["ocId": metadata.ocId,
                                                                   "ocIdTransfer": metadata.ocIdTransfer,
                                                                   "session": metadata.session,
                                                                   "serverUrl": metadata.serverUrl,
                                                                   "account": metadata.account,
                                                                   "fileName": metadata.fileName,
                                                                   "error": sendE2eeError],
                                                        second: 0.5)
            await networkingE2EE.unlock(account: metadata.account, serverUrl: metadata.serverUrl)
            return sendE2eeError
        }

        // HUD CHUNK
        //
        hud.initHudRing(text: NSLocalizedString("_wait_file_preparation_", comment: ""),
                        tapToCancelDetailText: true) {
            NotificationCenter.default.postOnMainThread(name: "NextcloudKit.chunkedFile.stop")
        }

        // UPLOAD
        //
        let resultsSendFile = await sendFile(metadata: metadata, e2eToken: e2eToken, hud: hud, uploadE2EEDelegate: uploadE2EEDelegate, controller: controller)

        // UNLOCK
        //
        await networkingE2EE.unlock(account: metadata.account, serverUrl: metadata.serverUrl)

        if let afError = resultsSendFile.afError, afError.isExplicitlyCancelledError {

            utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
            self.database.deleteMetadataOcId(metadata.ocId)
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile,
                                                        object: nil,
                                                        userInfo: ["ocId": metadata.ocId,
                                                                   "ocIdTransfer": metadata.ocIdTransfer,
                                                                   "session": metadata.session,
                                                                   "serverUrl": metadata.serverUrl,
                                                                   "account": metadata.account,
                                                                   "fileName": metadata.fileName,
                                                                   "error": resultsSendFile.error],
                                                        second: 0.5)

        } else if resultsSendFile.error == .success, let ocId = resultsSendFile.ocId {

            self.database.deleteMetadataOcId(metadata.ocId)
            utilityFileSystem.moveFileInBackground(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId), toPath: utilityFileSystem.getDirectoryProviderStorageOcId(ocId))

            metadata.date = (resultsSendFile.date as? NSDate) ?? NSDate()
            metadata.etag = resultsSendFile.etag ?? ""
            metadata.ocId = ocId
            if let fileId = self.utility.ocIdToFileId(ocId: ocId) {
                metadata.fileId = fileId
            }
            metadata.chunk = 0

            metadata.session = ""
            metadata.sessionTaskIdentifier = 0
            metadata.sessionError = ""
            metadata.status = NCGlobal.shared.metadataStatusNormal

            self.database.addMetadata(metadata)
            self.database.addLocalFile(metadata: metadata)
            utility.createImageFileFrom(metadata: metadata)
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile,
                                                        object: nil,
                                                        userInfo: ["ocId": metadata.ocId,
                                                                   "ocIdTransfer": metadata.ocIdTransfer,
                                                                   "session": metadata.session,
                                                                   "serverUrl": metadata.serverUrl,
                                                                   "account": metadata.account,
                                                                   "fileName": metadata.fileName,
                                                                   "error": resultsSendFile.error],
                                                        second: 0.5)

            // LIVE PHOTO
            if metadata.isLivePhoto,
               NCCapabilities.shared.getCapabilities(account: metadata.account).isLivePhotoServerAvailable {
                NCNetworking.shared.createLivePhoto(metadata: metadata)
            }
        } else {
            self.database.setMetadataSession(ocId: metadata.ocId,
                                             sessionTaskIdentifier: 0,
                                             sessionError: resultsSendFile.error.errorDescription,
                                             status: NCGlobal.shared.metadataStatusUploadError,
                                             errorCode: resultsSendFile.error.errorCode)
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterUploadedFile,
                                                        object: nil,
                                                        userInfo: ["ocId": metadata.ocId,
                                                                   "ocIdTransfer": metadata.ocIdTransfer,
                                                                   "session": metadata.session,
                                                                   "serverUrl": metadata.serverUrl,
                                                                   "account": metadata.account,
                                                                   "fileName": metadata.fileName,
                                                                   "error": resultsSendFile.error],
                                                        second: 0.5)
        }

        return (resultsSendFile.error)
    }

    // BRIDGE for chunk
    //
    private func sendFile(metadata: tableMetadata, e2eToken: String, hud: NCHud?, uploadE2EEDelegate: uploadE2EEDelegate? = nil, controller: UIViewController?) async -> (ocId: String?, etag: String?, date: Date?, afError: AFError?, error: NKError) {

        if metadata.chunk > 0 {

            return await withCheckedContinuation({ continuation in
                NCNetworking.shared.uploadChunkFile(metadata: metadata, withUploadComplete: false, customHeaders: ["e2e-token": e2eToken]) { num in
                    self.numChunks = num
                } counterChunk: { counter in
                    hud?.progress(num: Float(counter), total: Float(self.numChunks))
                } start: {
                    hud?.dismiss()
                    uploadE2EEDelegate?.start()
                } progressHandler: {totalBytesExpected, totalBytes, fractionCompleted in
                    uploadE2EEDelegate?.uploadE2EEProgress(totalBytesExpected, totalBytes, fractionCompleted)
                } completion: { _, file, afError, error in
                    DispatchQueue.main.async { hud?.dismiss() }
                    continuation.resume(returning: (ocId: file?.ocId, etag: file?.etag, date: file?.date, afError: afError, error: error))
                }
            })

        } else {

            let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)
            return await withCheckedContinuation({ continuation in
                NCNetworking.shared.uploadFile(metadata: metadata, fileNameLocalPath: fileNameLocalPath, withUploadComplete: false, customHeaders: ["e2e-token": e2eToken], controller: controller) {
                    DispatchQueue.main.async { hud?.dismiss() }
                    uploadE2EEDelegate?.start()
                } progressHandler: { totalBytesExpected, totalBytes, fractionCompleted in
                    uploadE2EEDelegate?.uploadE2EEProgress(totalBytesExpected, totalBytes, fractionCompleted)
                } completion: { _, ocId, etag, date, _, _, afError, error in
                    continuation.resume(returning: (ocId: ocId, etag: etag, date: date, afError: afError, error: error))
                }
            })
        }
    }
}
