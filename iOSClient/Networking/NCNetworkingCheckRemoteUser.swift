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

import Foundation
import NCCommunication

@objc class NCNetworkingCheckRemoteUser: NSObject {
    @objc public static let shared: NCNetworkingCheckRemoteUser = {
        let instance = NCNetworkingCheckRemoteUser()
        return instance
    }()
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var checkRemoteUserInProgress = false

    @objc func checkRemoteUser(account: String, function: String, errorCode: Int) {
           
        if self.checkRemoteUserInProgress {
            return;
        } else {
            self.checkRemoteUserInProgress = true;
        }
        
        let serverVersionMajor = NCManageDatabase.sharedInstance.getCapabilitiesServerInt(account: account, elements: NCElementsJSON.shared.capabilitiesVersionMajor)
        guard let tableAccount = NCManageDatabase.sharedInstance.getAccount(predicate: NSPredicate(format: "account == %@", account)) else { return }
        
        if serverVersionMajor >= k_nextcloud_version_17_0 {
            
            guard let token = CCUtility.getPassword(account) else { return }
            
            NCCommunication.shared.getRemoteWipeStatus(serverUrl: tableAccount.url, token: token, customUserAgent: nil, addCustomHeaders: nil, account: account) { (account, wipe, errorCode, errorDescriptiuon) in
                
                if wipe {
                    
                    self.appDelegate.deleteAccount(account, wipe: true)
                    NCContentPresenter.shared.messageNotification(tableAccount.user, description: "_wipe_account_", delay: TimeInterval(k_dismissAfterSecond*2), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError))
                    NCCommunication.shared.setRemoteWipeCompletition(serverUrl: tableAccount.url, token: token, customUserAgent: nil, addCustomHeaders: nil, account: account) { (account, errorCode, errorDescription) in
                        print("wipe");
                    }
                    
                } else {
                    
                    if UIApplication.shared.applicationState == .active && self.appDelegate.reachability.isReachable() {
                        let description = String.localizedStringWithFormat(NSLocalizedString("_error_check_remote_user_", comment: ""), tableAccount.user, tableAccount.url)
                        NCContentPresenter.shared.messageNotification("_error_", description: description, delay: TimeInterval(k_dismissAfterSecond*2), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                        CCUtility.setPassword(account, password: nil)
                    }
                }
            }
            
        } else if CCUtility.getPassword(account) != nil {
               
            if UIApplication.shared.applicationState == .active && appDelegate.reachability.isReachable() {
                let description = String.localizedStringWithFormat(NSLocalizedString("_error_check_remote_user_", comment: ""), tableAccount.user, tableAccount.url)
                NCContentPresenter.shared.messageNotification("_error_", description: description, delay: TimeInterval(k_dismissAfterSecond*2), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                CCUtility.setPassword(account, password: nil)
            }
        }
           
    }
}
