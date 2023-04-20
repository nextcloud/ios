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
import MobileVLCKit

class NCPlayer: NSObject {

    internal let appDelegate = UIApplication.shared.delegate as! AppDelegate
    internal var url: URL?
    internal weak var playerToolBar: NCPlayerToolBar?
    internal weak var viewController: UIViewController?

    private weak var imageVideoContainer: imageVideoContainerView?
    private weak var detailView: NCViewerMediaDetailView?
    private weak var viewerMediaPage: NCViewerMediaPage?

    var player: VLCMediaPlayer?
    var metadata: tableMetadata
    var singleTapGestureRecognizer: UITapGestureRecognizer!

    // MARK: - View Life Cycle

    init(imageVideoContainer: imageVideoContainerView, playerToolBar: NCPlayerToolBar?, metadata: tableMetadata, detailView: NCViewerMediaDetailView?, viewController: UIViewController, viewerMediaPage: NCViewerMediaPage?) {

        self.imageVideoContainer = imageVideoContainer
        self.playerToolBar = playerToolBar
        self.metadata = metadata
        self.detailView = detailView
        self.viewController = viewController
        self.viewerMediaPage = viewerMediaPage

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

        playerClose()
        print("deinit NCPlayer with ocId \(metadata.ocId)")
    }

    func openAVPlayer(url: URL) {

        self.url = url
        self.singleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didSingleTapWith(gestureRecognizer:)))

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

        print("Play URL: \(url)")
        player = VLCMediaPlayer()
        player?.media = VLCMedia(url: url)
        player?.media?.addOption("--network-caching=10000")
        player?.delegate = self

        let volume = CCUtility.getAudioVolume()
        if metadata.livePhoto {
            player?.audio?.volume = 0
        } else if metadata.classFile == NKCommon.TypeClassFile.audio.rawValue {
            player?.audio?.volume = Int32(volume)
        } else {
            player?.audio?.volume = Int32(volume)
            if let position = NCManageDatabase.shared.getVideoPosition(metadata: metadata) {
                player?.position = position
            }
        }

        player?.drawable = self.imageVideoContainer
        if let view = player?.drawable as? UIView {
            view.isUserInteractionEnabled = true
            view.addGestureRecognizer(singleTapGestureRecognizer)
        }

        if NCManageDatabase.shared.getVideoAutoplay(metadata: metadata) {
            playerPlay()
            playerToolBar?.show(enableTimerAutoHide: true)
        } else {
            playerToolBar?.show(enableTimerAutoHide: false)
        }

        playerToolBar?.setBarPlayer(ncplayer: self)
        playerToolBar?.setMetadata(self.metadata)
    }

    func deactivatePlayer() {

        playerPause()
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationWillResignActive), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidEnterBackground), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidBecomeActive), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemPlaybackStalled, object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterPauseMedia), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterPlayMedia), object: nil)
    }

    // MARK: - UIGestureRecognizerDelegate

    @objc func didSingleTapWith(gestureRecognizer: UITapGestureRecognizer) {
        viewerMediaPage?.didSingleTapWith(gestureRecognizer: gestureRecognizer)
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

        return player?.isPlaying ?? false
    }

    @objc func playerPlay() {

        player?.play()
        if let position = NCManageDatabase.shared.getVideoPosition(metadata: self.metadata) {
            player?.position = position
        }
        playerToolBar?.updateToolBar()
    }

    @objc func playerPause() {

        if let position = player?.position {
            player?.pause()
            playerToolBar?.updateToolBar()
        }

        if let playerToolBar = self.playerToolBar, playerToolBar.isPictureInPictureActive() {
            playerToolBar.pictureInPictureController?.stopPictureInPicture()
        }
    }

    @objc func playerClose() {

        player?.stop()

        if let playerToolBar = self.playerToolBar, playerToolBar.isPictureInPictureActive() {
            playerToolBar.pictureInPictureController?.stopPictureInPicture()
        }
    }

    func videoSeek(position: Float) {

        player?.position = position
        playerToolBar?.updateToolBar()
    }

    func videoStop() {
        if let url = self.url {
            NCManageDatabase.shared.addVideo(metadata: metadata, position: 0, autoplay: false)
            if !(self.detailView?.isShow() ?? false) {
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShowPlayerToolBar, userInfo: ["ocId": self.metadata.ocId, "enableTimerAutoHide": false])
            }
            self.openAVPlayer(url: url)
        }
    }

    func savePosition(_ position: Float) {

        if metadata.classFile == NKCommon.TypeClassFile.audio.rawValue { return }
        let length = Int(player?.media?.length.intValue ?? 0)

        NCManageDatabase.shared.addVideo(metadata: metadata, position: position, length: length, autoplay: isPlay())
        generatorImagePreview()
    }

    @objc func generatorImagePreview() {

        /*
        guard let time = player.time, !metadata.livePhoto, metadata.classFile != NKCommon.TypeClassFile.audio.rawValue  else { return }

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
        */
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
                if CCUtility.fileProviderStorageExists(self.metadata) || self.metadata.isDirectoryE2EE {
                    let url = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(self.metadata.ocId, fileNameView: self.metadata.fileNameView))
                    if requiredConvert {
#if MFFFLIB
                        self.convertVideo(withAlert: false)
#endif
                    } else {
                        self.openAVPlayer(url: url)
                    }
                }
            }
            hud.dismiss()
        }
    }
}

extension NCPlayer: VLCMediaPlayerDelegate {

    func mediaPlayerStateChanged(_ aNotification: Notification) {
        guard let player = self.player else { return }

        switch player.state {
        case .stopped:
            videoStop()
            print("Played mode: STOPPED")
            break
        case .opening:
            print("Played mode: OPENING")
            break
        case .buffering:
            print("Played mode: BUFFERING")
            break
        case .ended:
            print("Played mode: ENDED")
            break
        case .error:
            print("Played mode: ERROR")
            break
        case .playing:
            print("Played mode: PLAYING")
            break
        case .paused:
            print("Played mode: PAUSED")
            break
        default: break
        }

        print(player.state)
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification) {

        self.playerToolBar?.updateToolBar()
    }

    func mediaPlayerTitleChanged(_ aNotification: Notification) {
        guard let player = self.player else { return }
        print(".")
    }

    func mediaPlayerChapterChanged(_ aNotification: Notification) {
        guard let player = self.player else { return }
        print(".")
    }

    func mediaPlayerLoudnessChanged(_ aNotification: Notification) {
        guard let player = self.player else { return }
        print(".")
    }

    func mediaPlayerSnapshot(_ aNotification: Notification) {
        guard let player = self.player else { return }
        print(".")
    }

    func mediaPlayerStartedRecording(_ player: VLCMediaPlayer) {
        // Handle other states...
    }

    func mediaPlayer(_ player: VLCMediaPlayer, recordingStoppedAtPath path: String) {
        // Handle other states...
    }
}
