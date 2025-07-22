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
    parentItemIdentifier = NSFileProviderItemIdentifier.rootContainer.rawValue      --> .workingSet

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
    lazy var providerUtility = fileProviderUtility()
    lazy var utilityFileSystem = NCUtilityFileSystem()
    let global = NCGlobal.shared
    let database = NCManageDatabase.shared
    let backgroundSession = NKBackground(nkCommonInstance: NextcloudKit.shared.nkCommonInstance)

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
        // Skip authentication checks for the working set container
        if containerItemIdentifier != .workingSet {
            // Ensure a valid account is configured for the extension
            guard fileProviderData.shared.setupAccount(domain: domain, providerExtension: self) != nil else {
                throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.notAuthenticated.rawValue, userInfo: [:])
            }

            // Check if passcode protection is enabled and required
            if NCKeychain().passcode != nil, NCKeychain().requestPasscodeAtStart {
                throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.notAuthenticated.rawValue, userInfo: ["code": NSNumber(value: NCGlobal.shared.errorUnauthorizedFilesPasscode)])
            }

            // Check if Files app access is disabled by branding options
            if NCKeychain().disableFilesApp || NCBrandOptions.shared.disable_openin_file {
                throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.notAuthenticated.rawValue, userInfo: ["code": NSNumber(value: NCGlobal.shared.errorDisableFilesApp)])
            }
        }

        // Return the enumerator for the requested container
        return FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier)
    }

    // MARK: - Item

    override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
        if identifier == .rootContainer {
            guard let metadata = database.getRootContainerMetadata(accout: fileProviderData.shared.session.account) else {
                throw NSFileProviderError(.noSuchItem)
            }
            return FileProviderItem(metadata: metadata, parentItemIdentifier: .rootContainer)
        }

        guard let metadata = providerUtility.getTableMetadataFromItemIdentifier(identifier),
              let parentItemIdentifier = providerUtility.getParentItemIdentifier(account: metadata.account, serverUrl: metadata.serverUrl) else {
            throw NSFileProviderError(.noSuchItem)
        }
        let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)

        return item
    }

    override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
        guard let item = try? item(for: identifier) else {
            return nil
        }
        var url = fileProviderData.shared.fileProviderManager.documentStorageURL.appendingPathComponent(identifier.rawValue, isDirectory: true)

        let isDir = (item as? FileProviderItem)?.metadata.directory ?? false
        url = url.appendingPathComponent(item.filename, isDirectory: isDir)

        return url
    }

    override func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
        let pathComponents = url.pathComponents

        // Expect path format: <documentStorage>/<item identifier>/<file name>
        // e.g., /private/var/mobile/Containers/.../Documents/ABC123/photo.jpg
        guard pathComponents.count > 2 else {
            assertionFailure("Unexpected URL format. Cannot extract item identifier.")
            return nil
        }
        // Extract the identifier from the second-to-last component
        let itemIdentifier = NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])

        return itemIdentifier
    }

    override func providePlaceholder(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        // Resolve the persistent identifier from the file URL
        guard let identifier = persistentIdentifierForItem(at: url) else {
            return completionHandler(NSFileProviderError(.noSuchItem))
        }

        do {
            let fileProviderItem = try item(for: identifier)
            let placeholderURL = NSFileProviderManager.placeholderURL(for: url)
            try NSFileProviderManager.writePlaceholder(at: placeholderURL, withMetadata: fileProviderItem)

            completionHandler(nil)
        } catch {
            // Pass any thrown error to the completion handler
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

                    await fileProviderData.shared.signalEnumerator(ocId: metadata.ocId, type: .update)

                    let (task, error) = backgroundSession.download(serverUrlFileName: serverUrlFileName,
                                                                   fileNameLocalPath: fileNameLocalPath,
                                                                   account: account,
                                                                   automaticResume: false,
                                                                   sessionIdentifier: NCNetworking.shared.sessionDownloadBackgroundExt)

                    if let task, error == .success {
                        await self.database.setMetadataSessionAsync(ocId: ocId,
                                                                    sessionTaskIdentifier: task.taskIdentifier)
                        try await NSFileProviderManager.default.register(task, forItemWithIdentifier: NSFileProviderItemIdentifier(itemIdentifier.rawValue))
                        await fileProviderData.shared.signalEnumerator(ocId: metadata.ocId, type: .update)

                        fileProviderData.shared.downloadPendingCompletionHandlers[task.taskIdentifier] = completionHandler

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
                    guard let metadata = await self.database.getMetadataFromOcIdAndocIdTransferAsync(itemIdentifier.rawValue) else {
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
                        await fileProviderData.shared.signalEnumerator(ocId: ocId, type: .update)

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
                        account: fileProviderData.shared.session.account,
                        homeServerUrl: self.utilityFileSystem.getHomeServer(session: fileProviderData.shared.session)
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
                                                                         account: fileProviderData.shared.session.account)
                    let ocIdTransfer = UUID().uuidString.lowercased()

                    NSFileCoordinator().coordinate(readingItemAt: fileURL,
                                                   options: .withoutChanges,
                                                   error: &errorCoordinator) { url in
                            self.providerUtility.copyFile(url.path,
                                                          toPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(ocIdTransfer, fileNameView: fileName))
                    }

                    fileURL.stopAccessingSecurityScopedResource()

                    let metadata = await self.database.createMetadataAsync(fileName: fileName,
                                                                           ocId: ocIdTransfer,
                                                                           serverUrl: tableDirectory.serverUrl,
                                                                           session: fileProviderData.shared.session,
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
                                                                       automaticResume: false,
                                                                       sessionIdentifier: metadata.session)

                    if let task, error == .success {
                        await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                    sessionTaskIdentifier: task.taskIdentifier,
                                                                    status: NCGlobal.shared.metadataStatusUploading)

                        try await NSFileProviderManager.default.register(task, forItemWithIdentifier: NSFileProviderItemIdentifier(ocIdTransfer))
                        await fileProviderData.shared.signalEnumerator(ocId: metadata.ocId, type: .update)

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
