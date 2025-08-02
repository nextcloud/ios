// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit

class NCNetworkingE2EEMarkFolder: NSObject {
    let database = NCManageDatabase.shared

    func markFolderE2ee(account: String, serverUrlFileName: String, userId: String) async -> NKError {
        let resultsReadFileOrFolder = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrlFileName, depth: "0", account: account)
        guard resultsReadFileOrFolder.error == .success,
              var file = resultsReadFileOrFolder.files?.first else {
            return resultsReadFileOrFolder.error
        }
        let capabilities = await NKCapabilities.shared.getCapabilities(for: account)
        let resultsMarkE2EEFolder = await NextcloudKit.shared.markE2EEFolderAsync(fileId: file.fileId, delete: false, account: account, options: NCNetworkingE2EE().getOptions(account: account, capabilities: capabilities))
        guard resultsMarkE2EEFolder.error == .success else {
            return resultsMarkE2EEFolder.error
        }

        file.e2eEncrypted = true

        let metadataFromFiles = await self.database.convertFileToMetadataAsync(file)
        guard let metadata = await self.database.addAndReturnMetadataAsync(metadataFromFiles) else {
            return .invalidData
        }

        await self.database.addDirectoryAsync(serverUrl: serverUrlFileName,
                                              ocId: metadata.ocId,
                                              fileId: metadata.fileId,
                                              permissions: metadata.permissions,
                                              favorite: metadata.favorite,
                                              account: metadata.account)
        await self.database.deleteE2eEncryptionAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, serverUrlFileName))
        if capabilities.e2EEApiVersion == NCGlobal.shared.e2eeVersionV20 {
            await self.database.updateCounterE2eMetadataAsync(account: account, ocIdServerUrl: metadata.ocId, counter: 0)
        }

        // upload e2ee metadata
        let errorUploadMetadata = await NCNetworkingE2EE().uploadMetadata(serverUrl: serverUrlFileName, account: account)
        guard errorUploadMetadata == .success else {
            return errorUploadMetadata
        }

        await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
            delegate.transferChange(status: NCGlobal.shared.networkingStatusCreateFolder,
                                    metadata: metadata.detachedCopy(),
                                    error: .success)
        }

        return NKError()
    }
}
