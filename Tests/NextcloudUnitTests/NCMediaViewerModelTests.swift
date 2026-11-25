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

    @Test("Buffered images load originals even when previews are available")
    func bufferedImagePreviewLoadsOriginal() {
        let metadata = imageMetadata(fileName: "photo.HEIC")
        let policy = NCMediaViewerLoadingPolicy.standard

        #expect(policy.shouldDownloadOriginalImage(
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

    @Test("Live Photo resources download by default and respect an explicitly disabled switch")
    func livePhotoResourcesRespectInternalSwitch() {
        var metadata = imageMetadata(fileName: "live-photo.heic")
        metadata.livePhotoFile = "live-photo.mov"

        #expect(NCMediaViewerLoadingPolicy.standard.shouldDownloadLivePhotoResources(
            for: metadata
        ))
        let disabledPolicy = NCMediaViewerLoadingPolicy(
            automaticallyDownloadsOriginalImages: true,
            automaticallyDownloadsLivePhotoResources: false
        )
        #expect(!disabledPolicy.shouldDownloadLivePhotoResources(for: metadata))

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
            account: "", loader: loader
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
        #expect(model.appMetadata(for: otherItem)?.permissions == "")
        #expect(model.appMetadata(for: item)?.permissions == "RGDNVW")
    }

    @Test("Originals follow the existing buffer and previews survive eviction")
    func originalsFollowBuffer() async throws {
        let items = bufferItems()
        let loader = NCMediaViewerTestLoader(items: items)
        let model = NCMediaViewerModel(currentMetadata: items[0], ocIds: items.map(\.ocId),
                                       account: items[0].account, loader: loader)
        await model.loadSelectedPageIfNeeded()
        try await waitForOriginals(Set((0...5).map(String.init)), in: loader)

        model.finishPageTransition(at: 6)
        await model.loadSelectedPageIfNeeded()
        try await waitForOriginals(Set((1...11).map(String.init)), in: loader)
        if let page = model.pageModel(at: 0), case .image(let preview, let original, _, _) = page.state {
            #expect(preview != nil)
            #expect(original == nil)
        } else {
            Issue.record("An evicted image must retain its preview")
        }

        model.finishPageTransition(at: 0)
        await model.loadSelectedPageIfNeeded()
        try await waitForOriginals(Set((0...5).map(String.init)), in: loader)
        #expect(await loader.downloadCounts["0"] == 2)
        model.cancelAllDownloads()
        try await waitForOriginals([], in: loader)
    }

    @Test("Opening details shares the buffered original download")
    func detailsWaitForBufferedDownload() async throws {
        let items = bufferItems()
        let loader = NCMediaViewerTestLoader(items: items, pausedOcIds: ["0"])
        let model = NCMediaViewerModel(currentMetadata: items[0], ocIds: items.map(\.ocId),
                                       account: items[0].account, loader: loader)
        let loading = Task { await model.loadSelectedPageIfNeeded() }
        try await waitForOriginals(Set((1...5).map(String.init)), in: loader)
        try await waitForPendingDownload("0", in: loader)
        let details = Task { try await model.downloadOriginalImage(for: items[0]) }
        await loader.resumeDownload(for: "0")
        await loading.value
        _ = try await details.value
        #expect(await loader.downloadCounts["0"] == 1)
        model.cancelAllDownloads()
        try await waitForOriginals([], in: loader)
    }

    @Test("Eviction cancels an in-flight original and re-entry can download it again")
    func evictionCancelsPendingOriginal() async throws {
        let items = bufferItems()
        let loader = NCMediaViewerTestLoader(items: items, pausedOcIds: ["0"])
        let model = NCMediaViewerModel(currentMetadata: items[0], ocIds: items.map(\.ocId),
                                       account: items[0].account, loader: loader)
        let loading = Task { await model.loadSelectedPageIfNeeded() }
        try await waitForPendingDownload("0", in: loader)
        model.finishPageTransition(at: 6)
        await model.loadSelectedPageIfNeeded()
        await loading.value
        try await waitForOriginals(Set((1...11).map(String.init)), in: loader)
        #expect(await loader.pendingOcIds.isEmpty)

        model.finishPageTransition(at: 0)
        let reloading = Task { await model.loadSelectedPageIfNeeded() }
        try await waitForPendingDownload("0", in: loader)
        await loader.resumeDownload(for: "0")
        await reloading.value
        #expect(await loader.downloadCounts["0"] == 2)
        model.cancelAllDownloads()
        try await waitForOriginals([], in: loader)
    }

    private func waitForPendingDownload(_ ocId: String, in loader: NCMediaViewerTestLoader) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !(await loader.pendingOcIds.contains(ocId)), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        try #require(await loader.pendingOcIds.contains(ocId))
    }

    @Test("Fast thumbnail scrubbing applies only the latest requested selection")
    func latestThumbnailSelectionWins() async throws {
        let items = bufferItems()
        let loader = NCMediaViewerTestLoader(items: items, pausedMetadataOcIds: ["1", "12"])
        let model = NCMediaViewerModel(currentMetadata: items[0], ocIds: items.map(\.ocId),
                                       account: items[0].account, loader: loader)
        let first = Task { await model.displayPreviewPage(at: 1) }
        try await waitForPendingMetadata("1", in: loader)
        let latest = Task { await model.displayPreviewPage(at: 12) }
        try await waitForPendingMetadata("12", in: loader)

        await loader.resumeMetadata(for: "1")
        await first.value
        #expect(model.selectedIndex == 0)
        await loader.resumeMetadata(for: "12")
        await latest.value
        #expect(model.selectedIndex == 12)
        model.cancelAllDownloads()
    }

    @Test("Returning to the current thumbnail supersedes pending navigation")
    func currentThumbnailCancelsPendingSelection() async throws {
        let items = bufferItems()
        let loader = NCMediaViewerTestLoader(items: items, pausedMetadataOcIds: ["12"])
        let model = NCMediaViewerModel(currentMetadata: items[0], ocIds: items.map(\.ocId),
                                       account: items[0].account, loader: loader)
        let pending = Task { await model.displayPreviewPage(at: 12) }
        try await waitForPendingMetadata("12", in: loader)
        await model.displayPreviewPage(at: 0)
        await loader.resumeMetadata(for: "12")
        await pending.value
        #expect(model.selectedIndex == 0)
        model.cancelAllDownloads()
    }

    private func waitForPendingMetadata(_ ocId: String, in loader: NCMediaViewerTestLoader) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !(await loader.pendingMetadataOcIds.contains(ocId)), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        try #require(await loader.pendingMetadataOcIds.contains(ocId))
    }

    @Test("Returning during removal waits before downloading the same original again")
    func reentryWaitsForRemoval() async throws {
        let items = bufferItems()
        let loader = NCMediaViewerTestLoader(items: items, pausedReleaseOcIds: ["0"])
        let model = NCMediaViewerModel(currentMetadata: items[0], ocIds: items.map(\.ocId),
                                       account: items[0].account, loader: loader)
        await model.loadSelectedPageIfNeeded()
        try await waitForOriginals(Set((0...5).map(String.init)), in: loader)
        model.finishPageTransition(at: 6)
        await model.loadSelectedPageIfNeeded()

        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !(await loader.pendingReleaseOcIds.contains("0")), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        try #require(await loader.pendingReleaseOcIds.contains("0"))
        model.finishPageTransition(at: 0)
        let returning = Task { await model.loadSelectedPageIfNeeded() }
        // Give the returning load an opportunity to run while removal is suspended.
        for _ in 0..<20 { await Task.yield() }
        #expect(await loader.downloadCounts["0"] == 1)
        await loader.resumeRelease(for: "0")
        await returning.value
        try await waitForOriginals(Set((0...5).map(String.init)), in: loader)
        #expect(await loader.downloadCounts["0"] == 2)
        if let page = model.pageModel(at: 0), case .image(_, let original, _, _) = page.state {
            #expect(original != nil)
        } else {
            Issue.record("The returning page must display the new original")
        }
        model.cancelAllDownloads()
        try await waitForOriginals([], in: loader)
    }

    @Test("Thumbnail dragging freezes originals until the final selection settles")
    func thumbnailScrubbingDefersOriginalBuffer() async throws {
        let items = bufferItems()
        let loader = NCMediaViewerTestLoader(items: items)
        let model = NCMediaViewerModel(currentMetadata: items[0], ocIds: items.map(\.ocId),
                                       account: items[0].account, loader: loader)
        await model.loadSelectedPageIfNeeded()
        let initialOriginals = Set((0...5).map(String.init))
        try await waitForOriginals(initialOriginals, in: loader)
        let initialDownloads = await loader.downloadCounts

        model.beginThumbnailScrubbing()
        for index in [6, 9, 2, 12] {
            await model.displayPreviewPage(at: index)
            // Simulate the pager callbacks caused by each intermediate thumbnail selection.
            await model.displayPage(at: index)
            await model.prefetchVisiblePageIfNeeded(index: index)
            await model.loadSelectedPageIfNeeded()
            #expect(await loader.originals == initialOriginals)
            #expect(await loader.downloadCounts == initialDownloads)
        }

        await model.endThumbnailScrubbing(at: 12)
        try await waitForOriginals(Set((7...12).map(String.init)), in: loader)
        #expect(model.selectedIndex == 12)
        #expect(await loader.downloadCounts["6"] == nil)
        model.cancelAllDownloads()
        try await waitForOriginals([], in: loader)
    }

    @Test
    func livePhotoCompanionsFollowTheImageBuffer() async throws {
        var items = bufferItems()
        for index in items.indices { items[index].livePhotoFile = "\(index).mov" }
        let loader = NCMediaViewerTestLoader(items: items)
        let model = NCMediaViewerModel(currentMetadata: items[0], ocIds: items.map(\.ocId),
                                       account: items[0].account, loader: loader)
        await model.loadSelectedPageIfNeeded()
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while await loader.liveOriginals.count != 6, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        #expect(await loader.liveOriginals == Set((0...5).map(String.init)))
        model.beginThumbnailScrubbing()
        await model.displayPreviewPage(at: 12)
        #expect(await loader.liveOriginals == Set((0...5).map(String.init)))
        await model.endThumbnailScrubbing(at: 12)
        let finalDeadline = ContinuousClock.now.advanced(by: .seconds(2))
        let expected = Set((7...12).map(String.init))
        while await loader.liveOriginals != expected, ContinuousClock.now < finalDeadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        #expect(await loader.liveOriginals == expected)
        model.cancelAllDownloads()
        try await waitForOriginals([], in: loader)
        #expect(await loader.liveOriginals.isEmpty)
    }

    @Test("Audio downloads only for the selected page and is released when it leaves the buffer or the viewer closes")
    func audioOriginalsFollowBuffer() async throws {
        var items = bufferItems()
        for index in items.indices { items[index].classFile = NKTypeClassFile.audio.rawValue }
        let loader = NCMediaViewerTestLoader(items: items)
        let model = NCMediaViewerModel(currentMetadata: items[0], ocIds: items.map(\.ocId),
                                       account: items[0].account, loader: loader)
        await model.loadSelectedPageIfNeeded()
        try await waitForAudioWithoutFile(1...5, in: model)
        #expect(await loader.originals == ["0"])
        #expect(await loader.downloadCounts.keys.sorted() == ["0"])

        model.finishPageTransition(at: 6)
        await model.loadSelectedPageIfNeeded()
        try await waitForOriginals(["6"], in: loader)
        try await waitForAudioWithoutFile(0...0, in: model)

        model.cancelAllDownloads()
        try await waitForOriginals([], in: loader)
    }

    private func waitForAudioWithoutFile(_ indexes: ClosedRange<Int>, in model: NCMediaViewerModel) async throws {
        func hasNoFile() -> Bool {
            indexes.allSatisfy { index in
                if let page = model.pageModel(at: index), case .downloading = page.state {
                    return true
                }
                return false
            }
        }
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !hasNoFile(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        #expect(hasNoFile())
    }

    @Test("The common loader validates and reuses originals through injected services")
    func commonLoaderUsesHostStorageAndDownloads() async throws {
        var item = imageMetadata(fileName: "audio.mp3")
        item.ocId = "audio"
        item.classFile = NKTypeClassFile.audio.rawValue
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let services = NCMediaViewerTestLoader(items: [item], storageDirectory: directory)
        let loader = NCMediaViewerLoader(services: services)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = URL(fileURLWithPath: services.originalPath(for: item))
        try Data().write(to: url)
        #expect(await loader.localMediaURL(for: item) == nil)
        // The empty placeholder required by the File Provider extension is preserved.
        #expect(fileSize(at: url) == 0)
        #expect(try await loader.downloadMedia(for: item) == url)
        #expect(try await loader.downloadMedia(for: item) == url)
        #expect(await services.downloadCounts[item.ocId] == 1)
        await loader.releaseOriginal(for: item, includingOriginal: true, includingLivePhotoCompanion: true)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test("The common loader resolves and releases a Live Photo companion through host services")
    func commonLoaderUsesHostLivePhotoCompanion() async throws {
        var image = imageMetadata(fileName: "photo.heic")
        image.ocId = "photo"
        image.livePhotoFile = "movie"
        var movie = imageMetadata(fileName: "photo.mov")
        movie.ocId = "movie"
        movie.classFile = NKTypeClassFile.video.rawValue
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let services = NCMediaViewerTestLoader(items: [image, movie], storageDirectory: directory)
        let loader = NCMediaViewerLoader(services: services)
        let url = await loader.downloadLivePhotoMedia(for: image)
        #expect(url == URL(fileURLWithPath: services.originalPath(for: movie)))
        #expect(await services.downloadCounts[movie.ocId] == 1)
        #expect(await services.downloadCounts[image.ocId] == nil)
        let preview = URL(fileURLWithPath: services.previewPath(for: image, ext: "jpg"))
        try Data([1]).write(to: preview)
        await loader.releaseOriginal(for: image, includingOriginal: true, includingLivePhotoCompanion: true)
        #expect(await loader.localLivePhotoURL(for: image) == nil)
        #expect(FileManager.default.fileExists(atPath: preview.path))
    }

    @Test("SVG originals are kept, while undecodable raster originals are still discarded")
    func commonLoaderKeepsSVGOriginals() async throws {
        var svg = imageMetadata(fileName: "drawing.SVG")
        svg.ocId = "drawing"
        var jpg = imageMetadata(fileName: "photo.jpg")
        jpg.ocId = "photo"
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let services = NCMediaViewerTestLoader(items: [svg, jpg], storageDirectory: directory)
        let loader = NCMediaViewerLoader(services: services)

        let svgURL = URL(fileURLWithPath: services.originalPath(for: svg))
        #expect(try await loader.downloadMedia(for: svg) == svgURL)
        #expect(FileManager.default.fileExists(atPath: svgURL.path))
        #expect(await loader.localMediaURL(for: svg) == svgURL)
        #expect(await services.downloadCounts[svg.ocId] == 1)

        let jpgURL = URL(fileURLWithPath: services.originalPath(for: jpg))
        try Data([1]).write(to: jpgURL)
        #expect(await loader.localMediaURL(for: jpg) == nil)
        // The undecodable content is discarded, leaving the File Provider placeholder.
        #expect(fileSize(at: jpgURL) == 0)
    }

    @Test("On metered networks neighbors keep previews and only the selected page downloads its original")
    func meteredNetworkKeepsNeighborPreviews() async throws {
        let items = bufferItems()
        let loader = NCMediaViewerTestLoader(items: items)
        let policy = NCMediaViewerLoadingPolicy(
            automaticallyDownloadsOriginalImages: true,
            automaticallyDownloadsLivePhotoResources: true,
            allowsNeighborOriginalDownloads: { false }
        )
        let model = NCMediaViewerModel(currentMetadata: items[0], ocIds: items.map(\.ocId),
                                       account: items[0].account, loader: loader, loadingPolicy: policy)
        await model.loadSelectedPageIfNeeded()
        try await waitForPreviewOnlyPages(1...5, in: model)
        #expect(await loader.originals == ["0"])

        model.finishPageTransition(at: 1)
        await model.loadSelectedPageIfNeeded()
        try await waitForOriginals(["0", "1"], in: loader)
        try await waitForPreviewOnlyPages(2...6, in: model)
        #expect(await loader.originals == ["0", "1"])
        model.cancelAllDownloads()
    }

    private func waitForPreviewOnlyPages(_ indexes: ClosedRange<Int>, in model: NCMediaViewerModel) async throws {
        func showsPreviewOnly() -> Bool {
            indexes.allSatisfy { index in
                if let page = model.pageModel(at: index), case .image(.some, nil, _, _) = page.state {
                    return true
                }
                return false
            }
        }
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !showsPreviewOnly(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        #expect(showsPreviewOnly())
    }

    @Test("A data-source refresh keeps the page unless the file itself changed")
    func refreshKeepsUnchangedPage() async throws {
        let items = bufferItems()
        let loader = NCMediaViewerTestLoader(items: items)
        let model = NCMediaViewerModel(currentMetadata: items[0], ocIds: items.map(\.ocId),
                                       account: items[0].account, loader: loader)
        await model.loadSelectedPageIfNeeded()
        guard let page = model.pageModel(at: 0), case .image(_, .some, _, _) = page.state else {
            Issue.record("The selected image must show its original")
            return
        }
        // Only a full page reload bumps the thumbnail revision; neighbor prefetch does not.
        let reloadRevision = model.thumbnailReloadRevision

        await model.refreshPage(index: 0)
        #expect(model.thumbnailReloadRevision == reloadRevision)
        if case .image(_, .some, _, _) = page.state { } else {
            Issue.record("An unchanged file must keep its loaded original")
        }

        var renamed = items[0]
        renamed.fileName = "renamed.jpg"
        renamed.fileNameView = "renamed.jpg"
        await loader.updateItem(renamed)
        await model.refreshPage(index: 0)
        #expect(model.thumbnailReloadRevision > reloadRevision)
        #expect(page.metadata?.fileNameView == "renamed.jpg")
        model.cancelAllDownloads()
    }

    @Test("Originals that were already local before the viewer opened are never released")
    func preexistingOriginalsAreKept() async throws {
        let items = bufferItems()
        let loader = NCMediaViewerTestLoader(items: items)
        await loader.addLocalOriginals(["0", "1"])
        let model = NCMediaViewerModel(currentMetadata: items[0], ocIds: items.map(\.ocId),
                                       account: items[0].account, loader: loader)
        await model.loadSelectedPageIfNeeded()
        try await waitForOriginals(Set((0...5).map(String.init)), in: loader)
        #expect(await loader.downloadCounts["0"] == nil)
        #expect(await loader.downloadCounts["1"] == nil)

        model.cancelAllDownloads()
        try await waitForOriginals(["0", "1"], in: loader)
    }

    @Test("A Live Photo whose image was already local releases only the companion the viewer downloaded")
    func preexistingLivePhotoImageKeepsImage() async throws {
        var items = bufferItems()
        items[0].livePhotoFile = "0.mov"
        let loader = NCMediaViewerTestLoader(items: items)
        await loader.addLocalOriginals(["0"])
        let model = NCMediaViewerModel(currentMetadata: items[0], ocIds: items.map(\.ocId),
                                       account: items[0].account, loader: loader)
        await model.loadSelectedPageIfNeeded()
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !(await loader.liveOriginals.contains("0")), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        try #require(await loader.liveOriginals.contains("0"))

        model.cancelAllDownloads()
        try await waitForOriginals(["0"], in: loader)
        let releaseDeadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !(await loader.liveOriginals.isEmpty), ContinuousClock.now < releaseDeadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        #expect(await loader.liveOriginals.isEmpty)
    }

    private func fileSize(at url: URL) -> Int64? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value
    }

    private func bufferItems() -> [NCMediaViewerItem] {
        let account = UUID().uuidString
        return (0..<13).map { index in
            var item = imageMetadata(fileName: "\(index).jpg")
            item.ocId = String(index)
            item.account = account
            return item
        }
    }

    private func waitForOriginals(_ expected: Set<String>, in loader: NCMediaViewerTestLoader) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while await loader.originals != expected, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        #expect(await loader.originals == expected)
    }

    private func makeViewerModel() -> NCMediaViewerModel {
        var metadata = NCMediaViewerItem()
        metadata.ocId = "first"

        return NCMediaViewerModel(
            currentMetadata: metadata,
            ocIds: ["first", "second", "third"],
            account: "",
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
