// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

// MARK: - Video Viewer Content View

/// Displays a video using the shared video playback controller.
///
/// This view does not own the AVPlayer directly.
/// AVFoundation playback is presented as a separate UIKit-only controller through
/// `NCVideoAVPlayerPresenter`, outside the SwiftUI paging hierarchy.
/// VLC playback is presented as a separate UIKit-only controller through
/// `NCVideoVLCPresenter`, outside the SwiftUI paging hierarchy.
///
/// Loading rules:
/// - If a valid local URL is already available, it is used directly.
/// - The remote resolver is used only when no local URL is available.
/// - If the same video is already loaded, the existing player is reused.
/// - If the page is not selected, the view does not load a new video.
/// - AVFoundation is presented outside SwiftUI when selected.
/// - VLC is presented outside SwiftUI when selected.
/// - Real global stop events are handled through `.ncMediaViewerStopPlayback`.
struct NCVideoViewerContentView: View {
    let metadata: tableMetadata
    let localURL: URL?
    let previewURL: URL?
    let userAgent: String?
    let isSelected: Bool
    let contextMenuController: NCMainTabBarController?
    let navigationBar: UINavigationBar?
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onPreviousPage: (() -> Void)?
    let onNextPage: (() -> Void)?
    let onClose: ((_ ocId: String?) -> Void)?

    @ObservedObject private var playback = NCVideoPlaybackController.shared

    @State private var errorMessage: String?
    @State private var presentedAVPlayerURL: URL?
    @State private var resolvedVideoURL: URL?
    @State private var presentedVLCURL: URL?
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
        contextMenuController: NCMainTabBarController? = nil,
        navigationBar: UINavigationBar? = nil,
        canGoPrevious: Bool = false,
        canGoNext: Bool = false,
        onPreviousPage: (() -> Void)? = nil,
        onNextPage: (() -> Void)? = nil,
        onClose: ((_ ocId: String?) -> Void)? = nil
    ) {
        self.metadata = metadata
        self.localURL = localURL
        self.previewURL = previewURL
        self.userAgent = userAgent
        self.isSelected = isSelected
        self.contextMenuController = contextMenuController
        self.navigationBar = navigationBar
        self.canGoPrevious = canGoPrevious
        self.canGoNext = canGoNext
        self.onPreviousPage = onPreviousPage
        self.onNextPage = onNextPage
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            previewPlaceholderView

            if let errorMessage {
                failedView(errorMessage)
            } else {
                switch playback.engine {
                case .loading:
                    EmptyView()

                case .avFoundation(let url):
                    if isSelected,
                       isCurrentPlaybackVideo() {
                        Color.clear
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                            .onAppear {
                                presentAVPlayerIfSelected(url: url)
                            }
                            .onChange(of: url) { _, newURL in
                                presentedAVPlayerURL = nil
                                presentAVPlayerIfSelected(url: newURL)
                            }
                            .onChange(of: isSelected) { _, selected in
                                guard selected else {
                                    return
                                }

                                presentAVPlayerIfSelected(url: url)
                            }
                    } else {
                        EmptyView()
                    }

                case .vlc(let url):
                    if isSelected,
                       isCurrentPlaybackVideo() {
                        Color.clear
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                            .onAppear {
                                presentVLCIfSelected(url: url)
                            }
                            .onChange(of: url) { _, newURL in
                                presentedVLCURL = nil
                                presentVLCIfSelected(url: newURL)
                            }
                            .onChange(of: isSelected) { _, selected in
                                guard selected else {
                                    return
                                }

                                presentVLCIfSelected(url: url)
                            }
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
        .background(Color.black)
        .task(id: taskIdentifier) {
            await loadVideoIfSelected()
        }
        .onChange(of: isSelected) { _, selected in
            loadGeneration = UUID()

            guard selected else {
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
            // Do not stop or hide the player here.
            // SwiftUI can call onDisappear during rotation or layout rebuilds.
            // Real playback stops are driven by `.ncMediaViewerStopPlayback`.
        }
    }

    // MARK: - Views

    @ViewBuilder
    private var previewPlaceholderView: some View {
        NCVideoPreviewPlaceholderView(previewURL: previewURL)
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "video.slash")
                .font(.system(size: 44, weight: .regular))

            Text("Video not available")
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .foregroundStyle(.white)
        .padding(24)
    }

    // MARK: - Loading

    /// Stops fullscreen video playback when this video page is no longer selected.
    ///
    /// This is intentionally not done from `onDisappear`, because SwiftUI may call
    /// `onDisappear` during rotation or layout rebuilds. A transition from selected
    /// to not selected is instead a real page change.
    @MainActor
    private func stopPlaybackForDeselection() {
        presentedAVPlayerURL = nil
        resolvedVideoURL = nil
        presentedVLCURL = nil

        NCVideoAVPlayerPresenter.dismiss()
        NCVideoVLCPresenter.dismiss()
        playback.stop()
    }

    private var taskIdentifier: String {
        let localIdentifier = localURL?.absoluteString ?? "remote"
        return "\(metadata.ocId)|\(metadata.etag)|\(localIdentifier)"
    }

    /// Loads or reveals the video only when this page is still selected and stable.
    ///
    /// This is the single entry point for selected video loading.
    /// It is used by both `.task(id:)` and `isSelected` changes because SwiftUI may
    /// create a video page before it becomes selected, and `.task(id:)` may not run
    /// again when the same page later becomes selected.
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

    /// Waits briefly before allowing a selected video page to resolve or load playback.
    ///
    /// Fast swipe gestures can make intermediate video pages selected for a very short time.
    /// This gate keeps those transient pages as preview-only without slowing image paging,
    /// because it exists only inside the video viewer.
    ///
    /// - Parameters:
    ///   - expectedTaskIdentifier: Task identity captured before the delay.
    ///   - expectedLoadGeneration: Load generation captured before the delay.
    /// - Returns: True if the page is still selected and still represents the same load request.
    @MainActor
    private func waitForStableSelection(
        expectedTaskIdentifier: String,
        expectedLoadGeneration: UUID
    ) async -> Bool {
        guard isSelected else {
            return false
        }

        do {
            try await Task.sleep(nanoseconds: Self.videoSelectionSettleDelayNanoseconds)
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

    /// Resolves the playable video URL and loads it into the shared playback controller.
    ///
    /// Local URLs are loaded directly and have priority over remote resolution.
    ///
    /// - Parameters:
    ///   - expectedTaskIdentifier: Task identity captured before starting async resolution.
    ///   - expectedLoadGeneration: Load generation captured before starting async resolution.
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
                expectedLoadGeneration: expectedLoadGeneration,
                source: "local"
            )
            return
        }

        nkLog(
            tag: NCGlobal.shared.logTagViewer,
            emoji: .debug,
            message: "VIDEO resolve start ocId \(metadata.ocId), fileName \(metadata.fileNameView), fileId \(metadata.fileId)",
            consoleOnly: true
        )

        let result = await resolvedVideoURL(
            taskIdentifier: expectedTaskIdentifier
        )

        guard !Task.isCancelled else {
            nkLog(
                tag: NCGlobal.shared.logTagViewer,
                emoji: .debug,
                message: "VIDEO resolve cancelled ocId \(metadata.ocId)",
                consoleOnly: true
            )
            return
        }

        guard expectedTaskIdentifier == taskIdentifier else {
            nkLog(
                tag: NCGlobal.shared.logTagViewer,
                emoji: .debug,
                message: "VIDEO resolve ignored stale task ocId \(metadata.ocId)",
                consoleOnly: true
            )
            return
        }

        guard expectedLoadGeneration == loadGeneration else {
            nkLog(
                tag: NCGlobal.shared.logTagViewer,
                emoji: .debug,
                message: "VIDEO resolve ignored stale generation ocId \(metadata.ocId)",
                consoleOnly: true
            )
            return
        }

        guard isSelected else {
            nkLog(
                tag: NCGlobal.shared.logTagViewer,
                emoji: .debug,
                message: "VIDEO resolve skipped final not selected ocId \(metadata.ocId), fileName \(metadata.fileNameView)",
                consoleOnly: true
            )
            return
        }

        guard result.error == .success,
              let url = result.url else {
            nkLog(
                tag: NCGlobal.shared.logTagViewer,
                emoji: .error,
                message: "VIDEO resolve failed ocId \(metadata.ocId), error \(result.error.errorDescription)",
                consoleOnly: true
            )

            errorMessage = result.error.errorDescription
            return
        }

        loadResolvedVideo(
            url: url,
            autoplay: result.autoplay,
            expectedTaskIdentifier: expectedTaskIdentifier,
            expectedLoadGeneration: expectedLoadGeneration,
            source: "resolved"
        )
    }

    /// Loads a resolved video URL into the shared playback controller.
    ///
    /// - Parameters:
    ///   - url: Local or remote playable URL.
    ///   - autoplay: Whether the resolved URL requests autoplay.
    ///   - expectedTaskIdentifier: Task identity used to ignore stale async work.
    ///   - expectedLoadGeneration: Load generation used to ignore stale async work.
    ///   - source: Debug source label used in logs.
    @MainActor
    private func loadResolvedVideo(
        url: URL,
        autoplay: Bool,
        expectedTaskIdentifier: String,
        expectedLoadGeneration: UUID,
        source: String
    ) {
        guard expectedTaskIdentifier == taskIdentifier else {
            nkLog(
                tag: NCGlobal.shared.logTagViewer,
                emoji: .debug,
                message: "VIDEO load ignored stale task ocId \(metadata.ocId), source \(source), url \(url.absoluteString)",
                consoleOnly: true
            )
            return
        }

        guard expectedLoadGeneration == loadGeneration else {
            nkLog(
                tag: NCGlobal.shared.logTagViewer,
                emoji: .debug,
                message: "VIDEO load ignored stale generation ocId \(metadata.ocId), source \(source), url \(url.absoluteString)",
                consoleOnly: true
            )
            return
        }

        guard isSelected else {
            nkLog(
                tag: NCGlobal.shared.logTagViewer,
                emoji: .debug,
                message: "VIDEO load skipped not selected ocId \(metadata.ocId), source \(source), url \(url.absoluteString)",
                consoleOnly: true
            )
            return
        }

        nkLog(
            tag: NCGlobal.shared.logTagViewer,
            emoji: .debug,
            message: "VIDEO load \(source) url \(url.absoluteString), isFileURL \(url.isFileURL), fileName \(resolvedFileName)",
            consoleOnly: true
        )

        resolvedVideoURL = url

        playback.loadVideo(
            metadata: metadata,
            url: url,
            fileName: resolvedFileName,
            userAgent: userAgent,
            httpHeaders: httpHeaders(for: url),
            shouldAutoPlay: autoplay
        )
    }

    /// Returns HTTP headers for remote video playback.
    ///
    /// Local file URLs do not need HTTP headers.
    ///
    /// - Parameter url: Resolved video URL.
    /// - Returns: HTTP headers for AVFoundation remote playback.
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

    /// Returns whether this page already owns an active playback engine.
    ///
    /// Local videos require an exact URL match.
    /// Remote videos can only be checked by metadata because the direct-download URL
    /// is resolved lazily when the selected page loads.
    ///
    /// The playback engine must already be renderable. A loading or failed engine is
    /// not considered reusable, otherwise a cached video page could remain stuck as a
    /// plain preview when it becomes selected again.
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

    /// Reveals the current playback engine without changing the playback state.
    ///
    /// This is used when SwiftUI rebuilds the selected page, for example during
    /// rotation. It must not call `play()` because the user may have paused the video.
    @MainActor
    private func revealCurrentPlaybackIfNeeded() {
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

    /// Presents the UIKit-only AVPlayer viewer when this page is selected.
    ///
    /// - Parameter url: Local or remote playable URL selected by AVFoundation probing.
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
            previewURL: previewURL,
            userAgent: userAgent,
            contextMenuController: contextMenuController,
            canGoPrevious: canGoPrevious,
            canGoNext: canGoNext,
            onPrevious: goToPreviousPageFromAVPlayer,
            onNext: goToNextPageFromAVPlayer,
            onClose: closeFromFullscreenVideo
        )
    }

    /// Moves to the previous media item from the UIKit-only AVPlayer controller.
    @MainActor
    private func goToPreviousPageFromAVPlayer() {
        presentedAVPlayerURL = nil
        NCVideoAVPlayerPresenter.dismiss()
        onPreviousPage?()
    }

    /// Moves to the next media item from the UIKit-only AVPlayer controller.
    @MainActor
    private func goToNextPageFromAVPlayer() {
        presentedAVPlayerURL = nil
        NCVideoAVPlayerPresenter.dismiss()
        onNextPage?()
    }

    /// Closes the full media viewer from a fullscreen video controller.
    ///
    /// - Parameter ocId: Optional Nextcloud file identifier of the fullscreen video being closed.
    @MainActor
    private func closeFromFullscreenVideo(ocId: String?) {
        presentedAVPlayerURL = nil
        presentedVLCURL = nil
        playback.stop()
        onClose?(ocId)
    }

    /// Presents the UIKit-only VLC fallback viewer when this page is selected.
    ///
    /// - Parameter url: Local or remote playable URL.
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
            previewURL: previewURL,
            userAgent: userAgent,
            contextMenuController: contextMenuController,
            canGoPrevious: canGoPrevious,
            canGoNext: canGoNext,
            onPrevious: goToPreviousPageFromVLC,
            onNext: goToNextPageFromVLC,
            onClose: closeFromFullscreenVideo
        )
    }

    /// Moves to the previous media item from the UIKit-only VLC controller.
    @MainActor
    private func goToPreviousPageFromVLC() {
        presentedVLCURL = nil
        NCVideoVLCPresenter.dismiss()
        onPreviousPage?()
    }

    /// Moves to the next media item from the UIKit-only VLC controller.
    @MainActor
    private func goToNextPageFromVLC() {
        presentedVLCURL = nil
        NCVideoVLCPresenter.dismiss()
        onNextPage?()
    }

    // MARK: - In-Flight Resolution Cache

    /// Resolves a video URL through a shared in-flight task cache.
    ///
    /// SwiftUI can temporarily create multiple video page views for the same page while
    /// the selected state transitions from prefetched preview to selected video state.
    /// A shared task lets duplicated views await the same direct-link resolution instead
    /// of starting duplicate requests or skipping resolution while the original view is
    /// being cancelled.
    ///
    /// - Parameter taskIdentifier: Stable video task identity.
    /// - Returns: Resolved video URL, autoplay preference, and Nextcloud error.
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

    /// Delay used only for selected video pages before resolving or loading playback.
    ///
    /// This protects fast swipe gestures from starting remote resolution or VLC/AVPlayer
    /// for transient video pages, without affecting image paging responsiveness.
    private static let videoSelectionSettleDelayNanoseconds: UInt64 = 150_000_000

    private var resolvedFileName: String {
        if !metadata.fileNameView.isEmpty {
            return metadata.fileNameView
        }

        return metadata.fileName
    }
}

// MARK: - Video Preview Placeholder

/// Displays a static, non-interactive preview for video pages.
///
/// Video previews are shown only when a local preview image is already available.
/// When no preview is available, the view keeps a stable black background to avoid
/// extra icon-to-preview-to-player transitions.
private struct NCVideoPreviewPlaceholderView: View {
    let previewURL: URL?

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let image = previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .allowsHitTesting(false)
            }
        }
    }

    private var previewImage: UIImage? {
        guard let previewURL,
              previewURL.isFileURL else {
            return nil
        }

        return UIImage(contentsOfFile: previewURL.path)
    }
}

// MARK: - Video URL Resolution

/// Resolves the playable URL for a video item.
///
/// Resolution order:
/// - Explicit metadata URL.
/// - Local provider storage file.
/// - Nextcloud direct download URL.
struct NCVideoURLResolver {
    private let utilityFileSystem = NCUtilityFileSystem()

    /// Resolves the playable URL for a video metadata object.
    ///
    /// - Parameter metadata: Video metadata.
    /// - Returns: Resolved video URL, autoplay preference, and Nextcloud error.
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

    /// Resolves a direct download URL from Nextcloud.
    ///
    /// - Parameter metadata: Video metadata.
    /// - Returns: Direct download URL, autoplay preference, and Nextcloud error.
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
                        autoplay: false,
                        error: error
                    )
                )
            }
        }
    }
}
