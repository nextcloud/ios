// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
import UIKit
@testable import Nextcloud

@Suite("setBidiSafeTitle")
@MainActor
struct SetBidiSafeTitleTests {

    @Test("Normal file splits into base and extension labels")
    func normalFile() {
        let navItem = UINavigationItem()
        navItem.setBidiSafeTitle("document.pdf")

        let stack = try! #require(navItem.titleView as? UIStackView)
        #expect(stack.arrangedSubviews.count == 2)

        let baseLabel = stack.arrangedSubviews[0] as? UILabel
        let extLabel = stack.arrangedSubviews[1] as? UILabel
        #expect(baseLabel?.text == "document")
        #expect(extLabel?.text == ".pdf")
        #expect(navItem.title == nil)
    }

    @Test("Multiple extensions splits on last dot")
    func multipleExtensions() {
        let navItem = UINavigationItem()
        navItem.setBidiSafeTitle("archive.tar.gz")

        let stack = try! #require(navItem.titleView as? UIStackView)
        let baseLabel = stack.arrangedSubviews[0] as? UILabel
        let extLabel = stack.arrangedSubviews[1] as? UILabel
        #expect(baseLabel?.text == "archive.tar")
        #expect(extLabel?.text == ".gz")
    }

    @Test("No extension uses plain title")
    func noExtension() {
        let navItem = UINavigationItem()
        navItem.setBidiSafeTitle("README")

        #expect(navItem.titleView == nil)
        #expect(navItem.title == "README")
    }

    @Test("Dotfile uses plain title")
    func dotfile() {
        let navItem = UINavigationItem()
        navItem.setBidiSafeTitle(".hidden")

        #expect(navItem.titleView == nil)
        #expect(navItem.title == ".hidden")
    }

    @Test("Empty string uses plain title")
    func emptyString() {
        let navItem = UINavigationItem()
        navItem.setBidiSafeTitle("")

        #expect(navItem.titleView == nil)
        #expect(navItem.title == "")
    }

    @Test("RLO override isolates the real extension")
    func rloOverride() {
        let navItem = UINavigationItem()
        // U+202E (RLO) reverses displayed text: "malware\u{202E}fdp.exe" looks like "malwareexe.pdf"
        let malicious = "malware\u{202E}fdp.exe"
        navItem.setBidiSafeTitle(malicious)

        let stack = try! #require(navItem.titleView as? UIStackView)
        let extLabel = stack.arrangedSubviews[1] as? UILabel
        #expect(extLabel?.text == ".exe")
    }

    @Test("RLI override isolates the real extension")
    func rliOverride() {
        let navItem = UINavigationItem()
        // U+2067 (RLI) Right-to-Left Isolate
        let malicious = "invoice\u{2067}cod.exe"
        navItem.setBidiSafeTitle(malicious)

        let stack = try! #require(navItem.titleView as? UIStackView)
        let extLabel = stack.arrangedSubviews[1] as? UILabel
        #expect(extLabel?.text == ".exe")
    }

    @Test("LRO override isolates the real extension")
    func lroOverride() {
        let navItem = UINavigationItem()
        // U+202D (LRO) Left-to-Right Override
        let malicious = "report\u{202D}exe.pdf"
        navItem.setBidiSafeTitle(malicious)

        let stack = try! #require(navItem.titleView as? UIStackView)
        let extLabel = stack.arrangedSubviews[1] as? UILabel
        #expect(extLabel?.text == ".pdf")
    }

    @Test("Multiple bidi characters isolates the real extension")
    func multipleBidiChars() {
        let navItem = UINavigationItem()
        // Stacked overrides: RLO + LRI
        let malicious = "\u{202E}\u{2066}safe_document\u{2069}cod.exe"
        navItem.setBidiSafeTitle(malicious)

        let stack = try! #require(navItem.titleView as? UIStackView)
        let extLabel = stack.arrangedSubviews[1] as? UILabel
        #expect(extLabel?.text == ".exe")
    }

    @Test("Bidi override with PDF isolate in extension")
    func bidiPDFIsolate() {
        let navItem = UINavigationItem()
        // U+2069 (PDI) Pop Directional Isolate used to terminate an isolate
        let malicious = "image\u{2066}exe.jpg\u{2069}.png"
        navItem.setBidiSafeTitle(malicious)

        let stack = try! #require(navItem.titleView as? UIStackView)
        let extLabel = stack.arrangedSubviews[1] as? UILabel
        #expect(extLabel?.text == ".png")
    }

    @Test("FSI override isolates the real extension")
    func fsiOverride() {
        let navItem = UINavigationItem()
        // U+2068 (FSI) First Strong Isolate
        let malicious = "notes\u{2068}exe.bat"
        navItem.setBidiSafeTitle(malicious)

        let stack = try! #require(navItem.titleView as? UIStackView)
        let extLabel = stack.arrangedSubviews[1] as? UILabel
        #expect(extLabel?.text == ".bat")
    }
}

@Suite("setBidiSafeFilename")
@MainActor
struct SetBidiSafeFilenameTests {

    @Test("Normal file splits labels")
    func normalFile() {
        let view = UIView()
        let titleLabel = UILabel()
        let extensionLabel = UILabel()

        view.setBidiSafeFilename("photo.jpg", isDirectory: false, titleLabel: titleLabel, extensionLabel: extensionLabel)

        #expect(titleLabel.text == "photo")
        #expect(extensionLabel.text == ".jpg")
        #expect(extensionLabel.isHidden == false)
    }

    @Test("Directory shows full name and hides extension label")
    func directory() {
        let view = UIView()
        let titleLabel = UILabel()
        let extensionLabel = UILabel()

        view.setBidiSafeFilename("My Folder.backup", isDirectory: true, titleLabel: titleLabel, extensionLabel: extensionLabel)

        #expect(titleLabel.text == "My Folder.backup")
        #expect(extensionLabel.text == "")
        #expect(extensionLabel.isHidden == true)
    }

    @Test("No extension shows full name")
    func noExtension() {
        let view = UIView()
        let titleLabel = UILabel()
        let extensionLabel = UILabel()

        view.setBidiSafeFilename("Makefile", isDirectory: false, titleLabel: titleLabel, extensionLabel: extensionLabel)

        #expect(titleLabel.text == "Makefile")
        #expect(extensionLabel.text == "")
        #expect(extensionLabel.isHidden == true)
    }

    @Test("Dotfile shows full name")
    func dotfile() {
        let view = UIView()
        let titleLabel = UILabel()
        let extensionLabel = UILabel()

        view.setBidiSafeFilename(".gitignore", isDirectory: false, titleLabel: titleLabel, extensionLabel: extensionLabel)

        #expect(titleLabel.text == ".gitignore")
        #expect(extensionLabel.text == "")
        #expect(extensionLabel.isHidden == true)
    }

    @Test("Multiple extensions splits on last dot")
    func multipleExtensions() {
        let view = UIView()
        let titleLabel = UILabel()
        let extensionLabel = UILabel()

        view.setBidiSafeFilename("backup.tar.gz", isDirectory: false, titleLabel: titleLabel, extensionLabel: extensionLabel)

        #expect(titleLabel.text == "backup.tar")
        #expect(extensionLabel.text == ".gz")
        #expect(extensionLabel.isHidden == false)
    }

    @Test("RLO override isolates the real extension")
    func rloOverride() {
        let view = UIView()
        let titleLabel = UILabel()
        let extensionLabel = UILabel()

        // U+202E (RLO) reverses displayed text
        let malicious = "malware\u{202E}fdp.exe"
        view.setBidiSafeFilename(malicious, isDirectory: false, titleLabel: titleLabel, extensionLabel: extensionLabel)

        #expect(extensionLabel.text == ".exe")
        #expect(extensionLabel.isHidden == false)
    }

    @Test("RLI override isolates the real extension")
    func rliOverride() {
        let view = UIView()
        let titleLabel = UILabel()
        let extensionLabel = UILabel()

        // U+2067 (RLI) Right-to-Left Isolate
        let malicious = "invoice\u{2067}cod.exe"
        view.setBidiSafeFilename(malicious, isDirectory: false, titleLabel: titleLabel, extensionLabel: extensionLabel)

        #expect(extensionLabel.text == ".exe")
        #expect(extensionLabel.isHidden == false)
    }

    @Test("Multiple bidi characters isolates the real extension")
    func multipleBidiChars() {
        let view = UIView()
        let titleLabel = UILabel()
        let extensionLabel = UILabel()

        // Stacked overrides: RLO + LRI
        let malicious = "\u{202E}\u{2066}safe_document\u{2069}cod.exe"
        view.setBidiSafeFilename(malicious, isDirectory: false, titleLabel: titleLabel, extensionLabel: extensionLabel)

        #expect(extensionLabel.text == ".exe")
        #expect(extensionLabel.isHidden == false)
    }

    @Test("Bidi override on directory still shows full name")
    func bidiDirectory() {
        let view = UIView()
        let titleLabel = UILabel()
        let extensionLabel = UILabel()

        let malicious = "folder\u{202E}exe.txt"
        view.setBidiSafeFilename(malicious, isDirectory: true, titleLabel: titleLabel, extensionLabel: extensionLabel)

        #expect(titleLabel.text == malicious)
        #expect(extensionLabel.text == "")
        #expect(extensionLabel.isHidden == true)
    }

    @Test("Nil labels does not crash")
    func nilLabels() {
        let view = UIView()
        view.setBidiSafeFilename("test.txt", isDirectory: false, titleLabel: nil, extensionLabel: nil)
    }
}
