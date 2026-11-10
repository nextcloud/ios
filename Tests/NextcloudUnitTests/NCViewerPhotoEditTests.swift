// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Matt Van Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
import UIKit
import QuickLook
import NextcloudKit
@testable import Nextcloud

@Suite("Photo viewer edit session", .serialized)
@MainActor
struct NCViewerPhotoEditTests {

    // MARK: - Quick Look session isolation

    @Test("A second editor does not clear the first editor's changes")
    func editorsKeepSeparateChangeFlags() throws {
        let firstURL = try #require(NCViewerQuickLook.makeEditingFileURL(fileName: "photo.jpg"))
        try Data("original".utf8).write(to: firstURL)
        let first = NCViewerQuickLook(with: firstURL, isEditingEnabled: true, metadata: makeImage(ocId: "edit-first"))

        let editedURL = try #require(NCViewerQuickLook.makeEditingFileURL(fileName: "edited.jpg"))
        try Data("edited".utf8).write(to: editedURL)
        let item = PreviewItem()
        item.previewItemURL = firstURL
        first.previewController(first, didSaveEditedCopyOf: item, at: editedURL)
        #expect(first.hasChangesQuickLook)

        let secondURL = try #require(NCViewerQuickLook.makeEditingFileURL(fileName: "photo.jpg"))
        let second = NCViewerQuickLook(with: secondURL, isEditingEnabled: true, metadata: makeImage(ocId: "edit-second"))

        #expect(first.hasChangesQuickLook)
        #expect(!second.hasChangesQuickLook)
    }

    @Test("Editors of files with the same name get separate temporary files")
    func sameNameEditorsDoNotShareTheTemporaryFile() throws {
        let first = try #require(NCViewerQuickLook.makeEditingFileURL(fileName: "photo.jpg"))
        let second = try #require(NCViewerQuickLook.makeEditingFileURL(fileName: "photo.jpg"))

        #expect(first != second)
        #expect(first.lastPathComponent == "photo.jpg")
        #expect(second.lastPathComponent == "photo.jpg")

        try Data("first edit".utf8).write(to: first)
        try Data("second edit".utf8).write(to: second)

        #expect(try Data(contentsOf: first) == Data("first edit".utf8))
        #expect(try Data(contentsOf: second) == Data("second edit".utf8))
    }

    // MARK: - Shared download

    @Test("A request for a download already running joins it")
    func inFlightDownloadIsReused() async throws {
        let registry = NCInFlightTaskRegistry<String, Int>()
        let counter = Counter()
        let gate = Gate()

        async let first = registry.value(for: "photo") {
            await counter.increment()
            await gate.wait()
            return 1
        }
        await counter.waitUntil(1)
        async let second = registry.value(for: "photo") {
            await counter.increment()
            return 2
        }
        while await registry.joinedCount < 1 {
            await Task.yield()
        }
        await gate.open()

        let results = try await [first, second]
        #expect(results == [1, 1])
        #expect(await counter.value == 1)

        let next = try await registry.value(for: "photo") {
            await counter.increment()
            return 3
        }
        #expect(next == 3)
        #expect(await counter.value == 2)
    }

    // MARK: - Edit tied to the originating viewer

    @Test("Edit opens Quick Look when the viewer still shows the photo")
    func editOpensWhenPhotoIsStillShown() async {
        let metadata = makeImage(ocId: "edit-shown")
        let source = MockViewerPhotoEditSource(shownOcId: metadata.ocId)

        let edit = Task { @MainActor in
            await NCViewerPhotoEdit.edit(metadata: metadata, source: source) { source.present($0) }
        }
        await waitForDownload(source)
        source.finishDownload()

        #expect(await edit.value)
        #expect(source.presentedOcIds == [metadata.ocId])
        #expect(source.downloadRequests == [metadata.ocId])
    }

    @Test("Edit does not open Quick Look after the viewer moved to another photo")
    func editSkipsWhenViewerShowsAnotherPhoto() async {
        let metadata = makeImage(ocId: "edit-swiped")
        let source = MockViewerPhotoEditSource(shownOcId: metadata.ocId)

        let edit = Task { @MainActor in
            await NCViewerPhotoEdit.edit(metadata: metadata, source: source) { source.present($0) }
        }
        await waitForDownload(source)
        source.shownOcId = "edit-other"
        source.finishDownload()

        #expect(await edit.value == false)
        #expect(source.presentedOcIds.isEmpty)
    }

    @Test("Edit does not open Quick Look after the viewer closed")
    func editSkipsWhenViewerClosed() async {
        let metadata = makeImage(ocId: "edit-closed")
        let source = MockViewerPhotoEditSource(shownOcId: metadata.ocId)

        let edit = Task { @MainActor in
            await NCViewerPhotoEdit.edit(metadata: metadata, source: source) { source.present($0) }
        }
        await waitForDownload(source)
        source.isOnScreen = false
        source.finishDownload()

        #expect(await edit.value == false)
        #expect(source.presentedOcIds.isEmpty)
    }

    @Test("Edit does not open Quick Look when the download fails")
    func editSkipsWhenDownloadFails() async {
        let metadata = makeImage(ocId: "edit-failed")
        let source = MockViewerPhotoEditSource(shownOcId: metadata.ocId)

        let edit = Task { @MainActor in
            await NCViewerPhotoEdit.edit(metadata: metadata, source: source) { source.present($0) }
        }
        await waitForDownload(source)
        source.finishDownload(error: URLError(.notConnectedToInternet))

        #expect(await edit.value == false)
        #expect(source.presentedOcIds.isEmpty)
    }

    // MARK: - Helpers

    private func waitForDownload(_ source: MockViewerPhotoEditSource) async {
        while !source.hasPendingDownload {
            await Task.yield()
        }
    }

    private func makeImage(ocId: String) -> tableMetadata {
        let metadata = tableMetadata()
        metadata.account = "viewer-edit-session"
        metadata.ocId = ocId
        metadata.fileName = "photo.jpg"
        metadata.fileNameView = "photo.jpg"
        metadata.classFile = NKTypeClassFile.image.rawValue
        metadata.contentType = "image/jpeg"
        metadata.urlBase = "https://example.com"
        metadata.userId = "user"
        metadata.serverUrl = "https://example.com/remote.php/dav/files/user/Photos"
        return metadata
    }
}

private actor Counter {
    private(set) var value = 0

    func increment() {
        value += 1
    }

    func waitUntil(_ target: Int) async {
        while value < target {
            await Task.yield()
        }
    }
}

private actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen {
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}
