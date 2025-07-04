// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

class tableAvatar: Object {
    @objc dynamic var date = NSDate()
    @objc dynamic var etag = ""
    @objc dynamic var fileName = ""
    @objc dynamic var loaded: Bool = false

    override static func primaryKey() -> String {
        return "fileName"
    }
}

extension NCManageDatabase {

    // MARK: - Realm write

    func addAvatar(fileName: String, etag: String, sync: Bool = true) {
        performRealmWrite(sync: sync) { realm in
            let addObject = tableAvatar()
            addObject.date = NSDate()
            addObject.etag = etag
            addObject.fileName = fileName
            addObject.loaded = true
            realm.add(addObject, update: .all)
        }
    }

    /// Asynchronously adds a new avatar entry to the Realm database.
    /// - Parameters:
    ///   - fileName: The name of the avatar file.
    ///   - etag: The ETag associated with the avatar file.
    ///   - async: Whether the Realm write should be executed asynchronously (default is true).
    func addAvatarAsync(fileName: String, etag: String) async {
        await performRealmWriteAsync { realm in
            let addObject = tableAvatar()
            addObject.date = NSDate()
            addObject.etag = etag
            addObject.fileName = fileName
            addObject.loaded = true
            realm.add(addObject, update: .all)
        }
    }

    func clearAllAvatarLoadedAsync() async {
        await performRealmWriteAsync { realm in
            let results = realm.objects(tableAvatar.self)
            for result in results {
                result.loaded = false
            }
        }
    }

    @discardableResult
    func setAvatarLoaded(fileName: String, sync: Bool = true) -> UIImage? {
        let fileNameLocalPath = utilityFileSystem.directoryUserData + "/" + fileName
        var image: UIImage?

        performRealmWrite(sync: sync) { realm in
            if let result = realm.objects(tableAvatar.self).filter("fileName == %@", fileName).first {
                if let imageAvatar = UIImage(contentsOfFile: fileNameLocalPath) {
                    result.loaded = true
                    image = imageAvatar
                } else {
                    realm.delete(result)
                }
            }
        }
        return image
    }

    /// Asynchronously sets an avatar as loaded if the image exists on disk, or deletes the entry if not.
    /// - Parameters:
    ///   - fileName: The name of the avatar file to check and update.
    ///   - async: Whether the Realm write should be executed asynchronously (default is true).
    /// - Returns: The `UIImage` if successfully loaded from disk, or `nil` if not found or deleted.
    @discardableResult
    func setAvatarLoadedAsync(fileName: String) async -> UIImage? {
        let fileNameLocalPath = utilityFileSystem.directoryUserData + "/" + fileName
        var image: UIImage?

        await performRealmWriteAsync { realm in
            if let result = realm.objects(tableAvatar.self).filter("fileName == %@", fileName).first {
                if let imageAvatar = UIImage(contentsOfFile: fileNameLocalPath) {
                    result.loaded = true
                    image = imageAvatar
                } else {
                    realm.delete(result)
                }
            }
        }

        return image
    }

    // MARK: - Realm read

    func getTableAvatar(fileName: String) -> tableAvatar? {
        performRealmRead { realm in
            guard let result = realm.objects(tableAvatar.self)
                .filter("fileName == %@", fileName)
                .first else {
                return nil
            }
            return tableAvatar(value: result)
        }
    }

    func getTableAvatar(fileName: String,
                        dispatchOnMainQueue: Bool = true,
                        completion: @escaping (_ tblAvatar: tableAvatar?) -> Void) {
        performRealmRead({ realm in
            return realm.objects(tableAvatar.self)
                .filter("fileName == %@", fileName)
                .first
                .map { tableAvatar(value: $0) }
        }, sync: false) { result in
            if dispatchOnMainQueue {
                DispatchQueue.main.async {
                    completion(result)
                }
            } else {
                completion(result)
            }
        }
    }

    func getTableAvatarAsync(fileName: String) async -> tableAvatar? {
        return await performRealmReadAsync { realm in
            realm.objects(tableAvatar.self)
                .filter("fileName == %@", fileName)
                .first
                .map { tableAvatar(value: $0) }
        }
    }

    func getImageAvatarLoaded(fileName: String) -> (image: UIImage?, tblAvatar: tableAvatar?) {
        let fileNameLocalPath = utilityFileSystem.directoryUserData + "/" + fileName
        let image = UIImage(contentsOfFile: fileNameLocalPath)
        var tblAvatar: tableAvatar?

        performRealmRead { realm in
            if let result = realm.objects(tableAvatar.self).filter("fileName == %@", fileName).first {
                tblAvatar = tableAvatar(value: result)
            } else {
                self.utilityFileSystem.removeFile(atPath: fileNameLocalPath)
            }
        }

        return (image, tblAvatar)
    }

    func getImageAvatarLoaded(fileName: String,
                              dispatchOnMainQueue: Bool = true,
                              completion: @escaping (_ image: UIImage?, _ tblAvatar: tableAvatar?) -> Void) {
        let fileNameLocalPath = utilityFileSystem.directoryUserData + "/" + fileName
        let image = UIImage(contentsOfFile: fileNameLocalPath)

        performRealmRead({ realm in
            return realm.objects(tableAvatar.self)
                .filter("fileName == %@", fileName)
                .first
                .map { tableAvatar(value: $0) }
        }, sync: false) { result in
            if result == nil {
                self.utilityFileSystem.removeFile(atPath: fileNameLocalPath)
            }

            if dispatchOnMainQueue {
                DispatchQueue.main.async {
                    completion(image, result)
                }
            } else {
                completion(image, result)
            }
        }
    }
}
