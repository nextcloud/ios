// SPDX-FileCopyrightText: STRATO GmbH
// SPDX-FileCopyrightText: 2025 Serhii Kaliberda
// SPDX-License-Identifier: GPL-3.0-or-later

import AVKit
import AVFoundation
import UIKit

protocol NCMediaCoordinatorAVKitStrategyContext: AnyObject {
    var currentItem: tableMetadata? { get }

    func play(item: tableMetadata)
    func savedPosition(for metadata: tableMetadata) -> Float?

    func handleMediaPlayerStateChanged(isPlaying: Bool, state: NCPlayerState)
    func handleMediaPlayerTimeChanged()

    func handlePictureInPictureStateChanged(isActive: Bool, dueToPlaybackEnded: Bool)
    func restoreUserInterfaceForPictureInPictureStop()
}

private class NCMediaCoordinatorAVKitVideoView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        // swiftlint:disable force_cast
        return layer as! AVPlayerLayer
        // swiftlint:enable force_cast
    }
}

class NCMediaCoordinatorAVKitStrategy: NSObject, NCMediaCoordinatorStrategy {

    private static let preferredTimescale: CMTimeScale = 600

    private let context: NCMediaCoordinatorAVKitStrategyContext

    private let videoOutputView = NCMediaCoordinatorAVKitVideoView()
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?

    private var positionToSeekToOnFirstPlay: Double = Double.nan

    private var timeObserverToken: Any?
    private var playbackEndedObserver: Any?
    private var playingTimeControlStatusObserver: NSKeyValueObservation?

    private let pictureInPictureController: AVPictureInPictureController?

    private var isAudioSessionActive: Bool = false
    private let session = AVAudioSession.sharedInstance()

    private(set) var state: NCPlayerState = .stopped

    var isPictureInPictureSupported: Bool {
        return AVPictureInPictureController.isPictureInPictureSupported()
    }

    init(context: NCMediaCoordinatorAVKitStrategyContext, url: URL) {
        self.context = context
        self.url = url
        self.playerItem = AVPlayerItem(url: url)
        self.pictureInPictureController = AVPictureInPictureController(playerLayer: videoOutputView.playerLayer)
        self.pictureInPictureController?.canStartPictureInPictureAutomaticallyFromInline = true
        super.init()
        self.pictureInPictureController?.delegate = self
    }

    deinit {
        removeObservers()
    }

    func isSupported() async -> Bool {
        let isPlayable = try? await playerItem?.asset.load(.isPlayable)
        return isPlayable == true
    }

    // MARK: - NCMediaCoordinatorStrategy

    var url: URL? {
        didSet(oldValue) {
            guard oldValue != url else { return }
            if let url {
                playerItem = AVPlayerItem(url: url)
            } else {
                playerItem = nil
            }
        }
    }

    var position: Float {
        get {
            guard isVideoDurationAvailable(), let currentItem = player?.currentItem else {
                    return 0
                }

            let currentTime = player?.currentTime() ?? .zero
            let ratio = currentTime.seconds / currentItem.duration.seconds
            return Float(ratio)
        }
        set {
            guard isVideoDurationAvailable(), let currentItem = player?.currentItem else {
                return
            }

            let seconds = currentItem.duration.seconds * Double(newValue)
            let time = CMTime(seconds: max(0, seconds), preferredTimescale: Self.preferredTimescale)
            player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    var length: Float {
        guard let duration = player?.currentItem?.duration, duration.isNumeric else { return 0 }
        return Float(duration.seconds * 1000)
    }

    var isPlaying: Bool {
        return player?.timeControlStatus == .playing
    }

    var currentAudioTrackIndex: Int32 {
        get {
            guard let item = player?.currentItem,
                let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible),
                let selected = item.currentMediaSelection.selectedMediaOption(in: group),
                let index = group.options.firstIndex(of: selected) else {
                    return 0
            }
            return Int32(index)
        }
        set {
            guard let item = player?.currentItem,
                let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else {
                return
            }

            let options = group.options
            let idx = Int(newValue)
            guard options.indices.contains(idx) else { return }

            let option = options[idx]
            item.select(option, in: group)
        }
    }

    var currentVideoSubTitleIndex: Int32 {
        get {
            guard let item = player?.currentItem,
                let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible),
                let selected = item.currentMediaSelection.selectedMediaOption(in: group),
                let index = group.options.firstIndex(of: selected) else {
                    return 0
            }
            return Int32(index)
        }
        set {
            guard let item = player?.currentItem,
                let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
                    return
            }

            let options = group.options
            let idx = Int(newValue)
            guard options.indices.contains(idx) else { return }

            let option = options[idx]
            item.select(option, in: group)
        }
    }

    var videoSubTitlesNames: [String] {
        guard let item = player?.currentItem,
            let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
                return []
        }

        return group.options.map { $0.displayName }
    }

    var videoSubTitlesIndexes: [Int32] {
        guard let item = player?.currentItem,
            let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
                return []
        }

        return group.options.indices.map { Int32($0) }
    }

    var audioTrackNames: [String] {
        guard let item = player?.currentItem,
            let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible)
        else { return [] }

        return group.options.map { $0.displayName }
    }

    var audioTrackIndexes: [Int32] {
        guard let item = player?.currentItem,
            let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else {
                return []
        }

        return group.options.indices.map { Int32($0) }
    }

    var videoSize: CGSize {
        return player?.currentItem?.presentationSize ?? .zero
    }

    var playedTimeInSeconds: Int {
        let seconds = player?.currentTime().seconds ?? 0
        guard seconds.isFinite && seconds >= 0 else { return 0 }
        return Int(seconds)
    }

    var playedTime: String {
        return formattedTime(for: player?.currentTime())
    }

    var remainingTime: String {
        guard let item = player?.currentItem,
            item.duration.isNumeric else {
                return NCMediaCoordinatorConstants.emptyTime
        }

        let currentSeconds = player?.currentTime().seconds ?? 0
        let totalSeconds = item.duration.seconds

        guard totalSeconds.isFinite && totalSeconds > 0 else {
            return NCMediaCoordinatorConstants.emptyTime
        }

        let remaining = max(0, totalSeconds - currentSeconds)
        return "-\(formattedTime(for: CMTime(seconds: remaining, preferredTimescale: Self.preferredTimescale)))"
    }

    func finishMediaSession() {
        player?.pause()
        player?.seek(to: .zero)
        removeObservers()
        pictureInPictureController?.stopPictureInPicture()
        player = nil
        playerItem = nil
        url = nil
        updateState(isPlaying: false, state: .stopped)
        deactivateAudioSessionIfNeeded()
        videoOutputView.removeFromSuperview()
    }

    func onItemPlaybackEnded() {
        removeObservers()
        pictureInPictureController?.stopPictureInPicture()
        context.handlePictureInPictureStateChanged(isActive: false, dueToPlaybackEnded: true)
        player = nil
        deactivateAudioSessionIfNeeded()
    }

    func putVideoOutputView(in view: UIView) {
        guard videoOutputView.superview !== view else { return }

        videoOutputView.removeFromSuperview()
        videoOutputView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(videoOutputView)

        NSLayoutConstraint.activate([
            videoOutputView.topAnchor.constraint(equalTo: view.topAnchor),
            videoOutputView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoOutputView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoOutputView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        if let player {
            videoOutputView.playerLayer.player = player
            videoOutputView.playerLayer.videoGravity = .resizeAspect
        }
    }

    func startPictureInPicture() {
        guard isPictureInPictureSupported else { return }

        if pictureInPictureController?.isPictureInPictureActive ?? false {
            return
        }

        pictureInPictureController?.startPictureInPicture()
    }

    func stopPictureInPicture() {
        guard pictureInPictureController?.isPictureInPictureActive ?? false else {
            return
        }

        pictureInPictureController?.stopPictureInPicture()
    }

    func play() {
        player?.play()
    }

    func play(restart: Bool) {
        guard !isPlayerInErrorState() else {
            if let item = context.currentItem {
                context.play(item: item)
            }
            return
        }

        if player == nil, let url {
            playerItem = AVPlayerItem(url: url)
            setUpPlayer()
        }

        if restart {
            player?.seek(to: .zero)
        } else if let item = context.currentItem, let savedPosition = context.savedPosition(for: item) {
            positionToSeekToOnFirstPlay = Double(savedPosition)
        }

        activateAudioSessionIfNeeded()
        player?.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func stop() {
        player?.pause()
        player?.seek(to: .zero)
        updateState(isPlaying: false, state: .stopped)
        deactivateAudioSessionIfNeeded()
    }

    func jumpForward(_ seconds: Int32) {
        seek(by: TimeInterval(seconds))
    }

    func jumpBackward(_ seconds: Int32) {
        seek(by: -TimeInterval(seconds))
    }

    func currentMediaLengthInSeconds() -> Int {
        guard let duration = player?.currentItem?.duration, duration.isNumeric else { return 0 }
        return Int(duration.seconds)
    }

    func currentMediaIsInPlayer() -> Bool {
        guard let currentItem = player?.currentItem,
            let asset = currentItem.asset as? AVURLAsset,
            let url else {
                return false
        }

        return asset.url == url
    }

    // MARK: - Private helpers

    private func setUpPlayer() {
        removeObservers()

        guard let playerItem else { return }

        let player = AVPlayer(playerItem: playerItem)
        self.player = player

        videoOutputView.playerLayer.player = player
        videoOutputView.playerLayer.videoGravity = .resizeAspect

        addObservers()
    }

    private func seek(by delta: TimeInterval) {
        guard let player else { return }

        let currentSeconds = player.currentTime().seconds
        guard currentSeconds.isFinite else { return }

        let targetSeconds = max(0, currentSeconds + delta)
        let time = CMTime(seconds: targetSeconds, preferredTimescale: Self.preferredTimescale)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func isPlayerInErrorState() -> Bool {
        switch state {
        case .error: return true
        default: return false
        }
    }

    private func addObservers() {
        guard let player else { return }

        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: Self.preferredTimescale),
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.seekToPositionToSeekToOnFirstPlay()
            self.context.handleMediaPlayerTimeChanged()
        }

        playbackEndedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.updateState(isPlaying: false, state: .ended)
            self.context.handleMediaPlayerTimeChanged()
        }

        playingTimeControlStatusObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            guard let self = self else { return }
            switch player.timeControlStatus {
            case .playing:
                self.updateState(isPlaying: true, state: .playing)
            case .paused:
                self.updateState(isPlaying: false, state: .paused)
            case .waitingToPlayAtSpecifiedRate:
                self.updateState(isPlaying: false, state: .buffering)
            @unknown default:
                break
            }
        }
    }

    private func seekToPositionToSeekToOnFirstPlay() {
        guard !positionToSeekToOnFirstPlay.isNaN,
              isVideoDurationAvailable(),
              let currentItem = player?.currentItem else {
            return
        }
        let seconds = currentItem.duration.seconds * positionToSeekToOnFirstPlay
        let time = CMTime(seconds: max(0, seconds), preferredTimescale: Self.preferredTimescale)
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        positionToSeekToOnFirstPlay = Double.nan
    }

    private func isVideoDurationAvailable() -> Bool {
        guard let currentItem = player?.currentItem,
                currentItem.duration.isNumeric,
                currentItem.duration.seconds > 0 else {
                return false
            }
        return true
    }

    private func removeObservers() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }

        if let playbackEndedObserver {
            NotificationCenter.default.removeObserver(playbackEndedObserver)
            self.playbackEndedObserver = nil
        }

        if let playingTimeControlStatusObserver {
            playingTimeControlStatusObserver.invalidate()
            self.playingTimeControlStatusObserver = nil
        }
    }

    private func updateState(isPlaying: Bool, state: NCPlayerState) {
        self.state = state
        context.handleMediaPlayerStateChanged(isPlaying: isPlaying, state: state)
    }

    private func activateAudioSessionIfNeeded() {
        guard !isAudioSessionActive else { return }

        do {
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
            isAudioSessionActive = true
        } catch {
            isAudioSessionActive = false
            #if DEBUG
            print("Failed to activate AVAudioSession: \(error)")
            #endif
        }
    }

    private func deactivateAudioSessionIfNeeded() {
        guard isAudioSessionActive else { return }

        do {
            pause()
            try session.setActive(false)
            isAudioSessionActive = false
        } catch {
            #if DEBUG
            print("Failed to deactivate AVAudioSession: \(error)")
            #endif
        }
    }

    private func formattedTime(for time: CMTime?) -> String {
        guard let time,
              time.isNumeric else {
            return NCMediaCoordinatorConstants.emptyTime
        }

        let totalSeconds = Int(time.seconds)
        let seconds = totalSeconds % 60
        let minutes = (totalSeconds / 60) % 60
        let hours = totalSeconds / 3600

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

extension NCMediaCoordinatorAVKitStrategy: AVPictureInPictureControllerDelegate {

    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        context.handlePictureInPictureStateChanged(isActive: true, dueToPlaybackEnded: false)
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        context.handlePictureInPictureStateChanged(isActive: false, dueToPlaybackEnded: false)
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        context.handlePictureInPictureStateChanged(isActive: false, dueToPlaybackEnded: false)
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        context.handlePictureInPictureStateChanged(isActive: false, dueToPlaybackEnded: false)
        context.restoreUserInterfaceForPictureInPictureStop()
        completionHandler(true)
    }
}
