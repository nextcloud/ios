//
//  NCNetworkingE2EE.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 05/05/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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
import OpenSSL
import NextcloudKit
import CFNetwork
import Alamofire

class NCNetworkingE2EE: NSObject {
    public static let shared: NCNetworkingE2EE = {
        let instance = NCNetworkingE2EE()
        return instance
    }()

    func isE2EEVersionWriteable(account: String) -> NKError? {

        let versionE2EE = NCManageDatabase.shared.getCapabilitiesServerString(account: account, elements: NCElementsJSON.shared.capabilitiesE2EEApiVersion) ?? ""

        if NCGlobal.shared.e2eeReadVersions.last == versionE2EE {
            return nil
        }
        
        return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_e2e_error_not_versionwriteable_")
    }

    func generateRandomIdentifier() -> String {

        var UUID = NSUUID().uuidString
        UUID = "E2EE" + UUID.replacingOccurrences(of: "-", with: "")
        return UUID
    }

    func lock(account: String, serverUrl: String) async -> (fileId: String?, e2eToken: String?, error: NKError) {

        var e2eToken: String?

        guard let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) else {
            return (nil, nil, NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_e2e_error_lock_"))
        }

        if let tableLock = NCManageDatabase.shared.getE2ETokenLock(account: account, serverUrl: serverUrl) {
            e2eToken = tableLock.e2eToken
        }

        let lockE2EEFolderResults = await NextcloudKit.shared.lockE2EEFolder(fileId: directory.fileId, e2eToken: e2eToken, method: "POST")
        if lockE2EEFolderResults.error == .success, let e2eToken = lockE2EEFolderResults.e2eToken {
            NCManageDatabase.shared.setE2ETokenLock(account: account, serverUrl: serverUrl, fileId: directory.fileId, e2eToken: e2eToken)
        }

        return (directory.fileId, lockE2EEFolderResults.e2eToken, lockE2EEFolderResults.error)
    }

    func unlock(account: String, serverUrl: String) async -> () {

        guard let tableLock = NCManageDatabase.shared.getE2ETokenLock(account: account, serverUrl: serverUrl) else {
            return
        }

        let lockE2EEFolderResults = await NextcloudKit.shared.lockE2EEFolder(fileId: tableLock.fileId, e2eToken: tableLock.e2eToken, method: "DELETE")
        if lockE2EEFolderResults.error == .success {
            NCManageDatabase.shared.deleteE2ETokenLock(account: account, serverUrl: serverUrl)
        }

        return
    }

    func unlockAll(account: String) {
        guard CCUtility.isEnd(toEndEnabled: account) else { return }

        Task {
            for result in NCManageDatabase.shared.getE2EAllTokenLock(account: account) {
                let lockE2EEFolderResults = await NextcloudKit.shared.lockE2EEFolder(fileId: result.fileId, e2eToken: result.e2eToken, method: "DELETE")
                if lockE2EEFolderResults.error == .success {
                    NCManageDatabase.shared.deleteE2ETokenLock(account: account, serverUrl: result.serverUrl)
                }
            }
        }
    }
}
