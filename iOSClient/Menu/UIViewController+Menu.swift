//
//  NCHovercard+Menu.swift
//  Nextcloud
//
//  Created by admin on 10.11.21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import Foundation
import SVGKit

extension UIViewController {
    func handleProfileAction(_ action: NCHovercard.Action, for userId: String) {
        
        switch action.appId {
        case "email":
            guard let url = action.hyperlinkUrl,
                  url.scheme == "mailto",
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                NCContentPresenter.shared.showGenericError(description: "_cannot_send_mail_error_")
                return
            }

            sendEmail(to: components.path)
        case "spreed":
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            if let talkUrl = URL(string: "nextcloudtalk://open-conversation?server=\(appDelegate.urlBase)&user=\(userId)&withUser=\(appDelegate.userId)"),
               UIApplication.shared.canOpenURL(talkUrl) {
                UIApplication.shared.open(talkUrl, options: [.universalLinksOnly: true])
            } else if let url = action.hyperlinkUrl {
                UIApplication.shared.open(url, options: [:])
            }
        default:
            guard let url = action.hyperlinkUrl, UIApplication.shared.canOpenURL(url) else {
                NCContentPresenter.shared.showGenericError(description: "_open_url_error")
                return
            }
            UIApplication.shared.open(url, options: [:])
        }
    }
    
    func showProfileMenu(userId: String) {

        NCCommunication.shared.getHovercard(for: userId) { (card, errCode, err) in
            guard let card = card else {
                return
            }
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let personHeader = NCMenuAction(
                title: card.displayName,
                icon: NCUtility.shared.loadUserImage(for: userId, displayName: card.displayName, urlBase: appDelegate.urlBase),
                action: nil)
            
            let actions = card.actions.map { action -> NCMenuAction in
                var image = UIImage()
                if let url = URL(string: action.icon), let svg = SVGKImage(contentsOf: url) {
                    image = svg.uiImage
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
            NCContentPresenter.shared.showGenericError(description: "_cannot_send_mail_error_")
            return
        }

        let mail = MFMailComposeViewController()
        mail.mailComposeDelegate = self
        mail.setToRecipients([email])

        present(mail, animated: true)
    }
    
    func presentMenu(with actions: [NCMenuAction]) {
        let menuViewController = NCMenu.makeNCMenu(with: actions)

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
