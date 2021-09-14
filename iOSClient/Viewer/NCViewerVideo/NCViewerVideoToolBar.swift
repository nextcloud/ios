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

class NCViewerVideoToolBar: UIView {
    
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var muteButton: UIButton!
    @IBOutlet weak var playbackSlider: UISlider!
    @IBOutlet weak var labelOverallDuration: UILabel!
    @IBOutlet weak var labelCurrentTime: UILabel!
    
    var player: AVPlayer?
    
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
        }
    }
    
    func setPlayer(player: AVPlayer?) {
        self.player = player
        
        let duration: CMTime = (player?.currentItem?.asset.duration)!
        let durationSeconds: Float64 = CMTimeGetSeconds(duration)
        
        playbackSlider.minimumValue = 0
        playbackSlider.maximumValue = Float(durationSeconds)
        playbackSlider.isContinuous = true
        playbackSlider.action(for: .valueChanged) { _ in
            let seconds : Int64 = Int64(self.playbackSlider.value)
            let targetTime:CMTime = CMTimeMake(value: seconds, timescale: 1)
            self.player?.seek(to: targetTime)
            if self.player?.rate == 0 {
                self.player?.play()
            }
        }
        
        labelCurrentTime.text = stringFromTimeInterval(interval: 0)
        labelCurrentTime.textColor = .lightGray
        labelOverallDuration.text = "-" + stringFromTimeInterval(interval: durationSeconds)
        labelOverallDuration.textColor = .lightGray
        
        player?.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(1, preferredTimescale: 1), queue: .main, using: { (CMTime) in
            
            if self.player?.currentItem?.status == .readyToPlay {
                let currentSeconds: Float64 = CMTimeGetSeconds(self.player!.currentTime())
                self.playbackSlider.value = Float(currentSeconds)
                self.labelCurrentTime.text = self.stringFromTimeInterval(interval: currentSeconds)
                self.labelOverallDuration.text = "-" + self.stringFromTimeInterval(interval: durationSeconds - currentSeconds)
            }
        })
    }
    
    func setToolBar() {
        
        let mute = CCUtility.getAudioMute()
        
        if  player?.rate == 1 {
            playButton.setImage(NCUtility.shared.loadImage(named: "pause.fill", color: .white), for: .normal)
        } else {
            playButton.setImage(NCUtility.shared.loadImage(named: "play.fill", color: .white), for: .normal)
        }
       
        if mute {
            muteButton.setImage(NCUtility.shared.loadImage(named: "audioOff", color: .white), for: .normal)
        } else {
            muteButton.setImage(NCUtility.shared.loadImage(named: "audioOn", color: .white), for: .normal)
        }
    }

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
    
    @objc func playbackSliderValueChanged(_ playbackSlider:UISlider) {
           
        let seconds : Int64 = Int64(playbackSlider.value)
        let targetTime:CMTime = CMTimeMake(value: seconds, timescale: 1)
           
        player?.seek(to: targetTime)
           
        if player?.rate == 0 {
            player?.play()
        }
    }
    
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
