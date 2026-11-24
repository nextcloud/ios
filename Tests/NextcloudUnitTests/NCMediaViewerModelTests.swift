// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
import NextcloudKit
@testable import Nextcloud

@Suite("Media viewer model")
@MainActor
struct NCMediaViewerModelTests {
    @Test("Duplicate media identifiers produce a single viewer page")
    func removesDuplicateIdentifiers() {
        var metadata = NCMediaViewerItem()
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
        var metadata = NCMediaViewerItem()
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
        var metadata = imageMetadata(fileName: "live-photo.heic")
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

    @Test("Viewer metadata is a value snapshot, including Live Photo and file names")
    func metadataSnapshotDoesNotFollowRealmObjectMutations() {
        let metadata = tableMetadata()
        metadata.account = "account"
        metadata.ocId = "photo"
        metadata.fileId = "42"
        metadata.fileName = "encrypted-name"
        metadata.fileNameView = "Photo.HEIC"
        metadata.livePhotoFile = "companion-id"
        metadata.date = NSDate(timeIntervalSince1970: 123)
        metadata.size = 2048
        metadata.width = 4000
        metadata.height = 3000
        metadata.latitude = 45.46
        metadata.longitude = 9.19
        let item = NCMediaViewerItem(metadata: metadata)

        metadata.fileNameView = "Renamed.jpg"
        metadata.livePhotoFile = ""
        metadata.size = 0
        metadata.latitude = 0
        metadata.longitude = 0

        #expect(item.account == "account")
        #expect(item.ocId == "photo")
        #expect(item.fileId == "42")
        #expect(item.fileName == "encrypted-name")
        #expect(item.fileNameView == "Photo.HEIC")
        #expect(item.fileExtension == "HEIC")
        #expect(item.isLivePhoto)
        #expect(item.livePhotoFile == "companion-id")
        #expect(item.date == Date(timeIntervalSince1970: 123))
        #expect(item.size == 2048)
        #expect(item.width == 4000)
        #expect(item.height == 3000)
        #expect(item.latitude == 45.46)
        #expect(item.longitude == 9.19)
    }

    @Test("The app boundary preserves fields not exposed by the viewer")
    func appBoundaryPreservesCompleteDetachedMetadata() throws {
        let metadata = tableMetadata()
        metadata.account = "first-account"
        metadata.ocId = "same-id"
        metadata.permissions = "RGDNVW"
        metadata.placeholder = true
        metadata.url = "/temporary/movie.mov"
        let loader = NCMediaViewerLoader()
        let model = NCMediaViewerModel(
            currentMetadata: metadata, ocIds: [metadata.ocId],
            session: NCSession().getSession(account: ""), loader: loader
        )
        let item = try #require(model.selectedMetadata)
        metadata.permissions = ""

        let copy = try #require(model.appMetadata(for: item))
        #expect(copy.permissions == "RGDNVW")
        #expect(copy.placeholder)
        #expect(item.url == "/temporary/movie.mov")
        copy.permissions = "changed-by-action"
        #expect(model.appMetadata(for: item)?.permissions == "RGDNVW")

        metadata.account = "second-account"
        let otherItem = loader.item(from: metadata)
        #expect(loader.appMetadata(for: otherItem)?.permissions == "")
        #expect(model.appMetadata(for: item)?.permissions == "RGDNVW")
    }

    private func makeViewerModel() -> NCMediaViewerModel {
        var metadata = NCMediaViewerItem()
        metadata.ocId = "first"

        return NCMediaViewerModel(
            currentMetadata: metadata,
            ocIds: ["first", "second", "third"],
            session: NCSession().getSession(account: ""),
            loader: NCMediaViewerLoader()
        )
    }

    private func imageMetadata(fileName: String) -> NCMediaViewerItem {
        var metadata = NCMediaViewerItem()
        metadata.classFile = NKTypeClassFile.image.rawValue
        metadata.fileName = fileName
        metadata.fileNameView = fileName
        return metadata
    }
}
