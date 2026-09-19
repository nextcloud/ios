// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// An immutable snapshot of the local E2EE credentials for an account.
///
/// Individual values are optional because older setup attempts may have been
/// interrupted after storing only part of the key set. Keeping that partial
/// state can still preserve key material needed to read existing encrypted
/// content.
struct NCEndToEndKeySet: Codable, Equatable, Sendable {
    let identifier: String
    let archivedAt: Date
    let certificate: String?
    let privateKey: String?
    let publicKey: String?
    let passphrase: String?

    init?(
        certificate: String?,
        privateKey: String?,
        publicKey: String?,
        passphrase: String?,
        identifier: String = UUID().uuidString,
        archivedAt: Date = Date()
    ) {
        let certificate = Self.nonEmpty(certificate)
        let privateKey = Self.nonEmpty(privateKey)
        let publicKey = Self.nonEmpty(publicKey)
        let passphrase = Self.nonEmpty(passphrase)

        guard certificate != nil || privateKey != nil || publicKey != nil || passphrase != nil else {
            return nil
        }

        self.identifier = identifier
        self.archivedAt = archivedAt
        self.certificate = certificate
        self.privateKey = privateKey
        self.publicKey = publicKey
        self.passphrase = passphrase
    }

    func containsSameKeyMaterial(as other: NCEndToEndKeySet) -> Bool {
        certificate == other.certificate &&
            privateKey == other.privateKey &&
            publicKey == other.publicKey &&
            passphrase == other.passphrase
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }
        return value
    }
}
