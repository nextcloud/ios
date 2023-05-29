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
