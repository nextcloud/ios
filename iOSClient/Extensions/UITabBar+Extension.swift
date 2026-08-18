// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

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
