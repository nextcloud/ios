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
    private var durationSeconds: Double = 0
    private var viewerVideoToolBar: NCViewerVideoToolBar?

    public var metadata: tableMetadata?
    public var videoLayer: AVPlayerLayer?
    public var player: AVPlayer?

    //MARK: - NotificationCenter

    @objc func applicationDidEnterBackground(_ notification: NSNotification) {
        
        if metadata?.classFile == NCCommunicationCommon.typeClassFile.video.rawValue {
            self.player?.pause()
        }
    }
    
    func initVideoPlayer(imageView: UIImageView?, viewerVideoToolBar: NCViewerVideoToolBar?, metadata: tableMetadata) {
                
        guard let imageView = imageView else { return }
        if self.metadata == metadata { return }
        
        func initPlayer(url: URL) {
                        
            self.player = AVPlayer(url: url)
            self.player?.isMuted = CCUtility.getAudioMute()
            self.player?.seek(to: .zero)
            self.videoLayer = AVPlayerLayer(player: self.player)
            self.videoLayer!.frame = imageView.bounds
            self.videoLayer!.videoGravity = .resizeAspect
            
            imageView.layer.addSublayer(videoLayer!)

            // At end go back to start & show toolbar
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.player?.currentItem, queue: .main) { (notification) in
                if let item = notification.object as? AVPlayerItem, let currentItem = self.player?.currentItem, item == currentItem {
                    self.player?.seek(to: .zero)
                    self.viewerVideoToolBar?.showToolBar(metadata: metadata)
                    NCKTVHTTPCache.shared.saveCache(metadata: metadata)
                }
            }
            
            // save durationSeconds on database
            if let duration: CMTime = (player?.currentItem?.asset.duration) {
                durationSeconds = CMTimeGetSeconds(duration)
                NCManageDatabase.shared.addVideoTime(metadata: metadata, time: nil, durationSeconds: durationSeconds)
            }
            
            // NO Live Photo, seek to datamebase time
            if !metadata.livePhoto, let time = NCManageDatabase.shared.getVideoTime(metadata: metadata) {
                self.player?.seek(to: time)
            }
            
            viewerVideoToolBar?.setBarPlayer()
        }
        
        if let url = NCKTVHTTPCache.shared.getVideoURL(metadata: metadata) {
            
            self.imageView = imageView
            self.viewerVideoToolBar = viewerVideoToolBar
            self.metadata = metadata

            initPlayer(url: url)
        }        
    }
    
    func videoPlay() {
                
        self.player?.play()
    }
    
    func videoPause() {
        guard let metadata = self.metadata else { return }
        
        self.player?.pause()
        if let time = self.player?.currentTime() {
            NCManageDatabase.shared.addVideoTime(metadata: metadata, time: time, durationSeconds: nil)
        }
        
        NCKTVHTTPCache.shared.saveCache(metadata: metadata)
    }
    
    func videoSeek(time: CMTime) {
        guard let metadata = self.metadata else { return }
        
        self.player?.seek(to: time)
        NCManageDatabase.shared.addVideoTime(metadata: metadata, time: time, durationSeconds: nil)
    }
    
    func videoRemoved() {

        videoPause()
                            
        self.videoLayer?.removeFromSuperlayer()
    }
    
    func getVideoCurrentSeconds() -> Float64 {
        
        if let currentTime = NCViewerVideo.shared.player?.currentTime() {
            return CMTimeGetSeconds(currentTime)
        }
        return 0
    }
    
    func getVideoDurationSeconds() -> Float64 {
        
        return self.durationSeconds
    }
}

