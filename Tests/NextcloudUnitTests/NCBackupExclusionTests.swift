// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import Nextcloud

@Suite("Backup exclusion")
struct NCBackupExclusionTests {
    @Test("A directory given as a path is marked as excluded from backup")
    func directoryIsExcluded() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NCBackupExclusionTests-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(NCUtilityFileSystem().excludeFromBackup(path: directory.path))

        let values = try URL(fileURLWithPath: directory.path, isDirectory: true)
            .resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }

    @Test("An empty path is rejected")
    func emptyPathIsRejected() {
        #expect(!NCUtilityFileSystem().excludeFromBackup(path: ""))
    }
}
