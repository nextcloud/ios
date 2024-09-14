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

    private let countLimit = 1000
    private let totalCostLimit = 5000

    private let allowExtensions = [NCGlobal.shared.previewExt256, NCGlobal.shared.previewExt128]
    private var brandElementColor: UIColor?
    private var totalSize: Int64 = 0
    private typealias ThumbnailImageCache = LRUCache<String, UIImage>

    private lazy var cacheImage: ThumbnailImageCache = {
        return ThumbnailImageCache(totalCostLimit: totalCostLimit, countLimit: countLimit)
    }()

    var createCacheInProgress: Bool = false

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handleMemoryWarning), name: LRUCacheMemoryWarningNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: LRUCacheMemoryWarningNotification, object: nil)
    }

    @objc func handleMemoryWarning() {
        cacheImage.removeAllValues()
    }

    ///
    /// IMAGE CACHE
    ///
    func createCache() {
        if createCacheInProgress {
            return
        }
        createCacheInProgress = true
        cacheImage.removeAllValues()

        let manager = FileManager.default
        let resourceKeys = Set<URLResourceKey>([.nameKey, .pathKey, .fileSizeKey, .creationDateKey])
        let startDate = Date()
        var counter: Int = 0
        var totalSize: Int64 = 0

        if let enumerator = manager.enumerator(at: URL(fileURLWithPath: NCUtilityFileSystem().directoryProviderStorage), includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {

            for case let fileURL as URL in enumerator where allowExtensions.contains(where: { fileURL.lastPathComponent.hasSuffix($0) }) {

                let fileName = fileURL.lastPathComponent
                let ocId = fileURL.deletingLastPathComponent().lastPathComponent
                guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                      let fileSize = resourceValues.fileSize,
                      fileSize > 0 else { continue }

                autoreleasepool {
                    if let image = UIImage(contentsOfFile: fileURL.path) {
                        let cost = fileSize / 1000
                        cacheImage.setValue(image, forKey: ocId + fileName, cost: cost)
                        totalSize = totalSize + Int64(fileSize)
                        counter += 1
                        print(fileSize, cost)
                    }
                }
            }
        }

        let diffDate = Date().timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate
        NextcloudKit.shared.nkCommonInstance.writeLog("--------- Image cache process ---------")
        NextcloudKit.shared.nkCommonInstance.writeLog("Count: \(cacheImage.count)")
        NextcloudKit.shared.nkCommonInstance.writeLog("Total cost: \(cacheImage.totalCost)")
        NextcloudKit.shared.nkCommonInstance.writeLog("Total size: " + NCUtilityFileSystem().transformedSize(totalSize))
        NextcloudKit.shared.nkCommonInstance.writeLog("Time process: \(diffDate)")
        NextcloudKit.shared.nkCommonInstance.writeLog("---------------------------------------")

        createCacheInProgress = false
    }

    ///
    /// CACHE
    ///
    func addImageCache(ocId: String, etag: String, data: Data, ext: String) {
        guard allowExtensions.contains(ext),
              let image = UIImage(data: data),
              cacheImage.count < countLimit else { return }

        let cost = data.count / 1000
        cacheImage.setValue(image, forKey: ocId + etag + ext, cost: cost)
    }

    func addImageCache(ocId: String, etag: String, image: UIImage, ext: String) {
        guard allowExtensions.contains(ext),
              let data = image.jpegData(compressionQuality: 1.0) else { return }

        let cost = data.count / 1000
        cacheImage.setValue(image, forKey: ocId + etag + ext)
    }

    func getImageCache(ocId: String, etag: String, ext: String) -> UIImage? {
        return cacheImage.value(forKey: ocId + etag + ext)
    }

    func removeImageCache(ocId: String, etag: String) {
        let exts = [global.previewExt1024,
                    global.previewExt512,
                    global.previewExt256,
                    global.previewExt128]

        for i in 0..<exts.count {
            cacheImage.removeValue(forKey: ocId + etag + exts[i])
        }
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
