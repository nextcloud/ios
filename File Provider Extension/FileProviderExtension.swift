// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

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

final class FileProviderExtension: NSFileProviderExtension {
    lazy var providerUtility = fileProviderUtility()
    lazy var utilityFileSystem = NCUtilityFileSystem()
    let fileProviderData = FileProviderData.shared
    let global = NCGlobal.shared
    let database = NCManageDatabase.shared
    let backgroundSession = NKBackground(nkCommonInstance: NextcloudKit.shared.nkCommonInstance)

    override init() {
        super.init()

        _ = utilityFileSystem.directoryProviderStorage
    }

    deinit {
        print("")
    }

    // MARK: - Enumeration

    override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {
        var maybeEnumerator: NSFileProviderEnumerator?

        if containerItemIdentifier != NSFileProviderItemIdentifier.workingSet {
            if fileProviderData.setupAccount(providerExtension: self) == nil {
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
            metadata.account = fileProviderData.session.account
            metadata.directory = true
            metadata.ocId = NSFileProviderItemIdentifier.rootContainer.rawValue
            metadata.fileName = "root"
            metadata.fileNameView = "root"
            metadata.serverUrl = utilityFileSystem.getHomeServer(session: fileProviderData.session)
            metadata.classFile = NKTypeClassFile.directory.rawValue
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
        var url = NSFileProviderManager.default.documentStorageURL.appendingPathComponent(identifier.rawValue, isDirectory: true)

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
        Task {
            autoreleasepool {
                Task {
                    let pathComponents = url.pathComponents
                    let itemIdentifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
                    guard let metadata = await self.database.getMetadataFromOcIdAndocIdTransferAsync(itemIdentifier.rawValue) else {
                        completionHandler(NSFileProviderError(.noSuchItem))
                        return
                    }

                    if metadata.directory || !metadata.session.isEmpty {
                        completionHandler(nil)
                        return
                    }

                    let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
                    let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileName)
                    let account = metadata.account
                    let ocId = metadata.ocId

                    // Exists
                    if let tableLocalFile = await self.database.getTableLocalFileAsync(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)),
                       fileProviderUtility().fileProviderStorageExists(metadata),
                       tableLocalFile.etag == metadata.etag {
                        completionHandler(nil)
                        return
                    }

                    guard let metadata = await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                                     session: NCNetworking.shared.sessionDownload,
                                                                                     sessionTaskIdentifier: 0,
                                                                                     sessionError: "",
                                                                                     selector: "",
                                                                                     status: NCGlobal.shared.metadataStatusDownloading) else {
                        completionHandler(NSFileProviderError(.noSuchItem))
                        return
                    }

                    await fileProviderData.signalEnumerator(ocId: metadata.ocId, type: .update)

                    let (task, error) = backgroundSession.download(serverUrlFileName: serverUrlFileName,
                                                                   fileNameLocalPath: fileNameLocalPath,
                                                                   account: account,
                                                                   automaticResume: false,
                                                                   sessionIdentifier: NCNetworking.shared.sessionDownloadBackgroundExt)

                    if let task, error == .success {
                        await self.database.setMetadataSessionAsync(ocId: ocId,
                                                                    sessionTaskIdentifier: task.taskIdentifier)
                        try await NSFileProviderManager.default.register(task, forItemWithIdentifier: NSFileProviderItemIdentifier(itemIdentifier.rawValue))
                        await fileProviderData.signalEnumerator(ocId: metadata.ocId, type: .update)

                        fileProviderData.downloadPendingCompletionHandlers[task.taskIdentifier] = completionHandler

                        task.resume()
                    }
                }
            }
        }
    }

    override func itemChanged(at url: URL) {
        Task {
            autoreleasepool {
                Task {
                    let pathComponents = url.pathComponents
                    assert(pathComponents.count > 2)
                    let itemIdentifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
                    let fileName = pathComponents[pathComponents.count - 1]
                    guard let metadata = self.database.getMetadataFromOcIdAndocIdTransfer(itemIdentifier.rawValue) else {
                        return
                    }
                    let serverUrlFileName = metadata.serverUrl + "/" + fileName
                    let ocId = metadata.ocId
                    let account = metadata.account

                    await self.database.setMetadataSessionAsync(ocId: ocId,
                                                                session: NCNetworking.shared.sessionUploadBackgroundExt,
                                                                sessionTaskIdentifier: 0,
                                                                sessionError: "",
                                                                selector: "",
                                                                status: NCGlobal.shared.metadataStatusUploading)

                    let (task, error) = await backgroundSession.uploadAsync(serverUrlFileName: serverUrlFileName,
                                                                            fileNameLocalPath: url.path,
                                                                            dateCreationFile: nil,
                                                                            dateModificationFile: nil,
                                                                            overwrite: true,
                                                                            account: account,
                                                                            automaticResume: false,
                                                                            sessionIdentifier: NCNetworking.shared.sessionUploadBackgroundExt)

                    if let task, error == .success {
                        await self.database.setMetadataSessionAsync(ocId: ocId,
                                                                    sessionTaskIdentifier: task.taskIdentifier,
                                                                    status: NCGlobal.shared.metadataStatusUploading)

                        try await NSFileProviderManager.default.register(task, forItemWithIdentifier: NSFileProviderItemIdentifier(itemIdentifier.rawValue))
                        await fileProviderData.signalEnumerator(ocId: ocId, type: .update)

                        task.resume()
                    }
                }
            }
        }
    }

    override func stopProvidingItem(at url: URL) {
        Task {
            let pathComponents = url.pathComponents
            assert(pathComponents.count > 2)
            let itemIdentifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
            guard let metadata = await self.database.getMetadataFromOcIdAndocIdTransferAsync(itemIdentifier.rawValue) else {
                return
            }

            if metadata.session == NCNetworking.shared.sessionDownload,
               let session = NextcloudKit.shared.nkCommonInstance.nksessions.session(forAccount: metadata.session)?.sessionData.session {
                let tasks: [URLSessionTask] = await withCheckedContinuation { continuation in
                    session.getAllTasks { tasks in
                        continuation.resume(returning: tasks)
                    }
                }
                let downloadTasks = tasks.compactMap { $0 as? URLSessionDownloadTask }

                downloadTasks.forEach { task in
                    if metadata.sessionTaskIdentifier == task.taskIdentifier {
                        task.cancel()
                    }
                }
            }
        }
    }

    override func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        Task {
            autoreleasepool {
                Task {
                    guard let tableDirectory = await self.providerUtility.getTableDirectoryFromParentItemIdentifierAsync(
                        parentItemIdentifier,
                        account: fileProviderData.session.account,
                        homeServerUrl: self.utilityFileSystem.getHomeServer(session: fileProviderData.session)
                    ) else {
                        completionHandler(nil, NSFileProviderError(.noSuchItem))
                        return
                    }

                    var size: Int64 = 0
                    var errorCoordinator: NSError?
                    _ = fileURL.startAccessingSecurityScopedResource()

                    do {
                        let attributes = try self.providerUtility.fileManager.attributesOfItem(atPath: fileURL.path)
                        size = attributes[.size] as? Int64 ?? 0
                        if attributes[.type] as? FileAttributeType == .typeDirectory {
                            completionHandler(nil, NSFileProviderError(.noSuchItem))
                            return
                        }
                    } catch {
                        completionHandler(nil, NSFileProviderError(.noSuchItem))
                        return
                    }

                    let fileName = self.utilityFileSystem.createFileName(fileURL.lastPathComponent,
                                                                         serverUrl: tableDirectory.serverUrl,
                                                                         account: fileProviderData.session.account)
                    let ocIdTransfer = UUID().uuidString.lowercased()

                    NSFileCoordinator().coordinate(readingItemAt: fileURL,
                                                   options: .withoutChanges,
                                                   error: &errorCoordinator) { url in
                            self.providerUtility.copyFile(url.path,
                                                          toPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(ocIdTransfer, fileNameView: fileName))
                    }

                    fileURL.stopAccessingSecurityScopedResource()

                    let metadata = self.database.createMetadata(fileName: fileName,
                                                                ocId: ocIdTransfer,
                                                                serverUrl: tableDirectory.serverUrl,
                                                                session: fileProviderData.session,
                                                                sceneIdentifier: nil
                    )

                    metadata.session = NCNetworking.shared.sessionUploadBackgroundExt
                    metadata.size = size
                    metadata.status = NCGlobal.shared.metadataStatusUploading

                    await self.database.addMetadataAsync(metadata)
                    let serverUrlFileName = tableDirectory.serverUrl + "/" + fileName
                    let fileNameLocalPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(ocIdTransfer, fileNameView: fileName)
                    let nkBackground = NKBackground(nkCommonInstance: NextcloudKit.shared.nkCommonInstance)

                    let (task, error) = await nkBackground.uploadAsync(serverUrlFileName: serverUrlFileName,
                                                                      fileNameLocalPath: fileNameLocalPath,
                                                                      dateCreationFile: nil,
                                                                      dateModificationFile: nil,
                                                                      overwrite: true,
                                                                      account: metadata.account,
                                                                      sessionIdentifier: metadata.session)

                    if let task, error == .success {
                        await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                    sessionTaskIdentifier: task.taskIdentifier,
                                                                    status: NCGlobal.shared.metadataStatusUploading)

                        try await NSFileProviderManager.default.register(task, forItemWithIdentifier: NSFileProviderItemIdentifier(ocIdTransfer))
                        await fileProviderData.signalEnumerator(ocId: metadata.ocId, type: .update)

                        task.resume()

                        let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)
                        completionHandler(item, nil)
                    } else {
                        completionHandler(nil, NSFileProviderError(.noSuchItem))
                    }
                }
            }
        }
    }
}
