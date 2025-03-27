// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

class NCFavoriteNavigationController: NCMainNavigationController {

    // MARK: - Right

    override func createRightMenu() -> UIMenu? {
        guard let items = self.createRightMenuActions(),
              let collectionViewCommon
        else {
            return nil
        }

        if collectionViewCommon.layoutKey == global.layoutViewFavorite {
            return UIMenu(children: [items.select, items.viewStyleSubmenu, items.sortSubmenu])
        } else {
            let additionalSubmenu = UIMenu(title: "", options: .displayInline, children: [items.showDescription])
            return UIMenu(children: [items.select, items.viewStyleSubmenu, items.sortSubmenu, additionalSubmenu])
        }
    }
}
