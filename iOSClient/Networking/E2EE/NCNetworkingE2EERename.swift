// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit
import UIKit
import Foundation
import LucidBanner

class NCNetworkingE2EERename: NSObject {
    let database = NCManageDatabase.shared
    let networkingE2EE = NCNetworkingE2EE()
    let utilityFileSystem = NCUtilityFileSystem()

    @MainActor
    func rename(metadata: tableMetadata, fileNameNew: String, windowScene: UIWindowScene?) async -> NKError {
        let session = NCSession.shared.getSession(account: metadata.account)
        var error = NKError()
        var banner: LucidBanner?
        var token: Int?

        defer {
            if let banner, let token {
                if error == .success {
                    completeHudIndeterminateBannerSuccess(token: token, banner: banner)
                } else {
                    banner.dismiss()
                }
            }
        }

        // verify if exists the new fileName
        if await self.database.getE2eEncryptionAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, fileNameNew)) != nil {
            error = NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: "_file_already_exists_")
            return error
        }
        guard let directory = await self.database.getTableDirectoryAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) else {
            error = NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB,
                           errorDescription: NSLocalizedString("_e2ee_no_dir_", comment: ""))
            return error
        }

        // TEST UPLOAD IN PROGRESS
        //
        if await networkingE2EE.isInUpload(account: metadata.account, serverUrl: metadata.serverUrl) {
            error = NKError(errorCode: NCGlobal.shared.errorE2EEUploadInProgress, errorDescription: NSLocalizedString("_e2e_in_upload_", comment: ""))
            return error
        }

        // BANNER
        //
#if !EXTENSION
        if let windowScene {
            (banner, token) = showHudIndeterminateBanner(windowScene: windowScene, title: "_e2ee_rename_file_")
        }
#endif

        // LOCK
        //
        let resultsLock = await networkingE2EE.lock(account: metadata.account, serverUrl: metadata.serverUrl)
        guard resultsLock.error == .success, let e2eToken = resultsLock.e2eToken, let fileId = resultsLock.fileId else {
            error = resultsLock.error
            return error
        }

        // DOWNLOAD METADATA
        //
        error = await networkingE2EE.downloadMetadata(serverUrl: metadata.serverUrl, fileId: fileId, e2eToken: e2eToken, session: session)
        guard error == .success else {
            await networkingE2EE.unlock(account: metadata.account, serverUrl: metadata.serverUrl)
            return error
        }

        // DB RENAME
        //
        let newFileNamePath = utilityFileSystem.getRelativeFilePath(fileNameNew, serverUrl: metadata.serverUrl, session: session)
        await self.database.renameFileE2eEncryptionAsync(account: metadata.account, serverUrl: metadata.serverUrl, fileNameIdentifier: metadata.fileName, newFileName: fileNameNew, newFileNamePath: newFileNamePath)

        // UPLOAD METADATA
        //
        error = await networkingE2EE.uploadMetadata(serverUrl: metadata.serverUrl,
                                                    ocIdServerUrl: directory.ocId,
                                                    fileId: fileId,
                                                    e2eToken: e2eToken,
                                                    method: "PUT",
                                                    session: session)
        guard error == .success else {
            await networkingE2EE.unlock(account: metadata.account, serverUrl: metadata.serverUrl)
            return error
        }

        // UPDATE DB
        //
        await self.database.setMetadataFileNameViewAsync(serverUrl: metadata.serverUrl, fileName: metadata.fileName, newFileNameView: fileNameNew, account: metadata.account)

        // MOVE FILE SYSTEM
        //
        let atPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase) + "/" + metadata.fileNameView
        let toPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, userId: metadata.userId, urlBase: metadata.urlBase) + "/" + fileNameNew
        do {
            try FileManager.default.moveItem(atPath: atPath, toPath: toPath)
        } catch { }

        // UNLOCK
        //
        await networkingE2EE.unlock(account: metadata.account, serverUrl: metadata.serverUrl)

        await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
            delegate.transferChange(status: NCGlobal.shared.networkingStatusRename,
                                    account: metadata.account,
                                    fileName: metadata.fileName,
                                    serverUrl: metadata.serverUrl,
                                    selector: metadata.sessionSelector,
                                    ocId: metadata.ocId,
                                    destination: nil,
                                    error: error)
        }

        return error
    }
}
