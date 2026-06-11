// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct NCVideoPlaybackCoverView: View {
    let previewURL: URL?
    let backgroundStyle: NCViewerBackgroundStyle = .system
    let isPlayEnabled: Bool
    let isLaunchingPlayback: Bool
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
                        Color.ncViewerBackground(backgroundStyle)

                    @unknown default:
                        Color.ncViewerBackground(backgroundStyle)
                    }
                }
                .ignoresSafeArea()
            } else {
                Color.ncViewerBackground(backgroundStyle)
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
                    .foregroundStyle(isPlayEnabled ? .white : .black.opacity(0.35))
                    .videoControlIconShadow()
                    .frame(width: 62, height: 62)
                    .coverPlayButtonBackground(isEnabled: isPlayEnabled)
            }
            .disabled(!isPlayEnabled || isLaunchingPlayback)
            .opacity(isLaunchingPlayback ? 0 : 1)
            .scaleEffect(isLaunchingPlayback ? 1.12 : 1)
            .animation(.easeInOut(duration: 0.14), value: isLaunchingPlayback)
            .accessibilityLabel(Text(NSLocalizedString("_play_", comment: "")))
        }
    }
}

private extension View {
    @ViewBuilder
    func coverPlayButtonBackground(isEnabled: Bool) -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular, in: .circle)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.58), lineWidth: 1.2)
                }
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.20), lineWidth: 4)
                        .blur(radius: 2)
                        .mask(Circle())
                }
                .shadow(
                    color: .black.opacity(0.18),
                    radius: 14,
                    x: 0,
                    y: 4
                )
        } else {
            self
                .background(.white.opacity(isEnabled ? 0.92 : 0.45))
                .clipShape(Circle())
        }
    }
}

private extension View {
    func videoControlIconShadow() -> some View {
        shadow(
            color: .black.opacity(0.5),
            radius: 2.5,
            x: 0,
            y: 1
        )
    }
}

#Preview("Video Playback Cover") {
    NCVideoPlaybackCoverView(
        previewURL: NCVideoPlaybackCoverPreviewImage.url,
        isPlayEnabled: true,
        isLaunchingPlayback: false,
        onToggleChrome: {},
        onPlay: {}
    )
}

#Preview("Video Playback Cover - Disabled") {
    NCVideoPlaybackCoverView(
        previewURL: NCVideoPlaybackCoverPreviewImage.url,
        isPlayEnabled: false,
        isLaunchingPlayback: false,
        onToggleChrome: {},
        onPlay: {}
    )
}

private enum NCVideoPlaybackCoverPreviewImage {
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
