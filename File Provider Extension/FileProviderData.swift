// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

class fileProviderData: NSObject {
    static let shared = fileProviderData()

    var domain: NSFileProviderDomain?
    var fileProviderManager: NSFileProviderManager = NSFileProviderManager.default
    let utilityFileSystem = NCUtilityFileSystem()
    let global = NCGlobal.shared
    let database = NCManageDatabase.shared

    var listFavoriteIdentifierRank: [String: NSNumber] = [:]
    var fileProviderSignalDeleteContainerItemIdentifier: [NSFileProviderItemIdentifier: NSFileProviderItemIdentifier] = [:]
    var fileProviderSignalUpdateContainerItem: [NSFileProviderItemIdentifier: FileProviderItem] = [:]
    var fileProviderSignalDeleteWorkingSetItemIdentifier: [NSFileProviderItemIdentifier: NSFileProviderItemIdentifier] = [:]
    var fileProviderSignalUpdateWorkingSetItem: [NSFileProviderItemIdentifier: FileProviderItem] = [:]
    private var account: String = ""

    var downloadPendingCompletionHandlers: [Int: (Error?) -> Void] = [:]
    var uploadPendingCompletionHandlers: [Int: (Error?) -> Void] = [:]

    var session: NCSession.Session {
        if !account.isEmpty,
           let tableAccount = self.database.getTableAccount(account: account) {
            return NCSession.Session(account: tableAccount.account, urlBase: tableAccount.urlBase, user: tableAccount.user, userId: tableAccount.userId)
        } else if let activeTableAccount = self.database.getActiveTableAccount() {
            self.account = activeTableAccount.account
            return NCSession.Session(account: activeTableAccount.account, urlBase: activeTableAccount.urlBase, user: activeTableAccount.user, userId: activeTableAccount.userId)
        } else {
            return NCSession.Session(account: "", urlBase: "", user: "", userId: "")
        }
    }

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

    func setupAccount(domain: NSFileProviderDomain?, providerExtension: NSFileProviderExtension) -> tableAccount? {
        let version = NSString(format: NCBrandOptions.shared.textCopyrightNextcloudiOS as NSString, NCUtility().getVersionApp()) as String
        var tblAccount = self.database.getActiveTableAccount()
        let tblAccounts = self.database.getAllTableAccount()

        if let domain,
           let fileProviderManager = NSFileProviderManager(for: domain) {
            self.fileProviderManager = fileProviderManager
        }
        self.domain = domain

        NextcloudKit.configureLogger(logLevel: (NCBrandOptions.shared.disable_log ? .disabled : NCKeychain().log))

        nkLog(debug: "Start File Provider session " + version + " (File Provider Extension)")

        if let domain {
            for tableAccount in tblAccounts {
                guard let urlBase = NSURL(string: tableAccount.urlBase) else { continue }
                guard let host = urlBase.host else { continue }
                let accountDomain = tableAccount.userId + " (" + host + ")"
                if accountDomain == domain.identifier.rawValue {
                    let account = "\(tableAccount.user) \(tableAccount.urlBase)"
                    tblAccount = self.database.getTableAccount(account: account)
                    break
                }
            }
        }

        guard let tblAccount else {
            return nil
        }

        self.account = tblAccount.account

        // NextcloudKit Session
        NextcloudKit.shared.setup(groupIdentifier: NCBrandOptions.shared.capabilitiesGroup, delegate: NCNetworking.shared)
        NextcloudKit.shared.appendSession(account: tblAccount.account,
                                          urlBase: tblAccount.urlBase,
                                          user: tblAccount.user,
                                          userId: tblAccount.userId,
                                          password: NCKeychain().getPassword(account: tblAccount.account),
                                          userAgent: userAgent,
                                          httpMaximumConnectionsPerHost: NCBrandOptions.shared.httpMaximumConnectionsPerHost,
                                          httpMaximumConnectionsPerHostInDownload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInDownload,
                                          httpMaximumConnectionsPerHostInUpload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInUpload,
                                          groupIdentifier: NCBrandOptions.shared.capabilitiesGroup)

        return tblAccount
    }

    // MARK: -

    @discardableResult
    func signalEnumerator(ocId: String, type: TypeSignal) -> FileProviderItem? {
        guard let metadata = self.database.getMetadataFromOcId(ocId),
              let parentItemIdentifier = fileProviderUtility().getParentItemIdentifier(metadata: metadata) else {
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
            fileProviderManager.signalEnumerator(for: parentItemIdentifier) { _ in }
        }
        fileProviderManager.signalEnumerator(for: .workingSet) { _ in }

        return item
    }

    func signalEnumeratorAsync(ocId: String, type: TypeSignal) async {
        guard let metadata = await self.database.getMetadataFromOcIdAsync(ocId),
              let parentItemIdentifier = await fileProviderUtility().getParentItemIdentifierAsync(metadata: metadata) else {
            return
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
            try? await fileProviderManager.signalEnumerator(for: parentItemIdentifier)
        }
        try? await fileProviderManager.signalEnumerator(for: .workingSet)
    }

    // MARK: - DOWNLOAD

    func downloadComplete(metadata: tableMetadata, task: URLSessionTask, etag: String?, error: NKError) async {
        let ocId = metadata.ocId
        let taskIdentifier = task.taskIdentifier

        await self.database.setMetadataSessionAsync(ocId: ocId,
                                                    session: "",
                                                    sessionTaskIdentifier: 0,
                                                    sessionError: "",
                                                    status: self.global.metadataStatusNormal,
                                                    etag: etag)

        if error == .success {
            if let metadata = await self.database.getMetadataFromOcIdAsync(ocId) {
                await self.database.addLocalFileAsync(metadata: metadata)
            }
        }

        downloadPendingCompletionHandlers[taskIdentifier]?(nil)
        downloadPendingCompletionHandlers.removeValue(forKey: taskIdentifier)

        signalEnumerator(ocId: ocId, type: .update)
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
        guard let url = task.currentRequest?.url,
              let metadata = await self.database.getMetadataAsync(from: url, sessionTaskIdentifier: task.taskIdentifier) else {
            return
        }

        if let ocId, !metadata.ocIdTransfer.isEmpty {
            let atPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocIdTransfer)
            let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(ocId)
            self.utilityFileSystem.copyFile(atPath: atPath, toPath: toPath)
        }

        if error == .success, let ocId {
            // SIGNAL
            signalEnumerator(ocId: metadata.ocIdTransfer, type: .delete)

            if !metadata.ocIdTransfer.isEmpty, ocId != metadata.ocIdTransfer {
                await self.database.deleteMetadataOcIdAsync(metadata.ocIdTransfer)
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
            await self.database.addLocalFileAsync(metadata: metadata)

            // SIGNAL
            fileProviderData.shared.signalEnumerator(ocId: ocId, type: .update)

        } else {

            await self.database.deleteMetadataOcIdAsync(metadata.ocIdTransfer)

            // SIGNAL
            signalEnumerator(ocId: metadata.ocIdTransfer, type: .delete)
        }
    }
}
