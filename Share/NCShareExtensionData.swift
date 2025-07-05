// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

class NCShareExtensionData: NSObject {
    static let shared = NCShareExtensionData()

    private var tblAccount: tableAccount?

    override init() {
        self.tblAccount = NCManageDatabase.shared.getActiveTableAccount()
    }

    func setSessionAccount(_ account: String) async -> NCSession.Session {
        if account != self.tblAccount?.account,
           let tblAccount = await NCManageDatabase.shared.getTableAccountAsync(account: account) {
            self.tblAccount = tblAccount
        }

        return getSession()
    }

    func getSession() -> NCSession.Session {
        if let tblAccount {
            return NCSession.Session(account: tblAccount.account, urlBase: tblAccount.urlBase, user: tblAccount.user, userId: tblAccount.userId)
        } else {
            return NCSession.Session(account: "", urlBase: "", user: "", userId: "")
        }
    }

    func getTblAccoun() -> tableAccount? {
        return self.tblAccount
    }
}
