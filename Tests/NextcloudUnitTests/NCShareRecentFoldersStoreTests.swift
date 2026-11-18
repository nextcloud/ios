// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import Nextcloud

@MainActor
@Suite("Share recent destinations")
struct NCShareRecentFoldersStoreTests {
    @Test("Only the last three destinations are retained, newest first")
    func threeRecentDestinations() throws {
        let suite = "ShareRecentFoldersTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = NCShareRecentFoldersStore(defaults: defaults)
        for number in 1...7 { store.record(item(number), account: "personal") }

        #expect(store.folders(account: "personal") == [7, 6, 5].map(item))
    }

    @Test("Reusing a destination moves it to the top without duplicating it")
    func movesExistingDestination() throws {
        let suite = "ShareRecentFoldersTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = NCShareRecentFoldersStore(defaults: defaults)
        for number in 1...3 { store.record(item(number), account: "personal") }
        store.record(item(2), account: "personal")

        #expect(store.folders(account: "personal") == [2, 3, 1].map(item))
    }

    @Test("Accounts have independent histories")
    func separatesAccounts() throws {
        let suite = "ShareRecentFoldersTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = NCShareRecentFoldersStore(defaults: defaults)
        store.record(item(1), account: "personal")
        store.record(item(2), account: "work")

        #expect(store.folders(account: "personal") == [item(1)])
        #expect(store.folders(account: "work") == [item(2)])
        #expect(store.folders(account: "missing").isEmpty)
    }

    @Test("The history survives recreating the store")
    func persistsDestinations() throws {
        let suite = "ShareRecentFoldersTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        NCShareRecentFoldersStore(defaults: defaults).record(item(1), account: "personal")

        let restored = NCShareRecentFoldersStore(defaults: defaults)
        #expect(restored.folders(account: "personal") == [item(1)])
    }

    @Test("A stale folder is removed only from the requested account")
    func removesUnavailableDestination() throws {
        let suite = "ShareRecentFoldersTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = NCShareRecentFoldersStore(defaults: defaults)
        store.record(item(1), account: "personal")
        store.record(item(2), account: "personal")
        store.record(item(1), account: "work")
        store.remove(serverUrl: item(1).serverUrl, account: "personal")

        #expect(store.folders(account: "personal") == [item(2)])
        #expect(store.folders(account: "work") == [item(1)])
    }

    @Test("Unreadable saved data does not prevent a new destination being recorded")
    func corruptHistory() throws {
        let suite = "ShareRecentFoldersTests-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("invalid".utf8), forKey: "share.recentFolders.v1.personal")
        let store = NCShareRecentFoldersStore(defaults: defaults)
        #expect(store.folders(account: "personal").isEmpty)
        store.record(item(1), account: "personal")
        #expect(store.folders(account: "personal") == [item(1)])
    }

    private func item(_ number: Int) -> NCShareRecentFoldersStore.Item {
        .init(serverUrl: "https://cloud.example.com/files/folder\(number)", name: "Folder \(number)", ocId: "folder\(number)", isEncrypted: false)
    }
}
