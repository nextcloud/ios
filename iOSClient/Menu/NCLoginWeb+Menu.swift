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

import FloatingPanel

extension NCLoginWeb {

    func toggleMenu() {
        
        let menuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateInitialViewController() as! NCMenu
        var actions = [NCMenuAction]()
        
        let accounts = NCManageDatabase.shared.getAllAccount()
        var avatar = NCUtility.shared.loadImage(named: "person.crop.circle")
        
        for account in accounts {
            
            let title = account.user + " " + (URL(string: account.urlBase)?.host ?? "")
            let fileNamePath = String(CCUtility.getDirectoryUserData()) + "/" + String(CCUtility.getStringUser(account.user, urlBase: account.urlBase)) + "-" + account.user + ".png"

            if let image = UIImage(contentsOfFile: fileNamePath) {
                avatar = NCUtility.shared.createAvatar(image: image, size: 50)
            }
            
            actions.append(
                NCMenuAction(
                    title: title,
                    icon: avatar,
                    onTitle: title,
                    onIcon: avatar,
                    selected: account.active == true,
                    on: account.active == true,
                    action: { menuAction in
                        if self.appDelegate.account != account.account {
                            NCManageDatabase.shared.setAccountActive(account.account)
                            self.dismiss(animated: true) {
                                self.appDelegate.settingAccount(account.account, urlBase: account.urlBase, user: account.user, userId: account.userId, password: CCUtility.getPassword(account.account))
                                self.appDelegate.initializeMain()
                            }
                        }
                    }
                )
            )
        }
       
        menuViewController.actions = actions

        let menuPanelController = NCMenuPanelController()
        menuPanelController.parentPresenter = self
        menuPanelController.delegate = menuViewController
        menuPanelController.set(contentViewController: menuViewController)
        menuPanelController.track(scrollView: menuViewController.tableView)

        self.present(menuPanelController, animated: true, completion: nil)
    }
}

