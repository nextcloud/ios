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
import RealmSwift
import NextcloudKit

class tableVideo: Object {

    @objc dynamic var account = ""
    @objc dynamic var ocId = ""
    @objc dynamic var position: Float = 0
    @objc dynamic var codecNameVideo: String?
    @objc dynamic var codecNameAudio: String?
    @objc dynamic var codecAudioChannelLayout: String?
    @objc dynamic var codecAudioLanguage: String?
    @objc dynamic var codecMaxCompatibility: Bool = false
    @objc dynamic var codecQuality: String?

    override static func primaryKey() -> String {
        return "ocId"
    }
}

extension NCManageDatabase {

    func addVideo(metadata: tableMetadata, position: Float) {

        if metadata.livePhoto { return }
        let realm = try! Realm()

        do {
            try realm.write {
                if let result = realm.objects(tableVideo.self).filter("account == %@ AND ocId == %@", metadata.account, metadata.ocId).first {

                    result.position = position
                    realm.add(result, update: .all)

                } else {

                    let addObject = tableVideo()

                    addObject.account = metadata.account
                    addObject.ocId = metadata.ocId
                    addObject.position = position
                    realm.add(addObject, update: .all)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func addVideoCodec(metadata: tableMetadata, codecNameVideo: String?, codecNameAudio: String?, codecAudioChannelLayout: String?, codecAudioLanguage: String?, codecMaxCompatibility: Bool, codecQuality: String?) {

        let realm = try! Realm()

        do {
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
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func getVideo(metadata: tableMetadata?) -> tableVideo? {
        guard let metadata = metadata else { return nil }

        let realm = try! Realm()
        guard let result = realm.objects(tableVideo.self).filter("account == %@ AND ocId == %@", metadata.account, metadata.ocId).first else {
            return nil
        }

        return tableVideo.init(value: result)
    }

    func getVideoPosition(metadata: tableMetadata) -> Float? {

        if metadata.livePhoto { return nil }
        let realm = try! Realm()

        guard let result = realm.objects(tableVideo.self).filter("account == %@ AND ocId == %@", metadata.account, metadata.ocId).first else {
            return nil
        }

        if result.position == 0 { return nil }
        return result.position
    }

    func deleteVideo(metadata: tableMetadata) {

        let realm = try! Realm()

        do {
            try realm.write {
                let result = realm.objects(tableVideo.self).filter("account == %@ AND ocId == %@", metadata.account, metadata.ocId)
                realm.delete(result)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }
}
