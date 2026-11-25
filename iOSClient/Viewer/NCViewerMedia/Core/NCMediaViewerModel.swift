// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftUI
import NextcloudKit

// MARK: - Page State

enum NCMediaViewerPageState {
    case idle
    case metadataMissing
    case image(previewURL: URL?, localURL: URL?, livePhotoURL: URL?, progress: Double?)
    case audio(localURL: URL, previewURL: URL?)
    case video(localURL: URL?, previewURL: URL?)
    case downloading(previewURL: URL?, progress: Double?)
    case ready(localURL: URL, previewURL: URL?)
    case deleted
    case failed(previewURL: URL?, message: String)
}

// MARK: - Page Model

@MainActor
final class NCMediaViewerPageModel: ObservableObject, Identifiable {
    let id: String
    let index: Int
    let ocId: String

    @Published var metadata: NCMediaViewerItem?
    @Published var state: NCMediaViewerPageState
    var imageZoomState: NCImageZoomView.ZoomState?

    init(index: Int, ocId: String, metadata: NCMediaViewerItem? = nil, state: NCMediaViewerPageState = .idle) {
        self.id = ocId
        self.index = index
        self.ocId = ocId
        self.metadata = metadata
        self.state = state
    }
}

// MARK: - Initial Model

struct NCMediaViewerInitialModel {
    let currentMetadata: NCMediaViewerItem
    let ocIds: [String]

    init(currentMetadata: NCMediaViewerItem, ocIds: [String]) {
        self.currentMetadata = currentMetadata
        self.ocIds = ocIds
    }

    var normalizedOcIds: [String] {
        let candidates: [String]

        if ocIds.contains(currentMetadata.ocId) {
            candidates = ocIds
        } else {
            candidates = [currentMetadata.ocId] + ocIds
        }

        // Search and grouped data sources can expose the same item in more
        // than one section. A media item must still have only one viewer page.
        var seenOcIds = Set<String>()
        return candidates.filter { seenOcIds.insert($0).inserted }
    }

    var currentSelectedIndex: Int {
        normalizedOcIds.firstIndex(of: currentMetadata.ocId) ?? 0
    }
}

// MARK: - Loading Task Kind

private enum NCMediaViewerLoadingTaskKind {
    case selected
    case prefetch
}

// MARK: - Loading Task

private struct NCMediaViewerLoadingTask {
    let identifier: UUID
    let kind: NCMediaViewerLoadingTaskKind
    let task: Task<Void, Never>
}

// MARK: - Media Viewer Model

// Coordinates media paging, loading, and prefetching.
@MainActor
final class NCMediaViewerModel: ObservableObject {
    enum PageTransition: Equatable {
        case idle
        case interactive
        case programmatic(targetIndex: Int)

        var isIdle: Bool {
            self == .idle
        }

        var isProgrammatic: Bool {
            if case .programmatic = self {
                return true
            }

            return false
        }
    }

    // MARK: - Published State

    @Published private(set) var selectedIndex: Int
    @Published private(set) var pageTransition = PageTransition.idle
    @Published private(set) var revision: Int = 0
    @Published private(set) var thumbnailReloadRevision: Int = 0
    @Published private(set) var isChromeHidden = false
    @Published private(set) var autoPlayTargetIndex: Int?

    let playbackOptions = NCMediaPlaybackOptions()

    // MARK: - Dependencies

    let loader: NCMediaViewerLoading
    private let loadingPolicy: NCMediaViewerLoadingPolicy

    // MARK: - Source Context

    private let account: String
    let playbackProgressTint: @MainActor (String) -> Color

    // MARK: - Source Data

    private let ocIds: [String]

    // MARK: - Page Cache

    // Lazy page cache keyed by ocId.
    private var cachedPagesByOcId: [String: NCMediaViewerPageModel] = [:]

    // MARK: - Running Tasks

    private var loadingTasksByOcId: [String: NCMediaViewerLoadingTask] = [:]
    private var bufferedOcIds = Set<String>()
    // Also serialize a quick close/reopen against the previous viewer's pending removals.
    private static var releasingImagesByAccount: [String: [String: Task<Void, Never>]] = [:]
    private var isClosed = false
    private var previewSelectionID: UUID?
    private var thumbnailScrubID: UUID?

    // MARK: - Public Read-Only Access

    var numberOfPages: Int {
        ocIds.count
    }

    var currentSelectedIndex: Int {
        selectedIndex
    }

    var activePageIndex: Int? {
        pageTransition.isIdle ? selectedIndex : nil
    }

    var selectedOcId: String? {
        guard ocIds.indices.contains(selectedIndex) else {
            return nil
        }

        return ocIds[selectedIndex]
    }

    var selectedMetadata: NCMediaViewerItem? {
        guard ocIds.indices.contains(selectedIndex) else {
            return nil
        }

        let ocId = ocIds[selectedIndex]
        return cachedPagesByOcId[ocId]?.metadata
    }

    func ocId(at index: Int) -> String? {
        guard ocIds.indices.contains(index) else {
            return nil
        }

        return ocIds[index]
    }

    func metadataForThumbnail(at index: Int) -> NCMediaViewerItem? {
        guard let ocId = ocId(at: index) else {
            return nil
        }

        return cachedPagesByOcId[ocId]?.metadata
    }

    func clearAutoPlayIfNeeded(for index: Int) {
        guard autoPlayTargetIndex == index else {
            return
        }

        setAutoPlayTargetIndex(nil)
    }

    private func setAutoPlayTargetIndex(_ index: Int?) {
        guard autoPlayTargetIndex != index else {
            return
        }

        autoPlayTargetIndex = index
    }

    /// Deactivates media content while the collection view moves between pages.
    /// The target becomes active only after the paging animation settles.
    func beginPageTransition(to targetIndex: Int?, shouldAutoPlay: Bool) {
        if let targetIndex,
           !ocIds.indices.contains(targetIndex) {
            return
        }

        if let targetIndex {
            pageTransition = .programmatic(targetIndex: targetIndex)
        } else {
            pageTransition = .interactive
        }

        setAutoPlayTargetIndex(shouldAutoPlay ? targetIndex : nil)
    }

    /// Updates the visible selection during an interactive transition without
    /// activating media playback on an intermediate page.
    func updateSelectedIndexDuringTransition(_ index: Int) {
        guard ocIds.indices.contains(index) else {
            return
        }

        guard pageTransition == .interactive else {
            return
        }

        guard selectedIndex != index else {
            return
        }

        selectedIndex = index
    }

    /// Commits the page that actually settled after a transition.
    func finishPageTransition(at index: Int) {
        guard ocIds.indices.contains(index) else {
            return
        }

        if selectedIndex != index {
            selectedIndex = index
        }

        if pageTransition != .idle {
            pageTransition = .idle
        }

        if let autoPlayTargetIndex,
           autoPlayTargetIndex != index {
            setAutoPlayTargetIndex(nil)
        }
    }

    @MainActor
    func markPageAsDeleted(ocId: String) {
        // Stop any active playback before marking the page as deleted.
        // This is a destructive state change, so the global playback stop is intentional.
        NotificationCenter.default.post(name: .ncMediaViewerStopPlayback, object: nil)

        updatePage(ocId: ocId) { page in
            page.state = .deleted
        }
    }

    // MARK: - Init

    init(initialModel: NCMediaViewerInitialModel, account: String, loader: NCMediaViewerLoading, loadingPolicy: NCMediaViewerLoadingPolicy = .standard, playbackProgressTint: @escaping @MainActor (String) -> Color = { _ in .accentColor }) {
        let normalizedOcIds = initialModel.normalizedOcIds
        let initialIndex = normalizedOcIds.firstIndex(of: initialModel.currentMetadata.ocId) ?? 0
        self.loader = loader
        self.loadingPolicy = loadingPolicy
        self.account = account
        self.playbackProgressTint = playbackProgressTint
        self.ocIds = normalizedOcIds
        self.selectedIndex = initialIndex

        let currentPage = NCMediaViewerPageModel(
            index: initialIndex,
            ocId: initialModel.currentMetadata.ocId,
            metadata: initialModel.currentMetadata,
            state: .idle
        )

        cachedPagesByOcId[initialModel.currentMetadata.ocId] = currentPage
    }

    convenience init(
        currentMetadata: NCMediaViewerItem,
        ocIds: [String],
        account: String,
        loader: NCMediaViewerLoading,
        loadingPolicy: NCMediaViewerLoadingPolicy = .standard,
        playbackProgressTint: @escaping @MainActor (String) -> Color = { _ in .accentColor }
    ) {
        let initialModel = NCMediaViewerInitialModel(currentMetadata: currentMetadata, ocIds: ocIds)

        self.init(initialModel: initialModel, account: account, loader: loader, loadingPolicy: loadingPolicy, playbackProgressTint: playbackProgressTint)
    }

    deinit {
        loadingTasksByOcId.values.forEach { $0.task.cancel() }
        loadingTasksByOcId.removeAll()
    }

    // MARK: - Public API

    func pageModel(at index: Int) -> NCMediaViewerPageModel? {
        guard ocIds.indices.contains(index) else {
            return nil
        }

        let ocId = ocIds[index]

        if let cachedPage = cachedPagesByOcId[ocId] {
            return cachedPage
        }

        let page = NCMediaViewerPageModel(index: index, ocId: ocId, metadata: nil, state: .idle)

        cachedPagesByOcId[ocId] = page
        return page
    }

    func displayPage(at index: Int) async {
        guard ocIds.indices.contains(index),
              selectedIndex == index else {
            return
        }

        prefetchNeighborPages(around: index)

        if let ocId = ocId(at: index),
           !pageNeedsSelectedPageLoading(for: ocId) {
            return
        }

        await loadPageIfNeeded(index: index)
    }

    /// Freeze the original buffer while the thumbnail bar is dragging or decelerating.
    func beginThumbnailScrubbing() {
        guard !isClosed else { return }
        thumbnailScrubID = UUID()
    }

    func endThumbnailScrubbing(at index: Int) async {
        guard let scrubID = thumbnailScrubID, !isClosed else { return }
        // Resolve the final selection before allowing UIKit callbacks to move the buffer.
        await displayPreviewPage(at: index)
        guard thumbnailScrubID == scrubID, !isClosed else { return }
        thumbnailScrubID = nil
        await loadSelectedPageIfNeeded()
    }

    func displayPreviewPage(at index: Int) async {
        guard !isClosed, ocIds.indices.contains(index) else {
            return
        }

        // Thumbnail scrubbing can issue several selections before metadata resolves.
        // Even selecting the current page supersedes an older pending request.
        let selectionID = UUID()
        previewSelectionID = selectionID
        guard selectedIndex != index else {
            finishPageTransition(at: index)
            return
        }

        let sourceIndex = selectedIndex
        let ocId = ocIds[index]
        let targetMetadata = await resolvedMetadata(for: ocId)

        // Keep the source controls until the latest requested target's type is known.
        guard !isClosed, !Task.isCancelled, previewSelectionID == selectionID,
              selectedIndex == sourceIndex else { return }
        if let targetMetadata {
            setThumbnailMetadata(targetMetadata, for: ocId)
        }
        finishPageTransition(at: index)

        guard let metadata = targetMetadata else { return }

        let previewURL: URL?

        if let existingPreviewURL = currentPreviewURL(for: ocId) {
            previewURL = existingPreviewURL
        } else {
            previewURL = await loader.previewURL(for: metadata, ext: NCGlobal.shared.previewExt1024)
        }

        guard let previewURL, !isClosed, !Task.isCancelled,
              previewSelectionID == selectionID, selectedIndex == index else { return }
        if case .image(_, .some, _, _) = pageState(for: ocId) { return }

        switch metadata.classFile {
        case NKTypeClassFile.image.rawValue:
            setState(.image(previewURL: previewURL, localURL: nil, livePhotoURL: nil, progress: nil), for: ocId)

        case NKTypeClassFile.video.rawValue:
            setState(.video(localURL: nil, previewURL: previewURL), for: ocId)

        case NKTypeClassFile.audio.rawValue:
            setState(.downloading(previewURL: previewURL, progress: nil), for: ocId)

        default:
            break
        }
    }

    func selectedPageModel() -> NCMediaViewerPageModel? {
        pageModel(at: selectedIndex)
    }

    func loadSelectedPageIfNeeded() async {
        prefetchNeighborPages(around: selectedIndex)
        await loadPageIfNeeded(index: selectedIndex)
    }

    func loadPageIfNeeded(index: Int) async {
        guard ocIds.indices.contains(index) else {
            return
        }

        let ocId = ocIds[index]

        guard !isClosed, thumbnailScrubID == nil else { return }
        if let release = Self.releasingImagesByAccount[account]?[ocId] { await release.value }
        guard !isClosed, thumbnailScrubID == nil, !Task.isCancelled, bufferedOcIds.contains(ocId) else { return }

        if let loading = loadingTasksByOcId[ocId] {
            await loading.task.value
            clearLoadingTaskIfCurrent(ocId: ocId, identifier: loading.identifier)
            if loading.kind == .prefetch {
                // Audio prefetch may only have prepared artwork; finish selected-page loading.
                await loadPageIfNeeded(index: index)
            }
            return
        }

        guard pageNeedsSelectedPageLoading(for: ocId) else { return }

        let identifier = UUID()

        let task = Task { [weak self] in
            guard let self else {
                return
            }

            await self.loadPage(index: index)
        }

        loadingTasksByOcId[ocId] = NCMediaViewerLoadingTask(identifier: identifier, kind: .selected, task: task)

        await task.value

        clearLoadingTaskIfCurrent(ocId: ocId, identifier: identifier)
    }

    /// Reloads the page from the beginning, forcing a fresh metadata resolution before rebuilding the preview and media state.
    /// - Parameter index: The index of the page that must be reloaded.
    func reloadPage(index: Int) async {
        guard ocIds.indices.contains(index) else {
            return
        }

        let ocId = ocIds[index]

        guard !isClosed, thumbnailScrubID == nil, bufferedOcIds.contains(ocId) else { return }
        if let loading = loadingTasksByOcId[ocId] {
            await loading.task.value
            clearLoadingTaskIfCurrent(ocId: ocId, identifier: loading.identifier)
        }
        guard !isClosed, thumbnailScrubID == nil, bufferedOcIds.contains(ocId), !Task.isCancelled else { return }

        updatePage(ocId: ocId) { page in
            page.metadata = nil
            page.state = .idle
        }

        thumbnailReloadRevision &+= 1

        await loadPageIfNeeded(index: index)
    }

    func cancelAllDownloads() {
        guard !isClosed else { return }
        isClosed = true
        let previousBuffer = bufferedOcIds
        bufferedOcIds.removeAll()
        for ocId in previousBuffer { releaseBufferedImage(ocId: ocId) }
        Task { await loader.cancelAllDownloads() }
    }

    func downloadVideoForPlayback(_ metadata: NCMediaViewerItem) async throws -> URL {
        try await loader.downloadMedia(for: metadata, onDownloadStarted: nil)
    }

    @discardableResult
    func downloadOriginalImage(for metadata: NCMediaViewerItem, onDownloadStarted: (@MainActor @Sendable () -> Void)? = nil) async throws -> URL {
        guard !isClosed, let index = ocIds.firstIndex(of: metadata.ocId) else { throw CancellationError() }
        if await loader.localMediaURL(for: metadata) == nil { onDownloadStarted?() }
        await loadPageIfNeeded(index: index)
        guard !isClosed, !Task.isCancelled, bufferedOcIds.contains(metadata.ocId),
              let localURL = await loader.localMediaURL(for: metadata) else {
            throw CancellationError()
        }
        return localURL
    }

    func downloadLivePhotoResources(for metadata: NCMediaViewerItem) async -> (imageURL: URL, videoURL: URL)? {
        guard metadata.isLivePhoto else {
            return nil
        }

        do {
            let imageURL = try await downloadOriginalImage(for: metadata)

            guard !Task.isCancelled,
                  let videoURL = await loader.localLivePhotoURL(for: metadata),
                  !Task.isCancelled, !isClosed, bufferedOcIds.contains(metadata.ocId) else {
                return nil
            }

            setState(.image(previewURL: currentPreviewURL(for: metadata.ocId), localURL: imageURL, livePhotoURL: videoURL, progress: nil), for: metadata.ocId)

            return (imageURL, videoURL)
        } catch {
            return nil
        }
    }

    func cancelVideoDownload(for ocId: String) async {
        await loader.cancelDownload(for: ocId)
    }

    func prefetchVisiblePageIfNeeded(index: Int) async {
        guard ocIds.indices.contains(index) else {
            return
        }

        guard index == selectedIndex else { return }
        prefetchNeighborPages(around: index)
        await prefetchPageIfNeeded(index: index)
    }

    func toggleChromeVisibility() {
        isChromeHidden.toggle()
    }

    func setChromeHidden(_ isHidden: Bool) {
        guard isChromeHidden != isHidden else {
            return
        }

        isChromeHidden = isHidden
    }

    func previewURL(for metadata: NCMediaViewerItem, ext: String) async -> URL? {
        await loader.previewURL(for: metadata, ext: ext)
    }

    func resolveMetadataForThumbnail(at index: Int) async -> NCMediaViewerItem? {
        guard let ocId = ocId(at: index) else {
            return nil
        }

        if let existingMetadata = cachedPagesByOcId[ocId]?.metadata {
            return existingMetadata
        }

        guard let metadata = await resolvedMetadata(for: ocId) else {
            return nil
        }

        setThumbnailMetadata(metadata, for: ocId)

        return metadata
    }

    func nextMediaIndex(after index: Int, matchingClassFile classFile: String) async -> Int? {
        guard ocIds.indices.contains(index),
              index < ocIds.index(before: ocIds.endIndex) else {
            return nil
        }

        let sourceOcId = ocIds[index]

        for candidateIndex in ocIds.index(after: index)..<ocIds.endIndex {
            guard !Task.isCancelled else {
                return nil
            }

            guard ocIds[candidateIndex] != sourceOcId,
                  !isThumbnailDeleted(at: candidateIndex),
                  let metadata = await resolveMetadataForThumbnail(at: candidateIndex) else {
                continue
            }

            if metadata.classFile == classFile {
                return candidateIndex
            }
        }

        return nil
    }

    func isThumbnailDeleted(at index: Int) -> Bool {
        guard let ocId = ocId(at: index),
              let page = cachedPagesByOcId[ocId] else {
            return false
        }

        if case .deleted = page.state {
            return true
        }

        return false
    }

    // MARK: - Selected Page Loading

    private func loadPage(index: Int) async {
        guard ocIds.indices.contains(index) else {
            return
        }

        let ocId = ocIds[index]
        let metadata = await preparedMetadata(for: ocId)
        guard !Task.isCancelled else { return }
        guard let metadata else {
            setState(.metadataMissing, for: ocId)
            return
        }

        let previewURL = currentPreviewURL(for: ocId)

        if let localURL = await loader.localMediaURL(for: metadata) {
            guard !Task.isCancelled else {
                return
            }

            await loadLocalPage(metadata: metadata, previewURL: previewURL, localURL: localURL, for: ocId, index: index)
            return
        }

        guard !Task.isCancelled else {
            return
        }

        await loadRemotePage(metadata: metadata, previewURL: previewURL, for: ocId, index: index)
    }

    private func loadLocalPage(metadata: NCMediaViewerItem, previewURL: URL?, localURL: URL, for ocId: String, index: Int) async {
        var previewURL = previewURL
        if previewURL == nil,
           metadata.classFile == NKTypeClassFile.image.rawValue || metadata.classFile == NKTypeClassFile.video.rawValue {
            previewURL = await loader.previewURL(for: metadata, ext: NCGlobal.shared.previewExt1024)
            guard !Task.isCancelled else { return }
        }

        await setReadyState(metadata: metadata, previewURL: previewURL, localURL: localURL, for: ocId, index: index)
        if metadata.classFile == NKTypeClassFile.audio.rawValue {
            await loadAudioPreviewIfNeeded(metadata: metadata, localURL: localURL, currentPreviewURL: previewURL, for: ocId, index: index)
        }
    }

    private func loadRemotePage(metadata: NCMediaViewerItem, previewURL: URL?, for ocId: String, index: Int) async {
        var previewURL = previewURL

        if previewURL == nil,
           shouldLoadPreview(for: metadata) {
            previewURL = await loader.previewURL(for: metadata, ext: NCGlobal.shared.previewExt1024)
        }

        guard !Task.isCancelled else {
            return
        }

        switch metadata.classFile {
        case NKTypeClassFile.video.rawValue:
            setState(.video(localURL: nil, previewURL: previewURL), for: ocId)
            return

        case NKTypeClassFile.image.rawValue:
            if let previewURL {
                setState(.image(previewURL: previewURL, localURL: nil, livePhotoURL: nil, progress: nil), for: ocId)
            }

            guard loadingPolicy.shouldDownloadOriginalImage(for: metadata, hasUsablePreview: previewURL != nil) else {
                return
            }

        case NKTypeClassFile.audio.rawValue:
            setState(.downloading(previewURL: previewURL, progress: nil), for: ocId)

        default:
            break
        }

        guard thumbnailScrubID == nil else { return }
        do {
            let downloadedURL = try await loader.downloadMedia(for: metadata, onDownloadStarted: nil)

            guard !Task.isCancelled else {
                return
            }

            await setReadyState(metadata: metadata, previewURL: previewURL, localURL: downloadedURL, for: ocId, index: index)

            if metadata.classFile == NKTypeClassFile.audio.rawValue {
                await loadAudioPreviewIfNeeded(metadata: metadata, localURL: downloadedURL, currentPreviewURL: previewURL, for: ocId, index: index)
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            if metadata.classFile == NKTypeClassFile.image.rawValue,
               let previewURL {
                setState(.image(previewURL: previewURL, localURL: nil, livePhotoURL: nil, progress: nil), for: ocId)
            } else {
                setState(.failed(previewURL: previewURL, message: ""), for: ocId)
            }
        }
    }

    // MARK: - Prefetch

    private func prefetchNeighborPages(around index: Int) {
        guard !isClosed, thumbnailScrubID == nil, ocIds.indices.contains(index) else { return }
        let prefetchRadius = 5
        let indexes = (max(0, index - prefetchRadius)...min(ocIds.count - 1, index + prefetchRadius))
        let nextBuffer = Set(indexes.map { ocIds[$0] })
        let evicted = bufferedOcIds.subtracting(nextBuffer)
        bufferedOcIds = nextBuffer
        for ocId in evicted { releaseBufferedImage(ocId: ocId) }
        let neighborIndexes = indexes.filter { $0 != index }

        for neighborIndex in neighborIndexes {
            Task { [weak self] in
                guard let self else {
                    return
                }

                await self.prefetchPageIfNeeded(index: neighborIndex)
            }
        }
    }

    private func prefetchPageIfNeeded(index: Int) async {
        guard ocIds.indices.contains(index) else {
            return
        }

        let ocId = ocIds[index]

        if let release = Self.releasingImagesByAccount[account]?[ocId] { await release.value }
        guard !isClosed, thumbnailScrubID == nil, bufferedOcIds.contains(ocId), !Task.isCancelled else { return }
        // On metered networks, neighbors that already show a preview wait for selection or an unmetered network.
        guard pageState(for: ocId).isIdle ||
                (loadingPolicy.allowsNeighborOriginalDownloads() &&
                 cachedPagesByOcId[ocId]?.metadata?.classFile == NKTypeClassFile.image.rawValue && pageNeedsSelectedPageLoading(for: ocId)) else { return }
        guard loadingTasksByOcId[ocId] == nil else { return }

        let identifier = UUID()

        let task = Task { [weak self] in
            guard let self else {
                return
            }

            await self.loadPageForPrefetch(index: index)
        }

        loadingTasksByOcId[ocId] = NCMediaViewerLoadingTask(identifier: identifier, kind: .prefetch, task: task)

        await task.value

        clearLoadingTaskIfCurrent(ocId: ocId, identifier: identifier)
    }

    private func loadPageForPrefetch(index: Int) async {
        guard ocIds.indices.contains(index) else {
            return
        }

        let ocId = ocIds[index]
        guard let metadata = await preparedMetadata(for: ocId), !Task.isCancelled else { return }

        let previewURL: URL?

        if shouldLoadPreview(for: metadata) {
            previewURL = await loader.previewURL(for: metadata, ext: NCGlobal.shared.previewExt1024)
        } else {
            previewURL = nil
        }

        guard !Task.isCancelled else {
            return
        }

        guard shouldLoadPreview(for: metadata) else { return }
        let localURL = await loader.localMediaURL(for: metadata)
        guard !Task.isCancelled else { return }

        switch metadata.classFile {
        case NKTypeClassFile.image.rawValue:
            let allowsOriginalDownloads = loadingPolicy.allowsNeighborOriginalDownloads()
            if let localURL {
                await setReadyState(metadata: metadata, previewURL: previewURL, localURL: localURL, for: ocId, index: index,
                                    downloadsLivePhotoCompanion: allowsOriginalDownloads)
            } else if allowsOriginalDownloads {
                await loadRemotePage(metadata: metadata, previewURL: previewURL, for: ocId, index: index)
            } else if let previewURL {
                // Metered network: keep the preview; the original downloads once this page is selected.
                setState(.image(previewURL: previewURL, localURL: nil, livePhotoURL: nil, progress: nil), for: ocId)
            }
        case NKTypeClassFile.video.rawValue:
            setState(.video(localURL: localURL, previewURL: previewURL), for: ocId)
        case NKTypeClassFile.audio.rawValue:
            guard let localURL else {
                setState(.downloading(previewURL: previewURL, progress: nil), for: ocId)
                return
            }
            setState(.audio(localURL: localURL, previewURL: previewURL), for: ocId)
            await loadAudioPreviewIfNeeded(metadata: metadata, localURL: localURL, currentPreviewURL: previewURL, for: ocId, index: index)
        default:
            break
        }
    }

    /// Await the old download before removing its file. Re-entry waits for this task too.
    /// Images (with Live Photo companions) and audio follow the buffer; video keeps its own rules.
    private func releaseBufferedImage(ocId: String) {
        guard Self.releasingImagesByAccount[account]?[ocId] == nil else { return }
        if let metadata = cachedPagesByOcId[ocId]?.metadata,
           !Self.followsOriginalBuffer(metadata) { return }
        let loading = loadingTasksByOcId.removeValue(forKey: ocId)
        loading?.task.cancel()
        Self.releasingImagesByAccount[account, default: [:]][ocId] = Task {
            await loader.cancelDownload(for: ocId)
            if let metadata = cachedPagesByOcId[ocId]?.metadata, metadata.isLivePhoto {
                await loader.cancelLivePhotoMediaDownload(for: metadata)
            }
            await loading?.task.value
            defer {
                Self.releasingImagesByAccount[account]?[ocId] = nil
                if Self.releasingImagesByAccount[account]?.isEmpty == true {
                    Self.releasingImagesByAccount[account] = nil
                }
            }
            guard !bufferedOcIds.contains(ocId),
                  let metadata = cachedPagesByOcId[ocId]?.metadata,
                  Self.followsOriginalBuffer(metadata) else { return }
            if case .deleted = pageState(for: ocId) {
                // Keep the deleted placeholder.
            } else {
                let previewURL = currentPreviewURL(for: ocId)
                updatePage(ocId: ocId) { page in
                    page.imageZoomState = nil
                    if metadata.classFile == NKTypeClassFile.audio.rawValue {
                        // Selecting the page again downloads the audio file.
                        page.state = .downloading(previewURL: previewURL, progress: nil)
                    } else {
                        page.state = .image(previewURL: previewURL, localURL: nil, livePhotoURL: nil, progress: nil)
                    }
                }
            }
            await loader.releaseOriginalImage(for: metadata)
        }
    }

    private static func followsOriginalBuffer(_ metadata: NCMediaViewerItem) -> Bool {
        metadata.classFile == NKTypeClassFile.image.rawValue || metadata.classFile == NKTypeClassFile.audio.rawValue
    }

    // MARK: - Page Updates

    /// Resolves the item and hydrates image placeholders before publishing it to the page.
    private func preparedMetadata(for ocId: String) async -> NCMediaViewerItem? {
        let metadata = await resolvedMetadata(for: ocId)
        guard !Task.isCancelled, var metadata else { return nil }
        if metadata.classFile == NKTypeClassFile.image.rawValue {
            metadata = await loader.metadataForDetails(for: metadata)
            guard !Task.isCancelled else { return nil }
        }
        setMetadata(metadata, for: ocId)
        return metadata
    }

    private func resolvedMetadata(for ocId: String) async -> NCMediaViewerItem? {
        if let existingMetadata = cachedPagesByOcId[ocId]?.metadata {
            return existingMetadata
        }

        return await loader.metadata(for: ocId, account: account)
    }

    private func pageState(for ocId: String) -> NCMediaViewerPageState {
        cachedPagesByOcId[ocId]?.state ?? .idle
    }

    private func pageNeedsSelectedPageLoading(for ocId: String) -> Bool {
        let state = pageState(for: ocId)

        switch state {
        case .idle,
             .downloading:
            return true

        case .image(let previewURL, nil, _, _):
            guard let metadata = cachedPagesByOcId[ocId]?.metadata else {
                return true
            }

            return loadingPolicy.shouldDownloadOriginalImage(for: metadata, hasUsablePreview: previewURL != nil)

        case .video(nil, nil):
            return true

        case .image(_, .some, nil, _):
            guard let metadata = cachedPagesByOcId[ocId]?.metadata else { return false }
            return loadingPolicy.shouldDownloadLivePhotoResources(for: metadata)

        case .image(_, .some, .some, _),
             .audio,
             .video,
             .metadataMissing,
             .ready,
             .deleted,
             .failed:
            return false
        }
    }

    private func currentPreviewURL(for ocId: String) -> URL? {
        guard let page = cachedPagesByOcId[ocId] else {
            return nil
        }

        switch page.state {
        case .image(let previewURL, _, _, _):
            return previewURL

        case .downloading(let previewURL, _):
            return previewURL

        case .audio(_, let previewURL),
             .video(_, let previewURL),
             .ready(_, let previewURL),
             .failed(let previewURL, _):
            return previewURL

        case .idle,
             .metadataMissing,
             .deleted:
            return nil
        }
    }

    private func shouldLoadPreview(for metadata: NCMediaViewerItem) -> Bool {
        switch metadata.classFile {
        case NKTypeClassFile.image.rawValue,
             NKTypeClassFile.audio.rawValue,
             NKTypeClassFile.video.rawValue:
            return true

        default:
            return false
        }
    }

    private func setMetadata(_ metadata: NCMediaViewerItem, for ocId: String) {
        updatePage(ocId: ocId) { page in
            page.metadata = metadata
        }
    }

    private func setState(_ state: NCMediaViewerPageState, for ocId: String) {
        updatePage(ocId: ocId) { page in
            page.state = state
        }
    }

    private func setReadyState(metadata: NCMediaViewerItem, previewURL: URL?, localURL: URL, for ocId: String, index: Int, downloadsLivePhotoCompanion: Bool = true) async {
        if metadata.classFile == NKTypeClassFile.image.rawValue {
            var livePhotoURL: URL?

            guard !Task.isCancelled, !isClosed, bufferedOcIds.contains(ocId) else { return }
            // Display HD immediately while the companion video is being prepared.
            setState(.image(previewURL: previewURL, localURL: localURL, livePhotoURL: nil, progress: nil), for: ocId)
            if metadata.isLivePhoto {
                livePhotoURL = await loader.localLivePhotoURL(for: metadata)

                if livePhotoURL == nil, downloadsLivePhotoCompanion, !Task.isCancelled, thumbnailScrubID == nil,
                   loadingPolicy.shouldDownloadLivePhotoResources(for: metadata) {
                    livePhotoURL = await loader.downloadLivePhotoMedia(for: metadata)
                }
            } else {
                livePhotoURL = nil
            }

            guard !Task.isCancelled, !isClosed, bufferedOcIds.contains(ocId) else { return }
            setState(.image(previewURL: previewURL, localURL: localURL, livePhotoURL: livePhotoURL, progress: nil), for: ocId)
        } else if metadata.classFile == NKTypeClassFile.video.rawValue {
            setState(.video(localURL: localURL, previewURL: previewURL), for: ocId)
        } else if metadata.classFile == NKTypeClassFile.audio.rawValue {
            setState(.audio(localURL: localURL, previewURL: previewURL), for: ocId)
        } else {
            setState(.ready(localURL: localURL, previewURL: previewURL), for: ocId)
        }
    }

    private func loadAudioPreviewIfNeeded(metadata: NCMediaViewerItem, localURL: URL, currentPreviewURL: URL?, for ocId: String, index: Int) async {
        guard currentPreviewURL == nil else {
            return
        }

        let previewURL = await loader.previewURL(for: metadata, ext: NCGlobal.shared.previewExt1024)

        guard !Task.isCancelled,
              let previewURL else {
            return
        }

        guard case .audio(let readyLocalURL, _) = pageState(for: ocId),
              readyLocalURL == localURL else {
            return
        }

        setState(.audio(localURL: localURL, previewURL: previewURL), for: ocId)
    }

    private func updatePage(ocId: String, publishRevision: Bool = true, mutation: (NCMediaViewerPageModel) -> Void) {
        let page: NCMediaViewerPageModel

        if let cachedPage = cachedPagesByOcId[ocId] {
            page = cachedPage
        } else {
            guard let index = ocIds.firstIndex(of: ocId) else {
                return
            }
            page = NCMediaViewerPageModel(index: index, ocId: ocId, metadata: nil, state: .idle)

            cachedPagesByOcId[ocId] = page
        }

        mutation(page)

        if publishRevision {
            revision &+= 1
        }
    }

    private func setThumbnailMetadata(_ metadata: NCMediaViewerItem, for ocId: String) {
        updatePage(ocId: ocId, publishRevision: false) { page in
            page.metadata = metadata
        }
    }

    private func clearLoadingTaskIfCurrent(ocId: String, identifier: UUID) {
        guard loadingTasksByOcId[ocId]?.identifier == identifier else {
            return
        }

        loadingTasksByOcId[ocId] = nil
    }
}

// MARK: - NCMediaViewerPageState Helpers

private extension NCMediaViewerPageState {
    var isIdle: Bool {
        switch self {
        case .idle:
            return true

        case .metadataMissing,
             .image,
             .audio,
             .video,
             .downloading,
             .ready,
             .deleted,
             .failed:
            return false
        }
    }

}
