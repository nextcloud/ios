//
//  UITabBar+Extension.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 01/04/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import Foundation
import UIKit

extension UITabBar {
    func viewForItem(_ item: UITabBarItem) -> UIView? {
        guard let items = self.items,
              let index = items.firstIndex(of: item),
              let tabBarButtons = self.subviews.compactMap({ $0 as? UIControl }) as? [UIView],
              index < tabBarButtons.count else {
            return nil
        }
        return tabBarButtons[index]
    }
}
