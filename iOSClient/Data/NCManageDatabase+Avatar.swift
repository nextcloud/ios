//
//  NCManageDatabase+Avatar.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 20/01/23.
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
import RealmSwift
import NextcloudKit

class tableAvatar: Object {

    @objc dynamic var date = NSDate()
    @objc dynamic var etag = ""
    @objc dynamic var fileName = ""
    @objc dynamic var loaded: Bool = false

    override static func primaryKey() -> String {
        return "fileName"
    }
}

extension NCManageDatabase {

    func addAvatar(fileName: String, etag: String) {

        let realm = try! Realm()

        do {
            try realm.write {

                // Add new
                let addObject = tableAvatar()

                addObject.date = NSDate()
                addObject.etag = etag
                addObject.fileName = fileName
                addObject.loaded = true

                realm.add(addObject, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func getTableAvatar(fileName: String) -> tableAvatar? {

        let realm = try! Realm()

        guard let result = realm.objects(tableAvatar.self).filter("fileName == %@", fileName).first else {
            return nil
        }

        return tableAvatar.init(value: result)
    }

    func clearAllAvatarLoaded() {

        let realm = try! Realm()

        do {
            try realm.write {

                let results = realm.objects(tableAvatar.self)
                for result in results {
                    result.loaded = false
                    realm.add(result, update: .all)
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    @discardableResult
    func setAvatarLoaded(fileName: String) -> UIImage? {

        let realm = try! Realm()
        let fileNameLocalPath = String(CCUtility.getDirectoryUserData()) + "/" + fileName
        var image: UIImage?

        do {
            try realm.write {
                if let result = realm.objects(tableAvatar.self).filter("fileName == %@", fileName).first {
                    if let imageAvatar = UIImage(contentsOfFile: fileNameLocalPath) {
                        result.loaded = true
                        image = imageAvatar
                    } else {
                        realm.delete(result)
                    }
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }

        return image
    }

    func getImageAvatarLoaded(fileName: String) -> UIImage? {

        let realm = try! Realm()
        let fileNameLocalPath = String(CCUtility.getDirectoryUserData()) + "/" + fileName

        let result = realm.objects(tableAvatar.self).filter("fileName == %@", fileName).first
        if result == nil {
            NCUtilityFileSystem.shared.deleteFile(filePath: fileNameLocalPath)
            return nil
        } else if result?.loaded == false {
            return nil
        }

        return UIImage(contentsOfFile: fileNameLocalPath)
    }

}
