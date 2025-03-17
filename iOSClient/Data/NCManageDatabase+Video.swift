//
//  NCManageDatabase+Video.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 15/03/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
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
    func addVideo(metadata: tableMetadata, position: Float? = nil, width: Int? = nil, height: Int? = nil, length: Int? = nil, currentAudioTrackIndex: Int? = nil, currentVideoSubTitleIndex: Int? = nil) {
        if metadata.isLivePhoto { return }

        do {
            let realm = try Realm()
            try realm.write {
                if let result = realm.objects(tableVideo.self).filter("account == %@ AND ocId == %@", metadata.account, metadata.ocId).first {
                    if let position = position {
                        result.position = position
                    }
                    if let width = width {
                        result.width = width
                    }
                    if let height = height {
                        result.height = height
                    }
                    if let length = length {
                        result.length = length
                    }
                    if let currentAudioTrackIndex = currentAudioTrackIndex {
                        result.currentAudioTrackIndex = currentAudioTrackIndex
                    }
                    if let currentVideoSubTitleIndex = currentVideoSubTitleIndex {
                        result.currentVideoSubTitleIndex = currentVideoSubTitleIndex
                    }
                    realm.add(result, update: .all)
                } else {
                    let result = tableVideo()
                    result.account = metadata.account
                    result.ocId = metadata.ocId
                    if let position = position {
                        result.position = position
                    }
                    if let width = width {
                        result.width = width
                    }
                    if let height = height {
                        result.height = height
                    }
                    if let length = length {
                        result.length = length
                    }
                    if let currentAudioTrackIndex = currentAudioTrackIndex {
                        result.currentAudioTrackIndex = currentAudioTrackIndex
                    }
                    if let currentVideoSubTitleIndex = currentVideoSubTitleIndex {
                        result.currentVideoSubTitleIndex = currentVideoSubTitleIndex
                    }
                    realm.add(result, update: .all)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func addVideoCodec(metadata: tableMetadata, codecNameVideo: String?, codecNameAudio: String?, codecAudioChannelLayout: String?, codecAudioLanguage: String?, codecMaxCompatibility: Bool, codecQuality: String?) {
        do {
            let realm = try Realm()
            try realm.write {
                if let result = realm.objects(tableVideo.self).filter("account == %@ AND ocId == %@", metadata.account, metadata.ocId).first {
                    if let codecNameVideo = codecNameVideo { result.codecNameVideo = codecNameVideo }
                    if let codecNameAudio = codecNameAudio { result.codecNameAudio = codecNameAudio }
                    if let codecAudioChannelLayout = codecAudioChannelLayout { result.codecAudioChannelLayout = codecAudioChannelLayout }
                    if let codecAudioLanguage = codecAudioLanguage { result.codecAudioLanguage = codecAudioLanguage }
                    result.codecMaxCompatibility = codecMaxCompatibility
                    if let codecQuality = codecQuality { result.codecQuality = codecQuality }
                    realm.add(result, update: .all)
                } else {
                    let addObject = tableVideo()
                    addObject.account = metadata.account
                    addObject.ocId = metadata.ocId
                    addObject.codecNameVideo = codecNameVideo
                    addObject.codecNameAudio = codecNameAudio
                    addObject.codecAudioChannelLayout = codecAudioChannelLayout
                    addObject.codecAudioLanguage = codecAudioLanguage
                    addObject.codecMaxCompatibility = codecMaxCompatibility
                    addObject.codecQuality = codecQuality
                    realm.add(addObject, update: .all)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func getVideo(metadata: tableMetadata?) -> tableVideo? {
        guard let metadata = metadata else { return nil }

        do {
            let realm = try Realm()
            guard let result = realm.objects(tableVideo.self).filter("account == %@ AND ocId == %@", metadata.account, metadata.ocId).first else { return nil }
            return tableVideo.init(value: result)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func deleteVideo(metadata: tableMetadata) {
        do {
            let realm = try Realm()
            try realm.write {
                if let result = realm.objects(tableVideo.self).filter("account == %@ AND ocId == %@", metadata.account, metadata.ocId).first {
                    realm.delete(result)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }
}
