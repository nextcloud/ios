//
//  NCManageDatabase.swift
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
import SwiftyJSON
import CoreMedia
import Photos

class NCManageDatabase: NSObject {
    @objc static let shared: NCManageDatabase = {
        let instance = NCManageDatabase()
        return instance
    }()

    override init() {

        let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroups)
        let databaseFileUrlPath = dirGroup?.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud + "/" + NCGlobal.shared.databaseDefault)

        let bundleUrl: URL = Bundle.main.bundleURL
        let bundlePathExtension: String = bundleUrl.pathExtension
        let isAppex: Bool = bundlePathExtension == "appex"

        if let databaseFilePath = databaseFileUrlPath?.path {
            if FileManager.default.fileExists(atPath: databaseFilePath) {
                NKCommon.shared.writeLog("DATABASE FOUND in " + databaseFilePath)
            } else {
                NKCommon.shared.writeLog("DATABASE NOT FOUND in " + databaseFilePath)
            }
        }

        // Disable file protection for directory DB
        // https://docs.mongodb.com/realm/sdk/ios/examples/configure-and-open-a-realm/#std-label-ios-open-a-local-realm
        if let folderPathURL = dirGroup?.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud) {
            let folderPath = folderPathURL.path
            do {
                try FileManager.default.setAttributes([FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: folderPath)
            } catch {
                print("Dangerous error")
            }
        }

        if isAppex {

            // App Extension config

            let config = Realm.Configuration(
                fileURL: dirGroup?.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud + "/" + NCGlobal.shared.databaseDefault),
                schemaVersion: NCGlobal.shared.databaseSchemaVersion,
                objectTypes: [tableMetadata.self, tableLocalFile.self, tableDirectory.self, tableTag.self, tableAccount.self, tableCapabilities.self, tablePhotoLibrary.self, tableE2eEncryption.self, tableE2eEncryptionLock.self, tableShare.self, tableChunk.self, tableAvatar.self, tableDashboardWidget.self, tableDashboardWidgetButton.self, NCDBLayoutForView.self]
            )

            Realm.Configuration.defaultConfiguration = config

        } else {

            // App config

            let configCompact = Realm.Configuration(

                fileURL: databaseFileUrlPath,
                schemaVersion: NCGlobal.shared.databaseSchemaVersion,

                migrationBlock: { migration, oldSchemaVersion in

                    if oldSchemaVersion < 255 {
                        migration.deleteData(forType: tableActivity.className())
                        migration.deleteData(forType: tableActivityLatestId.className())
                        migration.deleteData(forType: tableActivityPreview.className())
                        migration.deleteData(forType: tableActivitySubjectRich.className())
                        migration.deleteData(forType: tableDirectory.className())
                        migration.deleteData(forType: tableMetadata.className())
                    }

                }, shouldCompactOnLaunch: { totalBytes, usedBytes in

                    // totalBytes refers to the size of the file on disk in bytes (data + free space)
                    // usedBytes refers to the number of bytes used by data in the file

                    // Compact if the file is over 100MB in size and less than 50% 'used'
                    let oneHundredMB = 100 * 1024 * 1024
                    return (totalBytes > oneHundredMB) && (Double(usedBytes) / Double(totalBytes)) < 0.5
                }
            )

            do {
                _ = try Realm(configuration: configCompact)
            } catch {
                if let databaseFileUrlPath = databaseFileUrlPath {
                    do {
                        #if !EXTENSION
                        let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_database_corrupt_")
                        NCContentPresenter.shared.showError(error: error, priority: .max)
                        #endif
                        NKCommon.shared.writeLog("DATABASE CORRUPT: removed")
                        try FileManager.default.removeItem(at: databaseFileUrlPath)
                    } catch {}
                }
            }

            let config = Realm.Configuration(
                fileURL: dirGroup?.appendingPathComponent(NCGlobal.shared.appDatabaseNextcloud + "/" + NCGlobal.shared.databaseDefault),
                schemaVersion: NCGlobal.shared.databaseSchemaVersion
            )

            Realm.Configuration.defaultConfiguration = config
        }

        // Verify Database, if corrupt remove it
        do {
            _ = try Realm()
        } catch {
            if let databaseFileUrlPath = databaseFileUrlPath {
                do {
                    #if !EXTENSION
                    let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_database_corrupt_")
                    NCContentPresenter.shared.showError(error: error, priority: .max)
                    #endif
                    NKCommon.shared.writeLog("DATABASE CORRUPT: removed")
                    try FileManager.default.removeItem(at: databaseFileUrlPath)
                } catch {}
            }
        }

        // Open Real
        _ = try! Realm()
    }

    // MARK: -
    // MARK: Utility Database

    @objc func clearTable(_ table: Object.Type, account: String? = nil) {

        let realm = try! Realm()

        do {
            try realm.write {
                var results: Results<Object>

                if let account = account {
                    results = realm.objects(table).filter("account == %@", account)
                } else {
                    results = realm.objects(table)
                }

                realm.delete(results)
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func clearDatabase(account: String?, removeAccount: Bool) {

        self.clearTable(tableActivity.self, account: account)
        self.clearTable(tableActivityLatestId.self, account: account)
        self.clearTable(tableActivityPreview.self, account: account)
        self.clearTable(tableActivitySubjectRich.self, account: account)
        self.clearTable(tableAvatar.self)
        self.clearTable(tableCapabilities.self, account: account)
        self.clearTable(tableChunk.self, account: account)
        self.clearTable(tableComments.self, account: account)
        self.clearTable(tableDashboardWidget.self, account: account)
        self.clearTable(tableDashboardWidgetButton.self, account: account)
        self.clearTable(tableDirectEditingCreators.self, account: account)
        self.clearTable(tableDirectEditingEditors.self, account: account)
        self.clearTable(tableDirectory.self, account: account)
        self.clearTable(tableE2eEncryption.self, account: account)
        self.clearTable(tableE2eEncryptionLock.self, account: account)
        self.clearTable(tableExternalSites.self, account: account)
        self.clearTable(tableGPS.self, account: nil)
        self.clearTable(tableLocalFile.self, account: account)
        self.clearTable(tableMetadata.self, account: account)
        self.clearTable(tablePhotoLibrary.self, account: account)
        self.clearTable(tableShare.self, account: account)
        self.clearTable(tableTag.self, account: account)
        self.clearTable(tableTip.self)
        self.clearTable(tableTrash.self, account: account)
        self.clearTable(tableUserStatus.self, account: account)
        self.clearTable(tableVideo.self, account: account)

        if removeAccount {
            self.clearTable(tableAccount.self, account: account)
        }
    }

    @objc func removeDB() {

        let realmURL = Realm.Configuration.defaultConfiguration.fileURL!
        let realmURLs = [
            realmURL,
            realmURL.appendingPathExtension("lock"),
            realmURL.appendingPathExtension("note"),
            realmURL.appendingPathExtension("management")
        ]
        for URL in realmURLs {
            do {
                try FileManager.default.removeItem(at: URL)
            } catch let error {
                NKCommon.shared.writeLog("Could not write to database: \(error)")
            }
        }
    }

    @objc func getThreadConfined(_ object: Object) -> Any {

        // id tradeReference = [[NCManageDatabase shared] getThreadConfined:metadata];
        return ThreadSafeReference(to: object)
    }

    @objc func putThreadConfined(_ tableRef: Any) -> Object? {

        // tableMetadata *metadataThread = (tableMetadata *)[[NCManageDatabase shared] putThreadConfined:tradeReference];
        let realm = try! Realm()

        return realm.resolve(tableRef as! ThreadSafeReference<Object>)
    }

    @objc func isTableInvalidated(_ object: Object) -> Bool {

        return object.isInvalidated
    }

    // MARK: -
    // MARK: Table Avatar

    @objc func addAvatar(fileName: String, etag: String) {

        let realm = try! Realm()

        do {
            try realm.write {

                // Add new
                let addObject = tableAvatar()

                addObject.date = NSDate()
                addObject.etag = etag
                addObject.fileName = fileName
                addObject.loaded = true

                realm.add(addObject, update: .all)
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    func getTableAvatar(fileName: String) -> tableAvatar? {

        let realm = try! Realm()

        guard let result = realm.objects(tableAvatar.self).filter("fileName == %@", fileName).first else {
            return nil
        }

        return tableAvatar.init(value: result)
    }

    func clearAllAvatarLoaded() {

        let realm = try! Realm()

        do {
            try realm.write {

                let results = realm.objects(tableAvatar.self)
                for result in results {
                    result.loaded = false
                    realm.add(result, update: .all)
                }
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @discardableResult
    func setAvatarLoaded(fileName: String) -> UIImage? {

        let realm = try! Realm()
        let fileNameLocalPath = String(CCUtility.getDirectoryUserData()) + "/" + fileName
        var image: UIImage?

        do {
            try realm.write {
                if let result = realm.objects(tableAvatar.self).filter("fileName == %@", fileName).first {
                    if let imageAvatar = UIImage(contentsOfFile: fileNameLocalPath) {
                        result.loaded = true
                        image = imageAvatar
                    } else {
                        realm.delete(result)
                    }
                }
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }

        return image
    }

    func getImageAvatarLoaded(fileName: String) -> UIImage? {

        let realm = try! Realm()
        let fileNameLocalPath = String(CCUtility.getDirectoryUserData()) + "/" + fileName

        let result = realm.objects(tableAvatar.self).filter("fileName == %@", fileName).first
        if result == nil {
            NCUtilityFileSystem.shared.deleteFile(filePath: fileNameLocalPath)
            return nil
        } else if result?.loaded == false {
            return nil
        }

        return UIImage(contentsOfFile: fileNameLocalPath)
    }

    // MARK: -
    // MARK: Table Capabilities

    @objc func addCapabilitiesJSon(_ data: Data, account: String) {

        let realm = try! Realm()

        do {
            try realm.write {
                let addObject = tableCapabilities()

                addObject.account = account
                addObject.jsondata = data

                realm.add(addObject, update: .all)
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func getCapabilities(account: String) -> String? {

        let realm = try! Realm()

        guard let result = realm.objects(tableCapabilities.self).filter("account == %@", account).first else {
            return nil
        }
        guard let jsondata = result.jsondata else {
            return nil
        }

        let json = JSON(jsondata)

        return json.rawString()?.replacingOccurrences(of: "\\/", with: "/")
    }

    @objc func getCapabilitiesServerString(account: String, elements: [String]) -> String? {

        let realm = try! Realm()

        guard let result = realm.objects(tableCapabilities.self).filter("account == %@", account).first else {
            return nil
        }
        guard let jsondata = result.jsondata else {
            return nil
        }

        let json = JSON(jsondata)
        return json[elements].string
    }

    @objc func getCapabilitiesServerInt(account: String, elements: [String]) -> Int {

        let realm = try! Realm()

        guard let result = realm.objects(tableCapabilities.self).filter("account == %@", account).first,
              let jsondata = result.jsondata else {
            return 0
        }

        let json = JSON(jsondata)
        return json[elements].intValue
    }

    @objc func getCapabilitiesServerBool(account: String, elements: [String], exists: Bool) -> Bool {

        let realm = try! Realm()

        guard let result = realm.objects(tableCapabilities.self).filter("account == %@", account).first else {
            return false
        }
        guard let jsondata = result.jsondata else {
            return false
        }

        let json = JSON(jsondata)
        if exists {
            return json[elements].exists()
        } else {
            return json[elements].boolValue
        }
    }

    @objc func getCapabilitiesServerArray(account: String, elements: [String]) -> [String]? {

        let realm = try! Realm()
        var resultArray: [String] = []

        guard let result = realm.objects(tableCapabilities.self).filter("account == %@", account).first else {
            return nil
        }
        guard let jsondata = result.jsondata else {
            return nil
        }

        let json = JSON(jsondata)

        if let results = json[elements].array {
            for result in results {
                resultArray.append(result.string ?? "")
            }
            return resultArray
        }

        return nil
    }

    // MARK: -
    // MARK: Table Chunk

    func getChunkFolder(account: String, ocId: String) -> String {

        let realm = try! Realm()

        if let result = realm.objects(tableChunk.self).filter("account == %@ AND ocId == %@", account, ocId).first {
            return result.chunkFolder
        }

        return NSUUID().uuidString
    }

    func getChunks(account: String, ocId: String) -> [String] {

        let realm = try! Realm()
        var filesNames: [String] = []

        let results = realm.objects(tableChunk.self).filter("account == %@ AND ocId == %@", account, ocId).sorted(byKeyPath: "fileName", ascending: true)
        for result in results {
            filesNames.append(result.fileName)
        }

        return filesNames
    }

    func addChunks(account: String, ocId: String, chunkFolder: String, fileNames: [String]) {

        let realm = try! Realm()
        var size: Int64 = 0

        do {
            try realm.write {

                for fileName in fileNames {

                    let object = tableChunk()
                    size += NCUtilityFileSystem.shared.getFileSize(filePath: CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileName)!)

                    object.account = account
                    object.chunkFolder = chunkFolder
                    object.fileName = fileName
                    object.index = ocId + fileName
                    object.ocId = ocId
                    object.size = size

                    realm.add(object, update: .all)
                }
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    func getChunk(account: String, fileName: String) -> tableChunk? {

        let realm = try! Realm()

        if let result = realm.objects(tableChunk.self).filter("account == %@ AND fileName == %@", account, fileName).first {
            return tableChunk.init(value: result)
        } else {
            return nil
        }
    }

    func deleteChunk(account: String, ocId: String, fileName: String) {

        let realm = try! Realm()

        do {
            try realm.write {

                let result = realm.objects(tableChunk.self).filter(NSPredicate(format: "account == %@ AND ocId == %@ AND fileName == %@", account, ocId, fileName))
                realm.delete(result)
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    func deleteChunks(account: String, ocId: String) {

        let realm = try! Realm()

        do {
            try realm.write {

                let result = realm.objects(tableChunk.self).filter(NSPredicate(format: "account == %@ AND ocId == %@", account, ocId))
                realm.delete(result)
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    // MARK: -
    // MARK: Table Direct Editing

    @objc func addDirectEditing(account: String, editors: [NKEditorDetailsEditors], creators: [NKEditorDetailsCreators]) {

        let realm = try! Realm()

        do {
            try realm.write {

                let resultsCreators = realm.objects(tableDirectEditingCreators.self).filter("account == %@", account)
                realm.delete(resultsCreators)

                let resultsEditors = realm.objects(tableDirectEditingEditors.self).filter("account == %@", account)
                realm.delete(resultsEditors)

                for creator in creators {

                    let addObject = tableDirectEditingCreators()

                    addObject.account = account
                    addObject.editor = creator.editor
                    addObject.ext = creator.ext
                    addObject.identifier = creator.identifier
                    addObject.mimetype = creator.mimetype
                    addObject.name = creator.name
                    addObject.templates = creator.templates

                    realm.add(addObject)
                }

                for editor in editors {

                    let addObject = tableDirectEditingEditors()

                    addObject.account = account
                    for mimeType in editor.mimetypes {
                        addObject.mimetypes.append(mimeType)
                    }
                    addObject.name = editor.name
                    if editor.name.lowercased() == NCGlobal.shared.editorOnlyoffice {
                        addObject.editor = NCGlobal.shared.editorOnlyoffice
                    } else {
                        addObject.editor = NCGlobal.shared.editorText
                    }
                    for mimeType in editor.optionalMimetypes {
                        addObject.optionalMimetypes.append(mimeType)
                    }
                    addObject.secure = editor.secure

                    realm.add(addObject)
                }
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func getDirectEditingCreators(account: String) -> [tableDirectEditingCreators]? {

        let realm = try! Realm()
        let results = realm.objects(tableDirectEditingCreators.self).filter("account == %@", account)

        if results.count > 0 {
            return Array(results.map { tableDirectEditingCreators.init(value: $0) })
        } else {
            return nil
        }
    }

    @objc func getDirectEditingCreators(predicate: NSPredicate) -> [tableDirectEditingCreators]? {

        let realm = try! Realm()

        let results = realm.objects(tableDirectEditingCreators.self).filter(predicate)

        if results.count > 0 {
            return Array(results.map { tableDirectEditingCreators.init(value: $0) })
        } else {
            return nil
        }
    }

    @objc func getDirectEditingEditors(account: String) -> [tableDirectEditingEditors]? {

        let realm = try! Realm()
        let results = realm.objects(tableDirectEditingEditors.self).filter("account == %@", account)

        if results.count > 0 {
            return Array(results.map { tableDirectEditingEditors.init(value: $0) })
        } else {
            return nil
        }
    }

    // MARK: -
    // MARK: Table e2e Encryption

    @objc func addE2eEncryption(_ e2e: tableE2eEncryption) {

        let realm = try! Realm()

        do {
            try realm.write {
                realm.add(e2e, update: .all)
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func deleteE2eEncryption(predicate: NSPredicate) {

        let realm = try! Realm()

        do {
            try realm.write {

                let results = realm.objects(tableE2eEncryption.self).filter(predicate)
                realm.delete(results)
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func getE2eEncryption(predicate: NSPredicate) -> tableE2eEncryption? {

        let realm = try! Realm()

        guard let result = realm.objects(tableE2eEncryption.self).filter(predicate).sorted(byKeyPath: "metadataKeyIndex", ascending: false).first else {
            return nil
        }

        return tableE2eEncryption.init(value: result)
    }

    @objc func getE2eEncryptions(predicate: NSPredicate) -> [tableE2eEncryption]? {

        guard self.getActiveAccount() != nil else {
            return nil
        }

        let realm = try! Realm()

        let results: Results<tableE2eEncryption>

        results = realm.objects(tableE2eEncryption.self).filter(predicate)

        if results.count > 0 {
            return Array(results.map { tableE2eEncryption.init(value: $0) })
        } else {
            return nil
        }
    }

    @objc func renameFileE2eEncryption(serverUrl: String, fileNameIdentifier: String, newFileName: String, newFileNamePath: String) {

        guard let activeAccount = self.getActiveAccount() else {
            return
        }

        let realm = try! Realm()

        realm.beginWrite()

        guard let result = realm.objects(tableE2eEncryption.self).filter("account == %@ AND serverUrl == %@ AND fileNameIdentifier == %@", activeAccount.account, serverUrl, fileNameIdentifier).first else {
            realm.cancelWrite()
            return
        }

        let object = tableE2eEncryption.init(value: result)

        realm.delete(result)

        object.fileName = newFileName
        object.fileNamePath = newFileNamePath

        realm.add(object)

        do {
            try realm.commitWrite()
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    // MARK: -
    // MARK: Table e2e Encryption Lock

    @objc func getE2ETokenLock(account: String, serverUrl: String) -> tableE2eEncryptionLock? {

        let realm = try! Realm()

        guard let result = realm.objects(tableE2eEncryptionLock.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).first else {
            return nil
        }

        return tableE2eEncryptionLock.init(value: result)
    }

    @objc func getE2EAllTokenLock(account: String) -> [tableE2eEncryptionLock] {

        let realm = try! Realm()

        let results = realm.objects(tableE2eEncryptionLock.self).filter("account == %@", account)

        if results.count > 0 {
            return Array(results.map { tableE2eEncryptionLock.init(value: $0) })
        } else {
            return []
        }
    }

    @objc func setE2ETokenLock(account: String, serverUrl: String, fileId: String, e2eToken: String) {

        let realm = try! Realm()

        do {
            try realm.write {
                let addObject = tableE2eEncryptionLock()

                addObject.account = account
                addObject.fileId = fileId
                addObject.serverUrl = serverUrl
                addObject.e2eToken = e2eToken

                realm.add(addObject, update: .all)
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func deleteE2ETokenLock(account: String, serverUrl: String) {

        let realm = try! Realm()

        do {
            try realm.write {
                if let result = realm.objects(tableE2eEncryptionLock.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).first {
                    realm.delete(result)
                }
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    // MARK: -
    // MARK: Table External Sites

    @objc func addExternalSites(_ externalSite: NKExternalSite, account: String) {

        let realm = try! Realm()

        do {
            try realm.write {
                let addObject = tableExternalSites()

                addObject.account = account
                addObject.idExternalSite = externalSite.idExternalSite
                addObject.icon = externalSite.icon
                addObject.lang = externalSite.lang
                addObject.name = externalSite.name
                addObject.url = externalSite.url
                addObject.type = externalSite.type

                realm.add(addObject)
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func deleteExternalSites(account: String) {

        let realm = try! Realm()

        do {
            try realm.write {
                let results = realm.objects(tableExternalSites.self).filter("account == %@", account)
                realm.delete(results)
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func getAllExternalSites(account: String) -> [tableExternalSites]? {

        let realm = try! Realm()

        let results = realm.objects(tableExternalSites.self).filter("account == %@", account).sorted(byKeyPath: "idExternalSite", ascending: true)

        if results.count > 0 {
            return Array(results.map { tableExternalSites.init(value: $0) })
        } else {
            return nil
        }
    }

    // MARK: -
    // MARK: Table GPS

    @objc func addGeocoderLocation(_ location: String, placemarkAdministrativeArea: String, placemarkCountry: String, placemarkLocality: String, placemarkPostalCode: String, placemarkThoroughfare: String, latitude: String, longitude: String) {

        let realm = try! Realm()

        realm.beginWrite()

        // Verify if exists
        guard realm.objects(tableGPS.self).filter("latitude == %@ AND longitude == %@", latitude, longitude).first == nil else {
            realm.cancelWrite()
            return
        }

        // Add new GPS
        let addObject = tableGPS()

        addObject.latitude = latitude
        addObject.location = location
        addObject.longitude = longitude
        addObject.placemarkAdministrativeArea = placemarkAdministrativeArea
        addObject.placemarkCountry = placemarkCountry
        addObject.placemarkLocality = placemarkLocality
        addObject.placemarkPostalCode = placemarkPostalCode
        addObject.placemarkThoroughfare = placemarkThoroughfare

        realm.add(addObject)

        do {
            try realm.commitWrite()
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func getLocationFromGeoLatitude(_ latitude: String, longitude: String) -> String? {

        let realm = try! Realm()

        let result = realm.objects(tableGPS.self).filter("latitude == %@ AND longitude == %@", latitude, longitude).first
        return result?.location
    }

    // MARK: -
    // MARK: Table LocalFile

    func addLocalFile(metadata: tableMetadata) {

        let realm = try! Realm()

        do {
            try realm.write {

                let addObject = getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) ?? tableLocalFile()

                addObject.account = metadata.account
                addObject.etag = metadata.etag
                addObject.exifDate = NSDate()
                addObject.exifLatitude = "-1"
                addObject.exifLongitude = "-1"
                addObject.ocId = metadata.ocId
                addObject.fileName = metadata.fileName

                realm.add(addObject, update: .all)
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    func addLocalFile(account: String, etag: String, ocId: String, fileName: String) {

        let realm = try! Realm()

        do {
            try realm.write {

                let addObject = tableLocalFile()

                addObject.account = account
                addObject.etag = etag
                addObject.exifDate = NSDate()
                addObject.exifLatitude = "-1"
                addObject.exifLongitude = "-1"
                addObject.ocId = ocId
                addObject.fileName = fileName

                realm.add(addObject, update: .all)
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func deleteLocalFile(predicate: NSPredicate) {

        let realm = try! Realm()

        do {
            try realm.write {
                let results = realm.objects(tableLocalFile.self).filter(predicate)
                realm.delete(results)
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func setLocalFile(ocId: String, fileName: String?, etag: String?) {

        let realm = try! Realm()

        do {
            try realm.write {
                let result = realm.objects(tableLocalFile.self).filter("ocId == %@", ocId).first
                if let fileName = fileName {
                    result?.fileName = fileName
                }
                if let etag = etag {
                    result?.etag = etag
                }
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func setLocalFile(ocId: String, exifDate: NSDate?, exifLatitude: String, exifLongitude: String, exifLensModel: String?) {

        let realm = try! Realm()

        do {
            try realm.write {
                if let result = realm.objects(tableLocalFile.self).filter("ocId == %@", ocId).first {
                    result.exifDate = exifDate
                    result.exifLatitude = exifLatitude
                    result.exifLongitude = exifLongitude
                    if exifLensModel?.count ?? 0 > 0 {
                        result.exifLensModel = exifLensModel
                    }
                }
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func getTableLocalFile(account: String) -> [tableLocalFile] {

        let realm = try! Realm()

        let results = realm.objects(tableLocalFile.self).filter("account == %@", account)
        return Array(results.map { tableLocalFile.init(value: $0) })
    }

    @objc func getTableLocalFile(predicate: NSPredicate) -> tableLocalFile? {

        let realm = try! Realm()

        guard let result = realm.objects(tableLocalFile.self).filter(predicate).first else {
            return nil
        }

        return tableLocalFile.init(value: result)
    }

    @objc func getTableLocalFiles(predicate: NSPredicate, sorted: String, ascending: Bool) -> [tableLocalFile] {

        let realm = try! Realm()

        let results = realm.objects(tableLocalFile.self).filter(predicate).sorted(byKeyPath: sorted, ascending: ascending)
        return Array(results.map { tableLocalFile.init(value: $0) })
    }

    @objc func setLocalFile(ocId: String, offline: Bool) {

        let realm = try! Realm()

        do {
            try realm.write {
                let result = realm.objects(tableLocalFile.self).filter("ocId == %@", ocId).first
                result?.offline = offline
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    // MARK: -
    // MARK: Table Photo Library

    @discardableResult
    @objc func addPhotoLibrary(_ assets: [PHAsset], account: String) -> Bool {

        let realm = try! Realm()

        do {
            try realm.write {

                for asset in assets {

                    var creationDateString = ""
                    let addObject = tablePhotoLibrary()

                    addObject.account = account
                    addObject.assetLocalIdentifier = asset.localIdentifier
                    addObject.mediaType = asset.mediaType.rawValue
                    if let creationDate = asset.creationDate {
                        addObject.creationDate = creationDate as NSDate
                        creationDateString = String(describing: creationDate)
                    }
                    if let modificationDate = asset.modificationDate {
                        addObject.modificationDate = modificationDate as NSDate
                    }
                    addObject.idAsset = account + asset.localIdentifier + creationDateString

                    realm.add(addObject, update: .all)
                }
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
            return false
        }

        return true
    }

    @objc func getPhotoLibraryIdAsset(image: Bool, video: Bool, account: String) -> [String]? {

        let realm = try! Realm()
        var predicate = NSPredicate()

        if image && video {

            predicate = NSPredicate(format: "account == %@ AND (mediaType == %d OR mediaType == %d)", account, PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)

        } else if image {

            predicate = NSPredicate(format: "account == %@ AND mediaType == %d", account, PHAssetMediaType.image.rawValue)

        } else if video {

            predicate = NSPredicate(format: "account == %@ AND mediaType == %d", account, PHAssetMediaType.video.rawValue)
        }

        let results = realm.objects(tablePhotoLibrary.self).filter(predicate)

        let idsAsset = results.map { $0.idAsset }

        return Array(idsAsset)
    }

    // MARK: -
    // MARK: Table Share

    @objc func addShare(account: String, home: String, shares: [NKShare]) {

        let realm = try! Realm()

        do {
            try realm.write {

                for share in shares {

                    let serverUrlPath = home + share.path
                    guard let serverUrl = NCUtilityFileSystem.shared.deleteLastPath(serverUrlPath: serverUrlPath, home: home) else {
                        continue
                    }

                    let object = tableShare()

                    object.account = account
                    if let fileName = share.path.components(separatedBy: "/").last {
                        object.fileName = fileName
                    }
                    object.serverUrl = serverUrl

                    object.canEdit = share.canEdit
                    object.canDelete = share.canDelete
                    object.date = share.date
                    object.displaynameFileOwner = share.displaynameFileOwner
                    object.displaynameOwner = share.displaynameOwner
                    object.expirationDate = share.expirationDate
                    object.fileParent = share.fileParent
                    object.fileSource = share.fileSource
                    object.fileTarget = share.fileTarget
                    object.hideDownload = share.hideDownload
                    object.idShare = share.idShare
                    object.itemSource = share.itemSource
                    object.itemType = share.itemType
                    object.label = share.label
                    object.mailSend = share.mailSend
                    object.mimeType = share.mimeType
                    object.note = share.note
                    object.parent = share.parent
                    object.password = share.password
                    object.path = share.path
                    object.permissions = share.permissions
                    object.primaryKey = account + " " + String(share.idShare)
                    object.sendPasswordByTalk = share.sendPasswordByTalk
                    object.shareType = share.shareType
                    object.shareWith = share.shareWith
                    object.shareWithDisplayname = share.shareWithDisplayname
                    object.storage = share.storage
                    object.storageId = share.storageId
                    object.token = share.token
                    object.uidOwner = share.uidOwner
                    object.uidFileOwner = share.uidFileOwner
                    object.url = share.url
                    object.userClearAt = share.userClearAt
                    object.userIcon = share.userIcon
                    object.userMessage = share.userMessage
                    object.userStatus = share.userStatus

                    realm.add(object, update: .all)
                }
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func getTableShares(account: String) -> [tableShare] {

        let realm = try! Realm()

        let sortProperties = [SortDescriptor(keyPath: "shareType", ascending: false), SortDescriptor(keyPath: "idShare", ascending: false)]
        let results = realm.objects(tableShare.self).filter("account == %@", account).sorted(by: sortProperties)

        return Array(results.map { tableShare.init(value: $0) })
    }

    func getTableShares(metadata: tableMetadata) -> (firstShareLink: tableShare?, share: [tableShare]?) {

        let realm = try! Realm()

        let sortProperties = [SortDescriptor(keyPath: "shareType", ascending: false), SortDescriptor(keyPath: "idShare", ascending: false)]
        let firstShareLink = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@ AND shareType == 3", metadata.account, metadata.serverUrl, metadata.fileName).first

        if let firstShareLink = firstShareLink {
            let results = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@ AND idShare != %d", metadata.account, metadata.serverUrl, metadata.fileName, firstShareLink.idShare).sorted(by: sortProperties)
            return(firstShareLink: tableShare.init(value: firstShareLink), share: Array(results.map { tableShare.init(value: $0) }))
        } else {
            let results = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, metadata.fileName).sorted(by: sortProperties)
            return(firstShareLink: firstShareLink, share: Array(results.map { tableShare.init(value: $0) }))
        }
    }

    func getTableShare(account: String, idShare: Int) -> tableShare? {

        let realm = try! Realm()

        guard let result = realm.objects(tableShare.self).filter("account = %@ AND idShare = %d", account, idShare).first else {
            return nil
        }

        return tableShare.init(value: result)
    }

    @objc func getTableShares(account: String, serverUrl: String) -> [tableShare] {

        let realm = try! Realm()

        let sortProperties = [SortDescriptor(keyPath: "shareType", ascending: false), SortDescriptor(keyPath: "idShare", ascending: false)]
        let results = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@", account, serverUrl).sorted(by: sortProperties)

        return Array(results.map { tableShare.init(value: $0) })
    }

    @objc func getTableShares(account: String, serverUrl: String, fileName: String) -> [tableShare] {

        let realm = try! Realm()

        let sortProperties = [SortDescriptor(keyPath: "shareType", ascending: false), SortDescriptor(keyPath: "idShare", ascending: false)]
        let results = realm.objects(tableShare.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@", account, serverUrl, fileName).sorted(by: sortProperties)

        return Array(results.map { tableShare.init(value: $0) })
    }

    @objc func deleteTableShare(account: String, idShare: Int) {

        let realm = try! Realm()

        realm.beginWrite()

        let result = realm.objects(tableShare.self).filter("account == %@ AND idShare == %d", account, idShare)
        realm.delete(result)

        do {
            try realm.commitWrite()
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func deleteTableShare(account: String) {

        let realm = try! Realm()

        realm.beginWrite()

        let result = realm.objects(tableShare.self).filter("account == %@", account)
        realm.delete(result)

        do {
            try realm.commitWrite()
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    // MARK: -
    // MARK: Table Tag

    @objc func addTag(_ ocId: String, tagIOS: Data?, account: String) {

        let realm = try! Realm()

        do {
            try realm.write {

                // Add new
                let addObject = tableTag()

                addObject.account = account
                addObject.ocId = ocId
                addObject.tagIOS = tagIOS

                realm.add(addObject, update: .all)
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func deleteTag(_ ocId: String) {

        let realm = try! Realm()

        realm.beginWrite()

        let result = realm.objects(tableTag.self).filter("ocId == %@", ocId)
        realm.delete(result)

        do {
            try realm.commitWrite()
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func getTags(predicate: NSPredicate) -> [tableTag] {

        let realm = try! Realm()

        let results = realm.objects(tableTag.self).filter(predicate)

        return Array(results.map { tableTag.init(value: $0) })
    }

    @objc func getTag(predicate: NSPredicate) -> tableTag? {

        let realm = try! Realm()

        guard let result = realm.objects(tableTag.self).filter(predicate).first else {
            return nil
        }

        return tableTag.init(value: result)
    }

    // MARK: -
    // MARK: Table Tip

    @objc func tipExists(_ tipName: String) -> Bool {

        let realm = try! Realm()

        guard (realm.objects(tableTip.self).where {
            $0.tipName == tipName
        }.first) == nil else {
            return true
        }

        return false
    }

    @objc func addTip(_ tipName: String) {

        let realm = try! Realm()

        do {
            try realm.write {
                let addObject = tableTip()
                addObject.tipName = tipName
                realm.add(addObject, update: .all)
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    // MARK: -
    // MARK: Table Trash

    @objc func addTrash(account: String, items: [NKTrash]) {

        let realm = try! Realm()

        do {
            try realm.write {
                for trash in items {
                    let object = tableTrash()

                    object.account = account
                    object.contentType = trash.contentType
                    object.date = trash.date
                    object.directory = trash.directory
                    object.fileId = trash.fileId
                    object.fileName = trash.fileName
                    object.filePath = trash.filePath
                    object.hasPreview = trash.hasPreview
                    object.iconName = trash.iconName
                    object.size = trash.size
                    object.trashbinDeletionTime = trash.trashbinDeletionTime
                    object.trashbinFileName = trash.trashbinFileName
                    object.trashbinOriginalLocation = trash.trashbinOriginalLocation
                    object.classFile = trash.classFile

                    realm.add(object, update: .all)
                }
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func deleteTrash(filePath: String?, account: String) {

        let realm = try! Realm()
        var predicate = NSPredicate()

        do {
            try realm.write {

                if filePath == nil {
                    predicate = NSPredicate(format: "account == %@", account)
                } else {
                    predicate = NSPredicate(format: "account == %@ AND filePath == %@", account, filePath!)
                }

                let result = realm.objects(tableTrash.self).filter(predicate)
                realm.delete(result)
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    @objc func deleteTrash(fileId: String?, account: String) {

        let realm = try! Realm()
        var predicate = NSPredicate()

        do {
            try realm.write {

                if fileId == nil {
                    predicate = NSPredicate(format: "account == %@", account)
                } else {
                    predicate = NSPredicate(format: "account == %@ AND fileId == %@", account, fileId!)
                }

                let result = realm.objects(tableTrash.self).filter(predicate)
                realm.delete(result)
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }

    func getTrash(filePath: String, sort: String?, ascending: Bool?, account: String) -> [tableTrash]? {

        let realm = try! Realm()
        let sort = sort ?? "date"
        let ascending = ascending ?? false

        let results = realm.objects(tableTrash.self).filter("account == %@ AND filePath == %@", account, filePath).sorted(byKeyPath: sort, ascending: ascending)

        return Array(results.map { tableTrash.init(value: $0) })
    }

    @objc func getTrashItem(fileId: String, account: String) -> tableTrash? {

        let realm = try! Realm()

        guard let result = realm.objects(tableTrash.self).filter("account == %@ AND fileId == %@", account, fileId).first else {
            return nil
        }

        return tableTrash.init(value: result)
    }

    // MARK: -
    // MARK: Table UserStatus

    @objc func addUserStatus(_ userStatuses: [NKUserStatus], account: String, predefined: Bool) {

        let realm = try! Realm()

        do {
            try realm.write {

                let results = realm.objects(tableUserStatus.self).filter("account == %@ AND predefined == %@", account, predefined)
                realm.delete(results)

                for userStatus in userStatuses {

                    let object = tableUserStatus()

                    object.account = account
                    object.clearAt = userStatus.clearAt
                    object.clearAtTime = userStatus.clearAtTime
                    object.clearAtType = userStatus.clearAtType
                    object.icon = userStatus.icon
                    object.id = userStatus.id
                    object.message = userStatus.message
                    object.predefined = userStatus.predefined
                    object.status = userStatus.status
                    object.userId = userStatus.userId

                    realm.add(object)
                }
            }
        } catch let error {
            NKCommon.shared.writeLog("Could not write to database: \(error)")
        }
    }
}
