// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import Nextcloud

// The extension's pure name planner is included directly in this test target.
@Suite("Share extension conflict names")
struct NCShareUploadNamePlannerTests {
    @Test("Unused names remain unchanged")
    func unchangedNames() {
        let names = ["photo.jpg", "report.pdf"]
        #expect(NCShareUploadNamePlanner.fileNames(for: names, existingNames: []) == names)
    }

    @Test("Existing files keep their names and copies receive the first free suffix")
    func existingCopies() {
        #expect(NCShareUploadNamePlanner.fileNames(
            for: ["photo.jpg"], existingNames: ["photo.jpg", "photo (1).jpg", "photo (2).jpg"]
        ) == ["photo (3).jpg"])
    }

    @Test("An earlier conflict cannot consume the original name of a later attachment")
    func reservesBatchNames() {
        #expect(NCShareUploadNamePlanner.fileNames(
            for: ["photo.jpg", "photo (1).jpg"], existingNames: ["photo.jpg"]
        ) == ["photo (2).jpg", "photo (1).jpg"])
    }

    @Test("Different source names that become equal after validation remain distinct")
    func duplicateValidatedNames() {
        let names = NCShareUploadNamePlanner.fileNames(for: ["report.pdf", "report.pdf", "report.pdf"], existingNames: [])
        #expect(names == ["report.pdf", "report (1).pdf", "report (2).pdf"])
    }

    @Test("An existing numeric suffix advances without nesting another suffix")
    func existingSuffix() {
        #expect(NCShareUploadNamePlanner.fileNames(
            for: ["photo (3).JPG"], existingNames: ["photo (3).JPG", "photo (4).JPG"]
        ) == ["photo (5).JPG"])
    }

    @Test("Files without extensions and hidden names remain valid")
    func extensionlessAndHidden() {
        #expect(NCShareUploadNamePlanner.fileNames(
            for: ["README", ".env"], existingNames: ["README", ".env"]
        ) == ["README (1)", ".env (1)"])
    }

    @Test("Canonical Unicode spellings refer to the same occupied name")
    func unicodeNames() {
        let names = NCShareUploadNamePlanner.fileNames(for: ["café.txt"], existingNames: ["cafe\u{301}.txt"])
        #expect(names == ["café (1).txt"])
    }

    @Test("A hundred conflicts produce a hundred distinct new names")
    func largeBatch() {
        let names = (1...100).map { "photo\($0).jpg" }
        let existing = Set(names + names.map { ($0 as NSString).deletingPathExtension + " (1).jpg" })
        let allocated = NCShareUploadNamePlanner.fileNames(for: names, existingNames: existing)

        #expect(allocated.count == 100)
        #expect(Set(allocated).count == 100)
        #expect(Set(allocated).isDisjoint(with: existing))
        #expect(allocated == (1...100).map { "photo\($0) (2).jpg" })
    }
}
