// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A page together with its subpages, ordered like in the Collectives web interface.
struct NCCollectivePageNode: Identifiable, Hashable, Sendable {
    let page: NCCollectivePage
    /// `nil` for pages without subpages, so `List(_:children:)` shows no disclosure indicator.
    let children: [NCCollectivePageNode]?

    var id: Int { page.id }

    /// Builds the subpage tree below `parentId` from the flat page list of a collective.
    ///
    /// Subpages follow the parent's custom `subpageOrder`; pages missing from it are appended sorted by title.
    static func tree(pages: [NCCollectivePage], parentId: Int) -> [NCCollectivePageNode] {
        let pagesByParent = Dictionary(grouping: pages, by: \.parentId)
        let order = pages.first { $0.id == parentId }?.subpageOrder ?? []
        return nodes(parentId: parentId, order: order, pagesByParent: pagesByParent)
    }

    private static func nodes(parentId: Int, order: [Int], pagesByParent: [Int: [NCCollectivePage]]) -> [NCCollectivePageNode] {
        let subpages = pagesByParent[parentId] ?? []
        let position = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let sorted = subpages.sorted { lhs, rhs in
            switch (position[lhs.id], position[rhs.id]) {
            case let (left?, right?):
                return left < right
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            case (nil, nil):
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        }
        return sorted.map { page in
            let children = nodes(parentId: page.id, order: page.subpageOrder, pagesByParent: pagesByParent)
            return NCCollectivePageNode(page: page, children: children.isEmpty ? nil : children)
        }
    }
}
