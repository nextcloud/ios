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
import NextcloudKit
import UIKit
import AVFoundation
import MediaPlayer
import JGProgressHUD
import Alamofire

class NCPlayer: NSObject {

    internal let appDelegate = UIApplication.shared.delegate as! AppDelegate
    internal var url: URL
    internal weak var playerToolBar: NCPlayerToolBar?
    internal weak var viewController: UIViewController?
    internal var autoPlay: Bool
    internal var isProxy: Bool
    internal var isStartPlayer: Bool
    internal var isStartObserver: Bool
    internal var subtitleUrls: [URL] = []
    internal var currentSubtitle: URL?

    private weak var imageVideoContainer: imageVideoContainerView?
    private weak var detailView: NCViewerMediaDetailView?
    private var observerAVPlayerItemDidPlayToEndTime: Any?
    private var observerAVPlayertTime: Any?

    var kvoPlayerObserver: NSKeyValueObservation?
    var player: AVPlayer?
    var durationTime: CMTime = .zero
    var metadata: tableMetadata
    var videoLayer: AVPlayerLayer?

    // MARK: - View Life Cycle

    init(url: URL, autoPlay: Bool, isProxy: Bool, imageVideoContainer: imageVideoContainerView, playerToolBar: NCPlayerToolBar?, metadata: tableMetadata, detailView: NCViewerMediaDetailView?, viewController: UIViewController) {

        self.url = url
        self.autoPlay = autoPlay
        self.isProxy = isProxy
        self.isStartPlayer = false
        self.isStartObserver = false
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
    }

    deinit {

        print("deinit NCPlayer with ocId \(metadata.ocId)")
        deactivateObserver()
    }

    func openAVPlayer() {

#if MFFFLIB
        MFFF.shared.setDelegate = self
        MFFF.shared.dismissMessage()
        NotificationCenter.default.addObserver(self, selector: #selector(convertVideoDidFinish(_:)), name: NSNotification.Name(rawValue: self.metadata.ocId), object: nil)

        if CCUtility.fileProviderStorageExists(metadata) {
            self.url = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: NCGlobal.shared.fileNameVideoEncoded))
            self.isProxy = false
        }
        if MFFF.shared.existsMFFFSession(url: URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))) {
            return
        }
#endif

        // Check already started
        if isStartPlayer {
            if !isStartObserver {
                print("Play already started - URL: \(self.url)")
                activateObserver()
                playerToolBar?.show()
            }
            return
        }

        print("Play URL: \(self.url)")
        player = AVPlayer(url: self.url)
        playerToolBar?.show()
        playerToolBar?.setMetadata(self.metadata)
#if MFFFLIB
        setUpForSubtitle()
#endif

        if metadata.livePhoto {
            player?.isMuted = false
        } else if metadata.classFile == NKCommon.TypeClassFile.audio.rawValue {
            player?.isMuted = CCUtility.getAudioMute()
        } else {
            player?.isMuted = CCUtility.getAudioMute()
            if let time = NCManageDatabase.shared.getVideoTime(metadata: metadata) {
                player?.seek(to: time)
            }
        }

        let observerAVPlayertStatus = self.player?.currentItem?.observe(\.status, options: [.new,.initial]) { player, change in

            if let player = self.player,
               let playerItem = player.currentItem,
               let object = player.currentItem,
               playerItem === object,
               self.viewController != nil {

                if self.isStartPlayer {
                    return
                }
                if (playerItem.status == .readyToPlay || playerItem.status == .failed) {
                    print("Player ready")
                    self.startPlayer()
                } else {
                    print("Player not ready")
                }
            }
        }

        if let observerAVPlayertStatus = observerAVPlayertStatus{
            kvoPlayerObserver = observerAVPlayertStatus
        }
    }

    func startPlayer() {

        player?.currentItem?.asset.loadValuesAsynchronously(forKeys: ["playable"], completionHandler: {

            var error: NSError? = nil
            let status = self.player?.currentItem?.asset.statusOfValue(forKey: "playable", error: &error) ?? .unknown

            DispatchQueue.main.async {

                switch status {
                case .loaded:

                    self.durationTime = self.player?.currentItem?.asset.duration ?? .zero
                    NCManageDatabase.shared.addVideoTime(metadata: self.metadata, time: nil, durationTime: self.durationTime)

                    self.videoLayer = AVPlayerLayer(player: self.player)
                    self.videoLayer!.frame = self.imageVideoContainer?.bounds ?? .zero
                    self.videoLayer!.videoGravity = .resizeAspect

                    if self.metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
                        self.imageVideoContainer?.layer.addSublayer(self.videoLayer!)
                        self.imageVideoContainer?.playerLayer = self.videoLayer
                        self.imageVideoContainer?.metadata = self.metadata
                        self.imageVideoContainer?.image = self.imageVideoContainer?.image?.image(alpha: 0)
                    }

                    self.playerToolBar?.setBarPlayer(ncplayer: self)
                    self.generatorImagePreview()
                    if !(self.detailView?.isShow() ?? false) {
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShowPlayerToolBar, userInfo: ["ocId":self.metadata.ocId, "enableTimerAutoHide": false])
                    }
                    self.activateObserver()
                    if self.autoPlay || CCUtility.getPlayerPlay() {
                        self.player?.play()
                    }
                    self.isStartPlayer = true
                    break

                case .failed:

                    self.playerToolBar?.hide()
                    if self.isProxy && NCKTVHTTPCache.shared.getDownloadStatusCode(metadata: self.metadata) == 200 {
                        let alertController = UIAlertController(title: NSLocalizedString("_error_", value: "Error", comment: ""), message: NSLocalizedString("_video_not_streamed_", comment: ""), preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_", value: "Yes", comment: ""), style: .default, handler: { _ in
                            self.downloadVideo()
                        }))
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_", value: "No", comment: ""), style: .default, handler: { _ in }))
                        self.viewController?.present(alertController, animated: true)
                    } else if self.metadata.isDirectoryE2EE {
                        let alertController = UIAlertController(title: NSLocalizedString("_info_", value: "Info", comment: ""), message: NSLocalizedString("_video_not_streamed_e2ee_", comment: ""), preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_", value: "Yes", comment: ""), style: .default, handler: { _ in
                            self.downloadVideo(isEncrypted: true)
                        }))
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_", value: "No", comment: ""), style: .default, handler: { _ in }))
                        self.viewController?.present(alertController, animated: true)
                    } else {
#if MFFFLIB
                        if error?.code == AVError.Code.fileFormatNotRecognized.rawValue {
                            self.convertVideo(withAlert: true)
                            break
                        }
#endif
                        if let title = error?.localizedDescription, let description = error?.localizedFailureReason {
                            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: description)
                            NCContentPresenter.shared.messageNotification(title, error: error, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, priority: .max)
                        } else {
                            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_error_something_wrong_")
                            NCContentPresenter.shared.showError(error: error, priority: .max)
                        }
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

    func activateObserver() {
        print("activating Observer ocId \(metadata.ocId)")

        observerAVPlayerItemDidPlayToEndTime = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: .main) {  [weak self] notification in

            guard let self = self else {
                return
            }

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
        observerAVPlayertTime = player?.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(1, preferredTimescale: 1), queue: .main, using: { [weak self] _ in

            guard let self = self else {
                return
            }

            if self.player?.currentItem?.status == .readyToPlay {
                self.playerToolBar?.updateToolBar()
            }
        })

        NotificationCenter.default.addObserver(self, selector: #selector(generatorImagePreview), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationWillResignActive), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidEnterBackground), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidBecomeActive), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(playerPause), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterPauseMedia), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playerPlay), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterPlayMedia), object: nil)

        if let player = self.player {
            NotificationCenter.default.addObserver(self, selector: #selector(playerStalled), name: NSNotification.Name.AVPlayerItemPlaybackStalled, object: player.currentItem)
        }

        isStartObserver = true
    }

    func deactivateObserver() {

        print("deactivating Observer ocId \(metadata.ocId)")

        if isPlay() {
            playerPause()
        }
        
        self.kvoPlayerObserver?.invalidate()
        self.kvoPlayerObserver = nil

        if let observerAVPlayerItemDidPlayToEndTime = self.observerAVPlayerItemDidPlayToEndTime {
            NotificationCenter.default.removeObserver(observerAVPlayerItemDidPlayToEndTime)
        }
        observerAVPlayerItemDidPlayToEndTime = nil

        if let observerAVPlayertTime = self.observerAVPlayertTime,
           let player = player {
            player.removeTimeObserver(observerAVPlayertTime)
        }
        observerAVPlayertTime = nil

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationWillResignActive), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidEnterBackground), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidBecomeActive), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemPlaybackStalled, object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterPauseMedia), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterPlayMedia), object: nil)
        
        isStartObserver = false
    }

    // MARK: - NotificationCenter

    @objc func applicationDidEnterBackground(_ notification: NSNotification) {

        if metadata.classFile == NKCommon.TypeClassFile.video.rawValue, let playerToolBar = self.playerToolBar {
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

    @objc func playerStalled() {

        print("current player \(String(describing: player)) stalled.\nCalling playerPlay()")
        playerPlay()
    }

    @objc func playerPlay() {

        player?.play()
        playerToolBar?.updateToolBar()
    }

    @objc func playerPause() {

        player?.pause()
        playerToolBar?.updateToolBar()

        if let playerToolBar = self.playerToolBar, playerToolBar.isPictureInPictureActive() {
            playerToolBar.pictureInPictureController?.stopPictureInPicture()
        }
    }

    func videoSeek(time: CMTime) {

        player?.seek(to: time)
        saveTime(time)
    }

    func saveTime(_ time: CMTime) {

        if metadata.classFile == NKCommon.TypeClassFile.audio.rawValue { return }

        NCManageDatabase.shared.addVideoTime(metadata: metadata, time: time, durationTime: nil)
        generatorImagePreview()
    }

    func saveCurrentTime() {

        if let player = self.player {
            saveTime(player.currentTime())
        }
    }

    @objc func generatorImagePreview() {

        guard let time = player?.currentTime(), !metadata.livePhoto, metadata.classFile != NKCommon.TypeClassFile.audio.rawValue  else { return }

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
                print("GeneratorImagePreview localized error:")
                print(error.localizedDescription)
            }
        }
    }

    internal func downloadVideo(isEncrypted: Bool = false, requiredConvert: Bool = false) {

        guard let view = appDelegate.window?.rootViewController?.view else { return }
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)!
        let hud = JGProgressHUD()
        var downloadRequest: DownloadRequest?

        hud.indicatorView = JGProgressHUDRingIndicatorView()
        if let indicatorView = hud.indicatorView as? JGProgressHUDRingIndicatorView {
            indicatorView.ringWidth = 1.5
        }
        hud.textLabel.text = NSLocalizedString(metadata.fileNameView, comment: "")
        hud.detailTextLabel.text = NSLocalizedString("_tap_to_cancel_", comment: "")
        hud.show(in: view)
        hud.tapOnHUDViewBlock = { hud in
            downloadRequest?.cancel()
        }

        NextcloudKit.shared.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath) { request in
            downloadRequest = request
        } taskHandler: { task in
            // task
        } progressHandler: { progress in
            hud.progress = Float(progress.fractionCompleted)
        } completionHandler: { _, _, _, _, _, afError, error in
            if afError == nil {
                NCManageDatabase.shared.addLocalFile(metadata: self.metadata)
                if isEncrypted {
                    if let result = NCManageDatabase.shared.getE2eEncryption(predicate: NSPredicate(format: "fileNameIdentifier == %@ AND serverUrl == %@", self.metadata.fileName, self.metadata.serverUrl)) {
                        NCEndToEndEncryption.sharedManager()?.decryptFile(self.metadata.fileName, fileNameView: self.metadata.fileNameView, ocId: self.metadata.ocId, key: result.key, initializationVector: result.initializationVector, authenticationTag: result.authenticationTag)
                    }
                }
                let urlVideo = NCKTVHTTPCache.shared.getVideoURL(metadata: self.metadata)
                if let url = urlVideo.url {
                    self.url = url
                    self.isProxy = urlVideo.isProxy
                    if requiredConvert {
#if MFFFLIB
                        self.convertVideo(withAlert: false)
#endif
                    } else {
                        self.openAVPlayer()
                    }
                }
            }
            hud.dismiss()
        }
    }
}
