// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Adaptive cover controls: graphics are independent; playback/download actions remain shared.
struct NCVideoAdaptivePlaybackCoverControlsView: View {
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
                .adaptiveCoverPlayButtonBackground()
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

private extension View {
    @ViewBuilder
    func adaptiveCoverPlayButtonBackground() -> some View {
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
