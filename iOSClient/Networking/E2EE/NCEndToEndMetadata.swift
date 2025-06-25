// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2017 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later


import UIKit
import NextcloudKit

class NCEndToEndMetadata: NSObject {
    let utilityFileSystem = NCUtilityFileSystem()
    let database = NCManageDatabase.shared

    // --------------------------------------------------------------------------------------------
    // MARK: Encode JSON Metadata Bridge
    // --------------------------------------------------------------------------------------------

    func encodeMetadata(serverUrl: String, addUserId: String? = nil, addCertificate: String? = nil, removeUserId: String? = nil, session: NCSession.Session) async -> (metadata: String?, signature: String?, counter: Int, error: NKError) {

        guard let directory = self.database.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl)) else {
            return (nil, nil, 0, NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB, errorDescription: "_e2e_error_"))
        }
        let capabilities = NKCapabilities.shared.getCapabilitiesBlocking(for: session.account)

        if capabilities.e2EEApiVersion == NCGlobal.shared.e2eeVersionV12 && NCGlobal.shared.e2eeVersions.contains(NCGlobal.shared.e2eeVersionV12) {
            return await encodeMetadataV12(account: session.account, serverUrl: serverUrl, ocIdServerUrl: directory.ocId)
        } else if capabilities.e2EEApiVersion == NCGlobal.shared.e2eeVersionV20 && NCGlobal.shared.e2eeVersions.contains(NCGlobal.shared.e2eeVersionV20) {
            return await encodeMetadataV20(serverUrl: serverUrl, ocIdServerUrl: directory.ocId, addUserId: addUserId, addCertificate: addCertificate, removeUserId: removeUserId, session: session)
        } else {
            return (nil, nil, 0, NKError(errorCode: NCGlobal.shared.errorE2EEVersion, errorDescription: "Server E2EE version " + capabilities.e2EEApiVersion + ", not compatible"))
        }
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Decode JSON Metadata Bridge
    // --------------------------------------------------------------------------------------------

    func decodeMetadata(_ metadata: String, signature: String?, serverUrl: String, session: NCSession.Session) async -> NKError {
        guard let data = metadata.data(using: .utf8), let directory = self.database.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl)) else {
            return (NKError(errorCode: NCGlobal.shared.errorE2EEJSon, errorDescription: "_e2e_error_"))
        }

        data.printJson()

        if (try? JSONDecoder().decode(E2eeV1.self, from: data)) != nil && NCGlobal.shared.e2eeVersions.contains(NCGlobal.shared.e2eeVersionV11) {
            return await decodeMetadataV1(metadata, serverUrl: serverUrl, ocIdServerUrl: directory.ocId, session: session)
        } else if (try? JSONDecoder().decode(E2eeV12.self, from: data)) != nil && NCGlobal.shared.e2eeVersions.contains(NCGlobal.shared.e2eeVersionV12) {
            return await decodeMetadataV12(metadata, serverUrl: serverUrl, ocIdServerUrl: directory.ocId, session: session)
        } else if (try? JSONDecoder().decode(E2eeV20.self, from: data)) != nil && NCGlobal.shared.e2eeVersions.contains(NCGlobal.shared.e2eeVersionV20) {
            return await decodeMetadataV20(metadata, signature: signature, serverUrl: serverUrl, ocIdServerUrl: directory.ocId, session: session)
        } else {
            return NKError(errorCode: NCGlobal.shared.errorE2EEVersion, errorDescription: "Unable to decode the metadata file")
        }
    }
}
