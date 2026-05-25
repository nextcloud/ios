// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

// MARK: - Video Viewer Content View

struct NCVideoViewerContentView: View {
    let metadata: tableMetadata
    let localURL: URL?
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
            // Ignore layout-driven disappear events.
        }
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "video.slash")
                .font(.system(size: 44, weight: .regular))

            Text(NSLocalizedString("_video_not_available_", comment: ""))
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

    @MainActor
    private func loadResolvedVideo(
        url: URL,
        autoplay: Bool,
        expectedTaskIdentifier: String,
        expectedLoadGeneration: UUID,
        source: String
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
    }

    @MainActor
    private func goToPreviousPageFromAVPlayer() {
        presentedAVPlayerURL = nil
        NCVideoAVPlayerPresenter.dismiss()
        onPreviousPage?()
    }

    @MainActor
    private func goToNextPageFromAVPlayer() {
        presentedAVPlayerURL = nil
        NCVideoAVPlayerPresenter.dismiss()
        onNextPage?()
    }

    @MainActor
    private func closeFromFullscreenVideo(ocId: String?) {
        presentedAVPlayerURL = nil
        presentedVLCURL = nil
        playback.stop()
        onClose?(ocId)
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
    }

    @MainActor
    private func goToPreviousPageFromVLC() {
        presentedVLCURL = nil
        NCVideoVLCPresenter.dismiss()
        onPreviousPage?()
    }

    @MainActor
    private func goToNextPageFromVLC() {
        presentedVLCURL = nil
        NCVideoVLCPresenter.dismiss()
        onNextPage?()
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

    // Prevent transient video pages from starting playback work.
    private static let videoSelectionSettleDelayNanoseconds: UInt64 = 150_000_000

    private var resolvedFileName: String {
        if !metadata.fileNameView.isEmpty {
            return metadata.fileNameView
        }

        return metadata.fileName
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
                        autoplay: false,
                        error: error
                    )
                )
            }
        }
    }
}
