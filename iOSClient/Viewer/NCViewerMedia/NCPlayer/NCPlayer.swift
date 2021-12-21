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
import AVKit
import MediaPlayer

/// The Set of custom player controllers currently using or transitioning out of PiP
private var activeNCPlayer = Set<NCPlayer>()

class NCPlayer: NSObject {
   
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var playerToolBar: NCPlayerToolBar?
    private var detailView: NCViewerMediaDetailView?
    private var observerAVPlayerItemDidPlayToEndTime: Any?
    private var observerAVPlayertTime: Any?

    public var player: AVPlayer?
    public var durationTime: CMTime = .zero
    public var metadata: tableMetadata?
    public var videoLayer: AVPlayerLayer?
    public var pictureInPictureController: AVPictureInPictureController?
    
    // MARK: - View Life Cycle

    init(url: URL, autoPlay: Bool, imageVideoContainer: imageVideoContainerView, playerToolBar: NCPlayerToolBar?, metadata: tableMetadata, detailView: NCViewerMediaDetailView?) {
        super.init()
        
        self.metadata = metadata
        self.detailView = detailView

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(AVAudioSession.PortOverride.none)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print(error)
        }
        
        print("Play URL: \(url)")
        player = AVPlayer(url: url)
        
        self.durationTime = self.player?.currentItem?.asset.duration ?? .zero
        NCManageDatabase.shared.addVideoTime(metadata: metadata, time: nil, durationTime: self.durationTime)

        if metadata.livePhoto {
            player?.isMuted = false
        } else if metadata.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue {
            player?.isMuted = CCUtility.getAudioMute()
        } else {
            player?.isMuted = CCUtility.getAudioMute()
            if let time = NCManageDatabase.shared.getVideoTime(metadata: metadata) {
                player?.seek(to: time)
            }
        }
        
        player?.currentItem?.asset.loadValuesAsynchronously(forKeys: ["playable"], completionHandler: {
            var error: NSError? = nil
            let status = self.player?.currentItem?.asset.statusOfValue(forKey: "playable", error: &error)
            switch status {
            case .loaded:
                DispatchQueue.main.async {
                    
                    self.activateObserver(playerToolBar: playerToolBar)
                    
                    self.videoLayer = AVPlayerLayer(player: self.player)
                    self.videoLayer!.frame = imageVideoContainer.bounds
                    self.videoLayer!.videoGravity = .resizeAspect
                    
                    if metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue {
                    
                        imageVideoContainer.layer.addSublayer(self.videoLayer!)
                        imageVideoContainer.playerLayer = self.videoLayer
                        imageVideoContainer.metadata = self.metadata
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            imageVideoContainer.image = imageVideoContainer.image?.image(alpha: 0)
                        }
                        
                        // PIP
                        if let playerLayer = self.videoLayer, metadata.livePhoto == false {
                            self.pictureInPictureController = AVPictureInPictureController(playerLayer: playerLayer)
                            self.pictureInPictureController?.delegate = self
                        }
                    }
                    
                    self.playerToolBar?.setBarPlayer(ncplayer: self, metadata: metadata, image: imageVideoContainer.image)
                    self.generatorImagePreview()
                    if !(detailView?.isShow() ?? false) {
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShowPlayerToolBar, userInfo: ["ocId":metadata.ocId, "enableTimerAutoHide": false])
                    }

                    if autoPlay {
                        self.player?.play()
                    }
                }
                break
            case .failed:
                DispatchQueue.main.async {
                    if let title = error?.localizedDescription, let description = error?.localizedFailureReason {
                        NCContentPresenter.shared.messageNotification(title, description: description, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorGeneric, forced: false)
                    } else {
                        NCContentPresenter.shared.messageNotification("_error_", description: "_error_something_wrong_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorGeneric, forced: false)
                    }
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
        })
    }

    deinit {
        print("deinit NCPlayer")
        
        deactivateObserver()
    }
    
    func activateObserver(playerToolBar: NCPlayerToolBar?) {
        guard let metadata = self.metadata else { return }
        
        self.playerToolBar = playerToolBar
        
        // At end go back to start & show toolbar
        observerAVPlayerItemDidPlayToEndTime = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: .main) { (notification) in
            if let item = notification.object as? AVPlayerItem, let currentItem = self.player?.currentItem, item == currentItem {
                NCKTVHTTPCache.shared.saveCache(metadata: metadata)
                self.videoSeek(time: .zero)
                if !(self.detailView?.isShow() ?? false) {
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShowPlayerToolBar, userInfo: ["ocId":metadata.ocId, "enableTimerAutoHide": false])
                }
                self.playerToolBar?.updateToolBar()
            }
        }
        
        // Evey 1 second update toolbar
        observerAVPlayertTime = player?.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(1, preferredTimescale: 1), queue: .main, using: { (CMTime) in
            if self.player?.currentItem?.status == .readyToPlay, let playerToolBar = self.playerToolBar, playerToolBar.isShow() {
                self.playerToolBar?.updateToolBar()
            }
        })
        
        NotificationCenter.default.addObserver(self, selector: #selector(generatorImagePreview), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationWillResignActive), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidEnterBackground), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidBecomeActive), object: nil)
    }
    
    func deactivateObserver() {
        
        if isPlay() {
            playerPause()
        }
        
        self.playerToolBar = nil
        
        if let observerAVPlayerItemDidPlayToEndTime = self.observerAVPlayerItemDidPlayToEndTime {
            NotificationCenter.default.removeObserver(observerAVPlayerItemDidPlayToEndTime)
        }
        self.observerAVPlayerItemDidPlayToEndTime = nil
        
        if  let observerAVPlayertTime = self.observerAVPlayertTime {
            player?.removeTimeObserver(observerAVPlayertTime)
        }
        self.observerAVPlayertTime = nil
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationWillResignActive), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidEnterBackground), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidBecomeActive), object: nil)
    }
    
    //MARK: - NotificationCenter

    @objc func applicationDidEnterBackground(_ notification: NSNotification) {
        
        if metadata?.classFile == NCCommunicationCommon.typeClassFile.video.rawValue {
            if !isPictureInPictureActive() {
                playerPause()
            }
        }
    }
    
    @objc func applicationDidBecomeActive(_ notification: NSNotification) {
        
        playerToolBar?.updateToolBar()
    }
    
    //MARK: -
    
    func isPlay() -> Bool {
        
        if player?.rate == 1 { return true } else { return false }
    }
    
    func isPictureInPictureActive() -> Bool {
        guard let pictureInPictureController = self.pictureInPictureController else { return false }
        
        if pictureInPictureController.isPictureInPictureActive {
            return true
        } else {
            return false
        }
    }
    
    func playerPlay() {
                
        player?.play()
        self.playerToolBar?.updateToolBar()
    }
    
    func playerPause() {
        
        player?.pause()
        self.playerToolBar?.updateToolBar()
        
        if isPictureInPictureActive() {
            pictureInPictureController?.stopPictureInPicture()
        }
    }
    
    func videoSeek(time: CMTime) {
        
        player?.seek(to: time)
        self.saveTime(time)
    }
    
    func saveTime(_ time: CMTime) {
        guard let metadata = self.metadata else { return }
        if metadata.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue { return }

        NCManageDatabase.shared.addVideoTime(metadata: metadata, time: time, durationTime: nil)
        generatorImagePreview()
    }
    
    func saveCurrentTime() {
        
        if let player = self.player {
            saveTime(player.currentTime())
        }
    }
    
    @objc func generatorImagePreview() {
        guard let time = player?.currentTime() else { return }
        guard let metadata = self.metadata else { return }
        if metadata.livePhoto { return }
        if metadata.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue { return }

        var image: UIImage?

        if let asset = player?.currentItem?.asset {

            do {
                let fileNamePreviewLocalPath = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)!
                let fileNameIconLocalPath = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)!
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                image = UIImage(cgImage: cgImage)
                // Update Playing Info Center
                let mediaItemPropertyTitle = MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyTitle] as? String
                if let image = image, mediaItemPropertyTitle == metadata.fileNameView {
                    MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { size in
                        return image
                    }
                }
                // Preview
                if let data = image?.jpegData(compressionQuality: 0.5) {
                    try data.write(to: URL.init(fileURLWithPath: fileNamePreviewLocalPath), options: .atomic)
                }
                // Icon
                if let data = image?.jpegData(compressionQuality: 0.5) {
                    try data.write(to: URL.init(fileURLWithPath: fileNameIconLocalPath), options: .atomic)
                }
            }
            catch let error as NSError {
                print(error.localizedDescription)
            }
        }
    }
}

extension NCPlayer: AVPictureInPictureControllerDelegate {
    
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        
        activeNCPlayer.insert(self)
    }
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        // nothing
    }
    
    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        //nothing
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        guard let metadata = self.metadata else { return }

        if !isPlay() {
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShowPlayerToolBar, userInfo: ["ocId":metadata.ocId, "enableTimerAutoHide": false])
        }
    }
}

