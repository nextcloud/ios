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

@objc class NCFile: NSObject {
    
    @objc var commentsUnread: Bool = false
    @objc var contentType = ""
    @objc var date = NSDate()
    @objc var directory: Bool = false
    @objc var e2eEncrypted: Bool = false
    @objc var etag = ""
    @objc var favorite: Bool = false
    @objc var fileId = ""
    @objc var fileName = ""
    @objc var hasPreview: Bool = false
    @objc var mountType = ""
    @objc var ocId = ""
    @objc var ownerId = ""
    @objc var ownerDisplayName = ""
    @objc var path = ""
    @objc var permissions = ""
    @objc var quotaUsedBytes: Double = 0
    @objc var quotaAvailableBytes: Double = 0
    @objc var resourceType = ""
    @objc var size: Double = 0
    @objc var trashbinFileName = ""
    @objc var trashbinOriginalLocation = ""
    @objc var trashbinDeletionTime = NSDate()
}

//MARK: -
