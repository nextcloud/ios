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
import NextcloudKit

class NCNetworkingE2EEMarkFolder: NSObject {
    func markFolderE2ee(account: String, fileName: String, serverUrl: String, userId: String) async -> NKError {
        let serverUrlFileName = serverUrl + "/" + fileName
        let resultsReadFileOrFolder = await NCNetworking.shared.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", account: account)
        guard resultsReadFileOrFolder.error == .success, let file = resultsReadFileOrFolder.files.first else { return resultsReadFileOrFolder.error }
        let resultsMarkE2EEFolder = await NCNetworking.shared.markE2EEFolder(fileId: file.fileId, delete: false, account: account, options: NCNetworkingE2EE().getOptions())
        guard resultsMarkE2EEFolder.error == .success else { return resultsMarkE2EEFolder.error }

        file.e2eEncrypted = true
        guard let metadata = NCManageDatabase.shared.addMetadata(NCManageDatabase.shared.convertFileToMetadata(file, isDirectoryE2EE: false)) else {
            return NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: "_e2e_error_")
        }
        NCManageDatabase.shared.addDirectory(e2eEncrypted: true, favorite: metadata.favorite, ocId: metadata.ocId, fileId: metadata.fileId, permissions: metadata.permissions, serverUrl: serverUrlFileName, account: metadata.account)
        NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, serverUrlFileName))
        if NCGlobal.shared.capabilityE2EEApiVersion == NCGlobal.shared.e2eeVersionV20 {
            NCManageDatabase.shared.updateCounterE2eMetadata(account: account, ocIdServerUrl: metadata.ocId, counter: 0)
        }

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterCreateFolder, userInfo: ["ocId": metadata.ocId, "serverUrl": serverUrl, "account": account, "withPush": true])

        return NKError()
    }
}
