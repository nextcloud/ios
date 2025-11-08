// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import Photos

extension NCUtilityFileSystem {
    func removeGroupApplicationSupport() {
        let path = directoryGroup + "/" + NCGlobal.shared.appApplicationSupport
        try? fileManager.removeItem(atPath: path)
    }

    func removeGroupLibraryDirectory() {
        try? fileManager.removeItem(atPath: directoryScan)
        try? fileManager.removeItem(atPath: directoryUserData)
    }

    func removeGroupDirectoryProviderStorage() {
        let path = getDirectoryProviderStorage()
        try? fileManager.removeItem(atPath: path)
    }

    func removeDocumentsDirectory() {
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: directoryDocuments)

            for file in contents {
                let fullPath = (directoryDocuments as NSString).appendingPathComponent(file)
                try fileManager.removeItem(atPath: fullPath)
            }
        } catch {
            print(error)
        }
    }

    func removeTemporaryDirectory() {
        try? fileManager.removeItem(atPath: NSTemporaryDirectory())
    }

    func emptyTemporaryDirectory() {
        do {
            let files = try fileManager.contentsOfDirectory(atPath: NSTemporaryDirectory())
            for file in files {
                do {
                    try fileManager.removeItem(atPath: NSTemporaryDirectory() + "/" + file)
                } catch { print("Error: \(error)") }
            }
        } catch { print("Error: \(error)") }
    }

    func fileProviderStorageSize(_ ocId: String, fileName: String, userId: String, urlBase: String) -> UInt64 {
        let fileNamePath = getDirectoryProviderStorageOcId(ocId, fileName: fileName, userId: userId, urlBase: urlBase)
        do {
            let fileNameAttribute = try fileManager.attributesOfItem(atPath: fileNamePath)
            let fileNameSize: UInt64 = fileNameAttribute[FileAttributeKey.size] as? UInt64 ?? 0
            return fileNameSize
        } catch { print("Error: \(error)") }
        return 0
    }

    func fileProviderStorageImageExists(_ ocId: String, etag: String, ext: String, userId: String, urlBase: String) -> Bool {
        let fileNamePath = getDirectoryProviderStorageImageOcId(ocId, etag: etag, ext: ext, userId: userId, urlBase: urlBase)
        do {
            let fileNamePathAttribute = try fileManager.attributesOfItem(atPath: fileNamePath)
            let fileSize: UInt64 = fileNamePathAttribute[FileAttributeKey.size] as? UInt64 ?? 0
            if fileSize > 0 {
                return true
            } else {
                return false
            }
        } catch { }
        return false
    }

    func fileProviderStorageImageExists(_ ocId: String, etag: String, userId: String, urlBase: String) -> Bool {
        if fileProviderStorageImageExists(ocId, etag: etag, ext: NCGlobal.shared.previewExt1024, userId: userId, urlBase: urlBase),
           fileProviderStorageImageExists(ocId, etag: etag, ext: NCGlobal.shared.previewExt512, userId: userId, urlBase: urlBase),
           fileProviderStorageImageExists(ocId, etag: etag, ext: NCGlobal.shared.previewExt256, userId: userId, urlBase: urlBase) {
            return true
        }
        return false
    }

    func createDirectoryStandard() {
        guard let directoryGroup = fileManager.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup)?.path else { return }
        if !fileManager.fileExists(atPath: directoryDocuments) { try? fileManager.createDirectory(atPath: directoryDocuments, withIntermediateDirectories: true) }
        let appDatabaseNextcloud = directoryGroup + "/" + NCGlobal.shared.appDatabaseNextcloud
        if !fileManager.fileExists(atPath: appDatabaseNextcloud) { try? fileManager.createDirectory(atPath: appDatabaseNextcloud, withIntermediateDirectories: true) }
        if !fileManager.fileExists(atPath: directoryUserData) { try? fileManager.createDirectory(atPath: directoryUserData, withIntermediateDirectories: true) }
        let appScan = directoryGroup + "/" + NCGlobal.shared.appScan
        if !fileManager.fileExists(atPath: appScan) { try? fileManager.createDirectory(atPath: appScan, withIntermediateDirectories: true) }
        if !fileManager.fileExists(atPath: NSTemporaryDirectory()) { try? fileManager.createDirectory(atPath: NSTemporaryDirectory(), withIntermediateDirectories: true) }
        // Directory Excluded From Backup
        if let url = NSURL(string: directoryDocuments) {
            try? url.setResourceValue(true, forKey: URLResourceKey.isExcludedFromBackupKey)
        }
        if let url = NSURL(string: directoryGroup) {
            try? url.setResourceValue(true, forKey: URLResourceKey.isExcludedFromBackupKey)
        }
    }

    func getFileSize(filePath: String) -> Int64 {
        guard fileManager.fileExists(atPath: filePath)
        else {
            return 0
        }

        do {
            let attributes = try fileManager.attributesOfItem(atPath: filePath)
            return attributes[FileAttributeKey.size] as? Int64 ?? 0
        } catch {
            print(error)
            return 0
        }
    }

    func getFileModificationDate(filePath: String) -> NSDate? {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: filePath)
            return attributes[FileAttributeKey.modificationDate] as? NSDate
        } catch {
            print(error)
        }
        return nil
    }

    func getFileCreationDate(filePath: String) -> NSDate? {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: filePath)
            return attributes[FileAttributeKey.creationDate] as? NSDate
        } catch {
            print(error)
        }
        return nil
    }

    func isDirectoryE2EEAsync(serverUrl: String, urlBase: String, userId: String, account: String) async -> Bool {
        guard serverUrl != getHomeServer(urlBase: urlBase, userId: userId) else {
            return false
        }
        if let metadata = await NCManageDatabase.shared.getMetadataDirectoryAsync(serverUrl: serverUrl, account: account) {
            return metadata.e2eEncrypted
        }
        return false
    }

    /// Traverses up the directory hierarchy from the given URL and returns the topmost directory
    /// that is marked as end-to-end encrypted (`e2eEncrypted == true`).
    /// The search stops when a non-encrypted parent is found or when the root is reached.
    /// - Parameters:
    ///   - serverUrl: The full URL of the starting directory (may include trailing slash).
    ///   - account: The account identifier used to query metadata.
    /// - Returns: The topmost `tableMetadata` that is end-to-end encrypted, or `nil` if none is found.
    func getMetadataE2EETopAsync(serverUrl: String, session: NCSession.Session) async -> tableMetadata? {
        let homeServer = getHomeServer(session: session)
        guard var url = URL(string: serverUrl) else {
            return nil
        }
        var top: tableMetadata?

        while true {
            var urlString = url.absoluteString

            // Remove trailing slash if present to conform to metadata key format
            if urlString.hasSuffix("/") {
                urlString.removeLast()
            }
            // Decode the URL to match Realm keys
            guard let decodedUrlString = urlString.removingPercentEncoding else {
                return top
            }

            // Query metadata for current directory
            if let metadata = NCManageDatabase.shared.getMetadataDirectory(serverUrl: decodedUrlString, account: session.account) {
                if metadata.e2eEncrypted {
                    top = metadata
                } else {
                    return top
                }
            } else {
                return top
            }

            // Move to the parent directory
            let parent = url.deletingLastPathComponent()

            // Check if we reached the homeServer (decoded too)
            let normalizedParent = parent.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let decodedParent = normalizedParent.removingPercentEncoding else {
                break
            }
            if decodedParent == homeServer {
                break
            }

            url = parent
        }

        return top
    }

    func createGranularityPath(asset: PHAsset? = nil, serverUrlBase: String? = nil) -> String {
        let autoUploadSubfolderGranularity = NCManageDatabase.shared.getAccountAutoUploadSubfolderGranularity()
        let dateFormatter = DateFormatter()
        let date = asset?.creationDate ?? Date()
        var path = ""

        dateFormatter.dateFormat = "yyyy"
        let year = dateFormatter.string(from: date)
        dateFormatter.dateFormat = "MM"
        let month = dateFormatter.string(from: date)
        dateFormatter.dateFormat = "dd"
        let day = dateFormatter.string(from: date)
        if autoUploadSubfolderGranularity == NCGlobal.shared.subfolderGranularityYearly {
            path = "\(year)"
        } else if autoUploadSubfolderGranularity == NCGlobal.shared.subfolderGranularityDaily {
            path = "\(year)/\(month)/\(day)"
        } else {  // Month Granularity is default
            path = "\(year)/\(month)"
        }

        if let serverUrlBase {
            return serverUrlBase + "/" + path
        } else {
            return path
        }
    }

    func cleanUpAsync() async {
        let days = TimeInterval(NCPreferences().cleanUpDay)
        if days == 0 {
            return
        }
        let database = NCManageDatabase.shared
        let minimumDate = Date().addingTimeInterval(-days * 24 * 60 * 60)
        let url = URL(fileURLWithPath: getDirectoryProviderStorage())
        var offlineDir: [String] = []

        let tblDirectories = await database.getTablesDirectoryAsync(predicate: NSPredicate(format: "offline == true"), sorted: "serverUrl", ascending: true)
        for tblDirectory in tblDirectories {
            if let tblMetadata = await database.getMetadataFromOcIdAsync(tblDirectory.ocId) {
                offlineDir.append(self.getDirectoryProviderStorageOcId(tblMetadata.ocId, userId: tblMetadata.userId, urlBase: tblMetadata.urlBase))
            }
        }

        let tblLocalFiles = await NCManageDatabase.shared.getTableLocalFilesAsync(predicate: NSPredicate(format: "offline == false"), sorted: "lastOpeningDate", ascending: true)

        let fileURLs = await enumerateFilesAsync(at: url, includingPropertiesForKeys: [.isRegularFileKey])
        for fileURL in fileURLs {
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path) {
                if attributes[.size] as? Double == 0 { continue }
                if attributes[.type] as? FileAttributeType == FileAttributeType.typeDirectory { continue }
                // check directory offline
                let filter = offlineDir.filter({ fileURL.path.hasPrefix($0)})
                if !filter.isEmpty {
                    continue
                }
                // -----------------------
                if let modificationDate = attributes[.modificationDate] as? Date,
                   modificationDate < minimumDate {
                    let fileName = fileURL.lastPathComponent
                    if fileName.hasSuffix(NCGlobal.shared.previewExt256) || fileName.hasSuffix(NCGlobal.shared.previewExt512) || fileName.hasSuffix(NCGlobal.shared.previewExt1024) {
                        try? fileManager.removeItem(atPath: fileURL.path)
                    }
                }
                // -----------------------
                let folderURL = fileURL.deletingLastPathComponent()
                let ocId = folderURL.lastPathComponent
                if let tblLocalFile = tblLocalFiles.filter({ $0.ocId == ocId }).first,
                    (tblLocalFile.lastOpeningDate as Date) < minimumDate {
                    do {
                        try fileManager.removeItem(atPath: fileURL.path)
                    } catch { }
                    fileManager.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
                    await NCManageDatabase.shared.deleteLocalFileAsync(id: ocId)
                }
            }
        }
    }

    private func enumerateFilesAsync(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]? = nil) async -> [URL] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var urls: [URL] = []
                if let enumerator = self.fileManager.enumerator(at: url, includingPropertiesForKeys: keys, options: []) {
                    for case let fileURL as URL in enumerator {
                        urls.append(fileURL)
                    }
                }
                continuation.resume(returning: urls)
            }
        }
    }

    func createFileName(_ fileName: String, serverUrl: String, account: String) -> String {
        var resultFileName = fileName
        var exitLoop = false

        while exitLoop == false {
            if NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "fileNameView ==[c] %@ AND serverUrl == %@ AND account == %@", resultFileName, serverUrl, account)) != nil {
                var name = NSString(string: resultFileName).deletingPathExtension
                let ext = NSString(string: resultFileName).pathExtension
                let characters = Array(name)

                if characters.count < 2 {
                    if ext.isEmpty {
                        resultFileName = name + " " + "1"
                    } else {
                        resultFileName = name + " " + "1" + "." + ext
                    }
                } else {
                    let space = characters[characters.count - 2]
                    let numChar = characters[characters.count - 1]
                    var num = Int(String(numChar))
                    if space == " " && num != nil {
                        name = String(name.dropLast())
                        num = num! + 1
                        if ext.isEmpty {
                            resultFileName = name + "\(num!)"
                        } else {
                            resultFileName = name + "\(num!)" + "." + ext
                        }
                    } else {
                        if ext.isEmpty {
                            resultFileName = name + " " + "1"
                        } else {
                            resultFileName = name + " " + "1" + "." + ext
                        }
                    }
                }
            } else {
                exitLoop = true
            }
        }

        return resultFileName
    }

    func clearCacheDirectory(_ directory: String) {
        if let cacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            do {
                let directoryURL = cacheURL.appendingPathComponent(directory, isDirectory: true)
                let directoryContents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: [])
                for file in directoryContents {
                    do {
                        try fileManager.removeItem(at: file)
                    } catch let error as NSError {
                        debugPrint("Ooops! Something went wrong: \(error)")
                    }
                }
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        }
    }

    func transformedSize(_ bytes: Int64) -> String {
        let formatter: ByteCountFormatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }

    func createFileNameDate(_ fileName: String, ext: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yy-MM-dd HH-mm-ss"
        let fileNameDate = formatter.string(from: Date())

        if fileName.isEmpty, !ext.isEmpty {
            return fileNameDate + "." + ext
        } else if !fileName.isEmpty, ext.isEmpty {
            return fileName + " " + fileNameDate
        } else if fileName.isEmpty, ext.isEmpty {
            return fileNameDate
        } else {
            return fileName + " " + fileNameDate + "." + ext
        }
    }

    func serverDirectoryUp(serverUrl: String, home: String) -> String? {
        var returnString: String?
        if home == serverUrl {
            return serverUrl
        }

        if let serverUrl = serverUrl.urlEncoded, let url = URL(string: serverUrl) {
            if let path = url.deletingLastPathComponent().absoluteString.removingPercentEncoding {
                if path.last == "/" {
                    returnString = String(path.dropLast())
                } else {
                    returnString = path
                }
            }
        }
        return returnString
    }

    func getPath(path: String, user: String, fileName: String? = nil) -> String {
        var path = path.replacingOccurrences(of: "/remote.php/dav/files/" + user, with: "")
        if let fileName = fileName {
            path += fileName
        }
        return path
    }
}
