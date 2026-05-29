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
        switch playback.engine {
        case .avFoundation(let url):
            NCVideoPlaybackCoverView(
                previewURL: previewURL,
                isPlayEnabled: isSelected && isCurrentPlaybackVideo(),
                onToggleChrome: onToggleChrome,
                onPlay: {
                    requestAVPlayerPresentation(url: url)
                }
            )

        case .vlc(let url):
            NCVideoPlaybackCoverView(
                previewURL: previewURL,
                isPlayEnabled: isSelected && isCurrentPlaybackVideo(),
                onToggleChrome: onToggleChrome,
                onPlay: {
                    requestVLCPresentation(url: url)
                }
            )

        case .loading:
            NCVideoPlaybackCoverView(
                previewURL: previewURL,
                isPlayEnabled: false,
                onToggleChrome: onToggleChrome,
                onPlay: {}
            )

        case .failed(let message):
            failedView(message)
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
            contextMenuController: contextMenuController,
            canGoPrevious: canGoPrevious,
            canGoNext: canGoNext,
            onPrevious: goToPreviousPageFromAVPlayer,
            onNext: goToNextPageFromAVPlayer,
            onClose: closeFromFullscreenVideo
        )

        NCVideoFullscreenTransitionOverlay.hide()
    }

    @MainActor
    private func goToPreviousPageFromAVPlayer() {
        NCVideoFullscreenTransitionOverlay.show()
        presentedAVPlayerURL = nil
        NCVideoAVPlayerPresenter.dismiss()
        onPreviousPage?()
        NCVideoFullscreenTransitionOverlay.hideAfterDelay()
    }

    @MainActor
    private func goToNextPageFromAVPlayer() {
        NCVideoFullscreenTransitionOverlay.show()
        presentedAVPlayerURL = nil
        NCVideoAVPlayerPresenter.dismiss()
        onNextPage?()
        NCVideoFullscreenTransitionOverlay.hideAfterDelay()
    }

    @MainActor
    private func closeFromFullscreenVideo(ocId: String?) {
        presentedAVPlayerURL = nil
        presentedVLCURL = nil
        hasRequestedPlayback = false
        NCVideoFullscreenTransitionOverlay.hide()
        onClose?(ocId)
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
            contextMenuController: contextMenuController,
            canGoPrevious: canGoPrevious,
            canGoNext: canGoNext,
            onPrevious: goToPreviousPageFromVLC,
            onNext: goToNextPageFromVLC,
            onClose: closeFromFullscreenVideo
        )

        NCVideoFullscreenTransitionOverlay.hide()
    }

    @MainActor
    private func goToPreviousPageFromVLC() {
        NCVideoFullscreenTransitionOverlay.show()
        presentedVLCURL = nil
        NCVideoVLCPresenter.dismiss()
        onPreviousPage?()
        NCVideoFullscreenTransitionOverlay.hideAfterDelay()
    }

    @MainActor
    private func goToNextPageFromVLC() {
        NCVideoFullscreenTransitionOverlay.show()
        presentedVLCURL = nil
        NCVideoVLCPresenter.dismiss()
        onNextPage?()
        NCVideoFullscreenTransitionOverlay.hideAfterDelay()
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

// MARK: - Video Playback Cover View

private struct NCVideoPlaybackCoverView: View {
    let previewURL: URL?
    let isPlayEnabled: Bool
    let onToggleChrome: (() -> Void)?
    let onPlay: () -> Void

    var body: some View {
        ZStack {
            if let previewURL {
                AsyncImage(url: previewURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()

                    case .failure,
                         .empty:
                        Color.black

                    @unknown default:
                        Color.black
                    }
                }
                .ignoresSafeArea()
            } else {
                Color.black
                    .ignoresSafeArea()
            }

            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    onToggleChrome?()
                }

            Button {
                guard isPlayEnabled else {
                    return
                }

                onPlay()
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 36, weight: .regular))
                    .foregroundStyle(isPlayEnabled ? .black : .black.opacity(0.35))
                    .frame(width: 62, height: 62)
                    .background(.white.opacity(isPlayEnabled ? 0.92 : 0.45))
                    .clipShape(Circle())
                    .shadow(
                        color: .black.opacity(isPlayEnabled ? 0.16 : 0.08),
                        radius: 14,
                        x: 0,
                        y: 4
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isPlayEnabled)
            .accessibilityLabel(Text(NSLocalizedString("_play_", comment: "")))
        }
    }
}

// MARK: - Fullscreen Video Transition Overlay

@MainActor
private enum NCVideoFullscreenTransitionOverlay {
    private static weak var overlayView: UIView?
    private static var hideTask: Task<Void, Never>?

    static func show() {
        hideTask?.cancel()

        guard let window = keyWindow else {
            return
        }

        let overlayView = overlayView ?? makeOverlayView(in: window)
        window.bringSubviewToFront(overlayView)
        overlayView.frame = window.bounds
        overlayView.alpha = 1
        overlayView.isHidden = false
    }

    static func hide() {
        hideTask?.cancel()
        hideTask = nil

        overlayView?.removeFromSuperview()
        overlayView = nil
    }

    static func hideAfterDelay() {
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            hide()
        }
    }

    private static func makeOverlayView(in window: UIWindow) -> UIView {
        let view = UIView(frame: window.bounds)
        view.backgroundColor = .black
        view.isUserInteractionEnabled = false
        view.autoresizingMask = [
            .flexibleWidth,
            .flexibleHeight
        ]
        window.addSubview(view)
        overlayView = view
        return view
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

// MARK: - Video URL Resolution

struct NCVideoURLResolver {
    private let utilityFileSystem = NCUtilityFileSystem()

    func getVideoURL(
        metadata: tableMetadata
    ) async -> (url: URL?, autoplay: Bool, error: NKError) {
        if !metadata.url.isEmpty {
            if metadata.url.hasPrefix("/") {
                return (
                    url: URL(fileURLWithPath: metadata.url),
                    autoplay: true,
                    error: .success
                )
            } else {
                return (
                    url: URL(string: metadata.url),
                    autoplay: true,
                    error: .success
                )
            }
        }

        if utilityFileSystem.fileProviderStorageExists(metadata) {
            let localPath = utilityFileSystem.getDirectoryProviderStorageOcId(
                metadata.ocId,
                fileName: metadata.fileNameView,
                userId: metadata.userId,
                urlBase: metadata.urlBase
            )

            return (
                url: URL(fileURLWithPath: localPath),
                autoplay: true,
                error: .success
            )
        }

        return await getDirectDownloadURL(metadata: metadata)
    }

    private func getDirectDownloadURL(
        metadata: tableMetadata
    ) async -> (url: URL?, autoplay: Bool, error: NKError) {
        await withCheckedContinuation { continuation in
            NextcloudKit.shared.getDirectDownload(
                fileId: metadata.fileId,
                account: metadata.account
            ) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                        account: metadata.account,
                        path: metadata.fileId,
                        name: "getDirectDownload"
                    )

                    await NCNetworking.shared.networkingTasks.track(
                        identifier: identifier,
                        task: task
                    )
                }
            } completion: { _, urlString, _, error in
                guard error == .success,
                      let urlString,
                      let url = URL(string: urlString) else {
                    continuation.resume(
                        returning: (
                            url: nil,
                            autoplay: false,
                            error: error
                        )
                    )
                    return
                }

                continuation.resume(
                    returning: (
                        url: url,
                        autoplay: true,
                        error: error
                    )
                )
            }
        }
    }
}
