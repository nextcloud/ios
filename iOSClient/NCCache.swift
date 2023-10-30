//
//  NCCache.swift
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

@objc class NCCache: NSObject {
    @objc public static let shared: NCCache = {
        let instance = NCCache()
        return instance
    }()

    // MARK: -

    private let limit: Int = 1000
    private typealias ThumbnailLRUCache = LRUCache<String, UIImage>
    private lazy var cache: ThumbnailLRUCache = {
        return ThumbnailLRUCache(countLimit: limit)
    }()
    private var ocIdEtag: [String: String] = [:]
    public var metadatas: [tableMetadata] = []
    public var predicateDefault: NSPredicate?
    public var predicate: NSPredicate?
    public var livePhoto: Bool = false

    func createMediaCache(account: String) {

        ocIdEtag.removeAll()
        metadatas.removeAll()
        getMediaMetadatas(account: account)

        guard !metadatas.isEmpty else { return }
        let ext = ".preview.ico"
        let manager = FileManager.default
        let resourceKeys = Set<URLResourceKey>([.nameKey, .pathKey, .fileSizeKey, .creationDateKey])
        struct FileInfo {
            var path: URL
            var ocId: String
            var date: Date
        }
        var files: [FileInfo] = []
        let startDate = Date()

        for metadata in metadatas {
            ocIdEtag[metadata.ocId] = metadata.etag
        }

        if let enumerator = manager.enumerator(at: URL(fileURLWithPath: NCUtilityFileSystem.shared.directoryProviderStorage), includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator where fileURL.lastPathComponent.hasSuffix(ext) {
                let fileName = fileURL.lastPathComponent
                let ocId = fileURL.deletingLastPathComponent().lastPathComponent
                guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                        let size = resourceValues.fileSize,
                        size > 0,
                        let date = resourceValues.creationDate,
                        let etag = ocIdEtag[ocId],
                        fileName == etag + ext else { continue }
                files.append(FileInfo(path: fileURL, ocId: ocId, date: date))
            }
        }

        files.sort(by: { $0.date > $1.date })
        if let firstDate = files.first?.date, let lastDate = files.last?.date {
            print("First date: \(firstDate)")
            print("Last date: \(lastDate)")
        }

        cache.removeAllValues()
        var counter: Int = 0
        for file in files {
            counter += 1
            if counter > limit { break }
            autoreleasepool {
                if let image = UIImage(contentsOfFile: file.path.path) {
                    cache.setValue(image, forKey: file.ocId)
                }
            }
        }

        let endDate = Date()
        let diffDate = endDate.timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate
        NextcloudKit.shared.nkCommonInstance.writeLog("--------- ThumbnailLRUCache image process ---------")
        NextcloudKit.shared.nkCommonInstance.writeLog("Counter process: \(cache.count)")
        NextcloudKit.shared.nkCommonInstance.writeLog("Time process: \(diffDate)")
        NextcloudKit.shared.nkCommonInstance.writeLog("--------- ThumbnailLRUCache image process ---------")
    }

    func getMediaImage(ocId: String) -> UIImage? {

        return cache.value(forKey: ocId)
    }

    func setMediaImage(ocId: String, image: UIImage) {

        cache.setValue(image, forKey: ocId)
    }

    @objc func clearMediaCache() {

        ocIdEtag.removeAll()
        metadatas.removeAll()
        cache.removeAllValues()
    }

    func getMediaMetadatas(account: String, filterClassTypeImage: Bool = false, filterClassTypeVideo: Bool = false) {

        guard let account = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", account)) else { return }
        let startServerUrl = NCUtilityFileSystem.shared.getHomeServer(urlBase: account.urlBase, userId: account.userId) + account.mediaPath

        predicateDefault = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == %@ OR classFile == %@) AND NOT (session CONTAINS[c] 'upload')", account.account, startServerUrl, NKCommon.TypeClassFile.image.rawValue, NKCommon.TypeClassFile.video.rawValue)

        if filterClassTypeImage {
            predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND classFile == %@ AND NOT (session CONTAINS[c] 'upload')", account.account, startServerUrl, NKCommon.TypeClassFile.video.rawValue)
        } else if filterClassTypeVideo {
            predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND classFile == %@ AND NOT (session CONTAINS[c] 'upload')", account.account, startServerUrl, NKCommon.TypeClassFile.image.rawValue)
        } else {
            predicate = predicateDefault
        }

        guard let predicate = predicate else { return }

        livePhoto = NCKeychain().livePhoto
        metadatas = NCManageDatabase.shared.getMetadatasMedia(predicate: predicate, livePhoto: livePhoto)

        switch NCKeychain().mediaSortDate {
        case "date":
            metadatas = self.metadatas.sorted(by: {($0.date as Date) > ($1.date as Date)})
        case "creationDate":
            metadatas = self.metadatas.sorted(by: {($0.creationDate as Date) > ($1.creationDate as Date)})
        case "uploadDate":
            metadatas = self.metadatas.sorted(by: {($0.uploadDate as Date) > ($1.uploadDate as Date)})
        default:
            break
        }
    }

    // MARK: -

    struct cacheImages {
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

        let brandElement = NCBrandColor.shared.brandElement
        let yellowFavorite = NCBrandColor.shared.yellowFavorite
        let utility = NCUtility()

        cacheImages.file = UIImage(named: "file")!

        cacheImages.shared = UIImage(named: "share")!.image(color: .systemGray, size: 50)
        cacheImages.canShare = UIImage(named: "share")!.image(color: .systemGray, size: 50)
        cacheImages.shareByLink = UIImage(named: "sharebylink")!.image(color: .systemGray, size: 50)

        cacheImages.favorite = utility.loadImage(named: "star.fill", color: yellowFavorite)
        cacheImages.comment = UIImage(named: "comment")!.image(color: .systemGray, size: 50)
        cacheImages.livePhoto = utility.loadImage(named: "livephoto", color: .label)
        cacheImages.offlineFlag = UIImage(named: "offlineFlag")!
        cacheImages.local = UIImage(named: "local")!

        let folderWidth: CGFloat = UIScreen.main.bounds.width / 3
        cacheImages.folderEncrypted = UIImage(named: "folderEncrypted")!.image(color: brandElement, size: folderWidth)
        cacheImages.folderSharedWithMe = UIImage(named: "folder_shared_with_me")!.image(color: brandElement, size: folderWidth)
        cacheImages.folderPublic = UIImage(named: "folder_public")!.image(color: brandElement, size: folderWidth)
        cacheImages.folderGroup = UIImage(named: "folder_group")!.image(color: brandElement, size: folderWidth)
        cacheImages.folderExternal = UIImage(named: "folder_external")!.image(color: brandElement, size: folderWidth)
        cacheImages.folderAutomaticUpload = UIImage(named: "folderAutomaticUpload")!.image(color: brandElement, size: folderWidth)
        cacheImages.folder = UIImage(named: "folder")!.image(color: brandElement, size: folderWidth)

        cacheImages.checkedYes = utility.loadImage(named: "checkmark.circle.fill", color: .systemBlue)
        cacheImages.checkedNo = utility.loadImage(named: "circle", color: .systemGray)

        cacheImages.buttonMore = UIImage(named: "more")!.image(color: .systemGray, size: 50)
        cacheImages.buttonStop = UIImage(named: "stop")!.image(color: .systemGray, size: 50)
        cacheImages.buttonMoreLock = UIImage(named: "moreLock")!.image(color: .systemGray, size: 50)
        cacheImages.buttonRestore = UIImage(named: "restore")!.image(color: .systemGray, size: 50)
        cacheImages.buttonTrash = UIImage(named: "trash")!.image(color: .systemGray, size: 50)

        cacheImages.iconContacts = UIImage(named: "icon-contacts")!.image(color: brandElement, size: folderWidth)
        cacheImages.iconTalk = UIImage(named: "icon-talk")!.image(color: brandElement, size: folderWidth)
        cacheImages.iconCalendar = UIImage(named: "icon-calendar")!.image(color: brandElement, size: folderWidth)
        cacheImages.iconDeck = UIImage(named: "icon-deck")!.image(color: brandElement, size: folderWidth)
        cacheImages.iconMail = UIImage(named: "icon-mail")!.image(color: brandElement, size: folderWidth)
        cacheImages.iconConfirm = UIImage(named: "icon-confirm")!.image(color: brandElement, size: folderWidth)
        cacheImages.iconPages = UIImage(named: "icon-pages")!.image(color: brandElement, size: folderWidth)

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeTheming)
    }
}
