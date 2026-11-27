// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 zouxianxian
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import Nextcloud
@testable import NextcloudKit

@MainActor
@Suite("Unified search provider results")
struct NCUnifiedSearchResultTests {
    private let provider = NKSearchProvider(id: "documents", name: "Documents", order: 1)
    private let session = NCSession.Session(account: UUID().uuidString, urlBase: "https://example.invalid", user: "tester", userId: "tester")
    private let resourceURL = "https://example.invalid/documents/42"

    private func searchResult(includePath: Bool) throws -> NKSearchResult {
        var attributes = ["fileId": "42"]
        if includePath {
            attributes["path"] = "/Reports/report.pdf"
        }
        let entry: [String: Any] = [
            "title": "Report",
            "subline": "Search match",
            "resourceUrl": resourceURL,
            "thumbnailUrl": "",
            "icon": "",
            "rounded": false,
            "attributes": attributes
        ]
        return try #require(NKSearchResult(json: .init([
            "name": provider.name,
            "isPaginated": false,
            "entries": [entry]
        ]), id: provider.id))
    }

    @Test("A cached file ID produces exactly one file row", arguments: [true, false])
    func cachedFileAppearsOnce(includePath: Bool) async throws {
        let result = try searchResult(includePath: includePath)
        let cached = tableMetadata()
        cached.account = session.account
        cached.ocId = UUID().uuidString
        cached.fileId = "42"
        cached.fileNameView = "report.pdf"
        let database = NCManageDatabase.shared
        await database.addMetadataAsync(cached)

        let rows = await NCCollectionViewCommon().getSearchResultMetadatas(session: session, provider: provider, searchResult: result)
        await database.deleteMetadataAsync(ocId: cached.ocId)

        #expect(rows?.map(\.ocId) == [cached.ocId])
        #expect(rows?.first?.section == provider.name)
    }

    @Test("An unresolved file produces exactly one provider link", arguments: [true, false])
    func unresolvedFileFallsBackToLink(includePath: Bool) async throws {
        // This account has no registered network session, so a supplied path cannot resolve.
        let result = try searchResult(includePath: includePath)
        let rows = await NCCollectionViewCommon().getSearchResultMetadatas(session: session, provider: provider, searchResult: result)

        #expect(rows?.map(\.url) == [resourceURL])
        #expect(rows?.first?.section == provider.name)
    }
}
