// SPDX-FileCopyrightText: STRATO GmbH
// SPDX-FileCopyrightText: 2025 Serhii Kaliberda
// SPDX-License-Identifier: GPL-3.0-or-later

import MobileVLCKit
import UIKit

private class PassThroughVLCVideoView: UIView {
    override func addSubview(_ view: UIView) {
        super.addSubview(view)
        view.isUserInteractionEnabled = false
    }
}

protocol NCMediaCoordinatorVLCStrategyContext: AnyObject {
    var currentItem: tableMetadata? { get }

    func play(item: tableMetadata)
    func savedPosition(for metadata: tableMetadata) -> Float?

    func handleMediaPlayerStateChanged(isPlaying: Bool, state: NCPlayerState)
    func handleMediaPlayerTimeChanged()
}

protocol NCMediaCoordinatorVLCStrategyDelegate: AnyObject {
    func showError(withTitle title: String, message: String)
    func showAlert(alert: UIAlertController)
    func showLogin(withTitle title: String, message: String, defaultUsername username: String?, askingForStorage: Bool, withReference reference: NSValue)
    func showProgress(withTitle title: String, message: String, isIndeterminate: Bool, position: Float, cancel cancelString: String?, withReference reference: NSValue)
    func updateProgress(withReference reference: NSValue, message: String?, position: Float)
    func cancelDialog(withReference reference: NSValue)
}

extension NCPlayerState {
    init(vlcState: VLCMediaPlayerState) {
        switch vlcState {
        case .stopped: self = .stopped
        case .opening: self = .opening
        case .buffering: self = .buffering
        case .ended: self = .ended
        case .error: self = .error(error: nil)
        case .playing: self = .playing
        case .paused: self = .paused
        case .esAdded: self = .streamAdded
        default: self = .stopped
        }
    }
}

extension NCMediaCoordinator.MediaTrackType {
    var vlcType: VLCMediaPlaybackSlaveType {
        switch self {
        case .audio: return .audio
        case .subtitle: return .subtitle
        }
    }
}

class NCMediaCoordinatorVLCStrategy: NSObject, NCMediaCoordinatorStrategy {

    var context: NCMediaCoordinatorVLCStrategyContext
    var delegate: NCMediaCoordinatorVLCStrategyDelegate?

    private var dialogProvider: VLCDialogProvider?

    private let videoOutputView = PassThroughVLCVideoView()

    // VLC-specific properties moved from NCMediaCoordinator
    private var media: VLCMedia?
    private var player: VLCMediaPlayer?

    // Exposed accessors for coordinator
    var drawableView: UIView {
        videoOutputView
    }

    var vlcMedia: VLCMedia? {
        get { media }
        set { media = newValue }
    }

    var vlcPlayer: VLCMediaPlayer? {
        get { player }
        set { player = newValue }
    }

    var url: URL? {
        didSet {
            if let url = url {
                media = VLCMedia(url: url)
                media?.addOption(":http-user-agent=\(userAgent)")
            } else {
                media = nil
            }
        }
    }

    var position: Float {
        get {
            return player?.position ?? 0
        }
        set {
            player?.position = newValue
        }
    }

    var length: Float {
        return Float(media?.length.intValue ?? 0)
    }

    var isPlaying: Bool {
        return player?.isPlaying ?? false
    }

    var currentAudioTrackIndex: Int32 {
        get { return player?.currentAudioTrackIndex ?? 0 }
        set { player?.currentAudioTrackIndex = newValue }
    }

    var currentVideoSubTitleIndex: Int32 {
        get { return player?.currentVideoSubTitleIndex ?? 0 }
        set { player?.currentVideoSubTitleIndex = newValue }
    }

    var videoSubTitlesNames: [String] {
        return player?.videoSubTitlesNames.compactMap { $0 as? String } ?? []
    }

    var videoSubTitlesIndexes: [Int32] {
        return player?.videoSubTitlesIndexes.compactMap { $0 as? Int32 } ?? []
    }

    var audioTrackNames: [String] {
        return player?.audioTrackNames.compactMap { $0 as? String } ?? []
    }

    var audioTrackIndexes: [Int32] {
        return player?.audioTrackIndexes.compactMap { $0 as? Int32 } ?? []
    }

    var videoSize: CGSize {
        return player?.videoSize ?? .zero
    }

    var playedTimeInSeconds: Int {
        return Int(player?.time.intValue ?? 0) / 1000
    }

    var playedTime: String {
        return player?.time.stringValue ?? ""
    }

    var remainingTime: String {
        return player?.remainingTime?.stringValue ?? ""
    }

    var state: NCPlayerState {
        return NCPlayerState(vlcState: player?.state ?? .stopped)
    }

    var isPictureInPictureSupported: Bool {
        return false
    }

    func startPictureInPicture() {
        // Not supported
    }

    func stopPictureInPicture() {
        // Not supported
    }

    init(context: NCMediaCoordinatorVLCStrategyContext) {
        self.context = context
    }

    func finishMediaSession() {
        player?.stop()
        position = 0
        player = nil
        url = nil
        dialogProvider = nil
        videoOutputView.removeFromSuperview()
    }

    func onItemPlaybackEnded() {
        player = nil
        position = 0
    }

    func putVideoOutputView(in view: UIView) {
        guard videoOutputView.superview != view else { return }
        videoOutputView.removeFromSuperview()
        videoOutputView.translatesAutoresizingMaskIntoConstraints = false
        videoOutputView.isUserInteractionEnabled = false
        view.addSubview(videoOutputView)
        NSLayoutConstraint.activate([
            videoOutputView.topAnchor.constraint(equalTo: view.topAnchor),
            videoOutputView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoOutputView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoOutputView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func play(restart: Bool) {
        guard !isPlayerInErrorState() else {
            if let item = context.currentItem {
                context.play(item: item)
            }
            return
        }
        guard let player, currentMediaIsInPlayer() && !restart else {
            stop()
            setUpDialogProvider()
            player = VLCMediaPlayer()
            player?.drawable = drawableView
            player?.media = vlcMedia
            player?.delegate = self

            var position: Float = 0
            if !restart, let item = context.currentItem, let resultPosition = context.savedPosition(for: item) {
                position = resultPosition
            }

            player?.play()
            player?.position = position
            return
        }
        player.play()
    }

    private func isPlayerInErrorState() -> Bool {
        switch state {
        case .error: return true
        default: return false
        }
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func stop() {
        player?.stop()
    }

    func jumpForward(_ seconds: Int32) {
        player?.jumpForward(seconds)
    }

    func jumpBackward(_ seconds: Int32) {
        player?.jumpBackward(seconds)
    }

    func currentMediaLengthInSeconds() -> Int {
        return media?.lengthInSeconds ?? 0
    }

    func currentMediaIsInPlayer() -> Bool {
        guard let player else { return false }
        return (player.media?.compare(media) == .orderedSame)
    }

    func addPlaybackTrack(_ trackURL: URL,
                          type mediaTrackType: NCMediaCoordinator.MediaTrackType,
                          enforce enforceSelection: Bool) {
        guard let player else { return }
        player.addPlaybackSlave(trackURL, type: mediaTrackType.vlcType, enforce: enforceSelection)
    }
}

extension NCMediaCoordinatorVLCStrategy: VLCMediaPlayerDelegate {
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        context.handleMediaPlayerStateChanged(isPlaying: isPlaying, state: state)
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        context.handleMediaPlayerTimeChanged()
    }
}

private extension VLCMedia {
    var lengthInSeconds: Int {
        return Int(length.intValue) / 1000
    }
}

extension NCMediaCoordinatorVLCStrategy: VLCCustomDialogRendererProtocol {
    private func setUpDialogProvider() {
        guard dialogProvider == nil else { return }
        dialogProvider = VLCDialogProvider(library: VLCLibrary.shared(), customUI: true)
        dialogProvider?.customRenderer = self
    }

    func showError(withTitle error: String, message: String) {
        delegate?.showError(withTitle: error, message: message)
    }

    func showLogin(withTitle title: String, message: String, defaultUsername username: String?, askingForStorage: Bool, withReference reference: NSValue) {
        delegate?.showLogin(withTitle: title, message: message, defaultUsername: username, askingForStorage: askingForStorage, withReference: reference)
    }

    func showQuestion(withTitle title: String, message: String, type questionType: VLCDialogQuestionType, cancel cancelString: String?, action1String: String?, action2String: String?, withReference reference: NSValue) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        if let action1String = action1String {
            alert.addAction(UIAlertAction(title: action1String, style: .default, handler: { _ in
                self.dialogProvider?.postAction(1, forDialogReference: reference)
            }))
        }
        if let action2String = action2String {
            alert.addAction(UIAlertAction(title: action2String, style: .default, handler: { _ in
                self.dialogProvider?.postAction(2, forDialogReference: reference)
            }))
        }
        if let cancelString = cancelString {
            alert.addAction(UIAlertAction(title: cancelString, style: .cancel, handler: { _ in
                self.dialogProvider?.postAction(3, forDialogReference: reference)
            }))
        }

        delegate?.showAlert(alert: alert)
    }

    func showProgress(withTitle title: String, message: String, isIndeterminate: Bool, position: Float, cancel cancelString: String?, withReference reference: NSValue) {
        delegate?.showProgress(withTitle: title, message: message, isIndeterminate: isIndeterminate, position: position, cancel: cancelString, withReference: reference)
    }

    func updateProgress(withReference reference: NSValue, message: String?, position: Float) {
        delegate?.updateProgress(withReference: reference, message: message, position: position)
    }

    func cancelDialog(withReference reference: NSValue) {
        delegate?.cancelDialog(withReference: reference)
    }
}
