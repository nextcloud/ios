// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

@MainActor
final class NCShareSessionStore {
    private var tblAccount: tableAccount? = NCManageDatabase.shared.getActiveTableAccount()

    /// Selection belongs to this share request; do not change the app's active account.
    /// Re-read even the current account because it may have been removed by the app.
    func setSessionAccount(_ account: String) async -> NCSession.Session? {
        guard let selected = await NCManageDatabase.shared.getTableAccountAsync(account: account) else { return nil }
        guard !Task.isCancelled else { return nil }
        tblAccount = selected
        return getSession()
    }

    func getSession() -> NCSession.Session {
        if let tblAccount {
            return NCSession.Session(account: tblAccount.account, urlBase: tblAccount.urlBase, user: tblAccount.user, userId: tblAccount.userId)
        }
        return NCSession.Session(account: "", urlBase: "", user: "", userId: "")
    }

    func getTblAccoun() -> tableAccount? {
        tblAccount
    }
}
