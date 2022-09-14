//
//  NCAppConfigView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 18/09/2019.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
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

class NCAppConfigView: UIViewController {

    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    private var serverUrl: String?
    private var username: String?
    private var password: String?

    @IBOutlet weak var logoImage: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = NCBrandColor.shared.brandElement
        titleLabel.textColor = NCBrandColor.shared.brandText

        titleLabel.text = NSLocalizedString("_appconfig_view_title_", comment: "")

        if let serverConfig = UserDefaults.standard.dictionary(forKey: NCBrandConfiguration.shared.configuration_bundleId) {
            serverUrl = serverConfig[NCBrandConfiguration.shared.configuration_serverUrl] as? String
            username = serverConfig[NCBrandConfiguration.shared.configuration_username] as? String
            password = serverConfig[NCBrandConfiguration.shared.configuration_password] as? String
        } else {
            serverUrl = UserDefaults.standard.string(forKey: NCBrandConfiguration.shared.configuration_serverUrl)
            username = UserDefaults.standard.string(forKey: NCBrandConfiguration.shared.configuration_username)
            password = UserDefaults.standard.string(forKey: NCBrandConfiguration.shared.configuration_password)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Stop timer error network
        appDelegate.timerErrorNetworking?.invalidate()

        guard let serverUrl = self.serverUrl else {
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "User Default, serverUrl not found")
            NCContentPresenter.shared.showError(error: error)
            return
        }
        guard let username = self.username else {
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "User Default, username not found")
            NCContentPresenter.shared.showError(error: error)
            return
        }
        guard let password = self.password else {
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "User Default, password not found")
            NCContentPresenter.shared.showError(error: error)
            return
        }

        NextcloudKit.shared.getAppPassword(serverUrl: serverUrl, username: username, password: password, userAgent: nil) { token, data, error in
            DispatchQueue.main.async {
                if error == .success && token != nil {
                    let account: String = "\(username) \(serverUrl)"

                    // NO account found, clear
                    if NCManageDatabase.shared.getAccounts() == nil { NCUtility.shared.removeAllSettings() }

                    // Add new account
                    NCManageDatabase.shared.deleteAccount(account)
                    NCManageDatabase.shared.addAccount(account, urlBase: serverUrl, user: username, password: token!)

                    guard let tableAccount = NCManageDatabase.shared.setAccountActive(account) else {
                        let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "setAccountActive error")
                        NCContentPresenter.shared.showError(error: error)
                        self.dismiss(animated: true, completion: nil)
                        return
                    }

                    self.appDelegate.settingAccount(account, urlBase: serverUrl, user: username, userId: tableAccount.userId, password: token!)
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterInitialize)

                    self.dismiss(animated: true) {}
                } else {
                    NCContentPresenter.shared.showError(error: error)
                }
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // Start timer error network
        appDelegate.startTimerErrorNetworking()
    }
}
