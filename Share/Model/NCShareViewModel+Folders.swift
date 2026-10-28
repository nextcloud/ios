// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

extension NCShareViewModel {
    func reloadData() async {
        let session = sessionStore.getSession()
        let folderUrl = serverUrl
        let layoutForView = NCManageDatabase.shared.getLayoutForView(account: session.account, key: keyLayout, serverUrl: folderUrl)
        let showHiddenFiles = NCPreferences().getShowHiddenFiles(account: session.account)
        let predicate = showHiddenFiles
            ? NSPredicate(
                format: "account == %@ AND serverUrl == %@ AND fileName != %@ AND directory == true",
                session.account,
                folderUrl,
                NextcloudKit.shared.nkCommonInstance.rootFileName
            )
            : NSPredicate(
                format: "account == %@ AND serverUrl == %@ AND fileName != %@ AND directory == true AND NOT fileName BEGINSWITH[c] %@",
                session.account,
                folderUrl,
                NextcloudKit.shared.nkCommonInstance.rootFileName,
                "."
            )

        let metadatas = await NCManageDatabase.shared.getMetadatasAsync(predicate: predicate,
                                                                        withLayout: layoutForView,
                                                                        withAccount: session.account)
        guard !Task.isCancelled, !isClosing, sessionStore.getSession().account == session.account,
              serverUrl == folderUrl else { return }
        folders = metadatas.map { metadata in
            NCShareFolderItem(
                id: metadata.ocId,
                name: metadata.fileNameView,
                image: metadata.e2eEncrypted
                    ? NCImageCache.shared.getFolderEncrypted(account: metadata.account)
                    : NCImageCache.shared.getFolder(account: metadata.account)
            )
        }
    }

    func didCreateFolder(_ notification: NSNotification) {
        Task {
            guard let userInfo = notification.userInfo as NSDictionary?,
                  let ocId = userInfo["ocId"] as? String,
                  let metadata = await NCManageDatabase.shared.getMetadataFromOcIdAsync(ocId)
            else { return }

            self.serverUrl += "/" + metadata.fileName
            await self.loadFolder()
            self.setNavigationBar(navigationTitle: metadata.fileNameView)
        }
    }

    func loadFolder() async {
        let session = sessionStore.getSession()
        let folderUrl = serverUrl
        isLoading = true
        defer {
            if sessionStore.getSession().account == session.account, serverUrl == folderUrl {
                isLoading = false
            }
        }
        let result = await NCNetworking.shared.readFolderAsync(serverUrl: folderUrl, account: session.account) { [weak self] task in
            Task { @MainActor [weak self] in
                guard let self, !self.isClosing, self.sessionStore.getSession().account == session.account,
                      self.serverUrl == folderUrl else {
                    task.cancel()
                    return
                }
                self.dataSourceTask = task
            }
        }
        guard !Task.isCancelled, !isClosing, sessionStore.getSession().account == session.account,
              serverUrl == folderUrl else { return }
        if result.error == .success {
            metadataFolder = result.metadataFolder
            await reloadData()
        } else {
            showAlert(description: result.error.errorDescription)
        }
    }
}

extension NCShareViewModel {
    func openFolder(_ folder: NCShareFolderItem) {
        guard isAuthenticated, !isClosing, !isSwitchingAccount, !isLoading, !isPreparingUpload else { return }
        let origin = serverUrl
        Task {
            guard let presenter else { return }
            guard let tblAccount = sessionStore.getTblAccoun(),
                  let metadata = await NCManageDatabase.shared.getMetadataFromOcIdAsync(folder.id) else {
                return self.showAlert(description: "_invalid_url_")
            }
            guard !Task.isCancelled, !isClosing, !isSwitchingAccount,
                  metadata.account == sessionStore.getSession().account, metadata.serverUrl == origin else { return }
            let serverUrl = self.utilityFileSystem.createServerUrl(serverUrl: metadata.serverUrl, fileName: metadata.fileName)

            if metadata.e2eEncrypted && !NCPreferences().isEndToEndEnabled(account: tblAccount.account) {
                self.showAlert(title: "_info_", description: "_e2e_goto_settings_for_enable_")
                return
            }
            let capabilities = await NKCapabilities.shared.getCapabilities(for: tblAccount.account)
            guard !Task.isCancelled, !isClosing, !isSwitchingAccount,
                  sessionStore.getSession().account == tblAccount.account, self.serverUrl == origin else { return }

            if let fileNameError = FileNameValidator.checkFileName(metadata.fileNameView, account: tblAccount.account, capabilities: capabilities) {
                let message = "\(fileNameError.errorDescription) \(NSLocalizedString("_please_rename_file_", comment: ""))"
                await UIAlertController.warningAsync(message: message, presenter: presenter)
                return
            }

            self.serverUrl = serverUrl
            self.setNavigationBar(navigationTitle: metadata.fileNameView)

            await self.reloadData()
            await self.loadFolder()
        }
    }
}
