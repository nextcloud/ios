//
//  NCTrash+Menu.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 03/03/2021.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//  Copyright © 2022 Henrik Storch. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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

import UIKit
import NextcloudKit

class NCContextMenuTrash: NSObject {
    let objectId: String
    let utility = NCUtility()
    weak var trashController: NCTrash?

    init(objectId: String, trashController: NCTrash?) {
        self.objectId = objectId
        self.trashController = trashController
    }

    func viewMenu() -> UIMenu {
        var actions: [UIMenuElement] = []

        let restoreAction = UIAction(
            title: NSLocalizedString("_restore_", comment: ""),
            image: utility.loadImage(named: "arrow.counterclockwise", colors: [NCBrandColor.shared.iconImageColor])
        ) { [weak self] _ in
            guard let self, let controller = self.trashController else { return }
            Task {
                await controller.restoreItem(with: self.objectId)
            }
        }
        actions.append(restoreAction)

        let deleteAction = UIAction(
            title: NSLocalizedString("_delete_", comment: ""),
            image: utility.loadImage(named: "trash", colors: [.red]),
            attributes: .destructive
        ) { [weak self] _ in
            guard let self, let controller = self.trashController else { return }
            Task {
                await controller.deleteItems(with: [self.objectId])
            }
        }
        actions.append(deleteAction)

        return UIMenu(title: "", children: actions)
    }
}
