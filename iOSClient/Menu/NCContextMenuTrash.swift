// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

/// A context menu for trash item actions (restore, delete).
/// See ``NCTrash`` for usage details.
class NCContextMenuTrash: NSObject {
    let objectId: String
    let utility = NCUtility()
    let trashController: NCTrash

    init(objectId: String, trashController: NCTrash) {
        self.objectId = objectId
        self.trashController = trashController
    }

    func viewMenu() -> UIMenu {
        var actions: [UIMenuElement] = []

        let restoreAction = UIAction(
            title: NSLocalizedString("_restore_", comment: ""),
            image: utility.loadImage(named: "arrow.counterclockwise", colors: [NCBrandColor.shared.iconImageColor])
        ) { [self] _ in
            Task {
                await trashController.restoreItem(with: objectId)
            }
        }
        actions.append(restoreAction)

        let deleteAction = UIAction(
            title: NSLocalizedString("_delete_", comment: ""),
            image: utility.loadImage(named: "trash", colors: [.red]),
            attributes: .destructive
        ) { [self] _ in
            Task {
                await trashController.deleteItems(with: [objectId])
            }
        }
        actions.append(deleteAction)

        return UIMenu(title: "", children: actions)
    }
}
