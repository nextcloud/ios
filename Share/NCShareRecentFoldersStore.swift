// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

@MainActor
struct NCShareRecentFoldersStore {
    struct Item: Codable, Equatable, Sendable {
        let serverUrl: String
        let name: String
        let ocId: String
        let isEncrypted: Bool
    }

    private let limit = 3
    private let defaults: UserDefaults
    private let keyPrefix = "share.recentFolders.v1."

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func folders(account: String) -> [Item] {
        guard let data = defaults.data(forKey: keyPrefix + account),
              let items = try? JSONDecoder().decode([Item].self, from: data) else { return [] }
        var seen: Set<String> = []
        return Array(items.filter { !$0.serverUrl.isEmpty && seen.insert($0.serverUrl).inserted }.prefix(limit))
    }

    /// Call only after the complete upload operation has succeeded.
    func record(_ item: Item, account: String) {
        guard !account.isEmpty, !item.serverUrl.isEmpty else { return }
        let updated = [item] + folders(account: account).filter { $0.serverUrl != item.serverUrl }
        save(Array(updated.prefix(limit)), account: account)
    }

    func remove(serverUrl: String, account: String) {
        save(folders(account: account).filter { $0.serverUrl != serverUrl }, account: account)
    }

    private func save(_ items: [Item], account: String) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: keyPrefix + account)
    }
}
