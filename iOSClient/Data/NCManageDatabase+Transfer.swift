// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import RealmSwift
import NextcloudKit

class TableTransfer: Object {
    @Persisted var account = ""
    @Persisted(primaryKey: true) var id = NSUUID().uuidString

    /// FileName = name of file, FileNameView = displayed file name, used for e2ee, normally equals FileName
    @Persisted var fileName = ""
    @Persisted var fileNameView = ""

    /// assetLocalIdentifier = phAsset localIdentifier
    @Persisted var assetLocalIdentifier = ""
    /// true when the file is present in getDirectoryProviderStorageOcId(id, fileNameView: fileName)
    @Persisted var isExtractFile: Bool = false

    /// used for webDAV
    @Persisted var urlBase = ""
    @Persisted var user = ""
    @Persisted var userId = ""
    @Persisted var serverUrl = ""

    //@Persisted var serverUrlTo = ""

    @Persisted var sceneIdentifier: String?
    @Persisted var livePhotoFile: String?
    @Persisted var classFile = ""
    @Persisted var contentType = ""
    @Persisted var size: Int64 = 0

    @Persisted var e2eEncrypted: Bool = false

    @Persisted var nativeFormat: Bool = false

    @Persisted var chunk: Int = 0

    @Persisted var creationDate = Date()
    @Persisted var modificationDate = Date()

    @Persisted var session = ""
    @Persisted var sessionDate = Date()
    @Persisted var sessionError = ""
    @Persisted var sessionSelector = ""
    @Persisted var sessionTaskIdentifier: Int = 0
    @Persisted var sessionStatus: Int = 0

    /*
    convenience init(account: String, id: String, timestamp: Date?, name: String, directory: String, extensionType: String, mimeType: String, hasPreview: Bool, reason: String) {
        self.init()

        self.account = account
        self.id = id
        self.primaryKey = account + id
        self.timestamp = timestamp
        self.name = name
        self.directory = directory
        self.extensionType = extensionType
        self.mimeType = mimeType
        self.hasPreview = hasPreview
        self.reason = reason
     }
     */
}

extension NCManageDatabase {
    func autoUpload(session: NCSession.Session, serverUrl: String, fileName: String, livePhotoFile: Bool, localIdentifier: String, uploadSession: String, sceneIdentifier: String?) {
        // MOST COMPATIBLE SEARCH --> HEIC --> JPG
        var fileNameSearchMetadata = fileName
        let ext = (fileNameSearchMetadata as NSString).pathExtension.lowercased()
        if ext == "heic", NCKeychain().formatCompatibility {
            fileNameSearchMetadata = (fileNameSearchMetadata as NSString).deletingPathExtension + ".jpg"
        }

        let predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView == %@", session.account, serverUrl, fileNameSearchMetadata)
        do {
            let realm = try Realm()
            /// verify if already exists
            if realm.objects(TableTransfer.self).filter(predicate).first != nil {
                return
            }
            try realm.write {
                let result = TableTransfer()
                result.account = session.account
                result.fileName = fileName
                result.fileNameView = fileName

                result.serverUrl = serverUrl
                result.urlBase = session.urlBase
                result.user = session.user
                result.userId = session.userId

                if livePhotoFile {
                    result.livePhotoFile = (fileName as NSString).deletingPathExtension + ".mov"
                }

                result.assetLocalIdentifier = localIdentifier
                result.session = uploadSession
                result.sessionSelector = NCGlobal.shared.selectorUploadAutoUpload
                result.sessionStatus = NCGlobal.shared.metadataStatusWaitUpload

                result.sceneIdentifier = sceneIdentifier
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write database: \(error)")
        }
    }
}
