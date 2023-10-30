//
//  NCLoginWeb+Menu.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 03/03/2021.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
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
import FloatingPanel

extension NCLoginWeb {

    func toggleMenu() {

        var actions = [NCMenuAction]()

        let accounts = NCManageDatabase.shared.getAllAccount()
        var avatar = utility.loadImage(named: "person.crop.circle")

        for account in accounts {

            let title = account.user + " " + (URL(string: account.urlBase)?.host ?? "")

            avatar = utility.loadUserImage(
                for: account.user,
                   displayName: account.displayName,
                   userBaseUrl: account)

            actions.append(
                NCMenuAction(
                    title: title,
                    icon: avatar,
                    onTitle: title,
                    onIcon: avatar,
                    selected: account.active == true,
                    on: account.active == true,
                    action: { _ in
                        if self.appDelegate.account != account.account {
                            self.dismiss(animated: true) {
                                self.appDelegate.changeAccount(account.account, userProfile: nil)
                            }
                        }
                    }
                )
            )
        }

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_delete_active_account_", comment: ""),
                icon: utility.loadImage(named: "trash", color: UIColor.systemGray),
                onTitle: NSLocalizedString("_delete_active_account_", comment: ""),
                onIcon: avatar,
                selected: false,
                on: false,
                action: { _ in
                    self.appDelegate.deleteAccount(self.appDelegate.account, wipe: false)
                    self.dismiss(animated: true) {
                        let accounts = NCManageDatabase.shared.getAllAccount()
                        if accounts.isEmpty {
                            self.appDelegate.openLogin(viewController: nil, selector: NCGlobal.shared.introLogin, openLoginWeb: false)
                        } else {
                            self.appDelegate.changeAccount(accounts.first!.account, userProfile: nil)
                        }
                    }
                }
            )
        )

        presentMenu(with: actions)
    }
}
