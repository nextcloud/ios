//
//  FileProviderExtension.swift
//  Files
//
//  Created by Marino Faggiana on 26/03/18.
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
import FileProvider
import NextcloudKit
import Alamofire

/* -----------------------------------------------------------------------------------------------------------------------------------------------
                                                            STRUCT item
   -----------------------------------------------------------------------------------------------------------------------------------------------
 
 
    itemIdentifier = NSFileProviderItemIdentifier.rootContainer.rawValue            --> root
    parentItemIdentifier = NSFileProviderItemIdentifier.rootContainer.rawValue      --> root
 
                                    ↓
 
    itemIdentifier = metadata.ocId (ex. 00ABC1)                                     --> func getItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier
    parentItemIdentifier = NSFileProviderItemIdentifier.rootContainer.rawValue      --> func getParentItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier?
 
                                    ↓

    itemIdentifier = metadata.ocId (ex. 00CCC)                                      --> func getItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier
    parentItemIdentifier = parent itemIdentifier (00ABC1)                           --> func getParentItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier?
 
                                    ↓
 
    itemIdentifier = metadata.ocId (ex. 000DD)                                      --> func getItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier
    parentItemIdentifier = parent itemIdentifier (00CCC)                            --> func getParentItemIdentifier(metadata: tableMetadata) -> NSFileProviderItemIdentifier?
 
   -------------------------------------------------------------------------------------------------------------------------------------------- */

class FileProviderExtension: NSFileProviderExtension, NCNetworkingDelegate {

    var outstandingSessionTasks: [URL: URLSessionTask] = [:]
    var outstandingOcIdTemp: [String: String] = [:]

    override init() {
        super.init()

        // Create directory File Provider Storage
        CCUtility.getDirectoryProviderStorage()
        // Configure URLSession
        _ = NCNetworking.shared.sessionManagerBackgroundExtension
    }

    deinit {
        print("")
    }

    // MARK: - Enumeration

    override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {

        var maybeEnumerator: NSFileProviderEnumerator?

        if containerItemIdentifier != NSFileProviderItemIdentifier.workingSet {
            if fileProviderData.shared.setupAccount(domain: domain, providerExtension: self) == nil {
                throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.notAuthenticated.rawValue, userInfo: [:])
            } else if let passcode = CCUtility.getPasscode(), !passcode.isEmpty, CCUtility.isPasscodeAtStartEnabled() {
                throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.notAuthenticated.rawValue, userInfo: ["code" : NSNumber(value: NCGlobal.shared.errorUnauthorizedFilesPasscode)])
            } else if CCUtility.getDisableFilesApp() || NCBrandOptions.shared.disable_openin_file {
                throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.notAuthenticated.rawValue, userInfo: ["code" : NSNumber(value: NCGlobal.shared.errorDisableFilesApp)])
            }
        }

        if containerItemIdentifier == NSFileProviderItemIdentifier.rootContainer {
            maybeEnumerator = FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier)
        } else if containerItemIdentifier == NSFileProviderItemIdentifier.workingSet {
            maybeEnumerator = FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier)
        } else {
            // determine if the item is a directory or a file
            // - for a directory, instantiate an enumerator of its subitems
            // - for a file, instantiate an enumerator that observes changes to the file
            let item = try self.item(for: containerItemIdentifier)

            if item.typeIdentifier == kUTTypeFolder as String {
                maybeEnumerator = FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier)
            } else {
                maybeEnumerator = FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier)
            }
        }

        guard let enumerator = maybeEnumerator else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo: [:])
        }

        return enumerator
    }

    // MARK: - Item

    override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {

        if identifier == .rootContainer {

            let metadata = tableMetadata()

            metadata.account = fileProviderData.shared.account
            metadata.directory = true
            metadata.ocId = NSFileProviderItemIdentifier.rootContainer.rawValue
            metadata.fileName = "root"
            metadata.fileNameView = "root"
            metadata.serverUrl = fileProviderData.shared.homeServerUrl
            metadata.classFile = NKCommon.TypeClassFile.directory.rawValue

            return FileProviderItem(metadata: metadata, parentItemIdentifier: NSFileProviderItemIdentifier(NSFileProviderItemIdentifier.rootContainer.rawValue))

        } else {

            guard let metadata = fileProviderUtility.shared.getTableMetadataFromItemIdentifier(identifier) else {
                throw NSFileProviderError(.noSuchItem)
            }
            guard let parentItemIdentifier = fileProviderUtility.shared.getParentItemIdentifier(metadata: metadata) else {
                throw NSFileProviderError(.noSuchItem)
            }
            let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
            return item
        }
    }

    override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {

        // resolve the given identifier to a file on disk
        guard let item = try? item(for: identifier) else {
            return nil
        }

        var url = fileProviderData.shared.fileProviderManager.documentStorageURL.appendingPathComponent(identifier.rawValue, isDirectory: true)

        // (fix copy/paste directory -> isDirectory = false)
        url = url.appendingPathComponent(item.filename, isDirectory: false)

        return url
    }

    override func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {

        // resolve the given URL to a persistent identifier using a database
        let pathComponents = url.pathComponents

        // exploit the fact that the path structure has been defined as
        // <base storage directory>/<item identifier>/<item file name> above
        assert(pathComponents.count > 2)

        let itemIdentifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
        return itemIdentifier
    }

    override func providePlaceholder(at url: URL, completionHandler: @escaping (Error?) -> Void) {

        guard let identifier = persistentIdentifierForItem(at: url) else {
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }

        do {
            let fileProviderItem = try item(for: identifier)
            let placeholderURL = NSFileProviderManager.placeholderURL(for: url)
            try NSFileProviderManager.writePlaceholder(at: placeholderURL, withMetadata: fileProviderItem)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    override func startProvidingItem(at url: URL, completionHandler: @escaping ((_ error: Error?) -> Void)) {

        let pathComponents = url.pathComponents
        let identifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])

        if let _ = outstandingSessionTasks[url] {
            completionHandler(nil)
            return
        }

        guard let metadata = fileProviderUtility.shared.getTableMetadataFromItemIdentifier(identifier) else {
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }

        // Document VIEW ONLY
        if metadata.isDocumentViewableOnly {
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }

        let tableLocalFile = NCManageDatabase.shared.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
        if tableLocalFile != nil && CCUtility.fileProviderStorageExists(metadata) && tableLocalFile?.etag == metadata.etag {
            completionHandler(nil)
            return
        }

        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)!

        // Update status
        NCManageDatabase.shared.setMetadataStatus(ocId: metadata.ocId, status: NCGlobal.shared.metadataStatusDownloading)
        fileProviderData.shared.signalEnumerator(ocId: metadata.ocId, update: true)

        NextcloudKit.shared.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, requestHandler: { _ in

        }, taskHandler: { task in

            self.outstandingSessionTasks[url] = task
            fileProviderData.shared.fileProviderManager.register(task, forItemWithIdentifier: NSFileProviderItemIdentifier(identifier.rawValue)) { _ in }

        }, progressHandler: { _ in

        }) { _, etag, date, _, _, _, error in

            self.outstandingSessionTasks.removeValue(forKey: url)
            guard var metadata = fileProviderUtility.shared.getTableMetadataFromItemIdentifier(identifier) else {
                completionHandler(NSFileProviderError(.noSuchItem))
                return
            }
            metadata = tableMetadata.init(value: metadata)

            if error == .success {

                metadata.status = NCGlobal.shared.metadataStatusNormal
                metadata.date = date ?? NSDate()
                metadata.etag = etag ?? ""

                NCManageDatabase.shared.addLocalFile(metadata: metadata)
                NCManageDatabase.shared.addMetadata(metadata)

                completionHandler(nil)

            } else if error.errorCode == 200 {

                NCManageDatabase.shared.setMetadataStatus(ocId: metadata.ocId, status: NCGlobal.shared.metadataStatusNormal)

                completionHandler(nil)

            } else {

                metadata.status = NCGlobal.shared.metadataStatusDownloadError
                metadata.sessionError = error.errorDescription
                NCManageDatabase.shared.addMetadata(metadata)

                completionHandler(NSFileProviderError(.noSuchItem))
            }

            fileProviderData.shared.signalEnumerator(ocId: metadata.ocId, update: true)
        }
    }

    override func itemChanged(at url: URL) {

        let pathComponents = url.pathComponents
        assert(pathComponents.count > 2)
        let itemIdentifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
        let fileName = pathComponents[pathComponents.count - 1]
        var ocId = itemIdentifier.rawValue

        // Temp ocId ?
        if outstandingOcIdTemp[ocId] != nil && outstandingOcIdTemp[ocId] != ocId {
            ocId = outstandingOcIdTemp[ocId]!
            let atPath = CCUtility.getDirectoryProviderStorageOcId(itemIdentifier.rawValue, fileNameView: fileName)
            let toPath = CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileName)
            CCUtility.copyFile(atPath: atPath, toPath: toPath)
        }
        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) else { return }

        let serverUrlFileName = metadata.serverUrl + "/" + fileName
        let fileNameLocalPath = url.path

        if let task = NKBackground(nkCommonInstance: NextcloudKit.shared.nkCommonInstance).upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, dateCreationFile: nil, dateModificationFile: nil, description: metadata.ocId, session: NCNetworking.shared.sessionManagerBackgroundExtension) {

            fileProviderData.shared.fileProviderManager.register(task, forItemWithIdentifier: NSFileProviderItemIdentifier(metadata.fileId)) { _ in }
        }
    }

    override func stopProvidingItem(at url: URL) {

        let fileHasLocalChanges = false

        if !fileHasLocalChanges {
            // remove the existing file to free up space
            do {
                _ = try fileProviderUtility.shared.fileManager.removeItem(at: url)
            } catch let error {
                print("error: \(error)")
            }

            // write out a placeholder to facilitate future property lookups
            self.providePlaceholder(at: url, completionHandler: { _ in
                // handle any error, do any necessary cleanup
            })
        }

        // Download task
        if let downloadTask = outstandingSessionTasks[url] {
            downloadTask.cancel()
            outstandingSessionTasks.removeValue(forKey: url)
        }
    }

    override func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {

        DispatchQueue.main.async {

            autoreleasepool {

                var size = 0 as Int64
                var error: NSError?

                guard let tableDirectory = fileProviderUtility.shared.getTableDirectoryFromParentItemIdentifier(parentItemIdentifier, account: fileProviderData.shared.account, homeServerUrl: fileProviderData.shared.homeServerUrl) else {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                    return
                }

                _ = fileURL.startAccessingSecurityScopedResource()

                // typefile directory ? (NOT PERMITTED)
                do {
                    let attributes = try fileProviderUtility.shared.fileManager.attributesOfItem(atPath: fileURL.path)
                    size = attributes[FileAttributeKey.size] as! Int64
                    let typeFile = attributes[FileAttributeKey.type] as! FileAttributeType
                    if typeFile == FileAttributeType.typeDirectory {
                        completionHandler(nil, NSFileProviderError(.noSuchItem))
                        return
                    }
                } catch {
                    completionHandler(nil, NSFileProviderError(.noSuchItem))
                    return
                }

                let fileName = NCUtilityFileSystem.shared.createFileName(fileURL.lastPathComponent, serverUrl: tableDirectory.serverUrl, account: fileProviderData.shared.account)
                let ocIdTemp = NSUUID().uuidString.lowercased()

                NSFileCoordinator().coordinate(readingItemAt: fileURL, options: .withoutChanges, error: &error) { url in
                    _ = fileProviderUtility.shared.copyFile(url.path, toPath: CCUtility.getDirectoryProviderStorageOcId(ocIdTemp, fileNameView: fileName))
                }

                fileURL.stopAccessingSecurityScopedResource()

                let metadata = NCManageDatabase.shared.createMetadata(account: fileProviderData.shared.account, user: fileProviderData.shared.user, userId: fileProviderData.shared.userId, fileName: fileName, fileNameView: fileName, ocId: ocIdTemp, serverUrl: tableDirectory.serverUrl, urlBase: fileProviderData.shared.accountUrlBase, url: "", contentType: "")
                metadata.session = NCNetworking.shared.sessionIdentifierBackgroundExtension
                metadata.size = size
                metadata.status = NCGlobal.shared.metadataStatusUploading

                NCManageDatabase.shared.addMetadata(metadata)

                let serverUrlFileName = tableDirectory.serverUrl + "/" + fileName
                let fileNameLocalPath = CCUtility.getDirectoryProviderStorageOcId(ocIdTemp, fileNameView: fileName)!

                if let task = NKBackground(nkCommonInstance: NextcloudKit.shared.nkCommonInstance).upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, dateCreationFile: nil, dateModificationFile: nil, description: ocIdTemp, session: NCNetworking.shared.sessionManagerBackgroundExtension) {

                    self.outstandingSessionTasks[URL(fileURLWithPath: fileNameLocalPath)] = task as URLSessionTask

                    fileProviderData.shared.fileProviderManager.register(task, forItemWithIdentifier: NSFileProviderItemIdentifier(ocIdTemp)) { _ in }
                }

                let item = FileProviderItem(metadata: tableMetadata.init(value: metadata), parentItemIdentifier: parentItemIdentifier)

                completionHandler(item, nil)
            }
        }
    }

    func uploadComplete(fileName: String, serverUrl: String, ocId: String?, etag: String?, date: NSDate?, size: Int64, description: String?, task: URLSessionTask, error: NKError) {

        guard let ocIdTemp = description else { return }
        guard let metadataTemp = NCManageDatabase.shared.getMetadataFromOcId(ocIdTemp) else { return }
        let metadata = tableMetadata.init(value: metadataTemp)

        let url = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(ocIdTemp, fileNameView: fileName))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.outstandingSessionTasks.removeValue(forKey: url)
        }
        outstandingOcIdTemp[ocIdTemp] = ocId

        if error == .success {

            // New file
            if ocId != ocIdTemp {
                // Signal update
                fileProviderData.shared.signalEnumerator(ocId: metadata.ocId, delete: true)
            }

            metadata.fileName = fileName
            metadata.serverUrl = serverUrl
            if let etag = etag { metadata.etag = etag }
            if let ocId = ocId { metadata.ocId = ocId }
            if let date = date { metadata.date = date }
            metadata.permissions = "RGDNVW"
            metadata.session = ""
            metadata.size = size
            metadata.status = NCGlobal.shared.metadataStatusNormal

            NCManageDatabase.shared.addMetadata(metadata)
            NCManageDatabase.shared.addLocalFile(metadata: metadata)

            // New file
            if ocId != ocIdTemp {

                NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp))

                // File system
                let atPath = CCUtility.getDirectoryProviderStorageOcId(ocIdTemp)
                let toPath = CCUtility.getDirectoryProviderStorageOcId(ocId)
                CCUtility.copyFile(atPath: atPath, toPath: toPath)
            }

            fileProviderData.shared.signalEnumerator(ocId: metadata.ocId, update: true)

        } else {

            NCManageDatabase.shared.deleteMetadata(predicate: NSPredicate(format: "ocId == %@", ocIdTemp))

            fileProviderData.shared.signalEnumerator(ocId: ocIdTemp, delete: true)
        }
    }

}
