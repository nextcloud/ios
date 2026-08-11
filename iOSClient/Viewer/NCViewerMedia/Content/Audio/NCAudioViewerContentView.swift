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
    let backgroundStyle: NCViewerBackgroundStyle
    let navigationBar: UINavigationBar?
    let canGoPrevious: Bool
    let canGoNext: Bool
    let isSelected: Bool
    let shouldAutoPlay: Bool
    @ObservedObject var playbackOptions: NCMediaPlaybackOptions
    let onPrevious: (_ shouldAutoPlay: Bool) -> Void
    let onNext: (_ shouldAutoPlay: Bool) -> Void
    let onPlayNextMedia: NCMediaPlaybackAdvanceRequest
    let onAutoPlayConsumed: () -> Void
    let onToggleChrome: () -> Void

    @StateObject private var model: NCAudioViewerModel

    init(
        metadata: tableMetadata,
        localURL: URL,
        previewURL: URL? = nil,
        backgroundStyle: NCViewerBackgroundStyle = .system,
        navigationBar: UINavigationBar? = nil,
        canGoPrevious: Bool = false,
        canGoNext: Bool = false,
        isSelected: Bool = true,
        shouldAutoPlay: Bool = false,
        playbackOptions: NCMediaPlaybackOptions,
        onPrevious: @escaping (_ shouldAutoPlay: Bool) -> Void = { _ in },
        onNext: @escaping (_ shouldAutoPlay: Bool) -> Void = { _ in },
        onPlayNextMedia: @escaping NCMediaPlaybackAdvanceRequest = { completion in
            completion(false)
        },
        onAutoPlayConsumed: @escaping () -> Void = {},
        onToggleChrome: @escaping () -> Void = {}
    ) {
        self.metadata = metadata
        self.localURL = localURL
        self.previewURL = previewURL
        self.backgroundStyle = backgroundStyle
        self.navigationBar = navigationBar
        self.canGoPrevious = canGoPrevious
        self.canGoNext = canGoNext
        self.isSelected = isSelected
        self.shouldAutoPlay = shouldAutoPlay
        self.playbackOptions = playbackOptions
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.onPlayNextMedia = onPlayNextMedia
        self.onAutoPlayConsumed = onAutoPlayConsumed
        self.onToggleChrome = onToggleChrome

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
            let navigationBarHeight: CGFloat = isLandscape ? 32 : 44
            let minimumNavigationBarBottom: CGFloat = isLandscape ? 32 : 64
            // The navigation bar frame moves while hidden. Its safe area and
            // bounds keep this inset stable when the bar becomes visible again.
            let safeAreaTop = max(
                proxy.safeAreaInsets.top,
                navigationBar?.window?.safeAreaInsets.top ?? 0
            )
            let effectiveNavigationBarHeight = max(
                navigationBar?.bounds.height ?? 0,
                navigationBarHeight
            )
            let navigationBarBottom = max(
                safeAreaTop + effectiveNavigationBarHeight,
                minimumNavigationBarBottom
            )
            let topActionsPadding = navigationBarBottom + 4

            ZStack {
                Color.ncViewerBackground(backgroundStyle)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onToggleChrome()
                    }

                VStack(spacing: mainSpacing) {
                    artworkView(size: artworkSize)
                    if !isLandscape {
                        VStack(spacing: 8) {
                            Text(displayFileName)
                                .font(.headline)
                                .foregroundStyle(primaryForegroundStyle)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)

                            Text(metadata.contentType.isEmpty ? "Audio" : metadata.contentType)
                                .font(.footnote)
                                .foregroundStyle(secondaryForegroundStyle)
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
                        .disabled(!isSelected || model.duration <= 0)

                        HStack {
                            Text(formatTime(model.currentTime))

                            Spacer()

                            Text(formatTime(model.duration))
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(secondaryForegroundStyle)
                    }
                    .padding(.horizontal, sliderHorizontalPadding)

                    ZStack {
                        Button {
                            model.togglePlayback()
                        } label: {
                            Image(systemName: model.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: playButtonSize, weight: .regular))
                                .foregroundStyle(primaryForegroundStyle)
                        }
                        .buttonStyle(.plain)
                        .disabled(!isSelected)

                        Button {
                            model.restart()
                        } label: {
                            Image(systemName: "backward.end.circle")
                                .font(.system(size: sideButtonSize, weight: .regular))
                                .foregroundStyle(mutedForegroundStyle)
                        }
                        .buttonStyle(.plain)
                        .disabled(!isSelected || model.duration <= 0)
                        .offset(
                            x: -(playButtonSize / 2 + buttonSpacing + sideButtonSize / 2)
                        )
                    }
                    .frame(height: playButtonSize)
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, topPadding)

                VStack {
                    HStack(spacing: 8) {
                        audioPlaybackOptionButton(
                            systemName: "repeat.1",
                            isActive: playbackOptions.isRepeatEnabled,
                            accessibilityLabel: "_repeat_current_media_"
                        ) {
                            playbackOptions.toggleRepeat()
                        }

                        audioPlaybackOptionButton(
                            systemName: playbackOptions.isAutoAdvanceEnabled ? "forward.end.fill" : "forward.end",
                            isActive: playbackOptions.isAutoAdvanceEnabled,
                            accessibilityLabel: "_play_next_media_automatically_"
                        ) {
                            playbackOptions.toggleAutoAdvance()
                        }

                        Spacer()
                    }
                    .padding(.leading, 28)
                    .padding(.top, topActionsPadding)

                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: localURL) {
            guard isSelected else {
                return
            }

            model.configurePlaybackCompletion(
                options: playbackOptions,
                onPlayNextMedia: onPlayNextMedia
            )
            await model.load(url: localURL)
            await consumeAutoPlayIfNeeded()
        }
        .onChange(of: isSelected) { _, selected in
            guard selected else {
                model.stop()
                return
            }

            Task { @MainActor in
                model.configurePlaybackCompletion(
                    options: playbackOptions,
                    onPlayNextMedia: onPlayNextMedia
                )
                await model.load(url: localURL)
                await consumeAutoPlayIfNeeded()
            }
        }
        .onChange(of: shouldAutoPlay) { _, newValue in
            guard newValue else {
                return
            }

            Task { @MainActor in
                await consumeAutoPlayIfNeeded()
            }
        }
        // Stop all audio playback when the media viewer performs a global playback teardown.
        // This notification is intentionally viewer-wide and should not be used for normal
        // audio page-to-page state changes.
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
                    .fill(artworkPlaceholderBackground)
                    .frame(width: size, height: size)

                Image(systemName: "waveform")
                    .font(.system(size: 76, weight: .regular))
                    .foregroundStyle(primaryForegroundStyle.opacity(0.9))
            }
        }
    }

    private func audioPlaybackOptionButton(
        systemName: String,
        isActive: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(isActive ? Color.accentColor : primaryForegroundStyle)
                .shadow(
                    color: .black.opacity(0.35),
                    radius: 2,
                    x: 0,
                    y: 1
                )
                .frame(width: 38, height: 38)
                .audioControlGlassBackground(shape: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NSLocalizedString(accessibilityLabel, comment: ""))
    }

    private var previewImage: UIImage? {
        guard let previewURL,
              previewURL.isFileURL else {
            return nil
        }

        return UIImage(contentsOfFile: previewURL.path)
    }

    private var primaryForegroundStyle: Color {
        switch backgroundStyle {
        case .black:
            return .white

        case .white:
            return .black

        case .system:
            return .primary

        case .custom:
            return .white
        }
    }

    private var secondaryForegroundStyle: Color {
        switch backgroundStyle {
        case .black:
            return .white.opacity(0.55)

        case .white:
            return .black.opacity(0.55)

        case .system:
            return .secondary

        case .custom:
            return .white.opacity(0.65)
        }
    }

    private var mutedForegroundStyle: Color {
        switch backgroundStyle {
        case .black:
            return .white.opacity(0.45)

        case .white:
            return .black.opacity(0.40)

        case .system:
            return .secondary.opacity(0.70)

        case .custom:
            return .white.opacity(0.45)
        }
    }

    private var artworkPlaceholderBackground: Color {
        switch backgroundStyle {
        case .black:
            return .white.opacity(0.08)

        case .white:
            return .black.opacity(0.06)

        case .system:
            return .secondary.opacity(0.10)

        case .custom:
            return .white.opacity(0.10)
        }
    }

    // MARK: - Private

    private var displayFileName: String {
        if !metadata.fileNameView.isEmpty {
            return metadata.fileNameView
        }

        return metadata.fileName
    }

    @MainActor
    private func consumeAutoPlayIfNeeded() async {
        guard shouldAutoPlay else {
            return
        }

        // The viewer-wide stop notification also releases players belonging to
        // prefetched audio pages. Recreate this page's player before autoplaying
        // instead of relying on the previous preload still being alive.
        await model.load(url: localURL)

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

private extension View {
    @ViewBuilder
    func audioControlGlassBackground<BackgroundShape: SwiftUI.Shape>(
        shape: BackgroundShape
    ) -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular, in: shape)
                .overlay {
                    shape
                        .stroke(.white.opacity(0.58), lineWidth: 1.2)
                }
                .shadow(
                    color: .black.opacity(0.18),
                    radius: 14,
                    x: 0,
                    y: 4
                )
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape
                        .stroke(.primary.opacity(0.12), lineWidth: 1)
                }
                .clipShape(shape)
        }
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

    // MARK: - Private State

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var currentURL: URL?
    private var loadedURL: URL?
    private weak var playbackOptions: NCMediaPlaybackOptions?
    private var onPlayNextMedia: NCMediaPlaybackAdvanceRequest?

    // MARK: - Public API

    func configurePlaybackCompletion(
        options: NCMediaPlaybackOptions,
        onPlayNextMedia: @escaping NCMediaPlaybackAdvanceRequest
    ) {
        playbackOptions = options
        self.onPlayNextMedia = onPlayNextMedia
    }

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

                switch self.playbackOptions?.completionAction ?? .stop {
                case .repeatCurrentItem:
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

                case .playNextItem:
                    self.currentTime = self.duration
                    self.isPlaying = false
                    self.onPlayNextMedia? { _ in }

                case .stop:
                    self.currentTime = self.duration
                    self.isPlaying = false
                }
            }
        }
    }
}
