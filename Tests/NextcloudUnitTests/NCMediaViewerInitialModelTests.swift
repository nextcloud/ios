// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import Nextcloud

@Suite("Media viewer initial model")
@MainActor
struct NCMediaViewerInitialModelTests {
    @Test("Duplicate media identifiers produce a single viewer page")
    func removesDuplicateIdentifiers() {
        let metadata = tableMetadata()
        metadata.ocId = "current"

        let model = NCMediaViewerInitialModel(
            currentMetadata: metadata,
            ocIds: ["first", "current", "current", "last", "first"]
        )

        #expect(model.normalizedOcIds == ["first", "current", "last"])
        #expect(model.currentSelectedIndex == 1)
    }

    @Test("Missing current media is inserted before the supplied identifiers")
    func insertsMissingCurrentIdentifier() {
        let metadata = tableMetadata()
        metadata.ocId = "current"

        let model = NCMediaViewerInitialModel(
            currentMetadata: metadata,
            ocIds: ["next", "next"]
        )

        #expect(model.normalizedOcIds == ["current", "next"])
        #expect(model.currentSelectedIndex == 0)
    }
}
