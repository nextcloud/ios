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
import MediaPlayer
import JGProgressHUD
import Alamofire

class NCPlayer: NSObject {
   
    internal let appDelegate = UIApplication.shared.delegate as! AppDelegate
    internal var url: URL
    internal var playerToolBar: NCPlayerToolBar?
    internal var viewController: UIViewController
    internal var autoPlay: Bool
    internal var isProxy: Bool

    private var imageVideoContainer: imageVideoContainerView
    private var detailView: NCViewerMediaDetailView?
    private var observerAVPlayerItemDidPlayToEndTime: Any?
    private var observerAVPlayertTime: Any?

    public var player: AVPlayer?
    public var durationTime: CMTime = .zero
    public var metadata: tableMetadata
    public var videoLayer: AVPlayerLayer?

    // MARK: - View Life Cycle

    init(url: URL, autoPlay: Bool, isProxy: Bool, imageVideoContainer: imageVideoContainerView, playerToolBar: NCPlayerToolBar?, metadata: tableMetadata, detailView: NCViewerMediaDetailView?, viewController: UIViewController) {
        
        self.url = url
        self.autoPlay = autoPlay
        self.isProxy = isProxy
        self.imageVideoContainer = imageVideoContainer
        self.playerToolBar = playerToolBar
        self.metadata = metadata
        self.detailView = detailView
        self.viewController = viewController

        super.init()
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(AVAudioSession.PortOverride.none)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print(error)
        }
        
        openAVPlayer()
    }
    
    internal func openAVPlayer() {
        
        #if MFFFLIB
        if MFFF.shared.existsMFFFSession(url: URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))) {
            return
        } else {
            MFFF.shared.dismissMessage()
        }
        #endif

        print("Play URL: \(self.url)")
        player = AVPlayer(url: self.url)
        playerToolBar?.setMetadata(self.metadata)

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
            let status = self.player?.currentItem?.asset.statusOfValue(forKey: "playable", error: &error) ?? .unknown

            DispatchQueue.main.async {

                switch status {
                case .loaded:
                    self.durationTime = self.player?.currentItem?.asset.duration ?? .zero
                    NCManageDatabase.shared.addVideoTime(metadata: self.metadata, time: nil, durationTime: self.durationTime)

                    self.activateObserver(playerToolBar: self.playerToolBar)

                    self.videoLayer = AVPlayerLayer(player: self.player)
                    self.videoLayer!.frame = self.imageVideoContainer.bounds
                    self.videoLayer!.videoGravity = .resizeAspect

                    if self.metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue {

                        self.imageVideoContainer.layer.addSublayer(self.videoLayer!)
                        self.imageVideoContainer.playerLayer = self.videoLayer
                        self.imageVideoContainer.metadata = self.metadata
                        self.imageVideoContainer.image = self.imageVideoContainer.image?.image(alpha: 0)
                    }

                    self.playerToolBar?.setBarPlayer(ncplayer: self)
                    self.generatorImagePreview()
                    if !(self.detailView?.isShow() ?? false) {
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShowPlayerToolBar, userInfo: ["ocId":self.metadata.ocId, "enableTimerAutoHide": false])
                    }
                    if self.autoPlay {
                        self.player?.play()
                    }
                    break
                case .failed:
                    self.playerToolBar?.hide()
                    if self.isProxy && NCKTVHTTPCache.shared.getDownloadStatusCode(metadata: self.metadata) == 200 {
                        let alertController = UIAlertController(title: NSLocalizedString("_error_", value: "Error", comment: ""), message: NSLocalizedString("_video_not_streamed_", comment: ""), preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_", value: "Yes", comment: ""), style: .default, handler: { _ in
                            self.downloadVideo()
                        }))
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_", value: "No", comment: ""), style: .default, handler: { _ in }))
                        self.viewController.present(alertController, animated: true)
                    } else {
                        #if MFFFLIB
                        if error?.code == AVError.Code.fileFormatNotRecognized.rawValue {
                            self.convertVideo()
                        }
                        #else
                        if let title = error?.localizedDescription, let description = error?.localizedFailureReason {
                            NCContentPresenter.shared.messageNotification(title, description: description, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorGeneric, priority: .max)
                        } else {
                            NCContentPresenter.shared.messageNotification("_error_", description: "_error_something_wrong_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorGeneric, priority: .max)
                        }
                        #endif
                    }
                    break
                case .cancelled:
                    break
                default:
                    break
                }
            }
        })
    }

    internal func downloadVideo() {
        
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
        let hud = JGProgressHUD()
        var downloadRequest: DownloadRequest?

        hud.indicatorView = JGProgressHUDRingIndicatorView()
        if let indicatorView = hud.indicatorView as? JGProgressHUDRingIndicatorView {
            indicatorView.ringWidth = 1.5
        }
        hud.show(in: self.viewController.view)
        hud.textLabel.text = NSLocalizedString(metadata.fileNameView, comment: "")
        hud.detailTextLabel.text = NSLocalizedString("_tap_to_cancel_", comment: "")
        hud.tapOnHUDViewBlock = { hud in
            downloadRequest?.cancel()
        }
        
        NCCommunication.shared.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath) { request in
            downloadRequest = request
        } taskHandler: { task in
            // task
        } progressHandler: { progress in
            hud.progress = Float(progress.fractionCompleted)
        } completionHandler: { _, _, _, _, _, error, _, _ in
            if error == nil {
                NCManageDatabase.shared.addLocalFile(metadata: self.metadata)
                let urlVideo = NCKTVHTTPCache.shared.getVideoURL(metadata: self.metadata)
                if let url = urlVideo.url {
                    self.url = url
                    self.isProxy = urlVideo.isProxy
                    self.openAVPlayer()
                }
            }
            hud.dismiss()
        }
    }

    deinit {
        print("deinit NCPlayer")

        deactivateObserver()
    }

    func activateObserver(playerToolBar: NCPlayerToolBar?) {

        self.playerToolBar = playerToolBar

        // At end go back to start & show toolbar
        observerAVPlayerItemDidPlayToEndTime = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: .main) { notification in
            if let item = notification.object as? AVPlayerItem, let currentItem = self.player?.currentItem, item == currentItem {
                
                NCKTVHTTPCache.shared.saveCache(metadata: self.metadata)
                
                self.videoSeek(time: .zero)
               
                if !(self.detailView?.isShow() ?? false) {
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShowPlayerToolBar, userInfo: ["ocId": self.metadata.ocId, "enableTimerAutoHide": false])
                }
                
                self.playerToolBar?.updateToolBar()
            }
        }

        // Evey 1 second update toolbar
        observerAVPlayertTime = player?.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(1, preferredTimescale: 1), queue: .main, using: { _ in
            if self.player?.currentItem?.status == .readyToPlay {
                self.playerToolBar?.updateToolBar()
            }
        })

        NotificationCenter.default.addObserver(self, selector: #selector(generatorImagePreview), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationWillResignActive), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidEnterBackground), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidBecomeActive), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerPause), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterPauseMedia), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playerPlay), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterPlayMedia), object: nil)
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
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterPauseMedia), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterPlayMedia), object: nil)
    }

    // MARK: - NotificationCenter

    @objc func applicationDidEnterBackground(_ notification: NSNotification) {
                
        if metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue, let playerToolBar = self.playerToolBar {
            if !playerToolBar.isPictureInPictureActive() {
                playerPause()
            }
        }
    }

    @objc func applicationDidBecomeActive(_ notification: NSNotification) {

        playerToolBar?.updateToolBar()
    }
    
    // MARK: -

    func isPlay() -> Bool {

        if player?.rate == 1 { return true } else { return false }
    }
    
    @objc func playerPlay() {
                
        player?.play()
        self.playerToolBar?.updateToolBar()
    }
    
    @objc func playerPause() {
        
        player?.pause()
        self.playerToolBar?.updateToolBar()

        if let playerToolBar = self.playerToolBar, playerToolBar.isPictureInPictureActive() {
            playerToolBar.pictureInPictureController?.stopPictureInPicture()
        }
    }

    func videoSeek(time: CMTime) {

        player?.seek(to: time)
        self.saveTime(time)
    }

    func saveTime(_ time: CMTime) {

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

        guard let time = player?.currentTime(), !metadata.livePhoto, metadata.classFile != NCCommunicationCommon.typeClassFile.audio.rawValue  else { return }

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
                    MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in
                        return image
                    }
                }
                // Preview
                if let data = image?.jpegData(compressionQuality: 0.5) {
                    try data.write(to: URL(fileURLWithPath: fileNamePreviewLocalPath), options: .atomic)
                }
                // Icon
                if let data = image?.jpegData(compressionQuality: 0.5) {
                    try data.write(to: URL(fileURLWithPath: fileNameIconLocalPath), options: .atomic)
                }
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        }
    }
}

