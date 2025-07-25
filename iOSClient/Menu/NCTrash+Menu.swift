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
    func toggleMenuMore(with objectId: String, image: UIImage?, isGridCell: Bool, sender: Any?) {
        guard let tblTrash = self.database.getTableTrash(fileId: objectId, account: session.account)
        else {
            return
        }
        guard isGridCell
        else {
            let alert = UIAlertController(title: NSLocalizedString("_want_delete_", comment: ""), message: tblTrash.trashbinFileName, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("_delete_", comment: ""), style: .destructive, handler: { _ in
                Task {
                    await self.deleteItems(with: [objectId])
                }
            }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel))
            self.present(alert, animated: true, completion: nil)
            return
        }

        var actions: [NCMenuAction] = []

        var iconHeader: UIImage!
        if let icon = utility.getImage(ocId: tblTrash.fileId, etag: tblTrash.fileName, ext: NCGlobal.shared.previewExt512, userId: session.userId, urlBase: session.urlBase) {
            iconHeader = icon
        } else {
            if tblTrash.directory {
                iconHeader = NCImageCache.shared.getFolder(account: tblTrash.account)
            } else {
                iconHeader = NCImageCache.shared.getImageFile()
            }
        }

        actions.append(
            NCMenuAction(
                title: tblTrash.trashbinFileName,
                icon: iconHeader,
                sender: sender,
                action: nil
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_restore_", comment: ""),
                icon: utility.loadImage(named: "arrow.counterclockwise", colors: [NCBrandColor.shared.iconImageColor]),
                sender: sender,
                action: { _ in
                    Task {
                        await self.restoreItem(with: objectId)
                    }
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_delete_", comment: ""),
                destructive: true,
                icon: utility.loadImage(named: "trash", colors: [.red]),
                sender: sender,
                action: { _ in
                    Task {
                        await self.deleteItems(with: [objectId])
                    }
                }
            )
        )

        presentMenu(with: actions, controller: controller, sender: sender)
    }
}
