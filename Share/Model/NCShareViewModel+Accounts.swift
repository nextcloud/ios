// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit
import UIKit

extension NCShareViewModel {
    func loadAccounts() {
        guard isAuthenticated, !isClosing, !isLoading, !isPreparingUpload,
              !isLoadingAccounts, !isShowingInputError else { return }
        isLoadingAccounts = true
        accountsTask = Task { @MainActor in
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
            accountAvatars = Dictionary(uniqueKeysWithValues: storedAccounts.map { account in
                (account.account, utility.loadUserImage(for: account.user, displayName: account.displayName, urlBase: account.urlBase))
            })
            accounts = storedAccounts.map { account in
                let name = account.displayName.isEmpty ? account.user : account.displayName
                return NCShareAccountItem(
                    id: account.account,
                    name: account.alias.isEmpty ? name : name + " - " + account.alias,
                    user: account.user,
                    serverUrl: account.urlBase,
                    isSelected: account.account == selected)
            }.sorted { $0.isSelected && !$1.isSelected }
        }
    }

    func selectAccount(_ account: String) {
        guard isAuthenticated, !isClosing, !isPreparingUpload, !isSwitchingAccount,
              accounts.contains(where: { $0.id == account }) else { return }
        guard account != sessionStore.getSession().account else { return }
        changeAccount(account)
    }

    func cancelAccountLoading() {
        accountsTask?.cancel()
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
            loadAccounts()
            await loadServerCapabilities(account: account, changeID: changeID)
            guard !Task.isCancelled, !isClosing, accountChangeID == changeID else { return }
            if serverCapabilities != nil { await initializeFolderBrowser() }
        }
    }

    func retryCapabilities() {
        guard !isOffline, isAuthenticated, !isClosing, !isLoadingCapabilities, !isSwitchingAccount, !isPreparingUpload else { return }
        let account = sessionStore.getSession().account
        guard !account.isEmpty else { return }
        let changeID = accountChangeID
        capabilitiesTask = Task { @MainActor in
            await loadServerCapabilities(account: account, changeID: changeID)
            guard isCurrentCapabilitiesRequest(account: account, changeID: changeID), serverCapabilities != nil else { return }
            if folders.isEmpty { await initializeFolderBrowser() }
        }
    }

    private func loadServerCapabilities(account: String, changeID: UUID) async {
        isLoadingCapabilities = true
        serverCapabilities = nil
        capabilitiesErrorMessage = ""
        defer { if accountChangeID == changeID { isLoadingCapabilities = false } }
        // Prefer the actual cached response, rather than default capabilities.
        var capabilities = await NCManageDatabase.shared.getCapabilities(account: account)
        guard isCurrentCapabilitiesRequest(account: account, changeID: changeID) else { return }
        if capabilities == nil {
            guard !isOffline else { return }
            let result = await NextcloudKit.shared.getCapabilitiesAsync(account: account) { [weak self] task in
                Task { @MainActor [weak self] in
                    guard let self, !self.isClosing, self.accountChangeID == changeID else {
                        task.cancel()
                        return
                    }
                    self.capabilitiesRequest = task
                }
            }
            guard isCurrentCapabilitiesRequest(account: account, changeID: changeID) else { return }
            guard result.error == .success, let loaded = result.capabilities else {
                capabilitiesErrorMessage = NSLocalizedString("_share_capabilities_unavailable_", comment: "")
                return
            }
            if let data = result.responseData?.data {
                await NCManageDatabase.shared.setDataCapabilities(data: data, account: account)
            }
            guard isCurrentCapabilitiesRequest(account: account, changeID: changeID) else { return }
            capabilities = loaded
        }
        guard let capabilities else { return }
        // Keep legacy networking services and NextcloudKit in sync with this request.
        await NKCapabilities.shared.setCapabilities(for: account, capabilities: capabilities)
        guard isCurrentCapabilitiesRequest(account: account, changeID: changeID) else { return }
        NCNetworking.shared.capabilities[account] = capabilities
        serverCapabilities = capabilities
        NCBrandColor.shared.settingThemingColor(account: account, capabilities: capabilities)
    }

    private func isCurrentCapabilitiesRequest(account: String, changeID: UUID) -> Bool {
        !Task.isCancelled && !isClosing && accountChangeID == changeID && sessionStore.getSession().account == account
    }
}
