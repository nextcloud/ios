// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Matt Van Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import Nextcloud

@Suite("Manual upload destination")
struct NCUploadAssetsModelTests {
    let baseServerUrl = "https://cloud.example/remote.php/dav/files/user/Photos"
    let granularityPath = "https://cloud.example/remote.php/dav/files/user/Photos/2026/04"

    @Test("A saved subfolder preference preserves the selected folder")
    func subfolderPreferenceDoesNotOverrideSelectedFolder() {
        let destination = NCUploadAssetsModel.manualUploadServerUrl(
            baseServerUrl: baseServerUrl,
            useAutoUploadFolder: false,
            useAutoUploadSubFolder: true,
            granularityPath: granularityPath
        )
        #expect(destination == baseServerUrl)
    }

    @Test("Auto Upload folder with subfolders uses the dated path")
    func autoUploadFolderWithSubfoldersUsesGranularityPath() {
        let destination = NCUploadAssetsModel.manualUploadServerUrl(
            baseServerUrl: baseServerUrl,
            useAutoUploadFolder: true,
            useAutoUploadSubFolder: true,
            granularityPath: granularityPath
        )
        #expect(destination == granularityPath)
    }

    @Test("Auto Upload folder without subfolders uses the base folder")
    func autoUploadFolderWithoutSubfoldersUsesBaseUrl() {
        let destination = NCUploadAssetsModel.manualUploadServerUrl(
            baseServerUrl: baseServerUrl,
            useAutoUploadFolder: true,
            useAutoUploadSubFolder: false,
            granularityPath: granularityPath
        )
        #expect(destination == baseServerUrl)
    }
}
