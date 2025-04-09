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
import JGProgressHUD

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
    var numChunks: Int = 0

    func upload(metadata: tableMetadata, uploadE2EEDelegate: uploadE2EEDelegate? = nil, hudView: UIView?, hud: JGProgressHUD?) async -> NKError {
        var metadata = metadata
        let ocIdTemp = metadata.ocId

        if let result = NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "serverUrl == %@ AND fileNameView == %@ AND ocId != %@", metadata.serverUrl, metadata.fileNameView, metadata.ocId)) {
            metadata.fileName = result.fileName
        } else {
            metadata.fileName = networkingE2EE.generateRandomIdentifier()
        }
        metadata.session = NextcloudKit.shared.nkCommonInstance.sessionIdentifierUpload
        metadata.sessionError = ""
        guard let result = NCManageDatabase.shared.addMetadata(metadata),
              let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) else {
            return NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
        }
        metadata = result

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
            let errorDownloadMetadata = await networkingE2EE.downloadMetadata(account: metadata.account, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId, fileId: fileId, e2eToken: e2eToken)
            if errorDownloadMetadata == .success {
                method = "PUT"
            } else if errorDownloadMetadata.errorCode != NCGlobal.shared.errorResourceNotFound {
                return errorDownloadMetadata
            }

            // CREATE E2E METADATA
            //
            NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, metadata.fileNameView))
            let object = tableE2eEncryption.init(account: metadata.account, ocIdServerUrl: directory.ocId, fileNameIdentifier: metadata.fileName)
            if let results = NCManageDatabase.shared.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
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
            NCManageDatabase.shared.addE2eEncryption(object)

            // UPLOAD METADATA
            //
            let uploadMetadataError = await networkingE2EE.uploadMetadata(account: metadata.account,
                                                                                   serverUrl: metadata.serverUrl,
                                                                                   ocIdServerUrl: directory.ocId,
                                                                                   fileId: fileId,
                                                                                   userId: metadata.userId,
                                                                                   e2eToken: e2eToken,
                                                                                   method: method)

            return uploadMetadataError
        }

        // LOCK
        //
        let resultsLock = await networkingE2EE.lock(account: metadata.account, serverUrl: metadata.serverUrl)
        guard let e2eToken = resultsLock.e2eToken, let fileId = resultsLock.fileId, resultsLock.error == .success else {
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp))
            NotificationCenter.default.post(
                name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile),
                object: nil,
                userInfo: ["ocId": metadata.ocId,
                           "serverUrl": metadata.serverUrl,
                           "account": metadata.account,
                           "fileName": metadata.fileName,
                           "ocIdTemp": ocIdTemp,
                           "error": NKError(errorCode: NCGlobal.shared.errorE2EELock, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))])
            return NKError(errorCode: NCGlobal.shared.errorE2EELock, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
        }

        // HUD ENCRYPTION
        //
        if let hudView {
            DispatchQueue.main.async {
                hud?.textLabel.text = NSLocalizedString("_wait_file_encryption_", comment: "")
                hud?.show(in: hudView)
            }
        }

        // SEND NEW METADATA
        //
        let sendE2eeError = await sendE2ee(e2eToken: e2eToken, fileId: fileId)
        guard sendE2eeError == .success else {
            DispatchQueue.main.async { hud?.dismiss() }
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp))
            NotificationCenter.default.post(
                name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile),
                object: nil,
                userInfo: ["ocId": metadata.ocId,
                           "serverUrl": metadata.serverUrl,
                           "account": metadata.account,
                           "fileName": metadata.fileName,
                           "ocIdTemp": ocIdTemp,
                           "error": sendE2eeError])
            await networkingE2EE.unlock(account: metadata.account, serverUrl: metadata.serverUrl)
            return sendE2eeError
        }

        // HUD CHUNK
        //
        if hudView != nil {
            DispatchQueue.main.async {
                if let hud {
                    hud.indicatorView = JGProgressHUDRingIndicatorView()
                    if let indicatorView = hud.indicatorView as? JGProgressHUDRingIndicatorView {
                        indicatorView.ringWidth = 1.5
                        indicatorView.ringColor = NCBrandColor.shared.brandElement
                    }
                    hud.tapOnHUDViewBlock = { _ in
                        NotificationCenter.default.postOnMainThread(name: "NextcloudKit.chunkedFile.stop")
                    }
                    hud.textLabel.text = NSLocalizedString("_wait_file_preparation_", comment: "")
                    hud.detailTextLabel.text = NSLocalizedString("_tap_to_cancel_", comment: "")
                    hud.detailTextLabel.textColor = NCBrandColor.shared.iconImageColor2
                }
            }
        }

        // UPLOAD
        //
        let resultsSendFile = await sendFile(metadata: metadata, e2eToken: e2eToken, hud: hud, uploadE2EEDelegate: uploadE2EEDelegate)

        // UNLOCK
        //
        await networkingE2EE.unlock(account: metadata.account, serverUrl: metadata.serverUrl)

        if let afError = resultsSendFile.afError, afError.isExplicitlyCancelledError {

            utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId))
            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            NotificationCenter.default.post(
                name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile),
                object: nil,
                userInfo: ["ocId": metadata.ocId,
                           "serverUrl": metadata.serverUrl,
                           "account": metadata.account,
                           "fileName": metadata.fileName,
                           "ocIdTemp": ocIdTemp,
                           "error": resultsSendFile.error])

        } else if resultsSendFile.error == .success, let ocId = resultsSendFile.ocId {

            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
            utilityFileSystem.moveFileInBackground(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId), toPath: utilityFileSystem.getDirectoryProviderStorageOcId(ocId))

            metadata.date = (resultsSendFile.date as? NSDate) ?? NSDate()
            metadata.etag = resultsSendFile.etag ?? ""
            metadata.ocId = ocId
            metadata.chunk = 0

            metadata.session = ""
            metadata.sessionError = ""
            metadata.status = NCGlobal.shared.metadataStatusNormal

            NCManageDatabase.shared.addMetadata(metadata)
            NCManageDatabase.shared.addLocalFile(metadata: metadata)
            utility.createImageFrom(fileNameView: metadata.fileNameView, ocId: metadata.ocId, etag: metadata.etag, classFile: metadata.classFile)
            NotificationCenter.default.post(
                name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile),
                object: nil,
                userInfo: ["ocId": metadata.ocId,
                           "serverUrl": metadata.serverUrl,
                           "account": metadata.account,
                           "fileName": metadata.fileName,
                           "ocIdTemp": ocIdTemp,
                           "error": resultsSendFile.error])

        } else {

            NCManageDatabase.shared.setMetadataSession(ocId: metadata.ocId,
                                                       sessionError: resultsSendFile.error.errorDescription,
                                                       status: NCGlobal.shared.metadataStatusUploadError,
                                                       errorCode: resultsSendFile.error.errorCode)
            NotificationCenter.default.post(
                name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile),
                object: nil,
                userInfo: ["ocId": metadata.ocId,
                           "serverUrl": metadata.serverUrl,
                           "account": metadata.account,
                           "fileName": metadata.fileName,
                           "ocIdTemp": ocIdTemp,
                           "error": resultsSendFile.error])
        }

        return (resultsSendFile.error)
    }

    // BRIDGE for chunk
    //
    private func sendFile(metadata: tableMetadata, e2eToken: String, hud: JGProgressHUD?, uploadE2EEDelegate: uploadE2EEDelegate? = nil) async -> (ocId: String?, etag: String?, date: Date?, afError: AFError?, error: NKError) {

        if metadata.chunk > 0 {

            return await withCheckedContinuation({ continuation in
                NCNetworking.shared.uploadChunkFile(metadata: metadata, withUploadComplete: false, customHeaders: ["e2e-token": e2eToken]) { num in
                    self.numChunks = num
                } counterChunk: { counter in
                    DispatchQueue.main.async { hud?.progress = Float(counter) / Float(self.numChunks) }
                } start: {
                    DispatchQueue.main.async { hud?.dismiss() }
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
                NCNetworking.shared.uploadFile(metadata: metadata, fileNameLocalPath: fileNameLocalPath, withUploadComplete: false, customHeaders: ["e2e-token": e2eToken]) {
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
