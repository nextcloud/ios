//
//  NCAccount.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 03/08/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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

import Foundation
import UIKit
import NextcloudKit

class NCAccount: NSObject {
    func createAccount(urlBase: String,
                       user: String,
                       password: String,
                       completion: @escaping (_ error: NKError) -> Void) {
        var urlBase = urlBase
        if urlBase.last == "/" { urlBase = String(urlBase.dropLast()) }
        let account: String = "\(user) \(urlBase)"

        NextcloudKit.shared.appendAccount(account,
                                          urlBase: urlBase,
                                          user: user,
                                          userId: user,
                                          password: password,
                                          userAgent: userAgent,
                                          nextcloudVersion: NCGlobal.shared.capabilityServerVersionMajor,
                                          groupIdentifier: NCBrandOptions.shared.capabilitiesGroup)

        NextcloudKit.shared.getUserProfile(account: account) { account, userProfile, _, error in
            if error == .success, let userProfile {
                NCManageDatabase.shared.addAccount(account, urlBase: urlBase, user: user, userId: userProfile.userId, password: password)
                NCKeychain().setClientCertificate(account: account, p12Data: NCNetworking.shared.p12Data, p12Password: NCNetworking.shared.p12Password)
                NextcloudKit.shared.updateAccount(account, userId: userProfile.userId)

                self.changeAccount(account, userProfile: userProfile) {
                    completion(error)
                }
            } else {
                NextcloudKit.shared.removeAccount(account)
                let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: error.errorDescription, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))
                UIApplication.shared.firstWindow?.rootViewController?.present(alertController, animated: true)
                completion(error)
            }
        }
    }

    func changeAccount(_ account: String,
                       userProfile: NKUserProfile?,
                       sceneIdentifier: String? = nil,
                       completion: () -> Void) {
        let previusActiveAccount = NCDomain.shared.getActiveDomain().account
        if NCManageDatabase.shared.setAccountActive(account) == nil {
            return completion()
        }

        /*
        NCNetworking.shared.cancelAllQueue()
        NCNetworking.shared.cancelDataTask()
        NCNetworking.shared.cancelDownloadTasks()
        NCNetworking.shared.cancelUploadTasks()
        */

        if account != previusActiveAccount {
            DispatchQueue.global().async {
                let domain = NCDomain.shared.getActiveDomain()
                if NCManageDatabase.shared.getAccounts()?.count == 1 {
                    NCImageCache.shared.createMediaCache(withCacheSize: true, domain: domain)
                } else {
                    NCImageCache.shared.createMediaCache(withCacheSize: false, domain: domain)
                }
            }
        }

        NCManageDatabase.shared.setCapabilities(account: account)
        NCDomain.shared.setSceneIdentifier(account: account, sceneIdentifier: sceneIdentifier)

        if let userProfile {
            NCManageDatabase.shared.setAccountUserProfile(account: account, userProfile: userProfile)
        }

        NCPushNotification.shared.pushNotification()
        NCService().startRequestServicesServer(account: account)

        NCAutoUpload.shared.initAutoUpload(viewController: nil) { items in
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Initialize Auto upload with \(items) uploads")
        }

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeUser)
        completion()
    }

    func deleteAccount(_ account: String) {
        UIApplication.shared.allSceneSessionDestructionExceptFirst()

        if let account = NCManageDatabase.shared.getAccount(predicate: NSPredicate(format: "account == %@", account)) {
            NCPushNotification.shared.unsubscribingNextcloudServerPushNotification(account: account.account, urlBase: account.urlBase, user: account.user, withSubscribing: false)
        }

        let results = NCManageDatabase.shared.getTableLocalFiles(predicate: NSPredicate(format: "account == %@", account), sorted: "ocId", ascending: false)
        let utilityFileSystem = NCUtilityFileSystem()
        for result in results {
            utilityFileSystem.removeFile(atPath: utilityFileSystem.getDirectoryProviderStorageOcId(result.ocId))
        }
        /// Remove account in all database
        NCManageDatabase.shared.clearDatabase(account: account, removeAccount: true)

        NCKeychain().clearAllKeysEndToEnd(account: account)
        NCKeychain().clearAllKeysPushNotification(account: account)
        NCKeychain().setPassword(account: account, password: nil)
    }

    func deleteAllAccounts() {
        let accounts = NCManageDatabase.shared.getAccounts()
        accounts?.forEach({ account in
            deleteAccount(account)
        })
    }

    func updateShareAccounts() -> Error? {
        guard let dirGroupApps = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroupApps) else { return nil }
        let tableAccount = NCManageDatabase.shared.getAllAccount()
        var accounts = [NKShareAccounts.DataAccounts]()

        for account in tableAccount {
            let name = account.alias.isEmpty ? account.displayName : account.alias
            let fileName = NCDomain.shared.getFileName(urlBase: account.urlBase, user: account.user)
            let fileNamePath = NCUtilityFileSystem().directoryUserData + "/" + fileName
            let image = UIImage(contentsOfFile: fileNamePath)
            accounts.append(NKShareAccounts.DataAccounts(withUrl: account.urlBase, user: account.user, name: name, image: image))
        }
        return NKShareAccounts().putShareAccounts(at: dirGroupApps, app: NCGlobal.shared.appScheme, dataAccounts: accounts)
    }
}
