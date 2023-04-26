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
import SVGKit
import NextcloudKit
import UIKit

extension UIViewController {
    fileprivate func handleProfileAction(_ action: NKHovercard.Action, for userId: String) {
        switch action.appId {
        case "email":
            guard
                let url = action.hyperlinkUrl,
                url.scheme == "mailto",
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            else {
                let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_cannot_send_mail_error_")
                NCContentPresenter.shared.showError(error: error)
                return
            }
            sendEmail(to: components.path)

        case "spreed":
            guard
                let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                let talkUrl = URL(string: "nextcloudtalk://open-conversation?server=\(appDelegate.urlBase)&user=\(appDelegate.userId)&withUser=\(userId)"),
                UIApplication.shared.canOpenURL(talkUrl)
            else { fallthrough /* default: open web link in browser */ }
            UIApplication.shared.open(talkUrl)

        default:
            guard let url = action.hyperlinkUrl, UIApplication.shared.canOpenURL(url) else {
                let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_open_url_error_")
                NCContentPresenter.shared.showError(error: error)
                return
            }
            UIApplication.shared.open(url, options: [:])
        }
    }

    func showProfileMenu(userId: String) {

        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let serverVersionMajor = NCManageDatabase.shared.getCapabilitiesServerInt(account: appDelegate.account, elements: NCElementsJSON.shared.capabilitiesVersionMajor)
        guard serverVersionMajor >= NCGlobal.shared.nextcloudVersion23 else { return }

        NextcloudKit.shared.getHovercard(for: userId) { account, card, _, _ in
            guard let card = card, account == appDelegate.account else { return }

            let personHeader = NCMenuAction(
                title: card.displayName,
                icon: NCUtility.shared.loadUserImage(
                    for: userId,
                       displayName: card.displayName,
                       userBaseUrl: appDelegate),
                action: nil)

            let actions = card.actions.map { action -> NCMenuAction in
                var image = NCUtility.shared.loadImage(named: "user", color: .label)
                if let url = URL(string: action.icon),
                   let svgSource = SVGKSourceURL.source(from: url),
                   let svg = SVGKImage(source: svgSource) {
                    image = svg.uiImage.withTintColor(.label, renderingMode: .alwaysOriginal)
                }
                return NCMenuAction(
                    title: action.title,
                    icon: image,
                    action: { _ in self.handleProfileAction(action, for: userId) })
            }

            let allActions = [personHeader] + actions
            self.presentMenu(with: allActions)
        }
    }

    func sendEmail(to email: String) {
        guard MFMailComposeViewController.canSendMail() else {
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_cannot_send_mail_error_")
            NCContentPresenter.shared.showError(error: error)
            return
        }

        let mail = MFMailComposeViewController()
        mail.mailComposeDelegate = self
        mail.setToRecipients([email])

        present(mail, animated: true)
    }

    func presentMenu(with actions: [NCMenuAction]) {
        guard !actions.isEmpty else { return }
        let actions = actions.sorted(by: { $0.order < $1.order })
        guard let menuViewController = NCMenu.makeNCMenu(with: actions) else {
            let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_internal_generic_error_")
            NCContentPresenter.shared.showError(error: error)
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

extension UIViewController: MFMailComposeViewControllerDelegate {
    public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}
