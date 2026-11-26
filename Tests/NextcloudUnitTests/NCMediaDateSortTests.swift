// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import Testing
@testable import Nextcloud

@Suite("Media date sorting")
struct NCMediaDateSortTests {
    @Test
    func capturedDateAndModificationDateStayIndependent() {
        let modified = Date(timeIntervalSince1970: 200)
        let captured = Date(timeIntervalSince1970: 100)
        let file = NKFile(date: modified, datePhotosOriginal: captured)

        #expect(NCMediaNetwork.DateSort.modified.date(for: file) == modified)
        #expect(NCMediaNetwork.DateSort.captured.date(for: file) == captured)
        #expect(NCMediaNetwork.DateSort.captured.date(for: NKFile(date: modified)) == modified)
    }

    @Test
    func fallbackSearchOnlyIncludesFilesWithoutCaptureDates() {
        let request = NCMediaNetwork().getRequestBodySearchMedia(
            href: "/files/user/Photos",
            elementDate: "d:getlastmodified",
            lessDate: "2026-11-25T00:00:00Z",
            greaterDate: "2026-01-01T00:00:00Z",
            limit: "300",
            missingCaptureDate: true
        )

        #expect(request.contains("<d:is-defined><d:prop><nc:metadata-photos-original_date_time/></d:prop></d:is-defined>"))
        #expect(request.contains("<d:prop><d:getlastmodified/></d:prop>"))
        #expect(request.contains("<d:literal>image/%</d:literal>"))
    }
}
