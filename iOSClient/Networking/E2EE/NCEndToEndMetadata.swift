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
    let utilityFileSystem = NCUtilityFileSystem()
    let database = NCManageDatabase.shared

    // --------------------------------------------------------------------------------------------
    // MARK: Encode JSON Metadata Bridge
    // --------------------------------------------------------------------------------------------

    func encodeMetadata(serverUrl: String, addUserId: String? = nil, addCertificate: String? = nil, removeUserId: String? = nil, session: NCSession.Session) -> (metadata: String?, signature: String?, counter: Int, error: NKError) {

        guard let directory = self.database.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl)) else {
            return (nil, nil, 0, NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: "_e2e_error_"))
        }
        let capabilities = NCCapabilities.shared.getCapabilities(account: session.account)

        if capabilities.capabilityE2EEApiVersion == NCGlobal.shared.e2eeVersionV12 && NCGlobal.shared.e2eeVersions.contains(NCGlobal.shared.e2eeVersionV12) {
            return encodeMetadataV12(account: session.account, serverUrl: serverUrl, ocIdServerUrl: directory.ocId)
        } else if capabilities.capabilityE2EEApiVersion == NCGlobal.shared.e2eeVersionV20 && NCGlobal.shared.e2eeVersions.contains(NCGlobal.shared.e2eeVersionV20) {
            return encodeMetadataV20(serverUrl: serverUrl, ocIdServerUrl: directory.ocId, addUserId: addUserId, addCertificate: addCertificate, removeUserId: removeUserId, session: session)
        } else {
            return (nil, nil, 0, NKError(errorCode: NCGlobal.shared.errorE2EEVersion, errorDescription: "Server E2EE version " + capabilities.capabilityE2EEApiVersion + ", not compatible"))
        }
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Decode JSON Metadata Bridge
    // --------------------------------------------------------------------------------------------

    func decodeMetadata(_ metadata: String, signature: String?, serverUrl: String, session: NCSession.Session) -> NKError {
        guard let data = metadata.data(using: .utf8), let directory = self.database.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl)) else {
            return (NKError(errorCode: NCGlobal.shared.errorE2EEJSon, errorDescription: "_e2e_error_"))
        }

        data.printJson()

        if (try? JSONDecoder().decode(E2eeV1.self, from: data)) != nil && NCGlobal.shared.e2eeVersions.contains(NCGlobal.shared.e2eeVersionV11) {
            return decodeMetadataV1(metadata, serverUrl: serverUrl, ocIdServerUrl: directory.ocId, session: session)
        } else if (try? JSONDecoder().decode(E2eeV12.self, from: data)) != nil && NCGlobal.shared.e2eeVersions.contains(NCGlobal.shared.e2eeVersionV12) {
            return decodeMetadataV12(metadata, serverUrl: serverUrl, ocIdServerUrl: directory.ocId, session: session)
        } else if (try? JSONDecoder().decode(E2eeV20.self, from: data)) != nil && NCGlobal.shared.e2eeVersions.contains(NCGlobal.shared.e2eeVersionV20) {
            return decodeMetadataV20(metadata, signature: signature, serverUrl: serverUrl, ocIdServerUrl: directory.ocId, session: session)
        } else {
            return NKError(errorCode: NCGlobal.shared.errorE2EEVersion, errorDescription: "Unable to decode the metadata file")
        }
    }
}
