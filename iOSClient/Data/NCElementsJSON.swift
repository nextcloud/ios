//
//  NCElementsJSON.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 14/05/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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

import UIKit

@objc class NCElementsJSON: NSObject {
    @objc static let shared: NCElementsJSON = {
        let instance = NCElementsJSON()
        return instance
    }()

    @objc public let capabilitiesVersionString: Array = ["ocs", "data", "version", "string"]
    @objc public let capabilitiesVersionMajor: Array = ["ocs", "data", "version", "major"]

    @objc public let capabilitiesFileSharingApiEnabled: Array = ["ocs", "data", "capabilities", "files_sharing", "api_enabled"]
    @objc public let capabilitiesFileSharingPubPasswdEnforced: Array = ["ocs", "data", "capabilities", "files_sharing", "public", "password", "enforced"]
    @objc public let capabilitiesFileSharingPubExpireDateEnforced: Array = ["ocs", "data", "capabilities", "files_sharing", "public", "expire_date", "enforced"]
    @objc public let capabilitiesFileSharingPubExpireDateDays: Array = ["ocs", "data", "capabilities", "files_sharing", "public", "expire_date", "days"]
    @objc public let capabilitiesFileSharingInternalExpireDateEnforced: Array = ["ocs", "data", "capabilities", "files_sharing", "public", "expire_date_internal", "enforced"]
    @objc public let capabilitiesFileSharingInternalExpireDateDays: Array = ["ocs", "data", "capabilities", "files_sharing", "public", "expire_date_internal", "days"]
    @objc public let capabilitiesFileSharingRemoteExpireDateEnforced: Array = ["ocs", "data", "capabilities", "files_sharing", "public", "expire_date_remote", "enforced"]
    @objc public let capabilitiesFileSharingRemoteExpireDateDays: Array = ["ocs", "data", "capabilities", "files_sharing", "public", "expire_date_remote", "days"]
    @objc public let capabilitiesFileSharingDefaultPermissions: Array = ["ocs", "data", "capabilities", "files_sharing", "default_permissions"]
    @objc public let capabilitiesFileSharingSendPasswordMail: Array = ["ocs", "data", "capabilities", "files_sharing", "sharebymail", "send_password_by_mail"]

    @objc public let capabilitiesThemingColor: Array = ["ocs", "data", "capabilities", "theming", "color"]
    @objc public let capabilitiesThemingColorElement: Array = ["ocs", "data", "capabilities", "theming", "color-element"]
    @objc public let capabilitiesThemingColorText: Array = ["ocs", "data", "capabilities", "theming", "color-text"]
    @objc public let capabilitiesThemingName: Array = ["ocs", "data", "capabilities", "theming", "name"]
    @objc public let capabilitiesThemingSlogan: Array = ["ocs", "data", "capabilities", "theming", "slogan"]

    @objc public let capabilitiesWebDavRoot: Array = ["ocs", "data", "capabilities", "core", "webdav-root"]

    @objc public let capabilitiesE2EEEnabled: Array = ["ocs", "data", "capabilities", "end-to-end-encryption", "enabled"]
    @objc public let capabilitiesE2EEApiVersion: Array = ["ocs", "data", "capabilities", "end-to-end-encryption", "api-version"]

    @objc public let capabilitiesExternalSites: Array = ["ocs", "data", "capabilities", "external"]

    @objc public let capabilitiesRichdocumentsMimetypes: Array = ["ocs", "data", "capabilities", "richdocuments", "mimetypes"]

    @objc public let capabilitiesActivity: Array = ["ocs", "data", "capabilities", "activity", "apiv2"]

    @objc public let capabilitiesNotification: Array = ["ocs", "data", "capabilities", "notifications", "ocs-endpoints"]

    @objc public let capabilitiesFilesUndelete: Array = ["ocs", "data", "capabilities", "files", "undelete"]
    @objc public let capabilitiesFilesLockVersion: Array = ["ocs", "data", "capabilities", "files", "locking"] // NC 24
    @objc public let capabilitiesFilesComments: Array = ["ocs", "data", "capabilities", "files", "comments"] // NC 20

    @objc public let capabilitiesHWCEnabled: Array = ["ocs", "data", "capabilities", "handwerkcloud", "enabled"]

    @objc public let capabilitiesUserStatusEnabled: Array = ["ocs", "data", "capabilities", "user_status", "enabled"]
    @objc public let capabilitiesUserStatusSupportsEmoji: Array = ["ocs", "data", "capabilities", "user_status", "supports_emoji"]

    @objc public let capabilitiesGroupfoldersEnabled: Array = ["ocs", "data", "capabilities", "groupfolders", "hasGroupFolders"]
}
