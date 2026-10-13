// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

final class NCTrashNavigationController: NCMainNavigationController {
    override func createOptionMenu() async -> UIMenu? {
        guard let trashViewController,
              let items = await NCContextMenuNavigation().viewMenuOption(
                trashViewController: trashViewController,
                mainNavigationController: self,
                session: session
              ) else { return nil }
        return UIMenu(children: items)
    }
}
