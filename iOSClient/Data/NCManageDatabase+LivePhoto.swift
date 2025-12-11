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

    func setLivePhotoVideo(account: String, serverUrlFileName: String, fileId: String, classFile: String) async {
        await core.performRealmWriteAsync { realm in
            let serverUrlFileNameNoExt = (serverUrlFileName as NSString).deletingPathExtension
            let primaryKey = account + serverUrlFileNameNoExt

            let livePhoto: tableLivePhoto
            if let existing = realm.object(ofType: tableLivePhoto.self, forPrimaryKey: primaryKey) {
                livePhoto = existing
            } else {
                // Create and add a new entry with the proper primary key
                let newObject = tableLivePhoto(account: account, serverUrlFileNameNoExt: serverUrlFileNameNoExt)
                realm.add(newObject, update: .modified)
                livePhoto = newObject
            }

            // Update only the relevant fields based on metadata content type
            if classFile == NKTypeClassFile.video.rawValue {
                livePhoto.serverUrlFileNameVideo = serverUrlFileName
                livePhoto.fileIdVideo = fileId
            } else if classFile == NKTypeClassFile.image.rawValue {
                livePhoto.serverUrlFileNameImage = serverUrlFileName
                livePhoto.fileIdImage = fileId
            }
        }
    }

    func deleteLivePhoto(account: String, serverUrlFileNameNoExt: String) async {
        let primaryKey = account + serverUrlFileNameNoExt

        await core.performRealmWriteAsync { realm in
            if let result = realm.object(ofType: tableLivePhoto.self, forPrimaryKey: primaryKey) {
                realm.delete(result)
            }
        }
    }

    func deleteLivePhotoError() async {
        await core.performRealmWriteAsync { realm in
            let results = realm.objects(tableLivePhoto.self)
                .where {
                    $0.errorCount >= 3
                }
            realm.delete(results)
        }
    }

    func setLivePhotoError(account: String, serverUrlFileNameNoExt: String) async {
        let primaryKey = account + serverUrlFileNameNoExt

        await core.performRealmWriteAsync { realm in
            if let result = realm.object(ofType: tableLivePhoto.self, forPrimaryKey: primaryKey) {
                result.errorCount = result.errorCount + 1
            }
        }
    }

    // MARK: - Realm Read

    // swiftlint:disable empty_string
    func getLivePhotos(account: String) async -> [tableLivePhoto]? {
        await core.performRealmReadAsync { realm in
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

    /// Returns true if at least one valid Live Photo record exists for the given account.
    func hasLivePhotos() async -> Bool {
        await core.performRealmReadAsync { realm in
            let results = realm.objects(tableLivePhoto.self)
                .where {
                    $0.serverUrlFileNameImage != "" &&
                    $0.serverUrlFileNameVideo != "" &&
                    $0.fileIdImage != "" &&
                    $0.fileIdVideo != ""
                }
            return !results.isEmpty
        } ?? false
    }
    // swiftlint:enable empty_string
}
