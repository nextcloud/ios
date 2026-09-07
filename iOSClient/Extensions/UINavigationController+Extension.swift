// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit

extension UINavigationController {

    // https://stackoverflow.com/questions/6131205/how-to-find-topmost-view-controller-on-ios
    override func topMostViewController() -> UIViewController {
        return self.visibleViewController!.topMostViewController()
    }

    func setNavigationBarAppearance(textColor: UIColor = NCBrandColor.shared.iconImageColor, backgroundColor: UIColor? = .systemBackground) {
        let appearance = UINavigationBarAppearance()

        if #available(iOS 26.0, *) {
            appearance.configureWithDefaultBackground()
        } else {
            appearance.configureWithTransparentBackground()
            if topViewController is NCMedia {
                // transparent
            } else {
                appearance.backgroundColor = backgroundColor
            }
            appearance.shadowColor = .clear
            appearance.shadowImage = UIImage()
        }
        appearance.titleTextAttributes = [.foregroundColor: textColor]

        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.compactScrollEdgeAppearance = appearance

        navigationBar.tintColor = textColor
        navigationBar.prefersLargeTitles = false
    }
    
    func setMediaAppreance() {
        setNavigationBarHidden(true, animated: false)
    }
    
    func popupFromNavigationStack(context: String) {
        guard let nav = currentNavigationController() else {
            return
        }
        nav.popViewController(animated: true)
    }

    func currentNavigationController() -> UINavigationController? {
        // Try to find the key window's root and traverse to the visible navigation controller
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        guard let root = keyWindow?.rootViewController else { return nil }
        return findNavigationController(from: root)
    }

    func findNavigationController(from vc: UIViewController) -> UINavigationController? {
        if let nav = vc as? UINavigationController { return nav }
        if let tab = vc as? UITabBarController {
            if let selected = tab.selectedViewController, let nav = findNavigationController(from: selected) { return nav }
        }
        if let presented = vc.presentedViewController, let nav = findNavigationController(from: presented) { return nav }
        for child in vc.children {
            if let nav = findNavigationController(from: child) { return nav }
        }
        return vc.navigationController
    }
}
