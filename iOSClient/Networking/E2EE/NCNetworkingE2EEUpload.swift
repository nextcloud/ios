// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import CFNetwork
import Alamofire
import Foundation

class NCNetworkingE2EEUpload: NSObject {
    let networkingE2EE = NCNetworkingE2EE()
    let utilityFileSystem = NCUtilityFileSystem()
    let global = NCGlobal.shared
    let utility = NCUtility()
    let database = NCManageDatabase.shared
    var numChunks: Int = 0

    @discardableResult
    @MainActor
    func upload(metadata: tableMetadata, session: NCSession.Session? = nil, controller: UIViewController? = nil) async -> NKError {
        var finalError: NKError = .success
        var session = session
        let hud = NCHud(controller?.view)
        let ocId = metadata.ocIdTransfer

        if session == nil {
            session = NCSession.shared.getSession(account: metadata.account)
        }
        guard let session,
              !session.account.isEmpty else {
            return NKError(errorCode: NCGlobal.shared.errorNCSessionNotFound, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
        }

        // HUD ENCRYPTION
        //
        hud.indeterminateProgress(text: NSLocalizedString("_wait_file_encryption_", comment: ""))

        defer {
            if finalError != .success {
                Task {
                    await self.database.deleteMetadataOcIdAsync(ocId)
                }
            }
            hud.dismiss()
        }

        if let result = await self.database.getMetadataAsync(predicate: NSPredicate(format: "serverUrl == %@ AND fileNameView == %@ AND ocId != %@", metadata.serverUrl, metadata.fileNameView, metadata.ocId)) {
            metadata.fileName = result.fileName
        } else {
            metadata.fileName = networkingE2EE.generateRandomIdentifier()
        }
        metadata.session = NCNetworking.shared.sessionUpload
        metadata.status = global.metadataStatusUploading
        metadata.sessionError = ""
        metadata.serverUrlFileName = utilityFileSystem.createServerUrl(serverUrl: metadata.serverUrl, fileName: metadata.fileName)

        guard let metadata = await self.database.addAndReturnMetadataAsync(metadata) else {
            return .invalidData
        }

        guard let directory = await self.database.getTableDirectoryAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) else {
            finalError = NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
            return finalError
        }

        func sendE2ee(e2eToken: String, fileId: String) async -> NKError {
            var key: NSString?, initializationVector: NSString?, authenticationTag: NSString?
            var method = "POST"

            // ENCRYPT FILE
            //
            if NCEndToEndEncryption.shared().encryptFile(metadata.fileNameView, fileNameIdentifier: metadata.fileName, directory: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase), key: &key, initializationVector: &initializationVector, authenticationTag: &authenticationTag) == false {
                finalError = NKError(errorCode: NCGlobal.shared.errorE2EEEncryptFile, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
                return finalError
            }
            guard let key = key as? String, let initializationVector = initializationVector as? String else {
                finalError = NKError(errorCode: NCGlobal.shared.errorE2EEEncodedKey, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
                return finalError
            }

            // DOWNLOAD METADATA
            //
            let errorDownloadMetadata = await networkingE2EE.downloadMetadata(serverUrl: metadata.serverUrl, fileId: fileId, e2eToken: e2eToken, session: session)
            if errorDownloadMetadata == .success {
                method = "PUT"
            } else if errorDownloadMetadata.errorCode != NCGlobal.shared.errorResourceNotFound {
                finalError = errorDownloadMetadata
                return finalError
            }

            // CREATE E2E METADATA
            //
            await self.database.deleteE2eEncryptionAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, metadata.fileNameView))
            let object = tableE2eEncryption.init(account: metadata.account, ocIdServerUrl: directory.ocId, fileNameIdentifier: metadata.fileName)
            if let results = await self.database.getE2eEncryptionAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
                object.metadataKey = results.metadataKey
                object.metadataKeyIndex = results.metadataKeyIndex
            } else {
                guard let key = NCEndToEndEncryption.shared().generateKey() as NSData? else {
                    finalError = NKError(errorCode: NCGlobal.shared.errorE2EEGenerateKey, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
                    return finalError
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

            await self.database.addE2eEncryptionAsync(object)

            // UPLOAD METADATA
            //
            let uploadMetadataError = await networkingE2EE.uploadMetadata(serverUrl: metadata.serverUrl,
                                                                          ocIdServerUrl: directory.ocId,
                                                                          fileId: fileId,
                                                                          e2eToken: e2eToken,
                                                                          method: method,
                                                                          session: session)

            finalError = uploadMetadataError
            return finalError
        }

        // LOCK
        //
        let resultsLock = await networkingE2EE.lock(account: metadata.account, serverUrl: metadata.serverUrl)
        guard let e2eToken = resultsLock.e2eToken,
                let fileId = resultsLock.fileId,
                resultsLock.error == .success
        else {
            await self.database.deleteMetadataAsync(predicate: NSPredicate(format: "ocIdTransfer == %@", metadata.ocIdTransfer))
            finalError = NKError(errorCode: NCGlobal.shared.errorE2EELock, errorDescription: NSLocalizedString("_e2e_error_", comment: ""))
            return finalError
        }

        // SEND NEW METADATA
        //
        let sendE2eeError = await sendE2ee(e2eToken: e2eToken, fileId: fileId)
        guard sendE2eeError == .success else {
            hud.dismiss()
            await self.database.deleteMetadataAsync(predicate: NSPredicate(format: "ocIdTransfer == %@", metadata.ocIdTransfer))
            await networkingE2EE.unlock(account: metadata.account, serverUrl: metadata.serverUrl)
            finalError = sendE2eeError
            return finalError
        }

        // HUD CHUNK
        //
        hud.pieProgress(text: NSLocalizedString("_wait_file_preparation_", comment: ""),
                        tapToCancelDetailText: true) {
            NotificationCenter.default.postOnMainThread(name: NextcloudKit.shared.nkCommonInstance.notificationCenterChunkedFileStop.rawValue)
        }

        // UPLOAD
        //
        let resultsSendFile = await sendFile(metadata: metadata, e2eToken: e2eToken, hud: hud, controller: controller)
        if resultsSendFile.error != .success {
            NCContentPresenter().showError(error: resultsSendFile.error)
        }

        // UNLOCK
        //
        await networkingE2EE.unlock(account: metadata.account, serverUrl: metadata.serverUrl)

        if resultsSendFile.error == .success, let ocId = resultsSendFile.ocId {
            let metadata = metadata.detachedCopy()

            await self.database.deleteMetadataOcIdAsync(metadata.ocId)
            await utilityFileSystem.moveFileAsync(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase),
                                                  toPath: utilityFileSystem.getDirectoryProviderStorageOcId(ocId, userId: metadata.userId, urlBase: metadata.urlBase))

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

            await self.database.addMetadataAsync(metadata)
            await self.database.addLocalFileAsync(metadata: metadata)
            utility.createImageFileFrom(metadata: metadata)

            await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                delegate.transferChange(status: global.networkingStatusUploaded,
                                        metadata: metadata,
                                        error: .success)
            }
        }

        finalError = resultsSendFile.error
        return finalError
    }

    // BRIDGE for chunk
    //
    private func sendFile(metadata: tableMetadata, e2eToken: String, hud: NCHud, controller: UIViewController?) async -> (ocId: String?, etag: String?, date: Date?, error: NKError) {

        if metadata.chunk > 0 {
            var counterUpload: Int = 0
            let results = await NCNetworking.shared.uploadChunkFile(metadata: metadata, withUploadComplete: false) { num in
                self.numChunks = num
            } counterChunk: { counter in
                hud.progress(num: Float(counter), total: Float(self.numChunks))
            } startFilesChunk: { _ in
                hud.setText(NSLocalizedString("_keep_active_for_upload_", comment: ""))
            } requestHandler: { _ in
                hud.progress(num: Float(counterUpload), total: Float(self.numChunks))
                counterUpload += 1
            } assembling: {
                hud.setText(NSLocalizedString("_wait_", comment: ""))
            }

            return (results.file?.ocId, results.file?.etag, results.file?.date, results.error)

        } else {
            let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId,
                                                                                      fileName: metadata.fileName,
                                                                                      userId: metadata.userId,
                                                                                      urlBase: metadata.urlBase)

            let results = await NCNetworking.shared.uploadFile(fileNameLocalPath: fileNameLocalPath,
                                                               serverUrlFileName: metadata.serverUrlFileName,
                                                               creationDate: metadata.creationDate as Date,
                                                               dateModificationFile: metadata.date as Date,
                                                               account: metadata.account,
                                                               metadata: metadata,
                                                               withUploadComplete: false,
                                                               customHeaders: ["e2e-token": e2eToken]) { _ in
                hud.setText(NSLocalizedString("_keep_active_for_upload_", comment: ""))
            } progressHandler: { _, _, fractionCompleted in
                hud.progress(fractionCompleted)
            }

            return (results.ocId, results.etag, results.date, results.error)
        }
    }
}
