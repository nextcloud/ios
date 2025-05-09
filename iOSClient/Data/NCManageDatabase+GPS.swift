// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

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

    // MARK: - Realm write

    func addGeocoderLocation(_ location: String, latitude: Double, longitude: Double) {
        performRealmWrite { realm in
            guard realm.objects(tableGPS.self)
                .filter("latitude == %@ AND longitude == %@", latitude, longitude)
                .first == nil
            else {
                return
            }

            let addObject = tableGPS()
            addObject.latitude = latitude
            addObject.longitude = longitude
            addObject.location = location
            realm.add(addObject)
        }
    }

    // MARK: - Realm read

    func getLocationFromLatAndLong(latitude: Double, longitude: Double) -> String? {
        performRealmRead { realm in
            realm.objects(tableGPS.self)
                .filter("latitude == %@ AND longitude == %@", latitude, longitude)
                .first?.location
        }
    }
}
