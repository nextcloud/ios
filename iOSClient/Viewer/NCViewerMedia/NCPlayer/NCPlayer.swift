// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Marino Faggiana
// SPDX-FileCopyrightText: 2025 STRATO GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import UIKit
import MobileVLCKit
import Combine

class NCPlayer: NSObject {
    private var mediaCoordinator = NCMediaCoordinator.shared
    private var metadata: tableMetadata
    internal let database = NCManageDatabase.shared
    internal var width: Int?
    internal var height: Int?
    internal var length: Int?

    private weak var playerToolBar: NCPlayerToolBar?
    internal weak var viewerMediaPage: NCViewerMediaPage?

    // MARK: - View Life Cycle

    init(playerToolBar: NCPlayerToolBar?, metadata: tableMetadata, viewerMediaPage: NCViewerMediaPage?) {
        self.playerToolBar = playerToolBar
        self.metadata = metadata
        self.viewerMediaPage = viewerMediaPage

        super.init()

        configurePlayingUI()
    }

    deinit {
        print("deinit NCPlayer with ocId \(metadata.ocId)")
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterPlayerStoppedPlaying)
    }

    private func configurePlayingUI() {
        playerToolBar?.setBarPlayer(position: 0, ncplayer: self, metadata: metadata, viewerMediaPage: viewerMediaPage)
        playerToolBar?.playerButtonView?.isHidden = false
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

    func addPlaybackTrack(_ trackURL: URL, type mediaTrackType: NCMediaCoordinator.MediaTrackType, enforce enforceSelection: Bool) {
        mediaCoordinator.addPlaybackTrack(trackURL, type: mediaTrackType, enforce: enforceSelection)
    }
}
