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

    func getCapabilities(account: String) -> Data? {

        let realm = try! Realm()

        guard let result = realm.objects(tableCapabilities.self).filter("account == %@", account).first else {
            return nil
        }

        return result.jsondata
    }

    func setCapabilities(account: String, data: Data? = nil) {

        let realm = try! Realm()
        let json: JSON?

        if let data = data {
            json = JSON(data)
        } else {
            guard let result = realm.objects(tableCapabilities.self).filter("account == %@", account).first,
                  let data = result.jsondata else {
                return
            }
            json = JSON(data)
        }

        guard let json = json else { return }

        NCGlobal.shared.capabilityServerVersion = json["ocs", "data", "version", "string"].stringValue
        NCGlobal.shared.capabilityServerVersionMajor = json["ocs", "data", "version", "major"].intValue

        NCGlobal.shared.capabilityFileSharingApiEnabled = json["ocs", "data", "capabilities", "files_sharing", "api_enabled"].boolValue
        NCGlobal.shared.capabilityFileSharingPubPasswdEnforced = json["ocs", "data", "capabilities", "files_sharing", "public", "password", "enforced"].boolValue
        NCGlobal.shared.capabilityFileSharingPubExpireDateEnforced = json["ocs", "data", "capabilities", "files_sharing", "public", "expire_date", "enforced"].boolValue
        NCGlobal.shared.capabilityFileSharingPubExpireDateDays = json["ocs", "data", "capabilities", "files_sharing", "public", "expire_date", "days"].intValue
        NCGlobal.shared.capabilityFileSharingInternalExpireDateEnforced = json["ocs", "data", "capabilities", "files_sharing", "public", "expire_date_internal", "enforced"].boolValue
        NCGlobal.shared.capabilityFileSharingInternalExpireDateDays = json["ocs", "data", "capabilities", "files_sharing", "public", "expire_date_internal", "days"].intValue
        NCGlobal.shared.capabilityFileSharingRemoteExpireDateEnforced = json["ocs", "data", "capabilities", "files_sharing", "public", "expire_date_remote", "enforced"].boolValue
        NCGlobal.shared.capabilityFileSharingRemoteExpireDateDays = json["ocs", "data", "capabilities", "files_sharing", "public", "expire_date_remote", "days"].intValue
        NCGlobal.shared.capabilityFileSharingDefaultPermission = json["ocs", "data", "capabilities", "files_sharing", "default_permissions"].intValue

        NCGlobal.shared.capabilityThemingColor = json["ocs", "data", "capabilities", "theming", "color"].stringValue
        NCGlobal.shared.capabilityThemingColorElement = json["ocs", "data", "capabilities", "theming", "color-element"].stringValue
        NCGlobal.shared.capabilityThemingColorText = json["ocs", "data", "capabilities", "theming", "color-text"].stringValue
        NCGlobal.shared.capabilityThemingName = json["ocs", "data", "capabilities", "theming", "name"].stringValue
        NCGlobal.shared.capabilityThemingSlogan = json["ocs", "data", "capabilities", "theming", "slogan"].stringValue

        NCGlobal.shared.capabilityE2EEEnabled = json["ocs", "data", "capabilities", "end-to-end-encryption", "enabled"].boolValue
        NCGlobal.shared.capabilityE2EEApiVersion = json["ocs", "data", "capabilities", "end-to-end-encryption", "api-version"].stringValue


        NCGlobal.shared.capabilityRichdocumentsMimetypes.removeAll()
        let mimetypes = json["ocs", "data", "capabilities", "richdocuments", "mimetypes"].arrayValue
        for mimetype in mimetypes {
            NCGlobal.shared.capabilityRichdocumentsMimetypes.append(mimetype.stringValue)
        }

        NCGlobal.shared.capabilityActivity.removeAll()
        let activities = json["ocs", "data", "capabilities", "activity", "apiv2"].arrayValue
        for activity in activities {
            NCGlobal.shared.capabilityActivity.append(activity.stringValue)
        }

        NCGlobal.shared.capabilityNotification.removeAll()
        let notifications = json["ocs", "data", "capabilities", "notifications", "ocs-endpoints"].arrayValue
        for notify in notifications {
            NCGlobal.shared.capabilityNotification.append(notify.stringValue)
        }

        NCGlobal.shared.capabilityFilesUndelete = json["ocs", "data", "capabilities", "files", "undelete"].boolValue
        NCGlobal.shared.capabilityFilesLockVersion = json["ocs", "data", "capabilities", "files", "locking"].stringValue
        NCGlobal.shared.capabilityFilesComments = json["ocs", "data", "capabilities", "files", "comments"].boolValue

        NCGlobal.shared.capabilityUserStatusEnabled = json["ocs", "data", "capabilities", "user_status", "enabled"].boolValue
        NCGlobal.shared.capabilityExternalSites = json["ocs", "data", "capabilities", "external"].exists()
        NCGlobal.shared.capabilityGroupfoldersEnabled = json["ocs", "data", "capabilities", "groupfolders", "hasGroupFolders"].boolValue
    }
}
