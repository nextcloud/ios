// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

class fileProviderUtility: NSObject {
    let fileManager = FileManager()
    let utilityFileSystem = NCUtilityFileSystem()
    let database = NCManageDatabase.shared

    func getAccountFromItemIdentifier(_ itemIdentifier: NSFileProviderItemIdentifier) -> String? {
        let ocId = itemIdentifier.rawValue
        return self.database.getMetadataFromOcId(ocId)?.account
    }

    func getTableMetadataFromItemIdentifier(_ itemIdentifier: NSFileProviderItemIdentifier) -> tableMetadata? {
        let ocId = itemIdentifier.rawValue
        return self.database.getMetadataFromOcId(ocId)
    }

    func getTableMetadataFromItemIdentifierAsync(_ itemIdentifier: NSFileProviderItemIdentifier) async -> tableMetadata? {
        let ocId = itemIdentifier.rawValue
        return await self.database.getMetadataFromOcIdAsync(ocId)
    }

    func getItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier {
        return NSFileProviderItemIdentifier(metadata.ocId)
    }

    func getParentItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier? {
        let homeServerUrl = utilityFileSystem.getHomeServer(session: FileProviderData.shared.session)
        if let directory = self.database.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
            if directory.serverUrl == homeServerUrl {
                return NSFileProviderItemIdentifier(NSFileProviderItemIdentifier.rootContainer.rawValue)
            } else {
                // get the metadata.ocId of parent Directory
                if let metadata = self.database.getMetadataFromOcId(directory.ocId) {
                    let identifier = getItemIdentifier(metadata: metadata)
                    return identifier
                }
            }
        }
        return nil
    }

    func getParentItemIdentifierAsync(metadata: tableMetadata) async -> NSFileProviderItemIdentifier? {
        let homeServerUrl = utilityFileSystem.getHomeServer(session: FileProviderData.shared.session)
        if let directory = await self.database.getTableDirectoryAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
            if directory.serverUrl == homeServerUrl {
                return NSFileProviderItemIdentifier(NSFileProviderItemIdentifier.rootContainer.rawValue)
            } else {
                // get the metadata.ocId of parent Directory
                if let metadata = await self.database.getMetadataFromOcIdAsync(directory.ocId) {
                    let identifier = getItemIdentifier(metadata: metadata)
                    return identifier
                }
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
        guard let directory = self.database.getTableDirectory(predicate: predicate) else { return nil }
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
        guard let directory = await self.database.getTableDirectoryAsync(predicate: predicate) else {
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
        let pathA = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)
        let pathB = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)

        let sizeA = fileSize(at: pathA)
        let sizeB = fileSize(at: pathB)

        if metadata.isDirectoryE2EE == true {
            return (sizeA == metadata.size || sizeB == metadata.size) && sizeB > 0
        }

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
}
