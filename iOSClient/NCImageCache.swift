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

    private let utility = NCUtility()
    private let global = NCGlobal.shared

    private let allowExtensions = [NCGlobal.shared.previewExt256, NCGlobal.shared.previewExt128, NCGlobal.shared.previewExt64]
    private var brandElementColor: UIColor?

    public var countLimit = 5_000
    lazy var cache: LRUCache<String, UIImage> = {
        return LRUCache<String, UIImage>(countLimit: countLimit)
    }()

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handleMemoryWarning), name: LRUCacheMemoryWarningNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: LRUCacheMemoryWarningNotification, object: nil)
    }

    @objc func handleMemoryWarning() {
        cache.removeAllValues()
        countLimit = countLimit - 500
        if countLimit <= 0 { countLimit = 100 }
        self.cache = LRUCache<String, UIImage>(countLimit: countLimit)
    }

    func addImageCache(ocId: String, etag: String, data: Data, ext: String, cost: Int) {
        guard allowExtensions.contains(ext),
              cache.count < countLimit,
              let image = UIImage(data: data) else { return }

        cache.setValue(image, forKey: ocId + etag + ext, cost: cost)
    }

    func addImageCache(ocId: String, etag: String, image: UIImage, ext: String, cost: Int) {
        guard allowExtensions.contains(ext),
              cache.count < countLimit else { return }

        cache.setValue(image, forKey: ocId + etag + ext, cost: cost)
    }

    func getImageCache(ocId: String, etag: String, ext: String) -> UIImage? {
        return cache.value(forKey: ocId + etag + ext)
    }

    func removeImageCache(ocIdPlusEtag: String) {
        let exts = [global.previewExt1024,
                    global.previewExt512,
                    global.previewExt256,
                    global.previewExt128,
                    global.previewExt64]

        for i in 0..<exts.count {
            cache.removeValue(forKey: ocIdPlusEtag + exts[i])
        }
    }

    func removeAll() {
        cache.removeAllValues()
    }

    // MARK: -

    func getMediaPredicate(filterLivePhotoFile: Bool, session: NCSession.Session, showOnlyImages: Bool, showOnlyVideos: Bool) -> NSPredicate {
        guard let tableAccount = NCManageDatabase.shared.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account)) else { return NSPredicate() }
        let startServerUrl = NCUtilityFileSystem().getHomeServer(session: session) + tableAccount.mediaPath

        var showBothPredicateMediaString = "account == %@ AND serverUrl BEGINSWITH %@ AND hasPreview == true AND (classFile == '\(NKCommon.TypeClassFile.image.rawValue)' OR classFile == '\(NKCommon.TypeClassFile.video.rawValue)') AND NOT (session CONTAINS[c] 'upload')"
        var showOnlyPredicateMediaString = "account == %@ AND serverUrl BEGINSWITH %@ AND hasPreview == true AND classFile == %@ AND NOT (session CONTAINS[c] 'upload')"

        if filterLivePhotoFile {
            showBothPredicateMediaString = showBothPredicateMediaString + " AND NOT (livePhotoFile != '' AND classFile == '\(NKCommon.TypeClassFile.video.rawValue)')"
            showOnlyPredicateMediaString = showOnlyPredicateMediaString + " AND NOT (livePhotoFile != '' AND classFile == '\(NKCommon.TypeClassFile.video.rawValue)')"
        }

        if showOnlyImages {
            return NSPredicate(format: showOnlyPredicateMediaString, session.account, startServerUrl, NKCommon.TypeClassFile.image.rawValue)
        } else if showOnlyVideos {
            return NSPredicate(format: showOnlyPredicateMediaString, session.account, startServerUrl, NKCommon.TypeClassFile.video.rawValue)
        } else {
            return NSPredicate(format: showBothPredicateMediaString, session.account, startServerUrl)
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
