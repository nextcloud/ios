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
import AVFoundation

class NCPlayer: NSObject {
   
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var imageVideoContainer: imageVideoContainerView?
    private var durationSeconds: Double = 0
    private var playerToolBar: NCPlayerToolBar?

    public var metadata: tableMetadata?
    public var player: AVPlayer?
    public var videoLayer: AVPlayerLayer?

    init(url: URL, imageVideoContainer: imageVideoContainerView?, playerToolBar: NCPlayerToolBar?, metadata: tableMetadata) {
        super.init()

        print("Play URL: \(url)")
        self.player = AVPlayer(url: url)
        self.playerToolBar = playerToolBar
        self.metadata = metadata
        
        self.player?.isMuted = CCUtility.getAudioMute()
        self.player?.seek(to: .zero)

        // At end go back to start & show toolbar
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.player?.currentItem, queue: .main) { (notification) in
            if let item = notification.object as? AVPlayerItem, let currentItem = self.player?.currentItem, item == currentItem {
                self.player?.seek(to: .zero)
                self.playerToolBar?.showToolBar(metadata: metadata, detailView: nil)
                NCKTVHTTPCache.shared.saveCache(metadata: metadata)
            }
        }
        
        self.player?.currentItem?.asset.loadValuesAsynchronously(forKeys: ["duration", "playable"], completionHandler: {
            if let duration: CMTime = (self.player?.currentItem?.asset.duration) {
                var error: NSError? = nil
                let status = self.player?.currentItem?.asset.statusOfValue(forKey: "playable", error: &error)
                switch status {
                case .loaded:
                    DispatchQueue.main.async {
                        if let imageVideoContainer = imageVideoContainer {
                            self.imageVideoContainer = imageVideoContainer
                            self.videoLayer = AVPlayerLayer(player: self.player)
                            self.videoLayer!.frame = imageVideoContainer.bounds
                            self.videoLayer!.videoGravity = .resizeAspect
                            imageVideoContainer.layer.addSublayer(self.videoLayer!)
                            imageVideoContainer.playerLayer = self.videoLayer
                            imageVideoContainer.metadata = self.metadata
                        }
                        self.durationSeconds = CMTimeGetSeconds(duration)
                        NCManageDatabase.shared.addVideoTime(metadata: metadata, time: nil, durationSeconds: self.durationSeconds)
                        // NO Live Photo, seek to datamebase time
                        if !metadata.livePhoto, let time = NCManageDatabase.shared.getVideoTime(metadata: metadata) {
                            self.player?.seek(to: time)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            playerToolBar?.setBarPlayer(ncplayer: self)
                        }
                    }
                    break
                case .failed:
                    DispatchQueue.main.async {
                        NCContentPresenter.shared.messageNotification("_error_", description: "_error_something_wrong_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.info, errorCode: NCGlobal.shared.errorGeneric, forced: false)
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

    deinit {
        print("deinit NCPlayer")
    }
    
    //MARK: - NotificationCenter

    @objc func applicationDidEnterBackground(_ notification: NSNotification) {
        
        if metadata?.classFile == NCCommunicationCommon.typeClassFile.video.rawValue {
            self.player?.pause()
        }
    }
    
    //MARK: -
    
    func videoPlay() {
                
        self.player?.play()
    }
    
    func videoPause() {
        
        self.player?.pause()
    }
    
    func saveCurrentTime() {
        guard let metadata = self.metadata else { return }

        NCManageDatabase.shared.addVideoTime(metadata: metadata, time: self.player?.currentTime(), durationSeconds: nil)
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
        
        return CMTimeGetSeconds(self.player?.currentTime() ?? .zero)
    }
    
    func getVideoDurationSeconds() -> Float64 {
        
        return self.durationSeconds
    }
    
    func generatorImage(to time: CMTime) -> UIImage? {
        
        var image: UIImage?

        if let asset = self.player?.currentItem?.asset {

            do {
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                image = UIImage(cgImage: cgImage)
                print("")
            }
            catch let error as NSError {
                print(error.localizedDescription)
            }
        }
        
        return image
    }
}

