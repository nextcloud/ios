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
import UniformTypeIdentifiers
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

class FileProviderExtension: NSFileProviderExtension {
    let providerUtility = fileProviderUtility()
    let utilityFileSystem = NCUtilityFileSystem()
    let database = NCManageDatabase.shared

    override init() {
        super.init()

        _ = utilityFileSystem.directoryProviderStorage
        _ = fileProviderData.shared.setupAccount(domain: domain, providerExtension: self)
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
            } else if NCKeychain().passcode != nil, NCKeychain().requestPasscodeAtStart {
                throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.notAuthenticated.rawValue, userInfo: ["code": NSNumber(value: NCGlobal.shared.errorUnauthorizedFilesPasscode)])
            } else if NCKeychain().disableFilesApp || NCBrandOptions.shared.disable_openin_file {
                throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.notAuthenticated.rawValue, userInfo: ["code": NSNumber(value: NCGlobal.shared.errorDisableFilesApp)])
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
            if item.contentType == UTType.folder {
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
            metadata.account = fileProviderData.shared.session.account
            metadata.directory = true
            metadata.ocId = NSFileProviderItemIdentifier.rootContainer.rawValue
            metadata.fileName = "root"
            metadata.fileNameView = "root"
            metadata.serverUrl = utilityFileSystem.getHomeServer(session: fileProviderData.shared.session)
            metadata.classFile = NKCommon.TypeClassFile.directory.rawValue
            return FileProviderItem(metadata: metadata, parentItemIdentifier: NSFileProviderItemIdentifier(NSFileProviderItemIdentifier.rootContainer.rawValue))
        } else {
            guard let metadata = providerUtility.getTableMetadataFromItemIdentifier(identifier),
                  let parentItemIdentifier = providerUtility.getParentItemIdentifier(metadata: metadata) else {
                throw NSFileProviderError(.noSuchItem)
            }
            let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
            return item
        }
    }

    override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
        guard let item = try? item(for: identifier) else { return nil }
        var url = fileProviderData.shared.fileProviderManager.documentStorageURL.appendingPathComponent(identifier.rawValue, isDirectory: true)
        // (fix copy/paste directory -> isDirectory = false)
        url = url.appendingPathComponent(item.filename, isDirectory: false)
        return url
    }

    override func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
        let pathComponents = url.pathComponents
        // exploit the fact that the path structure has been defined as
        // <base storage directory>/<item identifier>/<item file name> above
        assert(pathComponents.count > 2)
        let itemIdentifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
        return itemIdentifier
    }

    override func providePlaceholder(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        guard let identifier = persistentIdentifierForItem(at: url) else {
            return completionHandler(NSFileProviderError(.noSuchItem))
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
        let itemIdentifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
        var metadata: tableMetadata?
        if let result = fileProviderData.shared.getUploadMetadata(id: itemIdentifier.rawValue) {
            metadata = result.metadata
        } else {
            metadata = self.database.getMetadataFromOcIdAndocIdTransfer(itemIdentifier.rawValue)
        }
        guard let metadata else {
            return completionHandler(NSFileProviderError(.noSuchItem))
        }
        if metadata.session == NCNetworking.shared.sessionUploadBackgroundExt {
            return completionHandler(nil)
        }
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)
        // Exists ? return
        if let tableLocalFile = self.database.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)),
           utilityFileSystem.fileProviderStorageExists(metadata),
           tableLocalFile.etag == metadata.etag {
            return completionHandler(nil)
        } else {
            self.database.setMetadataSession(ocId: metadata.ocId,
                                             session: NCNetworking.shared.sessionDownload,
                                             sessionTaskIdentifier: 0,
                                             sessionError: "",
                                             selector: "",
                                             status: NCGlobal.shared.metadataStatusDownloading)
        }
        /// SIGNAL
        fileProviderData.shared.signalEnumerator(ocId: metadata.ocId, type: .update)

        NextcloudKit.shared.download(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, account: metadata.account, requestHandler: { _ in
        }, taskHandler: { task in
            self.database.setMetadataSession(ocId: metadata.ocId,
                                             sessionTaskIdentifier: task.taskIdentifier)
            fileProviderData.shared.fileProviderManager.register(task, forItemWithIdentifier: NSFileProviderItemIdentifier(itemIdentifier.rawValue)) { _ in }
        }, progressHandler: { _ in
        }) { _, etag, date, _, _, _, error in
            guard let metadata = self.providerUtility.getTableMetadataFromItemIdentifier(itemIdentifier) else {
                return completionHandler(NSFileProviderError(.noSuchItem))
            }
            if error == .success {
                metadata.sceneIdentifier = nil
                metadata.session = ""
                metadata.sessionError = ""
                metadata.sessionSelector = ""
                metadata.sessionDate = nil
                metadata.sessionTaskIdentifier = 0
                metadata.status = NCGlobal.shared.metadataStatusNormal
                metadata.date = (date as? NSDate) ?? NSDate()
                metadata.etag = etag ?? ""
                self.database.addLocalFile(metadata: metadata)
                self.database.addMetadata(metadata)
                completionHandler(nil)
            } else if error.errorCode == 200 {
                self.database.setMetadataStatus(ocId: metadata.ocId, status: NCGlobal.shared.metadataStatusNormal)
                completionHandler(nil)
            } else {
                metadata.status = NCGlobal.shared.metadataStatusDownloadError
                metadata.sessionError = error.errorDescription
                self.database.addMetadata(metadata)
                completionHandler(NSFileProviderError(.noSuchItem))
            }
            /// SIGNAL
            fileProviderData.shared.signalEnumerator(ocId: metadata.ocId, type: .update)
        }
    }

    /// Upload the changed file
    override func itemChanged(at url: URL) {
        let pathComponents = url.pathComponents
        assert(pathComponents.count > 2)
        let itemIdentifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
        let fileName = pathComponents[pathComponents.count - 1]
        var metadata: tableMetadata?
        if let result = fileProviderData.shared.getUploadMetadata(id: itemIdentifier.rawValue) {
            metadata = result.metadata
        } else {
            metadata = self.database.getMetadataFromOcIdAndocIdTransfer(itemIdentifier.rawValue)
        }
        guard let metadata else {
            return
        }
        let serverUrlFileName = metadata.serverUrl + "/" + fileName

        self.database.setMetadataSession(ocId: metadata.ocId,
                                         session: NCNetworking.shared.sessionUploadBackgroundExt,
                                         sessionTaskIdentifier: 0,
                                         sessionError: "",
                                         selector: "",
                                         status: NCGlobal.shared.metadataStatusUploading)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if let task = NKBackground(nkCommonInstance: NextcloudKit.shared.nkCommonInstance).upload(serverUrlFileName: serverUrlFileName,
                                                                                                      fileNameLocalPath: url.path,
                                                                                                      dateCreationFile: nil,
                                                                                                      dateModificationFile: nil,
                                                                                                      overwrite: true,
                                                                                                      account: metadata.account,
                                                                                                      sessionIdentifier: metadata.session) {
                self.database.setMetadataSession(ocId: metadata.ocId,
                                                 sessionTaskIdentifier: task.taskIdentifier,
                                                 status: NCGlobal.shared.metadataStatusUploading)
                fileProviderData.shared.fileProviderManager.register(task, forItemWithIdentifier: NSFileProviderItemIdentifier(metadata.fileId)) { _ in }
            }
        }
    }

    override func stopProvidingItem(at url: URL) {
        let pathComponents = url.pathComponents
        assert(pathComponents.count > 2)
        let itemIdentifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
        guard let metadata = self.database.getMetadataFromOcIdAndocIdTransfer(itemIdentifier.rawValue) else { return }
        if metadata.session == NCNetworking.shared.sessionDownload {
            let session = NextcloudKit.shared.nkCommonInstance.getSession(account: metadata.session)?.sessionData.session
            session?.getTasksWithCompletionHandler { _, _, downloadTasks in
                downloadTasks.forEach { task in
                    if metadata.sessionTaskIdentifier == task.taskIdentifier {
                        task.cancel()
                    }
                }
            }
        }
    }

    override func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        DispatchQueue.main.async {
            autoreleasepool {
                guard let tableDirectory = self.providerUtility.getTableDirectoryFromParentItemIdentifier(parentItemIdentifier, account: fileProviderData.shared.session.account, homeServerUrl: self.utilityFileSystem.getHomeServer(session: fileProviderData.shared.session)) else {
                    return completionHandler(nil, NSFileProviderError(.noSuchItem))
                }
                var size = 0 as Int64
                var error: NSError?
                _ = fileURL.startAccessingSecurityScopedResource()
                // typefile directory ? (NOT PERMITTED)
                do {
                    let attributes = try self.providerUtility.fileManager.attributesOfItem(atPath: fileURL.path)
                    size = attributes[FileAttributeKey.size] as? Int64 ?? 0
                    let typeFile = attributes[FileAttributeKey.type] as? FileAttributeType
                    if typeFile == FileAttributeType.typeDirectory {
                        return completionHandler(nil, NSFileProviderError(.noSuchItem))
                    }
                } catch {
                    return completionHandler(nil, NSFileProviderError(.noSuchItem))
                }

                let fileName = self.utilityFileSystem.createFileName(fileURL.lastPathComponent, serverUrl: tableDirectory.serverUrl, account: fileProviderData.shared.session.account)
                let ocIdTransfer = NSUUID().uuidString.lowercased()

                NSFileCoordinator().coordinate(readingItemAt: fileURL, options: .withoutChanges, error: &error) { url in
                    self.providerUtility.copyFile(url.path, toPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(ocIdTransfer, fileNameView: fileName))
                }

                fileURL.stopAccessingSecurityScopedResource()

                let metadataForUpload = self.database.createMetadata(fileName: fileName,
                                                                     fileNameView: fileName,
                                                                     ocId: ocIdTransfer,
                                                                     serverUrl: tableDirectory.serverUrl,
                                                                     url: "",
                                                                     contentType: "",
                                                                     session: fileProviderData.shared.session,
                                                                     sceneIdentifier: nil)

                metadataForUpload.session = NCNetworking.shared.sessionUploadBackgroundExt
                metadataForUpload.size = size
                metadataForUpload.status = NCGlobal.shared.metadataStatusUploading

                self.database.addMetadata(metadataForUpload)

                let serverUrlFileName = tableDirectory.serverUrl + "/" + fileName
                let fileNameLocalPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(ocIdTransfer, fileNameView: fileName)

                if let task = NKBackground(nkCommonInstance: NextcloudKit.shared.nkCommonInstance).upload(serverUrlFileName: serverUrlFileName,
                                                                                                          fileNameLocalPath: fileNameLocalPath,
                                                                                                          dateCreationFile: nil,
                                                                                                          dateModificationFile: nil,
                                                                                                          overwrite: true,
                                                                                                          account: metadataForUpload.account,
                                                                                                          sessionIdentifier: metadataForUpload.session) {
                    self.database.setMetadataSession(ocId: metadataForUpload.ocId,
                                                     sessionTaskIdentifier: task.taskIdentifier,
                                                     status: NCGlobal.shared.metadataStatusUploading)
                    fileProviderData.shared.fileProviderManager.register(task, forItemWithIdentifier: NSFileProviderItemIdentifier(ocIdTransfer)) { _ in }
                    fileProviderData.shared.appendUploadMetadata(id: ocIdTransfer, metadata: metadataForUpload, task: task)
                }

                let item = FileProviderItem(metadata: tableMetadata.init(value: metadataForUpload), parentItemIdentifier: parentItemIdentifier)
                completionHandler(item, nil)
            }
        }
    }
}
