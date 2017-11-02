//
//  NCDatabase.swift
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 06/05/17.
//  Copyright © 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
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

import RealmSwift

class tableAccount: Object {

    @objc dynamic var account = ""
    @objc dynamic var active: Bool = false
    @objc dynamic var address = ""
    @objc dynamic var autoUpload: Bool = false
    @objc dynamic var autoUploadBackground: Bool = false
    @objc dynamic var autoUploadCreateSubfolder: Bool = false
    @objc dynamic var autoUploadFileName = ""
    @objc dynamic var autoUploadDirectory = ""
    @objc dynamic var autoUploadFull: Bool = false
    @objc dynamic var autoUploadImage: Bool = false
    @objc dynamic var autoUploadVideo: Bool = false
    @objc dynamic var autoUploadWWAnPhoto: Bool = false
    @objc dynamic var autoUploadWWAnVideo: Bool = false
    @objc dynamic var autoUploadFormatCompatibility: Bool = false
    @objc dynamic var displayName = ""
    @objc dynamic var email = ""
    @objc dynamic var enabled: Bool = false
    @objc dynamic var optimization = NSDate()
    @objc dynamic var password = ""
    @objc dynamic var phone = ""
    @objc dynamic var quota: Double = 0
    @objc dynamic var quotaFree: Double = 0
    @objc dynamic var quotaRelative: Double = 0
    @objc dynamic var quotaTotal: Double = 0
    @objc dynamic var quotaUsed: Double = 0
    @objc dynamic var twitter = ""
    @objc dynamic var url = ""
    @objc dynamic var user = ""
    @objc dynamic var userID = ""
    @objc dynamic var webpage = ""
}

class tableActivity: Object {
    
    @objc dynamic var account = ""
    @objc dynamic var action = "Activity"
    @objc dynamic var date = NSDate()
    @objc dynamic var file = ""
    @objc dynamic var fileID = ""
    @objc dynamic var idActivity: Double = 0
    @objc dynamic var link = ""
    @objc dynamic var note = ""
    @objc dynamic var selector = ""
    @objc dynamic var type = ""
    @objc dynamic var verbose: Bool = false
}

class tableCapabilities: Object {
    
    @objc dynamic var account = ""
    @objc dynamic var themingBackground = ""
    @objc dynamic var themingColor = ""
    @objc dynamic var themingLogo = ""
    @objc dynamic var themingName = ""
    @objc dynamic var themingSlogan = ""
    @objc dynamic var themingUrl = ""
    @objc dynamic var versionMajor: Int = 0
    @objc dynamic var versionMicro: Int = 0
    @objc dynamic var versionMinor: Int = 0
    @objc dynamic var versionString = ""
    @objc dynamic var endToEndEncryption: Bool = false
    @objc dynamic var endToEndEncryptionVersion = ""
}

class tableCertificates: Object {
    
    @objc dynamic var certificateLocation = ""
}

class tableDirectory: Object {
    
    @objc dynamic var account = ""
    @objc dynamic var dateReadDirectory: NSDate? = nil
    @objc dynamic var directoryID = ""
    @objc dynamic var etag = ""
    @objc dynamic var favorite: Bool = false
    @objc dynamic var fileID = ""
    @objc dynamic var lock: Bool = false
    @objc dynamic var permissions = ""
    @objc dynamic var serverUrl = ""
    
    override static func primaryKey() -> String {
        return "directoryID"
    }
}

class tableE2eEncryption: Object {
    
    @objc dynamic var account = ""
    @objc dynamic var authenticationTag = ""
    @objc dynamic var fileName = ""
    @objc dynamic var fileNameIdentifier = ""
    @objc dynamic var key = ""
    @objc dynamic var initializationVector = ""
    @objc dynamic var tokenLock = ""
    @objc dynamic var metadataKey: Int = 0
    @objc dynamic var mimeType = ""
    @objc dynamic var version: Int = 0
    
    override static func primaryKey() -> String {
        return "fileName"
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
    @objc dynamic var date = NSDate()
    @objc dynamic var etag = ""
    @objc dynamic var exifDate = NSDate()
    @objc dynamic var exifLatitude = ""
    @objc dynamic var exifLongitude = ""
    @objc dynamic var favorite: Bool = false
    @objc dynamic var fileID = ""
    @objc dynamic var fileName = ""
    @objc dynamic var size: Double = 0
    
    override static func primaryKey() -> String {
        return "fileID"
    }
}

class tableMetadata: Object {
    
    @objc dynamic var account = ""
    @objc dynamic var assetLocalIdentifier = ""
    @objc dynamic var date = NSDate()
    @objc dynamic var directory: Bool = false
    @objc dynamic var directoryID = ""
    @objc dynamic var encrypted: Bool = false
    @objc dynamic var etag = ""
    @objc dynamic var favorite: Bool = false
    @objc dynamic var fileID = ""
    @objc dynamic var fileName = ""
    @objc dynamic var iconName = ""
    @objc dynamic var permissions = ""
    @objc dynamic var session = ""
    @objc dynamic var sessionError = ""
    @objc dynamic var sessionID = ""
    @objc dynamic var sessionSelector = ""
    @objc dynamic var sessionSelectorPost = ""
    @objc dynamic var sessionTaskIdentifier: Int = -1
    @objc dynamic var size: Double = 0
    @objc dynamic var status: Double = 0
    @objc dynamic var thumbnailExists: Bool = false
    @objc dynamic var typeFile = ""
    
    override static func primaryKey() -> String {
        return "fileID"
    }
    
    override static func indexedProperties() -> [String] {
        return ["directoryID"]
    }
}

class tablePhotoLibrary: Object {
    
    @objc dynamic var account = ""
    @objc dynamic var assetLocalIdentifier = ""
    @objc dynamic var creationDate: NSDate? = nil
    @objc dynamic var idAsset = ""
    @objc dynamic var modificationDate: NSDate? = nil
    @objc dynamic var mediaType: Int = 0

    override static func primaryKey() -> String {
        return "idAsset"
    }
}

class tableQueueDownload: Object {
    
    @objc dynamic var account = ""
    @objc dynamic var encrypted: Bool = false
    @objc dynamic var fileID = ""
    @objc dynamic var selector = ""
    @objc dynamic var selectorPost = ""
    @objc dynamic var serverUrl = ""
    @objc dynamic var session = ""

    override static func primaryKey() -> String {
        return "fileID"
    }
}

class tableQueueUpload: Object {
    
    @objc dynamic var account = ""
    @objc dynamic var assetLocalIdentifier = ""
    @objc dynamic var date = NSDate()
    @objc dynamic var encrypted: Bool = false
    @objc dynamic var fileName = ""
    @objc dynamic var fileNameIdentifier = ""
    @objc dynamic var lock: Bool = false
    @objc dynamic var priority: Int = 0
    @objc dynamic var selector = ""
    @objc dynamic var selectorPost = ""
    @objc dynamic var serverUrl = ""
    @objc dynamic var session = ""
}

class tableShare: Object {
    
    @objc dynamic var account = ""
    @objc dynamic var fileName = ""
    @objc dynamic var serverUrl = ""
    @objc dynamic var shareLink = ""
    @objc dynamic var shareUserAndGroup = ""
}
