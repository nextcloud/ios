//
//  UINavigationController+Extension.swift
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

extension UINavigationController {

    // https://stackoverflow.com/questions/6131205/how-to-find-topmost-view-controller-on-ios
    override func topMostViewController() -> UIViewController {
        return self.visibleViewController!.topMostViewController()
    }

    func setNavigationBarAppearance() {
        let standardAppearance = UINavigationBarAppearance()

        standardAppearance.configureWithDefaultBackground()
        standardAppearance.largeTitleTextAttributes = [NSAttributedString.Key.foregroundColor: NCBrandColor.shared.textColor]
        standardAppearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NCBrandColor.shared.textColor]
        navigationBar.standardAppearance = standardAppearance

        let scrollEdgeAppearance = UINavigationBarAppearance()
        scrollEdgeAppearance.configureWithDefaultBackground()

        scrollEdgeAppearance.backgroundColor = .systemBackground
        scrollEdgeAppearance.shadowColor = .clear
        scrollEdgeAppearance.shadowImage = UIImage()

        navigationBar.scrollEdgeAppearance = scrollEdgeAppearance
        navigationBar.tintColor = NCBrandColor.shared.iconImageColor
    }

    func setGroupAppearance() {
        let standardAppearance = UINavigationBarAppearance()

        standardAppearance.configureWithDefaultBackground()
        standardAppearance.largeTitleTextAttributes = [NSAttributedString.Key.foregroundColor: NCBrandColor.shared.textColor]
        standardAppearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NCBrandColor.shared.textColor]
        standardAppearance.backgroundColor = .systemGray6
        navigationBar.standardAppearance = standardAppearance

        let scrollEdgeAppearance = UINavigationBarAppearance()
        scrollEdgeAppearance.configureWithDefaultBackground()

        scrollEdgeAppearance.backgroundColor = .systemGroupedBackground
        scrollEdgeAppearance.shadowColor = .clear
        scrollEdgeAppearance.shadowImage = UIImage()

        navigationBar.scrollEdgeAppearance = scrollEdgeAppearance
        navigationBar.tintColor = NCBrandColor.shared.iconImageColor
    }

    func setMediaAppreance() {

        setNavigationBarHidden(true, animated: false)
    }
}
