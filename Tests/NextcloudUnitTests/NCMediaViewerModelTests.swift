// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
import NextcloudKit
@testable import Nextcloud

@Suite("Media viewer model")
@MainActor
struct NCMediaViewerModelTests {
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

    @Test("Programmatic paging deactivates media until the target settles")
    func programmaticPagingActivatesOnlySettledTarget() {
        let model = makeViewerModel()

        #expect(model.activePageIndex == 0)

        model.beginPageTransition(
            to: 1,
            shouldAutoPlay: true
        )

        #expect(model.pageTransition == .programmatic(targetIndex: 1))
        #expect(model.selectedIndex == 0)
        #expect(model.activePageIndex == nil)
        #expect(model.autoPlayTargetIndex == 1)

        model.finishPageTransition(at: 1)

        #expect(model.pageTransition == .idle)
        #expect(model.selectedIndex == 1)
        #expect(model.activePageIndex == 1)
        #expect(model.autoPlayTargetIndex == 1)
    }

    @Test("Interactive paging keeps intermediate pages inactive")
    func interactivePagingKeepsIntermediatePagesInactive() {
        let model = makeViewerModel()

        model.beginPageTransition(
            to: nil,
            shouldAutoPlay: false
        )
        model.updateSelectedIndexDuringTransition(1)

        #expect(model.pageTransition == .interactive)
        #expect(model.selectedIndex == 1)
        #expect(model.activePageIndex == nil)

        model.finishPageTransition(at: 1)

        #expect(model.pageTransition == .idle)
        #expect(model.activePageIndex == 1)
    }

    @Test("Settling on an unexpected page cancels pending autoplay")
    func unexpectedSettledPageCancelsAutoPlay() {
        let model = makeViewerModel()

        model.beginPageTransition(
            to: 2,
            shouldAutoPlay: true
        )
        model.finishPageTransition(at: 1)

        #expect(model.pageTransition == .idle)
        #expect(model.activePageIndex == 1)
        #expect(model.autoPlayTargetIndex == nil)
    }

    @Test("Selection updates are ignored outside an interactive transition")
    func ignoresTransitionUpdatesWhileIdle() {
        let model = makeViewerModel()

        model.updateSelectedIndexDuringTransition(1)

        #expect(model.selectedIndex == 0)
        #expect(model.activePageIndex == 0)
    }

    @Test("Loading a page does not implicitly change the selection")
    func loadingDoesNotSelectPage() async {
        let model = makeViewerModel()

        await model.displayPage(at: 1)

        #expect(model.selectedIndex == 0)
        #expect(model.activePageIndex == 0)
    }

    @Test("Regular image previews do not require the original file")
    func regularImagePreviewDoesNotRequireOriginal() {
        let metadata = imageMetadata(fileName: "photo.HEIC")
        let policy = NCMediaViewerLoadingPolicy.standard

        #expect(!policy.shouldDownloadOriginalImage(
            for: metadata,
            hasUsablePreview: true
        ))
    }

    @Test("GIF and SVG images always require the original file")
    func specialImageFormatsRequireOriginal() {
        let policy = NCMediaViewerLoadingPolicy.standard

        #expect(policy.shouldDownloadOriginalImage(
            for: imageMetadata(fileName: "animation.GIF"),
            hasUsablePreview: true
        ))
        #expect(policy.shouldDownloadOriginalImage(
            for: imageMetadata(fileName: "drawing.svg"),
            hasUsablePreview: true
        ))
    }

    @Test("A missing preview falls back to the original file")
    func missingPreviewRequiresOriginal() {
        let metadata = imageMetadata(fileName: "photo.jpg")
        let policy = NCMediaViewerLoadingPolicy.standard

        #expect(policy.shouldDownloadOriginalImage(
            for: metadata,
            hasUsablePreview: false
        ))
    }

    @Test("The internal switch restores automatic original downloads")
    func internalSwitchEnablesOriginalDownloads() {
        let metadata = imageMetadata(fileName: "photo.jpg")
        let policy = NCMediaViewerLoadingPolicy(
            automaticallyDownloadsOriginalImages: true,
            automaticallyDownloadsLivePhotoResources: false
        )

        #expect(policy.shouldDownloadOriginalImage(
            for: metadata,
            hasUsablePreview: true
        ))
    }

    @Test("Live Photo resources remain on demand unless their switch is enabled")
    func livePhotoResourcesRespectInternalSwitch() {
        let metadata = imageMetadata(fileName: "live-photo.heic")
        metadata.livePhotoFile = "live-photo.mov"

        #expect(!NCMediaViewerLoadingPolicy.standard.shouldDownloadLivePhotoResources(
            for: metadata
        ))

        let automaticPolicy = NCMediaViewerLoadingPolicy(
            automaticallyDownloadsOriginalImages: false,
            automaticallyDownloadsLivePhotoResources: true
        )

        #expect(automaticPolicy.shouldDownloadLivePhotoResources(for: metadata))
        #expect(automaticPolicy.shouldDownloadOriginalImage(
            for: metadata,
            hasUsablePreview: true
        ))
    }

    private func makeViewerModel() -> NCMediaViewerModel {
        let metadata = tableMetadata()
        metadata.ocId = "first"

        return NCMediaViewerModel(
            currentMetadata: metadata,
            ocIds: ["first", "second", "third"],
            session: NCSession().getSession(account: ""),
            loader: NCMediaViewerLoader()
        )
    }

    private func imageMetadata(fileName: String) -> tableMetadata {
        let metadata = tableMetadata()
        metadata.classFile = NKTypeClassFile.image.rawValue
        metadata.fileName = fileName
        metadata.fileNameView = fileName
        return metadata
    }
}
