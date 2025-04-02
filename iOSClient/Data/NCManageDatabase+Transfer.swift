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

    @Persisted var sceneIdentifier: String?
    @Persisted var livePhotoFile: String?
    @Persisted var classFile = ""
    @Persisted var contentType = ""
    @Persisted var iconName = ""
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
    func createTransferForAutoUpload(session: NCSession.Session,
                                     serverUrl: String,
                                     fileName: String,
                                     livePhoto: Bool,
                                     localIdentifier: String,
                                     uploadSession: String,
                                     sceneIdentifier: String?) -> TableTransfer? {
        /// MOST COMPATIBLE SEARCH --> HEIC --> JPG
        var fileNameFormatCompatibility = fileName
        let ext = (fileNameFormatCompatibility as NSString).pathExtension.lowercased()
        if ext == "heic", NCKeychain().formatCompatibility {
            fileNameFormatCompatibility = (fileNameFormatCompatibility as NSString).deletingPathExtension + ".jpg"
        }
        let predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView == %@", session.account, serverUrl, fileNameFormatCompatibility)

        do {
            let realm = try Realm()
            /// verify if already exists
            if realm.objects(TableTransfer.self).filter(predicate).first != nil {
                return nil
            }

            let result = TableTransfer()
            result.account = session.account
            result.fileName = fileName
            result.fileNameView = fileName

            result.serverUrl = serverUrl
            result.urlBase = session.urlBase
            result.user = session.user
            result.userId = session.userId

            if livePhoto {
                result.livePhotoFile = (fileName as NSString).deletingPathExtension + ".mov"
            }

            let (_, classFile, iconName, _, _, _) = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: fileName, mimeType: "", directory: false, account: session.account)

            result.classFile = classFile
            result.iconName = iconName
            result.assetLocalIdentifier = localIdentifier

            result.session = uploadSession
            result.sessionSelector = NCGlobal.shared.selectorUploadAutoUpload
            result.sessionStatus = NCGlobal.shared.metadataStatusWaitUpload

            result.sceneIdentifier = sceneIdentifier

            return result
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write database: \(error)")
        }

        return nil
    }

    func createTransferForUpload(session: NCSession.Session,
                                 serverUrl: String,
                                 fileName: String,
                                 livePhoto: Bool,
                                 nativeFormat: Bool,
                                 localIdentifier: String,
                                 uploadSession: String,
                                 sceneIdentifier: String?) -> TableTransfer? {
        let predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView == %@", session.account, serverUrl, fileName)

        do {
            let realm = try Realm()
            /// verify if already exists
            if realm.objects(TableTransfer.self).filter(predicate).first != nil {
                return nil
            }

            let result = TableTransfer()
            result.account = session.account
            result.fileName = fileName
            result.fileNameView = fileName

            result.serverUrl = serverUrl
            result.urlBase = session.urlBase
            result.user = session.user
            result.userId = session.userId

            if livePhoto {
                result.livePhotoFile = (fileName as NSString).deletingPathExtension + ".mov"
            }

            let (_, classFile, iconName, _, _, _) = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: fileName, mimeType: "", directory: false, account: session.account)

            result.classFile = classFile
            result.iconName = iconName
            result.nativeFormat = nativeFormat
            result.assetLocalIdentifier = localIdentifier

            result.session = uploadSession
            result.sessionSelector = NCGlobal.shared.selectorUploadFile
            result.sessionStatus = NCGlobal.shared.metadataStatusWaitUpload

            result.sceneIdentifier = sceneIdentifier

            return result
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write database: \(error)")
        }

        return nil
    }

    func createTransferProcessUploads(transfers: [TableTransfer], with verify: Bool = false, completion: @escaping (_ items: Int) -> Void = {_ in}) {
        var counter: Int = 0
        do {
            let realm = try Realm()
            try realm.write {
                for transfer in transfers {
                    if verify {
                        let predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView == %@", transfer.account, transfer.serverUrl, transfer.fileName)
                        if realm.objects(TableTransfer.self).filter(predicate).first != nil {
                            continue
                        }
                    }
                    realm.create(TableTransfer.self, value: transfer, update: .all)
                    counter += 1
                }
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write database: \(error)")
        }
        completion(counter)
    }
}
