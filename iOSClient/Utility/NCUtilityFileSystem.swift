// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import PhotosUI

final class NCUtilityFileSystem: NSObject, @unchecked Sendable {
    let fileManager = FileManager()
    let fileIO = DispatchQueue(label: "FileManager.Delete", qos: .utility)

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

    func fileProviderStorageExists(_ metadata: tableMetadata) -> Bool {
        let fileNamePath = getDirectoryProviderStorageOcId(metadata.ocId, fileName: metadata.fileName, userId: metadata.userId, urlBase: metadata.urlBase)
        let fileNameViewPath = getDirectoryProviderStorageOcId(metadata.ocId, fileName: metadata.fileNameView, userId: metadata.userId, urlBase: metadata.urlBase)
        do {
            let fileNameAttribute = try fileManager.attributesOfItem(atPath: fileNamePath)
            let fileNameSize: UInt64 = fileNameAttribute[FileAttributeKey.size] as? UInt64 ?? 0
            let fileNameViewAttribute = try fileManager.attributesOfItem(atPath: fileNameViewPath)
            let fileNameViewSize: UInt64 = fileNameViewAttribute[FileAttributeKey.size] as? UInt64 ?? 0
            if metadata.isDirectoryE2EE == true {
                if (fileNameSize == metadata.size || fileNameViewSize == metadata.size) && fileNameViewSize > 0 {
                    return true
                } else {
                    return false
                }
            } else {
                return (fileNameViewSize == metadata.size) && metadata.size > 0
            }
        } catch { print("Error: \(error)") }
        return false
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

    // MARK: -

    func removeFile(atPath path: String) {
        fileIO.async {
            do {
                try self.fileManager.removeItem(atPath: path)
            } catch {
                print(error)
            }
        }
    }

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

    // MARK: -

    func getHomeServer(session: NCSession.Session) -> String {
        return getHomeServer(urlBase: session.urlBase, userId: session.userId)
    }

    func getHomeServer(urlBase: String, userId: String) -> String {
        return urlBase + "/remote.php/dav/files/" + userId
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
}
