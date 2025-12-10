// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

public extension UIWindowScene {

    /// Returns the top-left coordinate of the UITabBar in this scene,
    /// expressed in the coordinate space of the scene's key window.
    ///
    /// If the scene does not host a UITabBarController as root,
    /// or no suitable window is found, the method returns `nil`.
    var tabBarTopLeft: CGPoint? {
        // Select key window if available, otherwise fallback to the first one.
        guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first,
              let tabBarController = window.rootViewController as? UITabBarController
        else {
            return nil
        }

        let tabBar = tabBarController.tabBar

        // Convert tab bar's bounds to the window coordinate space.
        let frameInWindow = tabBar.convert(tabBar.bounds, to: window)

        return CGPoint(x: frameInWindow.minX, y: frameInWindow.minY)
    }
}
