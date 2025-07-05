// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

class NCShareExtensionData: NSObject {
    static let shared = NCShareExtensionData()

    private var tblAccount: tableAccount?

    func getSession(account: String) -> NCSession.Session? {
        if account.isEmpty {
            tblAccount = NCManageDatabase.shared.getActiveTableAccount()
        } else if self.tblAccount == nil || self.tblAccount?.account != account {
            tblAccount = NCManageDatabase.shared.getTableAccount(account: account)
        }
        guard let tblAccount = self.tblAccount else {
            return nil
        }

        return NCSession.Session(account: tblAccount.account, urlBase: tblAccount.urlBase, user: tblAccount.user, userId: tblAccount.userId)
    }

    func getTblAccoun() -> tableAccount? {
        return self.tblAccount
    }
}
