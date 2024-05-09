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

@objc class NCImageCache: NSObject {
    @objc public static let shared: NCImageCache = {
        let instance = NCImageCache()
        return instance
    }()

    // MARK: -

    private let limit: Int = 1000
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

    private typealias ThumbnailImageLRUCache = LRUCache<String, imageInfo>
    private typealias ThumbnailSizeLRUCache = LRUCache<String, CGSize?>

    private lazy var cacheImage: ThumbnailImageLRUCache = {
        return ThumbnailImageLRUCache(countLimit: limit)
    }()
    private lazy var cacheSize: ThumbnailSizeLRUCache = {
        return ThumbnailSizeLRUCache()
    }()
    private var metadatasInfo: [String: metadataInfo] = [:]
    private var metadatas: ThreadSafeArray<tableMetadata>?

    var createMediaCacheInProgress: Bool = false
    let showAllPredicateMediaString = "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == '\(NKCommon.TypeClassFile.image.rawValue)' OR classFile == '\(NKCommon.TypeClassFile.video.rawValue)') AND NOT (session CONTAINS[c] 'upload')"
    let showBothPredicateMediaString = "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == '\(NKCommon.TypeClassFile.image.rawValue)' OR classFile == '\(NKCommon.TypeClassFile.video.rawValue)') AND NOT (session CONTAINS[c] 'upload') AND NOT (livePhotoFile != '' AND classFile == '\(NKCommon.TypeClassFile.video.rawValue)')"
    let showOnlyPredicateMediaString = "account == %@ AND serverUrl BEGINSWITH %@ AND classFile == %@ AND NOT (session CONTAINS[c] 'upload') AND NOT (livePhotoFile != '' AND classFile == '\(NKCommon.TypeClassFile.video.rawValue)')"

    override private init() {}

    @objc func createMediaCache(account: String, withCacheSize: Bool) {
        if createMediaCacheInProgress {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] ThumbnailLRUCache image process already in progress")
            return
        }
        createMediaCacheInProgress = true

        self.metadatasInfo.removeAll()
        self.metadatas = nil
        self.metadatas = getMediaMetadatas(account: account)
        let ext = ".preview.ico"
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
            for case let fileURL as URL in enumerator where fileURL.lastPathComponent.hasSuffix(ext) {
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
                       fileName == etag + ext {
                        files.append(FileInfo(path: fileURL, ocIdEtag: ocId + etag, date: date as Date, fileSize: fileSize, width: width, height: height))
                    } else {
                        let etag = fileName.replacingOccurrences(of: ".preview.ico", with: "")
                        files.append(FileInfo(path: fileURL, ocIdEtag: ocId + etag, date: Date.distantPast, fileSize: fileSize, width: width, height: height))
                    }
                } else if let date = metadatasInfo[ocId]?.date, let etag = metadatasInfo[ocId]?.etag, fileName == etag + ext {
                    files.append(FileInfo(path: fileURL, ocIdEtag: ocId + etag, date: date as Date, fileSize: fileSize, width: width, height: height))
                } else {
                    print("Nothing")
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
            if !withCacheSize, counter > limit {
                break
            }
            autoreleasepool {
                if let image = UIImage(contentsOfFile: file.path.path) {
                    if counter < limit {
                        cacheImage.setValue(imageInfo(image: image, size: image.size, date: file.date), forKey: file.ocIdEtag)
                        totalSize = totalSize + Int64(file.fileSize)
                    }
                    if file.width == 0, file.height == 0 {
                        cacheSize.setValue(image.size, forKey: file.ocIdEtag)
                    }
                }
            }
            counter += 1
        }

        let diffDate = Date().timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate
        NextcloudKit.shared.nkCommonInstance.writeLog("--------- ThumbnailLRUCache image process ---------")
        NextcloudKit.shared.nkCommonInstance.writeLog("Counter cache image: \(cacheImage.count)")
        NextcloudKit.shared.nkCommonInstance.writeLog("Counter cache size: \(cacheSize.count)")
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

    func setMediaImage(ocId: String, etag: String, image: UIImage, date: Date) {
        cacheImage.setValue(imageInfo(image: image, size: image.size, date: date), forKey: ocId + etag)
    }

    func getMediaImage(ocId: String, etag: String) -> UIImage? {
        if let cache = cacheImage.value(forKey: ocId + etag) {
            return cache.image
        }
        return nil
    }

    func hasMediaImageEnoughSpace() -> Bool {
        return limit > cacheImage.count
    }

    func setMediaSize(ocId: String, etag: String, size: CGSize) {
        cacheSize.setValue(size, forKey: ocId + etag)
    }

    func getMediaSize(ocId: String, etag: String) -> CGSize? {
        return cacheSize.value(forKey: ocId + etag) ?? nil
    }

    func getMediaMetadatas(account: String, predicate: NSPredicate? = nil) -> ThreadSafeArray<tableMetadata>? {
        guard let tableAccount = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", account)) else { return nil }
        let startServerUrl = NCUtilityFileSystem().getHomeServer(urlBase: tableAccount.urlBase, userId: tableAccount.userId) + tableAccount.mediaPath
        let predicateBoth = NSPredicate(format: showBothPredicateMediaString, account, startServerUrl)
        return NCManageDatabase.shared.getMediaMetadatas(predicate: predicate ?? predicateBoth)
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
        static var buttonRestore = UIImage()
        static var buttonTrash = UIImage()

        static var iconContacts = UIImage()
        static var iconTalk = UIImage()
        static var iconCalendar = UIImage()
        static var iconDeck = UIImage()
        static var iconMail = UIImage()
        static var iconConfirm = UIImage()
        static var iconPages = UIImage()
    }

    func createImagesCache() {
        let iconImageColor = NCBrandColor.shared.iconImageColor
        let utility = NCUtility()

        images.file = utility.loadImage(named: "doc", color: iconImageColor)

        images.shared = utility.loadImage(named: "person.fill.badge.plus", color: iconImageColor)
        images.canShare = utility.loadImage(named: "person.fill.badge.plus", color: iconImageColor)
        images.shareByLink = utility.loadImage(named: "link", color: NCBrandColor.shared.iconImageColor)

        images.favorite = utility.loadImage(named: "star.fill", color: NCBrandColor.shared.yellowFavorite)
        images.livePhoto = utility.loadImage(named: "livephoto", color: iconImageColor)
        images.offlineFlag = utility.loadImage(named: "arrow.down.circle.fill", color: .systemGreen)
        images.local = utility.loadImage(named: "checkmark.circle.fill", color: .systemGreen)

        images.checkedYes = utility.loadImage(named: "checkmark.circle.fill", color: NCBrandColor.shared.brand)
        images.checkedNo = utility.loadImage(named: "circle", color: NCBrandColor.shared.brand)

        images.buttonMore = utility.loadImage(named: "ellipsis", color: iconImageColor)
        images.buttonStop = utility.loadImage(named: "stop.circle", color: iconImageColor)
        images.buttonMoreLock = utility.loadImage(named: "lock.fill", color: iconImageColor)

        createImagesBrandCache()
    }

    func createImagesBrandCache() {

        let brandElement = NCBrandColor.shared.brandElement
        guard brandElement != self.brandElementColor else { return }
        self.brandElementColor = brandElement

        let folderWidth: CGFloat = UIScreen.main.bounds.width / 3
        images.folderEncrypted = UIImage(named: "folderEncrypted")!.image(color: brandElement, size: folderWidth)
        images.folderSharedWithMe = UIImage(named: "folder_shared_with_me")!.image(color: brandElement, size: folderWidth)
        images.folderPublic = UIImage(named: "folder_public")!.image(color: brandElement, size: folderWidth)
        images.folderGroup = UIImage(named: "folder_group")!.image(color: brandElement, size: folderWidth)
        images.folderExternal = UIImage(named: "folder_external")!.image(color: brandElement, size: folderWidth)
        images.folderAutomaticUpload = UIImage(named: "folderAutomaticUpload")!.image(color: brandElement, size: folderWidth)
        images.folder = UIImage(named: "folder")!.image(color: brandElement, size: folderWidth)

        images.iconContacts = UIImage(named: "icon-contacts")!.image(color: brandElement, size: folderWidth)
        images.iconTalk = UIImage(named: "icon-talk")!.image(color: brandElement, size: folderWidth)
        images.iconCalendar = UIImage(named: "icon-calendar")!.image(color: brandElement, size: folderWidth)
        images.iconDeck = UIImage(named: "icon-deck")!.image(color: brandElement, size: folderWidth)
        images.iconMail = UIImage(named: "icon-mail")!.image(color: brandElement, size: folderWidth)
        images.iconConfirm = UIImage(named: "icon-confirm")!.image(color: brandElement, size: folderWidth)
        images.iconPages = UIImage(named: "icon-pages")!.image(color: brandElement, size: folderWidth)

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeTheming)
    }
}
