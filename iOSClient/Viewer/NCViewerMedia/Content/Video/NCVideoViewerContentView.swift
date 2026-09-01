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
    let shouldAutoPlay: Bool
    let isAutomaticAdvanceTarget: Bool
    @ObservedObject var playbackOptions: NCMediaPlaybackOptions
    let onPreviousPage: (() -> Void)?
    let onNextPage: (() -> Void)?
    let onPlayNextMedia: NCMediaPlaybackAdvanceRequest?
    let onAutoPlayConsumed: (() -> Void)?
    let onToggleChrome: (() -> Void)?
    let onClose: ((_ ocId: String?) -> Void)?
    let downloadVideo: (@MainActor () async throws -> URL)?
    let cancelVideoDownload: (@MainActor () async -> Void)?

    @ObservedObject private var playback = NCVideoPlaybackController.shared

    @State private var errorMessage: String?
    @State var presentedAVPlayerURL: URL?
    @State var presentedVLCURL: URL?
    @State var hasRequestedPlayback = false
    @State var isLaunchingPlayback = false
    @State private var resolvedPlaybackURL: URL?
    @State private var isDownloadingPlayback = false
    @State private var playbackDownloadTask: Task<Void, Never>?
    @State private var loadGeneration = UUID()

    private let resolver = NCVideoURLResolver()
    private let forceDownloadBeforePlaybackForTesting = false

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
        shouldAutoPlay: Bool = false,
        isAutomaticAdvanceTarget: Bool = false,
        playbackOptions: NCMediaPlaybackOptions,
        onPreviousPage: (() -> Void)? = nil,
        onNextPage: (() -> Void)? = nil,
        onPlayNextMedia: NCMediaPlaybackAdvanceRequest? = nil,
        onAutoPlayConsumed: (() -> Void)? = nil,
        onToggleChrome: (() -> Void)? = nil,
        onClose: ((_ ocId: String?) -> Void)? = nil,
        downloadVideo: (@MainActor () async throws -> URL)? = nil,
        cancelVideoDownload: (@MainActor () async -> Void)? = nil
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
        self.shouldAutoPlay = shouldAutoPlay
        self.isAutomaticAdvanceTarget = isAutomaticAdvanceTarget
        self.playbackOptions = playbackOptions
        self.onPreviousPage = onPreviousPage
        self.onNextPage = onNextPage
        self.onPlayNextMedia = onPlayNextMedia
        self.onAutoPlayConsumed = onAutoPlayConsumed
        self.onToggleChrome = onToggleChrome
        self.onClose = onClose
        self.downloadVideo = downloadVideo
        self.cancelVideoDownload = cancelVideoDownload
    }

    var body: some View {
        ZStack {
            videoBackgroundColor
                .ignoresSafeArea()

            contentView
        }
        .background(videoBackgroundColor)
        .task(id: taskIdentifier) {
            await loadVideoIfSelected()
            scheduleAutoPlayIfNeeded()
        }
        .onAppear {
            scheduleAutoPlayIfNeeded()
        }
        .onChange(of: isSelected) { _, selected in
            loadGeneration = UUID()

            guard selected else {
                stopPlaybackForDeselection()
                return
            }

            Task {
                await loadVideoIfSelected()
                scheduleAutoPlayIfNeeded()
            }
        }
        .onChange(of: shouldAutoPlay) { _, shouldAutoPlay in
            guard shouldAutoPlay else {
                return
            }

            scheduleAutoPlayIfNeeded()
        }
        .onReceive(playback.$engine) { _ in
            scheduleAutoPlayIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .ncMediaViewerStopPlayback)) { _ in
            stopPlaybackForDeselection()
        }
        .onDisappear {
            // Ignore layout-driven disappear events.
        }
    }
}

// MARK: - Automatic Playback

private extension NCVideoViewerContentView {
    func scheduleAutoPlayIfNeeded() {
        // Keep the normal cover/play path completely untouched when this page
        // is not the selected autoplay target.
        guard isSelected,
              shouldAutoPlay else {
            return
        }

        Task { @MainActor in
            // Present on the next run-loop turn, after SwiftUI has committed the
            // selected page and the prepared playback state.
            await Task.yield()
            autoPlayIfNeeded()
        }
    }

    @MainActor
    func autoPlayIfNeeded() {
        guard isSelected,
              shouldAutoPlay,
              !hasRequestedPlayback,
              !isLaunchingPlayback else {
            return
        }

        if requiresUserTrustedCertificateDownload {
            guard downloadVideo != nil,
                  !isDownloadingPlayback else {
                return
            }

            isLaunchingPlayback = true
            downloadAndPlayVideo()
            return
        }

        switch playback.engine {
        case .avFoundation(let preparedPlayback):
            guard isCurrentPlaybackVideo() else {
                return
            }

            requestAVPlayerPresentation(preparedPlayback: preparedPlayback)

        case .vlc(let preparedPlayback):
            guard isCurrentPlaybackVideo() else {
                return
            }

            requestVLCPresentation(preparedPlayback: preparedPlayback)

        case .loading,
             .failed:
            break
        }
    }
}

// MARK: - Main Content

private extension NCVideoViewerContentView {
    var videoBackgroundColor: Color {
        isChromeHidden ? .black : Color.ncViewerBackground(.system)
    }

    @ViewBuilder
    var contentView: some View {
        if let errorMessage {
            failedView(errorMessage)
        } else if !hasRequestedPlayback {
            if case .failed(let message) = playback.engine,
               !requiresUserTrustedCertificateDownload {
                failedView(message)
            } else if shouldHideCoverDuringAutomaticLocalPlayback {
                // Local auto-advance should not briefly expose the underlying
                // cover between fullscreen video presentations.
                Color.black
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            } else {
                NCVideoPlaybackCoverView(
                    previewURL: previewURL,
                    isPlayEnabled: isPlaybackCoverPlayEnabled,
                    isLoading: isPlaybackCoverLoading,
                    isLaunchingPlayback: isLaunchingPlayback,
                    statusMessage: isDownloadingPlayback
                        ? NSLocalizedString("_download_in_progress_", comment: "")
                        : nil,
                    onCancel: isDownloadingPlayback
                        ? { cancelPlaybackDownload() }
                        : nil,
                    onToggleChrome: onToggleChrome,
                    onPlay: playFromCover
                )
            }
        } else {
            requestedPlaybackView
        }
    }

    var shouldHideCoverDuringAutomaticLocalPlayback: Bool {
        isAutomaticAdvanceTarget && localURL != nil
    }

    @ViewBuilder
    var requestedPlaybackView: some View {
        switch playback.engine {
        case .loading:
            NCVideoPlaybackCoverView(
                previewURL: previewURL,
                isPlayEnabled: false,
                isLoading: true,
                isLaunchingPlayback: true,
                statusMessage: nil,
                onCancel: nil,
                onToggleChrome: onToggleChrome,
                onPlay: { }
            )

        case .avFoundation(let preparedPlayback):
            if isSelected,
               isCurrentPlaybackVideo() {
                playbackPresentationPlaceholder(
                    url: preparedPlayback.url,
                    onURLChanged: { _ in
                        presentedAVPlayerURL = nil
                        presentAVPlayerIfSelected(preparedPlayback: preparedPlayback)
                    },
                    onSelectionRestored: {
                        presentAVPlayerIfSelected(preparedPlayback: preparedPlayback)
                    }
                )
            } else {
                EmptyView()
            }

        case .vlc(let preparedPlayback):
            if isSelected,
               isCurrentPlaybackVideo() {
                playbackPresentationPlaceholder(
                    url: preparedPlayback.url,
                    onURLChanged: { _ in
                        presentedVLCURL = nil
                        presentVLCIfSelected(preparedPlayback: preparedPlayback)
                    },
                    onSelectionRestored: {
                        presentVLCIfSelected(preparedPlayback: preparedPlayback)
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

    func failedView(_ message: String) -> some View {
        ZStack {
            NCVideoPlaybackCoverView(
                previewURL: previewURL,
                isPlayEnabled: false,
                isLoading: false,
                isLaunchingPlayback: false,
                statusMessage: nil,
                onCancel: nil,
                onToggleChrome: onToggleChrome,
                onPlay: { }
            )

            VStack(spacing: 12) {
                Image(systemName: "video.slash")
                    .font(.system(size: 44, weight: .regular))

                Text(NSLocalizedString("_video_not_available_", comment: ""))
                    .font(.headline)

                Button {
                    retryPlayback()
                } label: {
                    Label(
                        NSLocalizedString("_retry_", comment: ""),
                        systemImage: "arrow.clockwise"
                    )
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
            }
            .foregroundStyle(.white)
            .padding(24)
            .background(.black.opacity(0.36), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

// MARK: - Playback Cover

private extension NCVideoViewerContentView {
    var isPlaybackCoverLoading: Bool {
        guard isSelected else {
            return false
        }

        if requiresUserTrustedCertificateDownload {
            return isDownloadingPlayback
        }

        if case .loading = playback.engine {
            return true
        }

        return false
    }

    var isPlaybackCoverPlayEnabled: Bool {
        guard isSelected else {
            return false
        }

        if requiresUserTrustedCertificateDownload {
            return downloadVideo != nil && !isDownloadingPlayback
        }

        guard isCurrentPlaybackVideo() else {
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
    func playFromCover() {
        guard isPlaybackCoverPlayEnabled,
              !isLaunchingPlayback else {
            return
        }

        isLaunchingPlayback = true

        if requiresUserTrustedCertificateDownload {
            downloadAndPlayVideo()
            return
        }

        switch playback.engine {
        case .avFoundation(let preparedPlayback):
            requestAVPlayerPresentation(preparedPlayback: preparedPlayback)

        case .vlc(let preparedPlayback):
            requestVLCPresentation(preparedPlayback: preparedPlayback)

        case .loading,
             .failed:
            isLaunchingPlayback = false
        }
    }

    func playbackPresentationPlaceholder(
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
}

// MARK: - Loading

private extension NCVideoViewerContentView {
    var taskIdentifier: String {
        let localIdentifier = localURL?.absoluteString ?? "remote"
        return "\(metadata.ocId)|\(metadata.etag)|\(localIdentifier)"
    }

    @MainActor
    func stopPlaybackForDeselection() {
        cancelPlaybackDownload()

        guard isCurrentPlaybackVideo() else { return }

        NCVideoAVPlayerPresenter.dismiss()
        NCVideoVLCPresenter.dismiss {
            resetPlaybackPresentationState()
            playback.stopIfCurrent(ocId: metadata.ocId)
        }
    }

    @MainActor
    func loadVideoIfSelected() async {
        let expectedTaskIdentifier = taskIdentifier
        let expectedLoadGeneration = loadGeneration

        guard isStableSelection(
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

    @MainActor
    func isStableSelection(
        expectedTaskIdentifier: String,
        expectedLoadGeneration: UUID
    ) -> Bool {
        guard !Task.isCancelled else {
            return false
        }

        guard isSelected else {
            return false
        }

        guard expectedTaskIdentifier == taskIdentifier else {
            return false
        }

        guard expectedLoadGeneration == loadGeneration else {
            return false
        }

        return true
    }

    @MainActor
    func resolveAndLoadVideo(
        expectedTaskIdentifier: String,
        expectedLoadGeneration: UUID
    ) async {
        errorMessage = nil

        if let localURL {
            loadResolvedVideo(
                url: localURL,
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
            expectedTaskIdentifier: expectedTaskIdentifier,
            expectedLoadGeneration: expectedLoadGeneration
        )
    }

    @MainActor
    func loadResolvedVideo(
        url: URL,
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

        hasRequestedPlayback = false
        resolvedPlaybackURL = url

        if requiresUserTrustedCertificateDownload(for: url) {
            playback.stopIfCurrent(ocId: metadata.ocId)
            return
        }

        playback.loadVideo(
            metadata: metadata,
            url: url,
            fileName: resolvedFileName,
            userAgent: userAgent,
            httpHeaders: httpHeaders(for: url)
        )
    }

    func httpHeaders(for url: URL) -> [String: String] {
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
}

// MARK: - User-Trusted Certificate Download

private extension NCVideoViewerContentView {
    var requiresUserTrustedCertificateDownload: Bool {
        guard localURL == nil,
              let resolvedPlaybackURL else {
            return false
        }

        return requiresUserTrustedCertificateDownload(for: resolvedPlaybackURL)
    }

    func requiresUserTrustedCertificateDownload(for url: URL) -> Bool {
        guard !url.isFileURL else {
            return false
        }

        if forceDownloadBeforePlaybackForTesting {
            return true
        }

        let hosts = [
            url.host,
            URL(string: metadata.urlBase)?.host
        ]
        .compactMap { $0 }

        return hosts.contains { host in
            NCNetworking.shared.requiresUserTrustedCertificate(for: host)
        }
    }

    @MainActor
    func downloadAndPlayVideo() {
        guard let downloadVideo else {
            consumePendingAutoPlayIfNeeded()
            isLaunchingPlayback = false
            errorMessage = ""
            return
        }

        let expectedTaskIdentifier = taskIdentifier
        let expectedLoadGeneration = loadGeneration

        playbackDownloadTask?.cancel()
        isDownloadingPlayback = true
        errorMessage = nil

        playbackDownloadTask = Task { @MainActor in
            do {
                let downloadedURL = try await downloadVideo()
                try Task.checkCancellation()

                guard isStableSelection(
                    expectedTaskIdentifier: expectedTaskIdentifier,
                    expectedLoadGeneration: expectedLoadGeneration
                ) else {
                    return
                }

                playbackDownloadTask = nil
                isDownloadingPlayback = false
                resolvedPlaybackURL = downloadedURL
                hasRequestedPlayback = true

                playback.loadVideo(
                    metadata: metadata,
                    url: downloadedURL,
                    fileName: resolvedFileName,
                    userAgent: userAgent,
                    httpHeaders: [:]
                )
            } catch is CancellationError {
                return
            } catch {
                guard expectedTaskIdentifier == taskIdentifier,
                      expectedLoadGeneration == loadGeneration,
                      isSelected else {
                    return
                }

                playbackDownloadTask = nil
                isDownloadingPlayback = false
                isLaunchingPlayback = false
                consumePendingAutoPlayIfNeeded()
                errorMessage = ""
            }
        }
    }

    @MainActor
    func cancelPlaybackDownload() {
        guard playbackDownloadTask != nil || isDownloadingPlayback else {
            return
        }

        playbackDownloadTask?.cancel()
        playbackDownloadTask = nil
        isDownloadingPlayback = false
        isLaunchingPlayback = false
        hasRequestedPlayback = false
        consumePendingAutoPlayIfNeeded()

        guard let cancelVideoDownload else {
            return
        }

        Task { @MainActor in
            await cancelVideoDownload()
        }
    }
}

// MARK: - Playback Selection

private extension NCVideoViewerContentView {
    func isCurrentPlaybackVideo() -> Bool {
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

    @MainActor
    func revealCurrentPlaybackIfNeeded() {
        guard hasRequestedPlayback else {
            return
        }

        switch playback.engine {
        case .avFoundation(let preparedPlayback):
            presentAVPlayerIfSelected(preparedPlayback: preparedPlayback)

        case .vlc(let preparedPlayback):
            presentVLCIfSelected(preparedPlayback: preparedPlayback)

        case .loading,
             .failed:
            break
        }
    }
}

// MARK: - Fullscreen Playback State

extension NCVideoViewerContentView {
    @MainActor
    func closeFromFullscreenVideo(ocId: String?) {
        onClose?(ocId)
    }

    @MainActor
    func resetPlaybackPresentationState() {
        presentedAVPlayerURL = nil
        presentedVLCURL = nil
        hasRequestedPlayback = false
        isLaunchingPlayback = false
    }

    @MainActor
    func consumePendingAutoPlayIfNeeded() {
        guard shouldAutoPlay else {
            return
        }

        onAutoPlayConsumed?()
    }

    @MainActor
    func showPlaybackError() {
        resetPlaybackPresentationState()
        playback.stopIfCurrent(ocId: metadata.ocId)
        errorMessage = ""
    }

    @MainActor
    func retryPlayback() {
        errorMessage = nil
        resetPlaybackPresentationState()
        playback.stopIfCurrent(ocId: metadata.ocId)
        loadGeneration = UUID()

        Task {
            await loadVideoIfSelected()
        }
    }

}

// MARK: - URL Resolution

private extension NCVideoViewerContentView {
    @MainActor
    func resolvedVideoURL(
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
}

// MARK: - Helpers

private extension NCVideoViewerContentView {
    var resolvedFileName: String {
        if !metadata.fileNameView.isEmpty {
            return metadata.fileNameView
        }

        return metadata.fileName
    }
}
