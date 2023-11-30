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

@objc class NCImageCache: NSObject {
    @objc public static let shared: NCImageCache = {
        let instance = NCImageCache()
        return instance
    }()

    // MARK: -

    private let limit: Int = 1000
    private var account: String = ""
    private var brandElementColor: UIColor?

    enum ImageType {
        case placeholder
        case actual(_ image: UIImage)
    }

    private typealias ThumbnailLRUCache = LRUCache<String, ImageType>
    private lazy var cache: ThumbnailLRUCache = {
        return ThumbnailLRUCache(countLimit: limit)
    }()
    private var ocIdEtag: [String: String] = [:]
    private var metadatas: [tableMetadata]?

    var isMediaMetadatasInProcess: Bool = false

    override private init() {}

    func createMediaCache(account: String) {

        guard account != self.account, !account.isEmpty else { return }
        self.account = account

        ocIdEtag.removeAll()
        self.metadatas = []
        self.metadatas = getMediaMetadatas(account: account)
        guard let metadatas = self.metadatas, !metadatas.isEmpty else { return }
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

        if let enumerator = manager.enumerator(at: URL(fileURLWithPath: NCUtilityFileSystem().directoryProviderStorage), includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
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
                    cache.setValue(.actual(image), forKey: file.ocId)
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

    func initialMetadatas() -> [tableMetadata]? {
        let metadatas = self.metadatas
        self.metadatas = nil
        return metadatas
    }

    func getMediaImage(ocId: String) -> ImageType? {
        return cache.value(forKey: ocId)
    }

    func setMediaImage(ocId: String, image: ImageType) {
        cache.setValue(image, forKey: ocId)
    }

    @objc func clearMediaCache() {

        self.ocIdEtag.removeAll()
        self.metadatas?.removeAll()
        self.metadatas = nil
        cache.removeAllValues()
    }

    func getMediaMetadatas(account: String, predicate: NSPredicate? = nil) -> [tableMetadata] {

        defer {
            self.isMediaMetadatasInProcess = false
            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterFinishedMediaInProcess)
        }
        self.isMediaMetadatasInProcess = true

        guard let account = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", account)) else { return [] }
        let startServerUrl = NCUtilityFileSystem().getHomeServer(urlBase: account.urlBase, userId: account.userId) + account.mediaPath

        let predicateDefault = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == %@ OR classFile == %@) AND NOT (session CONTAINS[c] 'upload') AND NOT (livePhotoFile != '' AND classFile == %@)", account.account, startServerUrl, NKCommon.TypeClassFile.image.rawValue, NKCommon.TypeClassFile.video.rawValue, NKCommon.TypeClassFile.video.rawValue)

        return NCManageDatabase.shared.getMetadatasMedia(predicate: predicate ?? predicateDefault)
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

        let yellowFavorite = NCBrandColor.shared.yellowFavorite
        let utility = NCUtility()

        images.file = UIImage(named: "file")!

        images.shared = UIImage(named: "share")!.image(color: .systemGray, size: 50)
        images.canShare = UIImage(named: "share")!.image(color: .systemGray, size: 50)
        images.shareByLink = UIImage(named: "sharebylink")!.image(color: .systemGray, size: 50)

        images.favorite = utility.loadImage(named: "star.fill", color: yellowFavorite)
        images.comment = UIImage(named: "comment")!.image(color: .systemGray, size: 50)
        images.livePhoto = utility.loadImage(named: "livephoto", color: .label)
        images.offlineFlag = UIImage(named: "offlineFlag")!
        images.local = UIImage(named: "local")!

        images.checkedYes = utility.loadImage(named: "checkmark.circle.fill", color: .systemBlue)
        images.checkedNo = utility.loadImage(named: "circle", color: .systemGray)

        images.buttonMore = UIImage(named: "more")!.image(color: .systemGray, size: 50)
        images.buttonStop = UIImage(named: "stop")!.image(color: .systemGray, size: 50)
        images.buttonMoreLock = UIImage(named: "moreLock")!.image(color: .systemGray, size: 50)
        images.buttonRestore = UIImage(named: "restore")!.image(color: .systemGray, size: 50)
        images.buttonTrash = UIImage(named: "trash")!.image(color: .systemGray, size: 50)

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
