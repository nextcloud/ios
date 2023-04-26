//
//  NCNetworkingCheckRemoteUser.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 15/05/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//
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

        let serverVersionMajor = NCManageDatabase.shared.getCapabilitiesServerInt(account: account, elements: NCElementsJSON.shared.capabilitiesVersionMajor)
        guard let tableAccount = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", account)) else {
            return
        }

        // remove all process ----

        NCNetworking.shared.cancelAllTransfer(account: account) { }
        NCOperationQueue.shared.cancelAllQueue()
        NCNetworking.shared.cancelAllTask()

        // -----------------------

        if serverVersionMajor >= NCGlobal.shared.nextcloudVersion17 {

            let token = CCUtility.getPassword(account)!
            if token.isEmpty {
                return
            }

            NextcloudKit.shared.getRemoteWipeStatus(serverUrl: tableAccount.urlBase, token: token) { account, wipe, data, error in

                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                if wipe {

                    appDelegate.deleteAccount(account, wipe: true)
                    let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_wipe_account_")
                    NCContentPresenter.shared.messageNotification(tableAccount.user, error: error, delay: NCGlobal.shared.dismissAfterSecondLong, type: NCContentPresenter.messageType.error, priority: .max)
                    NextcloudKit.shared.setRemoteWipeCompletition(serverUrl: tableAccount.urlBase, token: token) { _, _ in print("wipe") }

                } else {

                    if UIApplication.shared.applicationState == .active && NextcloudKit.shared.isNetworkReachable() && !CCUtility.getPassword(account).isEmpty && !appDelegate.deletePasswordSession {
                        let description = String.localizedStringWithFormat(NSLocalizedString("_error_check_remote_user_", comment: ""), tableAccount.user, tableAccount.urlBase)
                        let error = NKError(errorCode: error.errorCode, errorDescription: description)
                        NCContentPresenter.shared.showError(error: error, priority: .max)
                        CCUtility.setPassword(account, password: nil)
                        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Password removed.")
                        appDelegate.deletePasswordSession = true
                    }
                }
            }

        } else if CCUtility.getPassword(account) != "" {

            if UIApplication.shared.applicationState == .active &&  NextcloudKit.shared.isNetworkReachable() {
                let description = String.localizedStringWithFormat(NSLocalizedString("_error_check_remote_user_", comment: ""), tableAccount.user, tableAccount.urlBase)
                let error = NKError(errorCode: error.errorCode, errorDescription: description)
                NCContentPresenter.shared.showError(error: error, priority: .max)
                CCUtility.setPassword(account, password: nil)
            }
        }
    }
}
