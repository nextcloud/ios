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
import MobileVLCKit

class NCPlayer: NSObject {

    internal let appDelegate = UIApplication.shared.delegate as! AppDelegate
    internal var url: URL?
    internal var player: VLCMediaPlayer?
    internal var thumbnailer: VLCMediaThumbnailer?
    internal var metadata: tableMetadata
    internal var singleTapGestureRecognizer: UITapGestureRecognizer!
    internal var width: Int64?
    internal var height: Int64?
    internal let fileNamePreviewLocalPath: String
    internal let fileNameIconLocalPath: String

    internal weak var playerToolBar: NCPlayerToolBar?
    internal weak var viewerMediaPage: NCViewerMediaPage?

    weak var imageVideoContainer: imageVideoContainerView?

    // MARK: - View Life Cycle

    init(imageVideoContainer: imageVideoContainerView, playerToolBar: NCPlayerToolBar?, metadata: tableMetadata, viewerMediaPage: NCViewerMediaPage?) {

        self.imageVideoContainer = imageVideoContainer
        self.playerToolBar = playerToolBar
        self.metadata = metadata
        self.viewerMediaPage = viewerMediaPage

        fileNamePreviewLocalPath = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)!
        fileNameIconLocalPath = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)!

        super.init()
    }

    deinit {

        print("deinit NCPlayer with ocId \(metadata.ocId)")
        closeAVPlayer()
    }

    func openAVPlayer(url: URL) {

        let userAgent = CCUtility.getUserAgent()!
        var position: Float = 0

        self.url = url
        self.singleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didSingleTapWith(gestureRecognizer:)))

        print("Play URL: \(url)")
        player = VLCMediaPlayer()
        player?.media = VLCMedia(url: url)
        player?.delegate = self

        // player?.media?.addOption("--network-caching=500")
        player?.media?.addOption(":http-user-agent=\(userAgent)")

        if let result = NCManageDatabase.shared.getVideoPosition(metadata: metadata) {
            position = result
            player?.position = position
        }

        player?.drawable = imageVideoContainer
        if let view = player?.drawable as? UIView {
            view.isUserInteractionEnabled = true
            view.addGestureRecognizer(singleTapGestureRecognizer)
        }

        playerToolBar?.setBarPlayer(ncplayer: self, position: position, metadata: metadata)

        if let media = player?.media {
            thumbnailer = VLCMediaThumbnailer(media: media, andDelegate: self)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidEnterBackground), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidBecomeActive), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(playerPause), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterPauseMedia), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playerPlay), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterPlayMedia), object: nil)
    }

    func closeAVPlayer() {

        playerStop()

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

        if metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
            playerPause()
        }
    }

    @objc func applicationDidBecomeActive(_ notification: NSNotification) { }

    // MARK: -

    func isPlay() -> Bool {

        return player?.isPlaying ?? false
    }

    @objc func playerPlay() {

        playerToolBar?.playbackSliderEvent = .began
        player?.play()
        playerToolBar?.playButtonPause()
        
        if let position = NCManageDatabase.shared.getVideoPosition(metadata: metadata) {
            player?.position = position
            playerToolBar?.playbackSliderEvent = .moved
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.playerToolBar?.playbackSliderEvent = .ended
        }
    }

    @objc func playerStop() {

        savePosition()
        player?.stop()
        playerToolBar?.playButtonPlay()
    }

    @objc func playerPause(withSnapshot: Bool = true) {

        savePosition()
        player?.pause()
        playerToolBar?.playButtonPlay()
    }

    func playerPosizion(_ position: Float) {

        player?.position = position
    }

    func savePosition() {

        guard let position = player?.position, metadata.classFile == NKCommon.TypeClassFile.video.rawValue else { return }

        if let width = width, let height = height {
            player?.saveVideoSnapshot(at: fileNamePreviewLocalPath, withWidth: Int32(width), andHeight: Int32(height))
        }

        NCManageDatabase.shared.addVideo(metadata: metadata, position: position)
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
            print("Played mode: STOPPED")
            break
        case .opening:
            print("Played mode: OPENING")
            break
        case .buffering:
            print("Played mode: BUFFERING")
            break
        case .ended:
            if let url = self.url {
                NCManageDatabase.shared.addVideo(metadata: metadata, position: 0)
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterShowPlayerToolBar, userInfo: ["ocId": self.metadata.ocId, "enableTimerAutoHide": false])
                self.thumbnailer?.fetchThumbnail()
                self.openAVPlayer(url: url)
            }
            print("Played mode: ENDED")
            break
        case .error:
            playerToolBar?.disableAllControl()
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_error_something_wrong_")
            NCContentPresenter.shared.showError(error: error, priority: .max)
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
            print("Played mode: PLAYING")
            break
        case .paused:
            print("Played mode: PAUSED")
            break
        default: break
        }
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification) {

        playerToolBar?.update()
    }

    func mediaPlayerTitleChanged(_ aNotification: Notification) {
        // Handle other states...
    }

    func mediaPlayerChapterChanged(_ aNotification: Notification) {
        // Handle other states...
    }

    func mediaPlayerLoudnessChanged(_ aNotification: Notification) {
        // Handle other states...
    }

    func mediaPlayerSnapshot(_ aNotification: Notification) {
        
        if let data = NSData(contentsOfFile: fileNamePreviewLocalPath),
           let image = UIImage(data: data as Data),
           let image = image.resizeImage(size: CGSize(width: NCGlobal.shared.sizeIcon, height: NCGlobal.shared.sizeIcon)),
           let data = image.jpegData(compressionQuality: 0.5) {
            try? data.write(to: URL(fileURLWithPath: fileNameIconLocalPath))
        }
        print("Snapshot saved on \(fileNameIconLocalPath)")
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
            if let data = image?.jpegData(compressionQuality: 0.5) {
                try data.write(to: URL(fileURLWithPath: fileNamePreviewLocalPath), options: .atomic)
            }
            if let data = image?.jpegData(compressionQuality: 0.5) {
                try data.write(to: URL(fileURLWithPath: fileNameIconLocalPath), options: .atomic)
            }
        } catch let error as NSError {
            print("GeneratorImagePreview localized error:")
            print(error.localizedDescription)
        }
    }
}
