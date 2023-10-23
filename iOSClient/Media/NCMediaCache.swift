//
//  NCMediaCache.swift
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

@objc class NCMediaCache: NSObject {

    @objc public static let shared: NCMediaCache = {
        let instance = NCMediaCache()
        return instance
    }()

    private let limit: Int = 1500
    private typealias ThumbnailLRUCache = LRUCache<String, UIImage>
    private lazy var cache: ThumbnailLRUCache = {
        return ThumbnailLRUCache(countLimit: limit)
    }()
    public var metadatas: [tableMetadata] = []
    public var predicateDefault: NSPredicate?
    public var predicate: NSPredicate?

    func createCache(account: String) {

        let resultsMedia = NCManageDatabase.shared.getMediaOcIdEtag(account: account)
        guard !resultsMedia.isEmpty,
              let directory = CCUtility.getDirectoryProviderStorage() else { return }

        metadatas.removeAll()
        getMetadatasMedia(account: account)

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

        if let enumerator = manager.enumerator(at: URL(fileURLWithPath: directory), includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator where fileURL.lastPathComponent.hasSuffix(ext) {
                let fileName = fileURL.lastPathComponent
                let ocId = fileURL.deletingLastPathComponent().lastPathComponent
                guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                        let size = resourceValues.fileSize,
                        size > 0,
                        let date = resourceValues.creationDate,
                        let etag = resultsMedia[ocId],
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

    func getImage(ocId: String) -> UIImage? {

        return cache.value(forKey: ocId)
    }

    func setImage(ocId: String, image: UIImage) {

        cache.setValue(image, forKey: ocId)
    }

    @objc func clearCache() {

        cache.removeAllValues()
    }

    func getMetadatasMedia(account: String, filterClassTypeImage: Bool = false, filterClassTypeVideo: Bool = false) {

        let livePhoto = CCUtility.getLivePhoto()
        guard let appDelegate = (UIApplication.shared.delegate as? AppDelegate),
              let account = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", account)) else { return }
        let startServerUrl = NCUtilityFileSystem.shared.getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId) + account.mediaPath

        predicateDefault = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == %@ OR classFile == %@) AND NOT (session CONTAINS[c] 'upload')", account.account, startServerUrl, NKCommon.TypeClassFile.image.rawValue, NKCommon.TypeClassFile.video.rawValue)

        if filterClassTypeImage {
            predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND classFile == %@ AND NOT (session CONTAINS[c] 'upload')", account.account, startServerUrl, NKCommon.TypeClassFile.video.rawValue)
        } else if filterClassTypeVideo {
            predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND classFile == %@ AND NOT (session CONTAINS[c] 'upload')", account.account, startServerUrl, NKCommon.TypeClassFile.image.rawValue)
        } else {
            predicate = predicateDefault
        }

        guard let predicate = predicate else { return }

        metadatas = NCManageDatabase.shared.getMetadatasMedia(predicate: predicate, livePhoto: livePhoto)

        switch CCUtility.getMediaSortDate() {
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
}
