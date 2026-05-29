// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct NCVideoPlaybackCoverView: View {
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
