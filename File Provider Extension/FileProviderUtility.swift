// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import FileProvider

class fileProviderUtility: NSObject {
    let fileManager = FileManager()

    func getDocumentStorageURL(for domain: NSFileProviderDomain?, userId: String, urlBase: String) -> URL? {
        guard let urlBase = NSURL(string: urlBase),
              let host = urlBase.host else {
            return nil
        }
        // Build the expected relative path used for the domain
        let relativePath = NCUtilityFileSystem().getPathDomain(userId: userId, host: host)

        // If a valid domain and manager exist, try to get its official documentStorageURL
        if let domain,
           let manager = NSFileProviderManager(for: domain) {
            let managerURL = manager.documentStorageURL

            // If the last path component matches, return the manager's path directly
            if managerURL.lastPathComponent == relativePath {
                return managerURL
            }

            // If it doesn't match (e.g. single-domain fallback), return manually constructed path
            return NSFileProviderManager.default.documentStorageURL.appendingPathComponent(relativePath)
        }

        return NSFileProviderManager.default.documentStorageURL.appendingPathComponent(relativePath)
    }

    func getAccountFromItemIdentifier(_ itemIdentifier: NSFileProviderItemIdentifier) -> String? {
        let ocId = itemIdentifier.rawValue
        return NCManageDatabaseFPE.shared.getMetadataFromOcId(ocId)?.account
    }

    func getTableMetadataFromItemIdentifier(_ itemIdentifier: NSFileProviderItemIdentifier) -> tableMetadata? {
        let ocId = itemIdentifier.rawValue
        return NCManageDatabaseFPE.shared.getMetadataFromOcId(ocId)
    }

    func getTableMetadataFromItemIdentifierAsync(_ itemIdentifier: NSFileProviderItemIdentifier) async -> tableMetadata? {
        let ocId = itemIdentifier.rawValue
        return await NCManageDatabaseFPE.shared.getMetadataFromOcIdAsync(ocId)
    }

    func getItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier {
        return NSFileProviderItemIdentifier(metadata.ocId)
    }

    func getParentItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier? {
        let homeServerUrl = NCUtilityFileSystem().getHomeServer(urlBase: metadata.urlBase, userId: metadata.userId)
        if let directory = NCManageDatabaseFPE.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
            if directory.serverUrl == homeServerUrl {
                return NSFileProviderItemIdentifier(NSFileProviderItemIdentifier.rootContainer.rawValue)
            } else {
                // get the metadata.ocId of parent Directory
                if let metadata = NCManageDatabaseFPE.shared.getMetadataFromOcId(directory.ocId) {
                    let identifier = getItemIdentifier(metadata: metadata)
                    return identifier
                }
            }
        }
        return nil
    }

    func getParentItemIdentifierAsync(metadata: tableMetadata) async -> NSFileProviderItemIdentifier? {
        let homeServerUrl = NCUtilityFileSystem().getHomeServer(urlBase: metadata.urlBase, userId: metadata.userId)
        if let directory = await NCManageDatabaseFPE.shared.getTableDirectoryAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
            if directory.serverUrl == homeServerUrl {
                return NSFileProviderItemIdentifier(NSFileProviderItemIdentifier.rootContainer.rawValue)
            } else {
                // get the metadata.ocId of parent Directory
                if let metadata = await NCManageDatabaseFPE.shared.getMetadataFromOcIdAsync(directory.ocId) {
                    let identifier = getItemIdentifier(metadata: metadata)
                    return identifier
                }
            }
        }
        return nil
    }

    func getParentItemIdentifierAsync(session: NCSession.Session, directory: tableDirectory?) async -> NSFileProviderItemIdentifier? {
        let homeServerUrl = NCUtilityFileSystem().getHomeServer(urlBase: session.urlBase, userId: session.userId)
        guard let directory else {
            return nil
        }
        if directory.serverUrl == homeServerUrl {
            return NSFileProviderItemIdentifier(NSFileProviderItemIdentifier.rootContainer.rawValue)
        } else {
            // get the metadata.ocId of parent Directory
            if let metadata = await NCManageDatabaseFPE.shared.getMetadataFromOcIdAsync(directory.ocId) {
                let identifier = getItemIdentifier(metadata: metadata)
                return identifier
            }
        }
        return nil
    }

    func getTableDirectoryFromParentItemIdentifier(_ parentItemIdentifier: NSFileProviderItemIdentifier, account: String, homeServerUrl: String) -> tableDirectory? {
        var predicate: NSPredicate
        if parentItemIdentifier == .rootContainer {
            predicate = NSPredicate(format: "account == %@ AND serverUrl == %@", account, homeServerUrl)
        } else {
            guard let metadata = getTableMetadataFromItemIdentifier(parentItemIdentifier) else { return nil }
            predicate = NSPredicate(format: "ocId == %@", metadata.ocId)
        }
        guard let directory = NCManageDatabaseFPE.shared.getTableDirectory(predicate: predicate) else { return nil }
        return directory
    }

    func getTableDirectoryFromParentItemIdentifierAsync(_ parentItemIdentifier: NSFileProviderItemIdentifier, account: String, homeServerUrl: String) async -> tableDirectory? {
        var predicate: NSPredicate
        if parentItemIdentifier == .rootContainer {
            predicate = NSPredicate(format: "account == %@ AND serverUrl == %@", account, homeServerUrl)
        } else {
            guard let metadata = await getTableMetadataFromItemIdentifierAsync(parentItemIdentifier) else {
                return nil
            }
            predicate = NSPredicate(format: "ocId == %@", metadata.ocId)
        }
        guard let directory = await NCManageDatabaseFPE.shared.getTableDirectoryAsync(predicate: predicate) else {
            return nil
        }

        return directory
    }

    func copyFile(_ atPath: String, toPath: String) {
        if !fileManager.fileExists(atPath: atPath) { return }

        do {
            try fileManager.removeItem(atPath: toPath)
        } catch let error {
            print("Error: \(error.localizedDescription)")
        }
        do {
            try fileManager.copyItem(atPath: atPath, toPath: toPath)
        } catch let error {
            print("Error: \(error.localizedDescription)")
        }
    }

    func moveFile(_ atPath: String, toPath: String) {
        if !fileManager.fileExists(atPath: atPath) { return }

        do {
            try fileManager.removeItem(atPath: toPath)
        } catch let error {
            print("Error: \(error.localizedDescription)")
        }
        do {
            try fileManager.moveItem(atPath: atPath, toPath: toPath)
        } catch let error {
            print("Error: \(error.localizedDescription)")
        }
    }

    func getFileSize(from url: URL) -> Int64? {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)

            if let fileSize = attributes[FileAttributeKey.size] as? Int64 {
                return fileSize
            } else {
                print("Failed to retrieve file size.")
                return nil
            }
        } catch {
            print("Error: \(error.localizedDescription)")
            return nil
        }
    }

    func fileProviderStorageExists(_ metadata: tableMetadata) -> Bool {
        let utilityFileSystem = NCUtilityFileSystem()
        let pathA = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileName: metadata.fileName, userId: metadata.userId, urlBase: metadata.urlBase)
        let pathB = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileName: metadata.fileNameView, userId: metadata.userId, urlBase: metadata.urlBase)

        let sizeA = fileSize(at: pathA)
        let sizeB = fileSize(at: pathB)

        return sizeB == metadata.size && metadata.size > 0
    }

    private func fileSize(at path: String) -> UInt64 {
        do {
            let attr = try fileManager.attributesOfItem(atPath: path)
            return attr[.size] as? UInt64 ?? 0
        } catch {
            nkLog(error: " [fileSize] Errore accesso a '\(path)': \(error)")
            return 0
        }
    }

    func createFileName(_ fileName: String, serverUrl: String, account: String) -> String {
        var resultFileName = fileName
        var exitLoop = false

        while exitLoop == false {
            if NCManageDatabaseFPE.shared.getMetadata(predicate: NSPredicate(format: "fileNameView ==[c] %@ AND serverUrl == %@ AND account == %@", resultFileName, serverUrl, account)) != nil {
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
}
