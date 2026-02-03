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
        self.currentIndex = currentIndex
        self.ncplayer = ncplayer
        self.metadata = metadata
        self.viewerMediaPage = viewerMediaPage
    }

    func viewMenu() -> UIMenu {
        var children: [UIMenuElement] = []

        // Add track action
        switch self.trackType {
        case .subtitle:
            let deferredElement = UIDeferredMenuElement.uncached { [self] completion in
                guard let player = ncplayer?.player else { return completion([]) }
                let spuTracks = player.videoSubTitlesNames
                let spuTrackIndexes = player.videoSubTitlesIndexes

                var actions = [UIAction]()
                var subTitleIndex: Int?

                if let data = self.database.getVideo(metadata: metadata), let idx = data.currentVideoSubTitleIndex {
                    subTitleIndex = idx
                } else if let idx = ncplayer?.player.currentVideoSubTitleIndex {
                    subTitleIndex = Int(idx)
                }

                if !spuTracks.isEmpty {
                    for index in 0...spuTracks.count - 1 {
                        guard let title = spuTracks[index] as? String, let idx = spuTrackIndexes[index] as? Int32 else { return }

                        let action = makeTrackAction(title: title, index: idx, isSelected: (subTitleIndex ?? -9999) == idx)
                        actions.append(action)
                    }
                }

                completion(actions)
            }

            children.append(deferredElement)
        case .audio:
            let deferredElement = UIDeferredMenuElement.uncached { [self] completion in
                guard let player = ncplayer?.player else { return completion([]) }
                let audioTracks = player.audioTrackNames
                let audioTrackIndexes = player.audioTrackIndexes

                var actions = [UIAction]()
                var audioIndex: Int?

                if let data = self.database.getVideo(metadata: metadata), let idx = data.currentAudioTrackIndex {
                    audioIndex = idx
                } else if let idx = ncplayer?.player.currentAudioTrackIndex {
                    audioIndex = Int(idx)
                }

                if !audioTracks.isEmpty {
                    for index in 0...audioTracks.count - 1 {
                        guard let title = audioTracks[index] as? String, let idx = audioTrackIndexes[index] as? Int32 else { return }

                        let action = makeTrackAction(title: title, index: idx, isSelected: (audioIndex ?? -9999) == idx)
                        actions.append(action)
                    }
                }

                completion(actions)
            }

            children.append(deferredElement)
        }

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
