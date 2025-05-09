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
            let video = realm.objects(tableVideo.self)
                .filter("account == %@ AND ocId == %@", metadata.account, metadata.ocId)
                .first ?? tableVideo()

            video.account = metadata.account
            video.ocId = metadata.ocId
            position.map { video.position = $0 }
            width.map { video.width = $0 }
            height.map { video.height = $0 }
            length.map { video.length = $0 }
            currentAudioTrackIndex.map { video.currentAudioTrackIndex = $0 }
            currentVideoSubTitleIndex.map { video.currentVideoSubTitleIndex = $0 }

            realm.add(video, update: .all)
        }
    }

    func addVideoCodec(metadata: tableMetadata, codecNameVideo: String?, codecNameAudio: String?, codecAudioChannelLayout: String?, codecAudioLanguage: String?, codecMaxCompatibility: Bool, codecQuality: String?) {
        performRealmWrite { realm in
           let video = realm.objects(tableVideo.self)
               .filter("account == %@ AND ocId == %@", metadata.account, metadata.ocId)
               .first ?? {
                   let new = tableVideo()
                   new.account = metadata.account
                   new.ocId = metadata.ocId
                   return new
               }()

           codecNameVideo.map { video.codecNameVideo = $0 }
           codecNameAudio.map { video.codecNameAudio = $0 }
           codecAudioChannelLayout.map { video.codecAudioChannelLayout = $0 }
           codecAudioLanguage.map { video.codecAudioLanguage = $0 }
           codecQuality.map { video.codecQuality = $0 }

           video.codecMaxCompatibility = codecMaxCompatibility
           realm.add(video, update: .all)
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
