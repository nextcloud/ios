// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

/// Lower audio panel. Observes the existing player model; never owns player creation or loading.
struct NCAudioAdaptiveControlsView: View {
    let metadata: tableMetadata
    @ObservedObject var playbackModel: NCAudioViewerModel
    @ObservedObject var playbackOptions: NCMediaPlaybackOptions
    let detailView: NCMediaViewerDetailView?
    let isSelected: Bool
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let navigationHeight = min(max(0, geometry.size.height - 5), max(44, geometry.size.height * 0.18))
            let playbackHeight = min(max(0, geometry.size.height - navigationHeight - 10), max(128, geometry.size.height * 0.45))
            let informationHeight = max(0, geometry.size.height - navigationHeight - playbackHeight - 10)
            VStack(spacing: 5) {
                NCMediaViewerDetailView(metadata: detailView?.metadata ?? metadata, exif: detailView?.exif ?? ExifData(), showsOnlyAvailableData: true)
                    .frame(height: informationHeight)
                    .background(controlSurface, in: RoundedRectangle(cornerRadius: 16))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                playbackControls
                    .frame(height: playbackHeight)
                    .background(controlSurface, in: RoundedRectangle(cornerRadius: 16))
                    .clipped()

                HStack(spacing: 5) {
                    pageButton(systemName: "chevron.left", title: "_previous_media_", isEnabled: canGoPrevious, action: onPrevious)
                    pageButton(systemName: "chevron.right", title: "_next_media_", isEnabled: canGoNext, action: onNext)
                }
                .frame(height: navigationHeight)
            }
        }
        .foregroundStyle(.white)
        .fontWeight(.bold)
        .tint(.white)
        .environment(\.colorScheme, .dark)
    }

    private var playbackControls: some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                controlButton(
                    systemName: playbackOptions.isRepeatEnabled ? "repeat.1.circle.fill" : "repeat.1",
                    title: "_repeat_current_media_", isEnabled: true, action: playbackOptions.toggleRepeat
                )
                controlButton(systemName: "backward.end.fill", title: "_restart_audio_", isEnabled: isSelected && playbackModel.duration > 0, action: playbackModel.restart)
                controlButton(
                    systemName: playbackModel.isPlaying ? "pause.fill" : "play.fill",
                    title: playbackModel.isPlaying ? "_pause_" : "_play_", isEnabled: isSelected, action: playbackModel.togglePlayback
                )
                controlButton(
                    systemName: playbackOptions.isAutoAdvanceEnabled ? "forward.end.fill" : "forward.end",
                    title: "_play_next_media_automatically_", isEnabled: true, action: playbackOptions.toggleAutoAdvance
                )
            }

            Slider(value: Binding(get: { playbackModel.currentTime }, set: { playbackModel.seek(to: $0) }), in: 0...max(playbackModel.duration, 1))
                .disabled(!isSelected || playbackModel.duration <= 0)

            HStack {
                Text(formatTime(playbackModel.currentTime))
                Spacer()
                Text(formatTime(playbackModel.duration))
            }
            .font(.caption.monospacedDigit())
        }
        .padding(.horizontal, 12)
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
                .background(controlSurface, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }

    private var controlSurface: LinearGradient {
        LinearGradient(colors: [Color(red: 0.19, green: 0.22, blue: 0.28), Color(red: 0.11, green: 0.13, blue: 0.17)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0, seconds < Double(Int.max) else { return "00:00" }
        let totalSeconds = Int(seconds.rounded(.down))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

#if DEBUG
#Preview("Adaptive Audio - Controls") {
    let metadata = tableMetadata()
    metadata.ocId = "adaptive-audio-preview"
    metadata.fileName = "Waterfall.m4a"
    metadata.fileNameView = metadata.fileName
    metadata.classFile = NKTypeClassFile.audio.rawValue
    metadata.size = 4_200_000

    return NCAudioAdaptiveControlsView(
        metadata: metadata,
        playbackModel: NCAudioViewerModel(),
        playbackOptions: NCMediaPlaybackOptions(preferences: nil),
        detailView: nil,
        isSelected: true,
        canGoPrevious: true,
        canGoNext: true,
        onPrevious: {},
        onNext: {}
    )
    .frame(width: 430, height: 330)
    .background(Color.black)
}
#endif
