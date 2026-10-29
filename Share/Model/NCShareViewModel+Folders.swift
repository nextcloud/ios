// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

extension NCShareViewModel {
    var visibleFolderRows: [NCShareFolderRow] {
        var rows: [NCShareFolderRow] = []
        var visited: Set<String> = []
        func append(_ folder: NCShareFolderItem, depth: Int) {
            guard visited.insert(folder.serverUrl).inserted else { return }
            rows.append(NCShareFolderRow(folder: folder, depth: depth))
            if expandedFolderURLs.contains(folder.serverUrl) {
                for child in folderChildren[folder.serverUrl] ?? [] { append(child, depth: depth + 1) }
            }
        }
        for folder in folders { append(folder, depth: 0) }
        return rows
    }

    func resetFolderBrowser() {
        folderBrowserID = UUID()
        folderSelectionTask?.cancel()
        for task in folderTasks.values { task.cancel() }
        for request in folderRequests.values { request.cancel() }
        folderTasks.removeAll()
        folderRequests.removeAll()
        folders = []
        recentFolders = []
        selectedFolder = nil
        folderChildren = [:]
        expandedFolderURLs = []
        loadingFolderURLs = []
        loadedFolderURLs = []
        folderLoadErrors = [:]
        isLoading = false
    }

    func initializeFolderBrowser() async {
        let session = sessionStore.getSession()
        let browserID = folderBrowserID
        let home = utilityFileSystem.getHomeServer(session: session)
        let root = NCShareFolderItem(
            ocId: "", name: NSLocalizedString("_share_home_folder_", comment: ""), serverUrl: home,
            path: "/", image: NCImageCache.shared.getFolder(account: session.account), isEncrypted: false)
        folders = [root]
        selectedFolder = root
        expandedFolderURLs = [home]
        recentFolders = recentFoldersStore.folders(account: session.account).filter {
            $0.serverUrl == home || $0.serverUrl.hasPrefix(home + "/")
        }.map { item in
            NCShareFolderItem(
                ocId: item.ocId, name: item.name, serverUrl: item.serverUrl,
                path: folderPath(item.serverUrl, home: home),
                image: item.isEncrypted ? NCImageCache.shared.getFolderEncrypted(account: session.account) : NCImageCache.shared.getFolder(account: session.account),
                isEncrypted: item.isEncrypted)
        }
        isLoading = true
        defer { if folderBrowserID == browserID { isLoading = false } }
        let cached = await cachedFolderChildren(at: home, parent: nil, session: session)
        guard isCurrentBrowser(browserID, account: session.account) else { return }
        folderChildren[home] = cached
        await loadFolderChildren(root, browserID: browserID)
    }

    func toggleFolder(_ folder: NCShareFolderItem) {
        guard canUseFolderBrowser, canAccessFolder(folder) else { return }
        if expandedFolderURLs.contains(folder.serverUrl) {
            expandedFolderURLs.remove(folder.serverUrl)
        } else {
            expandedFolderURLs.insert(folder.serverUrl)
            if !loadedFolderURLs.contains(folder.serverUrl) { requestFolderChildren(folder) }
        }
    }

    func retryFolder(_ folder: NCShareFolderItem) {
        guard canUseFolderBrowser, canAccessFolder(folder) else { return }
        expandedFolderURLs.insert(folder.serverUrl)
        requestFolderChildren(folder, refresh: true)
    }

    func requestFolderChildren(_ folder: NCShareFolderItem, refresh: Bool = false) {
        guard !isClosing, !loadingFolderURLs.contains(folder.serverUrl),
              refresh || !loadedFolderURLs.contains(folder.serverUrl) else { return }
        let browserID = folderBrowserID
        // Mark synchronously, before scheduling, to prevent duplicate requests.
        loadingFolderURLs.insert(folder.serverUrl)
        folderTasks[folder.serverUrl] = Task { @MainActor in
            await loadFolderChildren(folder, browserID: browserID)
        }
    }

    func selectFolder(_ folder: NCShareFolderItem) {
        guard canUseFolderBrowser, let capabilities = serverCapabilities, canAccessFolder(folder) else { return }
        let session = sessionStore.getSession()
        let browserID = folderBrowserID
        isLoading = true
        folderSelectionTask = Task { @MainActor in
            defer { if folderBrowserID == browserID { isLoading = false } }
            // Recent destinations may have been deleted or moved since last use.
            let result = await NCNetworking.shared.readFileAsync(serverUrlFileName: folder.serverUrl, account: session.account)
            guard isCurrentBrowser(browserID, account: session.account) else { return }
            guard result.error == .success, let metadata = result.metadata, metadata.directory else {
                if result.error.errorCode == NCGlobal.shared.errorResourceNotFound || result.error == .success {
                    recentFoldersStore.remove(serverUrl: folder.serverUrl, account: session.account)
                    recentFolders.removeAll { $0.serverUrl == folder.serverUrl }
                }
                showAlert(description: result.error == .success ? "_share_folder_unavailable_" : result.error.errorDescription)
                return
            }
            let selected = folderSnapshot(metadata, url: folder.serverUrl, parent: nil, session: session)
            guard canAccessFolder(selected) else { return }
            guard isCurrentBrowser(browserID, account: session.account), isAuthenticated else { return }
            let home = utilityFileSystem.getHomeServer(session: session)
            if folder.serverUrl != home,
               let error = FileNameValidator.checkFileName(metadata.fileNameView, account: session.account, capabilities: capabilities) {
                showAlert(description: error.errorDescription)
                return
            }
            serverUrl = folder.serverUrl
            metadataFolder = metadata
            selectedFolder = selected
            setNavigationBar(navigationTitle: selected.name)
        }
    }

    func recordRecentDestination() {
        guard let uploaded = uploadMetadata.first, let folder = selectedFolder,
              uploaded.serverUrl == folder.serverUrl else { return }
        recentFoldersStore.record(.init(
            serverUrl: folder.serverUrl, name: folder.name, ocId: folder.ocId, isEncrypted: folder.isEncrypted),
            account: uploaded.account)
    }

    private var canUseFolderBrowser: Bool {
        isAuthenticated && !isClosing && isAccountReady && !isLoading && !isPreparingUpload && !isLoadingAccounts
    }

    private func canAccessFolder(_ folder: NCShareFolderItem) -> Bool {
        let session = sessionStore.getSession()
        let home = utilityFileSystem.getHomeServer(session: session)
        guard folder.serverUrl == home || folder.serverUrl.hasPrefix(home + "/") else { return false }
        if folder.isEncrypted && !NCPreferences().isEndToEndEnabled(account: session.account) {
            showAlert(title: "_info_", description: "_e2e_goto_settings_for_enable_")
            return false
        }
        return true
    }

    private func isCurrentBrowser(_ browserID: UUID, account: String) -> Bool {
        !Task.isCancelled && !isClosing && folderBrowserID == browserID && sessionStore.getSession().account == account
    }

    private func loadFolderChildren(_ folder: NCShareFolderItem, browserID: UUID) async {
        let session = sessionStore.getSession()
        guard isCurrentBrowser(browserID, account: session.account) else { return }
        loadingFolderURLs.insert(folder.serverUrl)
        folderLoadErrors[folder.serverUrl] = nil
        defer {
            if folderBrowserID == browserID {
                loadingFolderURLs.remove(folder.serverUrl)
                folderRequests[folder.serverUrl] = nil
                folderTasks[folder.serverUrl] = nil
            }
        }
        let result = await NCNetworking.shared.readFolderAsync(serverUrl: folder.serverUrl, account: session.account) { [weak self] task in
            Task { @MainActor [weak self] in
                guard let self, self.folderBrowserID == browserID, !self.isClosing else {
                    task.cancel()
                    return
                }
                self.folderRequests[folder.serverUrl] = task
            }
        }
        guard isCurrentBrowser(browserID, account: session.account) else { return }
        guard result.error == .success else {
            folderLoadErrors[folder.serverUrl] = result.error.errorDescription
            return
        }
        let children = await cachedFolderChildren(at: folder.serverUrl, parent: result.metadataFolder, session: session)
        guard isCurrentBrowser(browserID, account: session.account) else { return }
        folderChildren[folder.serverUrl] = children
        loadedFolderURLs.insert(folder.serverUrl)
        if let metadata = result.metadataFolder {
            let updated = folderSnapshot(metadata, url: folder.serverUrl, parent: nil, session: session)
            if folders.first?.serverUrl == folder.serverUrl { folders = [updated] }
            if selectedFolder?.serverUrl == folder.serverUrl {
                metadataFolder = metadata
                selectedFolder = updated
            }
        }
    }

    private func cachedFolderChildren(at url: String, parent: tableMetadata?, session: NCSession.Session) async -> [NCShareFolderItem] {
        let layout = NCManageDatabase.shared.getLayoutForView(account: session.account, key: keyLayout, serverUrl: url)
        let hidden = NCPreferences().getShowHiddenFiles(account: session.account)
        let predicate = hidden
            ? NSPredicate(format: "account == %@ AND serverUrl == %@ AND directory == true AND fileName != %@", session.account, url, NextcloudKit.shared.nkCommonInstance.rootFileName)
            : NSPredicate(format: "account == %@ AND serverUrl == %@ AND directory == true AND fileName != %@ AND NOT fileName BEGINSWITH[c] %@", session.account, url, NextcloudKit.shared.nkCommonInstance.rootFileName, ".")
        let metadatas = await NCManageDatabase.shared.getMetadatasAsync(predicate: predicate, withLayout: layout, withAccount: session.account)
        return metadatas.map { metadata in
            let childUrl = utilityFileSystem.createServerUrl(serverUrl: metadata.serverUrl, fileName: metadata.fileName)
            return folderSnapshot(metadata, url: childUrl, parent: parent, session: session)
        }
    }

    private func folderSnapshot(_ metadata: tableMetadata, url: String, parent: tableMetadata?, session: NCSession.Session) -> NCShareFolderItem {
        let home = utilityFileSystem.getHomeServer(session: session)
        let image: UIImage
        let shared = parent.map { metadata.permissions.contains(NCMetadataPermissions.permissionShared) && !$0.permissions.contains(NCMetadataPermissions.permissionShared) } ?? false
        let mounted = parent.map { metadata.permissions.contains(NCMetadataPermissions.permissionMounted) && !$0.permissions.contains(NCMetadataPermissions.permissionMounted) } ?? false
        if metadata.e2eEncrypted {
            image = NCImageCache.shared.getFolderEncrypted(account: session.account)
        } else if shared {
            image = NCImageCache.shared.getFolderSharedWithMe(account: session.account)
        } else if !metadata.shareType.isEmpty {
            image = metadata.shareType.contains(3) ? NCImageCache.shared.getFolderPublic(account: session.account) : NCImageCache.shared.getFolderSharedWithMe(account: session.account)
        } else if metadata.mountType == "group" {
            image = NCImageCache.shared.getFolderGroup(account: session.account)
        } else if mounted {
            image = NCImageCache.shared.getFolderExternal(account: session.account)
        } else if metadata.fileName == autoUploadFileName && metadata.serverUrl == autoUploadDirectory {
            image = NCImageCache.shared.getFolderAutomaticUpload(account: session.account)
        } else {
            image = NCImageCache.shared.getFolder(account: session.account)
        }
        return NCShareFolderItem(
            ocId: metadata.ocId, name: url == home ? NSLocalizedString("_share_home_folder_", comment: "") : metadata.fileNameView,
            serverUrl: url, path: folderPath(url, home: home), image: image, isEncrypted: metadata.e2eEncrypted)
    }

    private func folderPath(_ url: String, home: String) -> String {
        let path = url.hasPrefix(home) ? String(url.dropFirst(home.count)) : url
        return path.isEmpty ? "/" : (path.removingPercentEncoding ?? path)
    }
}
