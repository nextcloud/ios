//
//  NCPlayer.swift
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
import UIKit

class NCPlayer: AVPlayer {
   
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var imageVideoContainer: imageVideoContainerView?
    private var durationSeconds: Double = 0
    private var playerToolBar: NCPlayerToolBar?

    public var metadata: tableMetadata?
    public var videoLayer: AVPlayerLayer?

    //MARK: - NotificationCenter

    @objc func applicationDidEnterBackground(_ notification: NSNotification) {
        
        if metadata?.classFile == NCCommunicationCommon.typeClassFile.video.rawValue {
            self.pause()
        }
    }
    
    deinit {
        print("deinit NCPlayer")
    }
    
    func setupVideoLayer(imageVideoContainer: imageVideoContainerView?, playerToolBar: NCPlayerToolBar?, metadata: tableMetadata) {
        
        self.playerToolBar = playerToolBar
        self.metadata = metadata
        
        isMuted = CCUtility.getAudioMute()
        seek(to: .zero)

        // At end go back to start & show toolbar
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: currentItem, queue: .main) { (notification) in
            if let item = notification.object as? AVPlayerItem, let currentItem = self.currentItem, item == currentItem {
                self.seek(to: .zero)
                self.playerToolBar?.showToolBar(metadata: metadata)
                NCKTVHTTPCache.shared.saveCache(metadata: metadata)
            }
        }
        
        currentItem?.asset.loadValuesAsynchronously(forKeys: ["duration", "playable"], completionHandler: {
            if let duration: CMTime = (self.currentItem?.asset.duration) {
                var error: NSError? = nil
                let status = self.currentItem?.asset.statusOfValue(forKey: "playable", error: &error)
                switch status {
                case .loaded:
                    DispatchQueue.main.async {
                        if let imageVideoContainer = imageVideoContainer {
                            self.imageVideoContainer = imageVideoContainer
                            self.videoLayer = AVPlayerLayer(player: self)
                            self.videoLayer!.frame = imageVideoContainer.bounds
                            self.videoLayer!.videoGravity = .resizeAspect
                            imageVideoContainer.layer.addSublayer(self.videoLayer!)
                            imageVideoContainer.playerLayer = self.videoLayer
                        }
                        self.durationSeconds = CMTimeGetSeconds(duration)
                        NCManageDatabase.shared.addVideoTime(metadata: metadata, time: nil, durationSeconds: self.durationSeconds)
                        // NO Live Photo, seek to datamebase time
                        if !metadata.livePhoto, let time = NCManageDatabase.shared.getVideoTime(metadata: metadata) {
                            self.seek(to: time)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            playerToolBar?.setBarPlayer(player: self)
                        }
                    }
                    break
                case .failed:
                    DispatchQueue.main.async {
                        //do something, show alert, put a placeholder image etc.
                    }
                    break
                case .cancelled:
                    DispatchQueue.main.async {
                        //do something, show alert, put a placeholder image etc.
                    }
                    break
                default:
                    break
                }
            }
        })
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidEnterBackground), object: nil)
    }
    
    
    func videoPlay() {
                
        play()
    }
    
    func videoPause() {
        guard let metadata = self.metadata else { return }
        
        pause()
        NCManageDatabase.shared.addVideoTime(metadata: metadata, time: currentTime(), durationSeconds: nil)
        
        NCKTVHTTPCache.shared.saveCache(metadata: metadata)
    }
    
    func videoSeek(time: CMTime) {
        guard let metadata = self.metadata else { return }
        
        seek(to: time)
        NCManageDatabase.shared.addVideoTime(metadata: metadata, time: time, durationSeconds: nil)
    }
    
    func videoRemoved() {

        videoPause()
                            
        self.videoLayer?.removeFromSuperlayer()
    }
    
    func getVideoCurrentSeconds() -> Float64 {
        
        return CMTimeGetSeconds(currentTime())
    }
    
    func getVideoDurationSeconds() -> Float64 {
        
        return self.durationSeconds
    }
}

