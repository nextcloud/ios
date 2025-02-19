//
//  NCShareExtension.swift
//  Share
//
//  Created by Marino Faggiana on 04.01.2022.
//  Copyright © 2022 Henrik Storch. All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import NextcloudKit
import UIKit

extension NCShareExtension: NCAccountRequestDelegate {

    // MARK: - Account

    func showAccountPicker() {
        let accounts = self.database.getAllAccountOrderAlias()
        guard accounts.count > 1,
              let vcAccountRequest = UIStoryboard(name: "NCAccountRequest", bundle: nil).instantiateInitialViewController() as? NCAccountRequest else { return }

        // Only here change the active account
        for account in accounts {
            account.active = account.account == session.account
        }

        vcAccountRequest.activeAccount = self.session.account
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

    func accountRequestAddAccount() { }

    func accountRequestChangeAccount(account: String, controller: UIViewController?) {
        guard let tableAccount = self.database.getTableAccount(predicate: NSPredicate(format: "account == %@", account)),
              let capabilities = self.database.setCapabilities(account: account) else {
            cancel(with: NCShareExtensionError.noAccount)
            return
        }
        self.account = account

        // CAPABILITIES
        database.setCapabilities(account: account)

        // COLORS
        NCBrandColor.shared.settingThemingColor(account: account)
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeTheming, userInfo: ["account": account])

        // NETWORKING
        NextcloudKit.shared.setup(delegate: NCNetworking.shared)
        NextcloudKit.shared.appendSession(account: tableAccount.account,
                                          urlBase: tableAccount.urlBase,
                                          user: tableAccount.user,
                                          userId: tableAccount.userId,
                                          password: NCKeychain().getPassword(account: tableAccount.account),
                                          userAgent: userAgent,
                                          nextcloudVersion: capabilities.capabilityServerVersionMajor,
                                          httpMaximumConnectionsPerHost: NCBrandOptions.shared.httpMaximumConnectionsPerHost,
                                          httpMaximumConnectionsPerHostInDownload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInDownload,
                                          httpMaximumConnectionsPerHostInUpload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInUpload,
                                          groupIdentifier: NCBrandOptions.shared.capabilitiesGroup)

        // SESSION
        NCSession.shared.appendSession(account: tableAccount.account, urlBase: tableAccount.urlBase, user: tableAccount.user, userId: tableAccount.userId)

        // get auto upload folder
        autoUploadFileName = self.database.getAccountAutoUploadFileName()
        autoUploadDirectory = self.database.getAccountAutoUploadDirectory(session: session)

        serverUrl = utilityFileSystem.getHomeServer(session: session)

        reloadDatasource(withLoadFolder: true)
        setNavigationBar(navigationTitle: NCBrandOptions.shared.brand)
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
