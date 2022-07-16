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
import NCCommunication

protocol DateCompareable {
    var dateKey: Date { get }
}

class tableAccount: Object, NCUserBaseUrl {

    @objc dynamic var account = ""
    @objc dynamic var active: Bool = false
    @objc dynamic var address = ""
    @objc dynamic var alias = ""
    @objc dynamic var autoUpload: Bool = false
    @objc dynamic var autoUploadCreateSubfolder: Bool = false
    @objc dynamic var autoUploadDirectory = ""
    @objc dynamic var autoUploadFileName = ""
    @objc dynamic var autoUploadFull: Bool = false
    @objc dynamic var autoUploadImage: Bool = false
    @objc dynamic var autoUploadVideo: Bool = false
    @objc dynamic var autoUploadWWAnPhoto: Bool = false
    @objc dynamic var autoUploadWWAnVideo: Bool = false
    @objc dynamic var backend = ""
    @objc dynamic var backendCapabilitiesSetDisplayName: Bool = false
    @objc dynamic var backendCapabilitiesSetPassword: Bool = false
    @objc dynamic var businessSize: String = ""
    @objc dynamic var businessType = ""
    @objc dynamic var city = ""
    @objc dynamic var country = ""
    @objc dynamic var displayName = ""
    @objc dynamic var email = ""
    @objc dynamic var enabled: Bool = false
    @objc dynamic var groups = ""
    @objc dynamic var language = ""
    @objc dynamic var lastLogin: Int64 = 0
    @objc dynamic var locale = ""
    @objc dynamic var mediaPath = ""
    @objc dynamic var organisation = ""
    @objc dynamic var password = ""
    @objc dynamic var phone = ""
    @objc dynamic var quota: Int64 = 0
    @objc dynamic var quotaFree: Int64 = 0
    @objc dynamic var quotaRelative: Double = 0
    @objc dynamic var quotaTotal: Int64 = 0
    @objc dynamic var quotaUsed: Int64 = 0
    @objc dynamic var role = ""
    @objc dynamic var storageLocation = ""
    @objc dynamic var subadmin = ""
    @objc dynamic var twitter = ""
    @objc dynamic var urlBase = ""
    @objc dynamic var user = ""
    @objc dynamic var userId = ""
    @objc dynamic var userStatusClearAt: NSDate?
    @objc dynamic var userStatusIcon: String?
    @objc dynamic var userStatusMessage: String?
    @objc dynamic var userStatusMessageId: String?
    @objc dynamic var userStatusMessageIsPredefined: Bool = false
    @objc dynamic var userStatusStatus: String?
    @objc dynamic var userStatusStatusIsUserDefined: Bool = false
    @objc dynamic var website = ""
    @objc dynamic var zip = ""

    // COLOR Files
    @objc dynamic var darkColorBackground = ""
    @objc dynamic var lightColorBackground = ""

    // HC
    @objc dynamic var hcIsTrial: Bool = false
    @objc dynamic var hcTrialExpired: Bool = false
    @objc dynamic var hcTrialRemainingSec: Int64 = 0
    @objc dynamic var hcTrialEndTime: NSDate?
    @objc dynamic var hcAccountRemoveExpired: Bool = false
    @objc dynamic var hcAccountRemoveRemainingSec: Int64 = 0
    @objc dynamic var hcAccountRemoveTime: NSDate?
    @objc dynamic var hcNextGroupExpirationGroup = ""
    @objc dynamic var hcNextGroupExpirationGroupExpired: Bool = false
    @objc dynamic var hcNextGroupExpirationExpiresTime: NSDate?
    @objc dynamic var hcNextGroupExpirationExpires = ""

    override static func primaryKey() -> String {
        return "account"
    }
}

class tableActivity: Object, DateCompareable {
    var dateKey: Date { date as Date }

    @objc dynamic var account = ""
    @objc dynamic var idPrimaryKey = ""
    @objc dynamic var action = "Activity"
    @objc dynamic var date = NSDate()
    @objc dynamic var idActivity: Int = 0
    @objc dynamic var app = ""
    @objc dynamic var type = ""
    @objc dynamic var user = ""
    @objc dynamic var subject = ""
    @objc dynamic var subjectRich = ""
    let subjectRichItem = List<tableActivitySubjectRich>()
    @objc dynamic var icon = ""
    @objc dynamic var link = ""
    @objc dynamic var message = ""
    @objc dynamic var objectType = ""
    @objc dynamic var objectId: Int = 0
    @objc dynamic var objectName = ""
    @objc dynamic var note = ""
    @objc dynamic var selector = ""
    @objc dynamic var verbose: Bool = false

    override static func primaryKey() -> String {
        return "idPrimaryKey"
    }
}

class tableActivityLatestId: Object {
    @objc dynamic var account = ""
    @objc dynamic var mostRecentlyLoadedActivityId: Int = 0
    override static func primaryKey() -> String {
        return "account"
    }
}

class tableActivityPreview: Object {

    @objc dynamic var account = ""
    @objc dynamic var filename = ""
    @objc dynamic var idPrimaryKey = ""
    @objc dynamic var idActivity: Int = 0
    @objc dynamic var source = ""
    @objc dynamic var link = ""
    @objc dynamic var mimeType = ""
    @objc dynamic var fileId: Int = 0
    @objc dynamic var view = ""
    @objc dynamic var isMimeTypeIcon: Bool = false

    override static func primaryKey() -> String {
        return "idPrimaryKey"
    }
}

class tableActivitySubjectRich: Object {

    @objc dynamic var account = ""
    @objc dynamic var idActivity: Int = 0
    @objc dynamic var idPrimaryKey = ""
    @objc dynamic var id = ""
    @objc dynamic var key = ""
    @objc dynamic var link = ""
    @objc dynamic var name = ""
    @objc dynamic var path = ""
    @objc dynamic var type = ""

    override static func primaryKey() -> String {
        return "idPrimaryKey"
    }
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

class tableDirectory: Object {

    @objc dynamic var account = ""
    @objc dynamic var e2eEncrypted: Bool = false
    @objc dynamic var etag = ""
    @objc dynamic var favorite: Bool = false
    @objc dynamic var fileId = ""
    @objc dynamic var ocId = ""
    @objc dynamic var offline: Bool = false
    @objc dynamic var permissions = ""
    @objc dynamic var richWorkspace: String?
    @objc dynamic var serverUrl = ""

    override static func primaryKey() -> String {
        return "ocId"
    }
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

class tableMetadata: Object, NCUserBaseUrl {
    override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? tableMetadata {
            return self.fileId == object.fileId && self.account == object.account
                   && self.path == object.path && self.fileName == object.fileName
        } else {
            return false
        }
    }

    @objc dynamic var account = ""
    @objc dynamic var assetLocalIdentifier = ""
    @objc dynamic var checksums = ""
    @objc dynamic var chunk: Bool = false
    @objc dynamic var classFile = ""
    @objc dynamic var commentsUnread: Bool = false
    @objc dynamic var contentType = ""
    @objc dynamic var creationDate = NSDate()
    @objc dynamic var dataFingerprint = ""
    @objc dynamic var date = NSDate()
    @objc dynamic var directory: Bool = false
    @objc dynamic var deleteAssetLocalIdentifier: Bool = false
    @objc dynamic var downloadURL = ""
    @objc dynamic var e2eEncrypted: Bool = false
    @objc dynamic var edited: Bool = false
    @objc dynamic var etag = ""
    @objc dynamic var etagResource = ""
    @objc dynamic var ext = ""
    @objc dynamic var favorite: Bool = false
    @objc dynamic var fileId = ""
    @objc dynamic var fileName = ""
    @objc dynamic var fileNameView = ""
    @objc dynamic var fileNameWithoutExt = ""
    @objc dynamic var hasPreview: Bool = false
    @objc dynamic var iconName = ""
    @objc dynamic var iconUrl = ""
    @objc dynamic var isAutoupload: Bool = false
    @objc dynamic var isExtractFile: Bool = false
    @objc dynamic var livePhoto: Bool = false
    @objc dynamic var mountType = ""
    @objc dynamic var name = ""
    @objc dynamic var note = ""
    @objc dynamic var ocId = ""
    @objc dynamic var ownerId = ""
    @objc dynamic var ownerDisplayName = ""
    @objc public var lock = false
    @objc public var lockOwner = ""
    @objc public var lockOwnerEditor = ""
    @objc public var lockOwnerType = 0
    @objc public var lockOwnerDisplayName = ""
    @objc public var lockTime: Date?
    @objc public var lockTimeOut: Date?
    @objc dynamic var path = ""
    @objc dynamic var permissions = ""
    @objc dynamic var quotaUsedBytes: Int64 = 0
    @objc dynamic var quotaAvailableBytes: Int64 = 0
    @objc dynamic var resourceType = ""
    @objc dynamic var richWorkspace: String?
    @objc dynamic var serverUrl = ""
    @objc dynamic var session = ""
    @objc dynamic var sessionError = ""
    @objc dynamic var sessionSelector = ""
    @objc dynamic var sessionTaskIdentifier: Int = 0
    @objc dynamic var sharePermissionsCollaborationServices: Int = 0
    let sharePermissionsCloudMesh = List<String>()
    let shareType = List<Int>()
    @objc dynamic var size: Int64 = 0
    @objc dynamic var status: Int = 0
    @objc dynamic var subline: String?
    @objc dynamic var trashbinFileName = ""
    @objc dynamic var trashbinOriginalLocation = ""
    @objc dynamic var trashbinDeletionTime = NSDate()
    @objc dynamic var uploadDate = NSDate()
    @objc dynamic var url = ""
    @objc dynamic var urlBase = ""
    @objc dynamic var user = ""
    @objc dynamic var userId = ""

    override static func primaryKey() -> String {
        return "ocId"
    }
}

extension tableMetadata {
    var fileExtension: String { (fileNameView as NSString).pathExtension }

    var isPrintable: Bool {
        classFile == NCCommunicationCommon.typeClassFile.image.rawValue || ["application/pdf", "com.adobe.pdf"].contains(contentType) || contentType.hasPrefix("text/")
    }

    /// Returns false if the user is lokced out of the file. I.e. The file is locked but by somone else
    func canUnlock(as user: String) -> Bool {
        return !lock || (lockOwner == user && lockOwnerType == 0)
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

class tableShare: Object {

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
        return "idShare"
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

class tableVideo: Object {

    @objc dynamic var account = ""
    @objc dynamic var duration: Int64 = 0
    @objc dynamic var ocId = ""
    @objc dynamic var time: Int64 = 0
    @objc dynamic var codecNameVideo: String?
    @objc dynamic var codecNameAudio: String?
    @objc dynamic var codecAudioChannelLayout: String?
    @objc dynamic var codecAudioLanguage: String?
    @objc dynamic var codecMaxCompatibility: Bool = false
    @objc dynamic var codecQuality: String?

    override static func primaryKey() -> String {
        return "ocId"
    }
}
