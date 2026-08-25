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
            return (nil, nil, 0, NKError(errorCode: NCGlobal.shared.errorUnexpectedResponseFromDB,
                                         errorDescription: NSLocalizedString("_e2ee_no_session_", comment: "")))
        }
        let capabilities = await NKCapabilities.shared.getCapabilities(for: session.account)

        if capabilities.e2EEApiVersion.hasPrefix("1.") {
            return await encodeMetadataV1(account: session.account, serverUrl: serverUrl, ocIdServerUrl: directory.ocId)
        } else if capabilities.e2EEApiVersion.hasPrefix("2.") {
            return await encodeMetadataV2(serverUrl: serverUrl, ocIdServerUrl: directory.ocId, addUserId: addUserId, addCertificate: addCertificate, removeUserId: removeUserId, session: session)
        } else {
            return (nil, nil, 0, NKError(errorCode: NCGlobal.shared.errorE2EEVersion, errorDescription: "Server E2EE version " + capabilities.e2EEApiVersion + ", not compatible"))
        }
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Decode JSON Metadata Bridge
    // --------------------------------------------------------------------------------------------

    func decodeMetadata(
        _ metadata: String,
        signature: String?,
        serverUrl: String,
        session: NCSession.Session
    ) async -> (error: NKError, access: NCEndToEndKeySetAccess) {
        guard let data = metadata.data(using: .utf8), let directory = self.database.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", session.account, serverUrl)) else {
            return (
                NKError(errorCode: NCGlobal.shared.errorE2EEJSon, errorDescription: "Unable to decode the metadata file"),
                .unavailable
            )
        }

        let isMetadataV1 = (try? JSONDecoder().decode(E2eeV1.self, from: data)) != nil
        let isMetadataV12 = (try? JSONDecoder().decode(E2eeV12.self, from: data)) != nil
        let metadataV2 = try? JSONDecoder().decode(E2eeV2.self, from: data)
        let isMetadataV2 = metadataV2 != nil

        guard isMetadataV1 || isMetadataV12 || isMetadataV2 else {
            return (
                NKError(
                    errorCode: NCGlobal.shared.errorE2EEVersion,
                    errorDescription: "Unable to decode the metadata file"
                ),
                .unavailable
            )
        }

        let access: NCEndToEndKeySetAccess
        do {
            access = try await resolveKeySetAccess(metadata, serverUrl: serverUrl, session: session)
        } catch {
            nkLog(
                tag: NCGlobal.shared.logTagE2EE,
                message: "Unable to resolve E2EE key-set access."
            )
            return (
                NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: error.localizedDescription),
                .unavailable
            )
        }

        nkLog(
            tag: NCGlobal.shared.logTagE2EE,
            message: "Resolved E2EE key-set access: \(access.diagnosticDescription)."
        )

        guard let keySet = access.keySet else {
            return (
                NKError(
                    errorCode: NCGlobal.shared.errorE2EENoUserFound,
                    errorDescription: NSLocalizedString("_e2ee_no_metadataKey_found_", comment: "")
                ),
                .unavailable
            )
        }

        let error: NKError
        if isMetadataV1 {
            error = await decodeMetadataV1(
                metadata,
                serverUrl: serverUrl,
                ocIdServerUrl: directory.ocId,
                session: session,
                keySet: keySet
            )
        } else if isMetadataV12 {
            error = await decodeMetadataV12(
                metadata,
                serverUrl: serverUrl,
                ocIdServerUrl: directory.ocId,
                session: session,
                keySet: keySet
            )
        } else {
            error = await decodeMetadataV2(
                metadata,
                signature: signature,
                serverUrl: serverUrl,
                ocIdServerUrl: directory.ocId,
                session: session,
                keySet: keySet
            )
        }

        return (error, access)
    }

    func resolveKeySetAccess(
        _ metadata: String,
        serverUrl: String,
        session: NCSession.Session
    ) async throws -> NCEndToEndKeySetAccess {
        var childRootEncryptedMetadataKey: String?
        if let data = metadata.data(using: .utf8),
           let metadataV2 = try? JSONDecoder().decode(E2eeV2.self, from: data),
           metadataV2.users?.isEmpty != false,
           let directoryTop = await utilityFileSystem.getMetadataE2EETopAsync(
               serverUrl: serverUrl,
               session: session
           ),
           serverUrl != directoryTop.serverUrlFileName {
            childRootEncryptedMetadataKey = try await storedRootEncryptedMetadataKey(
                serverUrl: serverUrl,
                session: session
            )
        }

        return try NCEndToEndKeySetResolver().resolve(
            metadata: metadata,
            account: session.account,
            userId: session.userId,
            rootEncryptedMetadataKey: childRootEncryptedMetadataKey
        )
    }

    func resolveStoredRootKeySetAccess(
        serverUrl: String,
        session: NCSession.Session
    ) async throws -> NCEndToEndKeySetAccess {
        guard let encryptedMetadataKey = try await storedRootEncryptedMetadataKey(
            serverUrl: serverUrl,
            session: session
        ) else {
            return .unavailable
        }

        return try NCEndToEndKeySetResolver().resolve(
            encryptedMetadataKey: encryptedMetadataKey,
            account: session.account
        )
    }

    private func storedRootEncryptedMetadataKey(
        serverUrl: String,
        session: NCSession.Session
    ) async throws -> String? {
        guard let directoryTop = await utilityFileSystem.getMetadataE2EETopAsync(
            serverUrl: serverUrl,
            session: session
        ),
        let tableUser = await database.getE2EUserAsync(
            account: session.account,
            directoryTopOcId: directoryTop.ocId,
            userId: session.userId
        ) else {
            return nil
        }

        return tableUser.encryptedMetadataKey
    }
}
