//
//  NCManageDatabase+PhotoLibrary.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 13/11/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
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
import Photos
import RealmSwift
import NextcloudKit

class tablePhotoLibrary: Object {
    @objc dynamic var account = ""
    @objc dynamic var assetLocalIdentifier = ""
    @objc dynamic var creationDate: NSDate?
    @objc dynamic var idAsset = ""
    @objc dynamic var modificationDate: NSDate?
    @objc dynamic var mediaType: Int = 0

    override static func primaryKey() -> String {
        return "idAsset"
    }
}

extension NCManageDatabase {
    @discardableResult
    func addPhotoLibrary(_ assets: [PHAsset], account: String) -> Bool {
        do {
            let realm = try Realm()
            try realm.write {
                for asset in assets {
                    var creationDateString = ""
                    let addObject = tablePhotoLibrary()
                    addObject.account = account
                    addObject.assetLocalIdentifier = asset.localIdentifier
                    addObject.mediaType = asset.mediaType.rawValue
                    if let creationDate = asset.creationDate {
                        addObject.creationDate = creationDate as NSDate
                        creationDateString = String(describing: creationDate)
                    }
                    if let modificationDate = asset.modificationDate {
                        addObject.modificationDate = modificationDate as NSDate
                    }
                    addObject.idAsset = account + asset.localIdentifier + creationDateString
                    realm.add(addObject, update: .all)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
            return false
        }
        return true
    }

    func getPhotoLibraryIdAsset(image: Bool, video: Bool, account: String) -> [String]? {
        var predicate = NSPredicate()

        if image && video {
            predicate = NSPredicate(format: "account == %@ AND (mediaType == %d OR mediaType == %d)", account, PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        } else if image {
            predicate = NSPredicate(format: "account == %@ AND mediaType == %d", account, PHAssetMediaType.image.rawValue)
        } else if video {
            predicate = NSPredicate(format: "account == %@ AND mediaType == %d", account, PHAssetMediaType.video.rawValue)
        }

        do {
            let realm = try Realm()
            let results = realm.objects(tablePhotoLibrary.self).filter(predicate)
            let idsAsset = results.map { $0.idAsset }
            return Array(idsAsset)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access to database: \(error)")
        }
        return nil
    }
}
