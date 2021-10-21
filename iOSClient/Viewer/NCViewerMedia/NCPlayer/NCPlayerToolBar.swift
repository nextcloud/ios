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
    @IBOutlet weak var labelLeftTime: UILabel!
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
    private var timerAutoHide: Timer?
    private var metadata: tableMetadata?
    private var image: UIImage?
    
    weak var viewerMedia: NCViewerMedia?

    // MARK: - View Life Cycle

    override func awakeFromNib() {
        super.awakeFromNib()
        
        // for disable gesture of UIPageViewController
        let panRecognizer = UIPanGestureRecognizer(target: self, action: nil)
        addGestureRecognizer(panRecognizer)
        let singleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didSingleTapWith(gestureRecognizer:)))
        addGestureRecognizer(singleTapGestureRecognizer)
        
        self.layer.cornerRadius = 15
        self.layer.masksToBounds = true
        
        let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blurEffectView.frame = self.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.insertSubview(blurEffectView, at:0)
        
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
        labelLeftTime.text = NCUtility.shared.stringFromTime(.zero)
        labelLeftTime.textColor = .lightGray
        
        backButton.isEnabled = false
        playButton.setImage(NCUtility.shared.loadImage(named: "play.fill", color: .lightGray), for: .normal)
        playButton.isEnabled = false
        forwardButton.isEnabled = false
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
    }
    
    deinit {
        print("deinit NCPlayerToolBar")
                
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
    }
    
    // MARK: -

    func setBarPlayer(ncplayer: NCPlayer, metadata: tableMetadata, image: UIImage?) {
                        
        self.ncplayer = ncplayer
        self.metadata = metadata
        self.image = image
                        
        playbackSlider.value = 0
        playbackSlider.minimumValue = 0
        playbackSlider.maximumValue = Float(ncplayer.durationTime.seconds)
        playbackSlider.addTarget(self, action: #selector(onSliderValChanged(slider:event:)), for: .valueChanged)

        labelCurrentTime.text = NCUtility.shared.stringFromTime(.zero)
        labelLeftTime.text = "-" + NCUtility.shared.stringFromTime(ncplayer.durationTime)
        
        updateToolBar(commandCenter: true)
    }
    
    public func updateToolBar(timeSeek: CMTime? = nil, commandCenter: Bool = false) {
        guard let metadata = self.metadata else { return }
        guard let ncplayer = self.ncplayer else { return }
        var time: CMTime = .zero
        
        let imageNameBackward = "gobackward.10"
        let imageNameForward = "goforward.10"
        
        /*
        if metadata.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue {
            imageNameBackward = "backward"
            imageNameForward = "forward"
        }
        */
        
        // COMMAND CENTER
        if commandCenter && CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
            enableCommandCenter()
        }
        
        // MUTE
        if CCUtility.getAudioMute() {
            muteButton.setImage(NCUtility.shared.loadImage(named: "audioOff", color: .white), for: .normal)
        } else {
            muteButton.setImage(NCUtility.shared.loadImage(named: "audioOn", color: .white), for: .normal)
        }
        muteButton.isEnabled = true
        
        // PIP
        if metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue && CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
            pipButton.setImage(NCUtility.shared.loadImage(named: "pip.enter", color: .white), for: .normal)
            pipButton.isEnabled = true
            if let playerLayer = ncplayer.videoLayer, ncplayer.pictureInPictureController == nil {
                ncplayer.pictureInPictureController = AVPictureInPictureController(playerLayer: playerLayer)
                ncplayer.pictureInPictureController?.delegate = ncplayer
            }
        } else {
            pipButton.setImage(NCUtility.shared.loadImage(named: "pip.enter", color: .gray), for: .normal)
            pipButton.isEnabled = false
            if ncplayer.pictureInPictureController != nil {
                ncplayer.pictureInPictureController = nil
                ncplayer.pictureInPictureController?.delegate = nil
            }
        }
        
        // SLIDER TIME (START - END)
        if timeSeek != nil {
            time = timeSeek!
        } else {
            time = (ncplayer.player?.currentTime() ?? .zero).convertScale(1000, method: .default)
            
        }
        playbackSlider.value = Float(time.seconds)
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time.seconds
        playbackSlider.isEnabled = true
        labelCurrentTime.text = NCUtility.shared.stringFromTime(time)
        labelLeftTime.text = "-" + NCUtility.shared.stringFromTime(ncplayer.durationTime - time)
        
        // BACK
        if #available(iOS 13.0, *) {
            backButton.setImage(NCUtility.shared.loadImage(named: imageNameBackward, color: .white), for: .normal)
        } else {
            backButton.setImage(NCUtility.shared.loadImage(named: imageNameBackward, color: .white, size: 30), for: .normal)
        }
        backButton.isEnabled = true
                 
        // PLAY
        if ncplayer.isPlay() {
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 1
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 0
        }
        let namedPlay = ncplayer.isPlay() ? "pause.fill" : "play.fill"
        if #available(iOS 13.0, *) {
            playButton.setImage(NCUtility.shared.loadImage(named: namedPlay, color: .white, symbolConfiguration: UIImage.SymbolConfiguration(pointSize: 30)), for: .normal)
        } else {
            playButton.setImage(NCUtility.shared.loadImage(named: namedPlay, color: .white, size: 30), for: .normal)
        }
        playButton.isEnabled = true
        
        // FORWARD
        if #available(iOS 13.0, *) {
            forwardButton.setImage(NCUtility.shared.loadImage(named: imageNameForward, color: .white), for: .normal)
        } else {
            forwardButton.setImage(NCUtility.shared.loadImage(named: imageNameForward, color: .white, size: 30), for: .normal)
        }
        forwardButton.isEnabled = true
    }
    
    // MARK: - Command Center
    
    func enableCommandCenter() {
        guard let ncplayer = self.ncplayer else { return }
        
        UIApplication.shared.beginReceivingRemoteControlEvents()
        var nowPlayingInfo = [String : Any]()

        // Add handler for Play Command
        MPRemoteCommandCenter.shared().playCommand.isEnabled = true
        appDelegate.playCommand = MPRemoteCommandCenter.shared().playCommand.addTarget { event in
            
            if !ncplayer.isPlay() {
                ncplayer.playerPlay()
                return .success
            }
            return .commandFailed
        }
      
        // Add handler for Pause Command
        MPRemoteCommandCenter.shared().pauseCommand.isEnabled = true
        appDelegate.pauseCommand = MPRemoteCommandCenter.shared().pauseCommand.addTarget { event in
          
            if ncplayer.isPlay() {
                ncplayer.playerPause()
                return .success
            }
            return .commandFailed
        }
        
        // VIDEO / AUDIO () ()
        if metadata?.classFile == NCCommunicationCommon.typeClassFile.video.rawValue || metadata?.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue {
            
            MPRemoteCommandCenter.shared().skipForwardCommand.isEnabled = true
            appDelegate.skipForwardCommand = MPRemoteCommandCenter.shared().skipForwardCommand.addTarget { event in
                
                let seconds = Float64((event as! MPSkipIntervalCommandEvent).interval)
                self.skip(seconds: seconds)
                return.success
            }
            
            MPRemoteCommandCenter.shared().skipBackwardCommand.isEnabled = true
            appDelegate.skipBackwardCommand = MPRemoteCommandCenter.shared().skipBackwardCommand.addTarget { event in
                
                let seconds = Float64((event as! MPSkipIntervalCommandEvent).interval)
                self.skip(seconds: -seconds)
                return.success
            }
        }
                
        // AUDIO < >
        /*
        if metadata?.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue {
                        
            MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = true
            appDelegate.nextTrackCommand = MPRemoteCommandCenter.shared().nextTrackCommand.addTarget { event in
                
                self.forward()
                return .success
            }
            
            MPRemoteCommandCenter.shared().previousTrackCommand.isEnabled = true
            appDelegate.previousTrackCommand = MPRemoteCommandCenter.shared().previousTrackCommand.addTarget { event in
             
                self.backward()
                return .success
            }
        }
        */
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = metadata?.fileNameView
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = ncplayer.player?.currentItem?.asset.duration.seconds
        if let image = self.image {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { size in
                return image
            }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    func disableCommandCenter() {
        
        UIApplication.shared.endReceivingRemoteControlEvents()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [:]

        MPRemoteCommandCenter.shared().playCommand.isEnabled = false
        MPRemoteCommandCenter.shared().pauseCommand.isEnabled = false
        MPRemoteCommandCenter.shared().skipForwardCommand.isEnabled = false
        MPRemoteCommandCenter.shared().skipBackwardCommand.isEnabled = false
        MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = false
        MPRemoteCommandCenter.shared().previousTrackCommand.isEnabled = false

        if let playCommand = appDelegate.playCommand {
            MPRemoteCommandCenter.shared().playCommand.removeTarget(playCommand)
            appDelegate.playCommand = nil
        }
        if let pauseCommand = appDelegate.pauseCommand {
            MPRemoteCommandCenter.shared().pauseCommand.removeTarget(pauseCommand)
            appDelegate.pauseCommand = nil
        }
        if let skipForwardCommand = appDelegate.skipForwardCommand {
            MPRemoteCommandCenter.shared().skipForwardCommand.removeTarget(skipForwardCommand)
            appDelegate.skipForwardCommand = nil
        }
        if let skipBackwardCommand = appDelegate.skipBackwardCommand {
            MPRemoteCommandCenter.shared().skipBackwardCommand.removeTarget(skipBackwardCommand)
            appDelegate.skipBackwardCommand = nil
        }
        if let nextTrackCommand = appDelegate.nextTrackCommand {
            MPRemoteCommandCenter.shared().nextTrackCommand.removeTarget(nextTrackCommand)
            appDelegate.nextTrackCommand = nil
        }
        if let previousTrackCommand = appDelegate.previousTrackCommand {
            MPRemoteCommandCenter.shared().previousTrackCommand.removeTarget(previousTrackCommand)
            appDelegate.previousTrackCommand = nil
        }
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
        guard let metadata = self.metadata else { return }
        
        if metadata.classFile != NCCommunicationCommon.typeClassFile.video.rawValue && metadata.classFile != NCCommunicationCommon.typeClassFile.audio.rawValue { return }
        if metadata.livePhoto { return }
        
        timerAutoHide?.invalidate()
        if enableTimerAutoHide {
            startTimerAutoHide()
        }
        
        if !self.isHidden { return }
            
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 1
            self.playerTopToolBarView.alpha = 1
        }, completion: { (value: Bool) in
            self.isHidden = false
            self.playerTopToolBarView.isHidden = false
        })
        
        updateToolBar()
    }
    
    func isShow() -> Bool {
        
        return !self.isHidden
    }
    
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
    
    func skip(seconds: Float64) {
        guard let ncplayer = ncplayer else { return }
        guard let player = ncplayer.player else { return }
        
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
            ncplayer.videoSeek(time: newTime)
        }
        
        reStartTimerAutoHide()
    }
    
    func forward() {
        
        var index: Int = 0
        
        if let currentIndex = self.viewerMedia?.currentIndex, let metadatas = self.viewerMedia?.metadatas, let ncplayer = self.ncplayer {
        
            if currentIndex == metadatas.count - 1 {
                index = 0
            } else {
                index = currentIndex + 1
            }
            
            self.viewerMedia?.goTo(index: index, direction: .forward, autoPlay: ncplayer.isPlay())
        }
    }
    
    func backward() {
        
        var index: Int = 0

        if let currentIndex = self.viewerMedia?.currentIndex, let metadatas = self.viewerMedia?.metadatas, let ncplayer = self.ncplayer {
            
            if currentIndex == 0 {
                index = metadatas.count - 1
            } else {
                index = currentIndex - 1
            }
            
            self.viewerMedia?.goTo(index: index, direction: .reverse, autoPlay: ncplayer.isPlay())
        }
    }
    
    //MARK: - Event / Gesture
    
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
    
    //MARK: - Action
    
    @objc func didSingleTapWith(gestureRecognizer: UITapGestureRecognizer) {
    }
    
    @IBAction func buttonPlayerToolBarTouchInside(_ sender: UIButton) {
    }
    
    @IBAction func buttonPlayerTopToolBarTouchInside(_ sender: UIButton) {
    }
    
    @IBAction func playerPause(_ sender: Any) {
        
        if ncplayer?.player?.timeControlStatus == .playing {
            ncplayer?.playerPause()
            ncplayer?.saveCurrentTime()
            timerAutoHide?.invalidate()
        } else if ncplayer?.player?.timeControlStatus == .paused {
            ncplayer?.playerPlay()
            startTimerAutoHide()
        } else if ncplayer?.player?.timeControlStatus == .waitingToPlayAtSpecifiedRate {
            print("timeControlStatus.waitingToPlayAtSpecifiedRate")
            if let reason = ncplayer?.player?.reasonForWaitingToPlay {
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
        ncplayer?.player?.isMuted = !mute
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
        
        /*
        if metadata?.classFile == NCCommunicationCommon.typeClassFile.video.rawValue {
            skip(seconds: 10)
        } else if metadata?.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue {
            forward()
        }
        */
    }
    
    @IBAction func backButtonSec(_ sender: Any) {
        
        skip(seconds: -10)
        
        /*
        if metadata?.classFile == NCCommunicationCommon.typeClassFile.video.rawValue {
            skip(seconds: -10)
        } else if metadata?.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue {
            backward()
        }
        */
    }
}

