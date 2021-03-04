//
//  NCShareComments+Menu.swift
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
import NCCommunication

extension NCShareComments {

    func toggleMenu(with tableComments: tableComments?) {
        
        let menuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateInitialViewController() as! NCMenu
        var actions = [NCMenuAction]()

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_edit_comment_", comment: ""),
                icon: UIImage(named: "edit")!.image(color: NCBrandColor.shared.icon, size: 50),
                action: { menuAction in
                    guard let metadata = self.metadata else { return }
                    guard let tableComments = tableComments else { return }
                    
                    let alert = UIAlertController(title: NSLocalizedString("_edit_comment_", comment: ""), message: nil, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: nil))
                    
                    alert.addTextField(configurationHandler: { textField in
                        textField.placeholder = NSLocalizedString("_new_comment_", comment: "")
                    })
                    
                    alert.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { action in
                        if let message = alert.textFields?.first?.text {
                            if message != "" {
                                NCCommunication.shared.updateComments(fileId: metadata.fileId, messageId: tableComments.messageId, message: message) { (account, errorCode, errorDescription) in
                                    if errorCode == 0 {
                                        self.reloadData()
                                    } else {
                                        NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                                    }
                                }
                            }
                        }
                    }))
                    
                    self.present(alert, animated: true)
                }
            )
        )
        
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_delete_comment_", comment: ""),
                icon: UIImage(named: "trash")!.image(color: NCBrandColor.shared.icon, size: 50),
                action: { menuAction in
                    guard let metadata = self.metadata else { return }
                    guard let tableComments = tableComments else { return }

                    NCCommunication.shared.deleteComments(fileId: metadata.fileId, messageId: tableComments.messageId) { (account, errorCode, errorDescription) in
                        if errorCode == 0 {
                            self.reloadData()
                        } else {
                            NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                        }
                    }
                }
            )
        )
        
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_cancel_", comment: ""),
                icon: UIImage(named: "cancel")!.image(color: NCBrandColor.shared.icon, size: 50),
                action: { menuAction in
                }
            )
        )
        
        menuViewController.actions = actions

        let menuPanelController = NCMenuPanelController()
        menuPanelController.parentPresenter = self
        menuPanelController.delegate = menuViewController
        menuPanelController.set(contentViewController: menuViewController)
        menuPanelController.track(scrollView: menuViewController.tableView)
        self.present(menuPanelController, animated: true, completion: nil)
    }
}

