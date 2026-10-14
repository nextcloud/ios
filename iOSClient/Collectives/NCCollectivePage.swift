// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A page of a collective as returned by the Collectives app OCS API.
///
/// Every page is a Markdown file. A page with subpages is stored as `<title>/Readme.md`,
/// a page without subpages as `<title>.md`, so always use the latest server data to build paths.
struct NCCollectivePage: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let parentId: Int
    let title: String
    let emoji: String?
    let timestamp: Int
    let fileName: String
    let filePath: String
    let collectivePath: String?
    let lastUserDisplayName: String?
    let subpageOrder: [Int]

    var isLandingPage: Bool {
        parentId == 0
    }

    var modificationDate: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    /// The page file path relative to the user's root folder, e.g. `.Collectives/Handbook/Intro/Readme.md`.
    var relativeFilePath: String? {
        guard let collectivePath, !collectivePath.isEmpty else { return nil }
        return [collectivePath, filePath, fileName]
            .filter { !$0.isEmpty }
            .joined(separator: "/")
    }

    /// The page id a link points to, e.g. `Intro/Readme.md?fileId=12` or `…/apps/collectives/Handbook-1/Intro-12`.
    /// A page's id is the file id of its Markdown file.
    static func pageId(linkedBy url: URL) -> Int? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let fileId = components?.queryItems?.first(where: { $0.name == "fileId" })?.value.flatMap({ Int($0) }) {
            return fileId
        }
        guard url.path.contains("/apps/collectives/") else { return nil }
        return url.lastPathComponent.split(separator: "-").last.flatMap { Int($0) }
    }
}
