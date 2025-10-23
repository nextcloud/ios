// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

class tableLivePhoto: Object {
    @Persisted(primaryKey: true) var primaryKey: String
    @Persisted var account: String
    @Persisted var serverUrlFileNameNoExt: String
    @Persisted var serverUrlFileNameImage: String = ""
    @Persisted var serverUrlFileNameVideo: String = ""
    @Persisted var fileIdImage: String = ""
    @Persisted var fileIdVideo: String = ""
    @Persisted var errorCount: Int = 0

    convenience init(account: String, serverUrlFileNameNoExt: String) {
        self.init()

        self.primaryKey = account + serverUrlFileNameNoExt
        self.account = account
        self.serverUrlFileNameNoExt = serverUrlFileNameNoExt
    }
}

extension NCManageDatabase {

    // MARK: - Realm Write

    func setLivePhotoVideo(metadatas: [tableMetadata]) async {
        guard !metadatas.isEmpty else {
            return
        }

        await performRealmWriteAsync { realm in
            for metadata in metadatas {
                let serverUrlFileNameNoExt = (metadata.serverUrlFileName as NSString).deletingPathExtension
                let primaryKey = metadata.account + serverUrlFileNameNoExt
                if let result = realm.object(ofType: tableLivePhoto.self, forPrimaryKey: primaryKey) {
                    if metadata.isVideo {
                        // Update existing (only the provided fields)
                        result.serverUrlFileNameVideo = metadata.serverUrlFileName
                        result.fileIdVideo = metadata.fileId
                    } else if metadata.isImage {
                        result.serverUrlFileNameImage = metadata.serverUrlFileName
                        result.fileIdImage = metadata.fileId
                    }
                } else {
                    // Insert new — ensure the initializer sets the same PK used above
                    let addObject = tableLivePhoto(account: metadata.account, serverUrlFileNameNoExt: serverUrlFileNameNoExt)
                    if metadata.isVideo {
                        addObject.serverUrlFileNameVideo = metadata.serverUrlFileName
                        addObject.fileIdVideo = metadata.fileId
                        realm.add(addObject, update: .modified)
                    } else if metadata.isImage {
                        addObject.serverUrlFileNameImage = metadata.serverUrlFileName
                        addObject.fileIdImage = metadata.fileId
                        realm.add(addObject, update: .modified)
                    }
                }
            }
        }
    }

    func deleteLivePhoto(account: String, serverUrlFileNameNoExt: String) async {
        let primaryKey = account + serverUrlFileNameNoExt

        await performRealmWriteAsync { realm in
            if let result = realm.object(ofType: tableLivePhoto.self, forPrimaryKey: primaryKey) {
                realm.delete(result)
            }
        }
    }

    func deleteLivePhotoError() async {
        await performRealmWriteAsync { realm in
            let results = realm.objects(tableLivePhoto.self)
                .where {
                    $0.errorCount >= 3
                }
            realm.delete(results)
        }
    }

    func setLivePhotoError(account: String, serverUrlFileNameNoExt: String) async {
        let primaryKey = account + serverUrlFileNameNoExt

        await performRealmWriteAsync { realm in
            if let result = realm.object(ofType: tableLivePhoto.self, forPrimaryKey: primaryKey) {
                result.errorCount = result.errorCount + 1
            }
        }
    }

    // MARK: - Realm Read

    // swiftlint:disable empty_string
    func getLivePhotos(account: String) async -> [tableLivePhoto]? {
        await performRealmReadAsync { realm in
            let results = realm.objects(tableLivePhoto.self)
                .where {
                    $0.account == account &&
                    $0.serverUrlFileNameImage != "" &&
                    $0.serverUrlFileNameVideo != "" &&
                    $0.fileIdImage != "" &&
                    $0.fileIdVideo != ""
                }
            return results.map { tableLivePhoto(value: $0) } // detached copy
        }
    }
    // swiftlint:enable empty_string
}
