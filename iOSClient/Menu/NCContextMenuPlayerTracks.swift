// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import MobileVLCKit

class NCContextMenuPlayerTracks: NSObject {
    enum TrackType {
        case subtitle
        case audio
    }

    let trackType: TrackType
    let tracks: [Any]
    let trackIndexes: [Any]
    let currentIndex: Int?
    let ncplayer: NCPlayer?
    let metadata: tableMetadata?
    let viewerMediaPage: NCViewerMediaPage?
    private let database = NCManageDatabase.shared

    init(trackType: TrackType,
         tracks: [Any],
         trackIndexes: [Any],
         currentIndex: Int?,
         ncplayer: NCPlayer?,
         metadata: tableMetadata?,
         viewerMediaPage: NCViewerMediaPage?) {
        self.trackType = trackType
        self.tracks = tracks
        self.trackIndexes = trackIndexes
        self.currentIndex = currentIndex
        self.ncplayer = ncplayer
        self.metadata = metadata
        self.viewerMediaPage = viewerMediaPage
    }

    func viewMenu() -> UIMenu {
        var children: [UIMenuElement] = []

        // Track selection items
        if !tracks.isEmpty {
            for index in 0..<tracks.count {
                guard let title = tracks[index] as? String,
                      let idx = trackIndexes[index] as? Int32 else { continue }

                let isSelected = (currentIndex ?? -9999) == Int(idx)
                children.append(makeTrackAction(title: title, index: idx, isSelected: isSelected))
            }
        }

        // Add track action
        children.append(makeAddTrackAction())

        return UIMenu(title: "", children: children)
    }

    private func makeTrackAction(title: String, index: Int32, isSelected: Bool) -> UIAction {
        UIAction(
            title: title,
            state: isSelected ? .on : .off
        ) { _ in
            guard let metadata = self.metadata else { return }

            switch self.trackType {
            case .subtitle:
                self.ncplayer?.player.currentVideoSubTitleIndex = index
                self.database.addVideo(metadata: metadata, currentVideoSubTitleIndex: Int(index))
            case .audio:
                self.ncplayer?.player.currentAudioTrackIndex = index
                self.database.addVideo(metadata: metadata, currentAudioTrackIndex: Int(index))
            }
        }
    }

    private func makeAddTrackAction() -> UIAction {
        let title = trackType == .subtitle
            ? NSLocalizedString("_add_subtitle_", comment: "")
            : NSLocalizedString("_add_audio_", comment: "")

        return UIAction(title: title) { _ in
            guard let metadata = self.metadata else { return }
            let storyboard = UIStoryboard(name: "NCSelect", bundle: nil)
            if let navigationController = storyboard.instantiateInitialViewController() as? UINavigationController,
               let viewController = navigationController.topViewController as? NCSelect {

                viewController.delegate = self.viewerMediaPage?.currentViewController.playerToolBar
                viewController.typeOfCommandView = .nothing
                viewController.includeDirectoryE2EEncryption = false
                viewController.enableSelectFile = true
                viewController.type = self.trackType == .subtitle ? "subtitle" : "audio"
                viewController.serverUrl = metadata.serverUrl
                viewController.session = NCSession.shared.getSession(account: metadata.account)
                viewController.controller = nil

                self.viewerMediaPage?.present(navigationController, animated: true, completion: nil)
            }
        }
    }
}
