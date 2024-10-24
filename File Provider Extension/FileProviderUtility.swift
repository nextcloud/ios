//
//  FileProviderData.swift
//  Files
//
//  Created by Marino Faggiana on 27/05/18.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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

    func getItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier {
        return NSFileProviderItemIdentifier(metadata.ocId)
    }

    func getParentItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier? {
        let homeServerUrl = utilityFileSystem.getHomeServer(session: fileProviderData.shared.session)
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
}
