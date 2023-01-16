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
import FloatingPanel
import NextcloudKit

extension NCTrash {
    var selectActions: [NCMenuAction] {
        [
            NCMenuAction(
                title: NSLocalizedString("_trash_restore_selected_", comment: ""),
                icon: NCUtility.shared.loadImage(named: "restore"),
                action: { _ in
                    self.selectOcId.forEach(self.restoreItem)
                    self.tapSelect()
                }
            ),
            NCMenuAction(
                title: NSLocalizedString("_trash_delete_selected_", comment: ""),
                icon: NCUtility.shared.loadImage(named: "trash"),
                action: { _ in
                    let alert = UIAlertController(title: NSLocalizedString("_trash_delete_selected_", comment: ""), message: "", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("_delete_", comment: ""), style: .destructive, handler: { _ in
                        self.selectOcId.forEach(self.deleteItem)
                        self.tapSelect()
                    }))
                    alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: { _ in }))
                    self.present(alert, animated: true, completion: nil)
                }
            )
        ]
    }

    func toggleMenuMoreHeader() {

        var actions: [NCMenuAction] = []

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_trash_restore_all_", comment: ""),
                icon: NCUtility.shared.loadImage(named: "restore"),
                action: { _ in
                    self.datasource.forEach({ self.restoreItem(with: $0.fileId) })
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_trash_delete_all_", comment: ""),
                icon: NCUtility.shared.loadImage(named: "trash"),
                action: { _ in
                    let alert = UIAlertController(title: NSLocalizedString("_trash_delete_all_description_", comment: ""), message: "", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("_trash_delete_all_", comment: ""), style: .destructive, handler: { _ in
                        self.emptyTrash()
                    }))
                    alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel))
                    self.present(alert, animated: true, completion: nil)
                }
            )
        )
        presentMenu(with: actions)
    }

    func toggleMenuMore(with objectId: String, image: UIImage?, isGridCell: Bool) {

        guard let tableTrash = NCManageDatabase.shared.getTrashItem(fileId: objectId, account: appDelegate.account) else {
            return
        }

        guard isGridCell else {
            let alert = UIAlertController(title: NSLocalizedString("_want_delete_", comment: ""), message: tableTrash.trashbinFileName, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("_delete_", comment: ""), style: .destructive, handler: { _ in
                self.deleteItem(with: objectId)
            }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel))
            self.present(alert, animated: true, completion: nil)

            return
        }

        var actions: [NCMenuAction] = []

        var iconHeader: UIImage!
        if let icon = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(tableTrash.fileId, etag: tableTrash.fileName)) {
            iconHeader = icon
        } else {
            if tableTrash.directory {
                iconHeader = UIImage(named: "folder")!.image(color: UIColor.systemGray, size: 50)
            } else {
                iconHeader = UIImage(named: tableTrash.iconName)
            }
        }

        actions.append(
            NCMenuAction(
                title: tableTrash.trashbinFileName,
                icon: iconHeader,
                action: nil
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_restore_", comment: ""),
                icon: UIImage(named: "restore")!.image(color: UIColor.systemGray, size: 50),
                action: { _ in
                    self.restoreItem(with: objectId)
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_delete_", comment: ""),
                icon: NCUtility.shared.loadImage(named: "trash"),
                action: { _ in
                    self.deleteItem(with: objectId)
                }
            )
        )

        presentMenu(with: actions)
    }
}
