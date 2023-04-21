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
import MediaPlayer
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
    var thumbnailer: VLCMediaThumbnailer?
    var metadata: tableMetadata
    var singleTapGestureRecognizer: UITapGestureRecognizer!

    var width: Int64?
    var height: Int64?

    let fileNamePreviewLocalPath: String
    let fileNameIconLocalPath: String

    // MARK: - View Life Cycle

    init(imageVideoContainer: imageVideoContainerView, playerToolBar: NCPlayerToolBar?, metadata: tableMetadata, detailView: NCViewerMediaDetailView?, viewController: UIViewController, viewerMediaPage: NCViewerMediaPage?) {

        self.imageVideoContainer = imageVideoContainer
        self.playerToolBar = playerToolBar
        self.metadata = metadata
        self.detailView = detailView
        self.viewController = viewController
        self.viewerMediaPage = viewerMediaPage

        fileNamePreviewLocalPath = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)!
        fileNameIconLocalPath = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)!

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

        player?.stop()

        if let playerToolBar = self.playerToolBar, playerToolBar.isPictureInPictureActive() {
            playerToolBar.pictureInPictureController?.stopPictureInPicture()
        }
    }

    func openAVPlayer(url: URL) {

        var position: Float = 0

        self.url = url
        self.singleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didSingleTapWith(gestureRecognizer:)))

        print("Play URL: \(url)")
        player = VLCMediaPlayer()
        player?.media = VLCMedia(url: url)
        player?.delegate = self

        player?.media?.addOption("--network-caching=5000")

        let volume = CCUtility.getAudioVolume()
        if metadata.livePhoto {
            player?.audio?.volume = 0
        } else if metadata.classFile == NKCommon.TypeClassFile.audio.rawValue {
            player?.audio?.volume = Int32(volume)
        } else {
            player?.audio?.volume = Int32(volume)
            if let result = NCManageDatabase.shared.getVideoPosition(metadata: metadata) {
                position = result
                player?.position = position
            }
        }

        player?.drawable = self.imageVideoContainer
        if let view = player?.drawable as? UIView {
            view.isUserInteractionEnabled = true
            view.addGestureRecognizer(singleTapGestureRecognizer)
        }

        playerToolBar?.setBarPlayer(ncplayer: self, position: position)
        playerToolBar?.setMetadata(self.metadata)
        playerToolBar?.show(enableTimerAutoHide: false)

        if let media = player?.media {
            thumbnailer = VLCMediaThumbnailer(media: media, andDelegate: self)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidEnterBackground), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidBecomeActive), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(playerPause), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterPauseMedia), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playerPlay), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterPlayMedia), object: nil)
    }

    func closeAVPlayer() {

        playerPause(withSnapshot: false)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidEnterBackground), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidBecomeActive), object: nil)

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

        playerToolBar?.update(position: player?.position)
    }

    // MARK: -

    func isPlay() -> Bool {

        return player?.isPlaying ?? false
    }

    @objc func playerPlay() {

        player?.play()

        if let position = NCManageDatabase.shared.getVideoPosition(metadata: self.metadata) {
            player?.position = position
            playerToolBar?.update(position: position)
        } else {
            playerToolBar?.update(position: player?.position)
        }
    }

    @objc func playerPause(withSnapshot: Bool = true) {

        if let width = width, let height = height, withSnapshot {
            player?.saveVideoSnapshot(at: fileNamePreviewLocalPath, withWidth: Int32(width), andHeight: Int32(height))
        }

        player?.pause()
        playerToolBar?.update(position: player?.position)

        if let playerToolBar = self.playerToolBar, playerToolBar.isPictureInPictureActive() {
            playerToolBar.pictureInPictureController?.stopPictureInPicture()
        }
    }

    func videoSeek(position: Float) {

        player?.position = position
        playerToolBar?.update(position: position)
    }

    func savePosition(_ position: Float) {

        if metadata.classFile == NKCommon.TypeClassFile.audio.rawValue { return }
        let length = Int(player?.media?.length.intValue ?? 0)

        NCManageDatabase.shared.addVideo(metadata: metadata, position: position, length: length)
    }

    func snapshot() {

        if let player = player, let width = width, let height = height {
            player.saveVideoSnapshot(at: fileNamePreviewLocalPath, withWidth: Int32(width), andHeight: Int32(height))
        }
    }
}

extension NCPlayer: VLCMediaPlayerDelegate {

    func mediaPlayerStateChanged(_ aNotification: Notification) {
        guard let player = self.player else { return }

        switch player.state {
        case .stopped:
            if let url = self.url {
                NCManageDatabase.shared.addVideo(metadata: metadata, position: 0)
                if !(self.detailView?.isShow() ?? false) {
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShowPlayerToolBar, userInfo: ["ocId": self.metadata.ocId, "enableTimerAutoHide": false])
                }
                self.thumbnailer?.fetchThumbnail()
                self.openAVPlayer(url: url)
            }
            print("Played mode: STOPPED")
            break
        case .opening:
            playerToolBar?.buffering()
            print("Played mode: OPENING")
            break
        case .buffering:
            playerToolBar?.buffering()
            print("Played mode: BUFFERING")
            break
        case .ended:
            print("Played mode: ENDED")
            playerToolBar?.update(position: player.position)
            break
        case .error:
            print("Played mode: ERROR")
            break
        case .playing:
            if let tracksInformation = player.media?.tracksInformation {
                for case let track as [String:Any] in tracksInformation {
                    if track["type"] as? String == "video" {
                        width = track["width"] as? Int64
                        height = track["height"] as? Int64
                    }
                }
            }
            // let metaDictionary = player.media?.metaData
            print("Played mode: PLAYING")
            break
        case .paused:
            print("Played mode: PAUSED")
            playerToolBar?.update(position: player.position)
            break
        default: break
        }

        print(player.state)
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification) {

        self.playerToolBar?.update(position: player?.position)
    }

    func mediaPlayerTitleChanged(_ aNotification: Notification) {
        print(".")
    }

    func mediaPlayerChapterChanged(_ aNotification: Notification) {
        print(".")
    }

    func mediaPlayerLoudnessChanged(_ aNotification: Notification) {
        print(".")
    }

    func mediaPlayerSnapshot(_ aNotification: Notification) {
        if let data = NSData(contentsOfFile: fileNamePreviewLocalPath),
           let image = UIImage(data: data as Data),
           let image = image.resizeImage(size: CGSize(width: NCGlobal.shared.sizeIcon, height: NCGlobal.shared.sizeIcon)),
           let data = image.jpegData(compressionQuality: 0.5) {
            try? data.write(to: URL(fileURLWithPath: fileNameIconLocalPath))
        }
        print("Snapshot saved")

    }

    func mediaPlayerStartedRecording(_ player: VLCMediaPlayer) {
        // Handle other states...
    }

    func mediaPlayer(_ player: VLCMediaPlayer, recordingStoppedAtPath path: String) {
        // Handle other states...
    }
}

extension NCPlayer: VLCMediaThumbnailerDelegate {

    func mediaThumbnailerDidTimeOut(_ mediaThumbnailer: VLCMediaThumbnailer) { }

    func mediaThumbnailer(_ mediaThumbnailer: VLCMediaThumbnailer, didFinishThumbnail thumbnail: CGImage) {

        var image: UIImage?

        do {
            image = UIImage(cgImage: thumbnail)
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
