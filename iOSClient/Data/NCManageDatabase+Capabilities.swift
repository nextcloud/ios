//
//  NCManageDatabase+Capabilities.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 29/05/23.
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
import SwiftyJSON

class tableCapabilities: Object {

    @objc dynamic var account = ""
    @objc dynamic var jsondata: Data?

    override static func primaryKey() -> String {
        return "account"
    }
}

extension NCManageDatabase {

    func addCapabilitiesJSon(_ data: Data, account: String) {

        let realm = try! Realm()

        do {
            try realm.write {
                let addObject = tableCapabilities()

                addObject.account = account
                addObject.jsondata = data

                realm.add(addObject, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("Could not write to database: \(error)")
        }
    }

    func getCapabilities(account: String) -> String? {

        let realm = try! Realm()

        guard let result = realm.objects(tableCapabilities.self).filter("account == %@", account).first else {
            return nil
        }
        guard let jsondata = result.jsondata else {
            return nil
        }

        let json = JSON(jsondata)

        return json.rawString()?.replacingOccurrences(of: "\\/", with: "/")
    }

    @objc func getCapabilitiesServerString(account: String, elements: [String]) -> String? {

        let realm = try! Realm()

        guard let result = realm.objects(tableCapabilities.self).filter("account == %@", account).first else {
            return nil
        }
        guard let jsondata = result.jsondata else {
            return nil
        }

        let json = JSON(jsondata)
        return json[elements].string
    }

    func getCapabilitiesServerInt(account: String, elements: [String]) -> Int {

        let realm = try! Realm()

        guard let result = realm.objects(tableCapabilities.self).filter("account == %@", account).first,
              let jsondata = result.jsondata else {
            return 0
        }

        let json = JSON(jsondata)
        return json[elements].intValue
    }

    @objc func getCapabilitiesServerBool(account: String, elements: [String], exists: Bool) -> Bool {

        let realm = try! Realm()

        guard let result = realm.objects(tableCapabilities.self).filter("account == %@", account).first else {
            return false
        }
        guard let jsondata = result.jsondata else {
            return false
        }

        let json = JSON(jsondata)
        if exists {
            return json[elements].exists()
        } else {
            return json[elements].boolValue
        }
    }

    func getCapabilitiesServerArray(account: String, elements: [String]) -> [String]? {

        let realm = try! Realm()
        var resultArray: [String] = []

        guard let result = realm.objects(tableCapabilities.self).filter("account == %@", account).first else {
            return nil
        }
        guard let jsondata = result.jsondata else {
            return nil
        }

        let json = JSON(jsondata)

        if let results = json[elements].array {
            for result in results {
                resultArray.append(result.string ?? "")
            }
            return resultArray
        }

        return nil
    }
}
