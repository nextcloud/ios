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
    internal var url: URL?
    internal var player = VLCMediaPlayer()
    internal var dialogProvider: VLCDialogProvider?
    internal var metadata: tableMetadata
    internal var singleTapGestureRecognizer: UITapGestureRecognizer?
    internal var activityIndicator: UIActivityIndicatorView
    internal let database = NCManageDatabase.shared
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

        self.activityIndicator = UIActivityIndicatorView(style: .large)
        self.activityIndicator.color = .white
        self.activityIndicator.hidesWhenStopped = true
        self.activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        if let viewerMediaPage = viewerMediaPage {
            viewerMediaPage.view.addSubview(activityIndicator)
            NSLayoutConstraint.activate([
                activityIndicator.centerXAnchor.constraint(equalTo: viewerMediaPage.view.centerXAnchor),
                activityIndicator.centerYAnchor.constraint(equalTo: viewerMediaPage.view.centerYAnchor)
            ])
        }

        super.init()
    }

    deinit {
        player.stop()
        print("deinit NCPlayer with ocId \(metadata.ocId)")
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterPlayerStoppedPlaying)
    }

    func openAVPlayer(url: URL, autoplay: Bool = false) {
        var position: Float = 0
        let userAgent = userAgent

        self.url = url
        self.singleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didSingleTapWith(gestureRecognizer:)))

        print("Play URL: \(url)")
        player.media = VLCMedia(url: url)
        player.delegate = self

        dialogProvider = VLCDialogProvider(library: VLCLibrary.shared(), customUI: true)
        dialogProvider?.customRenderer = self

        // player?.media?.addOption("--network-caching=500")
        player.media?.addOption(":http-user-agent=\(userAgent)")

        if let result = self.database.getVideo(metadata: metadata),
            let resultPosition = result.position {
            position = resultPosition
        }

        if metadata.isVideo {
            player.drawable = imageVideoContainer
            if let view = player.drawable as? UIView, let singleTapGestureRecognizer = singleTapGestureRecognizer {
                view.isUserInteractionEnabled = true
                view.addGestureRecognizer(singleTapGestureRecognizer)
            }
        }

        player.play()
        player.position = position

        if autoplay {
            pauseAfterPlay = false
        } else {
            pauseAfterPlay = true
        }

        playerToolBar?.setBarPlayer(position: position, ncplayer: self, metadata: metadata, viewerMediaPage: viewerMediaPage)

        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    func restartAVPlayer(position: Float, pauseAfterPlay: Bool) {
        if let url = self.url, !player.isPlaying {

            player.media = VLCMedia(url: url)
            player.position = position
            playerToolBar?.setBarPlayer(position: position)
            viewerMediaPage?.changeScreenMode(mode: .normal)
            self.pauseAfterPlay = pauseAfterPlay
            player.play()

            if metadata.isVideo {
                if position == 0 {
                    imageVideoContainer?.image = NCUtility().getImage(ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal.shared.previewExt1024)
                } else {
                    imageVideoContainer?.image = nil
                }
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

    func isPlaying() -> Bool {
        return player.isPlaying
    }

    func playerPlay() {
        playerToolBar?.playbackSliderEvent = .began

        if let result = self.database.getVideo(metadata: metadata), let position = result.position {
            player.position = position
            playerToolBar?.playbackSliderEvent = .moved
        }

        player.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.playerToolBar?.playbackSliderEvent = .ended
        }
    }

    @objc func playerStop() {
        savePosition()
        player.stop()
    }

    @objc func playerPause() {
        savePosition()
        player.pause()
    }

    func playerPosition(_ position: Float) {
        self.database.addVideo(metadata: metadata, position: position)
        player.position = position
    }

    func savePosition() {
        guard metadata.isVideo, isPlaying() else { return }
        self.database.addVideo(metadata: metadata, position: player.position)
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

        if player.state == .buffering && player.isPlaying {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }

        switch player.state {
        case .stopped:
            playerToolBar?.playButtonPlay()

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterPlayerStoppedPlaying)

            print("Played mode: STOPPED")
        case .opening:
            print("Played mode: OPENING")
        case .buffering:
            print("Played mode: BUFFERING")
        case .ended:
            self.database.addVideo(metadata: self.metadata, position: 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if let playRepeat = self.playerToolBar?.playRepeat {
                    self.restartAVPlayer(position: 0, pauseAfterPlay: !playRepeat)
                }
            }
            playerToolBar?.playButtonPlay()
            print("Played mode: ENDED")
        case .error:
            print("Played mode: ERROR")
        case .playing:
            guard let playerToolBar = playerToolBar else { return }
            if playerToolBar.playerButtonView.isHidden {
                playerToolBar.playerButtonView.isHidden = false
                viewerMediaPage?.changeScreenMode(mode: .normal)
            }
            if pauseAfterPlay {
                player.pause()
                pauseAfterPlay = false
                self.viewerMediaPage?.updateCommandCenter(ncplayer: self, title: metadata.fileNameView)
            } else {
                playerToolBar.playButtonPause()
                // Set track audio/subtitle
                let data = self.database.getVideo(metadata: metadata)
                if let currentAudioTrackIndex = data?.currentAudioTrackIndex {
                    player.currentAudioTrackIndex = Int32(currentAudioTrackIndex)
                }
                if let currentVideoSubTitleIndex = data?.currentVideoSubTitleIndex {
                    player.currentVideoSubTitleIndex = Int32(currentVideoSubTitleIndex)
                }
            }
            let size = player.videoSize
            if let mediaLength = player.media?.length.intValue {
                self.length = Int(mediaLength)
            }
            self.width = Int(size.width)
            self.height = Int(size.height)
            playerToolBar.updateTopToolBar(videoSubTitlesIndexes: player.videoSubTitlesIndexes, audioTrackIndexes: player.audioTrackIndexes)
            self.database.addVideo(metadata: metadata, width: self.width, height: self.height, length: self.length)

            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterPlayerIsPlaying)

            print("Played mode: PLAYING")
        case .paused:
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterPlayerStoppedPlaying)

            playerToolBar?.playButtonPlay()
            print("Played mode: PAUSED")
        default: break
        }
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        activityIndicator.stopAnimating()
        playerToolBar?.update()
    }
}

extension NCPlayer: VLCMediaThumbnailerDelegate {
    func mediaThumbnailerDidTimeOut(_ mediaThumbnailer: VLCMediaThumbnailer) { }
    func mediaThumbnailer(_ mediaThumbnailer: VLCMediaThumbnailer, didFinishThumbnail thumbnail: CGImage) { }
}

extension NCPlayer: VLCCustomDialogRendererProtocol {
    func showError(withTitle error: String, message: String) {
        let alert = UIAlertController(title: error, message: message, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in
            self.playerToolBar?.removeFromSuperview()
            self.viewerMediaPage?.viewUnload()
        }))

        self.viewerMediaPage?.present(alert, animated: true)
    }

    func showLogin(withTitle title: String, message: String, defaultUsername username: String?, askingForStorage: Bool, withReference reference: NSValue) {
        // UIAlertController other states...
    }

    func showQuestion(withTitle title: String, message: String, type questionType: VLCDialogQuestionType, cancel cancelString: String?, action1String: String?, action2String: String?, withReference reference: NSValue) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        if let action1String = action1String {
            alert.addAction(UIAlertAction(title: action1String, style: .default, handler: { _ in
                self.dialogProvider?.postAction(1, forDialogReference: reference)
            }))
        }
        if let action2String = action2String {
            alert.addAction(UIAlertAction(title: action2String, style: .default, handler: { _ in
                self.dialogProvider?.postAction(2, forDialogReference: reference)
            }))
        }
        if let cancelString = cancelString {
            alert.addAction(UIAlertAction(title: cancelString, style: .cancel, handler: { _ in
                self.dialogProvider?.postAction(3, forDialogReference: reference)
            }))
        }

        self.viewerMediaPage?.present(alert, animated: true)
    }

    func showProgress(withTitle title: String, message: String, isIndeterminate: Bool, position: Float, cancel cancelString: String?, withReference reference: NSValue) {
        // UIAlertController other states...
    }

    func updateProgress(withReference reference: NSValue, message: String?, position: Float) {
        // UIAlertController other states...
    }

    func cancelDialog(withReference reference: NSValue) {
        // UIAlertController other states...
    }
}
