//
//  NCNetworkingE2EEDelete.swift
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

import Foundation
import UIKit
import NextcloudKit

class NCNetworkingE2EEDelete: NSObject {
    let database = NCManageDatabase.shared
    let networkingE2EE = NCNetworkingE2EE()

    func delete(metadata: tableMetadata) async -> NKError {
        let session = NCSession.shared.getSession(account: metadata.account)
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

        // DELETE FILE
        //
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let options = NKRequestOptions(customHeader: ["e2e-token": e2eToken])
        let result = await NextcloudKit.shared.deleteFileOrFolder(serverUrlFileName: serverUrlFileName, account: metadata.account, options: options)
        if result.error == .success || result.error.errorCode == NCGlobal.shared.errorResourceNotFound {
            do {
                try FileManager.default.removeItem(atPath: NCUtilityFileSystem().getDirectoryProviderStorageOcId(metadata.ocId))
                database.deleteVideo(metadata: metadata)
                database.deleteMetadataOcId(metadata.ocId)
                database.deleteLocalFileOcId(metadata.ocId)
                // LIVE PHOTO SERVER
                if let metadataLive = self.database.getMetadataLivePhoto(metadata: metadata), metadataLive.isFlaggedAsLivePhotoByServer {
                    do {
                        try FileManager.default.removeItem(atPath: NCUtilityFileSystem().getDirectoryProviderStorageOcId(metadataLive.ocId))
                    } catch { }
                    self.database.deleteVideo(metadata: metadataLive)
                    self.database.deleteMetadataOcId(metadataLive.ocId)
                    self.database.deleteLocalFileOcId(metadataLive.ocId)
                }
                if metadata.directory {
                    self.database.deleteDirectoryAndSubDirectory(serverUrl: NCUtilityFileSystem().stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName), account: metadata.account)
                }
            } catch { }
        } else {
            await networkingE2EE.unlock(account: metadata.account, serverUrl: metadata.serverUrl)
            return result.error
        }

        // DOWNLOAD METADATA
        //
        let errorDownloadMetadata = await networkingE2EE.downloadMetadata(serverUrl: metadata.serverUrl, fileId: fileId, e2eToken: e2eToken, session: session)
        guard errorDownloadMetadata == .success else {
            await networkingE2EE.unlock(account: metadata.account, serverUrl: metadata.serverUrl)
            return errorDownloadMetadata
        }

        // UPDATE DB
        //
        self.database.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@",
                                                                 metadata.account,
                                                                 metadata.serverUrl,
                                                                 metadata.fileName))

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

        // UNLOCK
        //
        await networkingE2EE.unlock(account: metadata.account, serverUrl: metadata.serverUrl)

        return NKError()
    }
}
