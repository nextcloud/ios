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
