// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

// MARK: - Media Viewer Page View

struct NCMediaViewerPageView: View {
    @ObservedObject var model: NCMediaViewerModel
    @ObservedObject var page: NCMediaViewerPageModel

    let onToggleChrome: () -> Void

    let canGoPrevious: Bool
    let canGoNext: Bool
    let shouldAutoPlay: Bool
    let onPreviousPage: (_ shouldAutoPlay: Bool) -> Void
    let onNextPage: (_ shouldAutoPlay: Bool) -> Void
    let onClose: (_ ocId: String?) -> Void
    let onAutoPlayConsumed: () -> Void
    let onZoomChanged: (Bool) -> Void

    let contextMenuController: NCMainTabBarController?
    let navigationBar: UINavigationBar?

    private var isSelected: Bool {
        model.selectedIndex == page.index
    }

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

            case .video(let localURL, let previewURL):
                videoStateView(
                    localURL: localURL,
                    previewURL: previewURL
                )

            case .audio(let localURL, let previewURL):
                audioStateView(
                    localURL: localURL,
                    previewURL: previewURL
                )

            case .downloading(let previewURL, let progress):
                downloadingStateView(
                    previewURL: previewURL,
                    progress
                )

            case .ready(let localURL, let previewURL):
                genericReadyStateView(
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
                    message
                )
            }
        }
        .background(Color.ncViewerBackground(backgroundStyle))
        .ignoresSafeArea()
    }

    private var backgroundStyle: NCViewerBackgroundStyle {
        ncViewerBackgroundStyle(
            for: page.metadata,
            isChromeHidden: model.isChromeHidden
        )
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

            Text(NSLocalizedString("_media_not_available_", comment: ""))
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
            imagePlaceholderView
        }
    }

    @ViewBuilder
    private func videoStateView(
        localURL: URL?,
        previewURL: URL?
    ) -> some View {
        if let metadata = page.metadata {
            NCVideoViewerContentView(
                metadata: metadata,
                localURL: localURL,
                previewURL: previewURL,
                isSelected: isSelected,
                isChromeHidden: model.isChromeHidden,
                contextMenuController: contextMenuController,
                navigationBar: navigationBar,
                canGoPrevious: canGoPrevious,
                canGoNext: canGoNext,
                onPreviousPage: goToPreviousPageFromVideo,
                onNextPage: goToNextPageFromVideo,
                onToggleChrome: onToggleChrome,
                onClose: onClose
            )
            .id("\(page.ocId)-remote")
            .background(Color.ncViewerBackground(backgroundStyle))
        } else {
            metadataMissingView
        }
    }

    @ViewBuilder
    private func audioStateView(
        localURL: URL,
        previewURL: URL?
    ) -> some View {
        if let metadata = page.metadata {
            NCAudioViewerContentView(
                metadata: metadata,
                localURL: localURL,
                previewURL: previewURL,
                backgroundStyle: backgroundStyle,
                canGoPrevious: canGoPrevious,
                canGoNext: canGoNext,
                shouldAutoPlay: effectiveShouldAutoPlay,
                onPrevious: goToPreviousPage,
                onNext: goToNextPage,
                onAutoPlayConsumed: consumeAutoPlayIfNeeded,
                onToggleChrome: onToggleChrome
            )
            .background(Color.ncViewerBackground(backgroundStyle))
        } else {
            metadataMissingView
        }
    }

    @ViewBuilder
    private func downloadingStateView(
        previewURL: URL?,
        _ progress: Double?
    ) -> some View {
        switch page.metadata?.classFile {
        case NKTypeClassFile.video.rawValue:
            if isSelected {
                videoStateView(
                    localURL: nil,
                    previewURL: previewURL
                )
            } else {
                Color.ncViewerBackground(backgroundStyle)
                    .ignoresSafeArea()
            }

        case NKTypeClassFile.audio.rawValue:
            if let previewURL {
                previewOnlyView(previewURL: previewURL)
            } else {
                audioPlaceholderView
            }

        default:
            if let previewURL {
                previewOnlyView(previewURL: previewURL)
            } else {
                imagePlaceholderView
            }
        }
    }

    @ViewBuilder
    private func genericReadyStateView(
        localURL: URL,
        previewURL: URL?
    ) -> some View {
        if let metadata = page.metadata {
            switch metadata.classFile {
            case NKTypeClassFile.video.rawValue:
                videoStateView(
                    localURL: localURL,
                    previewURL: previewURL
                )

            case NKTypeClassFile.audio.rawValue:
                audioStateView(
                    localURL: localURL,
                    previewURL: previewURL
                )

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
        _ message: String
    ) -> some View {
        if let previewURL {
            previewOnlyView(previewURL: previewURL)
        } else if page.metadata?.classFile == NKTypeClassFile.audio.rawValue {
            audioPlaceholderView
        } else {
            unresolvedMediaPlaceholderView
        }
    }

    @ViewBuilder
    private var unresolvedMediaPlaceholderView: some View {
        switch page.metadata?.classFile {
        case NKTypeClassFile.video.rawValue:
            NCVideoPlaybackCoverView(
                previewURL: nil,
                isPlayEnabled: false,
                isLaunchingPlayback: false,
                onToggleChrome: onToggleChrome,
                onPlay: { }
            )
        case NKTypeClassFile.audio.rawValue:
            audioPlaceholderView
        default:
            imagePlaceholderView
        }
    }

    private var imagePlaceholderView: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo")
                .font(.system(size: 44, weight: .regular))

            Text(page.metadata?.fileNameView ?? page.metadata?.fileName ?? "")
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(primaryForegroundStyle)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(chromeToggleGesture())
    }

    private var audioPlaceholderView: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform")
                .font(.system(size: 44, weight: .regular))

            Text(page.metadata?.fileNameView ?? page.metadata?.fileName ?? "")
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(primaryForegroundStyle)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(chromeToggleGesture())
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
                topOverlayInset: livePhotoTopOverlayInset,
                onZoomChanged: onZoomChanged
            )
            .background(Color.ncViewerBackground(backgroundStyle))
            .contentShape(Rectangle())
            .gesture(chromeToggleGesture())
        } else {
            NCImageViewerContentView(
                identifier: page.ocId,
                previewURL: previewURL,
                fullURL: localURL,
                backgroundStyle: backgroundStyle,
                onZoomChanged: onZoomChanged
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
            backgroundStyle: backgroundStyle,
            onZoomChanged: onZoomChanged
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
