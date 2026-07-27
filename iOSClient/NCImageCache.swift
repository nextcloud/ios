// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit

final class NCImageCache: @unchecked Sendable {
    static let shared = NCImageCache()

    private let utility = NCUtility()
    private let cache = NSCache<NSString, UIImage>()
    private let maximumCachedImages = 510

    private var cacheWindowRadius: Int {
        maximumCachedImages / 2
    }
    private var cacheWindowUpdateThreshold: Int {
        maximumCachedImages / 6
    }
    @MainActor private var lastCacheCenterIndex: Int?
    @MainActor private var lastCacheExtension: String?
    @MainActor private var cacheWindowTask: Task<Void, Never>?
    @MainActor private var missingImageCacheKeys: Set<String> = []

    struct ImageCacheWindowItem: Sendable {
        let ocId: String
        let etag: String
    }
    private func imageCacheKey(ocId: String, etag: String, ext: String) -> String {
        "\(ocId)-\(etag)-\(ext)"
    }

    private init() {
        cache.countLimit = maximumCachedImages

        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.removeAll()
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.removeAll()
            }
        }
    }

    private func cacheKey(ocId: String, etag: String, ext: String) -> NSString {
        imageCacheKey(ocId: ocId, etag: etag, ext: ext) as NSString
    }

    func addImageCache(ocId: String, etag: String, image: UIImage, ext: String) {
        cache.setObject(image, forKey: cacheKey(ocId: ocId, etag: etag, ext: ext))
    }

    func getImageCache(ocId: String, etag: String, ext: String) -> UIImage? {
        cache.object(forKey: cacheKey(ocId: ocId, etag: etag, ext: ext))
    }

    @MainActor
    func removeAll() {
        cacheWindowTask?.cancel()
        cacheWindowTask = nil
        lastCacheCenterIndex = nil
        lastCacheExtension = nil
        missingImageCacheKeys.removeAll()
        cache.removeAllObjects()
    }

    // MARK: -

    @MainActor
    func updateImageCacheWindow(
        imageCacheWindowItems: [ImageCacheWindowItem],
        centerIndex: Int,
        numberOfColumns: Int,
        session: NCSession.Session,
        force: Bool = false
    ) {
        guard imageCacheWindowItems.indices.contains(centerIndex) else {
            return
        }
        let ext = NCGlobal.shared.getSizeExtension(column: numberOfColumns)

        if !force,
           lastCacheExtension == ext,
           let lastCacheCenterIndex,
           abs(centerIndex - lastCacheCenterIndex) < cacheWindowUpdateThreshold {
            return
        }

        lastCacheCenterIndex = centerIndex
        lastCacheExtension = ext

        cacheWindowTask?.cancel()

        cacheWindowTask = Task { [weak self] in
            guard let self else {
                return
            }

            await self.loadImageCacheWindow(
                imageCacheWindowItems: imageCacheWindowItems,
                centerIndex: centerIndex,
                ext: ext,
                session: session
            )
        }
    }

    @MainActor
    private func loadImageCacheWindow(
        imageCacheWindowItems: [ImageCacheWindowItem],
        centerIndex: Int,
        ext: String,
        session: NCSession.Session
    ) async {
        let itemCount = imageCacheWindowItems.count
        guard itemCount > 0,
              imageCacheWindowItems.indices.contains(centerIndex) else {
            return
        }

        let lowerBound = max(0, centerIndex - cacheWindowRadius)
        let upperBound = min(itemCount, centerIndex + cacheWindowRadius + 1)
        let userId = session.userId
        let urlBase = session.urlBase
        let items = Array(imageCacheWindowItems[lowerBound..<upperBound])
        var cacheHits = 0
        var diskReads = 0
        var knownMissingImages = 0
        var newMissingImages = 0
        var loadedImages = 0

        print("[MEDIA CACHE] START center: \(centerIndex) range: \(lowerBound)..<\(upperBound) items: \(items.count) ext: \(ext)")

        for item in items {
            guard !Task.isCancelled else {
                print("[MEDIA CACHE] CANCELLED center: \(centerIndex) hits: \(cacheHits) diskReads: \(diskReads) knownMissing: \(knownMissingImages) newMissing: \(newMissingImages) loaded: \(loadedImages)")
                return
            }

            let key = imageCacheKey(ocId: item.ocId, etag: item.etag, ext: ext)

            if missingImageCacheKeys.contains(key) {
                knownMissingImages += 1
                continue
            }

            if getImageCache(ocId: item.ocId, etag: item.etag, ext: ext) != nil {
                cacheHits += 1
                continue
            }

            diskReads += 1

            let image = await Task.detached(priority: .utility) {
                autoreleasepool {
                    NCUtility().getImage(
                        ocId: item.ocId,
                        etag: item.etag,
                        ext: ext,
                        userId: userId,
                        urlBase: urlBase
                    )
                }
            }.value

            guard !Task.isCancelled else {
                print("[MEDIA CACHE] CANCELLED center: \(centerIndex) hits: \(cacheHits) diskReads: \(diskReads) knownMissing: \(knownMissingImages) newMissing: \(newMissingImages) loaded: \(loadedImages)")
                return
            }

            guard let image else {
                missingImageCacheKeys.insert(key)
                newMissingImages += 1
                continue
            }

            addImageCache(
                ocId: item.ocId,
                etag: item.etag,
                image: image,
                ext: ext
            )

            loadedImages += 1
        }

        print("[MEDIA CACHE] END center: \(centerIndex) hits: \(cacheHits) diskReads: \(diskReads) knownMissing: \(knownMissingImages) newMissing: \(newMissingImages) loaded: \(loadedImages)")
    }

    // MARK: -

    func getImageFile(colors: [UIColor] = [NCBrandColor.shared.iconImageColor2]) -> UIImage {
        utility.loadImage(named: "doc", colors: colors)
    }

    func getImageShared(colors: [UIColor] = NCBrandColor.shared.iconImageMultiColors) -> UIImage {
        utility.loadImage(named: "person.fill.badge.plus", colors: colors)
    }

    func getImageCanShare(colors: [UIColor] = NCBrandColor.shared.iconImageMultiColors) -> UIImage {
        utility.loadImage(named: "person.fill.badge.plus", colors: colors)
    }

    func getImageShareByLink(colors: [UIColor] = [NCBrandColor.shared.iconImageColor]) -> UIImage {
        utility.loadImage(named: "link", colors: colors)
    }

    func getImageFavorite(colors: [UIColor] = [NCBrandColor.shared.yellowFavorite]) -> UIImage {
        utility.loadImage(named: "star.fill", colors: colors)
    }

    func getImageOfflineFlag(colors: [UIColor] = [.systemGreen]) -> UIImage {
        utility.loadImage(named: "arrow.down.circle.fill", colors: colors)
    }

    func getImageLocal(colors: [UIColor] = [.systemGreen]) -> UIImage {
        utility.loadImage(named: "checkmark.circle.fill", colors: colors)
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
        utility.loadImage(named: "ellipsis", colors: colors)
    }

    func getImageButtonStop(colors: [UIColor] = [NCBrandColor.shared.iconImageColor]) -> UIImage {
        utility.loadImage(named: "stop.circle", colors: colors)
    }

    func getImageButtonMoreLock(colors: [UIColor] = [NCBrandColor.shared.iconImageColor]) -> UIImage {
        utility.loadImage(named: "lock.fill", colors: colors)
    }

    func getFolder(account: String) -> UIImage {
        UIImage(named: "folder")!.image(color: NCBrandColor.shared.getElement(account: account))
    }

    func getFolderEncrypted(account: String) -> UIImage {
        UIImage(named: "folderEncrypted")!.image(color: NCBrandColor.shared.getElement(account: account))
    }

    func getFolderSharedWithMe(account: String) -> UIImage {
        UIImage(named: "folder_shared_with_me")!.image(color: NCBrandColor.shared.getElement(account: account))
    }

    func getFolderPublic(account: String) -> UIImage {
        UIImage(named: "folder_public")!.image(color: NCBrandColor.shared.getElement(account: account))
    }

    func getFolderGroup(account: String) -> UIImage {
        UIImage(named: "folder_group")!.image(color: NCBrandColor.shared.getElement(account: account))
    }

    func getFolderExternal(account: String) -> UIImage {
        UIImage(named: "folder_external")!.image(color: NCBrandColor.shared.getElement(account: account))
    }

    func getFolderAutomaticUpload(account: String) -> UIImage {
        UIImage(named: "folderAutomaticUpload")!.image(color: NCBrandColor.shared.getElement(account: account))
    }
}
