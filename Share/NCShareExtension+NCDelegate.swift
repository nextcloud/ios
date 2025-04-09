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
        let accounts = NCManageDatabase.shared.getAllAccountOrderAlias()
        guard accounts.count > 1,
              let vcAccountRequest = UIStoryboard(name: "NCAccountRequest", bundle: nil).instantiateInitialViewController() as? NCAccountRequest else { return }

        // Only here change the active account
        for account in accounts {
            account.active = account.account == self.activeAccount.account
        }

        vcAccountRequest.activeAccount = self.activeAccount
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

    func accountRequestChangeAccount(account: String) {
        guard let activeAccount = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", account)) else {
            cancel(with: NCShareExtensionError.noAccount)
            return
        }
        self.activeAccount = activeAccount

        // CAPABILITIES
        NCManageDatabase.shared.setCapabilities(account: account)

        // COLORS
        NCBrandColor.shared.settingThemingColor(account: activeAccount.account)
        NCBrandColor.shared.createUserColors()
        NCImageCache.shared.createImagesBrandCache()

        // NETWORKING
        NextcloudKit.shared.setup(
            account: activeAccount.account,
            user: activeAccount.user,
            userId: activeAccount.userId,
            password: NCKeychain().getPassword(account: activeAccount.account),
            urlBase: activeAccount.urlBase,
            userAgent: userAgent,
            nextcloudVersion: 0,
            delegate: NCNetworking.shared)

        // get auto upload folder
        autoUploadFileName = NCManageDatabase.shared.getAccountAutoUploadFileName()
        autoUploadDirectory = NCManageDatabase.shared.getAccountAutoUploadDirectory(urlBase: activeAccount.urlBase, userId: activeAccount.userId, account: activeAccount.account)

        serverUrl = utilityFileSystem.getHomeServer(urlBase: activeAccount.urlBase, userId: activeAccount.userId)

        layoutForView = NCManageDatabase.shared.getLayoutForView(account: activeAccount.account, key: keyLayout, serverUrl: serverUrl)

        reloadDatasource(withLoadFolder: true)
        setNavigationBar(navigationTitle: NCBrandOptions.shared.brand)

        FileNameValidator.shared.setup(
            forbiddenFileNames: NCGlobal.shared.capabilityForbiddenFileNames,
            forbiddenFileNameBasenames: NCGlobal.shared.capabilityForbiddenFileNameBasenames,
            forbiddenFileNameCharacters: NCGlobal.shared.capabilityForbiddenFileNameCharacters,
            forbiddenFileNameExtensions: NCGlobal.shared.capabilityForbiddenFileNameExtensions
        )
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
        self.upload()
    }
}

extension NCShareExtension: NCShareCellDelegate {
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

    func renameFile(named fileName: String) {
        let alert = UIAlertController.renameFile(fileName: fileName) { [self] newFileName in
            guard let fileIx = self.filesName.firstIndex(of: fileName),
                  !self.filesName.contains(newFileName),
                  utilityFileSystem.moveFile(atPath: (NSTemporaryDirectory() + fileName), toPath: (NSTemporaryDirectory() + newFileName)) else {
                      return showAlert(title: "_single_file_conflict_title_", description: "'\(fileName)' -> '\(newFileName)'")
                  }

            filesName[fileIx] = newFileName
            tableView.reloadData()
        }

        present(alert, animated: true)
    }
}
