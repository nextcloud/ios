// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct NCVideoPlaybackCoverView: View {
    @Environment(\.mediaAdaptiveCoverContext) private var adaptiveContext

    let previewURL: URL?
    let backgroundStyle: NCViewerBackgroundStyle = .system
    let isPlayEnabled: Bool
    let isLoading: Bool
    let isLaunchingPlayback: Bool
    let statusMessage: String?
    let onCancel: (() -> Void)?
    let onToggleChrome: (() -> Void)?
    let onPlay: () -> Void

    var body: some View {
        ZStack {
            if let adaptiveContext {
                NCVideoAdaptiveCoverPreview(state: adaptiveContext.state, previewURL: previewURL, backgroundStyle: backgroundStyle)
            } else {
                NCVideoPlaybackCoverPreview(previewURL: previewURL, backgroundStyle: backgroundStyle)
                    .ignoresSafeArea()
            }

            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    onToggleChrome?()
                }

            if let adaptiveContext {
                NCVideoAdaptiveCoverControls(state: adaptiveContext.state, ocId: adaptiveContext.ocId, controls: controlsPresentation, revision: controlsRevision)
            } else {
                controlsView
            }
        }
    }

    private var controlsView: NCVideoPlaybackCoverControlsView {
        NCVideoPlaybackCoverControlsView(presentation: controlsPresentation)
    }

    private var controlsPresentation: NCVideoPlaybackCoverPresentation {
        NCVideoPlaybackCoverPresentation(
            isPlayEnabled: isPlayEnabled,
            isLoading: isLoading,
            isLaunchingPlayback: isLaunchingPlayback,
            statusMessage: statusMessage,
            onCancel: onCancel,
            onPlay: onPlay
        )
    }

    private var controlsRevision: String {
        "\(previewURL?.absoluteString ?? "")|\(isPlayEnabled)|\(isLoading)|\(isLaunchingPlayback)|\(statusMessage ?? "")|\(onCancel != nil)"
    }
}

private struct NCVideoPlaybackCoverPreview: View {
    let previewURL: URL?
    let backgroundStyle: NCViewerBackgroundStyle

    var body: some View {
        if let previewURL {
            AsyncImage(url: previewURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()

                case .failure,
                     .empty:
                    Color.ncViewerBackground(backgroundStyle)

                @unknown default:
                    Color.ncViewerBackground(backgroundStyle)
                }
            }
        } else {
            Color.ncViewerBackground(backgroundStyle)
        }
    }
}

private struct NCVideoAdaptiveCoverPreview: View {
    @ObservedObject var state: NCMediaAdaptiveControlsState
    let previewURL: URL?
    let backgroundStyle: NCViewerBackgroundStyle

    var body: some View {
        if state.isFoldedLayout {
            // Fit and center within the upper region, without expanding through its safe-area edges.
            GeometryReader { geometry in
                NCVideoPlaybackCoverPreview(previewURL: previewURL, backgroundStyle: backgroundStyle)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
            }
            .clipped()
        } else {
            NCVideoPlaybackCoverPreview(previewURL: previewURL, backgroundStyle: backgroundStyle)
                .ignoresSafeArea()
        }
    }
}

/// Cover state and actions, independent of their normal or adaptive presentation.
struct NCVideoPlaybackCoverPresentation {
    let isPlayEnabled: Bool
    let isLoading: Bool
    let isLaunchingPlayback: Bool
    let statusMessage: String?
    let onCancel: (() -> Void)?
    let onPlay: () -> Void
}

/// Normal cover controls. Adaptive graphics live in NCVideoAdaptivePlaybackCoverControlsView.
struct NCVideoPlaybackCoverControlsView: View {
    let presentation: NCVideoPlaybackCoverPresentation

    var body: some View {
        VStack(spacing: 12) {
            Button {
                guard presentation.isPlayEnabled else {
                    return
                }

                presentation.onPlay()
            } label: {
                ZStack {
                    if presentation.isLoading || presentation.isLaunchingPlayback {
                        ProgressView()
                            .controlSize(.large)
                            .tint(.primary)
                            .transition(.opacity)
                    } else {
                        // Color.primary, not .primary: the default button style resolves .primary against the accent tint.
                        // The default style stays because .plain fades disabled content, like the loading spinner.
                        Image(systemName: "play.fill")
                            .font(.system(size: 36, weight: .regular))
                            .foregroundStyle(Color.primary.opacity(presentation.isPlayEnabled ? 1 : 0.35))
                            .transition(.opacity)
                    }
                }
                .frame(width: 62, height: 62)
                .coverPlayButtonBackground()
            }
            .disabled(!presentation.isPlayEnabled || presentation.isLoading || presentation.isLaunchingPlayback)
            .scaleEffect(presentation.isLaunchingPlayback ? 1.06 : 1)
            .animation(.easeInOut(duration: 0.18), value: presentation.isLoading)
            .animation(.easeInOut(duration: 0.14), value: presentation.isLaunchingPlayback)
            .accessibilityLabel(Text(NSLocalizedString("_play_", comment: "")))

            if let statusMessage = presentation.statusMessage {
                VStack(spacing: 10) {
                    Text(statusMessage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    if let onCancel = presentation.onCancel {
                        Button(NSLocalizedString("_cancel_", comment: "")) {
                            onCancel()
                        }
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.borderedProminent)
                        .tint(.white)
                        .foregroundStyle(.black)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.black.opacity(0.46), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}

private struct NCVideoAdaptiveCoverControls: View {
    @ObservedObject var state: NCMediaAdaptiveControlsState
    let ocId: String
    let controls: NCVideoPlaybackCoverPresentation
    let revision: String
    @State private var owner = UUID()

    var body: some View {
        ZStack {
            Color.clear
                .allowsHitTesting(false)

            if !state.isFoldedLayout {
                NCVideoPlaybackCoverControlsView(presentation: controls)
            }
        }
        .task(id: revision) {
            guard !Task.isCancelled else {
                return
            }
            state.setVideoCoverControls(controls, for: ocId, owner: owner)
        }
        .onDisappear {
            state.removeVideoCoverControls(for: ocId, owner: owner)
        }
    }
}

private extension View {
    @ViewBuilder
    func coverPlayButtonBackground() -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            self
                .background(.regularMaterial)
                .clipShape(Circle())
        }
    }
}

#Preview("Video Playback Cover") {
    NCVideoPlaybackCoverView(
        previewURL: NCVideoPlaybackCoverPreviewImage.url,
        isPlayEnabled: true,
        isLoading: false,
        isLaunchingPlayback: false,
        statusMessage: nil,
        onCancel: nil,
        onToggleChrome: {},
        onPlay: {}
    )
}

#Preview("Video Playback Cover - Loading") {
    NCVideoPlaybackCoverView(
        previewURL: NCVideoPlaybackCoverPreviewImage.url,
        isPlayEnabled: false,
        isLoading: true,
        isLaunchingPlayback: false,
        statusMessage: NSLocalizedString("_download_in_progress_", comment: ""),
        onCancel: {},
        onToggleChrome: {},
        onPlay: {}
    )
}

#Preview("Video Playback Cover - Folded Upper Region") {
    NCVideoPlaybackCoverView(
        previewURL: NCVideoPlaybackCoverPreviewImage.url,
        isPlayEnabled: true,
        isLoading: false,
        isLaunchingPlayback: false,
        statusMessage: nil,
        onCancel: nil,
        onToggleChrome: {},
        onPlay: {}
    )
    .environment(\.mediaAdaptiveCoverContext, NCVideoPlaybackCoverPreviewImage.foldedContext)
    .frame(width: 420, height: 240)
    .border(Color.orange)
}

private enum NCVideoPlaybackCoverPreviewImage {
    @MainActor
    static var foldedContext: NCMediaAdaptiveCoverContext {
        let state = NCMediaAdaptiveControlsState()
        state.isFoldedLayout = true
        return NCMediaAdaptiveCoverContext(state: state, ocId: "preview-video")
    }

    static var url: URL? {
        guard let image = UIImage(named: "testimage"),
              let data = image.jpegData(compressionQuality: 1) else {
            return nil
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("NCVideoPlaybackCoverPreview-testimage.jpg")

        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
