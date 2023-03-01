//
//  NCSortMenu.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 27/08/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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

class NCSortMenu: NSObject {

    private var sortButton: UIButton?
    private var serverUrl: String = ""
    private var hideDirectoryOnTop: Bool?

    private var key = ""

    func toggleMenu(viewController: UIViewController, account: String, key: String, sortButton: UIButton?, serverUrl: String, hideDirectoryOnTop: Bool = false) {

        self.key = key
        self.sortButton = sortButton
        self.serverUrl = serverUrl
        self.hideDirectoryOnTop = hideDirectoryOnTop

        guard let layoutForView = NCManageDatabase.shared.getLayoutForView(account: account, key: key, serverUrl: serverUrl) else { return }
        var actions = [NCMenuAction]()
        var title = ""
        var icon = UIImage()

        if layoutForView.ascending {
            title = NSLocalizedString("_order_by_name_z_a_", comment: "")
            icon = UIImage(named: "sortFileNameZA")!.image(color: UIColor.systemGray, size: 50)
        } else {
            title = NSLocalizedString("_order_by_name_a_z_", comment: "")
            icon = UIImage(named: "sortFileNameAZ")!.image(color: UIColor.systemGray, size: 50)
        }

        actions.append(
            NCMenuAction(
                title: title,
                icon: icon,
                selected: layoutForView.sort == "fileName",
                on: layoutForView.sort == "fileName",
                action: { _ in
                    layoutForView.sort = "fileName"
                    layoutForView.ascending = !layoutForView.ascending
                    self.actionMenu(layoutForView: layoutForView)
                }
            )
        )

        if layoutForView.ascending {
            title = NSLocalizedString("_order_by_date_more_recent_", comment: "")
            icon = UIImage(named: "sortDateMoreRecent")!.image(color: UIColor.systemGray, size: 50)
        } else {
            title = NSLocalizedString("_order_by_date_less_recent_", comment: "")
            icon = UIImage(named: "sortDateLessRecent")!.image(color: UIColor.systemGray, size: 50)
        }

        actions.append(
            NCMenuAction(
                title: title,
                icon: icon,
                selected: layoutForView.sort == "date",
                on: layoutForView.sort == "date",
                action: { _ in
                    layoutForView.sort = "date"
                    layoutForView.ascending = !layoutForView.ascending
                    self.actionMenu(layoutForView: layoutForView)
                }
            )
        )

        if layoutForView.ascending {
            title = NSLocalizedString("_order_by_size_largest_", comment: "")
            icon = UIImage(named: "sortLargest")!.image(color: UIColor.systemGray, size: 50)
        } else {
            title = NSLocalizedString("_order_by_size_smallest_", comment: "")
            icon = UIImage(named: "sortSmallest")!.image(color: UIColor.systemGray, size: 50)
        }

        actions.append(
            NCMenuAction(
                title: title,
                icon: icon,
                selected: layoutForView.sort == "size",
                on: layoutForView.sort == "size",
                action: { _ in
                    layoutForView.sort = "size"
                    layoutForView.ascending = !layoutForView.ascending
                    self.actionMenu(layoutForView: layoutForView)
                }
            )
        )

        if !hideDirectoryOnTop {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_directory_on_top_no_", comment: ""),
                    icon: UIImage(named: "foldersOnTop")!.image(color: UIColor.systemGray, size: 50),
                    selected: layoutForView.directoryOnTop,
                    on: layoutForView.directoryOnTop,
                    action: { _ in
                        layoutForView.directoryOnTop = !layoutForView.directoryOnTop
                        self.actionMenu(layoutForView: layoutForView)
                    }
                )
            )
        }

        viewController.presentMenu(with: actions)
    }

    func actionMenu(layoutForView: NCDBLayoutForView) {

        switch layoutForView.sort {
        case "fileName":
            layoutForView.titleButtonHeader = layoutForView.ascending ? "_sorted_by_name_a_z_" : "_sorted_by_name_z_a_"
        case "date":
            layoutForView.titleButtonHeader = layoutForView.ascending ? "_sorted_by_date_less_recent_" : "_sorted_by_date_more_recent_"
        case "size":
            layoutForView.titleButtonHeader = layoutForView.ascending ? "_sorted_by_size_smallest_" : "_sorted_by_size_largest_"
        default:
            break
        }

        self.sortButton?.setTitle(NSLocalizedString(layoutForView.titleButtonHeader, comment: ""), for: .normal)
        NCManageDatabase.shared.setLayoutForView(layoutForView: layoutForView)
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["serverUrl": self.serverUrl])
    }
}
