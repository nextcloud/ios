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
    internal var player = VLCMediaPlayer()
    internal var metadata: tableMetadata
    internal var singleTapGestureRecognizer: UITapGestureRecognizer!
    internal var width: Int?
    internal var height: Int?
    internal var length: Int?
    internal var pauseAfterPlay: Bool = false

    internal weak var playerToolBar: NCPlayerToolBar?
    internal weak var viewerMediaPage: NCViewerMediaPage?

    weak var imageVideoContainer: UIImageView?

    internal var counterSeconds: Double = 0

    // MARK: - View Life Cycle

    init(imageVideoContainer: UIImageView, playerToolBar: NCPlayerToolBar?, metadata: tableMetadata, viewerMediaPage: NCViewerMediaPage?) {

        self.imageVideoContainer = imageVideoContainer
        self.playerToolBar = playerToolBar
        self.metadata = metadata
        self.viewerMediaPage = viewerMediaPage

        super.init()
    }

    deinit {

        player.stop()
        print("deinit NCPlayer with ocId \(metadata.ocId)")
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidEnterBackground), object: nil)
    }

    func openAVPlayer(url: URL, autoplay: Bool = false) {

        var position: Float = 0
        let userAgent = CCUtility.getUserAgent()!

        self.url = url
        self.singleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didSingleTapWith(gestureRecognizer:)))

        print("Play URL: \(url)")
        player.media = VLCMedia(url: url)
        player.delegate = self

        // player?.media?.addOption("--network-caching=500")
        player.media?.addOption(":http-user-agent=\(userAgent)")

        if let result = NCManageDatabase.shared.getVideo(metadata: metadata),
            let resultPosition = result.position {
            position = resultPosition
        }

        player.drawable = imageVideoContainer
        if let view = player.drawable as? UIView {
            view.isUserInteractionEnabled = true
            view.addGestureRecognizer(singleTapGestureRecognizer)
        }

        player.play()
        player.position = position

        if autoplay {
            pauseAfterPlay = false
        } else {
            pauseAfterPlay = true
        }

        playerToolBar?.setBarPlayer(position: position, ncplayer: self, metadata: metadata, viewerMediaPage: viewerMediaPage)

        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidEnterBackground), object: nil)
    }

    func restartAVPlayer(position: Float) {

        if let url = self.url, !player.isPlaying {

            player.media = VLCMedia(url: url)
            player.position = position
            playerToolBar?.setBarPlayer(position: position)
            viewerMediaPage?.changeScreenMode(mode: .normal)
            pauseAfterPlay = true
            player.play()

            if position == 0 {
                let fileNamePreviewLocalPath = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)!
                imageVideoContainer?.image = UIImage(contentsOfFile: fileNamePreviewLocalPath)
            } else {
                imageVideoContainer?.image = nil
            }
        }
    }

    // MARK: - UIGestureRecognizerDelegate

    @objc func didSingleTapWith(gestureRecognizer: UITapGestureRecognizer) {
        changeScreenMode()
    }

    func changeScreenMode() {

        guard let viewerMediaPage = viewerMediaPage else { return }

        if viewerMediaScreenMode == .full {
            viewerMediaPage.changeScreenMode(mode: .normal)
        } else {
            viewerMediaPage.changeScreenMode(mode: .full)
        }
    }

    // MARK: - NotificationCenter

    @objc func applicationDidEnterBackground(_ notification: NSNotification) {

        if metadata.isVideo {
            playerPause()
        }
    }

    // MARK: -

    func isPlay() -> Bool {

        return player.isPlaying
    }

    func playerPlay() {

        playerToolBar?.playbackSliderEvent = .began

        if let result = NCManageDatabase.shared.getVideo(metadata: metadata), let position = result.position {
            player.position = position
            playerToolBar?.playbackSliderEvent = .moved
        }

        player.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.playerToolBar?.playbackSliderEvent = .ended
        }
    }

    @objc func playerStop() {

        player.stop()
    }

    @objc func playerPause() {

        savePosition()
        player.pause()
    }

    func playerPosition(_ position: Float) {

        NCManageDatabase.shared.addVideo(metadata: metadata, position: position)
        player.position = position
    }

    func savePosition() {

        guard metadata.isVideo, isPlay() else { return }
        NCManageDatabase.shared.addVideo(metadata: metadata, position: player.position)
    }

    func jumpForward(_ seconds: Int32) {

        player.play()
        player.jumpForward(seconds)
    }

    func jumpBackward(_ seconds: Int32) {

        player.play()
        player.jumpBackward(seconds)
    }
}

extension NCPlayer: VLCMediaPlayerDelegate {

    func mediaPlayerStateChanged(_ aNotification: Notification) {

        switch player.state {
        case .stopped:
            playerToolBar?.playButtonPlay()
            print("Played mode: STOPPED")
            break
        case .opening:
            print("Played mode: OPENING")
            break
        case .buffering:
            print("Played mode: BUFFERING")
            break
        case .ended:
            NCManageDatabase.shared.addVideo(metadata: self.metadata, position: 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.restartAVPlayer(position: 0)
            }
            playerToolBar?.playButtonPlay()
            print("Played mode: ENDED")
            break
        case .error:
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_error_something_wrong_")
            NCContentPresenter.shared.showError(error: error, priority: .max)
            playerToolBar?.removeFromSuperview()
            print("Played mode: ERROR")
            break
        case .playing:
            playerToolBar?.playerView(hidden: false)
            if pauseAfterPlay {
                player.pause()
                pauseAfterPlay = false
                print(player.position)
            } else {
                playerToolBar?.playButtonPause()
            }
            let size = player.videoSize
            if let mediaLength = player.media?.length.intValue {
                self.length = Int(mediaLength)
            }
            self.width = Int(size.width)
            self.height = Int(size.height)
            playerToolBar?.updateTopToolBar(videoSubTitlesIndexes: player.videoSubTitlesIndexes, audioTrackIndexes: player.audioTrackIndexes)
            NCManageDatabase.shared.addVideo(metadata: metadata, width: self.width, height: self.height, length: self.length)
            print("Played mode: PLAYING")
            break
        case .paused:
            playerToolBar?.playButtonPlay()
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
        // Handle other states...
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
