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

class NCPlayerToolBar: UIView {

    @IBOutlet weak var playerTopToolBarView: UIStackView!
    @IBOutlet weak var playerToolBarView: UIView!
    @IBOutlet weak var muteButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var forwardButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var playbackSlider: UISlider!
    @IBOutlet weak var labelLeftTime: UILabel!
    @IBOutlet weak var labelCurrentTime: UILabel!

    enum sliderEventType {
        case began
        case ended
        case moved
    }

    var ncplayer: NCPlayer?
    private var metadata: tableMetadata?
    private var wasInPlay: Bool = false
    private var playbackSliderEvent: sliderEventType = .ended
    private var timerAutoHide: Timer?

    private var timerAutoHideSeconds: Double {
        get {
            if NCUtility.shared.isSimulator() { // for test
                return 15
            } else {
                return 3.5
            }
        }
    }

    weak var viewerMediaPage: NCViewerMediaPage?

    // MARK: - View Life Cycle

    override func awakeFromNib() {
        super.awakeFromNib()

        let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blurEffectView.frame = self.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        playerToolBarView.insertSubview(blurEffectView, at: 0)
        playerTopToolBarView.layer.cornerRadius = 10
        playerTopToolBarView.layer.masksToBounds = true
        playerTopToolBarView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapTopToolBarWith(gestureRecognizer:))))

        let blurEffectTopToolBarView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blurEffectTopToolBarView.frame = playerTopToolBarView.bounds
        blurEffectTopToolBarView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        playerTopToolBarView.insertSubview(blurEffectTopToolBarView, at: 0)
        playerToolBarView.layer.cornerRadius = 10
        playerToolBarView.layer.masksToBounds = true
        playerToolBarView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapToolBarWith(gestureRecognizer:))))

        playbackSlider.value = 0
        playbackSlider.minimumValue = 0
        playbackSlider.maximumValue = 1
        playbackSlider.isContinuous = true
        playbackSlider.tintColor = .lightGray
        playbackSlider.isEnabled = false

        labelCurrentTime.text = NCUtility.shared.stringFromTime(.zero)
        labelCurrentTime.textColor = .lightGray
        labelLeftTime.text = NCUtility.shared.stringFromTime(.zero)
        labelLeftTime.textColor = .lightGray

        muteButton.setImage(NCUtility.shared.loadImage(named: "audioOff", color: .lightGray), for: .normal)
        muteButton.isEnabled = false

        playButton.setImage(NCUtility.shared.loadImage(named: "play.fill", color: .lightGray, symbolConfiguration: UIImage.SymbolConfiguration(pointSize: 30)), for: .normal)
        playButton.isEnabled = false

        backButton.setImage(NCUtility.shared.loadImage(named: "gobackward.10", color: .lightGray), for: .normal)
        backButton.isEnabled = false
        
        forwardButton.setImage(NCUtility.shared.loadImage(named: "goforward.10", color: .lightGray), for: .normal)
        forwardButton.isEnabled = false
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    deinit {
        print("deinit NCPlayerToolBar")
    }

    // MARK: -

    func setBarPlayer(ncplayer: NCPlayer, position: Float, metadata: tableMetadata) {

        self.ncplayer = ncplayer
        self.metadata = metadata

        playbackSlider.value = position
        playbackSlider.addTarget(self, action: #selector(onSliderValChanged(slider:event:)), for: .valueChanged)

        labelCurrentTime.text = ncplayer.player?.time.stringValue
        labelLeftTime.text = ncplayer.player?.remainingTime?.stringValue

        show(enableTimerAutoHide: false)
        update(position: position)
    }

    public func buffering() {

        muteButton.isEnabled = false
        playButton.isEnabled = false
        forwardButton.isEnabled = false
        backButton.isEnabled = false
        playbackSlider.isEnabled = false
    }

    public func update(position: Float?) {

        guard let ncplayer = self.ncplayer,
              let length = ncplayer.player?.media?.length.intValue,
              let position = position
        else { return }

        // SAVE POSITION
        if position > 0 {
            ncplayer.savePosition(position)
        }

        // MUTE
        if let muteButton = muteButton {
            let audio = CCUtility.getAudioVolume()
            if audio == 0 {
                muteButton.setImage(NCUtility.shared.loadImage(named: "audioOff", color: .white), for: .normal)
            } else {
                muteButton.setImage(NCUtility.shared.loadImage(named: "audioOn", color: .white), for: .normal)
            }
            muteButton.isEnabled = true
        }

        // SLIDER TIME (START - END)
        playbackSlider.value = position
        playbackSlider.isEnabled = true
        labelCurrentTime.text = ncplayer.player?.time.stringValue
        labelLeftTime.text = ncplayer.player?.remainingTime?.stringValue

        // BACK FORWARD
        if length > 0 {
            forwardButton.isEnabled = true
            forwardButton.setImage(NCUtility.shared.loadImage(named: "goforward.10", color: .white), for: .normal)
            backButton.isEnabled = true
            backButton.setImage(NCUtility.shared.loadImage(named: "gobackward.10", color: .white), for: .normal)
        } else {
            backButton.isEnabled = false
            backButton.setImage(NCUtility.shared.loadImage(named: "gobackward.10", color: .lightGray), for: .normal)
            forwardButton.isEnabled = false
            forwardButton.setImage(NCUtility.shared.loadImage(named: "goforward.10", color: .lightGray), for: .normal)
        }

        // PLAY
        if ncplayer.isPlay() {
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 1
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 0
        }
        let namedPlay = ncplayer.isPlay() ? "pause.fill" : "play.fill"
        playButton.setImage(NCUtility.shared.loadImage(named: namedPlay, color: .white, symbolConfiguration: UIImage.SymbolConfiguration(pointSize: 30)), for: .normal)
        playButton.isEnabled = true


    }

    // MARK: -

    public func show(enableTimerAutoHide: Bool = false) {

        guard let metadata = self.metadata, ncplayer != nil, !metadata.livePhoto else { return }
        if metadata.classFile != NKCommon.TypeClassFile.video.rawValue && metadata.classFile != NKCommon.TypeClassFile.audio.rawValue { return }

        timerAutoHide?.invalidate()
        if enableTimerAutoHide {
            startTimerAutoHide()
        }
        if !self.isHidden { return }

        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 1
        }, completion: { (_: Bool) in
            self.isHidden = false
        })

        update(position: ncplayer?.player?.position)
    }

    func isShow() -> Bool {

        return !self.isHidden
    }

    public func hide() {

        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
        }, completion: { (_: Bool) in
            self.isHidden = true
        })
    }

    @objc private func automaticHide() {

        if let metadata = self.metadata {
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterHidePlayerToolBar, userInfo: ["ocId": metadata.ocId])
        }
    }

    private func startTimerAutoHide() {

        timerAutoHide?.invalidate()
        timerAutoHide = Timer.scheduledTimer(timeInterval: timerAutoHideSeconds, target: self, selector: #selector(automaticHide), userInfo: nil, repeats: false)
    }

    private func reStartTimerAutoHide() {

        if let timerAutoHide = timerAutoHide, timerAutoHide.isValid {
            startTimerAutoHide()
        }
    }

    func skip(seconds: Float) {
        guard let ncplayer = ncplayer,
              let player = ncplayer.player,
              let length = player.media?.length.intValue
        else { return }

        let currentPosition = player.position * Float(length / 1000)
        var newPosition = (currentPosition + seconds) / Float(length / 1000)

        if newPosition < 0 || newPosition > 1 {
            newPosition = 0
        }

        ncplayer.videoSeek(position: newPosition)
        update(position: newPosition)
        reStartTimerAutoHide()
    }

    func stopTimerAutoHide() {

        timerAutoHide?.invalidate()
    }

    // MARK: - Event / Gesture

    @objc func onSliderValChanged(slider: UISlider, event: UIEvent) {

        guard let touchEvent = event.allTouches?.first,
              let ncplayer = ncplayer
        else { return }

        let newPosition = self.playbackSlider.value

        switch touchEvent.phase {
        case .began:
            ncplayer.playerPause()
            playbackSliderEvent = .began
        case .moved:
            playbackSliderEvent = .moved
        case .ended:
            ncplayer.playerPlay()
            ncplayer.videoSeek(position: newPosition)
            playbackSliderEvent = .ended
        default:
            break
        }

        reStartTimerAutoHide()

    }

    // MARK: - Action

    @objc func tapTopToolBarWith(gestureRecognizer: UITapGestureRecognizer) { }

    @objc func tapToolBarWith(gestureRecognizer: UITapGestureRecognizer) { }

    @IBAction func tapPlayerPause(_ sender: Any) {
        guard let ncplayer = ncplayer else { return }

        if ncplayer.isPlay() {
            ncplayer.playerPause()
            timerAutoHide?.invalidate()
        } else {
            ncplayer.playerPlay()
            startTimerAutoHide()
        }
    }

    @IBAction func tapMute(_ sender: Any) {

        let volume = CCUtility.getAudioVolume()

        if volume > 0 {
            CCUtility.setAudioVolume(0)
            ncplayer?.player?.audio?.volume = 0
        } else {
            CCUtility.setAudioVolume(100)
            ncplayer?.player?.audio?.volume = 100
        }

        update(position: ncplayer?.player?.position)
        reStartTimerAutoHide()
    }

    @IBAction func tapForward(_ sender: Any) {

        skip(seconds: 10)
    }

    @IBAction func tapBack(_ sender: Any) {

        skip(seconds: -10)
    }

    func forward() {

        var index: Int = 0

        if let currentIndex = self.viewerMediaPage?.currentIndex, let metadatas = self.viewerMediaPage?.metadatas, let ncplayer = self.ncplayer {

            if currentIndex == metadatas.count - 1 {
                index = 0
            } else {
                index = currentIndex + 1
            }

            self.viewerMediaPage?.goTo(index: index, direction: .forward, autoPlay: ncplayer.isPlay())
        }
    }

    func backward() {

        var index: Int = 0

        if let currentIndex = self.viewerMediaPage?.currentIndex, let metadatas = self.viewerMediaPage?.metadatas, let ncplayer = self.ncplayer {

            if currentIndex == 0 {
                index = metadatas.count - 1
            } else {
                index = currentIndex - 1
            }

            self.viewerMediaPage?.goTo(index: index, direction: .reverse, autoPlay: ncplayer.isPlay())
        }
    }
}

extension NCPlayerToolBar: AVPictureInPictureControllerDelegate {

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {

        if let metadata = self.metadata, let ncplayer = self.ncplayer, !ncplayer.isPlay() {
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShowPlayerToolBar, userInfo: ["ocId": metadata.ocId, "enableTimerAutoHide": false])
        }
    }
}
