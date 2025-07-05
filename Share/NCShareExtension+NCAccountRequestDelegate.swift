// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2021 Marino Faggiana
// SPDX-FileCopyrightText: 2021 Henrik Storch
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit
import UIKit

extension NCShareExtension: NCAccountRequestDelegate {

    // MARK: - Account

    func showAccountPicker() {
        Task {
            let accounts = await self.database.getAllAccountOrderAliasAsync()
            let session = self.extensionData.getSession()

            guard accounts.count > 1,
                  let vcAccountRequest = UIStoryboard(name: "NCAccountRequest", bundle: nil).instantiateInitialViewController() as? NCAccountRequest else {
                return
            }

            // Only here change the active account
            for account in accounts {
                account.active = account.account == session.account
            }

            vcAccountRequest.activeAccount = session.account
            vcAccountRequest.accounts = accounts.sorted { sorg, dest -> Bool in
                return sorg.active && !dest.active
            }
            vcAccountRequest.enableTimerProgress = false
            vcAccountRequest.enableAddAccount = false
            vcAccountRequest.delegate = self
            vcAccountRequest.dismissDidEnterBackground = true

            let screenHeighMax = UIScreen.main.bounds.height - (UIScreen.main.bounds.height / 5)
            let height = min(CGFloat(accounts.count * Int(vcAccountRequest.heightCell) + 45), screenHeighMax)

            let popup = NCPopupViewController(contentController: vcAccountRequest, popupWidth: 300, popupHeight: height + 20)

            self.present(popup, animated: true)

        }
    }

    func accountRequestAddAccount() { }

    func accountRequestChangeAccount(account: String, controller: UIViewController?) {
        Task {
            let session = await self.extensionData.setSessionAccount(account)
            guard let tblAccount = self.extensionData.getTblAccoun() else {
                cancel(with: NCShareExtensionError.noAccount)
                return
            }
            await self.database.applyCachedCapabilitiesAsync(account: account)

            // COLORS
            NCBrandColor.shared.settingThemingColor(account: account)

            // NETWORKING
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

            // get auto upload folder
            autoUploadFileName = self.database.getAccountAutoUploadFileName(account: account)
            autoUploadDirectory = self.database.getAccountAutoUploadDirectory(session: session)

            serverUrl = utilityFileSystem.getHomeServer(session: session)

            setNavigationBar(navigationTitle: NCBrandOptions.shared.brand)

            await reloadData()
            await loadFolder()
        }
    }
}

extension NCShareExtension: NCCreateFormUploadConflictDelegate {
    func dismissCreateFormUploadConflict(metadatas: [tableMetadata]?) {
        guard let metadatas = metadatas else {
            uploadStarted = false
            uploadMetadata.removeAll()
            return
        }

        self.uploadMetadata.append(contentsOf: metadatas)
        uploadStarted = true
        self.upload()
    }
}

extension NCShareExtension: NCShareCellDelegate {
    func showRenameFileDialog(named fileName: String, account: String) {
        let alert = UIAlertController.renameFile(fileName: fileName, account: account) { [self] newFileName in
            renameFile(oldName: fileName, newName: newFileName, account: account)
        }

        present(alert, animated: true)
    }

    func renameFile(oldName: String, newName: String, account: String) {
        guard let fileIx = self.filesName.firstIndex(of: oldName),
              !self.filesName.contains(newName),
              utilityFileSystem.moveFile(atPath: (NSTemporaryDirectory() + oldName), toPath: (NSTemporaryDirectory() + newName)) else {
            return showAlert(title: "_single_file_conflict_title_", description: "'\(oldName)' -> '\(newName)'")
        }

        filesName[fileIx] = newName
        tableView.reloadData()
    }

    func removeFile(named fileName: String) {
        guard let index = self.filesName.firstIndex(of: fileName) else {
            return showAlert(title: "_file_not_found_", description: fileName)
        }
        self.filesName.remove(at: index)
        if self.filesName.isEmpty {
            cancel(with: NCShareExtensionError.noFiles)
        } else {
            self.setCommandView()
        }
    }
}
