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
import PhotosUI

class NCUtilityFileSystem: NSObject {
    @objc static let shared: NCUtilityFileSystem = {
        let instance = NCUtilityFileSystem()
        return instance
    }()

    let fileManager = FileManager.default

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

    @objc func deleteFile(filePath: String) {

        do {
            try FileManager.default.removeItem(atPath: filePath)
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

    @objc func createFileName(_ fileName: String, serverUrl: String, account: String) -> String {

        var resultFileName = fileName
        var exitLoop = false

            while exitLoop == false {

                if NCManageDatabase.shared.getMetadata(predicate: NSPredicate(format: "fileNameView == %@ AND serverUrl == %@ AND account == %@", resultFileName, serverUrl, account)) != nil {

                    var name = NSString(string: resultFileName).deletingPathExtension
                    let ext = NSString(string: resultFileName).pathExtension
                    let characters = Array(name)

                    if characters.count < 2 {
                        if ext == "" {
                            resultFileName = name + " " + "1"
                        } else {
                            resultFileName = name + " " + "1" + "." + ext
                        }
                    } else {
                        let space = characters[characters.count-2]
                        let numChar = characters[characters.count-1]
                        var num = Int(String(numChar))
                        if space == " " && num != nil {
                            name = String(name.dropLast())
                            num = num! + 1
                            if ext == "" {
                                resultFileName = name + "\(num!)"
                            } else {
                                resultFileName = name + "\(num!)" + "." + ext
                            }
                        } else {
                            if ext == "" {
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

    func cleanUp(directory: String, days: TimeInterval) {

        if days == 0 { return}

        let minimumDate = Date().addingTimeInterval(-days*24*60*60)
        let url = URL(fileURLWithPath: directory)
        var offlineDir: [String] = []
        var offlineFiles: [String] = []

        if let directories = NCManageDatabase.shared.getTablesDirectory(predicate: NSPredicate(format: "offline == true"), sorted: "serverUrl", ascending: true) {
            for directory: tableDirectory in directories {
                offlineDir.append(CCUtility.getDirectoryProviderStorageOcId(directory.ocId))
            }
        }

        let files = NCManageDatabase.shared.getTableLocalFiles(predicate: NSPredicate(format: "offline == true"), sorted: "fileName", ascending: true)
        for file: tableLocalFile in files {
            offlineFiles.append(CCUtility.getDirectoryProviderStorageOcId(file.ocId, fileNameView: file.fileName))
        }

        func meetsRequirement(date: Date) -> Bool {
            return date < minimumDate
        }

        let manager = FileManager.default
        if let enumerator = manager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: []) {
            for case let fileURL as URL in enumerator {
                if let attributes = try? manager.attributesOfItem(atPath: fileURL.path) {
                    if let date = CCUtility.getATime(fileURL.path) {
                        if attributes[.size] as? Double == 0 { continue }
                        if attributes[.type] as? FileAttributeType == FileAttributeType.typeDirectory { continue }
                        if fileURL.pathExtension == NCGlobal.shared.extensionPreview { continue }
                        // check offline
                        if offlineFiles.contains(fileURL.path) { continue }
                        let filter = offlineDir.filter({ fileURL.path.hasPrefix($0)})
                        if filter.count > 0 { continue }
                        // check date
                        if meetsRequirement(date: date) {
                            let folderURL = fileURL.deletingLastPathComponent()
                            let ocId = folderURL.lastPathComponent
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
    }
}
