//
//  NCMediaManager.swift
//  Nextcloud
//
//  Created by Milen on 10.10.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import UIKit
import LRUCache
import NextcloudKit
import Queuer

struct ScaledThumbnail: Hashable {
    let image: UIImage
    var isPlaceholderImage = false
    var scaledSize: CGSize = .zero
    let ocId: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(ocId)
    }
}

@objc class NCMediaManager: NSObject {

    @objc public static let shared: NCMediaManager = {
        let instance = NCMediaManager()
        return instance
    }()

    typealias ThumbnailLRUCache = LRUCache<String, ScaledThumbnail>
    private let cache: ThumbnailLRUCache = ThumbnailLRUCache(countLimit: 2000)

    @objc func createCache(account: String) {

        let resultsMedia = NCManageDatabase.shared.getMediaOcIdEtag(account: account)
        guard !resultsMedia.isEmpty,
              let directory = CCUtility.getDirectoryProviderStorage() else { return }

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
        NextcloudKit.shared.nkCommonInstance.writeLog("--------- start ThumbnailLRUCache image process ---------")

        // Get files only image / video
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

        // Sort for most recent
        files.sort(by: { $0.date > $1.date })
        if let firstDate = files.first?.date, let lastDate = files.last?.date {
            print("First date: \(firstDate)")
            print("Last date: \(lastDate)")
        }

        // Insert in cache
        cache.removeAllValues()
        for file in files {
            autoreleasepool {
                if let image = UIImage(contentsOfFile: file.path.path) {
                    let scaledThumbnail = ScaledThumbnail(image: image, ocId: file.ocId)
                    cache.setValue(scaledThumbnail, forKey: file.ocId)
                }
            }
        }

        let endDate = Date()
        let diffDate = endDate.timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate
        NextcloudKit.shared.nkCommonInstance.writeLog("Counter process: \(cache.count)")
        NextcloudKit.shared.nkCommonInstance.writeLog("Time process: \(diffDate)")
        NextcloudKit.shared.nkCommonInstance.writeLog("--------- stop ThumbnailLRUCache image process ---------")
    }

    func getImage(ocId: String) -> UIImage? {

        if let scaledThumbnail = cache.value(forKey: ocId) {
            return scaledThumbnail.image
        }
        return nil
    }

    func setImage(ocId: String, image: UIImage) {

        let scaledThumbnail = ScaledThumbnail(image: image, ocId: ocId)
        cache.setValue(scaledThumbnail, forKey: ocId)
    }

    @objc func clearCache() {

        cache.removeAllValues()
    }
}
