// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

// MARK: - Page State

enum NCMediaViewerPageState {
    case idle
    case loadingMetadata
    case metadataMissing
    case checkingLocalFile
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

    @Published var metadata: tableMetadata?
    @Published var state: NCMediaViewerPageState

    init(
        index: Int,
        ocId: String,
        metadata: tableMetadata? = nil,
        state: NCMediaViewerPageState = .idle
    ) {
        self.id = ocId
        self.index = index
        self.ocId = ocId
        self.metadata = metadata
        self.state = state
    }
}

// MARK: - Initial Model

struct NCMediaViewerInitialModel {
    let currentMetadata: tableMetadata
    let ocIds: [String]

    init(
        currentMetadata: tableMetadata,
        ocIds: [String]
    ) {
        self.currentMetadata = currentMetadata
        self.ocIds = ocIds
    }

    var normalizedOcIds: [String] {
        if ocIds.contains(currentMetadata.ocId) {
            return ocIds
        } else {
            return [currentMetadata.ocId] + ocIds
        }
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

    // MARK: - Published State

    @Published private(set) var selectedIndex: Int
    @Published private(set) var revision: Int = 0
    @Published private(set) var thumbnailReloadRevision: Int = 0
    @Published private(set) var isChromeHidden = false
    @Published private(set) var autoPlayTargetIndex: Int?

    // MARK: - Dependencies

    private let loader: NCMediaViewerLoading
    private let utilityFileSystem = NCUtilityFileSystem()

    // MARK: - Source Context

    private let session: NCSession.Session

    // MARK: - Source Data

    private let ocIds: [String]

    // MARK: - Page Cache

    // Lazy page cache keyed by ocId.
    private var cachedPagesByOcId: [String: NCMediaViewerPageModel] = [:]

    // MARK: - Running Tasks

    private var loadingTasksByOcId: [String: NCMediaViewerLoadingTask] = [:]

    // MARK: - Public Read-Only Access

    var numberOfPages: Int {
        ocIds.count
    }

    var currentSelectedIndex: Int {
        selectedIndex
    }

    var selectedOcId: String? {
        guard ocIds.indices.contains(selectedIndex) else {
            return nil
        }

        return ocIds[selectedIndex]
    }

    var selectedMetadata: tableMetadata? {
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

    func metadataForThumbnail(at index: Int) -> tableMetadata? {
        guard let ocId = ocId(at: index) else {
            return nil
        }

        return cachedPagesByOcId[ocId]?.metadata
    }

    func requestAutoPlay(at index: Int) {
        guard ocIds.indices.contains(index) else {
            return
        }

        autoPlayTargetIndex = index
        revision &+= 1
    }

    func clearAutoPlayIfNeeded(for index: Int) {
        guard autoPlayTargetIndex == index else {
            return
        }

        autoPlayTargetIndex = nil
        revision &+= 1
    }

    @MainActor
    func markPageAsDeleted(ocId: String) {
        // Stop any active playback before marking the page as deleted.
        // This is a destructive state change, so the global playback stop is intentional.
        NotificationCenter.default.post(
            name: .ncMediaViewerStopPlayback,
            object: nil
        )

        updatePage(ocId: ocId) { page in
            page.state = .deleted
        }
    }

    // MARK: - Init

    init(
        initialModel: NCMediaViewerInitialModel,
        session: NCSession.Session,
        loader: NCMediaViewerLoading
    ) {
        self.loader = loader
        self.session = session
        self.ocIds = initialModel.normalizedOcIds
        self.selectedIndex = initialModel.currentSelectedIndex

        let currentPage = NCMediaViewerPageModel(
            index: initialModel.currentSelectedIndex,
            ocId: initialModel.currentMetadata.ocId,
            metadata: initialModel.currentMetadata,
            state: .idle
        )

        cachedPagesByOcId[initialModel.currentMetadata.ocId] = currentPage
    }

    convenience init(
        currentMetadata: tableMetadata,
        ocIds: [String],
        session: NCSession.Session,
        loader: NCMediaViewerLoading
    ) {
        let initialModel = NCMediaViewerInitialModel(
            currentMetadata: currentMetadata,
            ocIds: ocIds
        )

        self.init(
            initialModel: initialModel,
            session: session,
            loader: loader
        )
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

        let page = NCMediaViewerPageModel(
            index: index,
            ocId: ocId,
            metadata: nil,
            state: .idle
        )

        cachedPagesByOcId[ocId] = page
        return page
    }

    func displayPage(at index: Int) async {
        guard ocIds.indices.contains(index) else {
            return
        }

        if selectedIndex == index,
           let ocId = ocId(at: index),
           !pageState(for: ocId).needsSelectedPageLoading {
            return
        }

        selectedIndex = index

        prefetchNeighborPages(around: index)
        await loadPageIfNeeded(index: index)
    }

    func displayPreviewPage(at index: Int) async {
        guard ocIds.indices.contains(index) else {
            return
        }

        guard selectedIndex != index else {
            return
        }

        selectedIndex = index

        let ocId = ocIds[index]

        guard let metadata = await resolvedMetadata(for: ocId) else {
            return
        }

        setThumbnailMetadata(metadata, for: ocId)

        let previewURL: URL?

        if let existingPreviewURL = currentPreviewURL(for: ocId) {
            previewURL = existingPreviewURL
        } else {
            previewURL = await loader.previewURL(
                for: metadata,
                ext: NCGlobal.shared.previewExt1024
            )
        }

        guard let previewURL else {
            return
        }

        switch metadata.classFile {
        case NKTypeClassFile.image.rawValue:
            setState(
                .image(
                    previewURL: previewURL,
                    localURL: nil,
                    livePhotoURL: nil,
                    progress: nil
                ),
                for: ocId
            )

        case NKTypeClassFile.video.rawValue:
            setState(
                .video(
                    localURL: nil,
                    previewURL: previewURL
                ),
                for: ocId
            )

        case NKTypeClassFile.audio.rawValue:
            setState(
                .downloading(
                    previewURL: previewURL,
                    progress: nil
                ),
                for: ocId
            )

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

        loadingTasksByOcId[ocId] = NCMediaViewerLoadingTask(
            identifier: identifier,
            kind: .selected,
            task: task
        )

        await task.value

        clearLoadingTaskIfCurrent(
            ocId: ocId,
            identifier: identifier
        )
    }

    /// Reloads the page from the beginning, forcing a fresh metadata resolution before rebuilding the preview and media state.
    /// - Parameter index: The index of the page that must be reloaded.
    func reloadPage(index: Int) async {
        guard ocIds.indices.contains(index) else {
            return
        }

        let ocId = ocIds[index]

        loadingTasksByOcId[ocId]?.task.cancel()
        loadingTasksByOcId[ocId] = nil

        updatePage(ocId: ocId) { page in
            page.metadata = nil
            page.state = .idle
        }

        thumbnailReloadRevision &+= 1

        await loadPage(
            index: index,
            forceMetadataReload: true
        )
    }

    func cancelLoading(index: Int) {
        guard ocIds.indices.contains(index) else {
            return
        }

        let ocId = ocIds[index]

        loadingTasksByOcId[ocId]?.task.cancel()
        loadingTasksByOcId[ocId] = nil
    }

    func cancelAllDownloads() {
        Task {
            await loader.cancelAllDownloads()
        }
    }

    func setSelectedIndex(_ index: Int) {
        guard ocIds.indices.contains(index) else {
            return
        }

        guard selectedIndex != index else {
            return
        }

        selectedIndex = index
    }

    func prefetchVisiblePageIfNeeded(index: Int) async {
        guard ocIds.indices.contains(index) else {
            return
        }

        await prefetchPageIfNeeded(index: index)
        prefetchNeighborPages(around: index)
    }

    func toggleChromeVisibility() {
        isChromeHidden.toggle()
    }

    func previewURL(
        for metadata: tableMetadata,
        ext: String
    ) async -> URL? {
        await loader.previewURL(
            for: metadata,
            ext: ext
        )
    }

    func localPreviewURL(
        for metadata: tableMetadata,
        ext: String
    ) -> URL? {
        let localPath = utilityFileSystem.getDirectoryProviderStorageImageOcId(
            metadata.ocId,
            etag: metadata.etag,
            ext: ext,
            userId: metadata.userId,
            urlBase: metadata.urlBase
        )

        guard FileManager.default.fileExists(atPath: localPath) else {
            return nil
        }

        return URL(fileURLWithPath: localPath)
    }

    func resolveMetadataForThumbnail(
        at index: Int
    ) async -> tableMetadata? {
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

    private func loadPage(
        index: Int,
        forceMetadataReload: Bool = false
    ) async {
        guard ocIds.indices.contains(index) else {
            return
        }

        let ocId = ocIds[index]
        let metadata = await resolvedMetadata(
            for: ocId,
            allowCached: !forceMetadataReload
        )

        guard !Task.isCancelled else {
            return
        }

        guard let metadata else {
            setState(.metadataMissing, for: ocId)
            return
        }

        setMetadata(metadata, for: ocId)

        let previewURL = currentPreviewURL(for: ocId)

        if let localURL = await loader.localMediaURL(for: metadata) {
            guard !Task.isCancelled else {
                return
            }

            await loadLocalPage(
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

        await loadRemotePage(
            metadata: metadata,
            previewURL: previewURL,
            for: ocId,
            index: index
        )
    }

    private func loadLocalPage(
        metadata: tableMetadata,
        previewURL: URL?,
        localURL: URL,
        for ocId: String,
        index: Int
    ) async {
        switch metadata.classFile {
        case NKTypeClassFile.video.rawValue:
            var videoPreviewURL = previewURL

            if videoPreviewURL == nil {
                videoPreviewURL = await loader.previewURL(
                    for: metadata,
                    ext: NCGlobal.shared.previewExt1024
                )

                guard !Task.isCancelled else {
                    return
                }
            }

            setState(
                .video(
                    localURL: localURL,
                    previewURL: videoPreviewURL
                ),
                for: ocId
            )

        case NKTypeClassFile.audio.rawValue:
            await setReadyState(
                metadata: metadata,
                previewURL: previewURL,
                localURL: localURL,
                for: ocId,
                index: index
            )

            await loadAudioPreviewIfNeeded(
                metadata: metadata,
                localURL: localURL,
                currentPreviewURL: previewURL,
                for: ocId,
                index: index
            )

        case NKTypeClassFile.image.rawValue:
            var imagePreviewURL = previewURL

            if imagePreviewURL == nil {
                imagePreviewURL = await loader.previewURL(
                    for: metadata,
                    ext: NCGlobal.shared.previewExt1024
                )

                guard !Task.isCancelled else {
                    return
                }
            }

            await setReadyState(
                metadata: metadata,
                previewURL: imagePreviewURL,
                localURL: localURL,
                for: ocId,
                index: index
            )

        default:
            await setReadyState(
                metadata: metadata,
                previewURL: previewURL,
                localURL: localURL,
                for: ocId,
                index: index
            )
        }
    }

    private func loadRemotePage(
        metadata: tableMetadata,
        previewURL: URL?,
        for ocId: String,
        index: Int
    ) async {
        var previewURL = previewURL

        if previewURL == nil,
           shouldLoadPreview(for: metadata) {
            previewURL = await loader.previewURL(
                for: metadata,
                ext: NCGlobal.shared.previewExt1024
            )
        }

        guard !Task.isCancelled else {
            return
        }

        switch metadata.classFile {
        case NKTypeClassFile.video.rawValue:
            setState(
                .video(
                    localURL: nil,
                    previewURL: previewURL
                ),
                for: ocId
            )
            return

        case NKTypeClassFile.image.rawValue:
            if let previewURL {
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

        case NKTypeClassFile.audio.rawValue:
            setState(
                .downloading(
                    previewURL: previewURL,
                    progress: nil
                ),
                for: ocId
            )

        default:
            break
        }

        do {
            let downloadedURL = try await loader.downloadMedia(
                for: metadata
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

            if metadata.classFile == NKTypeClassFile.audio.rawValue {
                await loadAudioPreviewIfNeeded(
                    metadata: metadata,
                    localURL: downloadedURL,
                    currentPreviewURL: previewURL,
                    for: ocId,
                    index: index
                )
            }
        } catch is CancellationError {
            return
        } catch {
            if metadata.classFile == NKTypeClassFile.image.rawValue,
               let previewURL {
                setState(
                    .image(
                        previewURL: previewURL,
                        localURL: nil,
                        livePhotoURL: nil,
                        progress: nil
                    ),
                    for: ocId
                )
            } else {
                setState(
                    .failed(
                        previewURL: previewURL,
                        message: ""
                    ),
                    for: ocId
                )
            }
        }
    }

    // MARK: - Prefetch

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

    private func loadPageForPrefetch(index: Int) async {
        guard ocIds.indices.contains(index) else {
            return
        }

        let ocId = ocIds[index]
        let metadata = await resolvedMetadata(for: ocId)

        guard !Task.isCancelled else {
            return
        }

        guard let metadata else {
            return
        }

        setMetadata(metadata, for: ocId)

        let previewURL: URL?

        if shouldLoadPreview(for: metadata) {
            previewURL = await loader.previewURL(
                for: metadata,
                ext: NCGlobal.shared.previewExt1024
            )
        } else {
            previewURL = nil
        }

        guard !Task.isCancelled else {
            return
        }

        if metadata.classFile == NKTypeClassFile.image.rawValue,
           let previewURL {
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

        if metadata.classFile == NKTypeClassFile.video.rawValue {
            let localURL = await loader.localMediaURL(
                for: metadata
            )

            guard !Task.isCancelled else {
                return
            }

            setState(
                .video(
                    localURL: localURL,
                    previewURL: previewURL
                ),
                for: ocId
            )
            return
        }

        if metadata.classFile == NKTypeClassFile.audio.rawValue {
            let localURL = await loader.localMediaURL(
                for: metadata
            )

            guard !Task.isCancelled else {
                return
            }

            guard let localURL else {
                setState(
                    .downloading(
                        previewURL: previewURL,
                        progress: nil
                    ),
                    for: ocId
                )
                return
            }

            setState(
                .audio(
                    localURL: localURL,
                    previewURL: previewURL
                ),
                for: ocId
            )

            await loadAudioPreviewIfNeeded(
                metadata: metadata,
                localURL: localURL,
                currentPreviewURL: previewURL,
                for: ocId,
                index: index
            )
            return
        }
    }

    // MARK: - Page Updates

    private func resolvedMetadata(
        for ocId: String,
        allowCached: Bool = true
    ) async -> tableMetadata? {
        if allowCached,
           let existingMetadata = cachedPagesByOcId[ocId]?.metadata {
            return existingMetadata
        }

        return await loader.metadata(
            for: ocId,
            account: session.account
        )
    }

    private func pageState(
        for ocId: String
    ) -> NCMediaViewerPageState {
        cachedPagesByOcId[ocId]?.state ?? .idle
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
             .loadingMetadata,
             .metadataMissing,
             .deleted,
             .checkingLocalFile:
            return nil
        }
    }

    private func shouldLoadPreview(
        for metadata: tableMetadata
    ) -> Bool {
        switch metadata.classFile {
        case NKTypeClassFile.image.rawValue,
             NKTypeClassFile.audio.rawValue,
             NKTypeClassFile.video.rawValue:
            return true

        default:
            return false
        }
    }

    private func setMetadata(
        _ metadata: tableMetadata,
        for ocId: String
    ) {
        updatePage(ocId: ocId) { page in
            page.metadata = metadata
        }
    }

    private func setState(
        _ state: NCMediaViewerPageState,
        for ocId: String
    ) {
        updatePage(ocId: ocId) { page in
            page.state = state
        }
    }

    private func setReadyState(
        metadata: tableMetadata,
        previewURL: URL?,
        localURL: URL,
        for ocId: String,
        index: Int
    ) async {
        if metadata.classFile == NKTypeClassFile.image.rawValue {
            let livePhotoURL: URL?

            if metadata.isLivePhoto {
                livePhotoURL = await loader.downloadLivePhotoMedia(
                    for: metadata
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
        } else if metadata.classFile == NKTypeClassFile.video.rawValue {
            setState(
                .video(
                    localURL: localURL,
                    previewURL: previewURL
                ),
                for: ocId
            )
        } else if metadata.classFile == NKTypeClassFile.audio.rawValue {
            setState(
                .audio(
                    localURL: localURL,
                    previewURL: previewURL
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

    private func loadAudioPreviewIfNeeded(
        metadata: tableMetadata,
        localURL: URL,
        currentPreviewURL: URL?,
        for ocId: String,
        index: Int
    ) async {
        guard currentPreviewURL == nil else {
            return
        }

        let previewURL = await loader.previewURL(
            for: metadata,
            ext: NCGlobal.shared.previewExt1024
        )

        guard !Task.isCancelled,
              let previewURL else {
            return
        }

        guard case .audio(let readyLocalURL, _) = pageState(for: ocId),
              readyLocalURL == localURL else {
            return
        }

        setState(
            .audio(
                localURL: localURL,
                previewURL: previewURL
            ),
            for: ocId
        )
    }

    private func updatePage(
        ocId: String,
        publishRevision: Bool = true,
        mutation: (NCMediaViewerPageModel) -> Void
    ) {
        guard let index = ocIds.firstIndex(of: ocId) else {
            return
        }

        let page: NCMediaViewerPageModel

        if let cachedPage = cachedPagesByOcId[ocId] {
            page = cachedPage
        } else {
            page = NCMediaViewerPageModel(
                index: index,
                ocId: ocId,
                metadata: nil,
                state: .idle
            )

            cachedPagesByOcId[ocId] = page
        }

        mutation(page)

        if publishRevision {
            revision &+= 1
        }
    }

    private func setThumbnailMetadata(
        _ metadata: tableMetadata,
        for ocId: String
    ) {
        updatePage(
            ocId: ocId,
            publishRevision: false
        ) { page in
            page.metadata = metadata
        }
    }

    private func clearLoadingTaskIfCurrent(
        ocId: String,
        identifier: UUID
    ) {
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

        case .loadingMetadata,
             .metadataMissing,
             .checkingLocalFile,
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

    var needsSelectedPageLoading: Bool {
        switch self {
        case .idle:
            return true

        case .downloading:
            return true

        case .image(_, nil, _, _):
            return true

        case .video(nil, nil):
            return true

        case .audio:
            return false

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
