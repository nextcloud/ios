// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import AVFoundation
import NextcloudKit

// MARK: - Audio Viewer View

struct NCAudioViewerContentView: View {
    let metadata: tableMetadata
    let localURL: URL
    let previewURL: URL?
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
        previewURL: URL? = nil,
        canGoPrevious: Bool = false,
        canGoNext: Bool = false,
        shouldAutoPlay: Bool = false,
        onPrevious: @escaping (_ shouldAutoPlay: Bool) -> Void = { _ in },
        onNext: @escaping (_ shouldAutoPlay: Bool) -> Void = { _ in },
        onAutoPlayConsumed: @escaping () -> Void = {}
    ) {
        self.metadata = metadata
        self.localURL = localURL
        self.previewURL = previewURL
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
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            let artworkSize: CGFloat = isLandscape ? 110 : 180
            let mainSpacing: CGFloat = isLandscape ? 18 : 28
            let titleHorizontalPadding: CGFloat = 24
            let sliderHorizontalPadding: CGFloat = isLandscape ? 90 : 32
            let topPadding: CGFloat = isLandscape ? 72 : 0
            let buttonSpacing: CGFloat = isLandscape ? 24 : 28
            let sideButtonSize: CGFloat = isLandscape ? 30 : 34
            let playButtonSize: CGFloat = isLandscape ? 64 : 72

            VStack(spacing: mainSpacing) {
                artworkView(size: artworkSize)
                if !isLandscape {
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
                    .padding(.horizontal, titleHorizontalPadding)
                }

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
                .padding(.horizontal, sliderHorizontalPadding)

                HStack(spacing: buttonSpacing) {
                    Button {
                        model.toggleLoop()
                    } label: {
                        Image(systemName: model.isLoopEnabled ? "repeat.circle.fill" : "repeat.circle")
                            .font(.system(size: sideButtonSize, weight: .regular))
                            .foregroundStyle(model.isLoopEnabled ? .white : .white.opacity(0.45))
                    }
                    .buttonStyle(.plain)

                    Button {
                        model.togglePlayback()
                    } label: {
                        Image(systemName: model.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: playButtonSize, weight: .regular))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Button {
                        model.restart()
                    } label: {
                        Image(systemName: "gobackward")
                            .font(.system(size: sideButtonSize, weight: .regular))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                    .disabled(model.duration <= 0)
                }
            }
            .padding(.top, topPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
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

    private func artworkView(size: CGFloat) -> some View {
        ZStack {
            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            } else {
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: size, height: size)

                Image(systemName: "waveform")
                    .font(.system(size: 76, weight: .regular))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    private var previewImage: UIImage? {
        guard let previewURL,
              previewURL.isFileURL else {
            return nil
        }

        return UIImage(contentsOfFile: previewURL.path)
    }

    // MARK: - Private

    private var displayFileName: String {
        if !metadata.fileNameView.isEmpty {
            return metadata.fileNameView
        }

        return metadata.fileName
    }

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

// Keeps audio models alive across SwiftUI rebuilds.
@MainActor
final class NCAudioViewerPlaybackRegistry {
    static let shared = NCAudioViewerPlaybackRegistry()

    private var modelsByOcId: [String: NCAudioViewerModel] = [:]

    private init() { }

    func model(for ocId: String) -> NCAudioViewerModel {
        if let model = modelsByOcId[ocId] {
            return model
        }

        let model = NCAudioViewerModel()
        modelsByOcId[ocId] = model
        return model
    }

    // Do not remove models while SwiftUI pages may still hold them.
    func stopAll() {
        modelsByOcId.values.forEach { $0.stop() }
    }
}

// MARK: - Audio Viewer Model

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

        addTimeObserver(to: player)
        addEndObserver(for: item, player: player)

        Task { [weak self] in
            let loadedDuration: Double

            if let duration = try? await asset.load(.duration),
               duration.seconds.isFinite {
                loadedDuration = duration.seconds
            } else {
                loadedDuration = 0
            }

            await MainActor.run {
                guard let self,
                      self.currentURL == url,
                      self.player === player else {
                    return
                }

                self.duration = loadedDuration
            }
        }
    }

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

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func toggleLoop() {
        isLoopEnabled.toggle()
    }

    func restart() {
        seek(to: 0)

        if isPlaying {
            player?.play()
        }
    }

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

    func pause() {
        player?.pause()
        isPlaying = false
    }

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
