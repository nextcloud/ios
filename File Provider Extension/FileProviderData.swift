// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import UniformTypeIdentifiers

class fileProviderData: NSObject {
    static let shared = fileProviderData()

    var fileProviderManager: NSFileProviderManager = NSFileProviderManager.default
    let utilityFileSystem = NCUtilityFileSystem()
    let global = NCGlobal.shared
    let database = NCManageDatabase.shared

    var fileProviderSignalDeleteContainerItemIdentifier: [NSFileProviderItemIdentifier: NSFileProviderItemIdentifier] = [:]
    var fileProviderSignalUpdateContainerItem: [NSFileProviderItemIdentifier: FileProviderItem] = [:]
    var fileProviderSignalDeleteWorkingSetItemIdentifier: [NSFileProviderItemIdentifier: NSFileProviderItemIdentifier] = [:]
    var fileProviderSignalUpdateWorkingSetItem: [NSFileProviderItemIdentifier: FileProviderItem] = [:]

    var listFavoriteIdentifierRank: [String: NSNumber] = [:]

    private var account: String = ""

    var downloadPendingCompletionHandlers: [Int: (Error?) -> Void] = [:]

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
        let tblAccount = self.database.getActiveTableAccount()

        NextcloudKit.configureLogger(logLevel: (NCBrandOptions.shared.disable_log ? .disabled : NCKeychain().log))

        nkLog(debug: "Start File Provider session " + version + " (File Provider Extension)")

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
            fileProviderData.shared.fileProviderSignalDeleteContainerItemIdentifier[item.itemIdentifier] = item.itemIdentifier
            fileProviderData.shared.fileProviderSignalDeleteWorkingSetItemIdentifier[item.itemIdentifier] = item.itemIdentifier
        }
        if type == .update {
            fileProviderData.shared.fileProviderSignalUpdateContainerItem[item.itemIdentifier] = item
            fileProviderData.shared.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
        }
        if type == .workingSet {
            fileProviderData.shared.fileProviderSignalUpdateWorkingSetItem[item.itemIdentifier] = item
        }
        if type == .delete || type == .update {
            fileProviderManager.signalEnumerator(for: parentItemIdentifier) { _ in }
        }
        fileProviderManager.signalEnumerator(for: .workingSet) { _ in }
        return item
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

        let identifier = fileProviderUtility().getItemIdentifier(ocId: metadata.ocId)
        try? await NSFileProviderManager.default.signalEnumerator(for: identifier)
        try? await NSFileProviderManager.default.signalEnumerator(for: .workingSet)
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
            self.utilityFileSystem.moveFile(atPath: atPath, toPath: toPath)
        }

        if error == .success, let ocId {
            fileProviderData.shared.signalEnumerator(ocId: metadata.ocIdTransfer, type: .delete)
            if !metadata.ocIdTransfer.isEmpty, ocId != metadata.ocIdTransfer {
                await self.database.deleteMetadataOcIdAsync(metadata.ocIdTransfer)
            }

            metadata.fileName = fileName
            metadata.serverUrl = serverUrl
            metadata.uploadDate = (date as? NSDate) ?? NSDate()
            metadata.etag = etag ?? ""
            metadata.ocId = ocId
            metadata.ocIdTransfer = ocId
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

            fileProviderData.shared.signalEnumerator(ocId: metadata.ocId, type: .update)

        } else {

            await self.database.deleteMetadataOcIdAsync(metadata.ocIdTransfer)

            fileProviderData.shared.signalEnumerator(ocId: metadata.ocIdTransfer, type: .delete)
        }
    }
}
