// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Matt Van Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import Nextcloud

@Suite("Manual upload destination")
@MainActor
struct NCUploadAssetsModelTests {
    @Test("A saved subfolder preference preserves the selected folder")
    func subfolderPreferenceDoesNotOverrideSelectedFolder() {
        let destination = NCUploadAssetsModel.manualUploadServerUrl(
            baseServerUrl: "/test",
            useAutoUploadFolder: false,
            useAutoUploadSubFolder: true,
            granularityPath: "https://cloud.example/remote.php/dav/files/user/Photos/2026/04"
        )
        #expect(destination == "/test")
    }
}
