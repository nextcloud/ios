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
import Combine

class NCPlayer: NSObject {
    private var mediaCoordinator = NCMediaCoordinator.shared
    private var metadata: tableMetadata
    internal var singleTapGestureRecognizer: UITapGestureRecognizer?
    internal let database = NCManageDatabase.shared
    internal var width: Int?
    internal var height: Int?
    internal var length: Int?

    private weak var playerToolBar: NCPlayerToolBar?
    internal weak var viewerMediaPage: NCViewerMediaPage?

    weak var imageVideoContainer: UIImageView?

    // MARK: - View Life Cycle

    init(imageVideoContainer: UIImageView, playerToolBar: NCPlayerToolBar?, metadata: tableMetadata, viewerMediaPage: NCViewerMediaPage?) {
        self.imageVideoContainer = imageVideoContainer
        self.playerToolBar = playerToolBar
        self.metadata = metadata
        self.viewerMediaPage = viewerMediaPage

        super.init()

        configurePlayingUI()
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    deinit {
        print("deinit NCPlayer with ocId \(metadata.ocId)")
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterPlayerStoppedPlaying)
    }

    private func configurePlayingUI() {
        self.singleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didSingleTapWith(gestureRecognizer:)))
        if metadata.isVideo {
            mediaCoordinator.videoOutputView = imageVideoContainer
            if let view = mediaCoordinator.videoOutputView, let singleTapGestureRecognizer = singleTapGestureRecognizer {
                view.isUserInteractionEnabled = true
                view.addGestureRecognizer(singleTapGestureRecognizer)
            }
        }

        playerToolBar?.setBarPlayer(position: 0, ncplayer: self, metadata: metadata, viewerMediaPage: viewerMediaPage)
        playerToolBar?.playerButtonView?.isHidden = false
        if mediaCoordinator.isPlaying {
            playerToolBar?.playButtonPause()
        } else {
            playerToolBar?.playButtonPlay()
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
            mediaCoordinator.pause()
        }
    }

    // MARK: -

    func isPlaying() -> Bool {
        return mediaCoordinator.isPlaying
    }

    func playerPlay() {
        guard metadata.ocId == mediaCoordinator.item?.ocId else {
            mediaCoordinator.play(item: metadata)
            return
        }
        playerToolBar?.playbackSliderEvent = .began

        if let result = self.database.getVideoOrAudio(metadata: metadata), let position = result.position {
            mediaCoordinator.position = position
            playerToolBar?.playbackSliderEvent = .moved
        }

        mediaCoordinator.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.playerToolBar?.playbackSliderEvent = .ended
        }
    }

    @objc func playerPause() {
        mediaCoordinator.pause()
    }

    func playerPosition(_ position: Float) {
        mediaCoordinator.position = position
    }

    func jumpForward(_ seconds: Int32) {
        mediaCoordinator.jumpForward(seconds)
    }

    func jumpBackward(_ seconds: Int32) {
        mediaCoordinator.jumpBackward(seconds)
    }

    var videoSubTitlesNames: [Any] {
        mediaCoordinator.videoSubTitlesNames
    }

    var videoSubTitlesIndexes: [Any] {
        mediaCoordinator.videoSubTitlesIndexes
    }

    var currentVideoSubTitleIndex: Int32 {
        get { mediaCoordinator.currentVideoSubTitleIndex }
        set { mediaCoordinator.currentVideoSubTitleIndex = newValue }
    }

    var audioTrackNames: [Any] {
        mediaCoordinator.audioTrackNames
    }

    var audioTrackIndexes: [Any] {
        mediaCoordinator.audioTrackIndexes
    }

    var currentAudioTrackIndex: Int32 {
        get { mediaCoordinator.currentAudioTrackIndex }
        set { mediaCoordinator.currentAudioTrackIndex = newValue }
    }

    @discardableResult
    func addPlaybackSlave(_ slaveURL: URL, type slaveType: VLCMediaPlaybackSlaveType, enforce enforceSelection: Bool) -> Int32 {
        mediaCoordinator.addPlaybackSlave(slaveURL, type: slaveType, enforce: enforceSelection)
    }
}
