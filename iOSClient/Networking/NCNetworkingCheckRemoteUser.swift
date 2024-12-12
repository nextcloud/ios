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
    func checkRemoteUser(account: String, controller: NCMainTabBarController?, error: NKError) {
        let token = NCKeychain().getPassword(account: account)
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let tableAccount = NCManageDatabase.shared.getTableAccount(predicate: NSPredicate(format: "account == %@", account)),
              !token.isEmpty else { return }
        let titleNotification = String(format: NSLocalizedString("_account_unauthorized_", comment: ""), account)

        if UIApplication.shared.applicationState == .active && NextcloudKit.shared.isNetworkReachable() {

            NCContentPresenter().messageNotification(titleNotification, error: error, delay: NCGlobal.shared.dismissAfterSecondLong, type: NCContentPresenter.messageType.error, priority: .max)

            NextcloudKit.shared.getRemoteWipeStatus(serverUrl: tableAccount.urlBase, token: token, account: tableAccount.account) { account, wipe, _, error in
                NCAccount().deleteAccount(account, wipe: wipe)
                if wipe {
                    NextcloudKit.shared.setRemoteWipeCompletition(serverUrl: tableAccount.urlBase, token: token, account: tableAccount.account) { _, _, error in
                        NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Set Remote Wipe Completition error code: \(error.errorCode)")
                    }
                }

                if let accounts = NCManageDatabase.shared.getAccounts(),
                   account.count > 0,
                   let account = accounts.first {
                    NCAccount().changeAccount(account, userProfile: nil, controller: controller) { }
                } else {
                    appDelegate.openLogin(selector: NCGlobal.shared.introLogin)
                }
            }
        }
    }
}
