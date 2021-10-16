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
import NCCommunication
import CoreMedia
import UIKit
import AVKit
import MediaPlayer

class NCPlayerToolBar: UIView {
    
    @IBOutlet weak var playerTopToolBarView: UIView!
    @IBOutlet weak var pipButton: UIButton!
    @IBOutlet weak var muteButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var forwardButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var playbackSlider: UISlider!
    @IBOutlet weak var labelOverallDuration: UILabel!
    @IBOutlet weak var labelCurrentTime: UILabel!
    
    enum sliderEventType {
        case began
        case ended
        case moved
    }
        
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var ncplayer: NCPlayer?
    private var wasInPlay: Bool = false
    private var playbackSliderEvent: sliderEventType = .ended
    private var durationTime: CMTime = .zero
    private var timeObserver: Any?
    private var timerAutoHide: Timer?
    private var metadata: tableMetadata?
    private var image: UIImage?
    
    // MARK: - View Life Cycle

    override func awakeFromNib() {
        super.awakeFromNib()
        
        // for disable gesture of UIPageViewController
        let panRecognizer = UIPanGestureRecognizer(target: self, action: nil)
        addGestureRecognizer(panRecognizer)
        let singleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didSingleTapWith(gestureRecognizer:)))
        addGestureRecognizer(singleTapGestureRecognizer)
        
        // self
        self.layer.cornerRadius = 15
        self.layer.masksToBounds = true
        
        let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blurEffectView.frame = self.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.insertSubview(blurEffectView, at:0)
        
        // Top ToolBar
        playerTopToolBarView.layer.cornerRadius = 10
        playerTopToolBarView.layer.masksToBounds = true
        
        let blurEffectTopToolBarView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blurEffectTopToolBarView.frame = playerTopToolBarView.bounds
        blurEffectTopToolBarView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        playerTopToolBarView.insertSubview(blurEffectTopToolBarView, at:0)
        
        pipButton.setImage(NCUtility.shared.loadImage(named: "pip.enter", color: .lightGray), for: .normal)
        pipButton.isEnabled = false
        
        muteButton.setImage(NCUtility.shared.loadImage(named: "audioOff", color: .lightGray), for: .normal)
        muteButton.isEnabled = false
        
        playbackSlider.value = 0
        playbackSlider.minimumValue = 0
        playbackSlider.maximumValue = 0
        playbackSlider.isContinuous = true
        playbackSlider.tintColor = .lightGray
        playbackSlider.isEnabled = false
        
        labelCurrentTime.text = NCUtility.shared.stringFromTime(.zero)
        labelCurrentTime.textColor = .lightGray
        labelOverallDuration.text = NCUtility.shared.stringFromTime(.zero)
        labelOverallDuration.textColor = .lightGray
        
        backButton.setImage(NCUtility.shared.loadImage(named: "gobackward.10", color: .lightGray), for: .normal)
        backButton.isEnabled = false
        
        playButton.setImage(NCUtility.shared.loadImage(named: "play.fill", color: .lightGray), for: .normal)
        playButton.isEnabled = false
        
        forwardButton.setImage(NCUtility.shared.loadImage(named: "goforward.10", color: .lightGray), for: .normal)
        forwardButton.isEnabled = false
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
    }
    
    deinit {
        print("deinit NCPlayerToolBar")
        
        if self.timeObserver != nil {
            appDelegate.player?.removeTimeObserver(self.timeObserver!)
        }
        
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
    }
    
    // MARK: -

    func setBarPlayer(ncplayer: NCPlayer, timeSeek: CMTime, metadata: tableMetadata, image: UIImage?) {
                        
        self.ncplayer = ncplayer
        self.metadata = metadata
        self.image = image
                
        if let durationTime = NCManageDatabase.shared.getVideoDurationTime(metadata: ncplayer.metadata) {
        
            self.durationTime = durationTime
            
            playbackSlider.value = 0
            playbackSlider.minimumValue = 0
            playbackSlider.maximumValue = Float(durationTime.value)
            playbackSlider.addTarget(self, action: #selector(onSliderValChanged(slider:event:)), for: .valueChanged)

            labelCurrentTime.text = NCUtility.shared.stringFromTime(.zero)
            labelOverallDuration.text = "-" + NCUtility.shared.stringFromTime(durationTime)
        }
        
        if let ncplayer = self.ncplayer {
        
            UIApplication.shared.beginReceivingRemoteControlEvents()
            
            let commandCenter = MPRemoteCommandCenter.shared()
            var nowPlayingInfo = [String : Any]()

            commandCenter.playCommand.isEnabled = true
            
            // Add handler for Play Command
            appDelegate.commandCenterPlayCommand = commandCenter.playCommand.addTarget { event in
                
                if !ncplayer.isPlay() {
                    ncplayer.playerPlay()
                    self.updateToolBar(timeSeek: nil)
                    return .success
                }
                return .commandFailed
            }
          
            // Add handler for Pause Command
            appDelegate.commandCenterPauseCommand = commandCenter.pauseCommand.addTarget { event in
              
                if ncplayer.isPlay() {
                    ncplayer.playerPause()
                    self.updateToolBar(timeSeek: nil)
                    return .success
                }
                return .commandFailed
            }
            
            // Add handler for Backward Command
            appDelegate.commandCenterSkipBackwardCommand = commandCenter.skipBackwardCommand.addTarget { event in
                
                let seconds = Float64((event as! MPSkipIntervalCommandEvent).interval)
                self.skip(seconds: -seconds)
                return.success
            }
                
            // Add handler for Forward Command
            appDelegate.commandCenterskipForwardCommand = commandCenter.skipForwardCommand.addTarget { event in
                
                let seconds = Float64((event as! MPSkipIntervalCommandEvent).interval)
                self.skip(seconds: seconds)
                return.success
            }
            
            nowPlayingInfo[MPMediaItemPropertyTitle] = metadata.fileNameView
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = appDelegate.player?.currentItem?.asset.duration.seconds
            if let image = self.image {
                nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { size in
                    return image
                }
            }
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
        
        updateToolBar(timeSeek: timeSeek)
        
        self.timeObserver = appDelegate.player?.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(1, preferredTimescale: 1), queue: .main, using: { (CMTime) in
            
            if self.appDelegate.player?.currentItem?.status == .readyToPlay {
                if self.isHidden == false {
                    self.updateToolBar()
                }
            }
        })
    }
    
    public func updateToolBar(timeSeek: CMTime? = nil) {
        guard let metadata = self.metadata else { return }
        
        var namedPlay = "play.fill"
        var currentTime = appDelegate.player?.currentTime() ?? .zero
        currentTime = currentTime.convertScale(1000, method: .default)
        
        if CCUtility.getAudioMute() {
            muteButton.setImage(NCUtility.shared.loadImage(named: "audioOff", color: .white), for: .normal)
        } else {
            muteButton.setImage(NCUtility.shared.loadImage(named: "audioOn", color: .white), for: .normal)
        }
        muteButton.isEnabled = true
        
        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
            pipButton.setImage(NCUtility.shared.loadImage(named: "pip.enter", color: .white), for: .normal)
            pipButton.isEnabled = true
            if let ncplayer = self.ncplayer, let playerLayer = ncplayer.videoLayer, ncplayer.pictureInPictureController == nil {
                ncplayer.pictureInPictureController = AVPictureInPictureController(playerLayer: playerLayer)
                ncplayer.pictureInPictureController?.delegate = ncplayer
            }
        } else {
            pipButton.setImage(NCUtility.shared.loadImage(named: "pip.enter", color: .gray), for: .normal)
            pipButton.isEnabled = false
            if let ncplayer = self.ncplayer, ncplayer.pictureInPictureController != nil {
                ncplayer.pictureInPictureController = nil
                ncplayer.pictureInPictureController?.delegate = nil
            }
        }
        
        if timeSeek != nil {
            playbackSlider.value = Float(timeSeek!.value)
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = timeSeek!.seconds
        } else {
            playbackSlider.value = Float(currentTime.value)
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime.seconds
        }
        playbackSlider.isEnabled = true
        
        if #available(iOS 13.0, *) {
            backButton.setImage(NCUtility.shared.loadImage(named: "gobackward.10", color: .white), for: .normal)
        } else {
            backButton.setImage(NCUtility.shared.loadImage(named: "gobackward.10", color: .white, size: 30), for: .normal)
        }
        backButton.isEnabled = true
        
        if let ncplayer = ncplayer, ncplayer.isPlay() {
            namedPlay = "pause.fill"
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 1
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 0
        }
        
        if #available(iOS 13.0, *) {
            playButton.setImage(NCUtility.shared.loadImage(named: namedPlay, color: .white, symbolConfiguration: UIImage.SymbolConfiguration(pointSize: 30)), for: .normal)
        } else {
            playButton.setImage(NCUtility.shared.loadImage(named: namedPlay, color: .white, size: 30), for: .normal)
        }
        playButton.isEnabled = true
        
        if #available(iOS 13.0, *) {
            forwardButton.setImage(NCUtility.shared.loadImage(named: "goforward.10", color: .white), for: .normal)
        } else {
            forwardButton.setImage(NCUtility.shared.loadImage(named: "goforward.10", color: .white, size: 30), for: .normal)
        }
        forwardButton.isEnabled = true
        
        labelCurrentTime.text = NCUtility.shared.stringFromTime(currentTime)
        labelOverallDuration.text = "-" + NCUtility.shared.stringFromTime(self.durationTime - currentTime)
    }
    
    // MARK: Handle Notifications
    
    @objc func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo, let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt, let reason = AVAudioSession.RouteChangeReason(rawValue:reasonValue) else { return }
        
        switch reason {
        case .newDeviceAvailable:
            let session = AVAudioSession.sharedInstance()
            for output in session.currentRoute.outputs where output.portType == AVAudioSession.Port.headphones {
                print("headphones connected")
                DispatchQueue.main.sync {
                    ncplayer?.playerPlay()
                    startTimerAutoHide()
                }
                break
            }
        case .oldDeviceUnavailable:
            if let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                for output in previousRoute.outputs where output.portType == AVAudioSession.Port.headphones {
                    print("headphones disconnected")
                    DispatchQueue.main.sync {
                        ncplayer?.playerPause()
                        ncplayer?.saveCurrentTime()
                    }
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
            // Interruption began, take appropriate actions
        } else if type == .ended {
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Interruption Ended - playback should resume
                    print("Interruption Ended - playback should resume")
                    ncplayer?.playerPlay()
                    startTimerAutoHide()
                } else {
                    // Interruption Ended - playback should NOT resume
                    print("Interruption Ended - playback should NOT resume")
                }
            }
        }
    }
    
    // MARK: -

    public func hide() {
              
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
            self.playerTopToolBarView.alpha = 0
        }, completion: { (value: Bool) in
            self.isHidden = true
            self.playerTopToolBarView.isHidden = true
        })
    }
    
    @objc private func automaticHide() {
        
        if let metadata = self.metadata {
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterHidePlayerToolBar, userInfo: ["ocId":metadata.ocId])
        }
    }
    
    private func startTimerAutoHide() {
        
        timerAutoHide?.invalidate()
        timerAutoHide = Timer.scheduledTimer(timeInterval: 3.5, target: self, selector: #selector(automaticHide), userInfo: nil, repeats: false)
    }
    
    private func reStartTimerAutoHide() {
        
        if let timerAutoHide = timerAutoHide, timerAutoHide.isValid {
            startTimerAutoHide()
        }
    }
    
    public func show(enableTimerAutoHide: Bool) {
        guard let metadata = self.metadata else { return }
        
        if metadata.classFile != NCCommunicationCommon.typeClassFile.video.rawValue && metadata.classFile != NCCommunicationCommon.typeClassFile.audio.rawValue { return }
        if metadata.livePhoto { return }
        
        timerAutoHide?.invalidate()
        if enableTimerAutoHide {
            startTimerAutoHide()
        }
        
        if !self.isHidden { return }

        updateToolBar()
            
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 1
            self.playerTopToolBarView.alpha = 1
        }, completion: { (value: Bool) in
            self.isHidden = false
            self.playerTopToolBarView.isHidden = false
        })        
    }
    
    func isShow() -> Bool {
        return !self.isHidden
    }
    
    
    
    func skip(seconds: Float64) {
        guard let ncplayer = ncplayer else { return }
        guard let player = appDelegate.player else { return }
        
        let currentTime = player.currentTime()
        var newTime: CMTime = .zero
        let timeToAdd: CMTime = CMTimeMakeWithSeconds(abs(seconds), preferredTimescale: 1)

        if seconds > 0 {
            newTime = CMTimeAdd(currentTime, timeToAdd)
            
            if newTime < durationTime {
                ncplayer.videoSeek(time: newTime)
            } else if newTime >= durationTime {
                let timeToSubtract: CMTime = CMTimeMakeWithSeconds(3, preferredTimescale: 1)
                newTime = CMTimeSubtract(durationTime, timeToSubtract)
                if newTime > currentTime {
                    ncplayer.videoSeek(time: newTime)
                }
            }
        } else {
            newTime = CMTimeSubtract(currentTime, timeToAdd)
            ncplayer.videoSeek(time: newTime)
        }
        
        reStartTimerAutoHide()
    }
    
    //MARK: - Event / Gesture
    
    @objc func onSliderValChanged(slider: UISlider, event: UIEvent) {
        
        if let touchEvent = event.allTouches?.first, let ncplayer = ncplayer {
            
            let seconds: Int64 = Int64(self.playbackSlider.value)
            let targetTime: CMTime = CMTimeMake(value: seconds, timescale: 1000)
            
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
    
    @objc func didSingleTapWith(gestureRecognizer: UITapGestureRecognizer) {
        
        hide()
    }
    
    //MARK: - Action
    
    @IBAction func buttonTouchInside(_ sender: UIButton) {
    }
    
    @IBAction func playerPause(_ sender: Any) {
        
        if appDelegate.player?.timeControlStatus == .playing {
            ncplayer?.playerPause()
            ncplayer?.saveCurrentTime()
            timerAutoHide?.invalidate()
        } else if appDelegate.player?.timeControlStatus == .paused {
            ncplayer?.playerPlay()
            startTimerAutoHide()
        } else if appDelegate.player?.timeControlStatus == .waitingToPlayAtSpecifiedRate {
            print("timeControlStatus.waitingToPlayAtSpecifiedRate")
            if let reason = appDelegate.player?.reasonForWaitingToPlay {
                switch reason {
                case .evaluatingBufferingRate:
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
        
    @IBAction func setMute(_ sender: Any) {
        
        let mute = CCUtility.getAudioMute()
        
        CCUtility.setAudioMute(!mute)
        appDelegate.player?.isMuted = !mute
        updateToolBar()
        reStartTimerAutoHide()
    }
    
    @IBAction func setPip(_ sender: Any) {
        guard let metadata = self.metadata else { return }

        ncplayer?.pictureInPictureController?.startPictureInPicture()
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterHidePlayerToolBar, userInfo: ["ocId":metadata.ocId])
    }
    
    @IBAction func forwardButtonSec(_ sender: Any) {
        skip(seconds: 10)
    }
    
    @IBAction func backButtonSec(_ sender: Any) {
        skip(seconds: -10)
    }
}

