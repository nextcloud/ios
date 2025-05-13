//
//  NCUtilityFileSystem.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 28/05/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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
import NextcloudKit
import PhotosUI

final class NCUtilityFileSystem: NSObject, @unchecked Sendable {
    let fileManager = FileManager()
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
    var directoryProviderStorage: String {
        guard let directoryGroup = fileManager.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroup) else { return "" }
        let path = directoryGroup.appendingPathComponent(NCGlobal.shared.directoryProviderStorage).path
        if !fileManager.fileExists(atPath: path) {
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
            } catch { print("Error: \(error)") }
        }
        return path
    }

    // MARK: -

    func getDirectoryProviderStorageOcId(_ ocId: String) -> String {
        let path = directoryProviderStorage + "/" + ocId
        if !fileManager.fileExists(atPath: path) {
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
            } catch { print("Error: \(error)") }
        }
        return path
    }

    @objc func getDirectoryProviderStorageOcId(_ ocId: String, fileNameView: String) -> String {
        let path = getDirectoryProviderStorageOcId(ocId) + "/" + fileNameView
        if !fileManager.fileExists(atPath: path) {
            fileManager.createFile(atPath: path, contents: nil)
        }
        return path
    }

    func getDirectoryProviderStorageImageOcId(_ ocId: String, etag: String, ext: String) -> String {
        return getDirectoryProviderStorageOcId(ocId) + "/" + etag + ext
    }

    func fileProviderStorageExists(_ metadata: tableMetadata) -> Bool {
        let fileNamePath = getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)
        let fileNameViewPath = getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)
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

    func fileProviderStorageSize(_ ocId: String, fileNameView: String) -> UInt64 {
        let fileNamePath = getDirectoryProviderStorageOcId(ocId, fileNameView: fileNameView)
        do {
            let fileNameAttribute = try fileManager.attributesOfItem(atPath: fileNamePath)
            let fileNameSize: UInt64 = fileNameAttribute[FileAttributeKey.size] as? UInt64 ?? 0
            return fileNameSize
        } catch { print("Error: \(error)") }
        return 0
    }

    func fileProviderStorageImageExists(_ ocId: String, etag: String, ext: String) -> Bool {
        let fileNamePath = getDirectoryProviderStorageImageOcId(ocId, etag: etag, ext: ext)
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

    func fileProviderStorageImageExists(_ ocId: String, etag: String) -> Bool {
        if fileProviderStorageImageExists(ocId, etag: etag, ext: NCGlobal.shared.previewExt1024),
           fileProviderStorageImageExists(ocId, etag: etag, ext: NCGlobal.shared.previewExt512),
           fileProviderStorageImageExists(ocId, etag: etag, ext: NCGlobal.shared.previewExt256) {
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
        if !fileManager.fileExists(atPath: directoryProviderStorage) { try? fileManager.createDirectory(atPath: directoryProviderStorage, withIntermediateDirectories: true) }
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
        try? fileManager.removeItem(atPath: directoryProviderStorage)
    }

    func removeDocumentsDirectory() {
        try? fileManager.removeItem(atPath: directoryDocuments)
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

    func isDirectoryE2EE(serverUrl: String, account: String) -> Bool {
        return isDirectoryE2EE(session: NCSession.shared.getSession(account: account), serverUrl: serverUrl)
    }

    func isDirectoryE2EE(file: NKFile) -> Bool {
        let session = NCSession.Session(account: file.account, urlBase: file.urlBase, user: file.user, userId: file.userId)
        return isDirectoryE2EE(session: session, serverUrl: file.serverUrl)
    }

    func isDirectoryE2EE(session: NCSession.Session, serverUrl: String) -> Bool {
        if serverUrl == getHomeServer(session: session) || serverUrl == ".." { return false }
        if let directory = NCManageDatabase.shared.getTableDirectory(account: session.account, serverUrl: serverUrl) {
            return directory.e2eEncrypted
        }
        return false
    }

    func isDirectoryE2EETop(account: String, serverUrl: String) -> Bool {
        guard let serverUrl = serverUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return false }

        if let url = URL(string: serverUrl)?.deletingLastPathComponent(),
           let serverUrl = String(url.absoluteString.dropLast()).removingPercentEncoding {
            if let directory = NCManageDatabase.shared.getTableDirectory(account: account, serverUrl: serverUrl) {
                return !directory.e2eEncrypted
            }
        }
        return true
    }

    func getDirectoryE2EETop(serverUrl: String, account: String) -> tableDirectory? {
        guard var serverUrl = serverUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        var top: tableDirectory?

        while let url = URL(string: serverUrl)?.deletingLastPathComponent(),
              let serverUrlencoding = serverUrl.removingPercentEncoding,
              let directory = NCManageDatabase.shared.getTableDirectory(account: account, serverUrl: serverUrlencoding) {

            if directory.e2eEncrypted {
                top = directory
            } else {
                return top
            }

            serverUrl = String(url.absoluteString.dropLast())
        }

        return top
    }

    // MARK: -

    func getFileSize(filePath: String) -> Int64 {
        guard FileManager.default.fileExists(atPath: filePath)
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
            try FileManager.default.removeItem(at: fileURL)
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

    func removeFile(atPath: String) {
        do {
            try FileManager.default.removeItem(atPath: atPath)
        } catch {
            print(error)
        }
    }

    @discardableResult
    func moveFile(atPath: String, toPath: String) -> Bool {
        if atPath == toPath { return true }

        do {
            try FileManager.default.removeItem(atPath: toPath)
        } catch {
            print(error)
        }

        do {
            try FileManager.default.copyItem(atPath: atPath, toPath: toPath)
            try FileManager.default.removeItem(atPath: atPath)
            return true
        } catch {
            print(error)
            return false
        }
    }

    @discardableResult
    func copyFile(atPath: String, toPath: String) -> Bool {
        if atPath == toPath { return true }

        do {
            try FileManager.default.removeItem(atPath: toPath)
        } catch {
            print(error)
        }

        do {
            try FileManager.default.copyItem(atPath: atPath, toPath: toPath)
            return true
        } catch {
            print(error)
            return false
        }
    }

    @discardableResult
    func copyFile(at: URL, to: URL) -> Bool {
        if at == to { return true }

        do {
            try FileManager.default.removeItem(at: to)
        } catch {
            print(error)
        }

        do {
            try FileManager.default.copyItem(at: at, to: to)
            return true
        } catch {
            print(error)
            return false
        }
    }

    func moveFileInBackground(atPath: String, toPath: String) {
        if atPath == toPath { return }
        DispatchQueue.global().async {
            try? FileManager.default.removeItem(atPath: toPath)
            try? FileManager.default.copyItem(atPath: atPath, toPath: toPath)
            try? FileManager.default.removeItem(atPath: atPath)
        }
    }

    func linkItem(atPath: String, toPath: String) {
        try? FileManager.default.removeItem(atPath: toPath)
        try? FileManager.default.linkItem(atPath: atPath, toPath: toPath)
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

    func deleteLastPath(serverUrlPath: String, home: String? = nil) -> String? {
        var returnString: String?
        if home == serverUrlPath { return serverUrlPath }

        if let serverUrlPath = serverUrlPath.urlEncoded, let url = URL(string: serverUrlPath) {
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

    func stringAppendServerUrl(_ serverUrl: String, addFileName: String) -> String {
        if addFileName.isEmpty {
            return serverUrl
        } else if serverUrl.last == "/" {
            return serverUrl + addFileName
        } else {
            return serverUrl + "/" + addFileName
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

    func createFileName(_ fileName: String, fileDate: Date, fileType: PHAssetMediaType, notUseMask: Bool = false) -> String {
        var fileName = fileName
        let keychain = NCKeychain()
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

    func createFileName(_ fileName: String, serverUrl: String, account: String) -> String {
        var resultFileName = fileName
        var exitLoop = false

        while exitLoop == false {
            if NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "fileNameView == %@ AND serverUrl == %@ AND account == %@", resultFileName, serverUrl, account)) != nil {
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

    func getDirectorySize(directory: String) -> Int64 {
        let url = URL(fileURLWithPath: directory)
        let manager = FileManager.default
        var totalSize: Int64 = 0

        if let enumerator = manager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: []) {
            for case let fileURL as URL in enumerator {
                if let attributes = try? manager.attributesOfItem(atPath: fileURL.path) {
                    if let size = attributes[.size] as? Int64 {
                        totalSize += size
                    }
                }
            }
        }

        return totalSize
    }

    func transformedSize(_ bytes: Int64) -> String {
        let formatter: ByteCountFormatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }

    func cleanUp(directory: String, days: TimeInterval) {
        DispatchQueue.global().async {
            if days == 0 { return}
            let minimumDate = Date().addingTimeInterval(-days * 24 * 60 * 60)
            let url = URL(fileURLWithPath: directory)
            var offlineDir: [String] = []

            if let directories = NCManageDatabase.shared.getTablesDirectory(predicate: NSPredicate(format: "offline == true"), sorted: "serverUrl", ascending: true) {
                for directory: tableDirectory in directories {
                    offlineDir.append(self.getDirectoryProviderStorageOcId(directory.ocId))
                }
            }
            let resultsLocalFile = NCManageDatabase.shared.getResultsTableLocalFile(predicate: NSPredicate(format: "offline == false"), sorted: "lastOpeningDate", ascending: true)

            let manager = FileManager.default
            if let enumerator = manager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: []) {
                for case let fileURL as URL in enumerator {
                    if let attributes = try? manager.attributesOfItem(atPath: fileURL.path) {
                        if attributes[.size] as? Double == 0 { continue }
                        if attributes[.type] as? FileAttributeType == FileAttributeType.typeDirectory { continue }
                        // check directory offline
                        let filter = offlineDir.filter({ fileURL.path.hasPrefix($0)})
                        if !filter.isEmpty { continue }
                        // -----------------------
                        if let modificationDate = attributes[.modificationDate] as? Date,
                           modificationDate < minimumDate {
                            let fileName = fileURL.lastPathComponent
                            if fileName.hasSuffix(NCGlobal.shared.previewExt256) || fileName.hasSuffix(NCGlobal.shared.previewExt512) || fileName.hasSuffix(NCGlobal.shared.previewExt1024) {
                                try? manager.removeItem(atPath: fileURL.path)
                            }
                        }
                        // -----------------------
                        let folderURL = fileURL.deletingLastPathComponent()
                        let ocId = folderURL.lastPathComponent
                        if let result = resultsLocalFile?.filter({ $0.ocId == ocId }).first, (result.lastOpeningDate as Date) < minimumDate {
                            do {
                                try manager.removeItem(atPath: fileURL.path)
                            } catch { }
                            manager.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
                            NCManageDatabase.shared.deleteLocalFileOcId(ocId)
                        }
                    }
                }
            }
        }
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
}
