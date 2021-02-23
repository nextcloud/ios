//
//  NCChangeUserMenu.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 23/02/2021.
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

import FloatingPanel
import NCCommunication

class NCChangeUserMenu: NSObject {
    
    @objc func toggleMenu(viewController: UIViewController) {
        
        let mainMenuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateViewController(withIdentifier: "NCMainMenuTableViewController") as! NCMainMenuTableViewController
        mainMenuViewController.actions = self.initUsersMenu()

        let menuPanelController = NCMenuPanelController()
        menuPanelController.parentPresenter = viewController
        menuPanelController.delegate = mainMenuViewController
        menuPanelController.set(contentViewController: mainMenuViewController)
        menuPanelController.track(scrollView: mainMenuViewController.tableView)

        viewController.present(menuPanelController, animated: true, completion: nil)
    }
    
    private func initUsersMenu() -> [NCMenuAction] {
        
        var actions = [NCMenuAction]()
        let accounts = NCManageDatabase.shared.getAllAccount()
        var avatar = UIImage(named: "avatarCredentials")!.image(color: NCBrandColor.shared.icon, size: 50)
        
        for account in accounts {
            
            var fileNamePath = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(account.user, urlBase: account.urlBase) + "_" + account.user
            fileNamePath = fileNamePath + ".png"
            if var userImage = UIImage(contentsOfFile: fileNamePath) {
                userImage = userImage.resizeImage(size: CGSize(width: 50, height: 50), isAspectRation: true)!
                let userImageView = UIImageView(image: userImage)
                userImageView.avatar(roundness: 2, borderWidth: 1, borderColor: NCBrandColor.shared.avatarBorder, backgroundColor: .clear)
                UIGraphicsBeginImageContext(userImageView.bounds.size)
                userImageView.layer.render(in: UIGraphicsGetCurrentContext()!)
                if let newAvatar = UIGraphicsGetImageFromCurrentImageContext() {
                    avatar = newAvatar
                }
                UIGraphicsEndImageContext()
            }
            
            actions.append(
                NCMenuAction(
                    title: account.account,
                    icon: avatar,
                    onTitle: account.account,
                    onIcon: avatar,
                    selected: account.active == true,
                    on: account.active == true,
                    action: { menuAction in
                        
                    }
                )
            )
        }
       
        return actions
    }
}
