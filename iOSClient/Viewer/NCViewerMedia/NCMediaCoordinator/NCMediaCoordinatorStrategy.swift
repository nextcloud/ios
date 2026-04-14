// SPDX-FileCopyrightText: STRATO GmbH
// SPDX-FileCopyrightText: 2025 Serhii Kaliberda
// SPDX-License-Identifier: GPL-3.0-or-later

protocol NCMediaCoordinatorStrategy {

    var url: URL? { get set }

    var position: Float { get set }
    var length: Float { get }
    var isPlaying: Bool { get }
    var currentAudioTrackIndex: Int32 { get set }
    var currentVideoSubTitleIndex: Int32 { get set }
    var videoSubTitlesNames: [String] { get }
    var videoSubTitlesIndexes: [Int32] { get }
    var audioTrackNames: [String] { get }
    var audioTrackIndexes: [Int32] { get }
    var videoSize: CGSize { get }

    var playedTimeInSeconds: Int { get }
    var playedTime: String { get }
    var remainingTime: String { get }

    var state: NCPlayerState { get }

    var isPictureInPictureSupported: Bool { get }
    func startPictureInPicture()
    func stopPictureInPicture()

    func finishMediaSession()

    func onItemPlaybackEnded()

    func putVideoOutputView(in view: UIView)

    func play()
    func play(restart: Bool)
    func pause()
    func stop()
    func jumpForward(_ seconds: Int32)
    func jumpBackward(_ seconds: Int32)

    func currentMediaLengthInSeconds() -> Int
    func currentMediaIsInPlayer() -> Bool
}
