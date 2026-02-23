// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Marino Faggiana
// SPDX-FileCopyrightText: 2025 Serhii Kaliberda
// SPDX-License-Identifier: GPL-3.0-or-later

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
            playerToolBar?.showPauseButton()
        } else {
            playerToolBar?.showPlayButton()
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
