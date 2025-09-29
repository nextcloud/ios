// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import LRUCache
import NextcloudKit
import RealmSwift

final class NCImageCache: @unchecked Sendable {
    static let shared = NCImageCache()

    private let utility = NCUtility()
    private let utilityFileSystem = NCUtilityFileSystem()
    private let global = NCGlobal.shared
    private let database = NCManageDatabase.shared

    private let allowExtensions = [NCGlobal.shared.previewExt256]
    private var brandElementColor: UIColor?

    public var countLimit: Int = 2000
    lazy var cache: LRUCache<String, UIImage> = {
        return LRUCache<String, UIImage>(countLimit: countLimit)
    }()

    public var isLoadingCache: Bool = false
    public var controller: UITabBarController?

    init() {
        NotificationCenter.default.addObserver(forName: LRUCacheMemoryWarningNotification, object: nil, queue: nil) { _ in
            self.cache.removeAll()
            self.cache = LRUCache<String, UIImage>(countLimit: self.countLimit)
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
            self.cache.removeAll()
            self.cache = LRUCache<String, UIImage>(countLimit: self.countLimit)
        }

        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { _ in
#if !EXTENSION
            Task {
                guard let controller = self.controller as? NCMainTabBarController,
                    !self.isLoadingCache else {
                    return
                }

                var cost: Int = 0
                let session = await NCSession.shared.getSession(account: controller.account)

                if let tblAccount = await self.database.getTableAccountAsync(predicate: NSPredicate(format: "account == %@", controller.account)),
                   NCImageCache.shared.cache.count == 0 {

                    // MEDIA
                    let predicate = self.getMediaPredicate(session: session, mediaPath: tblAccount.mediaPath, showOnlyImages: false, showOnlyVideos: false)
                    guard let metadatas = await self.database.getMetadatasAsync(predicate: predicate, sortedByKeyPath: "datePhotosOriginal", limit: self.countLimit) else {
                        return
                    }

                    self.isLoadingCache = true
                    self.database.filterAndNormalizeLivePhotos(from: metadatas) { metadatas in
                        autoreleasepool {
                            self.cache.removeAll()
                            for metadata in metadatas {
                                guard !isAppInBackground else {
                                    self.cache.removeAll()
                                    break
                                }
                                if let image = self.utility.getImage(ocId: metadata.ocId,
                                                                     etag: metadata.etag,
                                                                     ext: self.global.previewExt256,
                                                                     userId: metadata.userId,
                                                                     urlBase: metadata.urlBase) {
                                    self.addImageCache(ocId: metadata.ocId, etag: metadata.etag, image: image, ext: self.global.previewExt256, cost: cost)
                                    cost += 1
                                }
                            }
                            self.isLoadingCache = false
                        }
                    }
                }
            }
#endif
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: LRUCacheMemoryWarningNotification, object: nil)
    }

    func allowExtensions(ext: String) -> Bool {
        return allowExtensions.contains(ext)
    }

    func addImageCache(ocId: String, etag: String, data: Data, ext: String, cost: Int) {
        guard allowExtensions.contains(ext),
              let image = UIImage(data: data) else { return }

        cache.setValue(image, forKey: ocId + etag + ext, cost: cost)
    }

    func addImageCache(ocId: String, etag: String, image: UIImage, ext: String, cost: Int) {
        guard allowExtensions.contains(ext) else { return }

        cache.setValue(image, forKey: ocId + etag + ext, cost: cost)
    }

    func addImageCache(image: UIImage, key: String) {
        cache.setValue(image, forKey: key)
    }

    func getImageCache(ocId: String, etag: String, ext: String) -> UIImage? {
        return cache.value(forKey: ocId + etag + ext)
    }

    func getImageCache(key: String) -> UIImage? {
        return cache.value(forKey: key)
    }

    func removeImageCache(ocIdPlusEtag: String) {
        for i in 0..<allowExtensions.count {
            cache.removeValue(forKey: ocIdPlusEtag + allowExtensions[i])
        }
    }

    func removeAll() {
        cache.removeAll()
    }

    // MARK: - MEDIA -

    func getMediaPredicate(session: NCSession.Session,
                           mediaPath: String,
                           showOnlyImages: Bool,
                           showOnlyVideos: Bool) -> NSPredicate {
        var predicate = NSPredicate()
        let startServerUrl = self.utilityFileSystem.getHomeServer(session: session) + mediaPath
        let showBothPredicateMediaString = "account == %@ AND serverUrl BEGINSWITH %@ AND mediaSearch == true AND hasPreview == true AND (classFile == '\(NKTypeClassFile.image.rawValue)' OR classFile == '\(NKTypeClassFile.video.rawValue)') AND NOT (status IN %@)"
        let showOnlyPredicateMediaString = "account == %@ AND serverUrl BEGINSWITH %@ AND mediaSearch == true AND hasPreview == true AND classFile == %@ AND NOT (status IN %@)"

        if showOnlyImages {
            predicate = NSPredicate(format: showOnlyPredicateMediaString, session.account, startServerUrl, NKTypeClassFile.image.rawValue, global.metadataStatusHideInView)
        } else if showOnlyVideos {
            predicate = NSPredicate(format: showOnlyPredicateMediaString, session.account, startServerUrl, NKTypeClassFile.video.rawValue, global.metadataStatusHideInView)
        } else {
            predicate = NSPredicate(format: showBothPredicateMediaString, session.account, startServerUrl, global.metadataStatusHideInView)
        }

        return predicate
    }

    // MARK: -

    func getImageFile(colors: [UIColor] = [NCBrandColor.shared.iconImageColor2]) -> UIImage {
        return utility.loadImage(named: "doc", colors: colors)
    }

    func getImageShared(colors: [UIColor] = NCBrandColor.shared.iconImageMultiColors) -> UIImage {
        return utility.loadImage(named: "person.fill.badge.plus", colors: colors)
    }

    func getImageCanShare(colors: [UIColor] = NCBrandColor.shared.iconImageMultiColors) -> UIImage {
        return utility.loadImage(named: "person.fill.badge.plus", colors: colors)
    }

    func getImageShareByLink(colors: [UIColor] = [NCBrandColor.shared.iconImageColor]) -> UIImage {
        return utility.loadImage(named: "link", colors: colors)
    }

    func getImageFavorite(colors: [UIColor] = [.systemBackground, NCBrandColor.shared.yellowFavorite]) -> UIImage {
        return utility.loadImage(named: "star.circle.fill", colors: colors)
    }

    func getImageOfflineFlag(colors: [UIColor] = [.systemGreen]) -> UIImage {
        return utility.loadImage(named: "arrow.down.circle.fill", colors: colors)
    }

    func getImageLocal(colors: [UIColor] = [.systemGreen]) -> UIImage {
        return utility.loadImage(named: "checkmark.circle.fill", colors: colors)
    }

    func getImageCheckedYes(colors: [UIColor] = [NCBrandColor.shared.iconImageColor2]) -> UIImage {
        return utility.loadImage(named: "checkmark.circle.fill", colors: colors)
    }

    func getImageCheckedNo(colors: [UIColor] = [NCBrandColor.shared.iconImageColor]) -> UIImage {
        return utility.loadImage(named: "circle", colors: colors)
    }

    func getImageButtonMore(colors: [UIColor] = [NCBrandColor.shared.iconImageColor]) -> UIImage {
        return utility.loadImage(named: "ellipsis", colors: colors)
    }

    func getImageButtonStop(colors: [UIColor] = [NCBrandColor.shared.iconImageColor]) -> UIImage {
        return utility.loadImage(named: "stop.circle", colors: colors)
    }

    func getImageButtonMoreLock(colors: [UIColor] = [NCBrandColor.shared.iconImageColor]) -> UIImage {
        return utility.loadImage(named: "lock.fill", colors: colors)
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
