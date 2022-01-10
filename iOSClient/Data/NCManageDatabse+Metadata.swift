//
//  NCManageDatabse+Metadata.swift
//  Nextcloud
//
//  Created by Henrik Storch on 30.11.21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import Foundation
import RealmSwift
import NCCommunication

extension NCManageDatabase {

    @objc func copyObject(metadata: tableMetadata) -> tableMetadata {
        return tableMetadata.init(value: metadata)
    }

    @objc func convertNCFileToMetadata(_ file: NCCommunicationFile, isEncrypted: Bool, account: String) -> tableMetadata {

        let metadata = tableMetadata()

        metadata.account = account
        metadata.checksums = file.checksums
        metadata.commentsUnread = file.commentsUnread
        metadata.contentType = file.contentType
        if let date = file.creationDate {
            metadata.creationDate = date
        } else {
            metadata.creationDate = file.date
        }
        metadata.dataFingerprint = file.dataFingerprint
        metadata.date = file.date
        metadata.directory = file.directory
        metadata.downloadURL = file.downloadURL
        metadata.e2eEncrypted = file.e2eEncrypted
        metadata.etag = file.etag
        metadata.ext = file.ext
        metadata.favorite = file.favorite
        metadata.fileId = file.fileId
        metadata.fileName = file.fileName
        metadata.fileNameView = file.fileName
        metadata.fileNameWithoutExt = file.fileNameWithoutExt
        metadata.hasPreview = file.hasPreview
        metadata.iconName = file.iconName
        metadata.livePhoto = file.livePhoto
        metadata.mountType = file.mountType
        metadata.note = file.note
        metadata.ocId = file.ocId
        metadata.ownerId = file.ownerId
        metadata.ownerDisplayName = file.ownerDisplayName
        metadata.path = file.path
        metadata.permissions = file.permissions
        metadata.quotaUsedBytes = file.quotaUsedBytes
        metadata.quotaAvailableBytes = file.quotaAvailableBytes
        metadata.richWorkspace = file.richWorkspace
        metadata.resourceType = file.resourceType
        metadata.serverUrl = file.serverUrl
        metadata.sharePermissionsCollaborationServices = file.sharePermissionsCollaborationServices
        for element in file.sharePermissionsCloudMesh {
            metadata.sharePermissionsCloudMesh.append(element)
        }
        for element in file.shareType {
            metadata.shareType.append(element)
        }
        metadata.size = file.size
        metadata.classFile = file.classFile
        if let date = file.uploadDate {
            metadata.uploadDate = date
        } else {
            metadata.uploadDate = file.date
        }
        metadata.urlBase = file.urlBase
        metadata.user = file.user
        metadata.userId = file.userId

        // E2EE find the fileName for fileNameView
        if isEncrypted || metadata.e2eEncrypted {
            if let tableE2eEncryption = NCManageDatabase.shared.getE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", account, file.serverUrl, file.fileName)) {
                metadata.fileNameView = tableE2eEncryption.fileName
                let results = NCCommunicationCommon.shared.getInternalType(fileName: metadata.fileNameView, mimeType: file.contentType, directory: file.directory)
                metadata.contentType = results.mimeType
                metadata.iconName = results.iconName
                metadata.classFile = results.classFile
            }
        }

        // Live Photo "DETECT"
        if !metadata.directory && !metadata.livePhoto && (metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue) {
            var classFile = metadata.classFile
            if classFile == NCCommunicationCommon.typeClassFile.image.rawValue {
                classFile = NCCommunicationCommon.typeClassFile.video.rawValue
            } else {
                classFile = NCCommunicationCommon.typeClassFile.image.rawValue
            }
            if getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameWithoutExt == %@ AND ocId != %@ AND classFile == %@", metadata.account, metadata.serverUrl, metadata.fileNameWithoutExt, metadata.ocId, classFile)) != nil {
                metadata.livePhoto = true
            }
        }

        return metadata
    }

    @objc func convertNCCommunicationFilesToMetadatas(_ files: [NCCommunicationFile], useMetadataFolder: Bool, account: String, completion: @escaping (_ metadataFolder: tableMetadata, _ metadatasFolder: [tableMetadata], _ metadatas: [tableMetadata]) -> Void) {

        var counter: Int = 0
        var isEncrypted: Bool = false
        var listServerUrl: [String: Bool] = [:]

        var metadataFolder = tableMetadata()
        var metadataFolders: [tableMetadata] = []
        var metadatas: [tableMetadata] = []

        for file in files {

            if let key = listServerUrl[file.serverUrl] {
                isEncrypted = key
            } else {
                isEncrypted = CCUtility.isFolderEncrypted(file.serverUrl, e2eEncrypted: file.e2eEncrypted, account: account, urlBase: file.urlBase)
                listServerUrl[file.serverUrl] = isEncrypted
            }

            let metadata = convertNCFileToMetadata(file, isEncrypted: isEncrypted, account: account)

            if counter == 0 && useMetadataFolder {
                metadataFolder = tableMetadata.init(value: metadata)
            } else {
                metadatas.append(metadata)
                if metadata.directory {
                    metadataFolders.append(metadata)
                }
            }

            counter += 1
        }

        completion(metadataFolder, metadataFolders, metadatas)
    }

    @objc func createMetadata(account: String, user: String, userId: String, fileName: String, fileNameView: String, ocId: String, serverUrl: String, urlBase: String, url: String, contentType: String, livePhoto: Bool) -> tableMetadata {

        let metadata = tableMetadata()
        let resultInternalType = NCCommunicationCommon.shared.getInternalType(fileName: fileName, mimeType: contentType, directory: false)

        metadata.account = account
        metadata.chunk = false
        metadata.contentType = resultInternalType.mimeType
        metadata.creationDate = Date() as NSDate
        metadata.date = Date() as NSDate
        metadata.hasPreview = true
        metadata.iconName = resultInternalType.iconName
        metadata.etag = ocId
        metadata.ext = (fileName as NSString).pathExtension.lowercased()
        metadata.fileName = fileName
        metadata.fileNameView = fileName
        metadata.fileNameWithoutExt = (fileName as NSString).deletingPathExtension
        metadata.livePhoto = livePhoto
        metadata.ocId = ocId
        metadata.permissions = "RGDNVW"
        metadata.serverUrl = serverUrl
        metadata.classFile = resultInternalType.classFile
        metadata.uploadDate = Date() as NSDate
        metadata.url = url
        metadata.urlBase = urlBase
        metadata.user = user
        metadata.userId = userId

        return metadata
    }

    @objc func addMetadata(_ metadata: tableMetadata) {

        let realm = try! Realm()

        do {
            try realm.safeWrite {
                realm.add(metadata, update: .all)
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func addMetadatas(_ metadatas: [tableMetadata]) {

        let realm = try! Realm()

        do {
            try realm.safeWrite {
                for metadata in metadatas {
                    realm.add(metadata, update: .all)
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func deleteMetadata(predicate: NSPredicate) {

        let realm = try! Realm()

        do {
            try realm.safeWrite {
                let results = realm.objects(tableMetadata.self).filter(predicate)
                realm.delete(results)
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func moveMetadata(ocId: String, serverUrlTo: String) {

        let realm = try! Realm()

        do {
            try realm.safeWrite {
                if let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first {
                    result.serverUrl = serverUrlTo
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func addMetadataServerUrl(ocId: String, serverUrl: String) {

        let realm = try! Realm()

        do {
            try realm.safeWrite {
                let results = realm.objects(tableMetadata.self).filter("ocId == %@", ocId)
                for result in results {
                    result.serverUrl = serverUrl
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func renameMetadata(fileNameTo: String, ocId: String) {

        let realm = try! Realm()

        do {
            try realm.safeWrite {
                if let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first {
                    let resultsType = NCCommunicationCommon.shared.getInternalType(fileName: fileNameTo, mimeType: "", directory: result.directory)
                    result.fileName = fileNameTo
                    result.fileNameView = fileNameTo
                    if result.directory {
                        result.fileNameWithoutExt = fileNameTo
                        result.ext = ""
                    } else {
                        result.fileNameWithoutExt = (fileNameTo as NSString).deletingPathExtension
                        result.ext = resultsType.ext
                    }
                    result.iconName = resultsType.iconName
                    result.contentType = resultsType.mimeType
                    result.classFile = resultsType.classFile
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @discardableResult
    func updateMetadatas(_ metadatas: [tableMetadata], metadatasResult: [tableMetadata], addCompareLivePhoto: Bool = true, addExistsInLocal: Bool = false, addCompareEtagLocal: Bool = false, addDirectorySynchronized: Bool = false) -> (metadatasUpdate: [tableMetadata], metadatasLocalUpdate: [tableMetadata], metadatasDelete: [tableMetadata]) {

        let realm = try! Realm()
        var ocIdsUdate: [String] = []
        var ocIdsLocalUdate: [String] = []
        var metadatasDelete: [tableMetadata] = []
        var metadatasUpdate: [tableMetadata] = []
        var metadatasLocalUpdate: [tableMetadata] = []

        realm.refresh()

        do {
            try realm.safeWrite {

                // DELETE
                for metadataResult in metadatasResult {
                    if metadatas.firstIndex(where: { $0.ocId == metadataResult.ocId }) == nil {
                        if let result = realm.objects(tableMetadata.self).filter(NSPredicate(format: "ocId == %@", metadataResult.ocId)).first {
                            metadatasDelete.append(tableMetadata.init(value: result))
                            realm.delete(result)
                        }
                    }
                }

                // UPDATE/NEW
                for metadata in metadatas {

                    if let result = metadatasResult.first(where: { $0.ocId == metadata.ocId }) {
                        // update
                        if result.status == NCGlobal.shared.metadataStatusNormal && (result.etag != metadata.etag || result.fileNameView != metadata.fileNameView || result.date != metadata.date || result.permissions != metadata.permissions || result.hasPreview != metadata.hasPreview || result.note != metadata.note) {
                            ocIdsUdate.append(metadata.ocId)
                            realm.add(tableMetadata.init(value: metadata), update: .all)
                        } else if result.status == NCGlobal.shared.metadataStatusNormal && addCompareLivePhoto && result.livePhoto != metadata.livePhoto {
                            ocIdsUdate.append(metadata.ocId)
                            realm.add(tableMetadata.init(value: metadata), update: .all)
                        }
                    } else {
                        // new
                        ocIdsUdate.append(metadata.ocId)
                        realm.add(tableMetadata.init(value: metadata), update: .all)
                    }

                    if metadata.directory && !ocIdsUdate.contains(metadata.ocId) {
                        let table = realm.objects(tableDirectory.self).filter(NSPredicate(format: "ocId == %@", metadata.ocId)).first
                        if table?.etag != metadata.etag {
                            ocIdsUdate.append(metadata.ocId)
                        }
                    }

                    // Local
                    if !metadata.directory && (addExistsInLocal || addCompareEtagLocal) {
                        let localFile = realm.objects(tableLocalFile.self).filter(NSPredicate(format: "ocId == %@", metadata.ocId)).first
                        if addCompareEtagLocal && localFile != nil && localFile?.etag != metadata.etag {
                            ocIdsLocalUdate.append(metadata.ocId)
                        }
                        if addExistsInLocal && (localFile == nil || localFile?.etag != metadata.etag) && !ocIdsLocalUdate.contains(metadata.ocId) {
                            ocIdsLocalUdate.append(metadata.ocId)
                        }
                    }
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }

        for ocId in ocIdsUdate {
            if let result = realm.objects(tableMetadata.self).filter(NSPredicate(format: "ocId == %@", ocId)).first {
                metadatasUpdate.append(tableMetadata.init(value: result))
            }
        }

        for ocId in ocIdsLocalUdate {
            if let result = realm.objects(tableMetadata.self).filter(NSPredicate(format: "ocId == %@", ocId)).first {
                metadatasLocalUpdate.append(tableMetadata.init(value: result))
            }
        }

        return (metadatasUpdate, metadatasLocalUpdate, metadatasDelete)
    }

    func setMetadataSession(ocId: String, session: String? = nil, sessionError: String? = nil, sessionSelector: String? = nil, sessionTaskIdentifier: Int? = nil, status: Int? = nil, etag: String? = nil) {

        let realm = try! Realm()
        realm.refresh()

        do {
            try realm.safeWrite {
                let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                if let session = session {
                    result?.session = session
                }
                if let sessionError = sessionError {
                    result?.sessionError = sessionError
                }
                if let sessionSelector = sessionSelector {
                    result?.sessionSelector = sessionSelector
                }
                if let sessionTaskIdentifier = sessionTaskIdentifier {
                    result?.sessionTaskIdentifier = sessionTaskIdentifier
                }
                if let status = status {
                    result?.status = status
                }
                if let etag = etag {
                    result?.etag = etag
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @discardableResult
    func setMetadataStatus(ocId: String, status: Int) -> tableMetadata? {

        let realm = try! Realm()
        var result: tableMetadata?

        do {
            try realm.safeWrite {
                result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                result?.status = status
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }

        if let result = result {
            return tableMetadata.init(value: result)
        } else {
            return nil
        }
    }

    func setMetadataEtagResource(ocId: String, etagResource: String?) {

        let realm = try! Realm()
        var result: tableMetadata?
        guard let etagResource = etagResource else { return }

        do {
            try realm.safeWrite {
                result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                result?.etagResource = etagResource
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func setMetadataFavorite(ocId: String, favorite: Bool) {

        let realm = try! Realm()

        do {
            try realm.safeWrite {
                let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                result?.favorite = favorite
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func updateMetadatasFavorite(account: String, metadatas: [tableMetadata]) {

        let realm = try! Realm()

        do {
            try realm.safeWrite {
                let results = realm.objects(tableMetadata.self).filter("account == %@ AND favorite == true", account)
                for result in results {
                    result.favorite = false
                }
                for metadata in metadatas {
                    realm.add(metadata, update: .all)
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func setMetadataEncrypted(ocId: String, encrypted: Bool) {

        let realm = try! Realm()

        do {
            try realm.safeWrite {
                let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                result?.e2eEncrypted = encrypted
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func setMetadataFileNameView(serverUrl: String, fileName: String, newFileNameView: String, account: String) {

        let realm = try! Realm()

        do {
            try realm.safeWrite {
                let result = realm.objects(tableMetadata.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@", account, serverUrl, fileName).first
                result?.fileNameView = newFileNameView
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func getMetadata(predicate: NSPredicate) -> tableMetadata? {

        let realm = try! Realm()
        realm.refresh()

        guard let result = realm.objects(tableMetadata.self).filter(predicate).first else {
            return nil
        }

        return tableMetadata.init(value: result)
    }

    @objc func getMetadata(predicate: NSPredicate, sorted: String, ascending: Bool) -> tableMetadata? {

        let realm = try! Realm()
        realm.refresh()

        guard let result = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending).first else {
            return nil
        }

        return tableMetadata.init(value: result)
    }

    @objc func getMetadatasViewer(predicate: NSPredicate, sorted: String, ascending: Bool) -> [tableMetadata]? {

        let realm = try! Realm()
        realm.refresh()

        let results: Results<tableMetadata>
        var finals: [tableMetadata] = []

        if (tableMetadata().objectSchema.properties.contains { $0.name == sorted }) {
            results = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)
        } else {
            results = realm.objects(tableMetadata.self).filter(predicate)
        }

        // For Live Photo
        var fileNameImages: [String] = []
        let filtered = results.filter { $0.classFile.contains(NCCommunicationCommon.typeClassFile.image.rawValue) }
        filtered.forEach { print($0)
            let fileName = ($0.fileNameView as NSString).deletingPathExtension
            fileNameImages.append(fileName)
        }

        for result in results {

            let ext = (result.fileNameView as NSString).pathExtension.uppercased()
            let fileName = (result.fileNameView as NSString).deletingPathExtension

            if !(ext == "MOV" && fileNameImages.contains(fileName)) {
                finals.append(result)
            }
        }

        if finals.count > 0 {
            return Array(finals.map { tableMetadata.init(value: $0) })
        } else {
            return nil
        }
    }

    @objc func getMetadatas(predicate: NSPredicate) -> [tableMetadata] {

        let realm = try! Realm()
        realm.refresh()

        let results = realm.objects(tableMetadata.self).filter(predicate)

        return Array(results.map { tableMetadata.init(value: $0) })
    }

    @objc func getAdvancedMetadatas(predicate: NSPredicate, page: Int = 0, limit: Int = 0, sorted: String, ascending: Bool) -> [tableMetadata] {

        let realm = try! Realm()
        realm.refresh()
        var metadatas: [tableMetadata] = []

        let results = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)

        if results.count > 0 {
            if page == 0 || limit == 0 {
                return Array(results.map { tableMetadata.init(value: $0) })
            } else {

                let nFrom = (page - 1) * limit
                let nTo = nFrom + (limit - 1)

                for n in nFrom...nTo {
                    if n == results.count {
                        break
                    }
                    metadatas.append(tableMetadata.init(value: results[n]))
                }
            }
        }
        return metadatas
    }

    @objc func getMetadataAtIndex(predicate: NSPredicate, sorted: String, ascending: Bool, index: Int) -> tableMetadata? {

        let realm = try! Realm()
        realm.refresh()

        let results = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)

        if results.count > 0  && results.count > index {
            return tableMetadata.init(value: results[index])
        } else {
            return nil
        }
    }

    @objc func getMetadataFromOcId(_ ocId: String?) -> tableMetadata? {

        let realm = try! Realm()
        realm.refresh()

        guard let ocId = ocId else { return nil }
        guard let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first else { return nil }

        return tableMetadata.init(value: result)
    }

    @objc func getMetadataFolder(account: String, urlBase: String, serverUrl: String) -> tableMetadata? {

        let realm = try! Realm()
        realm.refresh()
        var serverUrl = serverUrl
        var fileName = ""

        let serverUrlHome = NCUtilityFileSystem.shared.getHomeServer(account: account)
        if serverUrlHome == serverUrl {
            fileName = "."
            serverUrl = ".."
        } else {
            fileName = (serverUrl as NSString).lastPathComponent
            serverUrl = NCUtilityFileSystem.shared.deletingLastPathComponent(account: account, serverUrl: serverUrl)
        }

        guard let result = realm.objects(tableMetadata.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@", account, serverUrl, fileName).first else { return nil }

        return tableMetadata.init(value: result)
    }

    @objc func getTableMetadatasDirectoryFavoriteIdentifierRank(account: String) -> [String: NSNumber] {

        var listIdentifierRank: [String: NSNumber] = [:]
        let realm = try! Realm()
        var counter = 10 as Int64

        let results = realm.objects(tableMetadata.self).filter("account == %@ AND directory == true AND favorite == true", account).sorted(byKeyPath: "fileNameView", ascending: true)

        for result in results {
            counter += 1
            listIdentifierRank[result.ocId] = NSNumber(value: Int64(counter))
        }

        return listIdentifierRank
    }

    @objc func clearMetadatasUpload(account: String) {

        let realm = try! Realm()
        realm.refresh()

        do {
            try realm.safeWrite {

                let results = realm.objects(tableMetadata.self).filter("account == %@ AND (status == %d OR status == %@)", account, NCGlobal.shared.metadataStatusWaitUpload, NCGlobal.shared.metadataStatusUploadError)
                realm.delete(results)
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func readMarkerMetadata(account: String, fileId: String) {

        let realm = try! Realm()

        do {
            try realm.safeWrite {
                let results = realm.objects(tableMetadata.self).filter("account == %@ AND fileId == %@", account, fileId)
                for result in results {
                    result.commentsUnread = false
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func getAssetLocalIdentifiersUploaded(account: String, sessionSelector: String) -> [String] {

        let realm = try! Realm()
        realm.refresh()

        var assetLocalIdentifiers: [String] = []

        let results = realm.objects(tableMetadata.self).filter("account == %@ AND assetLocalIdentifier != '' AND deleteAssetLocalIdentifier == true AND sessionSelector == %@", account, sessionSelector)
        for result in results {
            assetLocalIdentifiers.append(result.assetLocalIdentifier)
        }

        return assetLocalIdentifiers
    }

    @objc func clearAssetLocalIdentifiers(_ assetLocalIdentifiers: [String], account: String) {

        let realm = try! Realm()

        do {
            try realm.safeWrite {
                let results = realm.objects(tableMetadata.self).filter("account == %@ AND assetLocalIdentifier IN %@", account, assetLocalIdentifiers)
                for result in results {
                    result.assetLocalIdentifier = ""
                    result.deleteAssetLocalIdentifier = false
                }
            }
        } catch let error {
            NCCommunicationCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func getMetadataLivePhoto(metadata: tableMetadata) -> tableMetadata? {

        let realm = try! Realm()
        var classFile = metadata.classFile

        realm.refresh()

        if !metadata.livePhoto || !CCUtility.getLivePhoto() {
            return nil
        }

        if classFile == NCCommunicationCommon.typeClassFile.image.rawValue {
            classFile = NCCommunicationCommon.typeClassFile.video.rawValue
        } else {
            classFile = NCCommunicationCommon.typeClassFile.image.rawValue
        }

        guard let result = realm.objects(tableMetadata.self).filter(NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameWithoutExt == %@ AND ocId != %@ AND classFile == %@", metadata.account, metadata.serverUrl, metadata.fileNameWithoutExt, metadata.ocId, classFile)).first else {
            return nil
        }

        return tableMetadata.init(value: result)
    }

    func getMetadatasMedia(predicate: NSPredicate, sort: String, ascending: Bool = false) -> [tableMetadata] {

        let realm = try! Realm()
        realm.refresh()

        let sortProperties = [SortDescriptor(keyPath: sort, ascending: ascending), SortDescriptor(keyPath: "fileNameView", ascending: false)]
        let results = realm.objects(tableMetadata.self).filter(predicate).sorted(by: sortProperties)

        return Array(results.map { tableMetadata.init(value: $0) })
    }

    func isMetadataShareOrMounted(metadata: tableMetadata, metadataFolder: tableMetadata?) -> Bool {

        var isShare = false
        var isMounted = false

        if metadataFolder != nil {

            isShare = metadata.permissions.contains(NCGlobal.shared.permissionShared) && !metadataFolder!.permissions.contains(NCGlobal.shared.permissionShared)
            isMounted = metadata.permissions.contains(NCGlobal.shared.permissionMounted) && !metadataFolder!.permissions.contains(NCGlobal.shared.permissionMounted)

        } else if let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {

            isShare = metadata.permissions.contains(NCGlobal.shared.permissionShared) && !directory.permissions.contains(NCGlobal.shared.permissionShared)
            isMounted = metadata.permissions.contains(NCGlobal.shared.permissionMounted) && !directory.permissions.contains(NCGlobal.shared.permissionMounted)
        }

        if isShare || isMounted {
            return true
        } else {
            return false
        }
    }

    func isDownloadMetadata(_ metadata: tableMetadata, download: Bool) -> Bool {

        let localFile = getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
        let fileSize = CCUtility.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView)
        if (localFile != nil || download) && (localFile?.etag != metadata.etag || fileSize == 0) {
            return true
        }
        return false
    }

    func getMetadataConflict(account: String, serverUrl: String, fileName: String) -> tableMetadata? {

        // verify exists conflict
        let fileNameExtension = (fileName as NSString).pathExtension.lowercased()
        let fileNameWithoutExtension = (fileName as NSString).deletingPathExtension
        var fileNameConflict = fileName

        if fileNameExtension == "heic" && CCUtility.getFormatCompatibility() {
            fileNameConflict = fileNameWithoutExtension + ".jpg"
        }
        return getMetadata(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileNameView == %@", account, serverUrl, fileNameConflict))
    }
}
