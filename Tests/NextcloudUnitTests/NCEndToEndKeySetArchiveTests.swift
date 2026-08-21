// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import Nextcloud

@Suite("End-to-end key set archive")
struct NCEndToEndKeySetArchiveTests {
    @Test("Archiving does not change the active credentials")
    func preservesNormalActiveCredentials() throws {
        let account = "e2ee-archive-\(UUID().uuidString)"
        let preferences = NCPreferences()
        defer {
            preferences.clearAllKeysEndToEnd(account: account)
        }

        setKeySet(on: preferences, account: account)
        try preferences.archiveCurrentEndToEndKeySet(account: account)

        #expect(preferences.isEndToEndEnabled(account: account))
        #expect(preferences.getEndToEndCertificate(account: account) == "certificate")
        #expect(preferences.getEndToEndPrivateKey(account: account) == "private-key")
        #expect(preferences.getEndToEndPublicKey(account: account) == "public-key")
        #expect(preferences.getEndToEndPassphrase(account: account) == "passphrase")
    }

    @Test("Archiving preserves active credentials after they are cleared")
    func preservesActiveCredentials() throws {
        let account = "e2ee-archive-\(UUID().uuidString)"
        let preferences = NCPreferences()
        defer {
            preferences.clearAllKeysEndToEnd(account: account)
        }

        setKeySet(on: preferences, account: account)
        let archivedKeySet = try preferences.archiveCurrentEndToEndKeySet(account: account)
        let snapshot = try #require(archivedKeySet)

        preferences.clearCurrentKeysEndToEnd(account: account)

        #expect(preferences.getEndToEndCertificate(account: account) == nil)
        #expect(preferences.getEndToEndPrivateKey(account: account) == nil)
        #expect(preferences.getEndToEndPublicKey(account: account) == nil)
        #expect(preferences.getEndToEndPassphrase(account: account) == nil)

        let archivedKeySets = try preferences.getArchivedEndToEndKeySets(account: account)
        #expect(archivedKeySets == [snapshot])
        #expect(snapshot.certificate == "certificate")
        #expect(snapshot.privateKey == "private-key")
        #expect(snapshot.publicKey == "public-key")
        #expect(snapshot.passphrase == "passphrase")
    }

    @Test("Explicit local removal also clears stale server-key state")
    func removalClearsStaleState() {
        let account = "e2ee-archive-\(UUID().uuidString)"
        let preferences = NCPreferences()

        preferences.setEndToEndServerKeyStale(account: account, stale: true)
        preferences.clearAllKeysEndToEnd(account: account)

        #expect(!preferences.isEndToEndServerKeyStale(account: account))
    }

    @Test("Archiving the same credentials does not create duplicates")
    func avoidsDuplicates() throws {
        let account = "e2ee-archive-\(UUID().uuidString)"
        let preferences = NCPreferences()
        defer {
            preferences.clearAllKeysEndToEnd(account: account)
        }

        setKeySet(on: preferences, account: account)
        let firstArchivedKeySet = try preferences.archiveCurrentEndToEndKeySet(account: account)
        let secondArchivedKeySet = try preferences.archiveCurrentEndToEndKeySet(account: account)
        let firstSnapshot = try #require(firstArchivedKeySet)
        let secondSnapshot = try #require(secondArchivedKeySet)

        #expect(secondSnapshot.identifier == firstSnapshot.identifier)
        #expect(try preferences.getArchivedEndToEndKeySets(account: account).count == 1)
    }

    @Test("A partial setup is archived when it contains usable key material")
    func preservesPartialKeyMaterial() throws {
        let account = "e2ee-archive-\(UUID().uuidString)"
        let preferences = NCPreferences()
        defer {
            preferences.clearAllKeysEndToEnd(account: account)
        }

        preferences.setEndToEndPrivateKey(account: account, privateKey: "private-key")

        let archivedKeySet = try preferences.archiveCurrentEndToEndKeySet(account: account)
        let snapshot = try #require(archivedKeySet)

        #expect(snapshot.privateKey == "private-key")
        #expect(snapshot.certificate == nil)
        #expect(snapshot.publicKey == nil)
        #expect(snapshot.passphrase == nil)
    }

    private func setKeySet(on preferences: NCPreferences, account: String) {
        preferences.setEndToEndCertificate(account: account, certificate: "certificate")
        preferences.setEndToEndPrivateKey(account: account, privateKey: "private-key")
        preferences.setEndToEndPublicKey(account: account, publicKey: "public-key")
        preferences.setEndToEndPassphrase(account: account, passphrase: "passphrase")
    }
}
