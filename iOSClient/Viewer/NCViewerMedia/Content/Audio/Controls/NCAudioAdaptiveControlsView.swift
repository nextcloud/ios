// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Lower audio panel. Observes the existing player model; never owns player creation or loading.
struct NCAudioAdaptiveControlsView: View {
    @ObservedObject var playbackModel: NCAudioViewerModel
    @ObservedObject var playbackOptions: NCMediaPlaybackOptions
    let isSelected: Bool
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let navigationHeight = NCMediaAdaptiveControlsLayout.navigationHeight(availableHeight: geometry.size.height)
            let playbackHeight = max(0, geometry.size.height - navigationHeight - NCMediaAdaptiveControlsLayout.spacing)
            VStack(spacing: NCMediaAdaptiveControlsLayout.spacing) {
                playbackControls
                    .frame(height: playbackHeight)
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.ncViewerAdaptiveControlBackground)
                            .gesture(pageSwipe)
                    }
                    .clipped()

                HStack(spacing: NCMediaAdaptiveControlsLayout.spacing) {
                    pageButton(systemName: "chevron.left", title: "_previous_media_", isEnabled: canGoPrevious, action: onPrevious)
                    pageButton(systemName: "chevron.right", title: "_next_media_", isEnabled: canGoNext, action: onNext)
                }
                .frame(height: navigationHeight)
                .simultaneousGesture(pageSwipe)
            }
        }
        .foregroundStyle(Color.ncViewerAdaptiveControlForeground)
        .fontWeight(.bold)
        .tint(Color.ncViewerAdaptiveControlForeground)
    }

    private var playbackControls: some View {
        VStack(spacing: NCMediaAdaptiveControlsLayout.spacing) {
            HStack(spacing: NCMediaAdaptiveControlsLayout.spacing) {
                controlButton(
                    systemName: playbackOptions.isRepeatEnabled ? "repeat.1.circle.fill" : "repeat.1",
                    title: "_repeat_current_media_", isEnabled: true, action: playbackOptions.toggleRepeat
                )
                controlButton(systemName: "gobackward.10", title: "_seek_backward_10_", isEnabled: isSelected && playbackModel.duration > 0) {
                    playbackModel.seek(to: playbackModel.currentTime - 10)
                }
                controlButton(
                    systemName: playbackModel.isPlaying ? "pause.fill" : "play.fill",
                    title: playbackModel.isPlaying ? "_pause_" : "_play_", isEnabled: isSelected, action: playbackModel.togglePlayback
                )
                controlButton(systemName: "goforward.10", title: "_seek_forward_10_", isEnabled: isSelected && playbackModel.duration > 0) {
                    playbackModel.seek(to: playbackModel.currentTime + 10)
                }
                controlButton(
                    systemName: playbackOptions.isAutoAdvanceEnabled ? "forward.end.fill" : "forward.end",
                    title: "_play_next_media_automatically_", isEnabled: true, action: playbackOptions.toggleAutoAdvance
                )
            }
            .contentShape(Rectangle())
            .simultaneousGesture(pageSwipe)

            // No page gesture on this row: horizontal drags seek within the current audio.
            Slider(value: Binding(get: { playbackModel.currentTime }, set: { playbackModel.seek(to: $0) }), in: 0...max(playbackModel.duration, 1))
                .disabled(!isSelected || playbackModel.duration <= 0)

            HStack {
                Text(formatTime(playbackModel.currentTime))
                Spacer()
                Text(formatTime(playbackModel.duration))
            }
            .font(.caption.monospacedDigit())
            .contentShape(Rectangle())
            .simultaneousGesture(pageSwipe)
        }
        .padding(.horizontal, 12)
    }

    private var pageSwipe: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let translation = value.translation
                guard abs(translation.width) >= 50, abs(translation.width) > abs(translation.height) else { return }
                if translation.width < 0, canGoNext {
                    onNext()
                } else if translation.width > 0, canGoPrevious {
                    onPrevious()
                }
            }
    }

    private func controlButton(systemName: String, title: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityLabel(NSLocalizedString(title, comment: ""))
    }

    private func pageButton(systemName: String, title: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(NSLocalizedString(title, comment: ""), systemImage: systemName)
                .font(.subheadline)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ncViewerAdaptiveControlBackground, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0, seconds < Double(Int.max) else { return "00:00" }
        let totalSeconds = Int(seconds.rounded(.down))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

#if DEBUG
#Preview("Adaptive Audio - Controls") {
    return NCAudioAdaptiveControlsView(
        playbackModel: NCAudioViewerModel(),
        playbackOptions: NCMediaPlaybackOptions(preferences: nil),
        isSelected: true,
        canGoPrevious: true,
        canGoNext: true,
        onPrevious: {},
        onNext: {}
    )
    .frame(width: 430, height: 330)
    .background(Color.ncViewerBackground(.system))
}
#endif
