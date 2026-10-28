// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit
import UIKit

extension NCShareViewModel {
    func showAccountPicker() {
        guard isAuthenticated, !isClosing, !isLoading, !isPreparingUpload,
              !isSwitchingAccount, !isLoadingAccounts, !isShowingAccounts, !isShowingInputError else { return }
        isLoadingAccounts = true
        accountPickerTask = Task { @MainActor in
            defer {
                isLoadingAccounts = false
                showInputErrorIfNeeded()
            }
            let selected = sessionStore.getSession().account
            let storedAccounts = await NCManageDatabase.shared.getAllAccountOrderAliasAsync()
            guard !Task.isCancelled, !isClosing, isAuthenticated,
                  sessionStore.getSession().account == selected else { return }
            guard !storedAccounts.isEmpty else {
                clearAccountView()
                showAlert(description: "_no_active_account_") { self.cancel(with: .noAccount) }
                return
            }
            accounts = storedAccounts.map { account in
                NCShareAccountItem(
                    id: account.account,
                    name: account.alias.isEmpty ? (account.displayName.isEmpty ? account.user : account.displayName) : account.alias,
                    user: account.user,
                    serverUrl: account.urlBase,
                    isSelected: account.account == selected)
            }.sorted { $0.isSelected && !$1.isSelected }
            if accounts.count > 1 { isShowingAccounts = true }
        }
    }

    func selectAccount(_ account: String) {
        guard isAuthenticated, !isClosing, !isPreparingUpload, !isSwitchingAccount,
              accounts.contains(where: { $0.id == account }) else { return }
        pendingAccountSelection = account == sessionStore.getSession().account ? nil : account
        isShowingAccounts = false
    }

    func dismissAccountPicker() {
        accountPickerTask?.cancel()
        pendingAccountSelection = nil
        isShowingAccounts = false
    }

    func accountPickerDismissed() {
        showInputErrorIfNeeded()
        let selected = pendingAccountSelection
        pendingAccountSelection = nil
        guard let selected, isAuthenticated, !isClosing, !isPreparingUpload else { return }
        changeAccount(selected)
    }

    func changeAccount(_ account: String) {
        guard !isClosing, !isPreparingUpload else { return }
        accountChangeTask?.cancel()
        let changeID = UUID()
        accountChangeID = changeID
        isSwitchingAccount = true
        clearAccountView()
        serverUrl = ""
        accountChangeTask = Task { @MainActor in
            defer { if accountChangeID == changeID { isSwitchingAccount = false } }
            let selectedSession = await sessionStore.setSessionAccount(account)
            guard !Task.isCancelled, !isClosing, accountChangeID == changeID else { return }
            guard let session = selectedSession,
                  let tblAccount = sessionStore.getTblAccoun(), tblAccount.account == account else {
                showAlert(description: "_no_active_account_") { self.cancel(with: .noAccount) }
                return
            }
            NextcloudKit.shared.setup(groupIdentifier: NCBrandOptions.shared.capabilitiesGroup, delegate: NCNetworking.shared)
            NextcloudKit.shared.appendSession(account: tblAccount.account,
                                              urlBase: tblAccount.urlBase,
                                              user: tblAccount.user,
                                              userId: tblAccount.userId,
                                              password: NCPreferences().getPassword(account: tblAccount.account),
                                              userAgent: userAgent,
                                              httpMaximumConnectionsPerHost: NCBrandOptions.shared.httpMaximumConnectionsPerHost,
                                              httpMaximumConnectionsPerHostInDownload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInDownload,
                                              httpMaximumConnectionsPerHostInUpload: NCBrandOptions.shared.httpMaximumConnectionsPerHostInUpload,
                                              groupIdentifier: NCBrandOptions.shared.capabilitiesGroup)
            autoUploadFileName = NCManageDatabase.shared.getAccountAutoUploadFileName(account: account)
            autoUploadDirectory = NCManageDatabase.shared.getAccountAutoUploadDirectory(
                account: account, urlBase: session.urlBase, userId: session.userId)
            serverUrl = utilityFileSystem.getHomeServer(session: session)
            setNavigationBar(navigationTitle: NCBrandOptions.shared.brand)
            showAccountView()
            await reloadData()
            guard !Task.isCancelled, !isClosing, accountChangeID == changeID else { return }
            await loadFolder()
        }
    }
}
