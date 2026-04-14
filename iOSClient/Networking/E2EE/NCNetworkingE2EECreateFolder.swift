// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import CFNetwork
import Foundation
import LucidBanner

class NCNetworkingE2EECreateFolder: NSObject {
    let networkingE2EE = NCNetworkingE2EE()
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let database = NCManageDatabase.shared
    let global = NCGlobal.shared

    @MainActor
    func createFolder(fileName: String, serverUrl: String, sceneIdentifier: String?, session: NCSession.Session) async -> NKError {
        var banner: LucidBanner?
        var token: Int?
        var error = NKError()

        defer {
            if let banner, let token {
                if error == .success {
                    completeHudIndeterminateBannerSuccess(token: token, banner: banner)
                } else {
                    banner.dismiss()
                }
            }
        }

        let capabilities = await NKCapabilities.shared.getCapabilities(for: session.account)
        var fileNameFolder = FileAutoRenamer.rename(fileName, isFolderPath: true, capabilities: capabilities)

        let fileNameIdentifier = networkingE2EE.generateRandomIdentifier()
        let serverUrlFileName = utilityFileSystem.createServerUrl(serverUrl: serverUrl, fileName: fileNameIdentifier)
        fileNameFolder = utilityFileSystem.createFileName(fileNameFolder, serverUrl: serverUrl, account: session.account)
        if fileNameFolder.isEmpty {
            error = NKError(errorCode: global.errorUnexpectedResponseFromDB,
                            errorDescription: NSLocalizedString("_e2ee_no_dir_", comment: ""))
            return error
        }

        // TEST UPLOAD IN PROGRESS
        //
        if await networkingE2EE.isInUpload(account: session.account, serverUrl: serverUrl) {
            error = NKError(errorCode: global.errorE2EEUploadInProgress,
                            errorDescription: NSLocalizedString("_e2e_in_upload_", comment: ""))
            return error
        }

        // BANNER
        //
#if !EXTENSION
        if let windowScene = SceneManager.shared.getWindow(sceneIdentifier: sceneIdentifier)?.windowScene {
            (banner, token) = showHudIndeterminateBanner(windowScene: windowScene, title: "_e2ee_create_folder_")
        }
#endif

        // LOCK
        //
        let resultsLock = await networkingE2EE.lock(account: session.account, serverUrl: serverUrl)
        guard let e2eToken = resultsLock.e2eToken,
              let fileId = resultsLock.fileId,
              resultsLock.error == .success else {
            error = NKError(errorCode: global.errorE2EELock,
                            errorDescription: NSLocalizedString("_e2ee_no_lock_", comment: ""))
            return error
        }

        // UPDATE METADATA
        //
        error = await updateMetadata(serverUrl: serverUrl,
                                     e2eToken: e2eToken,
                                     fileId: fileId,
                                     fileNameIdentifier: fileNameIdentifier,
                                     fileNameFolder: fileNameFolder,
                                     session: session)
        guard error == .success else {
            await networkingE2EE.unlock(account: session.account, serverUrl: serverUrl)
            return error
        }

        // CREATE FOLDER
        //
        let resultsCreateFolder = await NextcloudKit.shared.createFolderAsync(serverUrlFileName: serverUrlFileName, account: session.account, options: NKRequestOptions(customHeader: ["e2e-token": e2eToken])) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: session.account,
                                                                                            path: serverUrlFileName,
                                                                                            name: "createFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }
        guard resultsCreateFolder.error == .success, let ocId = resultsCreateFolder.ocId, let fileId = utility.ocIdToFileId(ocId: ocId) else {
            await networkingE2EE.unlock(account: session.account, serverUrl: serverUrl)
            error = resultsCreateFolder.error
            return error
        }

        // SET FOLDER AS E2EE
        //
        let resultsMarkE2EEFolder = await NextcloudKit.shared.markE2EEFolderAsync(fileId: fileId, delete: false, account: session.account, options: NCNetworkingE2EE().getOptions(account: session.account, capabilities: capabilities)) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: session.account,
                                                                                            path: fileId,
                                                                                            name: "markE2EEFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }
        guard resultsMarkE2EEFolder.error == .success  else {
            await networkingE2EE.unlock(account: session.account, serverUrl: serverUrl)
            error = resultsMarkE2EEFolder.error
            return error
        }

        // UNLOCK
        //
        await networkingE2EE.unlock(account: session.account, serverUrl: serverUrl)

        // WRITE DB (DIRECTORY - METADATA)
        //
        let resultsReadFileOrFolder = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrlFileName, depth: "0", account: session.account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                    account: session.account,
                    path: serverUrlFileName,
                    name: "readFileOrFolder")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }
        guard resultsReadFileOrFolder.error == .success, let file = resultsReadFileOrFolder.files?.first else {
            await networkingE2EE.unlock(account: session.account, serverUrl: serverUrl)
            error = resultsReadFileOrFolder.error
            return error
        }
        let metadata = await NCManageDatabaseCreateMetadata().convertFileToMetadataAsync(file)

        await self.database.createDirectory(metadata: metadata)

        // SEND METADATA FOR THE NEW FOLDER
        await NCNetworkingE2EE().uploadMetadata(serverUrl: serverUrlFileName, account: session.account)

        await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
            delegate.transferChange(status: self.global.networkingStatusCreateFolder,
                                    account: metadata.account,
                                    fileName: metadata.fileName,
                                    serverUrl: metadata.serverUrl,
                                    selector: metadata.sessionSelector,
                                    ocId: metadata.ocId,
                                    destination: nil,
                                    error: .success)
        }

        return error
    }

    func updateMetadata(serverUrl: String,
                        e2eToken: String,
                        fileId: String,
                        fileNameIdentifier: String,
                        fileNameFolder: String,
                        session: NCSession.Session) async -> NKError {
        var key: NSString?
        var initializationVector: NSString?
        var method = "POST"

        guard let directory = await self.database.getTableDirectoryAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl)) else {
            return NKError(errorCode: global.errorUnexpectedResponseFromDB,
                           errorDescription: NSLocalizedString("_e2ee_no_dir_", comment: ""))
        }

        // DOWNLOAD METADATA
        //
        let errorDownloadMetadata = await networkingE2EE.downloadMetadata(serverUrl: serverUrl, fileId: fileId, e2eToken: e2eToken, session: session)
        if errorDownloadMetadata == .success {
            method = "PUT"
        } else if errorDownloadMetadata.errorCode != global.errorResourceNotFound {
            return errorDownloadMetadata
        }

        NCEndToEndEncryption.shared().encodedkey(&key, initializationVector: &initializationVector)
        guard let key = key as? String, let initializationVector = initializationVector as? String else {
            return NKError(errorCode: global.errorE2EEEncodedKey,
                           errorDescription: NSLocalizedString("_e2ee_no_generate_key_", comment: ""))
        }

        let object = tableE2eEncryption.init(account: session.account, ocIdServerUrl: directory.ocId, fileNameIdentifier: fileNameIdentifier)
        object.blob = "folders"
        if let results = await self.database.getE2eEncryptionAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl)) {
            object.metadataKey = results.metadataKey
            object.metadataKeyIndex = results.metadataKeyIndex
        } else {
            guard let key = NCEndToEndEncryption.shared().generateKey() as NSData? else {
                return NKError(errorCode: global.errorE2EEGenerateKey,
                               errorDescription: NSLocalizedString("_e2ee_no_generate_key_", comment: ""))
            }
            object.metadataKey = key.base64EncodedString()
            object.metadataKeyIndex = 0
        }
        object.authenticationTag = ""
        object.fileName = fileNameFolder
        object.key = key
        object.initializationVector = initializationVector
        object.mimeType = "httpd/unix-directory"
        object.serverUrl = serverUrl
        await self.database.addE2eEncryptionAsync(object)

        // UPLOAD METADATA
        //
        let uploadMetadataError = await networkingE2EE.uploadMetadata(serverUrl: serverUrl,
                                                                      ocIdServerUrl: directory.ocId,
                                                                      fileId: fileId,
                                                                      e2eToken: e2eToken,
                                                                      method: method,
                                                                      session: session)

        return uploadMetadataError
    }
}
