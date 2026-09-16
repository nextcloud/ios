// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Selects the E2EE key set that can decrypt a metadata payload.
///
/// Selection only probes the asymmetric metadata key. It does not update the
/// database, counters, metadata, or files while trying candidate key sets.
struct NCEndToEndKeySetResolver {
    private let preferences: NCPreferences

    init(preferences: NCPreferences = NCPreferences()) {
        self.preferences = preferences
    }

    func resolve(
        metadata: String,
        account: String,
        userId: String,
        rootEncryptedMetadataKey: String? = nil
    ) throws -> NCEndToEndKeySetAccess {
        guard let data = metadata.data(using: .utf8) else {
            return .unavailable
        }

        let currentKeySet = currentKeySet(account: account)

        if let metadataV1 = try? JSONDecoder().decode(NCEndToEndMetadata.E2eeV1.self, from: data) {
            let encryptedMetadataKeys = Array(metadataV1.metadata.metadataKeys.values)
            return try resolve(
                currentKeySet: currentKeySet,
                account: account,
                canDecrypt: { keySet in
                    encryptedMetadataKeys.contains { canDecryptLegacyMetadataKey($0, with: keySet) }
                }
            )
        }

        if let metadataV12 = try? JSONDecoder().decode(NCEndToEndMetadata.E2eeV12.self, from: data) {
            return try resolve(
                currentKeySet: currentKeySet,
                account: account,
                canDecrypt: { keySet in
                    canDecryptLegacyMetadataKey(metadataV12.metadata.metadataKey, with: keySet)
                }
            )
        }

        if let metadataV2 = try? JSONDecoder().decode(NCEndToEndMetadata.E2eeV2.self, from: data) {
            guard let encryptedMetadataKey = encryptedMetadataKey(
                users: metadataV2.users,
                userId: userId,
                rootEncryptedMetadataKey: rootEncryptedMetadataKey
            ) else {
                return .unavailable
            }

            return try resolve(
                currentKeySet: currentKeySet,
                account: account,
                canDecrypt: { keySet in
                    canDecryptMetadataKey(encryptedMetadataKey, with: keySet)
                }
            )
        }

        return .unavailable
    }

    func resolve(encryptedMetadataKey: String, account: String) throws -> NCEndToEndKeySetAccess {
        try resolve(
            currentKeySet: currentKeySet(account: account),
            account: account,
            canDecrypt: { keySet in
                canDecryptMetadataKey(encryptedMetadataKey, with: keySet)
            }
        )
    }

    /// Child V2 metadata omits users, or encodes them as an empty array, and
    /// therefore reuses the encrypted key saved when its encrypted root was decoded.
    func encryptedMetadataKey(
        users: [NCEndToEndMetadata.E2eeV2.Users]?,
        userId: String,
        rootEncryptedMetadataKey: String?
    ) -> String? {
        if let users, !users.isEmpty {
            return users
                .first(where: { $0.userId == userId })?
                .encryptedMetadataKey
        }

        return rootEncryptedMetadataKey
    }

    /// Kept internal so candidate ordering can be verified independently of
    /// the platform crypto implementation.
    func select(
        currentKeySet: NCEndToEndKeySet?,
        archivedKeySets: [NCEndToEndKeySet],
        canDecrypt: (NCEndToEndKeySet) -> Bool
    ) -> NCEndToEndKeySetAccess {
        if let currentKeySet, canDecrypt(currentKeySet) {
            return .active(currentKeySet)
        }

        for keySet in archivedKeySets.reversed() where canDecrypt(keySet) {
            return .archived(keySet)
        }

        return .unavailable
    }

    private func resolve(
        currentKeySet: NCEndToEndKeySet?,
        account: String,
        canDecrypt: (NCEndToEndKeySet) -> Bool
    ) throws -> NCEndToEndKeySetAccess {
        if let currentKeySet, canDecrypt(currentKeySet) {
            return .active(currentKeySet)
        }

        return select(
            currentKeySet: nil,
            archivedKeySets: try preferences.getArchivedEndToEndKeySets(account: account),
            canDecrypt: canDecrypt
        )
    }

    func currentKeySet(account: String) -> NCEndToEndKeySet? {
        guard preferences.isEndToEndEnabled(account: account),
              !preferences.isEndToEndServerKeyStale(account: account) else {
            return nil
        }

        return NCEndToEndKeySet(
            certificate: preferences.getEndToEndCertificate(account: account),
            privateKey: preferences.getEndToEndPrivateKey(account: account),
            publicKey: preferences.getEndToEndPublicKey(account: account),
            passphrase: preferences.getEndToEndPassphrase(account: account),
            identifier: "active:" + account,
            archivedAt: .distantFuture
        )
    }

    private func canDecryptLegacyMetadataKey(_ encryptedMetadataKey: String, with keySet: NCEndToEndKeySet) -> Bool {
        guard let privateKey = keySet.privateKey,
              let encryptedData = Data(base64Encoded: encryptedMetadataKey),
              let decryptedData = NCEndToEndEncryption.shared().decryptAsymmetricData(encryptedData, privateKey: privateKey),
              let decodedData = Data(base64Encoded: decryptedData),
              let decodedKey = String(data: decodedData, encoding: .utf8) else {
            return false
        }

        return !decodedKey.isEmpty
    }

    private func canDecryptMetadataKey(_ encryptedMetadataKey: String, with keySet: NCEndToEndKeySet) -> Bool {
        guard let privateKey = keySet.privateKey,
              let encryptedData = Data(base64Encoded: encryptedMetadataKey),
              let decryptedData = NCEndToEndEncryption.shared().decryptAsymmetricData(encryptedData, privateKey: privateKey) else {
            return false
        }

        return !decryptedData.isEmpty
    }
}
