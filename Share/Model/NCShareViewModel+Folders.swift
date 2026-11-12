// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

extension NCShareViewModel {
    /// Flattens expanded branches into rows; collapsed children stay cached.
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
        if let rootFolder { append(rootFolder, depth: 0) }
        return rows
    }

    func resetFolderBrowser(preservingContent: Bool = false) {
        folderBrowserID = UUID()
        folderSelectionTask?.cancel()
        for task in folderTasks.values { task.cancel() }
        for request in folderRequests.values { request.cancel() }
        folderTasks.removeAll()
        folderRequests.removeAll()
        // Keep the previous snapshot visible but disabled while the account changes.
        if !preservingContent {
            rootFolder = nil
            recentFolders = []
            selectedFolder = nil
            isRecentFolderSelected = false
            folderChildren = [:]
            expandedFolderURLs = []
        }
        folderScrollTarget = nil
        loadedFolderURLs = []
        folderLoadErrors = [:]
        isLoading = false
    }

    func initializeFolderBrowser(refreshFromServer: Bool = true) async {
        let session = sessionStore.getSession()
        let browserID = folderBrowserID
        let home = utilityFileSystem.getHomeServer(session: session)
        let root = NCShareFolderItem(
            ocId: "", name: NSLocalizedString("_share_home_folder_", comment: ""), serverUrl: home,
            path: "/", image: NCImageCache.shared.getFolder(account: session.account), isEncrypted: false)
        let recent = recentFoldersStore.folders(account: session.account).filter {
            $0.serverUrl == home || $0.serverUrl.hasPrefix(home + "/")
        }.map { item in
            NCShareFolderItem(
                ocId: item.ocId, name: item.name, serverUrl: item.serverUrl,
                path: folderPath(item.serverUrl, home: home),
                image: item.isEncrypted ? NCImageCache.shared.getFolderEncrypted(account: session.account) : NCImageCache.shared.getFolder(account: session.account),
                isEncrypted: item.isEncrypted)
        }
        let cached = await cachedFolderChildren(at: home, session: session)
        guard isCurrentBrowser(browserID, account: session.account) else { return }
        // Publish the replacement snapshot together, without an empty intermediate list.
        rootFolder = root
        selectedFolder = root
        isRecentFolderSelected = false
        expandedFolderURLs = [home]
        recentFolders = recent
        folderChildren = [home: cached]
        // Make cached destinations usable without waiting for the server refresh.
        if refreshFromServer { requestFolderChildren(root) }
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

    /// Keeps at most one listing request per folder, while allowing independent
    /// branches to load concurrently. Browser reset cancels all registered requests.
    func requestFolderChildren(_ folder: NCShareFolderItem, refresh: Bool = false) {
        guard !isOffline, !isClosing, folderTasks[folder.serverUrl] == nil,
              refresh || !loadedFolderURLs.contains(folder.serverUrl) else { return }
        let browserID = folderBrowserID
        // Mark synchronously, before scheduling, to prevent duplicate requests.
        folderTasks[folder.serverUrl] = Task { @MainActor in
            await loadFolderChildren(folder, browserID: browserID)
        }
    }

    /// Validates the destination on the server, then selects and expands it.
    /// fromRecents controls which of the two occurrences displays the checkmark.
    func selectFolder(_ folder: NCShareFolderItem, fromRecents: Bool = false) {
        guard canUseFolderBrowser, let capabilities = serverCapabilities, canAccessFolder(folder) else { return }
        let session = sessionStore.getSession()
        let browserID = folderBrowserID
        isLoading = true
        folderSelectionTask = Task { @MainActor in
            defer {
                if folderBrowserID == browserID { isLoading = false }
            }
            // Recent destinations may have been deleted or moved since last use.
            let result = await NCNetworking.shared.readFileAsync(serverUrlFileName: folder.serverUrl, account: session.account)
            guard isCurrentBrowser(browserID, account: session.account) else { return }
            guard result.error == .success, let metadata = result.metadata, metadata.directory else {
                if result.error.errorCode == NCGlobal.shared.errorResourceNotFound || result.error == .success {
                    recentFoldersStore.remove(serverUrl: folder.serverUrl, account: session.account)
                    recentFolders.removeAll { $0.serverUrl == folder.serverUrl }
                    if fromRecents { return }
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
            selectedFolder = selected
            isRecentFolderSelected = fromRecents
            expandedFolderURLs.insert(selected.serverUrl)
            requestFolderChildren(selected)
        }
    }

    var canUseFolderBrowser: Bool {
        isAuthenticated && !isClosing && isAccountReady && !isLoading && !isPreparingUpload && !isLoadingAccounts
    }

    private func canAccessFolder(_ folder: NCShareFolderItem) -> Bool {
        let session = sessionStore.getSession()
        let home = utilityFileSystem.getHomeServer(session: session)
        guard folder.serverUrl == home || folder.serverUrl.hasPrefix(home + "/") else { return false }
        if folder.isEncrypted && !NCPreferences().isEndToEndEnabled(account: session.account) {
            showAlert(description: "_e2e_goto_settings_for_enable_")
            return false
        }
        return true
    }

    func isCurrentBrowser(_ browserID: UUID, account: String) -> Bool {
        !Task.isCancelled && !isClosing && folderBrowserID == browserID && sessionStore.getSession().account == account
    }

    private func loadFolderChildren(_ folder: NCShareFolderItem, browserID: UUID) async {
        let session = sessionStore.getSession()
        guard isCurrentBrowser(browserID, account: session.account) else { return }
        folderLoadErrors[folder.serverUrl] = nil
        defer {
            if folderBrowserID == browserID {
                folderRequests[folder.serverUrl] = nil
                folderTasks[folder.serverUrl] = nil
            }
        }
        let result = await NextcloudKit.shared.readFileOrFolderAsync(
            serverUrlFileName: folder.serverUrl, depth: "1",
            showHiddenFiles: NCPreferences().getShowHiddenFiles(account: session.account), account: session.account
        ) { [weak self] task in
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
            folderLoadErrors[folder.serverUrl] = result.error.userFriendlyMessage()
            return
        }
        guard let files = result.files else {
            folderLoadErrors[folder.serverUrl] = NSLocalizedString("_share_folder_unavailable_", comment: "")
            return
        }
        // The destination browser needs only directories. Do not convert file
        // types or replace the app's complete metadata listing in the database.
        let directories = files.filter(\.directory)
        let listing = await NCManageDatabaseCreateMetadata().convertFilesToMetadatasAsync(
            directories, serverUrlMetadataFolder: folder.serverUrl)
        guard isCurrentBrowser(browserID, account: session.account) else { return }
        guard !listing.metadataFolder.ocId.isEmpty else {
            folderLoadErrors[folder.serverUrl] = NSLocalizedString("_share_folder_unavailable_", comment: "")
            return
        }
        let layout = NCManageDatabase.shared.getLayoutForView(account: session.account, key: NCGlobal.shared.layoutViewShareExtension, serverUrl: folder.serverUrl)
        let sorted = await NCManageDatabase.shared.sortedMetadata(layoutForView: layout, account: session.account, metadatas: listing.metadatas)
        guard isCurrentBrowser(browserID, account: session.account) else { return }
        folderChildren[folder.serverUrl] = folderSnapshots(sorted, parent: listing.metadataFolder, session: session)
        loadedFolderURLs.insert(folder.serverUrl)
        let metadata = listing.metadataFolder
        let updated = folderSnapshot(metadata, url: folder.serverUrl, parent: nil, session: session)
        if rootFolder?.serverUrl == folder.serverUrl { rootFolder = updated }
        if selectedFolder?.serverUrl == folder.serverUrl {
            selectedFolder = updated
        }
    }

    private func cachedFolderChildren(at url: String, session: NCSession.Session) async -> [NCShareFolderItem] {
        let layout = NCManageDatabase.shared.getLayoutForView(account: session.account, key: NCGlobal.shared.layoutViewShareExtension, serverUrl: url)
        let hidden = NCPreferences().getShowHiddenFiles(account: session.account)
        let predicate = hidden
            ? NSPredicate(format: "account == %@ AND serverUrl == %@ AND directory == true AND fileName != %@", session.account, url, NextcloudKit.shared.nkCommonInstance.rootFileName)
            : NSPredicate(format: "account == %@ AND serverUrl == %@ AND directory == true AND fileName != %@ AND NOT fileName BEGINSWITH[c] %@", session.account, url, NextcloudKit.shared.nkCommonInstance.rootFileName, ".")
        let metadatas = await NCManageDatabase.shared.getMetadatasAsync(predicate: predicate, withLayout: layout, withAccount: session.account)
        return folderSnapshots(metadatas, parent: nil, session: session)
    }

    private func folderSnapshots(_ metadatas: [tableMetadata], parent: tableMetadata?, session: NCSession.Session) -> [NCShareFolderItem] {
        let ordered = metadatas.filter(\.favorite) + metadatas.filter { !$0.favorite }
        return ordered.map { metadata in
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
            serverUrl: url, path: folderPath(url, home: home), image: image,
            isEncrypted: metadata.e2eEncrypted, isFavorite: metadata.favorite)
    }

    private func folderPath(_ url: String, home: String) -> String {
        let path = url.hasPrefix(home) ? String(url.dropFirst(home.count)) : url
        return path.isEmpty ? "/" : (path.removingPercentEncoding ?? path)
    }
}
