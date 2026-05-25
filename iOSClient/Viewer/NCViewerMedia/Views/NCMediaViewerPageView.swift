// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

// MARK: - Media Viewer Page View

struct NCMediaViewerPageView: View {

    // MARK: - Properties

    let page: NCMediaViewerPageModel
    let isChromeHidden: Bool
    let onToggleChrome: () -> Void
    let isSelected: Bool

    let canGoPrevious: Bool
    let canGoNext: Bool
    let shouldAutoPlay: Bool
    let onPreviousPage: (_ shouldAutoPlay: Bool) -> Void
    let onNextPage: (_ shouldAutoPlay: Bool) -> Void
    let onClose: (_ ocId: String?) -> Void
    let onAutoPlayConsumed: () -> Void

    let contextMenuController: NCMainTabBarController?
    let navigationBar: UINavigationBar?

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.ncViewerBackground(backgroundStyle)
                .ignoresSafeArea()

            switch page.state {
            case .idle,
                 .loadingMetadata,
                 .checkingLocalFile:
                Color.ncViewerBackground(backgroundStyle)
                    .ignoresSafeArea()

            case .metadataMissing:
                metadataMissingView

            case .image(let previewURL, let localURL, let livePhotoURL, _):
                imageStateView(
                    previewURL: previewURL,
                    localURL: localURL,
                    livePhotoURL: livePhotoURL
                )

            case .video(let previewURL):
                videoStateView(previewURL: previewURL)

            case .downloading(let previewURL, let progress):
                downloadingStateView(
                    previewURL: previewURL,
                    progress: progress
                )

            case .ready(let localURL, let previewURL):
                readyStateView(
                    localURL: localURL,
                    previewURL: previewURL
                )

            case .deleted:
                deletedView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(chromeToggleGesture())

            case .failed(let previewURL, let message):
                failedStateView(
                    previewURL: previewURL,
                    message: message
                )
            }
        }
        .background(Color.ncViewerBackground(backgroundStyle))
        .ignoresSafeArea()
    }

    // MARK: - Computed Properties

    private var backgroundStyle: NCViewerBackgroundStyle {
        if isChromeHidden {
            return .black
        }

        guard let metadata = page.metadata else {
            return .system
        }

        switch metadata.classFile {
        case NKTypeClassFile.audio.rawValue,
             NKTypeClassFile.video.rawValue:
            return .black

        default:
            return ncViewerBackgroundStyle(for: metadata)
        }
    }

    // Neighbor pages must not consume auto-play.
    private var effectiveShouldAutoPlay: Bool {
        isSelected && shouldAutoPlay
    }

    private func goToPreviousPage(_ requestedAutoPlay: Bool) {
        guard canGoPrevious else {
            return
        }

        onPreviousPage(
            isSelected && requestedAutoPlay
        )
    }

    private func goToNextPage(_ requestedAutoPlay: Bool) {
        guard canGoNext else {
            return
        }

        onNextPage(
            isSelected && requestedAutoPlay
        )
    }

    private func consumeAutoPlayIfNeeded() {
        guard isSelected else {
            return
        }

        onAutoPlayConsumed()
    }

    // Video controllers delegate boundary checks to the paging coordinator.
    private func goToPreviousPageFromVideo() {
        onPreviousPage(false)
    }

    private func goToNextPageFromVideo() {
        onNextPage(false)
    }

    // MARK: - State Views

    private var metadataMissingView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 44, weight: .regular))

            Text("Media not available")
                .font(.headline)
        }
        .foregroundStyle(primaryForegroundStyle)
        .multilineTextAlignment(.center)
        .padding()
    }

    private var deletedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "trash")
                .font(.system(size: 44, weight: .regular))

            Text(NSLocalizedString("_media_no_longer_available_", comment: ""))
                .font(.headline)

            Text(NSLocalizedString("_this_item_has_been_deleted_", comment: ""))
                .font(.caption)
                .foregroundStyle(secondaryForegroundStyle)
        }
        .foregroundStyle(primaryForegroundStyle)
        .multilineTextAlignment(.center)
        .padding(24)
    }

    @ViewBuilder
    private func imageStateView(
        previewURL: URL?,
        localURL: URL?,
        livePhotoURL: URL?
    ) -> some View {
        if previewURL != nil || localURL != nil {
            imageContentView(
                previewURL: previewURL,
                localURL: localURL,
                livePhotoURL: livePhotoURL,
                backgroundStyle: backgroundStyle
            )
        } else {
            Color.ncViewerBackground(backgroundStyle)
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func videoStateView(previewURL: URL?) -> some View {
        if let metadata = page.metadata {
            NCVideoViewerContentView(
                metadata: metadata,
                localURL: nil,
                isSelected: isSelected,
                contextMenuController: contextMenuController,
                navigationBar: navigationBar,
                canGoPrevious: canGoPrevious,
                canGoNext: canGoNext,
                onPreviousPage: goToPreviousPageFromVideo,
                onNextPage: goToNextPageFromVideo,
                onClose: onClose
            )
            .id("\(page.ocId)-remote")
            .background(Color.ncViewerBackground(backgroundStyle))
        } else {
            metadataMissingView
        }
    }

    @ViewBuilder
    private func downloadingStateView(
        previewURL: URL?,
        progress: Double?
    ) -> some View {
        if page.metadata?.classFile == NKTypeClassFile.video.rawValue,
           isSelected {
            videoStateView(previewURL: previewURL)
        } else if page.metadata?.classFile == NKTypeClassFile.audio.rawValue {
            Color.ncViewerBackground(backgroundStyle)
                .ignoresSafeArea()
        } else if let previewURL {
            previewOnlyView(previewURL: previewURL)
        } else {
            Color.ncViewerBackground(backgroundStyle)
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func readyStateView(
        localURL: URL,
        previewURL: URL?
    ) -> some View {
        if let metadata = page.metadata {
            switch metadata.classFile {
            case NKTypeClassFile.video.rawValue:
                NCVideoViewerContentView(
                    metadata: metadata,
                    localURL: localURL,
                    isSelected: isSelected,
                    contextMenuController: contextMenuController,
                    navigationBar: navigationBar,
                    canGoPrevious: canGoPrevious,
                    canGoNext: canGoNext,
                    onPreviousPage: goToPreviousPageFromVideo,
                    onNextPage: goToNextPageFromVideo,
                    onClose: onClose
                )
                .id("\(page.ocId)-local-\(localURL.absoluteString)")
                .background(Color.ncViewerBackground(backgroundStyle))

            case NKTypeClassFile.audio.rawValue:
                NCAudioViewerContentView(
                    metadata: metadata,
                    localURL: localURL,
                    previewURL: previewURL,
                    canGoPrevious: canGoPrevious,
                    canGoNext: canGoNext,
                    shouldAutoPlay: effectiveShouldAutoPlay,
                    onPrevious: goToPreviousPage,
                    onNext: goToNextPage,
                    onAutoPlayConsumed: consumeAutoPlayIfNeeded
                )
                .background(Color.black)

            default:
                imageContentView(
                    previewURL: previewURL,
                    localURL: localURL,
                    livePhotoURL: nil,
                    backgroundStyle: backgroundStyle
                )
            }
        } else {
            metadataMissingView
        }
    }

    @ViewBuilder
    private func failedStateView(
        previewURL: URL?,
        message: String
    ) -> some View {
        if let previewURL {
            previewOnlyView(previewURL: previewURL)
        } else {
            Color.ncViewerBackground(backgroundStyle)
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func imageContentView(
        previewURL: URL?,
        localURL: URL?,
        livePhotoURL: URL?,
        backgroundStyle: NCViewerBackgroundStyle
    ) -> some View {
        if page.metadata?.isLivePhoto == true {
            NCLivePhotoViewerContentView(
                identifier: page.ocId,
                previewURL: previewURL,
                fullURL: localURL,
                videoURL: livePhotoURL,
                backgroundStyle: backgroundStyle,
                topOverlayInset: livePhotoTopOverlayInset
            )
            .background(Color.ncViewerBackground(backgroundStyle))
            .contentShape(Rectangle())
            .gesture(chromeToggleGesture())
        } else {
            NCImageViewerContentView(
                identifier: page.ocId,
                previewURL: previewURL,
                fullURL: localURL,
                backgroundStyle: backgroundStyle
            )
            .contentShape(Rectangle())
            .gesture(chromeToggleGesture())
        }
    }

    @ViewBuilder
    private func previewOnlyView(previewURL: URL) -> some View {
        NCImageViewerContentView(
            identifier: page.ocId,
            previewURL: previewURL,
            fullURL: nil,
            backgroundStyle: backgroundStyle
        )
        .contentShape(Rectangle())
        .gesture(chromeToggleGesture())
    }

    // Keep double tap reserved for image zoom.
    private func chromeToggleGesture() -> some Gesture {
        TapGesture(count: 2)
            .exclusively(
                before: TapGesture(count: 1)
            )
            .onEnded { value in
                switch value {
                case .first:
                    break

                case .second:
                    onToggleChrome()
                }
            }
    }

    // MARK: - Appearance Helpers

    private var primaryForegroundStyle: Color {
        switch backgroundStyle {
        case .black:
            return .white.opacity(0.85)

        case .system,
             .white,
             .custom:
            return .primary
        }
    }

    private var secondaryForegroundStyle: Color {
        switch backgroundStyle {
        case .black:
            return .white.opacity(0.85)

        case .system,
             .white,
             .custom:
            return .secondary
        }
    }

    // MARK: - Helpers

    private var livePhotoTopOverlayInset: CGFloat {
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        let window = windowScene?.windows.first { $0.isKeyWindow }
        let safeTop = window?.safeAreaInsets.top ?? 0

        return safeTop + 44 + 8
    }
}
