// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

// MARK: - Page State

/// Represents the loading state of a media viewer page.
///
/// The page metadata is stored in `NCMediaViewerPageModel.metadata`.
/// This state only describes the current loading/rendering phase.
enum NCMediaViewerPageState {
    /// The page exists but no loading operation has started yet.
    case idle

    /// The page is resolving its `tableMetadata` from `ocId`.
    case loadingMetadata

    /// The metadata could not be found anymore.
    case metadataMissing

    /// Metadata exists and the viewer is checking if the full media file is already local.
    case checkingLocalFile

    /// Image page state.
    ///
    /// The same image view remains mounted while the page moves from preview
    /// to full image. This avoids flickering caused by replacing SwiftUI view branches.
    case image(previewURL: URL?, localURL: URL?, livePhotoURL: URL?, progress: Double?)

    /// Video page state.
    ///
    /// Videos can be played from a local file, metadata URL, or Nextcloud direct
    /// download URL. The video viewer resolves the final playback URL by itself.
    case video(previewURL: URL?)

    /// Remote media state with an optional preview and optional download progress.
    ///
    /// For video/audio, this can also represent a remote-only state where a preview
    /// is available but the full media file has not been downloaded.
    case downloading(previewURL: URL?, progress: Double?)

    /// Non-image media is locally available.
    case ready(localURL: URL, previewURL: URL?)

    case deleted

    /// The page failed while resolving metadata, checking local content, or downloading.
    case failed(previewURL: URL?, message: String)
}

// MARK: - Page Model

/// Represents one page inside the media viewer.
///
/// The model does not create one page for every media item upfront.
/// Pages are created lazily when requested by the UIKit pager.
struct NCMediaViewerPageModel: Identifiable {
    /// Stable identifier used by SwiftUI.
    let id: String

    /// Absolute index inside the full `ocIds` array.
    let index: Int

    /// Nextcloud file identifier.
    let ocId: String

    /// Detached metadata if already available.
    var metadata: tableMetadata?

    /// Current loading state of the page.
    var state: NCMediaViewerPageState

    /// Creates a page model.
    ///
    /// - Parameters:
    ///   - index: Absolute index inside the full `ocIds` array.
    ///   - ocId: Nextcloud file identifier.
    ///   - metadata: Detached metadata if already available.
    ///   - state: Initial page state.
    init(index: Int, ocId: String, metadata: tableMetadata? = nil, state: NCMediaViewerPageState = .idle) {
        self.id = ocId
        self.index = index
        self.ocId = ocId
        self.metadata = metadata
        self.state = state
    }
}

// MARK: - Initial Model

/// Initial model used to open the media viewer.
///
/// The viewer receives:
/// - the current `tableMetadata`
/// - the ordered list of media `ocId` values
///
/// The current metadata must be detached before being passed here.
struct NCMediaViewerInitialModel {
    /// Metadata of the initially opened media.
    let currentMetadata: tableMetadata

    /// Ordered list of all media identifiers.
    let ocIds: [String]

    /// Creates the initial model for the media viewer.
    ///
    /// - Parameters:
    ///   - currentMetadata: Detached metadata of the initially opened media.
    ///   - ocIds: Ordered list of image/audio/video ocIds.
    init(
        currentMetadata: tableMetadata,
        ocIds: [String]
    ) {
        self.currentMetadata = currentMetadata
        self.ocIds = ocIds
    }

    /// Returns the ordered list of page identifiers.
    ///
    /// The current `ocId` is inserted only if missing.
    var normalizedOcIds: [String] {
        if ocIds.contains(currentMetadata.ocId) {
            return ocIds
        } else {
            return [currentMetadata.ocId] + ocIds
        }
    }

    /// Returns the initial selected index.
    ///
    /// If the current `ocId` is not found, the model starts from index zero.
    var initialSelectedIndex: Int {
        normalizedOcIds.firstIndex(of: currentMetadata.ocId) ?? 0
    }
}

// MARK: - Loading Task Kind

/// Describes which loader owns a running page task.
private enum NCMediaViewerLoadingTaskKind {
    /// Task started because the page became selected.
    case selected

    /// Task started by neighbor prefetch.
    case prefetch
}

// MARK: - Loading Task

/// Stores a running media viewer loading task.
///
/// The identifier prevents an old cancelled task from removing a newer task
/// stored under the same `ocId`.
private struct NCMediaViewerLoadingTask {
    let identifier: UUID
    let kind: NCMediaViewerLoadingTaskKind
    let task: Task<Void, Never>
}

// MARK: - Media Viewer Model

/// Model for the media viewer.
///
/// This model is optimized for very large media lists.
/// It stores the full ordered `ocIds` array, but creates page models lazily only
/// when the pager asks for them.
///
/// Responsibilities:
/// - keep the current selected index
/// - expose page count
/// - create page models lazily
/// - resolve metadata lazily
/// - request preview URLs
/// - check local media availability
/// - start full media downloads through the loader only for selected pages
/// - prefetch nearby pages without downloading full media
/// - update page states
///
/// It does not render UI and does not directly access Realm, FileManager,
/// or networking APIs. Those responsibilities belong to `NCMediaViewerLoading`.
@MainActor
final class NCMediaViewerModel: ObservableObject {

    // MARK: - Published State

    /// Currently selected absolute index inside the full `ocIds` array.
    @Published private(set) var selectedIndex: Int

    /// Incremented when a cached page changes.
    ///
    /// The UIKit paging coordinator observes this value and refreshes visible cells.
    @Published private(set) var revision: Int = 0

    /// Whether the viewer chrome is currently hidden.
    ///
    /// When hidden, the navigation bar is hidden and the viewer uses a black
    /// background for a cleaner fullscreen media experience.
    @Published private(set) var isChromeHidden = false

    /// Page index that should auto-start playback after navigation.
    @Published private(set) var autoPlayTargetIndex: Int?

    // MARK: - Dependencies

    private let loader: NCMediaViewerLoading

    // MARK: - Source Context

    /// Session used to resolve account-scoped metadata fallback lookups.
    private let session: NCSession.Session

    private let mediaSearch: Bool

    // MARK: - Source Data

    /// Full ordered media identifier list.
    private let ocIds: [String]

    // MARK: - Page Cache

    /// Page state cache keyed by `ocId`.
    ///
    /// Pages are created lazily when the pager asks for a specific index.
    private var cachedPagesByOcId: [String: NCMediaViewerPageModel] = [:]

    // MARK: - Running Tasks

    /// Running selected or prefetch loading tasks keyed by `ocId`.
    private var loadingTasksByOcId: [String: NCMediaViewerLoadingTask] = [:]

    // MARK: - Public Read-Only Access

    /// Total number of media pages.
    var numberOfPages: Int {
        ocIds.count
    }

    /// Initial selected index.
    var initialSelectedIndex: Int {
        selectedIndex
    }

    /// Current selected media ocId.
    ///
    /// - Returns: The ocId for the currently selected page if available.
    var selectedOcId: String? {
        guard ocIds.indices.contains(selectedIndex) else {
            return nil
        }

        return ocIds[selectedIndex]
    }

    /// Current selected page metadata.
    ///
    /// - Returns: Detached metadata for the currently selected page if available.
    var selectedMetadata: tableMetadata? {
        guard ocIds.indices.contains(selectedIndex) else {
            return nil
        }

        let ocId = ocIds[selectedIndex]
        return cachedPagesByOcId[ocId]?.metadata
    }

    /// Requests automatic playback for a target page index.
    ///
    /// - Parameter index: Target page index.
    func requestAutoPlay(at index: Int) {
        guard ocIds.indices.contains(index) else {
            return
        }

        autoPlayTargetIndex = index
        revision &+= 1
    }

    /// Clears the automatic playback request if it matches the provided index.
    ///
    /// - Parameter index: Page index that consumed auto-play.
    func clearAutoPlayIfNeeded(for index: Int) {
        guard autoPlayTargetIndex == index else {
            return
        }

        autoPlayTargetIndex = nil
        revision &+= 1
    }

    /// Marks a page as deleted without removing it from the viewer list.
    ///
    /// This is used for optimistic UI updates when a delete operation has been
    /// requested but the transfer delegate has not confirmed it yet.
    ///
    /// - Parameter ocId: Deleted file identifier.
    @MainActor
    func markPageAsDeleted(ocId: String) {
        NotificationCenter.default.post(
            name: .ncMediaViewerStopPlayback,
            object: nil
        )

        updatePage(ocId: ocId) { page in
            page.state = .deleted
        }

        revision += 1
    }

    // MARK: - Init

    /// Creates a media viewer model.
    ///
    /// - Parameters:
    ///   - initialModel: Initial viewer model containing current metadata and ordered ocIds.
    ///   - session: Current Nextcloud session used for account-scoped metadata fallback lookups.
    ///   - loader: Loader used to resolve metadata, local URLs, previews, and downloads.
    init(
        initialModel: NCMediaViewerInitialModel,
        session: NCSession.Session,
        mediaSearch: Bool,
        loader: NCMediaViewerLoading
    ) {
        self.loader = loader
        self.session = session
        self.mediaSearch = mediaSearch
        self.ocIds = initialModel.normalizedOcIds
        self.selectedIndex = initialModel.initialSelectedIndex

        let currentPage = NCMediaViewerPageModel(
            index: initialModel.initialSelectedIndex,
            ocId: initialModel.currentMetadata.ocId,
            metadata: initialModel.currentMetadata,
            state: .idle
        )

        cachedPagesByOcId[initialModel.currentMetadata.ocId] = currentPage
    }

    /// Creates a media viewer model from the current metadata and ordered media identifiers.
    ///
    /// - Parameters:
    ///   - currentMetadata: Detached metadata of the initially opened media.
    ///   - ocIds: Ordered list of image/audio/video ocIds.
    ///   - session: Current Nextcloud session used for account-scoped metadata fallback lookups.
    ///   - loader: Loader used to resolve metadata, local URLs, previews, and downloads.
    convenience init(
        currentMetadata: tableMetadata,
        ocIds: [String],
        session: NCSession.Session,
        mediaSearch: Bool,
        loader: NCMediaViewerLoading
    ) {
        let initialModel = NCMediaViewerInitialModel(
            currentMetadata: currentMetadata,
            ocIds: ocIds
        )

        self.init(
            initialModel: initialModel,
            session: session,
            mediaSearch: mediaSearch,
            loader: loader
        )
    }

    deinit {
        loadingTasksByOcId.values.forEach { $0.task.cancel() }
        loadingTasksByOcId.removeAll()
    }

    // MARK: - Public API

    /// Returns the page model for an absolute index.
    ///
    /// If the page is not cached yet, a lightweight idle page is created and cached.
    ///
    /// - Parameter index: Absolute index inside the full `ocIds` array.
    /// - Returns: Page model if the index exists.
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

    /// Handles page display from the UIKit pager.
    ///
    /// When a page becomes selected, a running prefetch task for that page is
    /// cancelled and replaced by selected-page loading.
    ///
    /// - Parameter index: Absolute page index currently displayed.
    func displayPage(at index: Int) async {
        guard ocIds.indices.contains(index) else {
            return
        }

        selectedIndex = index

        // Start neighbor prefetch immediately.
        // Do not wait for the selected page full download to finish.
        prefetchNeighborPages(around: index)

        await loadPageIfNeeded(index: index)
    }

    /// Returns the page model for the currently selected index.
    ///
    /// - Returns: Selected page model if available.
    func selectedPageModel() -> NCMediaViewerPageModel? {
        pageModel(at: selectedIndex)
    }

    /// Loads the initially selected page if needed.
    func loadSelectedPageIfNeeded() async {
        // Start neighbor prefetch immediately.
        // This prepares adjacent previews while the selected page is loading.
        prefetchNeighborPages(around: selectedIndex)

        await loadPageIfNeeded(index: selectedIndex)
    }

    /// Loads a page if it still needs selected-page loading.
    ///
    /// Prefetched pages can already have a preview, but selected-page loading
    /// must still run to check or download the full media file.
    ///
    /// - Parameter index: Absolute page index inside the full `ocIds` array.
    func loadPageIfNeeded(index: Int) async {
        guard ocIds.indices.contains(index) else {
            return
        }

        let ocId = ocIds[index]

        guard pageState(for: ocId).needsSelectedPageLoading else {
            return
        }

        if loadingTasksByOcId[ocId]?.kind == .selected {
            return
        }

        if loadingTasksByOcId[ocId]?.kind == .prefetch {
            loadingTasksByOcId[ocId]?.task.cancel()
            loadingTasksByOcId[ocId] = nil
        }

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

    /// Reloads a failed or missing page.
    ///
    /// - Parameter index: Absolute page index inside the full `ocIds` array.
    func reloadPage(index: Int) async {
        guard ocIds.indices.contains(index) else {
            return
        }

        let ocId = ocIds[index]

        loadingTasksByOcId[ocId]?.task.cancel()
        loadingTasksByOcId[ocId] = nil

        updatePage(ocId: ocId) { page in
            page.state = .idle
        }

        await loadPageIfNeeded(index: index)
    }

    /// Cancels loading for a specific page.
    ///
    /// - Parameter index: Absolute page index inside the full `ocIds` array.
    func cancelLoading(index: Int) {
        guard ocIds.indices.contains(index) else {
            return
        }

        let ocId = ocIds[index]

        loadingTasksByOcId[ocId]?.task.cancel()
        loadingTasksByOcId[ocId] = nil
    }

    /// Updates the selected index without starting full page loading.
    ///
    /// - Parameter index: Absolute page index inside the full `ocIds` array.
    func setSelectedIndex(_ index: Int) {
        guard ocIds.indices.contains(index) else {
            return
        }

        guard selectedIndex != index else {
            return
        }

        selectedIndex = index
    }

    /// Prefetches the currently visible page and its nearby pages.
    ///
    /// This method is used while the user scrolls. It warms the target area around
    /// the current visible index without starting audio or video playback.
    ///
    /// - Parameter index: Current visible page index.
    func prefetchVisiblePageIfNeeded(index: Int) async {
        guard ocIds.indices.contains(index) else {
            return
        }

        await prefetchPageIfNeeded(index: index)
        prefetchNeighborPages(around: index)
    }

    /// Toggles the media viewer chrome visibility.
    ///
    /// The chrome includes the navigation bar and the preferred page background.
    func toggleChromeVisibility() {
        isChromeHidden.toggle()
    }

    // MARK: - Selected Page Loading

    /// Loads metadata and media content for a selected or explicitly requested page.
    ///
    /// Loading order:
    /// - Resolve metadata.
    /// - Preserve any preview already stored in the current page state.
    /// - If the full local file exists, resolve a preview if needed and show it immediately.
    /// - Otherwise, resolve/show the preview.
    /// - For non-local videos, stop here and let the video viewer resolve direct playback.
    /// - For images and audio, download the full media file when needed.
    ///
    /// - Parameter index: Absolute page index inside the full `ocIds` array.
    private func loadPage(index: Int) async {
        guard ocIds.indices.contains(index) else {
            return
        }

        nkLog(
            tag: NCGlobal.shared.logTagViewer,
            emoji: .debug,
            message: "LOAD PAGE \(index)",
            consoleOnly: true
        )

        let ocId = ocIds[index]
        let metadata = await resolvedMetadata(for: ocId)

        guard !Task.isCancelled else {
            return
        }

        guard let metadata else {
            setState(.metadataMissing, for: ocId)
            return
        }

        setMetadata(metadata, for: ocId)

        var previewURL = currentPreviewURL(for: ocId)

        if let localURL = await loader.localMediaURL(for: metadata, index: index) {
            guard !Task.isCancelled else {
                return
            }

            if previewURL == nil {
                previewURL = await loader.previewURL(
                    for: metadata,
                    index: index
                )

                guard !Task.isCancelled else {
                    return
                }
            }

            await setReadyState(
                metadata: metadata,
                previewURL: previewURL,
                localURL: localURL,
                for: ocId,
                index: index
            )
            return
        }

        guard !Task.isCancelled else {
            return
        }

        if previewURL == nil {
            previewURL = await loader.previewURL(for: metadata, index: index)
        }

        guard !Task.isCancelled else {
            return
        }

        if isImage(metadata), let previewURL {
            setState(
                .image(
                    previewURL: previewURL,
                    localURL: nil,
                    livePhotoURL: nil,
                    progress: nil
                ),
                for: ocId
            )
        }

        if isVideo(metadata) {
            setState(
                .video(previewURL: previewURL),
                for: ocId
            )
            return
        }

        guard !Task.isCancelled else {
            return
        }

        do {
            if isAudio(metadata) {
                setState(
                    .downloading(
                        previewURL: previewURL,
                        progress: nil
                    ),
                    for: ocId
                )
            }

            let downloadedURL = try await loader.downloadMedia(
                for: metadata,
                index: index
            )

            guard !Task.isCancelled else {
                return
            }

            await setReadyState(
                metadata: metadata,
                previewURL: previewURL,
                localURL: downloadedURL,
                for: ocId,
                index: index
            )
        } catch is CancellationError {
            return
        } catch {
            setState(
                .failed(
                    previewURL: previewURL,
                    message: error.localizedDescription
                ),
                for: ocId
            )
        }
    }

    // MARK: - Prefetch

    /// Prefetches nearby pages around the selected index.
    ///
    /// The prefetch window is intentionally wider for smooth image navigation.
    /// Video and audio remain lightweight because `loadPageForPrefetch(index:)`
    /// only resolves metadata and preview state, without starting playback,
    /// creating AVPlayer/VLC instances, or resolving direct video download URLs.
    ///
    /// - Parameter index: Current selected absolute index.
    private func prefetchNeighborPages(around index: Int) {
        let prefetchRadius = 5

        let neighborIndexes = (-prefetchRadius...prefetchRadius)
            .map { index + $0 }
            .filter { $0 != index }
            .filter { ocIds.indices.contains($0) }

        for neighborIndex in neighborIndexes {
            Task { [weak self] in
                guard let self else {
                    return
                }

                await self.prefetchPageIfNeeded(index: neighborIndex)
            }
        }
    }

    /// Prefetches one page if it has not started loading yet.
    ///
    /// - Parameter index: Absolute page index inside the full `ocIds` array.
    private func prefetchPageIfNeeded(index: Int) async {
        guard ocIds.indices.contains(index) else {
            return
        }

        let ocId = ocIds[index]

        guard pageState(for: ocId).isIdle else {
            return
        }

        guard loadingTasksByOcId[ocId] == nil else {
            return
        }

        let identifier = UUID()

        let task = Task { [weak self] in
            guard let self else {
                return
            }

            await self.loadPageForPrefetch(index: index)
        }

        loadingTasksByOcId[ocId] = NCMediaViewerLoadingTask(
            identifier: identifier,
            kind: .prefetch,
            task: task
        )

        await task.value

        clearLoadingTaskIfCurrent(
            ocId: ocId,
            identifier: identifier
        )
    }

    /// Loads a page for neighbor prefetch.
    ///
    /// Prefetch resolves metadata and preview only.
    /// It never downloads the full media file and never starts playback.
    ///
    /// - Parameter index: Absolute page index inside the full `ocIds` array.
    private func loadPageForPrefetch(index: Int) async {
        guard ocIds.indices.contains(index) else {
            return
        }

        nkLog(
            tag: NCGlobal.shared.logTagViewer,
            emoji: .debug,
            message: "LOAD PREFETCH \(index)",
            consoleOnly: true
        )

        let ocId = ocIds[index]

        let metadata = await resolvedMetadata(for: ocId)

        guard !Task.isCancelled else {
            return
        }

        guard let metadata else {
            return
        }

        setMetadata(metadata, for: ocId)

        let previewURL = await loader.previewURL(
            for: metadata,
            index: index
        )

        guard !Task.isCancelled else {
            return
        }

        if isImage(metadata), let previewURL {
            setState(
                .image(
                    previewURL: previewURL,
                    localURL: nil,
                    livePhotoURL: nil,
                    progress: nil
                ),
                for: ocId
            )
            return
        }

        if isVideo(metadata) {
            setState(
                .downloading(
                    previewURL: previewURL,
                    progress: nil
                ),
                for: ocId
            )
            return
        }

        if isAudio(metadata) {
            setState(
                .downloading(
                    previewURL: previewURL,
                    progress: nil
                ),
                for: ocId
            )
            return
        }
    }

    // MARK: - Page Updates

    /// Resolves detached metadata for an `ocId`.
    ///
    /// - Parameter ocId: Nextcloud file identifier.
    /// - Returns: Existing cached metadata or metadata loaded from the loader.
    private func resolvedMetadata(for ocId: String) async -> tableMetadata? {
        if let existingMetadata = cachedPagesByOcId[ocId]?.metadata {
            return existingMetadata
        }

        return await loader.metadata(for: ocId, account: session.account, mediaSearch: mediaSearch)
    }

    /// Returns the current state for an `ocId`.
    ///
    /// - Parameter ocId: Nextcloud file identifier.
    /// - Returns: Page state.
    private func pageState(for ocId: String) -> NCMediaViewerPageState {
        cachedPagesByOcId[ocId]?.state ?? .idle
    }

    /// Returns whether the metadata represents an audio file.
    ///
    /// - Parameter metadata: Detached metadata.
    /// - Returns: True when the media is an audio file.
    private func isAudio(_ metadata: tableMetadata) -> Bool {
        metadata.classFile == NKTypeClassFile.audio.rawValue
    }

    /// Returns whether the metadata represents a video.
    ///
    /// - Parameter metadata: Detached metadata.
    /// - Returns: True when the media is a video.
    private func isVideo(_ metadata: tableMetadata) -> Bool {
        metadata.classFile == NKTypeClassFile.video.rawValue
    }

    /// Returns the currently cached preview URL for a page, if any.
    ///
    /// - Parameter ocId: Page file identifier.
    /// - Returns: Cached preview URL if the current page state contains one.
    private func currentPreviewURL(for ocId: String) -> URL? {
        guard let page = cachedPagesByOcId[ocId] else {
            return nil
        }

        switch page.state {
        case .image(let previewURL, _, _, _):
            return previewURL

        case .video(let previewURL):
            return previewURL

        case .downloading(let previewURL, _):
            return previewURL

        case .ready(_, let previewURL),
             .failed(let previewURL, _):
            return previewURL

        case .idle,
             .loadingMetadata,
             .metadataMissing,
             .deleted,
             .checkingLocalFile:
            return nil
        }
    }

    /// Updates the metadata for a page.
    ///
    /// - Parameters:
    ///   - metadata: Detached metadata.
    ///   - ocId: Page file identifier.
    private func setMetadata(_ metadata: tableMetadata, for ocId: String) {
        updatePage(ocId: ocId) { page in
            page.metadata = metadata
        }
    }

    /// Updates the state for a page.
    ///
    /// - Parameters:
    ///   - state: New page state.
    ///   - ocId: Page file identifier.
    private func setState(_ state: NCMediaViewerPageState, for ocId: String) {
        updatePage(ocId: ocId) { page in
            page.state = state
        }
    }

    /// Sets the correct ready state for image and non-image media.
    ///
    /// - Parameters:
    ///   - metadata: Detached metadata.
    ///   - previewURL: Optional local preview URL.
    ///   - localURL: Local full media URL.
    ///   - ocId: Page file identifier.
    ///   - index: Page index used for debug logs.
    private func setReadyState(
        metadata: tableMetadata,
        previewURL: URL?,
        localURL: URL,
        for ocId: String,
        index: Int
    ) async {
        if isImage(metadata) {
            let livePhotoURL: URL?

            if metadata.isLivePhoto {
                livePhotoURL = await loader.downloadLivePhotoMedia(
                    for: metadata,
                    index: index
                )
            } else {
                livePhotoURL = nil
            }

            setState(
                .image(
                    previewURL: previewURL,
                    localURL: localURL,
                    livePhotoURL: livePhotoURL,
                    progress: nil
                ),
                for: ocId
            )
        } else {
            setState(
                .ready(
                    localURL: localURL,
                    previewURL: previewURL
                ),
                for: ocId
            )
        }
    }

    /// Mutates a cached page and publishes a model revision.
    ///
    /// - Parameters:
    ///   - ocId: Page file identifier.
    ///   - mutation: Mutation applied to the page model.
    private func updatePage(
        ocId: String,
        mutation: (inout NCMediaViewerPageModel) -> Void
    ) {
        guard let index = ocIds.firstIndex(of: ocId) else {
            return
        }

        var page = cachedPagesByOcId[ocId] ?? NCMediaViewerPageModel(
            index: index,
            ocId: ocId,
            metadata: nil,
            state: .idle
        )

        mutation(&page)

        cachedPagesByOcId[ocId] = page
        revision &+= 1
    }

    /// Clears a loading task only if it is still the current task for the page.
    ///
    /// This prevents an older cancelled task from removing a newer task stored
    /// under the same `ocId`.
    ///
    /// - Parameters:
    ///   - ocId: Page file identifier.
    ///   - identifier: Task identifier to validate.
    private func clearLoadingTaskIfCurrent(
        ocId: String,
        identifier: UUID
    ) {
        guard loadingTasksByOcId[ocId]?.identifier == identifier else {
            return
        }

        loadingTasksByOcId[ocId] = nil
    }

    /// Returns whether the metadata represents an image.
    ///
    /// - Parameter metadata: Detached metadata.
    /// - Returns: True when the media is an image.
    private func isImage(_ metadata: tableMetadata) -> Bool {
        metadata.classFile == NKTypeClassFile.image.rawValue
    }
}

// MARK: - NCMediaViewerPageState Helpers

private extension NCMediaViewerPageState {
    /// Returns true when the page has not started loading yet.
    var isIdle: Bool {
        switch self {
        case .idle:
            return true

        case .loadingMetadata,
             .metadataMissing,
             .checkingLocalFile,
             .image,
             .video,
             .downloading,
             .ready,
             .deleted,
             .failed:
            return false
        }
    }

    /// Returns true when selected-page loading should continue.
    ///
    /// A prefetched image page can already have a preview but still needs
    /// selected-page loading to download the full image file.
    ///
    /// Video is considered resolved only after selected-page loading sets `.video`.
    /// Prefetch must use `.downloading(previewURL:progress:)` for videos so selected-page
    /// loading can still run when the user reaches the page.
    var needsSelectedPageLoading: Bool {
        switch self {
        case .idle:
            return true

        case .image(_, nil, _, _):
            return true

        case .downloading:
            return true

        case .image(_, .some, _, _),
             .video,
             .loadingMetadata,
             .metadataMissing,
             .checkingLocalFile,
             .ready,
             .deleted,
             .failed:
            return false
        }
    }
}
