// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

// MARK: - Video Viewer Content View

struct NCVideoViewerContentView: View {
    let metadata: tableMetadata
    let localURL: URL?
    let previewURL: URL?
    let userAgent: String?
    let isSelected: Bool
    let isChromeHidden: Bool
    let contextMenuController: NCMainTabBarController?
    let navigationBar: UINavigationBar?
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onPreviousPage: (() -> Void)?
    let onNextPage: (() -> Void)?
    let onToggleChrome: (() -> Void)?
    let onClose: ((_ ocId: String?) -> Void)?

    @ObservedObject private var playback = NCVideoPlaybackController.shared

    @State private var errorMessage: String?
    @State private var presentedAVPlayerURL: URL?
    @State private var resolvedVideoURL: URL?
    @State private var presentedVLCURL: URL?
    @State private var hasRequestedPlayback = false
    @State private var loadGeneration = UUID()

    private let resolver = NCVideoURLResolver()

    @MainActor
    private static var resolvingTasks = [String: Task<(url: URL?, autoplay: Bool, error: NKError), Never>]()

    init(
        metadata: tableMetadata,
        localURL: URL?,
        previewURL: URL? = nil,
        userAgent: String? = nil,
        isSelected: Bool = true,
        isChromeHidden: Bool = false,
        contextMenuController: NCMainTabBarController? = nil,
        navigationBar: UINavigationBar? = nil,
        canGoPrevious: Bool = false,
        canGoNext: Bool = false,
        onPreviousPage: (() -> Void)? = nil,
        onNextPage: (() -> Void)? = nil,
        onToggleChrome: (() -> Void)? = nil,
        onClose: ((_ ocId: String?) -> Void)? = nil
    ) {
        self.metadata = metadata
        self.localURL = localURL
        self.previewURL = previewURL
        self.userAgent = userAgent
        self.isSelected = isSelected
        self.isChromeHidden = isChromeHidden
        self.contextMenuController = contextMenuController
        self.navigationBar = navigationBar
        self.canGoPrevious = canGoPrevious
        self.canGoNext = canGoNext
        self.onPreviousPage = onPreviousPage
        self.onNextPage = onNextPage
        self.onToggleChrome = onToggleChrome
        self.onClose = onClose
    }
    private var videoBackgroundColor: Color {
        isChromeHidden ? .black : Color.ncViewerBackground(.system)
    }

    var body: some View {
        ZStack {
            videoBackgroundColor
                .ignoresSafeArea()

            if let errorMessage {
                failedView(errorMessage)
            } else if !hasRequestedPlayback {
                playbackCoverForCurrentEngine()
            } else {
                switch playback.engine {
                case .loading:
                    videoBackgroundColor
                        .ignoresSafeArea()
                        .allowsHitTesting(false)

                case .avFoundation(let url):
                    if isSelected,
                       isCurrentPlaybackVideo() {
                        playbackPresentationPlaceholder(
                            url: url,
                            onURLChanged: { newURL in
                                presentedAVPlayerURL = nil
                                presentAVPlayerIfSelected(url: newURL)
                            },
                            onSelectionRestored: {
                                presentAVPlayerIfSelected(url: url)
                            }
                        )
                    } else {
                        EmptyView()
                    }

                case .vlc(let url):
                    if isSelected,
                       isCurrentPlaybackVideo() {
                        playbackPresentationPlaceholder(
                            url: url,
                            onURLChanged: { newURL in
                                presentedVLCURL = nil
                                presentVLCIfSelected(url: newURL)
                            },
                            onSelectionRestored: {
                                presentVLCIfSelected(url: url)
                            }
                        )
                    } else {
                        EmptyView()
                    }

                case .failed(let message):
                    if isSelected {
                        failedView(message)
                    } else {
                        EmptyView()
                    }
                }
            }
        }
        .background(videoBackgroundColor)
        .task(id: taskIdentifier) {
            await loadVideoIfSelected()
        }
        .onChange(of: isSelected) { _, selected in
            loadGeneration = UUID()

            guard selected else {
                hasRequestedPlayback = false
                stopPlaybackForDeselection()
                return
            }

            Task {
                await loadVideoIfSelected()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .ncMediaViewerStopPlayback)) { _ in
            stopPlaybackForDeselection()
        }
        .onDisappear {
            // Ignore layout-driven disappear events.
        }
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "video.slash")
                .font(.system(size: 44, weight: .regular))

            Text(NSLocalizedString("_video_not_available_", comment: ""))
                .font(.headline)
        }
        .foregroundStyle(.white)
        .padding(24)
    }

    @ViewBuilder
    private func playbackCoverForCurrentEngine() -> some View {
        if case .failed(let message) = playback.engine {
            failedView(message)
        } else {
            NCVideoPlaybackCoverView(
                previewURL: previewURL,
                isPlayEnabled: isPlaybackCoverPlayEnabled,
                onToggleChrome: onToggleChrome,
                onPlay: playFromCover
            )
        }
    }

    private var isPlaybackCoverPlayEnabled: Bool {
        guard isSelected,
              isCurrentPlaybackVideo() else {
            return false
        }

        switch playback.engine {
        case .avFoundation,
             .vlc:
            return true

        case .loading,
             .failed:
            return false
        }
    }

    @MainActor
    private func playFromCover() {
        guard isPlaybackCoverPlayEnabled else {
            return
        }

        switch playback.engine {
        case .avFoundation(let url):
            requestAVPlayerPresentation(url: url)

        case .vlc(let url):
            requestVLCPresentation(url: url)

        case .loading,
             .failed:
            break
        }
    }

    private func playbackPresentationPlaceholder(
        url: URL,
        onURLChanged: @escaping (_ newURL: URL) -> Void,
        onSelectionRestored: @escaping () -> Void
    ) -> some View {
        videoBackgroundColor
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onAppear {
                onSelectionRestored()
            }
            .onChange(of: url) { _, newURL in
                onURLChanged(newURL)
            }
            .onChange(of: isSelected) { _, selected in
                guard selected else {
                    return
                }

                onSelectionRestored()
            }
    }

    // MARK: - Loading

    @MainActor
    private func stopPlaybackForDeselection() {
        presentedAVPlayerURL = nil
        resolvedVideoURL = nil
        presentedVLCURL = nil
        hasRequestedPlayback = false

        NCVideoAVPlayerPresenter.dismiss()
        NCVideoVLCPresenter.dismiss()
        playback.stop()
    }

    private var taskIdentifier: String {
        let localIdentifier = localURL?.absoluteString ?? "remote"
        return "\(metadata.ocId)|\(metadata.etag)|\(localIdentifier)"
    }

    // Single entry point for selected video loading.
    @MainActor
    private func loadVideoIfSelected() async {
        let expectedTaskIdentifier = taskIdentifier
        let expectedLoadGeneration = loadGeneration

        guard await waitForStableSelection(
            expectedTaskIdentifier: expectedTaskIdentifier,
            expectedLoadGeneration: expectedLoadGeneration
        ) else {
            return
        }

        errorMessage = nil

        if isCurrentPlaybackVideo() {
            revealCurrentPlaybackIfNeeded()
            return
        }

        await resolveAndLoadVideo(
            expectedTaskIdentifier: expectedTaskIdentifier,
            expectedLoadGeneration: expectedLoadGeneration
        )
    }

    // Avoid loading transient pages during fast swipes.
    @MainActor
    private func waitForStableSelection(
        expectedTaskIdentifier: String,
        expectedLoadGeneration: UUID
    ) async -> Bool {
        guard isSelected else {
            return false
        }

        do {
            try await Task.sleep(for: .milliseconds(150))
        } catch {
            return false
        }

        guard !Task.isCancelled else {
            return false
        }

        guard expectedTaskIdentifier == taskIdentifier else {
            return false
        }

        guard expectedLoadGeneration == loadGeneration else {
            return false
        }

        return isSelected
    }

    @MainActor
    private func resolveAndLoadVideo(
        expectedTaskIdentifier: String,
        expectedLoadGeneration: UUID
    ) async {
        errorMessage = nil

        if let localURL {
            loadResolvedVideo(
                url: localURL,
                autoplay: true,
                expectedTaskIdentifier: expectedTaskIdentifier,
                expectedLoadGeneration: expectedLoadGeneration
            )
            return
        }

        let result = await resolvedVideoURL(
            taskIdentifier: expectedTaskIdentifier
        )

        guard !Task.isCancelled else {
            return
        }

        guard expectedTaskIdentifier == taskIdentifier else {
            return
        }

        guard expectedLoadGeneration == loadGeneration else {
            return
        }

        guard isSelected else {
            return
        }

        guard result.error == .success,
              let url = result.url else {
            errorMessage = ""
            return
        }

        loadResolvedVideo(
            url: url,
            autoplay: result.autoplay,
            expectedTaskIdentifier: expectedTaskIdentifier,
            expectedLoadGeneration: expectedLoadGeneration
        )
    }

    @MainActor
    private func loadResolvedVideo(
        url: URL,
        autoplay: Bool,
        expectedTaskIdentifier: String,
        expectedLoadGeneration: UUID
    ) {
        guard expectedTaskIdentifier == taskIdentifier else {
            return
        }

        guard expectedLoadGeneration == loadGeneration else {
            return
        }

        guard isSelected else {
            return
        }

        resolvedVideoURL = url
        hasRequestedPlayback = false

        playback.loadVideo(
            metadata: metadata,
            url: url,
            fileName: resolvedFileName,
            userAgent: userAgent,
            httpHeaders: httpHeaders(for: url),
            shouldAutoPlay: autoplay
        )
    }

    private func httpHeaders(for url: URL) -> [String: String] {
        guard !url.isFileURL else {
            return [:]
        }

        guard let userAgent,
              !userAgent.isEmpty else {
            return [:]
        }

        return [
            "User-Agent": userAgent
        ]
    }

    // MARK: - Playback Selection

    // Loading or failed engines are not reusable.
    private func isCurrentPlaybackVideo() -> Bool {
        switch playback.engine {
        case .avFoundation,
             .vlc:
            break

        case .loading,
             .failed:
            return false
        }

        if let localURL {
            return playback.isCurrentVideo(
                ocId: metadata.ocId,
                etag: metadata.etag,
                url: localURL
            )
        }

        return playback.isCurrentVideo(
            ocId: metadata.ocId,
            etag: metadata.etag
        )
    }

    // Reveal without changing play/pause state.
    @MainActor
    private func revealCurrentPlaybackIfNeeded() {
        guard hasRequestedPlayback else {
            return
        }

        switch playback.engine {
        case .avFoundation(let url):
            presentAVPlayerIfSelected(url: url)

        case .vlc(let url):
            presentVLCIfSelected(url: url)

        case .loading,
             .failed:
            break
        }
    }

    @MainActor
    private func requestAVPlayerPresentation(url: URL) {
        hasRequestedPlayback = true
        presentAVPlayerIfSelected(url: url)
    }

    @MainActor
    private func presentAVPlayerIfSelected(url: URL) {
        guard isSelected else {
            return
        }

        guard presentedAVPlayerURL != url else {
            return
        }

        presentedAVPlayerURL = url

        NCVideoAVPlayerPresenter.present(
            metadata: metadata,
            url: url,
            userAgent: userAgent,
            shouldAutoPlay: true,
            contextMenuController: contextMenuController,
            canGoPrevious: canGoPrevious,
            canGoNext: canGoNext,
            onPrevious: goToPreviousPageFromAVPlayer,
            onNext: goToNextPageFromAVPlayer,
            onClose: closeFromFullscreenVideo
        )
    }

    @MainActor
    private func goToPreviousPageFromAVPlayer() {
        performFullscreenPageTransition(
            dismissPlayer: {
                NCVideoAVPlayerPresenter.dismiss()
            },
            changePage: {
                onPreviousPage?()
            }
        )
    }

    @MainActor
    private func goToNextPageFromAVPlayer() {
        performFullscreenPageTransition(
            dismissPlayer: {
                NCVideoAVPlayerPresenter.dismiss()
            },
            changePage: {
                onNextPage?()
            }
        )
    }

    @MainActor
    private func closeFromFullscreenVideo(ocId: String?) {
        presentedAVPlayerURL = nil
        presentedVLCURL = nil
        hasRequestedPlayback = false
    }

    @MainActor
    private func preparePlaybackCoverForPageTransition() {
        presentedAVPlayerURL = nil
        presentedVLCURL = nil
        hasRequestedPlayback = false
    }

    @MainActor
    private func performFullscreenPageTransition(
        dismissPlayer: @escaping () -> Void,
        changePage: @escaping () -> Void
    ) {
        preparePlaybackCoverForPageTransition()
        dismissPlayer()
        changePage()
    }

    @MainActor
    private func requestVLCPresentation(url: URL) {
        hasRequestedPlayback = true
        presentVLCIfSelected(url: url)
    }

    @MainActor
    private func presentVLCIfSelected(url: URL) {
        guard isSelected else {
            return
        }

        guard presentedVLCURL != url else {
            return
        }

        presentedVLCURL = url

        NCVideoVLCPresenter.present(
            metadata: metadata,
            url: url,
            userAgent: userAgent,
            shouldAutoPlay: true,
            contextMenuController: contextMenuController,
            canGoPrevious: canGoPrevious,
            canGoNext: canGoNext,
            onPrevious: goToPreviousPageFromVLC,
            onNext: goToNextPageFromVLC,
            onClose: closeFromFullscreenVideo
        )
    }

    @MainActor
    private func goToPreviousPageFromVLC() {
        performFullscreenPageTransition(
            dismissPlayer: {
                NCVideoVLCPresenter.dismiss()
            },
            changePage: {
                onPreviousPage?()
            }
        )
    }

    @MainActor
    private func goToNextPageFromVLC() {
        performFullscreenPageTransition(
            dismissPlayer: {
                NCVideoVLCPresenter.dismiss()
            },
            changePage: {
                onNextPage?()
            }
        )
    }

    // MARK: - In-Flight Resolution Cache

    // Share direct-link resolution between duplicated SwiftUI page instances.
    @MainActor
    private func resolvedVideoURL(
        taskIdentifier: String
    ) async -> (url: URL?, autoplay: Bool, error: NKError) {
        if let existingTask = Self.resolvingTasks[taskIdentifier] {
            return await existingTask.value
        }

        let task = Task {
            await resolver.getVideoURL(metadata: metadata)
        }

        Self.resolvingTasks[taskIdentifier] = task

        let result = await task.value
        Self.resolvingTasks[taskIdentifier] = nil

        return result
    }

    // MARK: - Helpers

    private var resolvedFileName: String {
        if !metadata.fileNameView.isEmpty {
            return metadata.fileNameView
        }

        return metadata.fileName
    }
}
