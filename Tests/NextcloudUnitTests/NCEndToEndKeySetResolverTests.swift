// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import Nextcloud

@Suite("End-to-end key set resolver")
struct NCEndToEndKeySetResolverTests {
    @Test("The active key set has priority over archived key sets")
    func activeKeySetHasPriority() throws {
        let active = try #require(makeKeySet(identifier: "active"))
        let archived = try #require(makeKeySet(identifier: "archived"))

        let access = NCEndToEndKeySetResolver().select(
            currentKeySet: active,
            archivedKeySets: [archived],
            canDecrypt: { _ in true }
        )

        #expect(access == .active(active))
        #expect(access.canWrite)
        #expect(access.writeAccessError == .success)
    }

    @Test("Equivalent PEM formatting identifies the same public key")
    func equivalentPublicKeysMatch() {
        let compact = "-----BEGIN PUBLIC KEY-----\nYWJjZA==\n-----END PUBLIC KEY-----"
        let wrapped = "-----BEGIN PUBLIC KEY-----\nYWJj\nZA==\n-----END PUBLIC KEY-----\n"
        let empty = "-----BEGIN PUBLIC KEY-----\n-----END PUBLIC KEY-----"

        #expect(NCNetworkingE2EE().publicKeysMatch(compact, wrapped))
        #expect(!NCNetworkingE2EE().publicKeysMatch(compact, "different-key"))
        #expect(!NCNetworkingE2EE().publicKeysMatch(empty, empty))
    }

    @Test("A stale local key is excluded from active write access")
    func staleKeyIsNotActive() throws {
        let account = "e2ee-stale-\(UUID().uuidString)"
        let preferences = NCPreferences()
        defer {
            preferences.clearAllKeysEndToEnd(account: account)
        }

        preferences.setEndToEndCertificate(account: account, certificate: "certificate")
        preferences.setEndToEndPrivateKey(account: account, privateKey: "private-key")
        preferences.setEndToEndPublicKey(account: account, publicKey: "public-key")
        preferences.setEndToEndPassphrase(account: account, passphrase: "passphrase")
        try preferences.archiveCurrentEndToEndKeySet(account: account)
        preferences.setEndToEndServerKeyStale(account: account, stale: true)

        let resolver = NCEndToEndKeySetResolver(preferences: preferences)
        let archivedKeySets = try preferences.getArchivedEndToEndKeySets(account: account)
        let archivedKeySet = try #require(archivedKeySets.last)
        let access = resolver.select(
            currentKeySet: resolver.currentKeySet(account: account),
            archivedKeySets: archivedKeySets,
            canDecrypt: { _ in true }
        )

        #expect(access == .archived(archivedKeySet))
        #expect(!access.canWrite)
    }

    @Test("The most recently archived matching key set is selected")
    func newestArchivedKeySetHasPriority() throws {
        let oldest = try #require(makeKeySet(identifier: "oldest"))
        let newest = try #require(makeKeySet(identifier: "newest"))

        let access = NCEndToEndKeySetResolver().select(
            currentKeySet: nil,
            archivedKeySets: [oldest, newest],
            canDecrypt: { _ in true }
        )

        #expect(access == .archived(newest))
        #expect(access.isReadOnly)
        #expect(access.writeAccessError.errorCode == NCGlobal.shared.errorE2EEReadOnly)
    }

    @Test("Access is unavailable when no key set can decrypt metadata")
    func unavailableWithoutMatchingKeySet() throws {
        let active = try #require(makeKeySet(identifier: "active"))
        let archived = try #require(makeKeySet(identifier: "archived"))

        let access = NCEndToEndKeySetResolver().select(
            currentKeySet: active,
            archivedKeySets: [archived],
            canDecrypt: { _ in false }
        )

        #expect(access == .unavailable)
        #expect(!access.canWrite)
        #expect(!access.isReadOnly)
        #expect(access.writeAccessError.errorCode == NCGlobal.shared.errorE2EENoUserFound)
    }

    @Test("A V2 child folder inherits its encrypted root metadata key")
    func childFolderUsesRootEncryptedMetadataKey() {
        let encryptedMetadataKey = NCEndToEndKeySetResolver().encryptedMetadataKey(
            users: nil,
            userId: "user",
            rootEncryptedMetadataKey: "root-key"
        )

        #expect(encryptedMetadataKey == "root-key")
    }

    @Test("A V2 child folder with an empty users array inherits its encrypted root metadata key")
    func childFolderWithEmptyUsersUsesRootEncryptedMetadataKey() {
        let encryptedMetadataKey = NCEndToEndKeySetResolver().encryptedMetadataKey(
            users: [],
            userId: "user",
            rootEncryptedMetadataKey: "root-key"
        )

        #expect(encryptedMetadataKey == "root-key")
    }

    @Test("A V2 root never falls back to a previously saved user key")
    func rootWithoutCurrentUserDoesNotUseSavedKey() {
        let otherUser = NCEndToEndMetadata.E2eeV2.Users(
            userId: "other-user",
            certificate: "certificate",
            encryptedMetadataKey: "other-key"
        )

        let encryptedMetadataKey = NCEndToEndKeySetResolver().encryptedMetadataKey(
            users: [otherUser],
            userId: "user",
            rootEncryptedMetadataKey: "saved-root-key"
        )

        #expect(encryptedMetadataKey == nil)
    }

    private func makeKeySet(identifier: String) -> NCEndToEndKeySet? {
        NCEndToEndKeySet(
            certificate: "certificate-" + identifier,
            privateKey: "private-key-" + identifier,
            publicKey: "public-key-" + identifier,
            passphrase: "passphrase-" + identifier,
            identifier: identifier,
            archivedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
