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

    func setLivePhotoImage(account: String, serverUrlFileName: String, fileId: String) async {
        let serverUrlFileNameNoExt = (serverUrlFileName as NSString).deletingPathExtension
        let primaryKey = account + serverUrlFileNameNoExt

        await performRealmWriteAsync { realm in
            if let result = realm.object(ofType: tableLivePhoto.self, forPrimaryKey: primaryKey) {
                result.serverUrlFileNameImage = serverUrlFileName
                result.fileIdImage = fileId
            } else {
                let addObject = tableLivePhoto(account: account, serverUrlFileNameNoExt: serverUrlFileNameNoExt)
                addObject.serverUrlFileNameImage = serverUrlFileName
                addObject.fileIdImage = fileId
                realm.add(addObject, update: .all)
            }
        }
    }

    func setLivePhotoVideo(account: String, serverUrlFileName: String, fileId: String) async {
        let serverUrlFileNameNoExt = (serverUrlFileName as NSString).deletingPathExtension
        let primaryKey = account + serverUrlFileNameNoExt

        await performRealmWriteAsync { realm in
            if let result = realm.object(ofType: tableLivePhoto.self, forPrimaryKey: primaryKey) {
                result.serverUrlFileNameVideo = serverUrlFileName
                result.fileIdVideo = fileId
            } else {
                let addObject = tableLivePhoto(account: account, serverUrlFileNameNoExt: serverUrlFileNameNoExt)
                addObject.serverUrlFileNameVideo = serverUrlFileName
                addObject.fileIdVideo = fileId
                realm.add(addObject, update: .all)
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
