//
//  NCNetworkingE2EEMarkFolder.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 24/08/23.
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

class NCNetworkingE2EEMarkFolder: NSObject {
    let database = NCManageDatabase.shared

    func markFolderE2ee(account: String, serverUrlFileName: String, userId: String) async -> NKError {
        let resultsReadFileOrFolder = await NextcloudKit.shared.readFileOrFolderAsync(serverUrlFileName: serverUrlFileName, depth: "0", account: account)
        guard resultsReadFileOrFolder.error == .success,
              var file = resultsReadFileOrFolder.files?.first else {
            return resultsReadFileOrFolder.error
        }
        let resultsMarkE2EEFolder = await NextcloudKit.shared.markE2EEFolderAsync(fileId: file.fileId, delete: false, account: account, options: NCNetworkingE2EE().getOptions(account: account))
        guard resultsMarkE2EEFolder.error == .success else {
            return resultsMarkE2EEFolder.error
        }
        let capabilities = NKCapabilities.shared.getCapabilitiesBlocking(for: account)

        file.e2eEncrypted = true

        let metadata = await self.database.addAndReturnMetadataAsync(self.database.convertFileToMetadata(file, isDirectoryE2EE: false))

        await self.database.addDirectoryAsync(e2eEncrypted: true, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, permissions: metadata.permissions, serverUrl: serverUrlFileName, account: metadata.account)
        await self.database.deleteE2eEncryptionAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, serverUrlFileName))
        if capabilities.e2EEApiVersion == NCGlobal.shared.e2eeVersionV20 {
            await self.database.updateCounterE2eMetadataAsync(account: account, ocIdServerUrl: metadata.ocId, counter: 0)
        }

        // upload e2ee metadata
        let errorUploadMetadata = await NCNetworkingE2EE().uploadMetadata(serverUrl: serverUrlFileName, account: account)
        guard errorUploadMetadata == .success else {
            return errorUploadMetadata
        }

        NCNetworking.shared.notifyAllDelegates { delegate in
            delegate.transferChange(status: NCGlobal.shared.networkingStatusCreateFolder,
                                    metadata: tableMetadata(value: metadata),
                                    error: .success)
        }

        return NKError()
    }
}
