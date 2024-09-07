//
//  NCImageCache.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 18/10/23.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
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
import LRUCache
import NextcloudKit
import RealmSwift

class NCImageCache: NSObject {
    static let shared = NCImageCache()

    // MARK: -

    private let utility = NCUtility()
    private let global = NCGlobal.shared

    private let limitCacheImagePreview: Int = 1000
    private var brandElementColor: UIColor?
    private var totalSize: Int64 = 0

    struct metadataInfo {
        var etag: String
        var date: NSDate
        var width: Int
        var height: Int
    }

    struct imageInfo {
        var image: UIImage?
        var size: CGSize?
        var date: Date
    }

    private typealias ThumbnailImageCache = LRUCache<String, imageInfo>
    private typealias ThumbnailSizeCache = LRUCache<String, CGSize?>

    private lazy var cacheImage: ThumbnailImageCache = {
        return ThumbnailImageCache(countLimit: limitCacheImagePreview)
    }()
    private lazy var cacheSize: ThumbnailSizeCache = {
        return ThumbnailSizeCache()
    }()

    var createMediaCacheInProgress: Bool = false

    override private init() {}

    ///
    /// MEDIA CACHE
    ///
    func createMediaCache() {
        if createMediaCacheInProgress {
            return
        }
        createMediaCacheInProgress = true

        let predicate = NSPredicate(format: "(classFile == '\(NKCommon.TypeClassFile.image.rawValue)' OR classFile == '\(NKCommon.TypeClassFile.video.rawValue)') AND NOT (session CONTAINS[c] 'upload') AND NOT (livePhotoFile != '' AND classFile == '\(NKCommon.TypeClassFile.video.rawValue)')")
        let metadatas = NCManageDatabase.shared.getResultsImageCacheMetadatas(predicate: predicate)
        var metadatasInfo: [String: metadataInfo] = [:]
        let manager = FileManager.default
        let resourceKeys = Set<URLResourceKey>([.nameKey, .pathKey, .fileSizeKey, .creationDateKey])
        struct FileInfo {
            var path: URL
            var ocIdEtagExt: String
            var date: Date
            var fileSize: Int
            var width: Int
            var height: Int
        }
        var files: [FileInfo] = []
        let startDate = Date()

        if let metadatas = metadatas {
            metadatas.forEach { metadata in
                metadatasInfo[metadata.ocId] = metadataInfo(etag: metadata.etag, date: metadata.date, width: metadata.width, height: metadata.height)
            }
        }

        if let enumerator = manager.enumerator(at: URL(fileURLWithPath: NCUtilityFileSystem().directoryProviderStorage), includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator where fileURL.lastPathComponent.hasSuffix(".preview.ico") {
                let fileName = fileURL.lastPathComponent
                let ocId = fileURL.deletingLastPathComponent().lastPathComponent
                guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                      let fileSize = resourceValues.fileSize,
                      fileSize > 0 else { continue }
                let width = metadatasInfo[ocId]?.width ?? 0
                let height = metadatasInfo[ocId]?.height ?? 0
                if let date = metadatasInfo[ocId]?.date {
                        files.append(FileInfo(path: fileURL, ocIdEtagExt: ocId + fileName, date: date as Date, fileSize: fileSize, width: width, height: height))
                } else {
                    files.append(FileInfo(path: fileURL, ocIdEtagExt: ocId + fileName, date: Date.distantPast, fileSize: fileSize, width: width, height: height))
                }
            }
        }

        files.sort(by: { $0.date > $1.date })
        if let firstDate = files.first?.date, let lastDate = files.last?.date {
            print("First date: \(firstDate)")
            print("Last date: \(lastDate)")
        }

        cacheImage.removeAllValues()
        cacheSize.removeAllValues()

        var counter: Int = 0
        for file in files {
            autoreleasepool {
                if let image = UIImage(contentsOfFile: file.path.path) {
                    if counter < limitCacheImagePreview {
                        cacheImage.setValue(imageInfo(image: image, size: image.size, date: file.date), forKey: file.ocIdEtagExt)
                        totalSize = totalSize + Int64(file.fileSize)
                        counter += 1
                    }
                    if file.width == 0, file.height == 0 {
                        cacheSize.setValue(image.size, forKey: file.ocIdEtagExt)
                    }
                }
            }
        }

        let diffDate = Date().timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate
        NextcloudKit.shared.nkCommonInstance.writeLog("--------- ThumbnailLRUCache image process ---------")
        NextcloudKit.shared.nkCommonInstance.writeLog("Counter cache image: \(cacheImage.count)")
        NextcloudKit.shared.nkCommonInstance.writeLog("Counter cache size: \(cacheSize.count)")
        NextcloudKit.shared.nkCommonInstance.writeLog("Total size images process: " + NCUtilityFileSystem().transformedSize(totalSize))
        NextcloudKit.shared.nkCommonInstance.writeLog("Time process: \(diffDate)")
        NextcloudKit.shared.nkCommonInstance.writeLog("--------- ThumbnailLRUCache image process ---------")

        createMediaCacheInProgress = false
    }

    ///
    ///
    ///
    func extract(fileName: String) -> (String?, String?) {
        let dotOccurrences = fileName.split(separator: ".")

        if dotOccurrences.count >= 4 {
            let etag = dotOccurrences.prefix(dotOccurrences.count - 3).joined(separator: ".")
            let ext = "." + dotOccurrences.suffix(3).joined(separator: ".")
            return (etag, ext)
        } else {
            return (nil, nil)
        }
    }

    ///
    /// CACHE
    ///
    func addImageCache(metadata: tableMetadata?, data: Data, ext: String) {
        guard let metadata, let image = UIImage(data: data) else { return }
        cacheImage.setValue(imageInfo(image: image, size: image.size, date: metadata.date as Date), forKey: metadata.ocId + metadata.etag + ext)
        cacheSize.setValue(image.size, forKey: metadata.ocId + metadata.etag)
    }

    func getImageCache(ocId: String, etag: String, ext: String) -> UIImage? {
        if let cache = cacheImage.value(forKey: ocId + etag + ext) {
            return cache.image
        }
        return nil
    }

    func removeImageCache(ocId: String, etag: String) {
        let exts = [global.storageExt1024x1024,
                    global.storageExt512x512,
                    global.storageExt256x256,
                    global.storageExt128x128]

        for i in 0..<exts.count {
            cacheImage.removeValue(forKey: ocId + etag + exts[i])
        }
        cacheSize.removeValue(forKey: ocId + etag)
    }

    ///
    /// SIZE CACHE
    ///
    func getPreviewSizeCache(ocId: String, etag: String) -> CGSize? {
        if let size = cacheSize.value(forKey: ocId + etag) {
            return size
        } else {
            if let image = UIImage(contentsOfFile: NCUtilityFileSystem().getDirectoryProviderStorageImageOcId(ocId, etag: etag, ext: NCGlobal.shared.storageExt1024x1024)) {
                return image.size
            }
        }
        return nil
    }

    // MARK: -

    func getImageFile() -> UIImage {
        return utility.loadImage(named: "doc", colors: [NCBrandColor.shared.iconImageColor2])
    }

    func getImageShared() -> UIImage {
        return utility.loadImage(named: "person.fill.badge.plus", colors: NCBrandColor.shared.iconImageMultiColors)
    }

    func getImageCanShare() -> UIImage {
        return utility.loadImage(named: "person.fill.badge.plus", colors: NCBrandColor.shared.iconImageMultiColors)
    }

    func getImageShareByLink() -> UIImage {
        return utility.loadImage(named: "link", colors: [NCBrandColor.shared.iconImageColor])
    }

    func getImageFavorite() -> UIImage {
        return utility.loadImage(named: "star.fill", colors: [NCBrandColor.shared.yellowFavorite])
    }

    func getImageOfflineFlag() -> UIImage {
        return utility.loadImage(named: "arrow.down.circle.fill", colors: [.systemGreen])
    }

    func getImageLocal() -> UIImage {
        return utility.loadImage(named: "checkmark.circle.fill", colors: [.systemGreen])
    }

    func getImageCheckedYes() -> UIImage {
        return utility.loadImage(named: "checkmark.circle.fill", colors: [NCBrandColor.shared.iconImageColor2])
    }

    func getImageCheckedNo() -> UIImage {
        return utility.loadImage(named: "circle", colors: [NCBrandColor.shared.iconImageColor])
    }

    func getImageButtonMore() -> UIImage {
        return utility.loadImage(named: "ellipsis", colors: [NCBrandColor.shared.iconImageColor])
    }

    func getImageButtonStop() -> UIImage {
        return utility.loadImage(named: "stop.circle", colors: [NCBrandColor.shared.iconImageColor])
    }

    func getImageButtonMoreLock() -> UIImage {
        return utility.loadImage(named: "lock.fill", colors: [NCBrandColor.shared.iconImageColor])
    }

    func getFolder(account: String) -> UIImage {
        return UIImage(named: "folder")!.image(color: NCBrandColor.shared.getElement(account: account))
    }

    func getFolderEncrypted(account: String) -> UIImage {
        return UIImage(named: "folderEncrypted")!.image(color: NCBrandColor.shared.getElement(account: account))
    }

    func getFolderSharedWithMe(account: String) -> UIImage {
        return UIImage(named: "folder_shared_with_me")!.image(color: NCBrandColor.shared.getElement(account: account))
    }

    func getFolderPublic(account: String) -> UIImage {
        return UIImage(named: "folder_public")!.image(color: NCBrandColor.shared.getElement(account: account))
    }

    func getFolderGroup(account: String) -> UIImage {
        return UIImage(named: "folder_group")!.image(color: NCBrandColor.shared.getElement(account: account))
    }

    func getFolderExternal(account: String) -> UIImage {
        return UIImage(named: "folder_external")!.image(color: NCBrandColor.shared.getElement(account: account))
    }

    func getFolderAutomaticUpload(account: String) -> UIImage {
        return UIImage(named: "folderAutomaticUpload")!.image(color: NCBrandColor.shared.getElement(account: account))
    }
}
