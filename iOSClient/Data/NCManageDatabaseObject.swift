// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import RealmSwift
import NextcloudKit

// MARK: - TABLE METADATA

class tableMetadata: Object {
    override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? tableMetadata,
           self.account == object.account,
           self.etag == object.etag,
           self.fileId == object.fileId,
           self.path == object.path,
           self.fileName == object.fileName,
           self.fileNameView == object.fileNameView,
           self.date == object.date,
           self.datePhotosOriginal == object.datePhotosOriginal,
           self.permissions == object.permissions,
           self.hasPreview == object.hasPreview,
           self.note == object.note,
           self.lock == object.lock,
           self.favorite == object.favorite,
           self.livePhotoFile == object.livePhotoFile,
           self.sharePermissionsCollaborationServices == object.sharePermissionsCollaborationServices,
           self.height == object.height,
           self.width == object.width,
           self.latitude == object.latitude,
           self.longitude == object.longitude,
           self.altitude == object.altitude,
           self.status == object.status,
           Array(self.tags).elementsEqual(Array(object.tags)),
           Array(self.shareType).elementsEqual(Array(object.shareType)) {
            return true
        } else {
            return false
        }
    }

    @objc dynamic var account = ""
    @objc dynamic var assetLocalIdentifier = ""
    @objc dynamic var checksums = ""
    @objc dynamic var chunk: Int = 0
    @objc dynamic var classFile = ""
    @objc dynamic var commentsUnread: Bool = false
    @objc dynamic var contentType = ""
    @objc dynamic var creationDate = NSDate()
    @objc dynamic var dataFingerprint = ""
    @objc dynamic var date = NSDate()
    @objc dynamic var datePhotosOriginal = NSDate()
    @objc dynamic var directory: Bool = false
    @objc dynamic var downloadURL = ""
    @objc dynamic var e2eEncrypted: Bool = false
    @objc dynamic var edited: Bool = false
    @objc dynamic var etag = ""
    let exifPhotos = List<NCKeyValue>()
    @objc dynamic var favorite: Bool = false
    @objc dynamic var fileId = ""
    @objc dynamic var fileName = ""
    @objc dynamic var fileNameView = ""
    @objc dynamic var hasPreview: Bool = false
    @objc dynamic var hidden: Bool = false
    @objc dynamic var iconName = ""
    @objc dynamic var iconUrl = ""
    @objc dynamic var isFlaggedAsLivePhotoByServer: Bool = false // Indicating if the file is sent as a live photo from the server, or if we should detect it as such and convert it client-side
    @objc dynamic var isExtractFile: Bool = false
    @objc dynamic var livePhotoFile = "" // If this is not empty, the media is a live photo. New media gets this straight from server, but old media needs to be detected as live photo (look isFlaggedAsLivePhotoByServer)
    @objc dynamic var mountType = ""
    @objc dynamic var name = "" // for unifiedSearch is the provider.id
    @objc dynamic var note = ""
    @objc dynamic var ocId = ""
    @objc dynamic var ocIdTransfer = ""
    @objc dynamic var ownerId = ""
    @objc dynamic var ownerDisplayName = ""
    @objc public var lock = false
    @objc public var lockOwner = ""
    @objc public var lockOwnerEditor = ""
    @objc public var lockOwnerType = 0
    @objc public var lockOwnerDisplayName = ""
    @objc public var lockTime: Date?
    @objc public var lockTimeOut: Date?
    @objc dynamic var mediaSearch: Bool = false
    @objc dynamic var path = ""
    @objc dynamic var permissions = ""
    @objc dynamic var placePhotos: String?
    @objc dynamic var quotaUsedBytes: Int64 = 0
    @objc dynamic var quotaAvailableBytes: Int64 = 0
    @objc dynamic var resourceType = ""
    @objc dynamic var richWorkspace: String?
    @objc dynamic var sceneIdentifier: String?
    @objc dynamic var serverUrl = ""
    @objc dynamic var serverUrlFileName = ""
    @objc dynamic var destination = ""
    @objc dynamic var session = ""
    @objc dynamic var sessionDate: Date?
    @objc dynamic var sessionError = ""
    @objc dynamic var sessionSelector = ""
    @objc dynamic var sessionTaskIdentifier: Int = 0
    /// The  integer for sharing permissions.
    @objc dynamic var sharePermissionsCollaborationServices: Int = 0
    let shareType = List<Int>()
    @objc dynamic var size: Int64 = 0
    @objc dynamic var status: Int = 0
    @objc dynamic var storeFlag: String?
    @objc dynamic var subline: String?
    let tags = List<String>()
    @objc dynamic var trashbinFileName = ""
    @objc dynamic var trashbinOriginalLocation = ""
    @objc dynamic var trashbinDeletionTime = NSDate()
    @objc dynamic var uploadDate = NSDate()
    @objc dynamic var url = ""
    @objc dynamic var urlBase = ""
    @objc dynamic var user = ""
    @objc dynamic var userId = ""
    @objc dynamic var latitude: Double = 0
    @objc dynamic var longitude: Double = 0
    @objc dynamic var altitude: Double = 0
    @objc dynamic var height: Int = 0
    @objc dynamic var width: Int = 0
    @objc dynamic var errorCode: Int = 0
    @objc dynamic var nativeFormat: Bool = false
    @objc dynamic var autoUploadServerUrlBase: String?
    @objc dynamic var typeIdentifier: String = ""

    override static func primaryKey() -> String {
        return "ocId"
    }
}

extension tableMetadata {
    var fileExtension: String {
        (fileNameView as NSString).pathExtension
    }

    var fileNoExtension: String {
        (fileNameView as NSString).deletingPathExtension
    }

    var isSavebleInCameraRoll: Bool {
        return (classFile == NKTypeClassFile.image.rawValue && contentType != "image/svg+xml") || classFile == NKTypeClassFile.video.rawValue
    }

    var isAudioOrVideo: Bool {
        return classFile == NKTypeClassFile.audio.rawValue || classFile == NKTypeClassFile.video.rawValue
    }

    var isImageOrVideo: Bool {
        return classFile == NKTypeClassFile.image.rawValue || classFile == NKTypeClassFile.video.rawValue
    }

    var isVideo: Bool {
        return classFile == NKTypeClassFile.video.rawValue
    }

    var isAudio: Bool {
        return classFile == NKTypeClassFile.audio.rawValue
    }

    var isImage: Bool {
        return classFile == NKTypeClassFile.image.rawValue
    }

    var isSavebleAsImage: Bool {
        classFile == NKTypeClassFile.image.rawValue && contentType != "image/svg+xml"
    }

    var isCopyableInPasteboard: Bool {
        !directory
    }

#if !EXTENSION_FILE_PROVIDER_EXTENSION
    var isCopyableMovable: Bool {
        !isDirectoryE2EE && !e2eEncrypted
    }

    var isModifiableWithQuickLook: Bool {
        if directory || isDirectoryE2EE {
            return false
        }
        return isPDF || isImage
    }

    var isRenameable: Bool {
        if !NCMetadataPermissions.canRename(self) {
            return false
        }
        if lock {
            return false
        }
        if !isDirectoryE2EE && e2eEncrypted {
            return false
        }
        return true
    }

    var canUnsetDirectoryAsE2EE: Bool {
        return !isDirectoryE2EE && directory && size == 0 && e2eEncrypted && NCPreferences().isEndToEndEnabled(account: account)
    }

    var isDeletable: Bool {
        if (!isDirectoryE2EE && e2eEncrypted) || !NCMetadataPermissions.canDelete(self) {
            return false
        }
        return true
    }

    var canSetAsAvailableOffline: Bool {
        return session.isEmpty && !isDirectoryE2EE && !e2eEncrypted
    }

    @objc var isDirectoryE2EE: Bool {
        return NCUtilityFileSystem().isDirectoryE2EE(serverUrl: serverUrl, urlBase: urlBase, userId: userId, account: account)
    }

    // Return if is sharable
    func isSharable() -> Bool {
        guard let capabilities = NCNetworking.shared.capabilities[account] else {
            return false
        }
        if !capabilities.fileSharingApiEnabled || (capabilities.e2EEEnabled && isDirectoryE2EE) {
            return false
        }
        return true
    }

    var hasPreviewBorder: Bool {
        !isImage && !isAudioOrVideo && hasPreview && NCUtilityFileSystem().fileProviderStorageImageExists(ocId, etag: etag, ext: NCGlobal.shared.previewExt1024, userId: userId, urlBase: urlBase)
    }

    var isAvailableEditorView: Bool {
        guard !isPDF,
              classFile == NKTypeClassFile.document.rawValue,
              NextcloudKit.shared.isNetworkReachable() else {
            return false
        }
        let utility = NCUtility()
        let directEditingEditors = utility.editorsDirectEditing(account: account, contentType: contentType).map { $0.lowercased() }
        let richDocumentEditor = utility.isTypeFileRichDocument(self)
        let capabilities = NCNetworking.shared.capabilities[account]

        if let capabilities,
           capabilities.richDocumentsEnabled,
           richDocumentEditor,
           directEditingEditors.isEmpty {
            // RichDocument: Collabora
            return true
        } else if directEditingEditors.contains("nextcloud text") || directEditingEditors.contains("onlyoffice") {
            // DirectEditing: Nextcloud Text - OnlyOffice
           return true
        }
        return false
    }

    var isAvailableRichDocumentEditorView: Bool {
        guard let capabilities = NCNetworking.shared.capabilities[account],
              classFile == NKTypeClassFile.document.rawValue,
              capabilities.richDocumentsEnabled,
              NextcloudKit.shared.isNetworkReachable() else { return false }

        if NCUtility().isTypeFileRichDocument(self) {
            return true
        }
        return false
    }

    var isAvailableDirectEditingEditorView: Bool {
        guard (classFile == NKTypeClassFile.document.rawValue) && NextcloudKit.shared.isNetworkReachable() else {
            return false
        }
        let editors = NCUtility().editorsDirectEditing(account: account, contentType: contentType).map { $0.lowercased() }

        if editors.contains("nextcloud text") || editors.contains("onlyoffice") {
            return true
        }
        return false
    }

    var isPDF: Bool {
        return (contentType == "application/pdf" || contentType == "com.adobe.pdf")
    }

#endif

    var isCreatable: Bool {
        if isDirectory {
            return NCMetadataPermissions.canCreateFolder(self)
        } else {
            return NCMetadataPermissions.canCreateFile(self)
        }
    }

    var canShare: Bool {
        return session.isEmpty && !directory && !NCBrandOptions.shared.disable_openin_file
    }

    var isDownload: Bool {
        status == NCGlobal.shared.metadataStatusWaitDownload || status == NCGlobal.shared.metadataStatusDownloading
    }

    var isUpload: Bool {
        status == NCGlobal.shared.metadataStatusWaitUpload || status == NCGlobal.shared.metadataStatusUploading
    }

    var isDirectory: Bool {
        directory
    }

    var isLivePhoto: Bool {
        !livePhotoFile.isEmpty
    }

    var isNotFlaggedAsLivePhotoByServer: Bool {
        !isFlaggedAsLivePhotoByServer
    }

    var imageSize: CGSize {
        CGSize(width: width, height: height)
    }


    /// Returns false if the user is lokced out of the file. I.e. The file is locked but by somone else
    func canUnlock(as user: String) -> Bool {
        return !lock || (lockOwner == user && lockOwnerType == 0)
    }

    /// Returns a detached (unmanaged) deep copy of the current `tableMetadata` object.
    ///
    /// - Note: The Realm `List` properties containing primitive types (e.g., `tags`, `shareType`) are copied automatically
    ///         by the Realm initializer `init(value:)`. For `List` containing Realm objects (e.g., `exifPhotos`), this method
    ///         creates new instances to ensure the copy is fully detached and safe to use outside of a Realm context.
    ///
    /// - Returns: A new `tableMetadata` instance fully detached from Realm.
    func detachedCopy() -> tableMetadata {
        // Use Realm's built-in copy constructor for primitive properties and List of primitives
        let detached = tableMetadata(value: self)

        // Deep copy of List of Realm objects (exifPhotos)
        detached.exifPhotos.removeAll()
        detached.exifPhotos.append(objectsIn: self.exifPhotos.map { NCKeyValue(value: $0) })

        return detached
    }
}

// MARK: - TABLE DIRECTORY

class tableDirectory: Object {
    @objc dynamic var account = ""
    @objc dynamic var colorFolder: String?
    @objc dynamic var etag = ""
    @objc dynamic var favorite: Bool = false
    @objc dynamic var fileId = ""
    @objc dynamic var lastOpeningDate = NSDate()
    @objc dynamic var lastSyncDate: NSDate?
    @objc dynamic var ocId = ""
    @objc dynamic var offline: Bool = false
    @objc dynamic var permissions = ""
    @objc dynamic var richWorkspace: String?
    @objc dynamic var serverUrl = ""

    override static func primaryKey() -> String {
        return "ocId"
    }
}

// MARK: - TABLE CAPABILITIES

class tableCapabilities: Object {
    @Persisted(primaryKey: true) var account = ""
    @Persisted var capabilities: Data?
    @Persisted var editors: Data?
}

// MARK: - TABLE ACCOUNT

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

// MARK: - TABLE LOCALFILE

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
    @objc dynamic var lastOpeningDate = NSDate()

    override static func primaryKey() -> String {
        return "ocId"
    }
}

// MARK: - TABLE AutoUploadTransfer

class tableAutoUploadTransfer: Object {
    @Persisted(primaryKey: true) var primaryKey: String
    @Persisted var account: String
    @Persisted var serverUrlBase: String
    @Persisted var fileName: String
    @Persisted var assetLocalIdentifier: String
    @Persisted var date: Date

    convenience init(account: String, serverUrlBase: String, fileName: String, assetLocalIdentifier: String, date: Date) {
        self.init()

        self.primaryKey = account + serverUrlBase + fileName
        self.account = account
        self.serverUrlBase = serverUrlBase
        self.fileName = fileName
        self.assetLocalIdentifier = assetLocalIdentifier
        self.date = date
    }
}

// MARK: - TABLE TAG

class tableTag: Object {
    @objc dynamic var account = ""
    @objc dynamic var ocId = ""
    @objc dynamic var tagIOS: Data?

    override static func primaryKey() -> String {
        return "ocId"
    }
}
