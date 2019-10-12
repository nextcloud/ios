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


@objc class NCFile: NSObject {
    private override init() {}
    
    let commentsUnread: Bool = false
    let contentType = ""
    let creationDate = NSDate()
    let date = NSDate()
    let directory: Bool = false
    let displayName = ""
    let encrypted: Bool = false
    let etag = ""
    let favorite: Bool = false
    let fileId = ""
    let fileName = ""
    let hasPreview: Bool = false
    let mountType = ""
    let ocId = ""
    let ownerId = ""
    let ownerDisplayName = ""
    let path = ""
    let permissions = ""
    let quotaUsedBytes: Double = 0
    let quotaAvailableBytes: Double = 0
    let resourceType = ""
    let size: Double = 0
    let trashbinFileName = ""
    let trashbinOriginalLocation = ""
    let trashbinDeletionTime = NSDate()
}
