// SPDX-FileCopyrightText: STRATO GmbH
// SPDX-FileCopyrightText: 2025 Serhii Kaliberda
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Combine
import MediaPlayer
import NextcloudKit
import Alamofire

enum NCPlayerState: Equatable {
    static func == (lhs: NCPlayerState, rhs: NCPlayerState) -> Bool {
        switch (lhs, rhs) {
        case (.stopped, .stopped): return true
        case (.opening, .opening): return true
        case (.buffering, .buffering): return true
        case (.ended, .ended): return true
        case (.error(let lhsError), .error(let rhsError)): return rhsError == lhsError
        case (.playing, .playing): return true
        case (.paused, .paused): return true
        case (.gettingURL, .gettingURL): return true
        case (.downloading(let lhsProgress), .downloading(let rhsProgress)): return lhsProgress == rhsProgress
        case (.downloaded, .downloaded): return true
        default: return false
        }
    }

    case stopped
    case opening
    case buffering
    case ended
    case error(error: NKError?)
    case playing
    case paused
    case gettingURL
    case downloading(progress: Double)
    case downloaded
    case streamAdded
}

class NCMediaCoordinator: NSObject {

    enum MediaTrackType {
        case audio
        case subtitle
    }

    static let secondsIn5Minutes: Int = 300
    static let secondsToSeek: Int = 10

    private let database = NCManageDatabase.shared
    private let utility = NCUtility()
    private let global = NCGlobal.shared
    private let utilityFileSystem = NCUtilityFileSystem()
    private let networking = NCNetworking.shared

    static let shared = NCMediaCoordinator()

    // MARK: - Strategy
    private var strategy: NCMediaCoordinatorStrategy?

    // MARK: - Delegate
    weak var delegate: NCMediaCoordinatorVLCStrategyDelegate? {
        didSet {
            (strategy as? NCMediaCoordinatorVLCStrategy)?.delegate = delegate
        }
    }

    // MARK: - Picture in Picture Properties
    private(set) var isPictureInPictureActive: Bool = false {
        didSet(oldValue) {
            guard oldValue != isPictureInPictureActive else { return }
            isPictureInPictureActiveSubject.send(isPictureInPictureActive)
        }
    }
    private(set) var isPictureInPictureSupported: Bool = false {
        didSet(oldValue) {
            guard oldValue != isPictureInPictureSupported else { return }
            isPictureInPictureSupportedSubject
                .send(isPictureInPictureSupported)
        }
    }

    // MARK: - Command Center Properties
    private var playCommand: Any?
    private var pauseCommand: Any?
    private var previousTrackCommand: Any?
    private var nextTrackCommand: Any?
    private var skipBackwardCommand: Any?
    private var skipForwardCommand: Any?

    private var url: URL? {
        didSet {
            if let url = url {
                strategy?.url = url
            } else {
                strategy?.url = nil
            }
        }
    }

    // MARK: - Publishers
    private let metadataSwitchSubject = PassthroughSubject<(old: tableMetadata?, new: tableMetadata?), Never>()
    private let positionSubject = PassthroughSubject<Float, Never>()
    private let isPlayingSubject = PassthroughSubject<Bool, Never>()
    private let stateSubject = PassthroughSubject<NCPlayerState, Never>()
    private let isPictureInPictureSupportedSubject = PassthroughSubject<Bool, Never>()
    private let isPictureInPictureActiveSubject = PassthroughSubject<Bool, Never>()

    // MARK: - Public Publishers
    var metadataSwitchPublisher: AnyPublisher<(old: tableMetadata?, new: tableMetadata?), Never> {
        metadataSwitchSubject.eraseToAnyPublisher()
    }

    var positionPublisher: AnyPublisher<Float, Never> {
        positionSubject.eraseToAnyPublisher()
    }

    var statePublisher: AnyPublisher<NCPlayerState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    var isPictureInPictureSupportedPublisher: AnyPublisher<Bool, Never> {
        isPictureInPictureSupportedSubject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    var isPictureInPictureActivePublisher: AnyPublisher<Bool, Never> {
        isPictureInPictureActiveSubject.eraseToAnyPublisher()
    }

    var isPlayingPublisher: AnyPublisher<Bool, Never> {
        isPlayingSubject.eraseToAnyPublisher()
    }

    var currentItemIndex: Int? {
        guard let item else {
            return nil
        }
        return items.firstIndex(where: { $0.ocId == item.ocId })
    }
    var items: [tableMetadata] = []
    var item: tableMetadata? {
        didSet {
            if oldValue?.ocId != item?.ocId {
                metadataSwitchSubject.send((oldValue, item))
                updateCoverImage()
            }
        }
    }
    private var coverImage: UIImage? {
        didSet {
            updateNowPlayingImage(coverImage)
        }
    }

    var playRepeat: Bool = false

    var fileName: String {
        item?.fileName ?? ""
    }

    private weak var viewToPutVideoOutputView: UIView?
    func putVideoOutputView(in view: UIView) {
        viewToPutVideoOutputView = view
        strategy?.putVideoOutputView(in: view)
    }

    var position: Float {
        get {
            return strategy?.position ?? 0
        }
        set {
            strategy?.position = newValue
            positionSubject.send(newValue)
        }
    }

    var length: Float {
        return strategy?.length ?? 0
    }

    var isPlaying: Bool {
        return strategy?.isPlaying ?? false
    }

    private(set) var state: NCPlayerState = .stopped {
        didSet {
            stateSubject.send(state)
        }
    }

    var currentAudioTrackIndex: Int32 {
        get { return strategy?.currentAudioTrackIndex ?? 0 }
        set { strategy?.currentAudioTrackIndex = newValue }
    }

    var currentVideoSubTitleIndex: Int32 {
        get { return strategy?.currentVideoSubTitleIndex ?? 0 }
        set { strategy?.currentVideoSubTitleIndex = newValue }
    }

    var playedTime: String {
        return strategy?.playedTime ?? ""
    }

    var remainingTime: String {
        return strategy?.remainingTime ?? ""
    }

    var videoSubTitlesNames: [String] {
        return strategy?.videoSubTitlesNames ?? []
    }

    var videoSubTitlesIndexes: [Int32] {
        return strategy?.videoSubTitlesIndexes ?? []
    }

    var audioTrackNames: [String] {
        return strategy?.audioTrackNames ?? []
    }

    var audioTrackIndexes: [Int32] {
        return strategy?.audioTrackIndexes ?? []
    }

    var videoSize: CGSize {
        return strategy?.videoSize ?? .zero
    }

    private override init() {
        super.init()
    }

    func stop() {
        savePosition()
        strategy?.stop()
    }

    func play(restart: Bool = false) {
        strategy?.play(restart: restart)
    }

    func play(item: tableMetadata) {
        if (self.item?.ocId == item.ocId) && !isPlayerInErrorState() {
            play()
        } else {
            self.item = item
            setNowPlayingInfo()
            prepareAndStartPlayback(for: item)
        }
    }

    internal func isPlayerInErrorState() -> Bool {
        switch state {
        case .error: return true
        default: return false
        }
    }

    func pause() {
        savePosition()
        strategy?.pause()
    }

    func jumpForward(_ seconds: Int32) {
        strategy?.play()
        strategy?.jumpForward(seconds)
    }

    func jumpBackward(_ seconds: Int32) {
        strategy?.play()
        strategy?.jumpBackward(seconds)
    }

    private func savePosition() {
        guard let metadata = self.item, let strategy = self.strategy else { return }
        guard currentMediaIsInPlayer() else { return }
        guard strategy.currentMediaLengthInSeconds() > Self.secondsIn5Minutes else { return }
        self.database.addVideoOrAudio(metadata: metadata, position: position)
    }

    private func resetSavedPosition() {
        guard let metadata = self.item, currentMediaIsInPlayer() else { return }
        self.database.addVideoOrAudio(metadata: metadata, position: 0)
    }

    func addPlaybackTrack(_ trackURL: URL, type mediaTrackType: MediaTrackType, enforce enforceSelection: Bool) {
        guard strategy != nil else { return }

        if let vlcStrategy = strategy as? NCMediaCoordinatorVLCStrategy {
            vlcStrategy.addPlaybackTrack(trackURL,
                                         type: mediaTrackType,
                                         enforce: enforceSelection)
            return
        }

        guard let currentURL = url else {
            return
        }

        stop()

        let vlcStrategy = NCMediaCoordinatorVLCStrategy(context: self)
        vlcStrategy.delegate = delegate

        strategy = vlcStrategy

        vlcStrategy.url = currentURL
        if let viewToPutVideoOutputView {
            vlcStrategy.putVideoOutputView(in: viewToPutVideoOutputView)
        }

        isPictureInPictureSupported = vlcStrategy.isPictureInPictureSupported

        vlcStrategy.play(restart: false)

        vlcStrategy.addPlaybackTrack(trackURL,
                                     type: mediaTrackType,
                                     enforce: enforceSelection)
    }

    private var downloadRequest: DownloadRequest?
    private func prepareAndStartPlayback(for metadata: tableMetadata) {
        self.state = .gettingURL
        networking.getVideoUrl(metadata: metadata) { url, error in
            if error == .success, let url = url {
                self.onReceived(playbackURL: url, metadata: metadata)
            } else {
                Task { @MainActor in
                    guard let metadata = await self.database.setMetadataSessionInWaitDownloadAsync(ocId: metadata.ocId,
                                                                                                   session: self.networking.sessionDownload,
                                                                                                   selector: "") else {
                        return
                    }
                    let results = await self.networking.downloadFile(metadata: metadata) { request in
                        self.downloadRequest = request
                    } progressHandler: { progress in
                        self.state = .downloading(progress: progress.fractionCompleted)
                    }
                    if results.nkError == .success {
                        self.state = .downloaded
                        if self.utilityFileSystem.fileProviderStorageExists(metadata) {
                            let url = URL(fileURLWithPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileName: metadata.fileNameView, userId: metadata.userId, urlBase: metadata.urlBase))
                            self.onReceived(playbackURL: url, metadata: metadata)
                        }
                    } else {
                        self.state = .error(error: results.nkError)
                    }
                }
            }
        }
    }

    func cancelDownload() {
        downloadRequest?.cancel()
        downloadRequest = nil
    }

    private func onReceived(playbackURL url: URL, metadata: tableMetadata) {
        guard self.item?.ocId == metadata.ocId else { return }

        if metadata.isVideo {
            Task { @MainActor in
                self.strategy = await createStrategy(for: url)
                self.url = url
                self.play()
            }
        } else {
            self.strategy = NCMediaCoordinatorVLCStrategy(context: self)
            self.url = url
            self.play()
        }
    }

    func forward() {
        guard let metadata = self.item,
              let index = items.firstIndex(where: { $0.ocId == metadata.ocId }),
              index < items.count - 1 else {
            return
        }
        let nextItemIndex = items.index(after: index)
        let nextMetadata = items[nextItemIndex]
        pause()
        play(item: nextMetadata)
    }

    private var needToRestartOnRewindAfterPlayedSeconds: Int = 5
    func rewind() {
        guard let item, let strategy else { return }
        if strategy.playedTimeInSeconds > needToRestartOnRewindAfterPlayedSeconds {
            self.database.addVideoOrAudio(metadata: item, position: 0)
            position = 0
            return
        }

        guard let metadata = self.item,
              let index = items.firstIndex(where: { $0.ocId == metadata.ocId }),
              index > 0 else {
            return
        }
        let prevItemIndex = items.index(before: index)
        let prevMetadata = items[prevItemIndex]
        pause()
        play(item: prevMetadata)
    }

    func finishMediaSession(clearQueue: Bool = true) {
        savePosition()
        strategy?.finishMediaSession()
        isPlayingSubject.send(false)
        strategy = nil
        item = nil
        playRepeat = false
        if clearQueue {
            items.removeAll()
        }
        clearNowPlaying()
        isPictureInPictureSupported = false
        isPictureInPictureActive = false
    }

    // MARK: - Command Center

    private func setNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()

        UIApplication.shared.beginReceivingRemoteControlEvents()

        // Add handler for Play Command
        MPRemoteCommandCenter.shared().playCommand.isEnabled = true
        if playCommand == nil {
            playCommand = MPRemoteCommandCenter.shared().playCommand.addTarget { _ in
                if !self.isPlaying {
                    self.play()
                    return .success
                }
                return .commandFailed
            }
        }

        // Add handler for Pause Command
        MPRemoteCommandCenter.shared().pauseCommand.isEnabled = true
        if pauseCommand == nil {
            pauseCommand = MPRemoteCommandCenter.shared().pauseCommand.addTarget { _ in
                if self.isPlaying {
                    self.pause()
                    return .success
                }
                return .commandFailed
            }
        }

        if item?.isVideo == true {
            // Seek Backward
            MPRemoteCommandCenter.shared().skipBackwardCommand.isEnabled = true
            if skipBackwardCommand == nil {
                skipBackwardCommand = MPRemoteCommandCenter.shared().skipBackwardCommand.addTarget { _ in
                    self.jumpBackward(Int32(Self.secondsToSeek))
                    return .success
                }
            }
            // Seek Forward
            MPRemoteCommandCenter.shared().skipForwardCommand.isEnabled = true
            if skipForwardCommand == nil {
                skipForwardCommand = MPRemoteCommandCenter.shared().skipForwardCommand.addTarget { _ in
                    self.jumpForward(Int32(Self.secondsToSeek))
                    return .success
                }
            }
        } else {
            // Previous Track
            MPRemoteCommandCenter.shared().previousTrackCommand.isEnabled = true
            if previousTrackCommand == nil {
                previousTrackCommand = MPRemoteCommandCenter.shared().previousTrackCommand.addTarget { _ in
                    self.rewind()
                    return .success
                }
            }

            // Next Track
            MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = true
            if nextTrackCommand == nil {
                nextTrackCommand = MPRemoteCommandCenter.shared().nextTrackCommand.addTarget { _ in
                    self.forward()
                    return .success
                }
            }
        }

        nowPlayingInfo[MPMediaItemPropertyTitle] = item?.fileName
        if let coverImage {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: coverImage.size) { _ in
                return coverImage
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func updateNowPlayingTime() {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]

        let length = self.length / 1000
        let positionInSecond = position * length

        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = length
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = positionInSecond

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func updateNowPlayingPlaybackRate(isPlaying: Bool) {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1 : 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func updateNowPlayingImage(_ image: UIImage?) {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        if let image = image {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in
                return image
            }
        } else {
            nowPlayingInfo.removeValue(forKey: MPMediaItemPropertyArtwork)
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func clearNowPlaying() {
        UIApplication.shared.endReceivingRemoteControlEvents()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [:]

        MPRemoteCommandCenter.shared().playCommand.isEnabled = false
        MPRemoteCommandCenter.shared().pauseCommand.isEnabled = false
        MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = false
        MPRemoteCommandCenter.shared().previousTrackCommand.isEnabled = false
        MPRemoteCommandCenter.shared().skipBackwardCommand.isEnabled = false
        MPRemoteCommandCenter.shared().skipForwardCommand.isEnabled = false

        if let playCommand = playCommand {
            MPRemoteCommandCenter.shared().playCommand.removeTarget(playCommand)
            self.playCommand = nil
        }
        if let pauseCommand = pauseCommand {
            MPRemoteCommandCenter.shared().pauseCommand.removeTarget(pauseCommand)
            self.pauseCommand = nil
        }
        if let previousTrackCommand = previousTrackCommand {
            MPRemoteCommandCenter.shared().previousTrackCommand.removeTarget(previousTrackCommand)
            self.previousTrackCommand = nil
        }
        if let nextTrackCommand = nextTrackCommand {
            MPRemoteCommandCenter.shared().nextTrackCommand.removeTarget(nextTrackCommand)
            self.nextTrackCommand = nil
        }
        if let skipBackwardCommand = skipBackwardCommand {
            MPRemoteCommandCenter.shared().skipBackwardCommand.removeTarget(skipBackwardCommand)
            self.skipBackwardCommand = nil
        }
        if let skipForwardCommand = skipForwardCommand {
            MPRemoteCommandCenter.shared().skipForwardCommand.removeTarget(skipForwardCommand)
            self.skipForwardCommand = nil
        }
    }

    private func updateCoverImage() {
        guard let item else { return }

        self.coverImage = nil

        if item.isVideo && !item.hasPreview {
            utility.createImageFileFrom(metadata: item)
            self.coverImage = utility.getImage(ocId: item.ocId,
                                               etag: item.etag,
                                               ext: global.previewExt1024,
                                               userId: item.userId,
                                               urlBase: item.urlBase)
        } else if let image = UIImage(contentsOfFile: utilityFileSystem.getDirectoryProviderStorageImageOcId(item.ocId,
                                                                                                             etag: item.etag,
                                                                                                             ext: global.previewExt1024,
                                                                                                             userId: item.userId,
                                                                                                             urlBase: item.urlBase)) {
            self.coverImage = image
        } else if item.isAudio {
            self.coverImage = utility.loadImage(named: "waveform", colors: [NCBrandColor.shared.iconImageColor2])
        }
    }

    private func onItemPlaybackEnded() {
        guard let ocId = item?.ocId,
              let endedItemIndex = items.firstIndex(where: { $0.ocId == ocId }) else { return }

        if endedItemIndex < items.count - 1 {
            url = nil
            let nextItemIndex = items.index(after: endedItemIndex)
            let metadata = items[nextItemIndex]
            play(item: metadata)
        } else {
            resetSavedPosition()
            strategy?.onItemPlaybackEnded()
        }
    }

    private func currentMediaIsInPlayer() -> Bool {
        guard let strategy else { return false }
        return strategy.currentMediaIsInPlayer()
    }

    // MARK: - Picture in Picture

    func switchPictureInPicture() {
        guard isPictureInPictureSupported else { return }

        if isPictureInPictureActive {
            strategy?.stopPictureInPicture()
        } else {
            strategy?.startPictureInPicture()
        }
    }

    @MainActor
    private func createStrategy(for url: URL) async -> NCMediaCoordinatorStrategy {
        let avKitStrategy = NCMediaCoordinatorAVKitStrategy(context: self, url: url)
        let isPlayableByAVKit = await avKitStrategy.isSupported(url: url)

        let strategy: NCMediaCoordinatorStrategy
        if isPlayableByAVKit {
            strategy = avKitStrategy
        } else {
            let vlcStrategy = NCMediaCoordinatorVLCStrategy(context: self)
            vlcStrategy.delegate = delegate
            strategy = vlcStrategy
        }

        if let viewToPutVideoOutputView {
            strategy.putVideoOutputView(in: viewToPutVideoOutputView)
        }
        isPictureInPictureSupported = strategy.isPictureInPictureSupported
        return strategy
    }
}

extension NCMediaCoordinator: NCMediaCoordinatorVLCStrategyContext, NCMediaCoordinatorAVKitStrategyContext {
    var currentItem: tableMetadata? { item }

    func savedPosition(for metadata: tableMetadata) -> Float? {
        database.getVideoOrAudio(metadata: metadata)?.position
    }

    func handleMediaPlayerStateChanged(isPlaying: Bool, state: NCPlayerState) {
        updateNowPlayingPlaybackRate(isPlaying: isPlaying)
        isPlayingSubject.send(isPlaying)
        self.state = state
        switch state {
        case .ended:
            if playRepeat {
                self.play(restart: true)
            } else {
                onItemPlaybackEnded()
            }
        default: break
        }
    }

    func handleMediaPlayerTimeChanged() {
        updateNowPlayingTime()
        positionSubject.send(position)
    }

    func handlePictureInPictureStateChanged(isActive: Bool, dueToPlaybackEnded: Bool) {
        guard isPictureInPictureActive != isActive else { return }
        if !isActive && !dueToPlaybackEnded {
            pause()
        }
        isPictureInPictureActive = isActive
    }

    func restoreUserInterfaceForPictureInPictureStop() {
        guard let metadata = item, metadata.isVideo else { return }

        Task { @MainActor in
            // Resolve the tab bar controller for the scene where this media was opened
            let controller: NCMainTabBarController?
            if let sceneIdentifier = metadata.sceneIdentifier {
                controller = SceneManager.shared.getController(sceneIdentifier: sceneIdentifier)
            } else {
                controller = SceneManager.shared.getControllers().first
            }

            guard let tabBarController = controller,
                  let navigationController = tabBarController.currentNavigationController() else { return }

            if let existingViewer = navigationController.viewControllers.last as? NCViewerMediaPage,
               existingViewer.currentViewController.metadata.ocId == metadata.ocId {
                return
            }

            guard let viewerMediaPageContainer = await NCViewer().getViewerController(metadata: metadata) else {
                return
            }

            navigationController.pushViewController(viewerMediaPageContainer, animated: true)
        }
    }
}
