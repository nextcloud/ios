//
//  NCCommunicationModel.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 12/10/19.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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

//MARK: - File

@objc public class NCFile: NSObject {
    
    @objc public var commentsUnread: Bool = false
    @objc public var contentType = ""
    @objc public var date = NSDate()
    @objc public var directory: Bool = false
    @objc public var e2eEncrypted: Bool = false
    @objc public var etag = ""
    @objc public var favorite: Bool = false
    @objc public var fileId = ""
    @objc public var fileName = ""
    @objc public var hasPreview: Bool = false
    @objc public var mountType = ""
    @objc public var ocId = ""
    @objc public var ownerId = ""
    @objc public var ownerDisplayName = ""
    @objc public var path = ""
    @objc public var permissions = ""
    @objc public var quotaUsedBytes: Double = 0
    @objc public var quotaAvailableBytes: Double = 0
    @objc public var resourceType = ""
    @objc public var size: Double = 0
    @objc public var trashbinFileName = ""
    @objc public var trashbinOriginalLocation = ""
    @objc public var trashbinDeletionTime = NSDate()
}

@objc public class NCExternalFile: NSObject {
    
    @objc public var idExternalSite: Int = 0
    @objc public var name = ""
    @objc public var url = ""
    @objc public var lang = ""
    @objc public var icon = ""
    @objc public var type = ""
}




