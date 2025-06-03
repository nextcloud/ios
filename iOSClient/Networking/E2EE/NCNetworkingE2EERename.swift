//
//  NCNetworkingE2EERename.swift
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

import NextcloudKit
import UIKit
import Foundation

class NCNetworkingE2EERename: NSObject {
    let database = NCManageDatabase.shared
    let networkingE2EE = NCNetworkingE2EE()
    let utilityFileSystem = NCUtilityFileSystem()

    func rename(metadata: tableMetadata, fileNameNew: String) async -> NKError {
        let session = NCSession.shared.getSession(account: metadata.account)
        // verify if exists the new fileName
        if self.database.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, fileNameNew)) != nil {
            return NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: "_file_already_exists_")
        }
        guard let directory = self.database.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) else {
            return NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: "_e2e_error_")
        }

        // TEST UPLOAD IN PROGRESS
        //
        if networkingE2EE.isInUpload(account: metadata.account, serverUrl: metadata.serverUrl) {
            return NKError(errorCode: NCGlobal.shared.errorE2EEUploadInProgress, errorDescription: NSLocalizedString("_e2e_in_upload_", comment: ""))
        }

        // LOCK
        //
        let resultsLock = await networkingE2EE.lock(account: metadata.account, serverUrl: metadata.serverUrl)
        guard resultsLock.error == .success, let e2eToken = resultsLock.e2eToken, let fileId = resultsLock.fileId else { return resultsLock.error }

        // DOWNLOAD METADATA
        //
        let errorDownloadMetadata = await networkingE2EE.downloadMetadata(serverUrl: metadata.serverUrl, fileId: fileId, e2eToken: e2eToken, session: session)
        guard errorDownloadMetadata == .success else {
            await networkingE2EE.unlock(account: metadata.account, serverUrl: metadata.serverUrl)
            return errorDownloadMetadata
        }

        // DB RENAME
        //
        let newFileNamePath = utilityFileSystem.getFileNamePath(fileNameNew, serverUrl: metadata.serverUrl, session: session)
        self.database.renameFileE2eEncryption(account: metadata.account, serverUrl: metadata.serverUrl, fileNameIdentifier: metadata.fileName, newFileName: fileNameNew, newFileNamePath: newFileNamePath)

        // UPLOAD METADATA
        //
        let uploadMetadataError = await networkingE2EE.uploadMetadata(serverUrl: metadata.serverUrl,
                                                                      ocIdServerUrl: directory.ocId,
                                                                      fileId: fileId,
                                                                      e2eToken: e2eToken,
                                                                      method: "PUT",
                                                                      session: session)
        guard uploadMetadataError == .success else {
            await networkingE2EE.unlock(account: metadata.account, serverUrl: metadata.serverUrl)
            return uploadMetadataError
        }

        // UPDATE DB
        //
        self.database.setMetadataFileNameView(serverUrl: metadata.serverUrl, fileName: metadata.fileName, newFileNameView: fileNameNew, account: metadata.account)

        // MOVE FILE SYSTEM
        //
        let atPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + metadata.fileNameView
        let toPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId) + "/" + fileNameNew
        do {
            try FileManager.default.moveItem(atPath: atPath, toPath: toPath)
        } catch { }

        // UNLOCK
        //
        await networkingE2EE.unlock(account: metadata.account, serverUrl: metadata.serverUrl)

        NCNetworking.shared.notifyAllDelegates { delegate in
            delegate.transferChange(status: NCGlobal.shared.networkingStatusRename,
                                    metadata: metadata,
                                    error: uploadMetadataError)
        }

        return NKError()
    }
}
