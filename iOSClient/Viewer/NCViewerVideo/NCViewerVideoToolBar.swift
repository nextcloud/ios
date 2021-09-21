//
//  NCViewerVideoToolBar.swift
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

class NCViewerVideoToolBar: UIView {
    
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var muteButton: UIButton!
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
    
    var player: AVPlayer?
    var metadata: tableMetadata!
    
    private var playbackSliderEvent: sliderEventType = .ended
    private let seekDuration: Float64 = 15

    // MARK: - View Life Cycle

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)

        if newWindow != nil {
            
            let blurEffect = UIBlurEffect(style: .dark)
            let blurEffectView = UIVisualEffectView(effect: blurEffect)
            
            self.layer.cornerRadius = 15
            self.layer.masksToBounds = true
                       
            blurEffectView.frame = self.bounds
            blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.insertSubview(blurEffectView, at:0)
            
            playbackSlider.value = 0
            playbackSlider.minimumValue = 0
            playbackSlider.maximumValue = 0
            playbackSlider.isContinuous = true
            playbackSlider.tintColor = .lightGray
            
            labelCurrentTime.text = stringFromTimeInterval(interval: 0)
            labelCurrentTime.textColor = .lightGray
            labelOverallDuration.text = stringFromTimeInterval(interval: 0)
            labelOverallDuration.textColor = .lightGray
            
            backButton.setImage(NCUtility.shared.loadImage(named: "gobackward.15", color: .white), for: .normal)
            forwardButton.setImage(NCUtility.shared.loadImage(named: "goforward.15", color: .white), for: .normal)

            setToolBar()
        }
    }
    
    func setBarPlayer(player: AVPlayer?, metadata: tableMetadata?) {
        self.player = player
        self.metadata = metadata
        
        let duration: CMTime = (player?.currentItem?.asset.duration)!
        let durationSeconds: Float64 = CMTimeGetSeconds(duration)
        
        playbackSlider.value = 0
        playbackSlider.minimumValue = 0
        playbackSlider.maximumValue = Float(durationSeconds)
        playbackSlider.addTarget(self, action: #selector(onSliderValChanged(slider:event:)), for: .valueChanged)

        labelCurrentTime.text = stringFromTimeInterval(interval: 0)
        labelOverallDuration.text = "-" + stringFromTimeInterval(interval: durationSeconds)
        
        player?.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(1, preferredTimescale: 1), queue: .main, using: { (CMTime) in
            
            if self.player?.currentItem?.status == .readyToPlay {
                if self.isHidden == false {
                    self.updateOutlet()
                }
            }
        })
        
        setToolBar()
        
        // show
        updateOutlet()
        self.isHidden = false
    }
    
    @objc public func hideToolBar() {
        updateOutlet()
        self.isHidden = true
    }
    
    @objc public func showToolBar() {
        self.isHidden = false
    }
    
    public func setToolBar() {

        if player?.rate == 1 {
            playButton.setImage(NCUtility.shared.loadImage(named: "pause.fill", color: .white), for: .normal)
        } else {
            playButton.setImage(NCUtility.shared.loadImage(named: "play.fill", color: .white), for: .normal)
        }
       
        if CCUtility.getAudioMute() {
            muteButton.setImage(NCUtility.shared.loadImage(named: "audioOff", color: .white), for: .normal)
        } else {
            muteButton.setImage(NCUtility.shared.loadImage(named: "audioOn", color: .white), for: .normal)
        }
    }
    
    private func updateOutlet() {
        
        if let duration = player?.currentItem?.asset.duration, let currentTime = player?.currentTime() {
            
            let durationSeconds: Float64 = CMTimeGetSeconds(duration)
            let currentSeconds: Float64 = CMTimeGetSeconds(currentTime)
            
            self.playbackSlider.value = Float(currentSeconds)
            self.labelCurrentTime.text = self.stringFromTimeInterval(interval: currentSeconds)
            self.labelOverallDuration.text = "-" + self.stringFromTimeInterval(interval: durationSeconds - currentSeconds)
        }
    }
    
    //MARK: - Event
    
    @objc func onSliderValChanged(slider: UISlider, event: UIEvent) {
        if let touchEvent = event.allTouches?.first {
            let seconds: Int64 = Int64(self.playbackSlider.value)
            let targetTime: CMTime = CMTimeMake(value: seconds, timescale: 1)
            switch touchEvent.phase {
            case .began:
                self.player?.pause()
                playbackSliderEvent = .began
            case .moved:
                self.player?.seek(to: targetTime)
                playbackSliderEvent = .moved
            case .ended:
                self.player?.seek(to: targetTime)
                NCManageDatabase.shared.addVideoTime(metadata: self.metadata, time: targetTime)
                self.player?.play()
                playbackSliderEvent = .ended
            default:
                break
            }
        }
    }

    //MARK: - Action
    
    @IBAction func playerPause(_ sender: Any) {
        
        if player?.timeControlStatus == .playing {
            player?.pause()
        } else if player?.timeControlStatus == .paused {
            player?.play()
        }
    }
        
    @IBAction func setMute(_ sender: Any) {
        
        let mute = CCUtility.getAudioMute()
        
        CCUtility.setAudioMute(!mute)
        player?.isMuted = !mute
        setToolBar()
    }
    
    @IBAction func forwardButtonSec(_ sender: Any) {
        guard let player = self.player else { return }
        guard let duration = player.currentItem?.duration else { return }
        
        let playerCurrentTime = CMTimeGetSeconds(player.currentTime())
        let newTime = playerCurrentTime + seekDuration
        
        if newTime < CMTimeGetSeconds(duration) {
            let targetTime: CMTime = CMTimeMake(value: Int64(newTime * 1000 as Float64), timescale: 1000)
            
            self.player?.seek(to: targetTime)
            NCManageDatabase.shared.addVideoTime(metadata: self.metadata, time: targetTime)
            self.player?.play()
        }
    }
    
    @IBAction func backButtonSec(_ sender: Any) {
        guard let player = self.player else { return }

        let playerCurrenTime = CMTimeGetSeconds(player.currentTime())
        var newTime = playerCurrenTime - seekDuration
        
        if newTime < 0 { newTime = 0 }
        let targetTime: CMTime = CMTimeMake(value: Int64(newTime * 1000 as Float64), timescale: 1000)
        
        self.player?.seek(to: targetTime)
        NCManageDatabase.shared.addVideoTime(metadata: self.metadata, time: targetTime)
        self.player?.play()
    }
    
    //MARK: - Algorithms
    
    func stringFromTimeInterval(interval: TimeInterval) -> String {
    
        let interval = Int(interval)
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
