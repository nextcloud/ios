// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

class NCFavoriteNavigationController: NCMainNavigationController {
    override func createRightMenu() -> UIMenu? {
        guard let items = self.createMenuActions(),
              let collectionViewCommon
        else {
            return nil
        }

        if collectionViewCommon.layoutKey == global.layoutViewFavorite {
            return UIMenu(children: [items.select, items.viewStyleSubmenu, items.sortSubmenu])
        } else {
            let additionalSubmenu = UIMenu(title: "", options: .displayInline, children: [items.foldersOnTop, items.personalFilesOnlyAction, items.showDescription])
            return UIMenu(children: [items.select, items.viewStyleSubmenu, items.sortSubmenu, additionalSubmenu])
        }
    }
}
