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
 
 
    itemIdentifier = NSFileProviderItemIdentifier.rootContainer.rawValue            --> _ROOT_
    parentItemIdentifier = NSFileProviderItemIdentifier.rootContainer.rawValue      --> _ROOT_

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

    override init() { }

    deinit { }

    // MARK: - Enumeration

    override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {
        // Skip authentication checks for the working set container
        if containerItemIdentifier != .workingSet {

            // Verify version
            if let groupDefaults = UserDefaults(suiteName: NCBrandOptions.shared.capabilitiesGroup) {
                let lastVersion = groupDefaults.string(forKey: NCGlobal.shared.udLastVersion)
                let versionApp = NCUtility().getVersionApp(withBuild: false)
                if lastVersion != versionApp {
                    throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.notAuthenticated.rawValue, userInfo: ["code": NSNumber(value: NCGlobal.shared.errorVersionMismatch)])
                }
            }

            // Ensure a valid account is configured for the extension
            guard fileProviderData.setupAccount(domain: self.domain, providerExtension: self) != nil else {
                throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.notAuthenticated.rawValue, userInfo: [:])
            }

            // Check if passcode protection is enabled and required
            if NCPreferences().passcode != nil, NCPreferences().requestPasscodeAtStart {
                throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.notAuthenticated.rawValue, userInfo: ["code": NSNumber(value: NCGlobal.shared.errorUnauthorizedFilesPasscode)])
            }

            // Check if Files app access is disabled by branding options
            if NCPreferences().disableFilesApp || NCBrandOptions.shared.disable_openin_file {
                throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.notAuthenticated.rawValue, userInfo: ["code": NSNumber(value: NCGlobal.shared.errorDisableFilesApp)])
            }
        }

        // Return the enumerator for the requested container
        return FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier)
    }

    // MARK: - Item

    override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
        if identifier == .rootContainer, let session = fileProviderData.session {
            let metadata = database.createMetadataDirectory(fileName: NextcloudKit.shared.nkCommonInstance.rootFileName,
                                                            ocId: NSFileProviderItemIdentifier.rootContainer.rawValue,
                                                            serverUrl: utilityFileSystem.getHomeServer(session: session),
                                                            session: session)

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
        guard let session = fileProviderData.session,
              let item = try? item(for: identifier),
              let rootURL = fileProviderUtility().getDocumentStorageURL(for: domain, userId: session.userId, urlBase: session.urlBase) else {
            return nil
        }

        var url = rootURL.appendingPathComponent(identifier.rawValue, isDirectory: true)

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

                    let serverUrlFileName = utilityFileSystem.createServerUrl(serverUrl: metadata.serverUrl, fileName: metadata.fileName)
                    let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileName: metadata.fileName, userId: metadata.userId, urlBase: metadata.urlBase)
                    let account = metadata.account
                    let ocId = metadata.ocId

                    // Exists
                    if let tableLocalFile = await self.database.getTableLocalFileAsync(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)),
                       fileProviderUtility().fileProviderStorageExists(metadata),
                       tableLocalFile.etag == metadata.etag {
                        completionHandler(nil)
                        return
                    }

                    await fileProviderData.signalEnumerator(ocId: ocId, type: .update)

                    let (task, error) = backgroundSession.download(serverUrlFileName: serverUrlFileName,
                                                                   fileNameLocalPath: fileNameLocalPath,
                                                                   account: account,
                                                                   automaticResume: false,
                                                                   sessionIdentifier: NCNetworking.shared.sessionDownloadBackgroundExt)

                    if let task, error == .success {
                        await self.database.setMetadataSessionAsync(ocId: metadata.ocId,
                                                                    session: NCNetworking.shared.sessionDownload,
                                                                    sessionTaskIdentifier: task.taskIdentifier,
                                                                    sessionError: "",
                                                                    selector: "",
                                                                    status: NCGlobal.shared.metadataStatusDownloading)
                        do {
                            if let domain = self.domain,
                               let manager = NSFileProviderManager(for: domain) {
                                try await manager.register(task, forItemWithIdentifier: NSFileProviderItemIdentifier(itemIdentifier.rawValue))
                            } else {
                                try await NSFileProviderManager.default.register(task, forItemWithIdentifier: NSFileProviderItemIdentifier(itemIdentifier.rawValue))
                            }
                        } catch {
                            print(error)
                        }

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
                    guard let metadata = await self.database.getMetadataFromOcIdAndocIdTransferAsync(itemIdentifier.rawValue),
                          metadata.status == global.metadataStatusNormal else {
                        return
                    }
                    let serverUrlFileName = utilityFileSystem.createServerUrl(serverUrl: metadata.serverUrl, fileName: fileName)
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

                        do {
                            if let domain = self.domain,
                               let manager = NSFileProviderManager(for: domain) {
                                try await manager.register(task, forItemWithIdentifier: NSFileProviderItemIdentifier(itemIdentifier.rawValue))
                            } else {
                                try await NSFileProviderManager.default.register(task, forItemWithIdentifier: NSFileProviderItemIdentifier(itemIdentifier.rawValue))
                            }
                        } catch {
                            print(error)
                        }

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
                    guard let session = fileProviderData.session,
                        let tableDirectory = await self.providerUtility.getTableDirectoryFromParentItemIdentifierAsync(
                        parentItemIdentifier,
                        account: session.account,
                        homeServerUrl: self.utilityFileSystem.getHomeServer(session: session)
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
                                                                         account: session.account)
                    let ocIdTransfer = UUID().uuidString.lowercased()

                    NSFileCoordinator().coordinate(readingItemAt: fileURL,
                                                   options: .withoutChanges,
                                                   error: &errorCoordinator) { url in
                            self.providerUtility.copyFile(url.path,
                                                          toPath: self.utilityFileSystem.getDirectoryProviderStorageOcId(ocIdTransfer,
                                                                                                                         fileName: fileName,
                                                                                                                         userId: session.userId,
                                                                                                                         urlBase: session.urlBase))
                    }

                    fileURL.stopAccessingSecurityScopedResource()

                    let metadata = await self.database.createMetadataAsync(fileName: fileName,
                                                                           ocId: ocIdTransfer,
                                                                           serverUrl: tableDirectory.serverUrl,
                                                                           session: session,
                                                                           sceneIdentifier: nil)

                    metadata.session = NCNetworking.shared.sessionUploadBackgroundExt
                    metadata.size = size
                    metadata.status = NCGlobal.shared.metadataStatusUploading

                    await database.addMetadataAsync(metadata)
                    let serverUrlFileName = utilityFileSystem.createServerUrl(serverUrl: tableDirectory.serverUrl, fileName: fileName)
                    let fileNameLocalPath = utilityFileSystem.getDirectoryProviderStorageOcId(ocIdTransfer,
                                                                                              fileName: fileName,
                                                                                              userId: session.userId,
                                                                                              urlBase: session.urlBase)
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

                        do {
                            if let domain = self.domain,
                               let manager = NSFileProviderManager(for: domain) {
                                try await manager.register(task, forItemWithIdentifier: NSFileProviderItemIdentifier(ocIdTransfer))
                            } else {
                                try await NSFileProviderManager.default.register(task, forItemWithIdentifier: NSFileProviderItemIdentifier(ocIdTransfer))
                            }
                        } catch {
                            print(error)
                        }

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
