// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

typealias tableVideo = tableVideoV4
class tableVideoV4: Object {
    @Persisted var account = ""
    @Persisted(primaryKey: true) var ocId = ""
    @Persisted var position: Float?
    @Persisted var width: Int?
    @Persisted var height: Int?
    @Persisted var length: Int?
    @Persisted var codecNameVideo: String?
    @Persisted var codecNameAudio: String?
    @Persisted var codecAudioChannelLayout: String?
    @Persisted var codecAudioLanguage: String?
    @Persisted var codecMaxCompatibility: Bool = false
    @Persisted var codecQuality: String?
    @Persisted var currentAudioTrackIndex: Int?
    @Persisted var currentVideoSubTitleIndex: Int?
}

extension NCManageDatabase {

    // MARK: - Realm write

    func addVideo(metadata: tableMetadata, position: Float? = nil, width: Int? = nil, height: Int? = nil, length: Int? = nil, currentAudioTrackIndex: Int? = nil, currentVideoSubTitleIndex: Int? = nil) {
        if metadata.isLivePhoto { return }

        performRealmWrite { realm in
            if let result = realm.objects(tableVideo.self).filter("account == %@ AND ocId == %@", metadata.account, metadata.ocId).first {
                if let position {
                    result.position = position
                }
                if let width {
                    result.width = width
                }
                if let height {
                    result.height = height
                }
                if let length {
                    result.length = length
                }
                if let currentAudioTrackIndex {
                    result.currentAudioTrackIndex = currentAudioTrackIndex
                }
                if let currentVideoSubTitleIndex {
                    result.currentVideoSubTitleIndex = currentVideoSubTitleIndex
                }
                realm.add(result, update: .all)
            } else {
                let video = tableVideo()

                video.account = metadata.account
                video.ocId = metadata.ocId
                if let position {
                    video.position = position
                }
                if let width {
                    video.width = width
                }
                if let height {
                    video.height = height
                }
                if let length {
                    video.length = length
                }
                if let currentAudioTrackIndex {
                    video.currentAudioTrackIndex = currentAudioTrackIndex
                }
                if let currentVideoSubTitleIndex {
                    video.currentVideoSubTitleIndex = currentVideoSubTitleIndex
                }
                realm.add(video, update: .all)
            }
        }
    }

    func deleteVideo(metadata: tableMetadata) {
        performRealmWrite { realm in
            if let result = realm.objects(tableVideo.self)
                .filter("account == %@ AND ocId == %@", metadata.account, metadata.ocId)
                .first {
                realm.delete(result)
            }
        }
    }

    // MARK: - Realm read

    func getVideo(metadata: tableMetadata?) -> tableVideo? {
        guard let metadata else { return nil }

        return performRealmRead { realm in
            realm.objects(tableVideo.self)
                .filter("account == %@ AND ocId == %@", metadata.account, metadata.ocId)
                .first
                .map { tableVideo(value: $0) }
        }
    }
}
