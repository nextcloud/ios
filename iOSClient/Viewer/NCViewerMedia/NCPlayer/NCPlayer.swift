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
    internal var width: Int?
    internal var height: Int?
    internal var length: Int?
    internal let fileNamePreviewLocalPath: String

    internal weak var playerToolBar: NCPlayerToolBar?
    internal weak var viewerMediaPage: NCViewerMediaPage?

    weak var imageVideoContainer: imageVideoContainerView?

    internal var counterSeconds: Double = 0

    // MARK: - View Life Cycle

    init(imageVideoContainer: imageVideoContainerView, playerToolBar: NCPlayerToolBar?, metadata: tableMetadata, viewerMediaPage: NCViewerMediaPage?) {

        self.imageVideoContainer = imageVideoContainer
        self.playerToolBar = playerToolBar
        self.metadata = metadata
        self.viewerMediaPage = viewerMediaPage

        fileNamePreviewLocalPath = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)!

        super.init()
    }

    deinit {

        print("deinit NCPlayer with ocId \(metadata.ocId)")
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidEnterBackground), object: nil)
    }

    func openAVPlayer(url: URL) {

        let userAgent = CCUtility.getUserAgent()!
        var positionSliderToolBar: Float = 0

        self.url = url
        self.singleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didSingleTapWith(gestureRecognizer:)))

        print("Play URL: \(url)")
        player = VLCMediaPlayer()
        player?.media = VLCMedia(url: url)
        player?.delegate = self

        // player?.media?.addOption("--network-caching=500")
        player?.media?.addOption(":http-user-agent=\(userAgent)")

        if let result = NCManageDatabase.shared.getVideo(metadata: metadata), let position = result.position {
            positionSliderToolBar = position
            player?.position = positionSliderToolBar
        }

        player?.drawable = imageVideoContainer
        if let view = player?.drawable as? UIView {
            view.isUserInteractionEnabled = true
            view.addGestureRecognizer(singleTapGestureRecognizer)
        }

        playerToolBar?.setBarPlayer(ncplayer: self, position: positionSliderToolBar, metadata: metadata, viewerMediaPage: viewerMediaPage)

        player?.play()
        player?.pause()

        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidEnterBackground), object: nil)
    }

    // MARK: - UIGestureRecognizerDelegate

    @objc func didSingleTapWith(gestureRecognizer: UITapGestureRecognizer) {

        viewerMediaPage?.didSingleTapWith(gestureRecognizer: gestureRecognizer)
    }

    // MARK: - NotificationCenter

    @objc func applicationDidEnterBackground(_ notification: NSNotification) {

        if metadata.isVideo {
            playerStop()
        }
    }

    // MARK: -

    func isPlay() -> Bool {

        return player?.isPlaying ?? false
    }

    func playerPlay() {

        playerToolBar?.playbackSliderEvent = .began
        player?.play()
        playerToolBar?.playButtonPause()

        if let result = NCManageDatabase.shared.getVideo(metadata: metadata), let position = result.position {
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

    @objc func playerPause() {

        savePosition()
        player?.pause()
        playerToolBar?.playButtonPlay()
    }

    func playerPosition(_ position: Float) {

        NCManageDatabase.shared.addVideo(metadata: metadata, position: position)
        player?.position = position
    }

    func savePosition() {

        guard let position = player?.position, metadata.isVideo, isPlay() else { return }
        NCManageDatabase.shared.addVideo(metadata: metadata, position: position)
    }

    func setVolumeAudio(_ volume: Int32) {

        player?.audio?.volume = volume
    }

    func jumpForward(_ seconds: Int32) {

        player?.jumpForward(seconds)
    }

    func jumpBackward(_ seconds: Int32) {

        player?.jumpBackward(seconds)
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
                self.thumbnailer?.fetchThumbnail()
                self.openAVPlayer(url: url)
            }
            print("Played mode: ENDED")
            break
        case .error:
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_error_something_wrong_")
            NCContentPresenter.shared.showError(error: error, priority: .max)
            print("Played mode: ERROR")
            break
        case .playing:
            let size = player.videoSize
            if let mediaLength = player.media?.length.intValue {
                self.length = Int(mediaLength)
            }
            self.width = Int(size.width)
            self.height = Int(size.height)
            NCManageDatabase.shared.addVideo(metadata: metadata, width: self.width, height: self.height, length: self.length)
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

    func mediaThumbnailer(_ mediaThumbnailer: VLCMediaThumbnailer, didFinishThumbnail thumbnail: CGImage) { }
}
