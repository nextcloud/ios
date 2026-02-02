//
//  UIViewController+Menu.swift
//  Nextcloud
//
//  Created by Henrik Storch on 10.11.21.
//  Copyright © 2021 Henrik Storch All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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
import MessageUI
import NextcloudKit

extension UIViewController {
    /// Creates a profile context menu for the given user
    /// Returns a UIMenu for use with button.menu
    func profileMenu(userId: String, session: NCSession.Session) -> UIMenu {
        return NCContextMenuProfile(
            userId: userId,
            session: session,
            viewController: self
        ).viewMenu()
    }

    func sendEmail(to email: String) {
        guard MFMailComposeViewController.canSendMail() else {
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_cannot_send_mail_error_")
            NCContentPresenter().showError(error: error)
            return
        }

        let mail = MFMailComposeViewController()
        mail.mailComposeDelegate = self
        mail.setToRecipients([email])

        present(mail, animated: true)
    }

    func presentMenu(with actions: [NCMenuAction], menuColor: UIColor = .systemBackground, textColor: UIColor = NCBrandColor.shared.textColor, controller: NCMainTabBarController? = nil, sender: Any?) {
        guard !actions.isEmpty else { return }
        let actions = actions.sorted(by: { $0.order < $1.order })
        guard let menuViewController = NCMenu.makeNCMenu(with: actions, menuColor: menuColor, textColor: textColor, controller: controller) else {
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_internal_generic_error_")
            NCContentPresenter().showError(error: error)
            return
        }

        let menuPanelController = NCMenuPanelController()
        menuPanelController.parentPresenter = self
        menuPanelController.delegate = menuViewController
        menuPanelController.set(contentViewController: menuViewController)
        menuPanelController.track(scrollView: menuViewController.tableView)

        present(menuPanelController, animated: true, completion: nil)
    }
}

extension UIViewController: @retroactive MFMailComposeViewControllerDelegate {
    public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}
