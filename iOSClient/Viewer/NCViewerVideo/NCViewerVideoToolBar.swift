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
    }
    
    func setToolBar() {
        
        let mute = CCUtility.getAudioMute()
        
        if  player?.rate == 1 {
            playButton.setImage(NCUtility.shared.loadImage(named: "pause.fill"), for: .normal)
        } else {
            playButton.setImage(NCUtility.shared.loadImage(named: "play.fill"), for: .normal)
        }
       
        if mute {
            muteButton.setImage(NCUtility.shared.loadImage(named: "audioOff"), for: .normal)
        } else {
            muteButton.setImage(NCUtility.shared.loadImage(named: "audioOn"), for: .normal)
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
    
}
