//
//  NCDatabase.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/05/17.
//  Copyright © 2017 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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
import RealmSwift
import NextcloudKit

protocol DateCompareable {
    var dateKey: Date { get }
}

class tableAvatar: Object {

    @objc dynamic var date = NSDate()
    @objc dynamic var etag = ""
    @objc dynamic var fileName = ""
    @objc dynamic var loaded: Bool = false

    override static func primaryKey() -> String {
        return "fileName"
    }
}

class tableCapabilities: Object {

    @objc dynamic var account = ""
    @objc dynamic var jsondata: Data?

    override static func primaryKey() -> String {
        return "account"
    }
}

class tableChunk: Object {

    @objc dynamic var account = ""
    @objc dynamic var chunkFolder = ""
    @objc dynamic var fileName = ""
    @objc dynamic var index = ""
    @objc dynamic var ocId = ""
    @objc dynamic var size: Int64 = 0

    override static func primaryKey() -> String {
        return "index"
    }
}

class tableComments: Object, DateCompareable {
    var dateKey: Date { creationDateTime as Date }

    @objc dynamic var account = ""
    @objc dynamic var actorDisplayName = ""
    @objc dynamic var actorId = ""
    @objc dynamic var actorType = ""
    @objc dynamic var creationDateTime = NSDate()
    @objc dynamic var isUnread: Bool = false
    @objc dynamic var message = ""
    @objc dynamic var messageId = ""
    @objc dynamic var objectId = ""
    @objc dynamic var objectType = ""
    @objc dynamic var path = ""
    @objc dynamic var verb = ""

    override static func primaryKey() -> String {
        return "messageId"
    }
}

class tableDirectEditingCreators: Object {

    @objc dynamic var account = ""
    @objc dynamic var editor = ""
    @objc dynamic var ext = ""
    @objc dynamic var identifier = ""
    @objc dynamic var mimetype = ""
    @objc dynamic var name = ""
    @objc dynamic var templates: Int = 0
}

class tableDirectEditingEditors: Object {

    @objc dynamic var account = ""
    @objc dynamic var editor = ""
    let mimetypes = List<String>()
    @objc dynamic var name = ""
    let optionalMimetypes = List<String>()
    @objc dynamic var secure: Int = 0
}

class tableE2eEncryption: Object {

    @objc dynamic var account = ""
    @objc dynamic var authenticationTag: String?
    @objc dynamic var fileName = ""
    @objc dynamic var fileNameIdentifier = ""
    @objc dynamic var fileNamePath = ""
    @objc dynamic var key = ""
    @objc dynamic var initializationVector = ""
    @objc dynamic var metadataKey = ""
    @objc dynamic var metadataKeyIndex: Int = 0
    @objc dynamic var mimeType = ""
    @objc dynamic var serverUrl = ""
    @objc dynamic var version: Int = 1

    override static func primaryKey() -> String {
        return "fileNamePath"
    }
}

class tableE2eEncryptionLock: Object {

    @objc dynamic var account = ""
    @objc dynamic var date = NSDate()
    @objc dynamic var fileId = ""
    @objc dynamic var serverUrl = ""
    @objc dynamic var e2eToken = ""

    override static func primaryKey() -> String {
        return "fileId"
    }
}

class tableExternalSites: Object {

    @objc dynamic var account = ""
    @objc dynamic var icon = ""
    @objc dynamic var idExternalSite: Int = 0
    @objc dynamic var lang = ""
    @objc dynamic var name = ""
    @objc dynamic var type = ""
    @objc dynamic var url = ""
}

class tableGPS: Object {

    @objc dynamic var latitude = ""
    @objc dynamic var location = ""
    @objc dynamic var longitude = ""
    @objc dynamic var placemarkAdministrativeArea = ""
    @objc dynamic var placemarkCountry = ""
    @objc dynamic var placemarkLocality = ""
    @objc dynamic var placemarkPostalCode = ""
    @objc dynamic var placemarkThoroughfare = ""
}

class tableLocalFile: Object {

    @objc dynamic var account = ""
    @objc dynamic var etag = ""
    @objc dynamic var exifDate: NSDate?
    @objc dynamic var exifLatitude = ""
    @objc dynamic var exifLongitude = ""
    @objc dynamic var exifLensModel: String?
    @objc dynamic var favorite: Bool = false
    @objc dynamic var fileName = ""
    @objc dynamic var ocId = ""
    @objc dynamic var offline: Bool = false

    override static func primaryKey() -> String {
        return "ocId"
    }
}

class tablePhotoLibrary: Object {

    @objc dynamic var account = ""
    @objc dynamic var assetLocalIdentifier = ""
    @objc dynamic var creationDate: NSDate?
    @objc dynamic var idAsset = ""
    @objc dynamic var modificationDate: NSDate?
    @objc dynamic var mediaType: Int = 0

    override static func primaryKey() -> String {
        return "idAsset"
    }
}

typealias tableShare = tableShareV2
class tableShareV2: Object {

    @objc dynamic var account = ""
    @objc dynamic var canEdit: Bool = false
    @objc dynamic var canDelete: Bool = false
    @objc dynamic var date: NSDate?
    @objc dynamic var displaynameFileOwner = ""
    @objc dynamic var displaynameOwner = ""
    @objc dynamic var expirationDate: NSDate?
    @objc dynamic var fileName = ""
    @objc dynamic var fileParent: Int = 0
    @objc dynamic var fileSource: Int = 0
    @objc dynamic var fileTarget = ""
    @objc dynamic var hideDownload: Bool = false
    @objc dynamic var idShare: Int = 0
    @objc dynamic var itemSource: Int = 0
    @objc dynamic var itemType = ""
    @objc dynamic var label = ""
    @objc dynamic var mailSend: Bool = false
    @objc dynamic var mimeType = ""
    @objc dynamic var note = ""
    @objc dynamic var parent: String = ""
    @objc dynamic var password: String = ""
    @objc dynamic var path = ""
    @objc dynamic var permissions: Int = 0
    @objc dynamic var primaryKey = ""
    @objc dynamic var sendPasswordByTalk: Bool = false
    @objc dynamic var serverUrl = ""
    @objc dynamic var shareType: Int = 0
    @objc dynamic var shareWith = ""
    @objc dynamic var shareWithDisplayname = ""
    @objc dynamic var storage: Int = 0
    @objc dynamic var storageId = ""
    @objc dynamic var token = ""
    @objc dynamic var uidFileOwner = ""
    @objc dynamic var uidOwner = ""
    @objc dynamic var url = ""
    @objc dynamic var userClearAt: NSDate?
    @objc dynamic var userIcon = ""
    @objc dynamic var userMessage = ""
    @objc dynamic var userStatus = ""

    override static func primaryKey() -> String {
        return "primaryKey"
    }
}

class tableTag: Object {

    @objc dynamic var account = ""
    @objc dynamic var ocId = ""
    @objc dynamic var tagIOS: Data?

    override static func primaryKey() -> String {
        return "ocId"
    }
}

class tableTip: Object {

    @Persisted(primaryKey: true) var tipName = ""
}

class tableTrash: Object {

    @objc dynamic var account = ""
    @objc dynamic var classFile = ""
    @objc dynamic var contentType = ""
    @objc dynamic var date = NSDate()
    @objc dynamic var directory: Bool = false
    @objc dynamic var fileId = ""
    @objc dynamic var fileName = ""
    @objc dynamic var filePath = ""
    @objc dynamic var hasPreview: Bool = false
    @objc dynamic var iconName = ""
    @objc dynamic var size: Int64 = 0
    @objc dynamic var trashbinFileName = ""
    @objc dynamic var trashbinOriginalLocation = ""
    @objc dynamic var trashbinDeletionTime = NSDate()

    override static func primaryKey() -> String {
        return "fileId"
    }
}

class tableUserStatus: Object {

    @objc dynamic var account = ""
    @objc dynamic var clearAt: NSDate?
    @objc dynamic var clearAtTime: String?
    @objc dynamic var clearAtType: String?
    @objc dynamic var icon: String?
    @objc dynamic var id: String?
    @objc dynamic var message: String?
    @objc dynamic var predefined: Bool = false
    @objc dynamic var status: String?
    @objc dynamic var userId: String?
}
