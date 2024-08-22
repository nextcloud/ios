//
//  NCNetworkingCheckRemoteUser.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 15/05/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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

import UIKit
import NextcloudKit

class NCNetworkingCheckRemoteUser {
    func checkRemoteUser(account: String, error: NKError) {
        let token = NCKeychain().getPassword(account: account)
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let tableAccount = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", account)),
              !token.isEmpty else { return }

        NCNetworking.shared.cancelAllTask()

        NextcloudKit.shared.getRemoteWipeStatus(serverUrl: tableAccount.urlBase, token: token, account: tableAccount.account) { account, wipe, _, error in
            var finalError: NKError?

            if wipe {
                appDelegate.deleteAccount(account) // delete account, don't delete database
                finalError = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_wipe_account_")
            } else if UIApplication.shared.applicationState == .active && NextcloudKit.shared.isNetworkReachable() {
                appDelegate.deleteAccount(account) // delete account, delete database
                finalError = NKError(errorCode: error.errorCode, errorDescription: "_error_check_remote_user_")
            }

            if let finalError {
                NCContentPresenter().messageNotification(tableAccount.user, error: finalError, delay: NCGlobal.shared.dismissAfterSecondLong, type: NCContentPresenter.messageType.error, priority: .max)
            }

            NextcloudKit.shared.setRemoteWipeCompletition(serverUrl: tableAccount.urlBase, token: token, account: tableAccount.account) { _, _ in print("wipe") }

            let accounts = NCManageDatabase.shared.getAccounts()

            if accounts?.count ?? 0 > 0, let newAccount = accounts?.first {
                appDelegate.changeAccount(newAccount, userProfile: nil) { }
            } else {
                appDelegate.openLogin(selector: NCGlobal.shared.introLogin, openLoginWeb: false)
            }
        }
    }
}
