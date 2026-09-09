// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022-2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import MessageUI
import LucidBanner
import SwiftUI

extension UIViewController {
    // https://stackoverflow.com/questions/6131205/how-to-find-topmost-view-controller-on-ios
    @objc func topMostViewController() -> UIViewController {
        // Handling Modal views
        if let presentedViewController = self.presentedViewController {
            return presentedViewController.topMostViewController()
        }
        // Handling UIViewController's added as subviews to some other views.
        else {
            for view in self.view.subviews {
                // Key property which most of us are unaware of / rarely use.
                if let subViewController = view.next {
                    if subViewController is UIViewController {
                        if let viewController = subViewController as? UIViewController {
                            return viewController.topMostViewController()
                        }
                    }
                }
            }
            return self
        }
    }

    // https://stackoverflow.com/questions/23620276/how-to-check-if-a-view-controller-is-presented-modally-or-pushed-on-a-navigation
    var isModal: Bool {
        if let index = navigationController?.viewControllers.firstIndex(of: self), index > 0 {
            return false
        } else if presentingViewController != nil {
            return true
        } else if navigationController?.presentingViewController?.presentedViewController == navigationController {
            return true
        } else if tabBarController?.presentingViewController is UITabBarController {
            return true
        } else {
            return false
        }
    }
    
    private struct Holder {
        static var loader: UIHostingController<NCLoadingAlert>?
    }
    
    func showLoader() {
        guard Holder.loader == nil else { return }
        
        let loader = UIHostingController(rootView: NCLoadingAlert())
        loader.view.frame = view.bounds
        loader.view.backgroundColor = .clear
        loader.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        addChild(loader)
        view.addSubview(loader.view)
        loader.didMove(toParent: self)
        
        Holder.loader = loader
    }
    
    func hideLoader() {
        guard let loader = Holder.loader else { return }
        loader.willMove(toParent: nil)
        loader.view.removeFromSuperview()
        loader.removeFromParent()
        Holder.loader = nil
    }
}

extension UIViewController: @retroactive MFMailComposeViewControllerDelegate {
    public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}
