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

class NCPlayerToolBar: UIView {

    @IBOutlet weak var playerTopToolBarView: UIStackView!
    @IBOutlet weak var playerToolBarView: UIView!
    @IBOutlet weak var pipButton: UIButton!
    @IBOutlet weak var subtitleButton: UIButton!
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


// NCUtility.shared.isSimulatorOrTestFlight()

    var pictureInPictureController: AVPictureInPictureController?
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

        pipButton.setImage(NCUtility.shared.loadImage(named: "pip.enter", color: .lightGray), for: .normal)
        pipButton.isEnabled = false

        muteButton.setImage(NCUtility.shared.loadImage(named: "audioOff", color: .lightGray), for: .normal)
        muteButton.isEnabled = false

        subtitleButton.setImage(NCUtility.shared.loadImage(named: "captions.bubble", color: .white), for: .normal)
        subtitleButton.isEnabled = true
        subtitleButton.isHidden = true

        playbackSlider.value = 0
        playbackSlider.minimumValue = 0
        playbackSlider.maximumValue = 0
        playbackSlider.isContinuous = true
        playbackSlider.tintColor = .lightGray
        playbackSlider.isEnabled = false

        labelCurrentTime.text = NCUtility.shared.stringFromTime(.zero)
        labelCurrentTime.textColor = .lightGray
        labelLeftTime.text = NCUtility.shared.stringFromTime(.zero)
        labelLeftTime.textColor = .lightGray

        backButton.setImage(NCUtility.shared.loadImage(named: "gobackward.10", color: .lightGray), for: .normal)
        backButton.isEnabled = false

        playButton.setImage(NCUtility.shared.loadImage(named: "play.fill", color: .lightGray, symbolConfiguration: UIImage.SymbolConfiguration(pointSize: 30)), for: .normal)
        playButton.isEnabled = false

        forwardButton.setImage(NCUtility.shared.loadImage(named: "goforward.10", color: .lightGray), for: .normal)
        forwardButton.isEnabled = false

        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    deinit {
        print("deinit NCPlayerToolBar")

        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
    }

    // MARK: -

    func setMetadata(_ metadata: tableMetadata) {

        self.metadata = metadata
    }

    func setBarPlayer(ncplayer: NCPlayer) {

        self.ncplayer = ncplayer

        playbackSlider.value = 0
        playbackSlider.minimumValue = 0
        playbackSlider.maximumValue = Float(ncplayer.durationTime.seconds)
        playbackSlider.addTarget(self, action: #selector(onSliderValChanged(slider:event:)), for: .valueChanged)

        labelCurrentTime.text = NCUtility.shared.stringFromTime(.zero)
        labelLeftTime.text = "-" + NCUtility.shared.stringFromTime(ncplayer.durationTime)

        updateToolBar()
    }

    public func updateToolBar() {

        guard let ncplayer = self.ncplayer else { return }

        // MUTE
        if let muteButton = muteButton {
            if CCUtility.getAudioMute() {
                muteButton.setImage(NCUtility.shared.loadImage(named: "audioOff", color: .white), for: .normal)
            } else {
                muteButton.setImage(NCUtility.shared.loadImage(named: "audioOn", color: .white), for: .normal)
            }
            muteButton.isEnabled = true
        }

        // PIP
        if let pipButton = pipButton {
            if metadata?.classFile == NKCommon.TypeClassFile.video.rawValue && AVPictureInPictureController.isPictureInPictureSupported() {
                pipButton.setImage(NCUtility.shared.loadImage(named: "pip.enter", color: .white), for: .normal)
                pipButton.isEnabled = true
            } else {
                pipButton.setImage(NCUtility.shared.loadImage(named: "pip.enter", color: .gray), for: .normal)
                pipButton.isEnabled = false
            }
        }

        // SLIDER TIME (START - END)
        let time = (ncplayer.player?.currentTime() ?? .zero).convertScale(1000, method: .default)
        playbackSlider.value = Float(time.seconds)
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time.seconds
        playbackSlider.isEnabled = true
        labelCurrentTime.text = NCUtility.shared.stringFromTime(time)
        labelLeftTime.text = "-" + NCUtility.shared.stringFromTime(ncplayer.durationTime - time)

        // BACK
        backButton.setImage(NCUtility.shared.loadImage(named: "gobackward.10", color: .white), for: .normal)
        backButton.isEnabled = true

        // PLAY
        if ncplayer.isPlay() {
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 1
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 0
        }
        let namedPlay = ncplayer.isPlay() ? "pause.fill" : "play.fill"
        playButton.setImage(NCUtility.shared.loadImage(named: namedPlay, color: .white, symbolConfiguration: UIImage.SymbolConfiguration(pointSize: 30)), for: .normal)
        playButton.isEnabled = true

        // FORWARD
        forwardButton.setImage(NCUtility.shared.loadImage(named: "goforward.10", color: .white), for: .normal)
        forwardButton.isEnabled = true
    }

    // MARK: Handle Notifications

    @objc func handleRouteChange(notification: Notification) {

        guard let userInfo = notification.userInfo, let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt, let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        switch reason {
        case .newDeviceAvailable:
            let session = AVAudioSession.sharedInstance()
            for output in session.currentRoute.outputs where output.portType == AVAudioSession.Port.headphones {
                print("headphones connected")
                ncplayer?.playerPlay()
                startTimerAutoHide()
                break
            }
        case .oldDeviceUnavailable:
            if let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                for output in previousRoute.outputs where output.portType == AVAudioSession.Port.headphones {
                    print("headphones disconnected")
                    ncplayer?.playerPause()
                    ncplayer?.saveCurrentTime()
                    break
                }
            }
        default: ()
        }
    }

    @objc func handleInterruption(notification: Notification) {

        guard let userInfo = notification.userInfo, let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt, let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        if type == .began {
            print("Interruption began")
        } else if type == .ended {
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    print("Interruption Ended - playback should resume")
                    ncplayer?.playerPlay()
                    startTimerAutoHide()
                } else {
                    print("Interruption Ended - playback should NOT resume")
                }
            }
        }
    }

    // MARK: -

    public func show(enableTimerAutoHide: Bool = false) {

        guard let metadata = self.metadata, ncplayer != nil, !metadata.livePhoto else { return }
        if metadata.classFile != NKCommon.TypeClassFile.video.rawValue && metadata.classFile != NKCommon.TypeClassFile.audio.rawValue { return }

#if MFFFLIB
        if MFFF.shared.existsMFFFSession(url: URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))) {
            self.hide()
            return
        }
#endif

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

        updateToolBar()
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

    func skip(seconds: Float64) {

        guard let ncplayer = ncplayer, let player = ncplayer.player else { return }

        let currentTime = player.currentTime()
        var newTime: CMTime = .zero
        let timeToAdd: CMTime = CMTimeMakeWithSeconds(abs(seconds), preferredTimescale: 1)

        if seconds > 0 {
            newTime = CMTimeAdd(currentTime, timeToAdd)
            if newTime < ncplayer.durationTime {
                ncplayer.videoSeek(time: newTime)
            } else if newTime >= ncplayer.durationTime {
                let timeToSubtract: CMTime = CMTimeMakeWithSeconds(3, preferredTimescale: 1)
                newTime = CMTimeSubtract(ncplayer.durationTime, timeToSubtract)
                if newTime > currentTime {
                    ncplayer.videoSeek(time: newTime)
                }
            }
        } else {
            newTime = CMTimeSubtract(currentTime, timeToAdd)
            if newTime.seconds < 0 {
                newTime = .zero
            }
            ncplayer.videoSeek(time: newTime)
        }

        updateToolBar()
        reStartTimerAutoHide()
    }

    func isPictureInPictureActive() -> Bool {

        if let pictureInPictureController = self.pictureInPictureController, pictureInPictureController.isPictureInPictureActive {
            return true
        } else {
            return false
        }
    }

    func stopTimerAutoHide() {

        timerAutoHide?.invalidate()
    }

    // MARK: - Event / Gesture

    @objc func onSliderValChanged(slider: UISlider, event: UIEvent) {

        if let touchEvent = event.allTouches?.first, let ncplayer = ncplayer {

            let seconds: Int64 = Int64(self.playbackSlider.value)
            let targetTime: CMTime = CMTimeMake(value: seconds, timescale: 1)

            switch touchEvent.phase {
            case .began:
                wasInPlay = ncplayer.isPlay()
                ncplayer.playerPause()
                playbackSliderEvent = .began
            case .moved:
                ncplayer.videoSeek(time: targetTime)
                playbackSliderEvent = .moved
            case .ended:
                ncplayer.videoSeek(time: targetTime)
                if wasInPlay {
                    ncplayer.playerPlay()
                }
                playbackSliderEvent = .ended
            default:
                break
            }

            reStartTimerAutoHide()
        }
    }

    // MARK: - Action

    @objc func tapTopToolBarWith(gestureRecognizer: UITapGestureRecognizer) { }

    @objc func tapToolBarWith(gestureRecognizer: UITapGestureRecognizer) { }

    @IBAction func tapPlayerPause(_ sender: Any) {

        if ncplayer?.player?.timeControlStatus == .playing {
            CCUtility.setPlayerPlay(false)
            ncplayer?.playerPause()
            ncplayer?.saveCurrentTime()
            timerAutoHide?.invalidate()
        } else if ncplayer?.player?.timeControlStatus == .paused {
            CCUtility.setPlayerPlay(true)
            ncplayer?.playerPlay()
            startTimerAutoHide()
        } else if ncplayer?.player?.timeControlStatus == .waitingToPlayAtSpecifiedRate {
            print("timeControlStatus.waitingToPlayAtSpecifiedRate")
            if let reason = ncplayer?.player?.reasonForWaitingToPlay {
                switch reason {
                case .evaluatingBufferingRate:
                    self.ncplayer?.player?.playImmediately(atRate: 1)
                    print("reasonForWaitingToPlay.evaluatingBufferingRate")
                case .toMinimizeStalls:
                    print("reasonForWaitingToPlay.toMinimizeStalls")
                case .noItemToPlay:
                    print("reasonForWaitingToPlay.noItemToPlay")
                default:
                    print("Unknown \(reason)")
                }
            }
        }
    }

    @IBAction func tapMute(_ sender: Any) {

        let mute = CCUtility.getAudioMute()

        CCUtility.setAudioMute(!mute)
        ncplayer?.player?.isMuted = !mute
        updateToolBar()
        reStartTimerAutoHide()
    }

    @IBAction func tapPip(_ sender: Any) {

        guard let videoLayer = ncplayer?.videoLayer else { return }

        if let pictureInPictureController = self.pictureInPictureController, pictureInPictureController.isPictureInPictureActive {
            pictureInPictureController.stopPictureInPicture()
        }

        if pictureInPictureController == nil {
            pictureInPictureController = AVPictureInPictureController(playerLayer: videoLayer)
            pictureInPictureController?.delegate = self
        }

        if let pictureInPictureController = pictureInPictureController, pictureInPictureController.isPictureInPicturePossible, let metadata = self.metadata {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                pictureInPictureController.startPictureInPicture()
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterHidePlayerToolBar, userInfo: ["ocId": metadata.ocId])
            }
        }
    }

    @IBAction func tapForward(_ sender: Any) {

        skip(seconds: 10)
    }

    @IBAction func tapBack(_ sender: Any) {

        skip(seconds: -10)
    }

    @IBAction func tapSubtitle(_ sender: Any) {
        self.ncplayer?.showAlertSubtitles()
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
