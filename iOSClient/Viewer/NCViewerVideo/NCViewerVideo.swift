//
//  NCViewerVideo.swift
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

class NCViewerVideo: NSObject {
    @objc static let shared: NCViewerVideo = {
        let instance = NCViewerVideo()
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidEnterBackground), object: nil)
        return instance
    }()
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var imageView: UIImageView?
    private var timeObserver: Any?
    private var rateObserver: Any?
    
    public var metadata: tableMetadata?
    public var videoLayer: AVPlayerLayer?
    public var player: AVPlayer?
    public var viewerVideoToolBar: NCViewerVideoToolBar?
    
    //MARK: - NotificationCenter

    @objc func applicationDidEnterBackground(_ notification: NSNotification) {
        
        if metadata?.classFile == NCCommunicationCommon.typeClassFile.video.rawValue {
            self.player?.pause()
        }
    }
    
    func initVideoPlayer(imageView: UIImageView?, viewerVideoToolBar: NCViewerVideoToolBar?, metadata: tableMetadata) {
        guard let imageView = imageView else { return }
       
        self.imageView = imageView
        self.viewerVideoToolBar = viewerVideoToolBar
        self.metadata = metadata
        
        NCKTVHTTPCache.shared.startProxy(user: appDelegate.user, password: appDelegate.password, metadata: metadata)
        
        func initPlayer(url: URL) {
            
            self.player = AVPlayer(url: url)
            self.player?.isMuted = CCUtility.getAudioMute()
            self.videoLayer = AVPlayerLayer(player: self.player)
            self.videoLayer!.frame = imageView.bounds
            self.videoLayer!.videoGravity = .resizeAspect
            
            imageView.layer.addSublayer(videoLayer!)

            // At end go back to start & show toolbar
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.player?.currentItem, queue: .main) { (notification) in
                if let item = notification.object as? AVPlayerItem, let currentItem = self.player?.currentItem, item == currentItem {
                    self.player?.seek(to: .zero)
                    self.viewerVideoToolBar?.showToolBar()
                }
            }
                        
            self.rateObserver = self.player?.addObserver(self, forKeyPath: "rate", options: [], context: nil)
            
            viewerVideoToolBar?.setBarPlayer(player: self.player, metadata: metadata)
        }
        
        //NCNetworking.shared.getVideoUrl(metadata: metadata) { url in
        //            if let url = url {
        //}

        if let url = NCKTVHTTPCache.shared.getVideoURL(metadata: metadata) {
            initPlayer(url: url)
        }
    }
    
    func videoPlay() {
        self.player?.play()
    }
    
    func videoStop() {
        
        guard let metadata = self.metadata else { return }
        
        self.player?.pause()
        self.player?.seek(to: CMTime.zero)
        
        if let timeObserver = timeObserver {
            self.player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        if rateObserver != nil {
            self.player?.removeObserver(self, forKeyPath: "rate")
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
            NCKTVHTTPCache.shared.stopProxy(metadata: metadata)
            self.rateObserver = nil
        }
               
        self.videoLayer?.removeFromSuperlayer()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard let metadata = self.metadata else { return }
        
        if keyPath != nil && keyPath == "rate" {
            
            self.viewerVideoToolBar?.setToolBarImage()
            
            if self.player?.rate == 1 {
                
                if let time = NCManageDatabase.shared.getVideoTime(metadata: metadata) {
                    self.player?.seek(to: time)
                    self.player?.isMuted = CCUtility.getAudioMute()
                    let timeSecond = Double(CMTimeGetSeconds(time))
                    print("Play video at: \(timeSecond)")
                }
                
            } else if !metadata.livePhoto {
                
                if let time = self.player?.currentTime(), let duration = self.player?.currentItem?.asset.duration {
                    let timeSecond = Double(CMTimeGetSeconds(time))
                    let durationSeconds = Double(CMTimeGetSeconds(duration))
                    if timeSecond < durationSeconds {
                        NCManageDatabase.shared.addVideoTime(metadata: metadata, time: self.player?.currentTime(), durationSeconds: nil)
                        if let time = self.player?.currentTime() {
                            let timeSecond = Double(CMTimeGetSeconds(time))
                            print("Stop video at: \(timeSecond)")
                        }
                    } else {
                        NCManageDatabase.shared.deleteVideoTime(metadata: metadata)
                    }
                }
            }
        }
    }
}

