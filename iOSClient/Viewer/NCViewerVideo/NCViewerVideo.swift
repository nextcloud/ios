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
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var videoLayer: AVPlayerLayer?
    private var view: UIView?
    private var timeObserver: Any?
    private var rateObserver: Any?
    private var metadata: tableMetadata?
    
    public var viewerVideoToolBar: NCViewerVideoToolBar?
    public var player: AVPlayer?
    public var pictureInPictureOcId: String = ""
    
    init(view: UIView?, viewerVideoToolBar: NCViewerVideoToolBar?) {
        super.init()

        self.view = view
        self.viewerVideoToolBar = viewerVideoToolBar
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidEnterBackground), object: nil)
    }
    
    deinit {
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidEnterBackground), object: nil)
    }
    
    //MARK: - NotificationCenter

    @objc func applicationDidEnterBackground(_ notification: NSNotification) {
        
        if metadata?.classFile == NCCommunicationCommon.typeClassFile.video.rawValue {
            player?.pause()
        }
    }
    
    func videoPlay(metadata: tableMetadata) {
        self.metadata = metadata
        
        NCKTVHTTPCache.shared.startProxy(user: appDelegate.user, password: appDelegate.password, metadata: metadata)
        
        func play(url: URL) {
            
            self.player = AVPlayer(url: url)
            self.player?.isMuted = CCUtility.getAudioMute()
            self.videoLayer = AVPlayerLayer(player: self.player)

            if let view = view  {

                self.videoLayer!.frame = view.bounds
                self.videoLayer!.videoGravity = .resizeAspect
                view.layer.addSublayer(self.videoLayer!)
                
                // At end go back to start & show toolbar
                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.player?.currentItem, queue: .main) { (notification) in
                    if let item = notification.object as? AVPlayerItem, let currentItem = self.player?.currentItem, item == currentItem {
                        self.player?.seek(to: .zero)
                        if metadata.livePhoto {
                            NCManageDatabase.shared.deleteVideoTime(metadata: metadata)
                        }
                        self.viewerVideoToolBar?.showToolBar()
                    }
                }
                            
                self.rateObserver = self.player?.addObserver(self, forKeyPath: "rate", options: [], context: nil)
                
                if self.pictureInPictureOcId != metadata.ocId {
                    self.player?.play()
                }
            }
            
            viewerVideoToolBar?.setBarPlayer(player: player)
        }
        
        //NCNetworking.shared.getVideoUrl(metadata: metadata) { url in
        //            if let url = url {
        //}

        if let url = NCKTVHTTPCache.shared.getVideoURL(metadata: metadata) {
            play(url: url)
        }
    }
    
    func videoStop() {
        
        guard let metadata = self.metadata else { return }
        
        player?.pause()
        player?.seek(to: CMTime.zero)
        
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        if rateObserver != nil {
            player?.removeObserver(self, forKeyPath: "rate")
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
            NCKTVHTTPCache.shared.stopProxy(metadata: metadata)
            self.rateObserver = nil
        }
               
        videoLayer?.removeFromSuperlayer()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard let metadata = self.metadata else { return }
        
        if keyPath != nil && keyPath == "rate" {
            
            self.viewerVideoToolBar?.setToolBar()
            
            if ((player?.rate) == 1) {
                
                if let time = NCManageDatabase.shared.getVideoTime(metadata: metadata) {
                    player?.seek(to: time)
                    player?.isMuted = CCUtility.getAudioMute()
                }
                
            } else if !metadata.livePhoto {
                
                if let time = player?.currentTime(), let duration = self.player?.currentItem?.asset.duration {
                    let timeSecond = Double(CMTimeGetSeconds(time))
                    let durationSeconds = Double(CMTimeGetSeconds(duration))
                    if timeSecond < durationSeconds {
                        NCManageDatabase.shared.addVideoTime(metadata: metadata, time: player?.currentTime())
                    }
                }
            }
        }
    }
}

