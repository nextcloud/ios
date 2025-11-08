// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import RealmSwift
import NextcloudKit

class tableAccount: Object {
    @objc dynamic var account = ""
    @objc dynamic var active: Bool = false
    @objc dynamic var address = ""
    @objc dynamic var alias = ""
    @objc dynamic var autoUploadCreateSubfolder: Bool = false
    @objc dynamic var autoUploadSubfolderGranularity: Int = NCGlobal.shared.subfolderGranularityMonthly
    @objc dynamic var autoUploadDirectory = ""
    @objc dynamic var autoUploadFileName = ""
    @objc dynamic var autoUploadStart: Bool = false
    @objc dynamic var autoUploadImage: Bool = false
    @objc dynamic var autoUploadVideo: Bool = false
    @objc dynamic var autoUploadWWAnPhoto: Bool = false
    @objc dynamic var autoUploadWWAnVideo: Bool = false
    @objc dynamic var autoUploadSinceDate: Date?
    @objc dynamic var backend = ""
    @objc dynamic var backendCapabilitiesSetDisplayName: Bool = false
    @objc dynamic var backendCapabilitiesSetPassword: Bool = false
    @objc dynamic var displayName = ""
    @objc dynamic var email = ""
    @objc dynamic var enabled: Bool = false
    @objc dynamic var groups = ""
    @objc dynamic var language = ""
    @objc dynamic var lastLogin: Int64 = 0
    @objc dynamic var locale = ""
    @objc dynamic var mediaPath = ""
    @objc dynamic var organisation = ""
    @objc dynamic var phone = ""
    @objc dynamic var quota: Int64 = 0
    @objc dynamic var quotaFree: Int64 = 0
    @objc dynamic var quotaRelative: Double = 0
    @objc dynamic var quotaTotal: Int64 = 0
    @objc dynamic var quotaUsed: Int64 = 0
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

    override static func primaryKey() -> String {
        return "account"
    }

    func tableAccountToCodable() -> tableAccountCodable {
        return tableAccountCodable(account: self.account,
                                   active: self.active,
                                   alias: self.alias,
                                   autoUploadCreateSubfolder: self.autoUploadCreateSubfolder,
                                   autoUploadSubfolderGranularity: self.autoUploadSubfolderGranularity,
                                   autoUploadDirectory: self.autoUploadDirectory,
                                   autoUploadFileName: self.autoUploadFileName,
                                   autoUploadStart: self.autoUploadStart,
                                   autoUploadImage: self.autoUploadImage,
                                   autoUploadVideo: self.autoUploadVideo,
                                   autoUploadWWAnPhoto: self.autoUploadWWAnPhoto,
                                   autoUploadWWAnVideo: self.autoUploadWWAnVideo,
                                   autoUploadSinceDate: self.autoUploadSinceDate,
                                   user: self.user,
                                   userId: self.userId,
                                   urlBase: self.urlBase)
    }

    convenience init(codableObject: tableAccountCodable) {
        self.init()
        self.account = codableObject.account
        self.active = codableObject.active
        self.alias = codableObject.alias

        self.autoUploadCreateSubfolder = codableObject.autoUploadCreateSubfolder
        self.autoUploadSubfolderGranularity = codableObject.autoUploadSubfolderGranularity
        self.autoUploadDirectory = codableObject.autoUploadDirectory
        self.autoUploadFileName = codableObject.autoUploadFileName
        self.autoUploadStart = codableObject.autoUploadStart
        self.autoUploadImage = codableObject.autoUploadImage
        self.autoUploadVideo = codableObject.autoUploadVideo
        self.autoUploadWWAnPhoto = codableObject.autoUploadWWAnPhoto
        self.autoUploadWWAnVideo = codableObject.autoUploadWWAnVideo

        self.user = codableObject.user
        self.userId = codableObject.userId
        self.urlBase = codableObject.urlBase
    }
}

struct tableAccountCodable: Codable {
    var account: String
    var active: Bool
    var alias: String

    var autoUploadCreateSubfolder: Bool
    var autoUploadSubfolderGranularity: Int
    var autoUploadDirectory = ""
    var autoUploadFileName: String
    var autoUploadStart: Bool
    var autoUploadImage: Bool
    var autoUploadVideo: Bool
    var autoUploadWWAnPhoto: Bool
    var autoUploadWWAnVideo: Bool
    var autoUploadSinceDate: Date?

    var user: String
    var userId: String
    var urlBase: String
}
