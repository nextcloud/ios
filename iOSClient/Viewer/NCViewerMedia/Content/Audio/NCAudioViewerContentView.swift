// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import AVFoundation
import NextcloudKit

// MARK: - Audio Viewer View

/// Displays and plays a local audio file.
///
/// The playback model is retrieved from `NCAudioViewerPlaybackRegistry` so the
/// underlying `AVPlayer` survives SwiftUI view rebuilds caused by rotation,
/// layout invalidation, or cell refreshes.
struct NCAudioViewerContentView: View {
    let metadata: tableMetadata
    let localURL: URL
    let canGoPrevious: Bool
    let canGoNext: Bool
    let shouldAutoPlay: Bool
    let onPrevious: (_ shouldAutoPlay: Bool) -> Void
    let onNext: (_ shouldAutoPlay: Bool) -> Void
    let onAutoPlayConsumed: () -> Void

    @StateObject private var model: NCAudioViewerModel

    init(
        metadata: tableMetadata,
        localURL: URL,
        canGoPrevious: Bool = false,
        canGoNext: Bool = false,
        shouldAutoPlay: Bool = false,
        onPrevious: @escaping (_ shouldAutoPlay: Bool) -> Void = { _ in },
        onNext: @escaping (_ shouldAutoPlay: Bool) -> Void = { _ in },
        onAutoPlayConsumed: @escaping () -> Void = {}
    ) {
        self.metadata = metadata
        self.localURL = localURL
        self.canGoPrevious = canGoPrevious
        self.canGoNext = canGoNext
        self.shouldAutoPlay = shouldAutoPlay
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.onAutoPlayConsumed = onAutoPlayConsumed

        _model = StateObject(
            wrappedValue: NCAudioViewerPlaybackRegistry.shared.model(
                for: metadata.ocId
            )
        )
    }

    var body: some View {
        VStack(spacing: 28) {
            artworkView

            VStack(spacing: 8) {
                Text(displayFileName)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(metadata.contentType.isEmpty ? "Audio" : metadata.contentType)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 10) {
                Slider(
                    value: Binding(
                        get: { model.currentTime },
                        set: { model.seek(to: $0) }
                    ),
                    in: 0...max(model.duration, 1)
                )
                .disabled(model.duration <= 0)

                HStack {
                    Text(formatTime(model.currentTime))

                    Spacer()

                    Text(formatTime(model.duration))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 32)

            HStack(spacing: 28) {
                Button {
                    model.toggleLoop()
                } label: {
                    Image(systemName: model.isLoopEnabled ? "repeat.circle.fill" : "repeat.circle")
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(model.isLoopEnabled ? .white : .white.opacity(0.45))
                }
                .buttonStyle(.plain)

                Button {
                    model.togglePlayback()
                } label: {
                    Image(systemName: model.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 72, weight: .regular))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button {
                    model.restart()
                } label: {
                    Image(systemName: "gobackward")
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
                .disabled(model.duration <= 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .task(id: localURL) {
            await model.load(url: localURL)
            consumeAutoPlayIfNeeded()
        }
        .onChange(of: shouldAutoPlay) { _, newValue in
            guard newValue else {
                return
            }

            consumeAutoPlayIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .ncMediaViewerStopPlayback)) { _ in
            NCAudioViewerPlaybackRegistry.shared.stopAll()
        }
    }

    // MARK: - Views

    private var artworkView: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 180, height: 180)

            Image(systemName: "waveform")
                .font(.system(size: 76, weight: .regular))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    // MARK: - Private

    private var displayFileName: String {
        if !metadata.fileNameView.isEmpty {
            return metadata.fileNameView
        }

        return metadata.fileName
    }

    /// Starts playback when this page receives an auto-play request.
    @MainActor
    private func consumeAutoPlayIfNeeded() {
        guard shouldAutoPlay else {
            return
        }

        model.play()
        onAutoPlayConsumed()
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite,
              seconds >= 0 else {
            return "00:00"
        }

        let totalSeconds = Int(seconds.rounded())
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60

        return String(
            format: "%02d:%02d",
            minutes,
            remainingSeconds
        )
    }
}

// MARK: - Audio Viewer Playback Registry

/// Keeps audio playback models alive across SwiftUI view rebuilds.
///
/// The media viewer can rebuild cells during rotation or layout changes.
/// This registry prevents the audio player from being destroyed just because
/// the SwiftUI page view was recreated.
@MainActor
final class NCAudioViewerPlaybackRegistry {
    static let shared = NCAudioViewerPlaybackRegistry()

    private var modelsByOcId: [String: NCAudioViewerModel] = [:]

    private init() { }

    /// Returns a stable audio model for the given media item.
    ///
    /// - Parameter ocId: Stable Nextcloud media identifier.
    /// - Returns: Existing or newly created audio playback model.
    func model(for ocId: String) -> NCAudioViewerModel {
        if let model = modelsByOcId[ocId] {
            return model
        }

        let model = NCAudioViewerModel()
        modelsByOcId[ocId] = model
        return model
    }

    /// Stops all cached audio models without removing them.
    ///
    /// SwiftUI pages may still hold `@StateObject` references to these models.
    /// Removing them while views are alive can create duplicate playback models for
    /// the same `ocId` after a later cell refresh or rebuild.
    func stopAll() {
        modelsByOcId.values.forEach { $0.stop() }
    }
}

// MARK: - Audio Viewer Model

/// Lightweight audio playback model backed by `AVPlayer`.
///
/// The model observes playback time and item completion, exposes SwiftUI-friendly
/// state, and performs cleanup when playback is explicitly stopped.
@MainActor
final class NCAudioViewerModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isPlaying = false
    @Published private(set) var duration: Double = 0
    @Published var currentTime: Double = 0
    @Published private(set) var isLoopEnabled = false

    // MARK: - Private State

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var currentURL: URL?
    private var loadedURL: URL?

    // MARK: - Public API

    /// Loads a local audio file.
    ///
    /// If the same URL is already loaded, the existing player is reused.
    ///
    /// - Parameter url: Local audio file URL.
    func load(url: URL) async {
        guard currentURL != url else {
            return
        }

        stop()

        currentURL = url
        loadedURL = url

        configureAudioSession()

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)

        player.actionAtItemEnd = .pause

        self.player = player

        let loadedDuration: Double

        if let duration = try? await asset.load(.duration),
           duration.seconds.isFinite {
            loadedDuration = duration.seconds
        } else {
            loadedDuration = 0
        }

        guard !Task.isCancelled,
              currentURL == url,
              self.player === player else {
            player.pause()
            return
        }

        self.duration = loadedDuration

        addTimeObserver(to: player)
        addEndObserver(for: item, player: player)
    }

    /// Starts audio playback.
    func play() {
        guard let player else {
            guard let loadedURL else {
                return
            }

            Task { @MainActor in
                await load(url: loadedURL)
                play()
            }
            return
        }

        if duration > 0,
           currentTime >= duration - 0.2 {
            seek(to: 0)
        }

        configureAudioSession()

        player.play()
        isPlaying = true
    }

    /// Toggles audio playback.
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// Toggles loop playback.
    func toggleLoop() {
        isLoopEnabled.toggle()
    }

    /// Restarts playback from the beginning.
    func restart() {
        seek(to: 0)

        if isPlaying {
            player?.play()
        }
    }

    /// Seeks to a specific playback time.
    ///
    /// - Parameter seconds: Target playback position in seconds.
    func seek(to seconds: Double) {
        guard let player else {
            return
        }

        let clampedSeconds = min(
            max(seconds, 0),
            max(duration, 0)
        )

        currentTime = clampedSeconds

        let time = CMTime(
            seconds: clampedSeconds,
            preferredTimescale: 600
        )

        player.seek(
            to: time,
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    /// Pauses playback without releasing the player.
    func pause() {
        player?.pause()
        isPlaying = false
    }

    /// Stops playback and releases the player.
    func stop() {
        if let player {
            player.pause()
        }

        if let timeObserver,
           let player {
            player.removeTimeObserver(timeObserver)
        }

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }

        timeObserver = nil
        endObserver = nil
        player = nil
        currentURL = nil

        isPlaying = false
        currentTime = 0
        duration = 0
    }

    // MARK: - Private

    /// Configures the audio session for media playback.
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: []
            )

            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            nkLog(
                tag: NCGlobal.shared.logTagViewer,
                emoji: .error,
                message: "AUDIO session error: \(error.localizedDescription)",
                consoleOnly: true
            )
        }
    }

    /// Adds a periodic time observer to update SwiftUI playback state.
    ///
    /// - Parameter player: Player to observe.
    private func addTimeObserver(to player: AVPlayer) {
        let interval = CMTime(
            seconds: 0.25,
            preferredTimescale: 600
        )

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            guard let self else {
                return
            }

            Task { @MainActor in
                guard self.player === player else {
                    return
                }

                self.currentTime = time.seconds.isFinite ? time.seconds : 0
            }
        }
    }

    /// Observes the end of playback and restarts the item when loop is enabled.
    ///
    /// - Parameters:
    ///   - item: Player item to observe.
    ///   - player: Player that owns the item.
    private func addEndObserver(
        for item: AVPlayerItem,
        player: AVPlayer
    ) {
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self, weak player] _ in
            guard let self,
                  let player else {
                return
            }

            Task { @MainActor in
                guard self.player === player else {
                    return
                }

                if self.isLoopEnabled {
                    self.currentTime = 0

                    player.seek(
                        to: .zero,
                        toleranceBefore: .zero,
                        toleranceAfter: .zero
                    ) { _ in
                        Task { @MainActor in
                            guard self.player === player else {
                                return
                            }

                            player.play()
                            self.isPlaying = true
                        }
                    }
                } else {
                    self.currentTime = self.duration
                    self.isPlaying = false
                }
            }
        }
    }
}
