//
//  UITabBarController+Extension.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 02/08/2022.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
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

import Foundation
import UIKit

extension UITabBarController {

    // https://stackoverflow.com/questions/6131205/how-to-find-topmost-view-controller-on-ios
    override func topMostViewController() -> UIViewController {
        return self.selectedViewController!.topMostViewController()
    }

    func getSelectedTabIndex() -> Int? {
        // 1. Access the window through the scene delegate
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return nil
        }

        // 2. Identify the UITabBarController
        if let tabBarController = rootVC as? UITabBarController {
            return tabBarController.selectedIndex
        } else if let presentedTabBar = rootVC.presentedViewController as? UITabBarController {
            return presentedTabBar.selectedIndex
        }

        return nil
    }
}
