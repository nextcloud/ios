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
    var playbackSliderEvent: sliderEventType = .ended

    private var ncplayer: NCPlayer?
    private var metadata: tableMetadata?
    private var wasInPlay: Bool = false
    private var timerAutoHide: Timer?
    private var timerAutoHideSeconds: Double {
        get {
            if NCUtility.shared.isSimulator() { // for test
                return 150
            } else {
                return 3.5
            }
        }
    }

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

        labelCurrentTime.textColor = .white
        labelLeftTime.textColor = .white

        muteButton.setImage(NCUtility.shared.loadImage(named: "audioOn", color: .white), for: .normal)

        playButton.setImage(NCUtility.shared.loadImage(named: "play.fill", color: .white, symbolConfiguration: UIImage.SymbolConfiguration(pointSize: 30)), for: .normal)

        backButton.setImage(NCUtility.shared.loadImage(named: "gobackward.10", color: .white), for: .normal)

        forwardButton.setImage(NCUtility.shared.loadImage(named: "goforward.10", color: .white), for: .normal)
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

        playButton.setImage(NCUtility.shared.loadImage(named: "play.fill", color: .white, symbolConfiguration: UIImage.SymbolConfiguration(pointSize: 30)), for: .normal)
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 0

        playbackSlider.value = position
        playbackSlider.addTarget(self, action: #selector(onSliderValChanged(slider:event:)), for: .valueChanged)

        labelCurrentTime.text = ncplayer.player?.time.stringValue
        labelLeftTime.text = ncplayer.player?.remainingTime?.stringValue

        if CCUtility.getAudioVolume() == 0 {
            ncplayer.player?.audio?.volume = 0
            muteButton.setImage(NCUtility.shared.loadImage(named: "audioOff", color: .white), for: .normal)
        } else {
            ncplayer.player?.audio?.volume = 100
            muteButton.setImage(NCUtility.shared.loadImage(named: "audioOn", color: .white), for: .normal)
        }

        show(enableTimerAutoHide: false)
    }

    public func update() {

        guard let ncplayer = self.ncplayer,
              let length = ncplayer.player?.media?.length.intValue,
              let position = ncplayer.player?.position
        else { return }
        let positionInSecond = position * Float(length / 1000)

        // SLIDER & TIME
        if playbackSliderEvent == .ended {
            playbackSlider.value = position
        }
        labelCurrentTime.text = ncplayer.player?.time.stringValue
        labelLeftTime.text = ncplayer.player?.remainingTime?.stringValue
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyPlaybackDuration] = length / 1000
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = positionInSecond
    }

    public func disableAllControl() {

        muteButton.isEnabled = false
        playButton.isEnabled = false
        forwardButton.isEnabled = false
        backButton.isEnabled = false
        playbackSlider.isEnabled = false
    }

    // MARK: -

    public func show(enableTimerAutoHide: Bool = false) {

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

    func stopTimerAutoHide() {

        timerAutoHide?.invalidate()
    }

    func playButtonPause() {

        playButton.setImage(NCUtility.shared.loadImage(named: "pause.fill", color: .white, symbolConfiguration: UIImage.SymbolConfiguration(pointSize: 30)), for: .normal)
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 1
    }

    func playButtonPlay() {

        playButton.setImage(NCUtility.shared.loadImage(named: "play.fill", color: .white, symbolConfiguration: UIImage.SymbolConfiguration(pointSize: 30)), for: .normal)
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 0
    }

    // MARK: - Event / Gesture

    @objc func onSliderValChanged(slider: UISlider, event: UIEvent) {

        guard let touchEvent = event.allTouches?.first,
              let ncplayer = ncplayer
        else { return }

        let newPosition = playbackSlider.value

        switch touchEvent.phase {
        case .began:
            playbackSliderEvent = .began
        case .moved:
            ncplayer.playerPosition(newPosition)
            playbackSliderEvent = .moved
        case .ended:
            ncplayer.playerPosition(newPosition)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.playbackSliderEvent = .ended
            }
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

        if CCUtility.getAudioVolume() > 0 {
            CCUtility.setAudioVolume(0)
            ncplayer?.player?.audio?.volume = 0
            muteButton.setImage(NCUtility.shared.loadImage(named: "audioOff", color: .white), for: .normal)
        } else {
            CCUtility.setAudioVolume(100)
            ncplayer?.player?.audio?.volume = 100
            muteButton.setImage(NCUtility.shared.loadImage(named: "audioOn", color: .white), for: .normal)
        }

        reStartTimerAutoHide()
    }

    @IBAction func tapForward(_ sender: Any) {

        ncplayer?.player?.jumpForward(10)
        reStartTimerAutoHide()
    }

    @IBAction func tapBack(_ sender: Any) {

        ncplayer?.player?.jumpBackward(10)
        reStartTimerAutoHide()
    }
}
