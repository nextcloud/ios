//
//  NCEndToEndMetadata.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 13/11/17.
//  Copyright © 2017 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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

class NCEndToEndMetadata: NSObject {

    // --------------------------------------------------------------------------------------------
    // MARK: Encode JSON Metadata Bridge
    // --------------------------------------------------------------------------------------------

    func encodeMetadata(account: String, serverUrl: String, userId: String, addUserId: String? = nil, addCertificate: String? = nil, removeUserId: String? = nil) -> (metadata: String?, signature: String?, error: NKError) {

        let e2EEApiVersion = NCGlobal.shared.capabilityE2EEApiVersion

        guard let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) else {
            return (nil, nil, NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: "_e2e_error_"))
        }

        if e2EEApiVersion == NCGlobal.shared.e2eeVersionV12 && NCGlobal.shared.e2eeVersions.contains(NCGlobal.shared.e2eeVersionV12) {
            return encodeMetadataV12(account: account, serverUrl: serverUrl, ocIdServerUrl: directory.ocId)
        } else if e2EEApiVersion == NCGlobal.shared.e2eeVersionV20 && NCGlobal.shared.e2eeVersions.contains(NCGlobal.shared.e2eeVersionV20) {
            return encodeMetadataV20(account: account, serverUrl: serverUrl, ocIdServerUrl: directory.ocId, userId: userId, addUserId: addUserId, addCertificate: addCertificate, removeUserId: removeUserId)
        } else {
            return (nil, nil, NKError(errorCode: NCGlobal.shared.errorE2EEVersion, errorDescription: "_e2e_error_"))
        }
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Decode JSON Metadata Bridge
    // --------------------------------------------------------------------------------------------

    func decodeMetadata(_ json: String, signature: String?, serverUrl: String, account: String, urlBase: String, userId: String, ownerId: String?) -> NKError {

        guard let data = json.data(using: .utf8), let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", account, serverUrl)) else {
            return (NKError(errorCode: NCGlobal.shared.errorE2EEJSon, errorDescription: "_e2e_error_"))
        }

        data.printJson()

        let decoder = JSONDecoder()

        if (try? decoder.decode(E2eeV1.self, from: data)) != nil && NCGlobal.shared.e2eeVersions.contains(NCGlobal.shared.e2eeVersionV11) {
            return decodeMetadataV1(json, serverUrl: serverUrl, account: account, ocIdServerUrl: directory.ocId, urlBase: urlBase, userId: userId)
        } else if (try? decoder.decode(E2eeV12.self, from: data)) != nil && NCGlobal.shared.e2eeVersions.contains(NCGlobal.shared.e2eeVersionV12) {
            return decodeMetadataV12(json, serverUrl: serverUrl, account: account, ocIdServerUrl: directory.ocId, urlBase: urlBase, userId: userId, ownerId: ownerId)
        } else if (try? decoder.decode(E2eeV20.self, from: data)) != nil && NCGlobal.shared.e2eeVersions.contains(NCGlobal.shared.e2eeVersionV20) {
            return decodeMetadataV20(json, signature: signature, serverUrl: serverUrl, account: account, ocIdServerUrl: directory.ocId, urlBase: urlBase, userId: userId, ownerId: ownerId)
        } else {
            return NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "Server E2EE version " + NCGlobal.shared.capabilityE2EEApiVersion + ", not compatible")
        }
    }
}
