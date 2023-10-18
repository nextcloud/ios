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

@objc class NCMediaManager {

    @objc public static let shared: NCMediaManager = {
        let instance = NCMediaManager()
        return instance
    }()

    private typealias ThumbnailLRUCache = LRUCache<String, UIImage>
    private let cache: ThumbnailLRUCache = ThumbnailLRUCache(countLimit: 1500)

    func createCache(account: String) {

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
        let startMemory = NCUtility.shared.getMemoryUsedAndDeviceTotalInMegabytes()
        NextcloudKit.shared.nkCommonInstance.writeLog("--------- start ThumbnailLRUCache image process ---------")
        NextcloudKit.shared.nkCommonInstance.writeLog("Memory used in MB: \(startMemory.0)")

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
                    cache.setValue(image, forKey: file.ocId)
                }
            }
        }

        let endDate = Date()
        let diffDate = endDate.timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate
        let endMemory = NCUtility.shared.getMemoryUsedAndDeviceTotalInMegabytes()
        let usedMemory = endMemory.0 - startMemory.0
        NextcloudKit.shared.nkCommonInstance.writeLog("Counter process: \(cache.count)")
        NextcloudKit.shared.nkCommonInstance.writeLog("Time process: \(diffDate)")
        NextcloudKit.shared.nkCommonInstance.writeLog("Memory used in MB: \(endMemory.0)")
        NextcloudKit.shared.nkCommonInstance.writeLog("Memory used for cache in MB: \(usedMemory)")
        NextcloudKit.shared.nkCommonInstance.writeLog("--------- stop ThumbnailLRUCache image process ---------")
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
}
