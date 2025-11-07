// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import PhotosUI

final class NCUtilityFileSystem: NSObject, @unchecked Sendable {
    let fileManager = FileManager()
    private let fileIO = DispatchQueue(label: "FileManager.Delete", qos: .utility)

    var directoryGroup: String {
        return fileManager.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup)?.path ?? ""
    }
    var directoryDocuments: String {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? ""
    }
    var directoryCertificates: String {
        guard let directoryGroup = fileManager.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup) else { return "" }
        let path = directoryGroup.appendingPathComponent(NCGlobal.shared.appCertificates).path
        if !fileManager.fileExists(atPath: path) {
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
            } catch { print("Error: \(error)") }
        }
        return path
    }
    var directoryUserData: String {
        guard let directoryGroup = fileManager.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup) else { return "" }
        let path = directoryGroup.appendingPathComponent(NCGlobal.shared.appUserData).path
        if !fileManager.fileExists(atPath: path) {
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
            } catch { print("Error: \(error)") }
        }
        return path
    }
    var directoryScan: String {
        guard let directoryGroup = fileManager.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup) else { return "" }
        let path = directoryGroup.appendingPathComponent(NCGlobal.shared.appScan).path
        if !fileManager.fileExists(atPath: path) {
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
            } catch { print("Error: \(error)") }
        }
        return path
    }

    // MARK: -

    func getPathDomain(userId: String, host: String) -> String {
        let path = "\(userId)-\(host)"
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: "@", with: "-")
            .lowercased()
        return path
    }

    func getDirectoryProviderStorage() -> String {
        guard let directoryGroup = fileManager.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup) else {
            return ""
        }
        let path = directoryGroup.appendingPathComponent(NCGlobal.shared.directoryProviderStorage).path
        if !fileManager.fileExists(atPath: path) {
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
            } catch {
                print(error)
            }
        }
        return path
    }

    /// Returns a stable document storage path as String, based on the shared App Group and domain info.
    /// Useful for storing per-domain data (DB, cache, etc.) accessible from both app and File Provider extension.
    func getDocumentStorage(userId: String, urlBase: String) -> String {
        guard let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup),
              let urlBase = NSURL(string: urlBase),
              let host = urlBase.host else {
            return ""
        }
        let relativePath = getPathDomain(userId: userId, host: host)
        let path = groupURL
                .appendingPathComponent(NCGlobal.shared.directoryProviderStorage, isDirectory: true)
                .appendingPathComponent(relativePath, isDirectory: true)
                .path

        // Create directory if needed
        if !fileManager.fileExists(atPath: path) {
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
            } catch {
                print(error)
                return ""
            }
        }

        return path
    }

    func getDirectoryProviderStorageOcId(_ ocId: String, userId: String, urlBase: String) -> String {
        let path = getDocumentStorage(userId: userId, urlBase: urlBase) + "/" + ocId
        if !fileManager.fileExists(atPath: path) {
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
            } catch { print("Error: \(error)") }
        }
        return path
    }

    @objc func getDirectoryProviderStorageOcId(_ ocId: String, fileName: String, userId: String, urlBase: String) -> String {
        let path = getDirectoryProviderStorageOcId(ocId, userId: userId, urlBase: urlBase) + "/" + fileName
        if !fileManager.fileExists(atPath: path) {
            fileManager.createFile(atPath: path, contents: nil)
        }
        return path
    }

    func getDirectoryProviderStorageImageOcId(_ ocId: String, etag: String, ext: String, userId: String, urlBase: String) -> String {
        return getDirectoryProviderStorageOcId(ocId, userId: userId, urlBase: urlBase) + "/" + etag + ext
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

    // MARK: -

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

    func writeFile(fileURL: URL, text: String) -> Bool {
        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            print(error)
        }

        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            return true
        } catch {
            print(error)
            return false
        }
    }

    func removeFile(atPath path: String) {
        fileIO.async {
            do {
                try self.fileManager.removeItem(atPath: path)
            } catch {
                print(error)
            }
        }
    }

    /// Moves a file from one path to another, overwriting the destination if it exists.
    /// - Parameters:
    ///   - atPath: The source file path.
    ///   - toPath: The destination file path.
    func moveFileAsync(atPath: String, toPath: String) async {
        if atPath == toPath {
            return
        }

        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    if self.fileManager.fileExists(atPath: toPath) {
                        try self.fileManager.removeItem(atPath: toPath)
                    }
                    try self.fileManager.moveItem(atPath: atPath, toPath: toPath)
                } catch {
                    print("Error moving \(atPath) -> \(toPath): \(error)")
                }
                continuation.resume()
            }
        }
    }

    @discardableResult
    func moveFile(atPath: String, toPath: String) -> Bool {
        if atPath == toPath {
            return true
        }

        do {
            if fileManager.fileExists(atPath: toPath) {
                try fileManager.removeItem(atPath: toPath)
            }
            try fileManager.moveItem(atPath: atPath, toPath: toPath)
        } catch {
            print(error)
            return false
        }
        return true
    }

    @discardableResult
    func copyFile(atPath: String, toPath: String) -> Bool {
        if atPath == toPath {
            return true
        }

        do {
            if fileManager.fileExists(atPath: toPath) {
                try fileManager.removeItem(atPath: toPath)
            }
            try fileManager.copyItem(atPath: atPath, toPath: toPath)
            return true
        } catch {
            print(error)
            return false
        }
    }

    func linkItem(atPath: String, toPath: String) {
        try? fileManager.removeItem(atPath: toPath)
        try? fileManager.linkItem(atPath: atPath, toPath: toPath)
    }

    /// Asynchronously returns the size (in bytes) of the file at the given path.
    /// - Parameter path: Full file system path as a String.
    /// - Returns: Size in bytes, or `0` if the file doesn't exist or can't be accessed.
    func fileSizeAsync(atPath path: String) async -> Int64 {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let attributes = try self.fileManager.attributesOfItem(atPath: path)
                    if let size = attributes[.size] as? NSNumber {
                        continuation.resume(returning: size.int64Value)
                    } else {
                        continuation.resume(returning: 0)
                    }
                } catch {
                    continuation.resume(returning: 0)
                }
            }
        }
    }

    // MARK: -

    func getHomeServer(session: NCSession.Session) -> String {
        return getHomeServer(urlBase: session.urlBase, userId: session.userId)
    }

    func getHomeServer(urlBase: String, userId: String) -> String {
        return urlBase + "/remote.php/dav/files/" + userId
    }

    func getPath(path: String, user: String, fileName: String? = nil) -> String {
        var path = path.replacingOccurrences(of: "/remote.php/dav/files/" + user, with: "")
        if let fileName = fileName {
            path += fileName
        }
        return path
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

    func createServerUrl(serverUrl: String, fileName: String) -> String {
        if fileName.isEmpty {
            return serverUrl
        } else if serverUrl.last == "/" {
            return serverUrl + fileName
        } else {
            return serverUrl + "/" + fileName
        }
    }

    func getFileNamePath(_ fileName: String, serverUrl: String, session: NCSession.Session) -> String {
        let home = getHomeServer(session: session)
        var fileNamePath = serverUrl.replacingOccurrences(of: home, with: "") + "/" + fileName
        if fileNamePath.first == "/" {
            fileNamePath.removeFirst()
        }
        return fileNamePath
    }

    func getFileNamePath(_ fileName: String, serverUrl: String, urlBase: String, userId: String) -> String {
        let home = getHomeServer(urlBase: urlBase, userId: userId)
        var fileNamePath = serverUrl.replacingOccurrences(of: home, with: "") + "/" + fileName
        if fileNamePath.first == "/" {
            fileNamePath.removeFirst()
        }
        return fileNamePath
    }

    func createFileName(_ fileName: String, fileDate: Date, fileType: PHAssetMediaType, notUseMask: Bool = false) -> String {
        var fileName = fileName
        let keychain = NCPreferences()
        var addFileNameType: Bool = keychain.fileNameType
        let useFileNameOriginal: Bool = keychain.fileNameOriginal
        var numberFileName: String = ""
        var fileNameType = ""
        let fileNameExt = (fileName as NSString).pathExtension.lowercased()

        /// Original FileName
        if useFileNameOriginal {
            addFileNameType = false
            if !notUseMask {
                return fileName
            }
        }

        /// Get counter
        if fileName.count > 8 {
            let index = fileName.index(fileName.startIndex, offsetBy: 4)
            numberFileName = String(fileName[index..<fileName.index(index, offsetBy: 4)])
        } else {
            numberFileName = keychain.incrementalNumber
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yy-MM-dd HH-mm-ss"
        let fileNameDate = formatter.string(from: fileDate)

        switch fileType {
        case .image:
            fileNameType = NSLocalizedString("_photo_", comment: "")
        case .video:
            fileNameType = NSLocalizedString("_video_", comment: "")
        case .audio:
            fileNameType = NSLocalizedString("_audio_", comment: "")
        case .unknown:
            fileNameType = NSLocalizedString("_unknown_", comment: "")
        default:
            fileNameType = NSLocalizedString("_unknown_", comment: "")
        }

        if !keychain.fileNameMask.isEmpty, !notUseMask {
            fileName = keychain.fileNameMask
            if !fileName.isEmpty {
                formatter.dateFormat = "dd"
                let dayNumber = formatter.string(from: fileDate)
                formatter.dateFormat = "MMM"
                let month = formatter.string(from: fileDate)
                formatter.dateFormat = "MM"
                let monthNumber = formatter.string(from: fileDate)
                formatter.dateFormat = "yyyy"
                let year = formatter.string(from: fileDate)
                formatter.dateFormat = "yy"
                let yearNumber = formatter.string(from: fileDate)
                formatter.dateFormat = "HH"
                let hour24 = formatter.string(from: fileDate)
                formatter.dateFormat = "hh"
                let hour12 = formatter.string(from: fileDate)
                formatter.dateFormat = "mm"
                let minute = formatter.string(from: fileDate)
                formatter.dateFormat = "ss"
                let second = formatter.string(from: fileDate)
                formatter.dateFormat = "a"
                let ampm = formatter.string(from: fileDate)

                // Replace string with date
                fileName = fileName.replacingOccurrences(of: "DD", with: dayNumber)
                fileName = fileName.replacingOccurrences(of: "MMM", with: month)
                fileName = fileName.replacingOccurrences(of: "MM", with: monthNumber)
                fileName = fileName.replacingOccurrences(of: "YYYY", with: year)
                fileName = fileName.replacingOccurrences(of: "YY", with: yearNumber)
                fileName = fileName.replacingOccurrences(of: "HH", with: hour24)
                fileName = fileName.replacingOccurrences(of: "hh", with: hour12)
                fileName = fileName.replacingOccurrences(of: "mm", with: minute)
                fileName = fileName.replacingOccurrences(of: "ss", with: second)
                fileName = fileName.replacingOccurrences(of: "ampm", with: ampm)

                if addFileNameType {
                    fileName = "\(fileNameType)\(fileName)\(numberFileName).\(fileNameExt)"
                } else {
                    fileName = "\(fileName)\(numberFileName).\(fileNameExt)"
                }
                fileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
                return fileName
            }
        }
        if addFileNameType {
            fileName = "\(fileNameType) \(fileNameDate) \(numberFileName).\(fileNameExt)"
        } else {
            fileName = "\(fileNameDate) \(numberFileName).\(fileNameExt)"
        }
        return fileName
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

    func transformedSize(_ bytes: Int64) -> String {
        let formatter: ByteCountFormatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
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
}
