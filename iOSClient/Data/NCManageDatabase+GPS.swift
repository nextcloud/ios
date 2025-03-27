//
//  NCManageDatabase+GPS.swift
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
import RealmSwift
import NextcloudKit

typealias tableGPS = tableGPSV2
class tableGPSV2: Object {
    @objc dynamic var latitude: Double = 0
    @objc dynamic var longitude: Double = 0
    @objc dynamic var location = ""
}

extension NCManageDatabase {
    func addGeocoderLocation(_ location: String, latitude: Double, longitude: Double) {
        do {
            let realm = try Realm()
            guard realm.objects(tableGPS.self).filter("latitude == %@ AND longitude == %@", latitude, longitude).first == nil else { return }
            try realm.write {
                let addObject = tableGPS()
                addObject.latitude = latitude
                addObject.location = location
                addObject.longitude = longitude
                realm.add(addObject)
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func getLocationFromLatAndLong(latitude: Double, longitude: Double) -> String? {
        do {
            let realm = try Realm()
            let result = realm.objects(tableGPS.self).filter("latitude == %@ AND longitude == %@", latitude, longitude).first
            return result?.location
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access to database: \(error)")
        }
        return nil
    }
}
