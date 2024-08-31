//
//  NCManageDatabase+Metadata+Result.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 31/08/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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
import UIKit
import RealmSwift
import NextcloudKit

extension NCManageDatabase {
    func addMetadatas(_ metadatas: [tableMetadata]) {
        do {
            let realm = try Realm()
            try realm.write {
                realm.add(metadatas, update: .all)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func deleteMetadata(predicate: NSPredicate) {
        do {
            let realm = try Realm()
            try realm.write {
                let results = realm.objects(tableMetadata.self).filter(predicate)
                realm.delete(results)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func deleteMetadataOcId(_ ocId: String?) {
        guard let ocId else { return }

        do {
            let realm = try Realm()
            try realm.write {
                let results = realm.objects(tableMetadata.self).filter("ocId == %@", ocId)
                realm.delete(results)
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
    }

    func deleteMetadata(results: Results<tableMetadata>) {
        do {
            let realm = try Realm()
            try realm.write {
                realm.delete(results)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func renameMetadata(fileNameTo: String, ocId: String, account: String) {
        do {
            let realm = try Realm()
            try realm.write {
                if let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first {
                    let resultsType = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: fileNameTo, mimeType: "", directory: result.directory, account: account)
                    result.fileName = fileNameTo
                    result.fileNameView = fileNameTo
                    result.iconName = resultsType.iconName
                    result.contentType = resultsType.mimeType
                    result.classFile = resultsType.classFile
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func setMetadataEtagResource(ocId: String, etagResource: String?) {
        guard let etagResource = etagResource else { return }

        do {
            let realm = try Realm()
            try realm.write {
                let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                result?.etagResource = etagResource
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func setMetadataLivePhotoByServer(account: String, ocId: String, livePhotoFile: String) {
        do {
            let realm = try Realm()
            try realm.write {
                if let result = realm.objects(tableMetadata.self).filter("account == %@ AND ocId == %@", account, ocId).first {
                    result.isFlaggedAsLivePhotoByServer = true
                    result.livePhotoFile = livePhotoFile
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func updateMetadatasFavorite(account: String, metadatas: [tableMetadata]) {
        do {
            let realm = try Realm()
            try realm.write {
                let results = realm.objects(tableMetadata.self).filter("account == %@ AND favorite == true", account)
                for result in results {
                    result.favorite = false
                }
                for metadata in metadatas {
                    if let result = realm.objects(tableMetadata.self).filter("account == %@ AND ocId == %@", account, metadata.ocId).first {
                        result.favorite = true
                    } else {
                        realm.add(metadata, update: .modified)
                    }
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func setMetadataEncrypted(ocId: String, encrypted: Bool) {
        do {
            let realm = try Realm()
            try realm.write {
                let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first
                result?.e2eEncrypted = encrypted
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func setMetadataFileNameView(serverUrl: String, fileName: String, newFileNameView: String, account: String) {
        do {
            let realm = try Realm()
            try realm.write {
                let result = realm.objects(tableMetadata.self).filter("account == %@ AND serverUrl == %@ AND fileName == %@", account, serverUrl, fileName).first
                result?.fileNameView = newFileNameView
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func getResultsMetadatasAccount(_ account: String, serverUrl: String, layoutForView: NCDBLayoutForView?) -> [tableMetadata] {
        let predicate = NSPredicate(format: "account == %@ AND serverUrl == %@ AND NOT (status IN %@) AND NOT (livePhotoFile != '' AND classFile == %@)", account, serverUrl, NCGlobal.shared.metadataStatusFileUp, NKCommon.TypeClassFile.video.rawValue)

        do {
            let realm = try Realm()
            var results = realm.objects(tableMetadata.self).filter(predicate)
            if let layoutForView {
                if layoutForView.directoryOnTop {
                    results = results.sorted(byKeyPath: layoutForView.sort, ascending: layoutForView.ascending).sorted(byKeyPath: "directory", ascending: false).sorted(byKeyPath: "favorite", ascending: false)
                } else {
                    results = results.sorted(byKeyPath: layoutForView.sort, ascending: layoutForView.ascending).sorted(byKeyPath: "favorite", ascending: false)
                }
            }
            return Array(results)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return []
    }

    func getResultsMetadatas(predicate: NSPredicate, sortedByKeyPath: String, ascending: Bool, arraySlice: Int = 0) -> [tableMetadata] {
        do {
            let realm = try Realm()
            let results = realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sortedByKeyPath, ascending: ascending).prefix(arraySlice)
            return Array(results)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return []
    }

    func getResultsMetadatas(predicate: NSPredicate, sortedByKeyPath: String? = nil, ascending: Bool = false) -> Results<tableMetadata>? {
        do {
            let realm = try Realm()
            if let sortedByKeyPath {
                return realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: sortedByKeyPath, ascending: ascending)
            } else {
                return realm.objects(tableMetadata.self).filter(predicate)
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getResultMetadata(predicate: NSPredicate) -> tableMetadata? {
        do {
            let realm = try Realm()
            return realm.objects(tableMetadata.self).filter(predicate).first
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getResultMetadataFromFileName(_ fileName: String, serverUrl: String, sessionTaskIdentifier: Int) -> tableMetadata? {
        do {
            let realm = try Realm()
            return realm.objects(tableMetadata.self).filter("fileName == %@ AND serverUrl == %@ AND sessionTaskIdentifier == %d", fileName, serverUrl, sessionTaskIdentifier).first
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getResultsMetadatasFromGroupfolders(session: NCSession.Session) -> [tableMetadata] {
        var metadatas: [tableMetadata] = []
        let homeServerUrl = utilityFileSystem.getHomeServer(session: session)

        do {
            let realm = try Realm()
            let groupfolders = realm.objects(TableGroupfolders.self).filter("account == %@", session.account)
            for groupfolder in groupfolders {
                let mountPoint = groupfolder.mountPoint.hasPrefix("/") ? groupfolder.mountPoint : "/" + groupfolder.mountPoint
                let serverUrlFileName = homeServerUrl + mountPoint
                if let directory = realm.objects(tableDirectory.self).filter("account == %@ AND serverUrl == %@", session.account, serverUrlFileName).first,
                   let metadata = realm.objects(tableMetadata.self).filter("ocId == %@", directory.ocId).first {
                    metadatas.append(metadata)
                }
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return metadatas
    }

    func getResultsMediaMetadatas(predicate: NSPredicate) -> Results<tableMetadata>? {
        do {
            let realm = try Realm()
            return realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: "date", ascending: false)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func getResultsImageCacheMetadatas(predicate: NSPredicate) -> Results<tableMetadata>? {
        do {
            let realm = try Realm()
            return realm.objects(tableMetadata.self).filter(predicate).sorted(byKeyPath: "date", ascending: false)
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func moveMetadata(ocId: String, serverUrlTo: String) {
        do {
            let realm = try Realm()
            try realm.write {
                if let result = realm.objects(tableMetadata.self).filter("ocId == %@", ocId).first {
                    result.serverUrl = serverUrlTo
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func getTableMetadatasDirectoryFavoriteIdentifierRank(account: String) -> [String: NSNumber] {
        var listIdentifierRank: [String: NSNumber] = [:]
        var counter = 10 as Int64

        do {
            let realm = try Realm()
            let results = realm.objects(tableMetadata.self).filter("account == %@ AND directory == true AND favorite == true", account).sorted(byKeyPath: "fileNameView", ascending: true)
            for result in results {
                counter += 1
                listIdentifierRank[result.ocId] = NSNumber(value: Int64(counter))
            }
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return listIdentifierRank
    }

    func clearMetadatasUpload(account: String) {
        do {
            let realm = try Realm()
            try realm.write {
                let results = realm.objects(tableMetadata.self).filter("account == %@ AND (status == %d OR status == %d)", account, NCGlobal.shared.metadataStatusWaitUpload, NCGlobal.shared.metadataStatusUploadError)
                realm.delete(results)
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }

    func getAssetLocalIdentifiersUploaded() -> [String]? {
        var assetLocalIdentifiers: [String] = []

        do {
            let realm = try Realm()
            let results = realm.objects(tableMetadata.self).filter("assetLocalIdentifier != ''")
            for result in results {
                assetLocalIdentifiers.append(result.assetLocalIdentifier)
            }
            return assetLocalIdentifiers
        } catch let error as NSError {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not access database: \(error)")
        }
        return nil
    }

    func clearAssetLocalIdentifiers(_ assetLocalIdentifiers: [String]) {
        do {
            let realm = try Realm()
            try realm.write {
                let results = realm.objects(tableMetadata.self).filter("assetLocalIdentifier IN %@", assetLocalIdentifiers)
                for result in results {
                    result.assetLocalIdentifier = ""
                }
            }
        } catch let error {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Could not write to database: \(error)")
        }
    }
}
