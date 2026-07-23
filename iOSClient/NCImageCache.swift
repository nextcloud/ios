// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import RealmSwift

final class NCImageCache: @unchecked Sendable {
    static let shared = NCImageCache()

    private let utility = NCUtility()
    private let utilityFileSystem = NCUtilityFileSystem()
    private let global = NCGlobal.shared
    private let database = NCManageDatabase.shared
    private let allowExtensions = [NCGlobal.shared.previewExt256]

    public var countLimit: Int = 1500 {
        didSet {
            cache.countLimit = countLimit
        }
    }

    private let cache = NSCache<NSString, UIImage>()

    public var isLoadingCache: Bool = false
    public var controller: UITabBarController?

    init() {
        cache.countLimit = countLimit

        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil) { _ in
            self.cache.removeAllObjects()
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
            self.cache.removeAllObjects()
        }

#if !EXTENSION
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { _ in
            Task {
                guard let controller = self.controller as? NCMainTabBarController,
                      !self.isLoadingCache else {
                    return
                }

                self.isLoadingCache = true

                let session = await NCSession.shared.getSession(account: controller.account)

                guard let tblAccount = await self.database.getTableAccountAsync(predicate: NSPredicate(format: "account == %@", controller.account)) else {
                    self.isLoadingCache = false
                    return
                }

                let mediaPredicate = self.getMediaPredicate(session: session,
                                                            mediaPath: tblAccount.mediaPath,
                                                            showOnlyImages: false,
                                                            showOnlyVideos: false)

                let compactMetadatas = await self.database.getMediaCompactMetadatasAsync(
                    predicate: mediaPredicate,
                    sortedByKeyPath: "date",
                    ascending: false
                )

                autoreleasepool {
                    self.cache.removeAllObjects()
                    for compactMetadata in compactMetadatas {
                        guard !isAppInBackground else {
                            self.cache.removeAllObjects()
                            break
                        }
                        if let image = self.utility.getImage(ocId: compactMetadata.ocId,
                                                             etag: compactMetadata.etag,
                                                             ext: self.global.previewExt256,
                                                             userId: session.userId,
                                                             urlBase: session.urlBase) {
                            self.addImageCache(ocId: compactMetadata.ocId,
                                               etag: compactMetadata.etag,
                                               image: image,
                                               ext: self.global.previewExt256)
                        }
                    }
                    self.isLoadingCache = false
                }
            }
        }
#endif
    }

    func allowExtensions(ext: String) -> Bool {
        return allowExtensions.contains(ext)
    }

    func addImageCache(ocId: String, etag: String, data: Data, ext: String) {
        guard allowExtensions.contains(ext),
              let image = UIImage(data: data) else { return }

        cache.setObject(image, forKey: (ocId + etag + ext) as NSString)
    }

    func addImageCache(ocId: String, etag: String, image: UIImage, ext: String) {
        guard allowExtensions.contains(ext) else { return }

        cache.setObject(image, forKey: (ocId + etag + ext) as NSString)
    }

    func addImageCache(image: UIImage, key: String) {
        cache.setObject(image, forKey: key as NSString)
    }

    func getImageCache(ocId: String, etag: String, ext: String) -> UIImage? {
        return cache.object(forKey: (ocId + etag + ext) as NSString)
    }

    func getImageCache(key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }

    func removeImageCache(ocIdPlusEtag: String) {
        for ext in allowExtensions {
            cache.removeObject(forKey: (ocIdPlusEtag + ext) as NSString)
        }
    }

    func removeAll() {
        cache.removeAllObjects()
    }

    // MARK: - MEDIA -

    func getMediaPredicate(session: NCSession.Session,
                           mediaPath: String,
                           showOnlyImages: Bool,
                           showOnlyVideos: Bool) -> NSPredicate {
        let startServerUrl = self.utilityFileSystem.getHomeServer(session: session) + mediaPath

        let showBothPredicate = """
        account == %@ AND
        serverUrl BEGINSWITH %@ AND
        hasPreview == true AND
        (
        classFile == '\(NKTypeClassFile.image.rawValue)' OR classFile == '\(NKTypeClassFile.video.rawValue)'
        ) AND
        NOT (status IN %@)
        """

        let showOnlyPredicateImage = """
        account == %@ AND
        serverUrl BEGINSWITH %@ AND
        hasPreview == true AND
        (
        classFile == '\(NKTypeClassFile.image.rawValue)' OR (classFile == '\(NKTypeClassFile.video.rawValue)' AND livePhotoFile != '')
        ) AND
        NOT (status IN %@)
        """

        let showOnlyPredicateVideo = """
        account == %@ AND
        serverUrl BEGINSWITH %@ AND
        hasPreview == true AND
        classFile == 'video' AND
        NOT (status IN %@)
        """

        if showOnlyImages {
            return NSPredicate(format: showOnlyPredicateImage,
                               session.account,
                               startServerUrl,
                               global.metadataStatusHideInView)
        } else if showOnlyVideos {
            return NSPredicate(format: showOnlyPredicateVideo,
                               session.account,
                               startServerUrl,
                               global.metadataStatusHideInView)
        } else {
            return NSPredicate(format: showBothPredicate,
                               session.account,
                               startServerUrl,
                               global.metadataStatusHideInView)
        }
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

    func getImageFavorite(colors: [UIColor] = [NCBrandColor.shared.yellowFavorite]) -> UIImage {
        return utility.loadImage(named: "star.fill", colors: colors)
    }

    func getImageOfflineFlag(colors: [UIColor] = [.systemGreen]) -> UIImage {
        return utility.loadImage(named: "arrow.down.circle.fill", colors: colors)
    }

    func getImageLocal(colors: [UIColor] = [.systemGreen]) -> UIImage {
        return utility.loadImage(named: "checkmark.circle.fill", colors: colors)
    }

    func getImageCheckedYes(color: UIColor) -> UIImage? {
        let config = UIImage.SymbolConfiguration(paletteColors: [.white, color])
        return UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)
    }

    func getImageCheckedNo(color: UIColor) -> UIImage? {
        let weightConfig = UIImage.SymbolConfiguration(weight: .light)
        let colorConfig = UIImage.SymbolConfiguration(paletteColors: [color])
        let config = weightConfig.applying(colorConfig)
        return UIImage(systemName: "circle", withConfiguration: config)
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
