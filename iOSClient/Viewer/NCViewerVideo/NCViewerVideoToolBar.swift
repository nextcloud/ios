//
//  NCViewerVideoToolBar.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 01/07/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import Foundation

class NCViewerVideoToolBar: UIView {
    
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var muteButton: UIButton!
    
    var player: AVPlayer?

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
