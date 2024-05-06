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

class NCUtilityFileSystem: NSObject {

    let fileManager = FileManager.default

    // MARK: -

    var directoryGroup: String {
        return fileManager.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroups)?.path ?? ""
    }

    var directoryDocuments: String {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? ""
    }

    var directoryCertificates: String {
        guard let directoryGroup = fileManager.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroups) else { return "" }
        let path = directoryGroup.appendingPathComponent(NCGlobal.shared.appCertificates).path
        if !fileManager.fileExists(atPath: path) {
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
            } catch { print("Error: \(error)") }
        }
        return path
    }

    var directoryUserData: String {
        guard let directoryGroup = fileManager.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroups) else { return "" }
        let path = directoryGroup.appendingPathComponent(NCGlobal.shared.appUserData).path
        if !fileManager.fileExists(atPath: path) {
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
            } catch { print("Error: \(error)") }
        }
        return path
    }

    var directoryScan: String {
        guard let directoryGroup = fileManager.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroups) else { return "" }
        let path = directoryGroup.appendingPathComponent(NCGlobal.shared.appScan).path
        if !fileManager.fileExists(atPath: path) {
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
            } catch { print("Error: \(error)") }
        }
        return path
    }

    @objc var directoryProviderStorage: String {
        guard let directoryGroup = fileManager.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroups) else { return "" }
        let path = directoryGroup.appendingPathComponent(NCGlobal.shared.directoryProviderStorage).path
        if !fileManager.fileExists(atPath: path) {
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
            } catch { print("Error: \(error)") }
        }
        return path
    }

    @objc func getDirectoryProviderStorageOcId(_ ocId: String) -> String {
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

    func getDirectoryProviderStorageIconOcId(_ ocId: String, etag: String) -> String {
        return getDirectoryProviderStorageOcId(ocId) + "/" + etag + ".small.ico"
    }

    func getDirectoryProviderStoragePreviewOcId(_ ocId: String, etag: String) -> String {
        return getDirectoryProviderStorageOcId(ocId) + "/" + etag + ".preview.ico"
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
                return fileNameViewSize == metadata.size
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

    func fileProviderStoragePreviewIconExists(_ ocId: String, etag: String) -> Bool {
        let fileNamePathPreview = getDirectoryProviderStoragePreviewOcId(ocId, etag: etag)
        let fileNamePathIcon = getDirectoryProviderStorageIconOcId(ocId, etag: etag)
        do {
            let fileNamePathPreviewAttribute = try fileManager.attributesOfItem(atPath: fileNamePathPreview)
            let fileSizePreview: UInt64 = fileNamePathPreviewAttribute[FileAttributeKey.size] as? UInt64 ?? 0
            let fileNamePathIconAttribute = try fileManager.attributesOfItem(atPath: fileNamePathIcon)
            let fileSizeIcon: UInt64 = fileNamePathIconAttribute[FileAttributeKey.size] as? UInt64 ?? 0
            if fileSizePreview > 0 && fileSizeIcon > 0 {
                return true
            } else {
                return false
            }
        } catch { print("Error: \(error)") }
        return false
    }

    @objc func createDirectoryStandard() {
        guard let directoryGroup = fileManager.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroups)?.path else { return }
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

    @objc func removeGroupApplicationSupport() {
        let path = directoryGroup + "/" + NCGlobal.shared.appApplicationSupport
        try? fileManager.removeItem(atPath: path)
    }

    @objc func removeGroupLibraryDirectory() {
        try? fileManager.removeItem(atPath: directoryScan)
        try? fileManager.removeItem(atPath: directoryUserData)
    }

    @objc func removeGroupDirectoryProviderStorage() {
        try? fileManager.removeItem(atPath: directoryProviderStorage)
    }

    @objc func removeDocumentsDirectory() {
        try? fileManager.removeItem(atPath: directoryDocuments)
    }

    @objc func removeTemporaryDirectory() {
        try? fileManager.removeItem(atPath: NSTemporaryDirectory())
    }

    @objc func emptyTemporaryDirectory() {
        do {
            let files = try fileManager.contentsOfDirectory(atPath: NSTemporaryDirectory())
            for file in files {
                do {
                    try fileManager.removeItem(atPath: NSTemporaryDirectory() + "/" + file)
                } catch { print("Error: \(error)") }
            }
        } catch { print("Error: \(error)") }
    }

    func isDirectoryE2EE(serverUrl: String, userBase: NCUserBaseUrl) -> Bool {
        return isDirectoryE2EE(account: userBase.account, urlBase: userBase.urlBase, userId: userBase.userId, serverUrl: serverUrl)
    }

    func isDirectoryE2EE(file: NKFile) -> Bool {
        return isDirectoryE2EE(account: file.account, urlBase: file.urlBase, userId: file.userId, serverUrl: file.serverUrl)
    }

    func isDirectoryE2EE(account: String, urlBase: String, userId: String, serverUrl: String) -> Bool {
        if serverUrl == getHomeServer(urlBase: urlBase, userId: userId) || serverUrl == ".." { return false }
        if let directory = NCManageDatabase.shared.getTableDirectory(account: account, serverUrl: serverUrl) {
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

    @objc func getFileSize(filePath: String) -> Int64 {

        do {
            let attributes = try fileManager.attributesOfItem(atPath: filePath)
            return attributes[FileAttributeKey.size] as? Int64 ?? 0
        } catch {
            print(error)
        }
        return 0
    }

    @objc func getFileModificationDate(filePath: String) -> NSDate? {

        do {
            let attributes = try fileManager.attributesOfItem(atPath: filePath)
            return attributes[FileAttributeKey.modificationDate] as? NSDate
        } catch {
            print(error)
        }
        return nil
    }

    @objc func getFileCreationDate(filePath: String) -> NSDate? {

        do {
            let attributes = try fileManager.attributesOfItem(atPath: filePath)
            return attributes[FileAttributeKey.creationDate] as? NSDate
        } catch {
            print(error)
        }
        return nil
    }

    @objc func writeFile(fileURL: URL, text: String) -> Bool {

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

    @objc func removeFile(atPath: String) {

        do {
            try FileManager.default.removeItem(atPath: atPath)
        } catch {
            print(error)
        }
    }

    @discardableResult
    @objc func moveFile(atPath: String, toPath: String) -> Bool {

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
    @objc func copyFile(atPath: String, toPath: String) -> Bool {

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

    @objc func moveFileInBackground(atPath: String, toPath: String) {

        if atPath == toPath { return }

        DispatchQueue.global().async {

            try? FileManager.default.removeItem(atPath: toPath)
            try? FileManager.default.copyItem(atPath: atPath, toPath: toPath)
            try? FileManager.default.removeItem(atPath: atPath)
        }
    }

    @objc func linkItem(atPath: String, toPath: String) {

        try? FileManager.default.removeItem(atPath: toPath)
        try? FileManager.default.linkItem(atPath: atPath, toPath: toPath)
    }

    // MARK: - 

    @objc func getHomeServer(urlBase: String, userId: String) -> String {
        return urlBase + "/remote.php/dav/files/" + userId
    }

    @objc func getPath(path: String, user: String, fileName: String? = nil) -> String {

        var path = path.replacingOccurrences(of: "/remote.php/dav/files/" + user, with: "")
        if let fileName = fileName {
            path += fileName
        }
        return path
    }

    @objc func deleteLastPath(serverUrlPath: String, home: String? = nil) -> String? {

        var returnString: String?

        if home == serverUrlPath {
            return serverUrlPath
        }

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

    @objc func getFileNamePath(_ fileName: String, serverUrl: String, urlBase: String, userId: String) -> String {

        let home = getHomeServer(urlBase: urlBase, userId: userId)
        var fileNamePath = serverUrl.replacingOccurrences(of: home, with: "") + "/" + fileName
        if fileNamePath.first == "/" {
            fileNamePath.removeFirst()
        }
        return fileNamePath
    }

    @objc func createFileName(_ fileName: String, serverUrl: String, account: String) -> String {

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

    @objc func getDirectorySize(directory: String) -> Int64 {

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

    @objc func transformedSize(_ bytes: Int64) -> String {
        let formatter: ByteCountFormatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }

    func cleanUp(directory: String, days: TimeInterval) {

        if days == 0 { return}

        let minimumDate = Date().addingTimeInterval(-days * 24 * 60 * 60)
        let url = URL(fileURLWithPath: directory)
        var offlineDir: [String] = []

        if let directories = NCManageDatabase.shared.getTablesDirectory(predicate: NSPredicate(format: "offline == true"), sorted: "serverUrl", ascending: true) {
            for directory: tableDirectory in directories {
                offlineDir.append(getDirectoryProviderStorageOcId(directory.ocId))
            }
        }
        let resultsLocalFile = NCManageDatabase.shared.getResultsTableLocalFile(predicate: NSPredicate(format: "offline == false"), sorted: "lastOpeningDate", ascending: true)

        let manager = FileManager.default
        if let enumerator = manager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: []) {
            for case let fileURL as URL in enumerator {
                if let attributes = try? manager.attributesOfItem(atPath: fileURL.path) {
                    if attributes[.size] as? Double == 0 { continue }
                    if attributes[.type] as? FileAttributeType == FileAttributeType.typeDirectory { continue }
                    if fileURL.pathExtension == "ico" { continue }
                    // check directory offline
                    let filter = offlineDir.filter({ fileURL.path.hasPrefix($0)})
                    if !filter.isEmpty { continue }
                    // -----------------------
                    let folderURL = fileURL.deletingLastPathComponent()
                    let ocId = folderURL.lastPathComponent
                    if let result = resultsLocalFile?.filter({ $0.ocId == ocId }).first, (result.lastOpeningDate as Date) < minimumDate {
                        do {
                            try manager.removeItem(atPath: fileURL.path)
                        } catch { }
                        manager.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
                        NCManageDatabase.shared.deleteLocalFile(predicate: NSPredicate(format: "ocId == %@", ocId))
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

    func createGranularityPath(asset: PHAsset? = nil, serverUrl: String? = nil) -> String {

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

        if let serverUrl {
            return serverUrl + "/" + path
        } else {
            return path
        }
    }
}
