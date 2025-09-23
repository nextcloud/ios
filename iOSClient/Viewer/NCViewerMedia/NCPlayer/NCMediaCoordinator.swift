//
//  NCMediaCoordinator.swift
//  Nextcloud
//
//  Created by Sergey Kaliberda on 21.07.2025.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import Foundation
import MobileVLCKit
import Combine
import MediaPlayer
import NextcloudKit
import Alamofire

protocol NCMediaCoordinatorDelegate: AnyObject {
    func showError(withTitle title: String, message: String)
    func showAlert(alert: UIAlertController)
    func showLogin(withTitle title: String, message: String, defaultUsername username: String?, askingForStorage: Bool, withReference reference: NSValue)
    func showProgress(withTitle title: String, message: String, isIndeterminate: Bool, position: Float, cancel cancelString: String?, withReference reference: NSValue)
    func updateProgress(withReference reference: NSValue, message: String?, position: Float)
    func cancelDialog(withReference reference: NSValue)
}

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

    init(vlcState: VLCMediaPlayerState) {
        switch vlcState {
        case .stopped: self = .stopped
        case .opening: self = .opening
        case .buffering: self = .buffering
        case .ended: self = .ended
        case .error: self = .error(error: nil)
        case .playing: self = .playing
        case .paused: self = .paused
        default: self = .stopped
        }
    }
}

class NCMediaCoordinator: NSObject {
    
    static let secondsIn5Minutes: Int = 300
    
    private var player: VLCMediaPlayer?
    private var dialogProvider: VLCDialogProvider?
    private let database = NCManageDatabase.shared
    private let utility = NCUtility()
    private let global = NCGlobal.shared
    private let utilityFileSystem = NCUtilityFileSystem()
    private let networking = NCNetworking.shared
    
    static let shared = NCMediaCoordinator()
    
    // MARK: - Delegate
    weak var delegate: NCMediaCoordinatorDelegate?
    
    // MARK: - Command Center Properties
    private var playCommand: Any?
    private var pauseCommand: Any?
    private var previousTrackCommand: Any?
    private var nextTrackCommand: Any?
    
    private var media: VLCMedia?
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
    
    // MARK: - Publishers
    private let metadataSwitchSubject = PassthroughSubject<(old: tableMetadata?, new: tableMetadata?), Never>()
    private let fileNameSubject = PassthroughSubject<String, Never>()
    private let positionSubject = PassthroughSubject<Float, Never>()
    private let isPlayingSubject = PassthroughSubject<Bool, Never>()
    private let stateSubject = PassthroughSubject<NCPlayerState, Never>()
    
    // MARK: - Public Publishers
    var metadataSwitchPublisher: AnyPublisher<(old: tableMetadata?, new: tableMetadata?), Never> {
        metadataSwitchSubject.eraseToAnyPublisher()
    }
    
    var fileNamePublisher: AnyPublisher<String, Never> {
        fileNameSubject.eraseToAnyPublisher()
    }
    
    var positionPublisher: AnyPublisher<Float, Never> {
        positionSubject.eraseToAnyPublisher()
    }
    
    var isPlayingPublisher: AnyPublisher<Bool, Never> {
        isPlayingSubject.eraseToAnyPublisher()
    }
    
    var statePublisher: AnyPublisher<NCPlayerState, Never> {
        stateSubject.eraseToAnyPublisher()
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
            fileNameSubject.send(fileName)
            if oldValue?.ocId != item?.ocId {
                metadataSwitchSubject.send((oldValue, item))
                updateCoverImage()
            }
        }
    }
    private var coverImage: UIImage? {
        didSet {
            guard let coverImage else {
                return
            }
            updateNowPlayingImage(coverImage)
        }
    }
    
    var playRepeat: Bool = false
    
    var fileName: String {
        item?.fileName ?? ""
    }
    
    weak var videoOutputView: UIView? {
        didSet {
            player?.drawable = videoOutputView
        }
    }
    
    var position: Float {
        get {
            return player?.position ?? 0
        }
        set {
            player?.position = newValue
            positionSubject.send(newValue)
        }
    }
    
    var length: Float {
        return Float(player?.media?.length.intValue ?? 0)
    }
    
    var isPlaying: Bool {
        return player?.isPlaying ?? false
    }
    
    private(set) var state: NCPlayerState = .stopped {
        didSet {
            stateSubject.send(state)
        }
    }
    
    var currentAudioTrackIndex: Int32 {
        get { return player?.currentAudioTrackIndex ?? 0 }
        set { player?.currentTitleIndex = newValue }
    }

    var currentVideoSubTitleIndex: Int32 {
        get { return player?.currentVideoSubTitleIndex ?? 0 }
        set { player?.currentVideoSubTitleIndex = newValue }
    }
    
    var time: VLCTime {
        get { return player?.time ?? VLCTime() }
    }

    var videoSubTitlesNames: [Any] {
        get { return player?.videoSubTitlesNames ?? [] }
    }

    var videoSubTitlesIndexes: [Any] {
        get { return player?.videoSubTitlesIndexes ?? [] }
    }

    var audioTrackNames: [Any] {
        get { return player?.audioTrackNames ?? [] }
    }

    var audioTrackIndexes: [Any] {
        get { return player?.audioTrackIndexes ?? [] }
    }

    var remainingTime: VLCTime? {
        get { return player?.remainingTime }
    }

    var videoSize: CGSize {
        get { return player?.videoSize ?? .zero }
    }
    
    private override init() {
        super.init()
    }
    
    func setUpDialogProvider() {
        guard dialogProvider == nil else { return }
        dialogProvider = VLCDialogProvider(library: VLCLibrary.shared(), customUI: true)
        dialogProvider?.customRenderer = self
    }
    
    func stop() {
        savePosition()
        player?.stop()
    }
    
    func play(restart: Bool = false) {
        guard !isPlayerInErrorState() else {
            if let item = item {
                play(item: item)
            }
            return
        }
        guard let player, currentMediaIsInPlayer() && !restart else {
            stop()
            
            setUpDialogProvider()
            
            player = VLCMediaPlayer()
            player?.drawable = videoOutputView
            player?.media = media
            player?.delegate = self
            
            var position: Float = 0
            if let result = self.database.getVideoOrAudio(metadata: item),
                let resultPosition = result.position {
                position = resultPosition
            }
            
            player?.play()
            player?.position = position
            return
        }
        player.play()
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
    
    private func isPlayerInErrorState() -> Bool {
        switch state {
        case .error(_): return true
        default: return false
        }
    }
    
    func pause() {
        savePosition()
        player?.pause()
    }
    
    func jumpForward(_ seconds: Int32) {
        player?.play()
        player?.jumpForward(seconds)
    }

    func jumpBackward(_ seconds: Int32) {
        player?.play()
        player?.jumpBackward(seconds)
    }
    
    func savePosition() {
        guard let metadata = self.item, let media = self.media else { return }
        guard currentMediaIsInPlayer() else { return }
        guard media.lengthInSeconds > Self.secondsIn5Minutes else { return }
        self.database.addVideoOrAudio(metadata: metadata, position: position)
    }
    
    private func resetSavedPosition() {
        guard let metadata = self.item, currentMediaIsInPlayer() else { return }
        self.database.addVideoOrAudio(metadata: metadata, position: 0)
    }

    @discardableResult
    func addPlaybackSlave(_ slaveURL: URL, type slaveType: VLCMediaPlaybackSlaveType, enforce enforceSelection: Bool) -> Int32 {
        return player?.addPlaybackSlave(slaveURL, type: slaveType, enforce: enforceSelection) ?? 0
    }

    private var downloadRequest: DownloadRequest?
    private func prepareAndStartPlayback(for metadata: tableMetadata) {
        stateSubject.send(.gettingURL)
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
        self.url = url
        play()
    }

    func forward() {
        guard let metadata = self.item,
              let index = items.firstIndex(where: { $0.ocId == metadata.ocId }),
              index < items.count - 1 else {
            return
        }
        let nextItemIndex = items.index(after: index)
        let nextMetadata = items[nextItemIndex]
        play(item: nextMetadata)
    }

    var needToRestartOnRewindAfterPlayedSeconds: Int = 5
    func rewind() {
        guard let item else { return }
        if (time.intValue/1000) > needToRestartOnRewindAfterPlayedSeconds {
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
        play(item: prevMetadata)
    }
    
    func finishMediaSession(clearQueue: Bool = true) {
        savePosition()
        player?.stop()
        position = 0
        player = nil
        item = nil
        url = nil
        videoOutputView = nil
        playRepeat = false
        if clearQueue {
            items.removeAll()
        }
        clearNowPlaying()
        dialogProvider = nil
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
    
    private func updateNowPlayingImage(_ image: UIImage) {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in
            return image
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
    }

    private func updateCoverImage() {
        guard let item else { return }
        
        if item.isVideo && !item.hasPreview {
            utility.createImageFileFrom(metadata: item)
            self.coverImage = utility.getImage(ocId: item.ocId,
                                               etag: item.etag,
                                               ext: global.previewExt1024,
                                               userId: item.userId,
                                               urlBase: item.urlBase)
        } else if item.isAudio {
            self.coverImage = utility.loadImage(named: "waveform", colors: [NCBrandColor.shared.iconImageColor2])
        } else if let image = UIImage(contentsOfFile: utilityFileSystem.getDirectoryProviderStorageImageOcId(item.ocId,
                                                                                                             etag: item.etag,
                                                                                                             ext: global.previewExt1024,
                                                                                                             userId: item.userId,
                                                                                                             urlBase: item.urlBase)) {
            self.coverImage = image
        }
    }
    
    private func itemPlaybackEnded() {
        guard let ocId = item?.ocId,
              let endedItemIndex = items.firstIndex(where: { $0.ocId == ocId }) else { return }
              
        if endedItemIndex < items.count - 1 {
            url = nil
            let nextItemIndex = items.index(after: endedItemIndex)
            let metadata = items[nextItemIndex]
            play(item: metadata)
        } else {
            resetSavedPosition()
            player = nil
            position = 0
        }
    }
    
    private func currentMediaIsInPlayer() -> Bool {
        guard let player else { return false }
        return (player.media?.compare(media) == .orderedSame)
    }
}

extension NCMediaCoordinator: VLCMediaPlayerDelegate {
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        guard let player else {
            isPlayingSubject.send(false)
            updateNowPlayingPlaybackRate(isPlaying: false)
            state = .stopped
            return
        }
        isPlayingSubject.send(player.isPlaying)
        updateNowPlayingPlaybackRate(isPlaying: player.isPlaying)
        state = NCPlayerState(vlcState: player.state)
        switch state {
        case .ended:
            if playRepeat {
                self.play(restart: true)
            } else {
                itemPlaybackEnded()
            }
        default: break
        }
    }
    
    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        updateNowPlayingTime()
        positionSubject.send(position)
    }
}

extension NCMediaCoordinator: VLCCustomDialogRendererProtocol {
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

private extension VLCMedia {
    var lengthInSeconds: Int {
        return Int(length.intValue) / 1000
    }
}
