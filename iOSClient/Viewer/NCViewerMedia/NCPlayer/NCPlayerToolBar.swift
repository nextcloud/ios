// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Marino Faggiana
// SPDX-FileCopyrightText: 2025 Serhii Kaliberda
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import UIKit
import AVKit
import Alamofire
import LucidBanner

class NCPlayerToolBar: UIView {
    @IBOutlet weak var utilityView: UIView!
    @IBOutlet weak var fullscreenButton: UIButton!
    @IBOutlet weak var subtitleButton: UIButton!
    @IBOutlet weak var audioButton: UIButton!

    @IBOutlet weak var playerButtonView: UIStackView!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var forwardButton: UIButton!

    @IBOutlet weak var playbackSliderView: UIView!
    @IBOutlet weak var playbackSlider: NCPlayerToolBarSlider!
    @IBOutlet weak var labelLeftTime: UILabel!
    @IBOutlet weak var labelCurrentTime: UILabel!
    @IBOutlet weak var repeatButton: UIButton!

    private var mediaCoordinator = NCMediaCoordinator.shared

    enum sliderEventType {
        case none
        case began
        case ended
        case moved
    }

    var playbackSliderEvent: sliderEventType = .none
    var isFullscreen: Bool = false
    var playRepeat: Bool {
        get {
            mediaCoordinator.playRepeat
        }
        set {
            mediaCoordinator.playRepeat = newValue
        }
    }

    private var ncplayer: NCPlayer?
    private var metadata: tableMetadata?
    private let audioSession = AVAudioSession.sharedInstance()
    private var pointSize: CGFloat = 0
    private let utilityFileSystem = NCUtilityFileSystem()
    private let utility = NCUtility()
    private let global = NCGlobal.shared
    private let database = NCManageDatabase.shared
    private weak var viewerMediaPage: NCViewerMediaPage?
    private var buttonImage = UIImage()

    // MARK: - View Life Cycle

    override func awakeFromNib() {
        super.awakeFromNib()

        self.backgroundColor = UIColor.black.withAlphaComponent(0.1)

        fullscreenButton.setImage(utility.loadImage(named: "arrow.up.left.and.arrow.down.right", colors: [.white]), for: .normal)

        subtitleButton.setImage(utility.loadImage(named: "captions.bubble", colors: [.white]), for: .normal)
        subtitleButton.isEnabled = false
        subtitleButton.showsMenuAsPrimaryAction = true

        audioButton.setImage(utility.loadImage(named: "speaker.zzz", colors: [.white]), for: .normal)
        audioButton.isEnabled = false
        audioButton.showsMenuAsPrimaryAction = true

        if UIDevice.current.userInterfaceIdiom == .pad {
            pointSize = 60
        } else {
            pointSize = 50
        }

        playerButtonView.spacing = pointSize
        playerButtonView.isHidden = true

        buttonImage = UIImage(systemName: "gobackward.10", withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize))!.withTintColor(.white, renderingMode: .alwaysOriginal)
        backButton.setImage(buttonImage, for: .normal)

        buttonImage = UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize))!.withTintColor(.white, renderingMode: .alwaysOriginal)
        playButton.setImage(buttonImage, for: .normal)

        buttonImage = UIImage(systemName: "goforward.10", withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize))!.withTintColor(.white, renderingMode: .alwaysOriginal)
        forwardButton.setImage(buttonImage, for: .normal)

        playbackSlider.addTapGesture()
        playbackSlider.setThumbImage(UIImage(systemName: "circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15)), for: .normal)
        playbackSlider.value = 0
        playbackSlider.tintColor = .white
        playbackSlider.addTarget(self, action: #selector(playbackValChanged(slider:event:)), for: .valueChanged)
        updateRepeatButtonImage()

        utilityView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap(gestureRecognizer:))))
        playbackSliderView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap(gestureRecognizer:))))
        playbackSliderView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(tap(gestureRecognizer:))))
        playerButtonView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap(gestureRecognizer:))))

        labelCurrentTime.textColor = .white
        labelLeftTime.textColor = .white

        // Normally hide
        self.alpha = 0
        self.isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    deinit {
        print("deinit NCPlayerToolBar")
    }

    // MARK: -

    func setBarPlayer(position: Float, ncplayer: NCPlayer? = nil, metadata: tableMetadata? = nil, viewerMediaPage: NCViewerMediaPage? = nil) {
        if let ncplayer = ncplayer {
            self.ncplayer = ncplayer
        }
        if let metadata = metadata {
            self.metadata = metadata
        }
        if let viewerMediaPage = viewerMediaPage {
            self.viewerMediaPage = viewerMediaPage
        }

        playerButtonView.isHidden = true

        buttonImage = UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize))!.withTintColor(.white, renderingMode: .alwaysOriginal)
        playButton.setImage(buttonImage, for: .normal)

        playbackSlider.value = position

        labelCurrentTime.text = "--:--"
        labelLeftTime.text = "--:--"

        if viewerMediaScreenMode == .normal {
            show()
        } else {
            hide()
        }

        setupSubtitleButton()
        setupAudioButton()
    }

    public func update(position: Float, length: Float, playedTime: String, remainingTime: String?) {
        // SLIDER & TIME
        if playbackSliderEvent != .began && playbackSliderEvent != .moved {
            playbackSlider.value = position
        }
        labelCurrentTime.text = playedTime
        labelLeftTime.text = remainingTime
    }

    public func updateTopToolBar() {
        if let metadata = metadata, metadata.isVideo {
            self.subtitleButton.isEnabled = true
            self.audioButton.isEnabled = true
        }
    }

    // MARK: -

    public func show() {
        UIView.animate(withDuration: 0.5, animations: {
            self.alpha = 1
        }, completion: { (_: Bool) in
            self.isHidden = false
        })
    }

    func hide() {
        UIView.animate(withDuration: 0.5, animations: {
            self.alpha = 0
        }, completion: { (_: Bool) in
            self.isHidden = true
        })
    }

    func showPauseButton() {
        buttonImage = UIImage(systemName: "pause.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize))!.withTintColor(.white, renderingMode: .alwaysOriginal)
        playButton.setImage(buttonImage, for: .normal)
    }

    func showPlayButton() {
        buttonImage = UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize))!.withTintColor(.white, renderingMode: .alwaysOriginal)
        playButton.setImage(buttonImage, for: .normal)
    }

    // MARK: - Event / Gesture

    @objc func playbackValChanged(slider: UISlider, event: UIEvent) {
        guard let ncplayer = ncplayer else { return }
        let newPosition = playbackSlider.value

        if let touchEvent = event.allTouches?.first {
            switch touchEvent.phase {
            case .began:
                viewerMediaPage?.timerAutoHide?.invalidate()
                playbackSliderEvent = .began
            case .moved:
                ncplayer.playerPosition(newPosition)
                playbackSliderEvent = .moved
            case .ended:
                ncplayer.playerPosition(newPosition)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.playbackSliderEvent = .ended
                    self.viewerMediaPage?.startTimerAutoHide()
                }
            default:
                break
            }
        } else {
            ncplayer.playerPosition(newPosition)
            self.viewerMediaPage?.startTimerAutoHide()
        }
    }

    // MARK: - Action

    @objc func tap(gestureRecognizer: UITapGestureRecognizer) { }

    @IBAction func tapFullscreen(_ sender: Any) {
        isFullscreen = !isFullscreen
        if isFullscreen {
            fullscreenButton.setImage(utility.loadImage(named: "arrow.down.right.and.arrow.up.left", colors: [.white]), for: .normal)
        } else {
            fullscreenButton.setImage(utility.loadImage(named: "arrow.up.left.and.arrow.down.right", colors: [.white]), for: .normal)
        }
        viewerMediaPage?.changeScreenMode(mode: viewerMediaScreenMode)
    }

    private func setupSubtitleButton() {
          guard let player = ncplayer else { return }

          var currentIndex: Int?
          if let data = database.getVideoOrAudio(metadata: metadata), let idx = data.currentVideoSubTitleIndex {
              currentIndex = idx
          } else {
              currentIndex = Int(player.currentVideoSubTitleIndex)
          }

          subtitleButton.menu = NCContextMenuPlayerTracks(
              trackType: .subtitle,
              tracks: player.videoSubTitlesNames,
              trackIndexes: player.videoSubTitlesIndexes,
              currentIndex: currentIndex,
              ncplayer: ncplayer,
              metadata: metadata,
              viewerMediaPage: viewerMediaPage
          ).viewMenu()
      }

      private func setupAudioButton() {
          guard let player = ncplayer else { return }

          var currentIndex: Int?
          if let data = database.getVideoOrAudio(metadata: metadata), let idx = data.currentAudioTrackIndex {
              currentIndex = idx
          } else {
              currentIndex = Int(player.currentAudioTrackIndex)
          }

          audioButton.menu = NCContextMenuPlayerTracks(
              trackType: .audio,
              tracks: player.audioTrackNames,
              trackIndexes: player.audioTrackIndexes,
              currentIndex: currentIndex,
              ncplayer: ncplayer,
              metadata: metadata,
              viewerMediaPage: viewerMediaPage
          ).viewMenu()
      }

    @IBAction func tapPlayerPause(_ sender: Any) {
        guard let ncplayer = ncplayer else { return }

        if ncplayer.isPlaying() {
            ncplayer.playerPause()
        } else {
            ncplayer.playerPlay()
        }

        self.viewerMediaPage?.startTimerAutoHide()
    }

    @IBAction func tapForward(_ sender: Any) {
        guard let ncplayer = ncplayer else { return }

        ncplayer.jumpForward(10)
        self.viewerMediaPage?.startTimerAutoHide()
    }

    @IBAction func tapBack(_ sender: Any) {
        guard let ncplayer = ncplayer else { return }

        ncplayer.jumpBackward(10)
        self.viewerMediaPage?.startTimerAutoHide()
    }

    @IBAction func tapRepeat(_ sender: Any) {
        playRepeat.toggle()
        updateRepeatButtonImage()
    }

    private func updateRepeatButtonImage() {
        if playRepeat {
            repeatButton.setImage(utility.loadImage(named: "repeat", colors: [.white]), for: .normal)
        } else {
            repeatButton.setImage(utility.loadImage(named: "repeat", colors: [NCBrandColor.shared.iconImageColor2]), for: .normal)
        }
    }
}

extension NCPlayerToolBar: NCSelectDelegate {
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool, session: NCSession.Session) {
        if let metadata = metadata, let viewerMediaPage = viewerMediaPage {
            let fileNameLocalPath = NCUtilityFileSystem().getDirectoryProviderStorageOcId(metadata.ocId, fileName: metadata.fileNameView, userId: metadata.userId, urlBase: metadata.urlBase)
            let scene = SceneManager.shared.getWindow(controller: viewerMediaPage.tabBarController)?.windowScene

            if utilityFileSystem.fileProviderStorageExists(metadata) {
                addPlaybackSlave(type: type, metadata: metadata)
            } else {
                var downloadRequest: DownloadRequest?
                let token = showHudBanner(scene: scene,
                                          title: NSLocalizedString("_download_in_progress_", comment: ""),
                                          stage: .button) {
                    if let request = downloadRequest {
                        request.cancel()
                    }
                }

                NextcloudKit.shared.download(serverUrlFileName: metadata.serverUrlFileName, fileNameLocalPath: fileNameLocalPath, account: metadata.account, requestHandler: { request in
                    downloadRequest = request
                }, taskHandler: { task in
                    Task {
                        let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: metadata.account,
                                                                                                    path: metadata.serverUrlFileName,
                                                                                                    name: "download")
                        await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)

                        let ocId = metadata.ocId
                        await self.database.setMetadataSessionAsync(ocId: ocId,
                                                                    sessionTaskIdentifier: task.taskIdentifier,
                                                                    status: self.global.metadataStatusDownloading)
                    }
                }, progressHandler: { progress in
                    Task {@MainActor in
                        LucidBanner.shared.update(
                            payload: LucidBannerPayload.Update(progress: Double(progress.fractionCompleted)),
                            for: token)
                    }
                }) { _, etag, _, _, _, _, error in
                    Task {
                        LucidBanner.shared.dismiss()

                        let ocId = metadata.ocId
                        await self.database.setMetadataSessionAsync(ocId: ocId,
                                                                    session: "",
                                                                    sessionTaskIdentifier: 0,
                                                                    sessionError: "",
                                                                    status: self.global.metadataStatusNormal,
                                                                    etag: etag)

                        if error == .success {
                            self.addPlaybackSlave(type: type, metadata: metadata)
                        } else if error.errorCode != 200 {
                            await showErrorBanner(scene: scene, text: error.errorDescription, errorCode: error.errorCode)
                        }
                    }
                }
            }
        }
    }

    // swiftlint:disable inclusive_language
    func addPlaybackSlave(type: String, metadata: tableMetadata) {
        // swiftlint:enable inclusive_language
        let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileName: metadata.fileNameView, userId: metadata.userId, urlBase: metadata.urlBase)

        if type == "subtitle" {
            self.ncplayer?.addPlaybackSlave(URL(fileURLWithPath: fileNameLocalPath), type: .subtitle, enforce: true)
        } else if type == "audio" {
            self.ncplayer?.addPlaybackSlave(URL(fileURLWithPath: fileNameLocalPath), type: .audio, enforce: true)
        }
    }
}

// https://stackoverflow.com/questions/13196263/custom-uislider-increase-hot-spot-size
//
class NCPlayerToolBarSlider: UISlider {
    private var thumbTouchSize = CGSize(width: 100, height: 100)

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let increasedBounds = bounds.insetBy(dx: -thumbTouchSize.width, dy: -thumbTouchSize.height)
        let containsPoint = increasedBounds.contains(point)
        return containsPoint
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let percentage = CGFloat((value - minimumValue) / (maximumValue - minimumValue))
        let thumbSizeHeight = thumbRect(forBounds: bounds, trackRect: trackRect(forBounds: bounds), value: 0).size.height
        let thumbPosition = thumbSizeHeight + (percentage * (bounds.size.width - (2 * thumbSizeHeight)))
        let touchLocation = touch.location(in: self)
        return touchLocation.x <= (thumbPosition + thumbTouchSize.width) && touchLocation.x >= (thumbPosition - thumbTouchSize.width)
    }

    public func addTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))

        addGestureRecognizer(tap)
    }

    @objc private func handleTap(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: self)
        let percent = minimumValue + Float(location.x / bounds.width) * (maximumValue - minimumValue)

        setValue(percent, animated: true)
        sendActions(for: .valueChanged)
    }
}
