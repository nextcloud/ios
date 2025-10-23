// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

class FileProviderData: NSObject {
    static let shared = FileProviderData()

    let utilityFileSystem = NCUtilityFileSystem()
    let global = NCGlobal.shared
    let database = NCManageDatabase.shared

    var domain: NSFileProviderDomain?
    var session: NCSession.Session?

    var listFavoriteIdentifierRank: [String: NSNumber] = [:]
    var fileProviderSignalDeleteContainerItemIdentifier: [NSFileProviderItemIdentifier: NSFileProviderItemIdentifier] = [:]
    var fileProviderSignalUpdateContainerItem: [NSFileProviderItemIdentifier: FileProviderItem] = [:]
    var fileProviderSignalDeleteWorkingSetItemIdentifier: [NSFileProviderItemIdentifier: NSFileProviderItemIdentifier] = [:]
    var fileProviderSignalUpdateWorkingSetItem: [NSFileProviderItemIdentifier: FileProviderItem] = [:]

    var downloadPendingCompletionHandlers: [Int: (Error?) -> Void] = [:]

    enum FileProviderError: Error {
        case downloadError
        case uploadError
    }

    enum TypeSignal: String {
        case delete
        case update
        case workingSet
    }

    // MARK: - 

    @discardableResult
    func setupAccount(domain: NSFileProviderDomain? = nil,
                      tblAccount: tableAccount? = nil,
                      providerExtension: NSFileProviderExtension) -> tableAccount? {
        let version = NSString(format: NCBrandOptions.shared.textCopyrightNextcloudiOS as NSString, NCUtility().getVersionBuild()) as String
        let tblAccounts = self.database.getAllTableAccount()
        var matchAccount: tableAccount?

        NextcloudKit.configureLogger(logLevel: (NCBrandOptions.shared.disable_log ? .disabled : NCPreferences().log))

        if let domain {
            self.domain = domain
            // Match the domain identifier with one of the stored accounts
            matchAccount = tblAccounts.first(where: {
                guard let urlBase = NSURL(string: $0.urlBase), let host = urlBase.host else {
                    return false
                }
                let accountDomain = "\($0.userId) (\(host))"
                return accountDomain == domain.identifier.rawValue
            }) ?? self.database.getActiveTableAccount()
        } else {
            matchAccount = self.database.getActiveTableAccount()
        }

        guard let matchAccount else {
            return nil
        }
        self.session = NCSession.Session(account: matchAccount.account,
                                         urlBase: matchAccount.urlBase,
                                         user: matchAccount.user,
                                         userId: matchAccount.userId)

        nkLog(start: "Start File Provider session " + version + " (File Provider Extension) with account: \(matchAccount.account)")

        // NextcloudKit Session
        NextcloudKit.shared.setup(groupIdentifier: NCBrandOptions.shared.capabilitiesGroup, delegate: NCNetworking.shared)
        NextcloudKit.shared.appendSession(account: matchAccount.account,
                                          urlBase: matchAccount.urlBase,
                                          user: matchAccount.user,
                                          userId: matchAccount.userId,
                                          password: NCPreferences().getPassword(account: matchAccount.account),
                                          userAgent: userAgent,
                                          httpMaximumConnectionsPerHost: NCBrandOptions.shared.httpMaximumConnectionsPerHost,
                                          httpMaximumConnectionsPerHostInDownload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInDownload,
                                          httpMaximumConnectionsPerHostInUpload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInUpload,
                                          groupIdentifier: NCBrandOptions.shared.capabilitiesGroup)

        return matchAccount
    }

    // MARK: -

    @discardableResult
    func signalEnumerator(ocId: String, type: TypeSignal) async -> FileProviderItem? {
        guard let metadata = await self.database.getMetadataFromOcIdAsync(ocId),
              let parentItemIdentifier = await fileProviderUtility().getParentItemIdentifierAsync(metadata: metadata) else {
            return nil
        }
        let item = FileProviderItem(metadata: metadata, parentItemIdentifier: parentItemIdentifier)

        if type == .delete {
            fileProviderSignalDeleteContainerItemIdentifier[item.itemIdentifier] = item.itemIdentifier
            fileProviderSignalDeleteWorkingSetItemIdentifier[item.itemIdentifier] = item.itemIdentifier
        }
        if type == .update {
            fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
            fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
        }
        if type == .workingSet {
            fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
        }
        if type == .delete || type == .update {
            do {
                if let domain = self.domain {
                    try await NSFileProviderManager(for: domain)?.signalEnumerator(for: parentItemIdentifier)
                } else {
                    try await NSFileProviderManager.default.signalEnumerator(for: parentItemIdentifier)
                }
            } catch {
                print(error)
            }
        }

        do {
            if let domain {
                try await NSFileProviderManager(for: domain)?.signalEnumerator(for: .workingSet)
            } else {
                try await NSFileProviderManager.default.signalEnumerator(for: .workingSet)
            }
        } catch {
            print(error)
        }

        return item
    }

    // MARK: - DOWNLOAD

    func downloadComplete(fileName: String,
                          serverUrl: String,
                          etag: String?,
                          date: Date?,
                          dateLastModified: Date?,
                          length: Int64,
                          task: URLSessionTask,
                          error: NKError) async {
        let taskIdentifier = task.taskIdentifier
        let metadata = await self.database.getMetadataAsync(predicate: NSPredicate(format: "serverUrl == %@ AND fileName == %@", serverUrl, fileName))

        guard let metadata else {
            downloadPendingCompletionHandlers[taskIdentifier]?(nil)
            downloadPendingCompletionHandlers.removeValue(forKey: taskIdentifier)

            await signalEnumerator(ocId: "", type: .update)
            return
        }

        let ocId = metadata.ocId

        await self.database.setMetadataSessionAsync(ocId: ocId,
                                                    session: "",
                                                    sessionTaskIdentifier: 0,
                                                    sessionError: "",
                                                    status: self.global.metadataStatusNormal,
                                                    etag: etag)

        if error == .success {
            if let metadata = await self.database.getMetadataFromOcIdAsync(ocId) {
                await self.database.addLocalFilesAsync(metadatas: [metadata])
            }
        }

        if let completion = downloadPendingCompletionHandlers[taskIdentifier] {
            await MainActor.run {
                completion(nil)
            }
        }
        downloadPendingCompletionHandlers.removeValue(forKey: taskIdentifier)

        await signalEnumerator(ocId: ocId, type: .update)
    }

    // MARK: - UPLOAD

    func uploadComplete(fileName: String,
                        serverUrl: String,
                        ocId: String?,
                        etag: String?,
                        date: Date?,
                        size: Int64,
                        task: URLSessionTask,
                        error: NKError) async {
        guard let metadata = await self.database.getMetadataAsync(predicate: NSPredicate(format: "serverUrl == %@ AND fileName == %@ AND sessionTaskIdentifier == %d", serverUrl, fileName, task.taskIdentifier)) else {
            let predicate = NSPredicate(format: "fileName == %@ AND serverUrl == %@", fileName, serverUrl)
            await self.database.deleteMetadataAsync(predicate: predicate)

            return
        }

        if let ocId, !metadata.ocIdTransfer.isEmpty {
            let atPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocIdTransfer, userId: metadata.userId, urlBase: metadata.urlBase)
            let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId, userId: metadata.userId, urlBase: metadata.urlBase)
            self.utilityFileSystem.copyFile(atPath: atPath, toPath: toPath)
        }

        if error == .success, let ocId {
            await signalEnumerator(ocId: metadata.ocIdTransfer, type: .delete)

            if !metadata.ocIdTransfer.isEmpty, ocId != metadata.ocIdTransfer {
                await self.database.deleteMetadataAsync(id: metadata.ocIdTransfer)
            }

            metadata.fileName = fileName
            metadata.serverUrl = serverUrl
            metadata.uploadDate = (date as? NSDate) ?? NSDate()
            metadata.etag = etag ?? ""
            metadata.ocId = ocId
            metadata.size = size
            if let fileId = NCUtility().ocIdToFileId(ocId: ocId) {
                metadata.fileId = fileId
            }

            metadata.sceneIdentifier = nil
            metadata.session = ""
            metadata.sessionError = ""
            metadata.sessionSelector = ""
            metadata.sessionDate = nil
            metadata.sessionTaskIdentifier = 0
            metadata.status = NCGlobal.shared.metadataStatusNormal

            await self.database.addMetadataAsync(metadata)
            await self.database.addLocalFilesAsync(metadatas: [metadata])

            await signalEnumerator(ocId: ocId, type: .update)

        } else {

            await self.database.deleteMetadataAsync(id: metadata.ocIdTransfer)

            await signalEnumerator(ocId: metadata.ocIdTransfer, type: .delete)
        }
    }
}
