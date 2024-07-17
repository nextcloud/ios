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

import UIKit
import LRUCache
import NextcloudKit
import RealmSwift

class NCImageCache: NSObject {
    public static let shared: NCImageCache = {
        let instance = NCImageCache()
        return instance
    }()

    // MARK: -

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

    private typealias ThumbnailImagePreviewLRUCache = LRUCache<String, imageInfo>
    private typealias ThumbnailImageIconLRUCache = LRUCache<String, UIImage>
    private typealias ThumbnailSizePreviewLRUCache = LRUCache<String, CGSize?>

    private lazy var cacheImagePreview: ThumbnailImagePreviewLRUCache = {
        return ThumbnailImagePreviewLRUCache(countLimit: limitCacheImagePreview)
    }()
    private lazy var cacheImageIcon: ThumbnailImageIconLRUCache = {
        return ThumbnailImageIconLRUCache()
    }()
    private lazy var cacheSizePreview: ThumbnailSizePreviewLRUCache = {
        return ThumbnailSizePreviewLRUCache()
    }()
    private var metadatasInfo: [String: metadataInfo] = [:]
    private var metadatas: ThreadSafeArray<tableMetadata>?

    var createMediaCacheInProgress: Bool = false
    let showAllPredicateMediaString = "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == '\(NKCommon.TypeClassFile.image.rawValue)' OR classFile == '\(NKCommon.TypeClassFile.video.rawValue)') AND NOT (session CONTAINS[c] 'upload')"
    let showBothPredicateMediaString = "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == '\(NKCommon.TypeClassFile.image.rawValue)' OR classFile == '\(NKCommon.TypeClassFile.video.rawValue)') AND NOT (session CONTAINS[c] 'upload') AND NOT (livePhotoFile != '' AND classFile == '\(NKCommon.TypeClassFile.video.rawValue)')"
    let showOnlyPredicateMediaString = "account == %@ AND serverUrl BEGINSWITH %@ AND classFile == %@ AND NOT (session CONTAINS[c] 'upload') AND NOT (livePhotoFile != '' AND classFile == '\(NKCommon.TypeClassFile.video.rawValue)')"

    override private init() {}

    ///
    /// MEDIA CACHE
    ///
    func createMediaCache(account: String, withCacheSize: Bool) {
        if createMediaCacheInProgress {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] ThumbnailLRUCache image process already in progress")
            return
        }
        createMediaCacheInProgress = true

        self.metadatasInfo.removeAll()
        self.metadatas = nil
        self.metadatas = getMediaMetadatas(account: account)
        let manager = FileManager.default
        let resourceKeys = Set<URLResourceKey>([.nameKey, .pathKey, .fileSizeKey, .creationDateKey])
        struct FileInfo {
            var path: URL
            var ocIdEtag: String
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
            for case let fileURL as URL in enumerator where fileURL.lastPathComponent.hasSuffix(NCGlobal.shared.storageExtPreview) {
                let fileName = fileURL.lastPathComponent
                let ocId = fileURL.deletingLastPathComponent().lastPathComponent
                guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                      let fileSize = resourceValues.fileSize,
                      fileSize > 0 else { continue }
                let width = metadatasInfo[ocId]?.width ?? 0
                let height = metadatasInfo[ocId]?.height ?? 0
                if withCacheSize {
                    if let date = metadatasInfo[ocId]?.date,
                       let etag = metadatasInfo[ocId]?.etag,
                       fileName == etag + NCGlobal.shared.storageExtPreview {
                        files.append(FileInfo(path: fileURL, ocIdEtag: ocId + etag, date: date as Date, fileSize: fileSize, width: width, height: height))
                    } else {
                        let etag = fileName.replacingOccurrences(of: NCGlobal.shared.storageExtPreview, with: "")
                        files.append(FileInfo(path: fileURL, ocIdEtag: ocId + etag, date: Date.distantPast, fileSize: fileSize, width: width, height: height))
                    }
                } else if let date = metadatasInfo[ocId]?.date, let etag = metadatasInfo[ocId]?.etag, fileName == etag + NCGlobal.shared.storageExtPreview {
                    files.append(FileInfo(path: fileURL, ocIdEtag: ocId + etag, date: date as Date, fileSize: fileSize, width: width, height: height))
                }
            }
        }

        files.sort(by: { $0.date > $1.date })
        if let firstDate = files.first?.date, let lastDate = files.last?.date {
            print("First date: \(firstDate)")
            print("Last date: \(lastDate)")
        }

        cacheImagePreview.removeAllValues()
        cacheSizePreview.removeAllValues()
        var counter: Int = 0
        for file in files {
            if !withCacheSize, counter > limitCacheImagePreview {
                break
            }
            autoreleasepool {
                if let image = UIImage(contentsOfFile: file.path.path) {
                    if counter < limitCacheImagePreview {
                        cacheImagePreview.setValue(imageInfo(image: image, size: image.size, date: file.date), forKey: file.ocIdEtag)
                        totalSize = totalSize + Int64(file.fileSize)
                        counter += 1
                    }
                    if file.width == 0, file.height == 0 {
                        cacheSizePreview.setValue(image.size, forKey: file.ocIdEtag)
                    }
                }
            }
        }

        let diffDate = Date().timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate
        NextcloudKit.shared.nkCommonInstance.writeLog("--------- ThumbnailLRUCache image process ---------")
        NextcloudKit.shared.nkCommonInstance.writeLog("Counter cache image: \(cacheImagePreview.count)")
        NextcloudKit.shared.nkCommonInstance.writeLog("Counter cache size: \(cacheSizePreview.count)")
        NextcloudKit.shared.nkCommonInstance.writeLog("Total size images process: " + NCUtilityFileSystem().transformedSize(totalSize))
        NextcloudKit.shared.nkCommonInstance.writeLog("Time process: \(diffDate)")
        NextcloudKit.shared.nkCommonInstance.writeLog("--------- ThumbnailLRUCache image process ---------")

        createMediaCacheInProgress = false
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterCreateMediaCacheEnded)
    }

    func initialMetadatas() -> ThreadSafeArray<tableMetadata>? {
        defer { self.metadatas = nil }
        return self.metadatas
    }

    func getMediaMetadatas(account: String, predicate: NSPredicate? = nil) -> ThreadSafeArray<tableMetadata>? {
        guard let tableAccount = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", account)) else { return nil }
        let startServerUrl = NCUtilityFileSystem().getHomeServer(urlBase: tableAccount.urlBase, userId: tableAccount.userId) + tableAccount.mediaPath
        let predicateBoth = NSPredicate(format: showBothPredicateMediaString, account, startServerUrl)
        return NCManageDatabase.shared.getMediaMetadatas(predicate: predicate ?? predicateBoth)
    }

    ///
    /// PREVIEW CACHE
    ///
    func addPreviewImageCache(metadata: tableMetadata, image: UIImage) {
        cacheImagePreview.setValue(imageInfo(image: image, size: image.size, date: metadata.date as Date), forKey: metadata.ocId + metadata.etag)
        cacheSizePreview.setValue(image.size, forKey: metadata.ocId + metadata.etag)
    }

    func getPreviewImageCache(ocId: String, etag: String) -> UIImage? {
        if let cache = cacheImagePreview.value(forKey: ocId + etag) {
            return cache.image
        }
        return nil
    }

    ///
    /// SIZE CACHE
    ///
    func getPreviewSizeCache(ocId: String, etag: String) -> CGSize? {
        if let size = cacheSizePreview.value(forKey: ocId + etag) {
            return size
        } else {
            if let image = UIImage(contentsOfFile: NCUtilityFileSystem().getDirectoryProviderStoragePreviewOcId(ocId, etag: etag)) {
                return image.size
            }
        }
        return nil
    }

    ///
    /// ICON CACHE
    ///
    func setIconImageCache(ocId: String, etag: String, image: UIImage) {
        cacheImageIcon.setValue(image, forKey: ocId + etag)
    }

    func getIconImageCache(ocId: String, etag: String) -> UIImage? {
        return cacheImageIcon.value(forKey: ocId + etag)
    }

    // MARK: -

    struct images {
        static var file = UIImage()

        static var shared = UIImage()
        static var canShare = UIImage()
        static var shareByLink = UIImage()

        static var favorite = UIImage()
        static var comment = UIImage()
        static var livePhoto = UIImage()
        static var offlineFlag = UIImage()
        static var local = UIImage()

        static var folderEncrypted = UIImage()
        static var folderSharedWithMe = UIImage()
        static var folderPublic = UIImage()
        static var folderGroup = UIImage()
        static var folderExternal = UIImage()
        static var folderAutomaticUpload = UIImage()
        static var folder = UIImage()

        static var checkedYes = UIImage()
        static var checkedNo = UIImage()

        static var buttonMore = UIImage()
        static var buttonStop = UIImage()
        static var buttonMoreLock = UIImage()

        static var iconContacts = UIImage()
        static var iconTalk = UIImage()
        static var iconCalendar = UIImage()
        static var iconDeck = UIImage()
        static var iconMail = UIImage()
        static var iconConfirm = UIImage()
        static var iconPages = UIImage()
        static var iconFile = UIImage()
    }

    func createImagesCache() {
        let utility = NCUtility()

        images.file = utility.loadImage(named: "doc", colors: [NCBrandColor.shared.iconImageColor2])

        images.shared = utility.loadImage(named: "person.fill.badge.plus", colors: NCBrandColor.shared.iconImageMultiColors)
        images.canShare = utility.loadImage(named: "person.fill.badge.plus", colors: NCBrandColor.shared.iconImageMultiColors)
        images.shareByLink = utility.loadImage(named: "link", colors: [NCBrandColor.shared.iconImageColor])

        images.favorite = utility.loadImage(named: "star.fill", colors: [NCBrandColor.shared.yellowFavorite])
        images.livePhoto = utility.loadImage(named: "livephoto", colors: [NCBrandColor.shared.iconImageColor])
        images.offlineFlag = utility.loadImage(named: "arrow.down.circle.fill", colors: [.systemGreen])
        images.local = utility.loadImage(named: "checkmark.circle.fill", colors: [.systemGreen])

        images.checkedYes = utility.loadImage(named: "checkmark.circle.fill", colors: [NCBrandColor.shared.brandElement])
        images.checkedNo = utility.loadImage(named: "circle", colors: [NCBrandColor.shared.brandElement])

        images.buttonMore = utility.loadImage(named: "ellipsis", colors: [NCBrandColor.shared.iconImageColor])
        images.buttonStop = utility.loadImage(named: "stop.circle", colors: [NCBrandColor.shared.iconImageColor])
        images.buttonMoreLock = utility.loadImage(named: "lock.fill", colors: [NCBrandColor.shared.iconImageColor])

        createImagesBrandCache()
    }

    func createImagesBrandCache() {
        let brandElement = NCBrandColor.shared.brandElement
        guard brandElement != self.brandElementColor else { return }
        self.brandElementColor = brandElement
        let utility = NCUtility()

        images.folderEncrypted = UIImage(named: "folderEncrypted")!.image(color: brandElement)
        images.folderSharedWithMe = UIImage(named: "folder_shared_with_me")!.image(color: brandElement)
        images.folderPublic = UIImage(named: "folder_public")!.image(color: brandElement)
        images.folderGroup = UIImage(named: "folder_group")!.image(color: brandElement)
        images.folderExternal = UIImage(named: "folder_external")!.image(color: brandElement)
        images.folderAutomaticUpload = UIImage(named: "folderAutomaticUpload")!.image(color: brandElement)
        images.folder = UIImage(named: "folder")!.image(color: brandElement)

        images.iconContacts = utility.loadImage(named: "person.crop.rectangle.stack", colors: [NCBrandColor.shared.iconImageColor])
        images.iconTalk = UIImage(named: "talk-template")!.image(color: brandElement)
        images.iconCalendar = utility.loadImage(named: "calendar", colors: [NCBrandColor.shared.iconImageColor])
        images.iconDeck = utility.loadImage(named: "square.stack.fill", colors: [NCBrandColor.shared.iconImageColor])
        images.iconMail = utility.loadImage(named: "mail", colors: [NCBrandColor.shared.iconImageColor])
        images.iconConfirm = utility.loadImage(named: "arrow.right", colors: [NCBrandColor.shared.iconImageColor])
        images.iconPages = utility.loadImage(named: "doc.richtext", colors: [NCBrandColor.shared.iconImageColor])
        images.iconFile = utility.loadImage(named: "doc", colors: [NCBrandColor.shared.iconImageColor])

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeTheming)
    }
}
