//
//  NCPlayerToolBar.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 01/07/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import NextcloudKit
import CoreMedia
import UIKit
import AVKit
import MediaPlayer
import MobileVLCKit
import FloatingPanel
import JGProgressHUD
import Alamofire

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
    @IBOutlet weak var playbackSlider: UISlider!
    @IBOutlet weak var labelLeftTime: UILabel!
    @IBOutlet weak var labelCurrentTime: UILabel!
    @IBOutlet weak var repeatButton: UIButton!

    enum sliderEventType {
        case began
        case ended
        case moved
    }
    var playbackSliderEvent: sliderEventType = .ended
    var isFullscreen: Bool = false
    var playRepeat: Bool = false

    private let hud = JGProgressHUD()
    private var ncplayer: NCPlayer?
    private var metadata: tableMetadata?
    private let audioSession = AVAudioSession.sharedInstance()
    private var pointSize: CGFloat = 0

    private weak var viewerMediaPage: NCViewerMediaPage?

    // MARK: - View Life Cycle

    override func awakeFromNib() {
        super.awakeFromNib()

        self.backgroundColor = UIColor.black.withAlphaComponent(0.1)

        fullscreenButton.setImage(NCUtility.shared.loadImage(named: "arrow.up.left.and.arrow.down.right", color: .white), for: .normal)

        subtitleButton.setImage(NCUtility.shared.loadImage(named: "captions.bubble", color: .white), for: .normal)
        subtitleButton.isEnabled = false

        audioButton.setImage(NCUtility.shared.loadImage(named: "speaker.zzz", color: .white), for: .normal)
        audioButton.isEnabled = false

        if UIDevice.current.userInterfaceIdiom == .pad {
            pointSize = 60
        } else {
            pointSize = 50
        }

        playerButtonView.spacing = pointSize
        playerButtonView.isHidden = true

        backButton.setImage(NCUtility.shared.loadImage(named: "gobackward.10", color: .white, symbolConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize)), for: .normal)
        playButton.setImage(NCUtility.shared.loadImage(named: "play.fill", color: .white, symbolConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize)), for: .normal)
        forwardButton.setImage(NCUtility.shared.loadImage(named: "goforward.10", color: .white, symbolConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize)), for: .normal)

        playbackSlider.setThumbImage(UIImage(systemName: "circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15)), for: .normal)
        playbackSlider.value = 0
        playbackSlider.tintColor = .white
        playbackSlider.addTarget(self, action: #selector(playbackValChanged(slider:event:)), for: .valueChanged)
        repeatButton.setImage(NCUtility.shared.loadImage(named: "repeat", color: .gray), for: .normal)

        utilityView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap(gestureRecognizer:))))
        playbackSliderView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap(gestureRecognizer:))))
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
        
        playButton.setImage(NCUtility.shared.loadImage(named: "play.fill", color: .white, symbolConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize)), for: .normal)

        playbackSlider.value = position

        labelCurrentTime.text = "--:--"
        labelLeftTime.text = "--:--"

        if viewerMediaScreenMode == .normal {
            show()
        } else {
            hide()
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = position
    }

    public func update() {

        guard let ncplayer = self.ncplayer,
              let length = ncplayer.player.media?.length.intValue
        else { return }

        let position = ncplayer.player.position
        let positionInSecond = position * Float(length / 1000)

        // SLIDER & TIME
        if playbackSliderEvent == .ended {
            playbackSlider.value = position
        }
        labelCurrentTime.text = ncplayer.player.time.stringValue
        labelLeftTime.text = ncplayer.player.remainingTime?.stringValue

        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyPlaybackDuration] = length / 1000
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = positionInSecond
    }

    public func updateTopToolBar(videoSubTitlesIndexes: [Any], audioTrackIndexes: [Any]) {

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

    func playButtonPause() {

        playButton.setImage(NCUtility.shared.loadImage(named: "pause.fill", color: .white, symbolConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize)), for: .normal)
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 1
    }

    func playButtonPlay() {

        playButton.setImage(NCUtility.shared.loadImage(named: "play.fill", color: .white, symbolConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize)), for: .normal)
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 0
    }

    // MARK: - Event / Gesture

    @objc func playbackValChanged(slider: UISlider, event: UIEvent) {

        guard let touchEvent = event.allTouches?.first,
              let ncplayer = ncplayer
        else { return }

        let newPosition = playbackSlider.value

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
    }

    // MARK: - Action

    @objc func tap(gestureRecognizer: UITapGestureRecognizer) { }

    @IBAction func tapFullscreen(_ sender: Any) {

        isFullscreen = !isFullscreen
        if isFullscreen {
            fullscreenButton.setImage(NCUtility.shared.loadImage(named: "arrow.down.right.and.arrow.up.left", color: .white), for: .normal)
        } else {
            fullscreenButton.setImage(NCUtility.shared.loadImage(named: "arrow.up.left.and.arrow.down.right", color: .white), for: .normal)
        }
        viewerMediaPage?.changeScreenMode(mode: viewerMediaScreenMode)
    }

    @IBAction func tapSubTitle(_ sender: Any) {

        guard let player = ncplayer?.player else { return }

        let spuTracks = player.videoSubTitlesNames
        let spuTrackIndexes = player.videoSubTitlesIndexes

        toggleMenuSubTitle(spuTracks: spuTracks, spuTrackIndexes: spuTrackIndexes)
    }

    @IBAction func tapAudio(_ sender: Any) {

        guard let player = ncplayer?.player else { return }

        let audioTracks = player.audioTrackNames
        let audioTrackIndexes = player.audioTrackIndexes

        toggleMenuAudio(audioTracks: audioTracks, audioTrackIndexes: audioTrackIndexes)
    }

    @IBAction func tapPlayerPause(_ sender: Any) {
        guard let ncplayer = ncplayer else { return }

        if ncplayer.isPlay() {
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

        if playRepeat {
            playRepeat = false
            repeatButton.setImage(NCUtility.shared.loadImage(named: "repeat", color: .gray), for: .normal)
        } else {
            playRepeat = true
            repeatButton.setImage(NCUtility.shared.loadImage(named: "repeat", color: .white), for: .normal)
        }
    }
}

extension NCPlayerToolBar {

    func toggleMenuSubTitle(spuTracks: [Any], spuTrackIndexes: [Any]) {

        var actions = [NCMenuAction]()
        var subTitleIndex: Int?

        if let data = NCManageDatabase.shared.getVideo(metadata: metadata), let idx = data.currentVideoSubTitleIndex {
            subTitleIndex = idx
        } else if let idx = ncplayer?.player.currentVideoSubTitleIndex {
            subTitleIndex = Int(idx)
        }

        if !spuTracks.isEmpty {
            for index in 0...spuTracks.count - 1 {

                guard let title = spuTracks[index] as? String, let idx = spuTrackIndexes[index] as? Int32, let metadata = self.metadata else { return }

                actions.append(
                    NCMenuAction(
                        title: title,
                        icon: UIImage(),
                        onTitle: title,
                        onIcon: UIImage(),
                        selected: (subTitleIndex ?? -9999) == idx,
                        on: (subTitleIndex ?? -9999) == idx,
                        action: { _ in
                            self.ncplayer?.player.currentVideoSubTitleIndex = idx
                            NCManageDatabase.shared.addVideo(metadata: metadata, currentVideoSubTitleIndex: Int(idx))
                        }
                    )
                )
            }

            actions.append(.seperator(order: 0))
        }

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_add_subtitle_", comment: ""),
                icon: UIImage(),
                onTitle: NSLocalizedString("_add_subtitle_", comment: ""),
                onIcon: UIImage(),
                selected: false,
                on: false,
                action: { _ in

                    guard let metadata = self.metadata else { return }
                    let storyboard = UIStoryboard(name: "NCSelect", bundle: nil)
                    let navigationController = storyboard.instantiateInitialViewController() as! UINavigationController
                    let viewController = navigationController.topViewController as! NCSelect

                    viewController.delegate = self
                    viewController.typeOfCommandView = .nothing
                    viewController.includeDirectoryE2EEncryption = false
                    viewController.enableSelectFile = true
                    viewController.type = "subtitle"
                    viewController.serverUrl = metadata.serverUrl

                    self.viewerMediaPage?.present(navigationController, animated: true, completion: nil)
                }
            )
        )

        viewerMediaPage?.presentMenu(with: actions, menuColor: UIColor(hexString: "#1C1C1EFF"), textColor: .white)
    }

    func toggleMenuAudio(audioTracks: [Any], audioTrackIndexes: [Any]) {

        var actions = [NCMenuAction]()
        var audioIndex: Int?

        if let data = NCManageDatabase.shared.getVideo(metadata: metadata), let idx = data.currentAudioTrackIndex {
            audioIndex = idx
        } else if let idx = ncplayer?.player.currentAudioTrackIndex {
            audioIndex = Int(idx)
        }

        if !audioTracks.isEmpty {
            for index in 0...audioTracks.count - 1 {

                guard let title = audioTracks[index] as? String, let idx = audioTrackIndexes[index] as? Int32, let metadata = self.metadata else { return }

                actions.append(
                    NCMenuAction(
                        title: title,
                        icon: UIImage(),
                        onTitle: title,
                        onIcon: UIImage(),
                        selected: (audioIndex ?? -9999) == idx,
                        on: (audioIndex ?? -9999) == idx,
                        action: { _ in
                            self.ncplayer?.player.currentAudioTrackIndex = idx
                            NCManageDatabase.shared.addVideo(metadata: metadata, currentAudioTrackIndex: Int(idx))
                        }
                    )
                )
            }

            actions.append(.seperator(order: 0))
        }

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_add_audio_", comment: ""),
                icon: UIImage(),
                onTitle: NSLocalizedString("_add_audio_", comment: ""),
                onIcon: UIImage(),
                selected: false,
                on: false,
                action: { _ in

                    guard let metadata = self.metadata else { return }
                    let storyboard = UIStoryboard(name: "NCSelect", bundle: nil)
                    let navigationController = storyboard.instantiateInitialViewController() as! UINavigationController
                    let viewController = navigationController.topViewController as! NCSelect

                    viewController.delegate = self
                    viewController.typeOfCommandView = .nothing
                    viewController.includeDirectoryE2EEncryption = false
                    viewController.enableSelectFile = true
                    viewController.type = "audio"
                    viewController.serverUrl = metadata.serverUrl

                    self.viewerMediaPage?.present(navigationController, animated: true, completion: nil)
                }
            )
        )

        viewerMediaPage?.presentMenu(with: actions, menuColor: UIColor(hexString: "#1C1C1EFF"), textColor: .white)
    }
}

extension NCPlayerToolBar: NCSelectDelegate {

    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool) {

        if let metadata = metadata, let viewerMediaPage = viewerMediaPage {

            let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
            let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!

            if CCUtility.fileProviderStorageExists(metadata) {
                addPlaybackSlave(type: type, metadata: metadata)
            } else {
                var downloadRequest: DownloadRequest?
                hud.indicatorView = JGProgressHUDRingIndicatorView()
                hud.detailTextLabel.text = NSLocalizedString("_tap_to_cancel_", comment: "")
                if let indicatorView = hud.indicatorView as? JGProgressHUDRingIndicatorView {
                    indicatorView.ringWidth = 1.5
                }
                hud.tapOnHUDViewBlock = { _ in
                    if let request = downloadRequest {
                        request.cancel()
                    }
                }
                hud.show(in: viewerMediaPage.view)

                NextcloudKit.shared.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, requestHandler: { request in
                    downloadRequest = request
                }, taskHandler: { _ in
                }, progressHandler: { progress in
                    self.hud.progress = Float(progress.fractionCompleted)
                }) { account, _, _, _, _, _, error in
                    self.hud.dismiss()
                    if error == .success {
                        self.addPlaybackSlave(type: type, metadata: metadata)
                    } else if error.errorCode != 200 {
                        NCContentPresenter.shared.showError(error: error)
                    }
                }
            }
        }
    }

    func addPlaybackSlave(type: String, metadata: tableMetadata) {

        let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!

        if type == "subtitle" {
            self.ncplayer?.player.addPlaybackSlave(URL(fileURLWithPath: fileNameLocalPath), type: .subtitle, enforce: true)
        } else if type == "audio" {
            self.ncplayer?.player.addPlaybackSlave(URL(fileURLWithPath: fileNameLocalPath), type: .audio, enforce: true)
        }
    }
}
