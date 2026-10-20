// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

final class NCGroupfoldersNavigationController: NCMainNavigationController {
    override func createOptionMenu() async -> UIMenu? {
        guard let collectionViewCommon,
              let items = await NCContextMenuNavigation().viewMenuOption(
                collectionViewCommon: collectionViewCommon,
                mainNavigationController: self,
                session: session
              ) else { return nil }

        if collectionViewCommon.layoutKey == global.layoutViewGroupfolders {
            return UIMenu(children: [items.select, items.viewStyleSubmenu, items.sortSubmenu])
        }
        // Folders opened from this section retain the regular file actions.
        if collectionViewCommon.layoutKey == global.layoutViewFiles {
            let additionalSettings = UIMenu(title: "", options: .displayInline, children: [items.showDescription])
            return UIMenu(children: [items.select, items.viewStyleSubmenu, items.sortSubmenu, additionalSettings])
        }
        return nil
    }
}
