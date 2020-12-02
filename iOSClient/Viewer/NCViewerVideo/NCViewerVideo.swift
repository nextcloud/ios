//
//  NCViewerVideo.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 27/10/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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

protocol NCViewerVideoDelegate {
    func startPictureInPicture(metadata: tableMetadata)
    func stopPictureInPicture(metadata: tableMetadata, playing: Bool)
}

@objc class NCViewerVideo: AVPlayerViewController {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var metadata = tableMetadata()
    var pictureInPicture: Bool = false
    var delegateViewerVideo: NCViewerVideoDelegate?
    private var rateObserverToken: Any?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        NCKTVHTTPCache.shared.startProxy(user: appDelegate.user, password: appDelegate.password, metadata: metadata)
        
        if let url = NCKTVHTTPCache.shared.getVideoURL(metadata: metadata) {
            
            player = AVPlayer(url: url)
        
            // At end go back to start
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: .main) { (notification) in
                if let item = notification.object as? AVPlayerItem, let currentItem = self.player?.currentItem, item == currentItem {
                    self.player?.seek(to: CMTime.zero)
                }
            }
        
            rateObserverToken = player?.addObserver(self, forKeyPath: "rate", options: [], context: nil)
            
            player?.play()
            if let time = NCManageDatabase.shared.getVideoTime(account: self.metadata.account, ocId: self.metadata.ocId) {
                player?.seek(to: time)
            }
            player?.isMuted = CCUtility.getAudioMute()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NCManageDatabase.shared.addVideoTime(account: metadata.account, ocId: metadata.ocId, time: player?.currentTime())
        
        if let player = self.player {
            CCUtility.setAudioMute(player.isMuted)
        }
        
        if !pictureInPicture {
            player?.pause()
            
            if rateObserverToken != nil {
                player?.removeObserver(self, forKeyPath: "rate")
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
                NCKTVHTTPCache.shared.stopProxy()
                self.rateObserverToken = nil
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath != nil && keyPath == "rate" {
            NCKTVHTTPCache.shared.saveCache(metadata: metadata)
        }
    }
}

extension NCViewerVideo: AVPlayerViewControllerDelegate {
    
    func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(_ playerViewController: AVPlayerViewController) -> Bool {
        true
    }
    
    func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        pictureInPicture = true
        delegateViewerVideo?.startPictureInPicture(metadata: metadata)
    }
    
    func playerViewControllerWillStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        NCManageDatabase.shared.addVideoTime(account: metadata.account, ocId: metadata.ocId, time: player?.currentTime())
        pictureInPicture = false
        let playing = player?.timeControlStatus == .playing
        delegateViewerVideo?.stopPictureInPicture(metadata: metadata, playing: playing)
    }
}
