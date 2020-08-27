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

import FloatingPanel
import NCCommunication

class NCSortMenu: NSObject {
    
    private var sortButton: UIButton?
    private var serverUrl: String?
    private var hideDirectoryOnTop: Bool?
    
    private var key = ""
    private var layout = ""
    private var sort = ""
    private var ascending = true
    private var groupBy = ""
    private var directoryOnTop = false
    private var titleButton = ""
    private var itemForLine: Int = 0

    @objc func toggleMenu(viewController: UIViewController, key: String, sortButton: UIButton?, serverUrl: String?, hideDirectoryOnTop: Bool = false) {
        
        self.key = key
        self.sortButton = sortButton
        self.serverUrl = serverUrl
        self.hideDirectoryOnTop = hideDirectoryOnTop
        
        (layout, sort, ascending, groupBy, directoryOnTop, titleButton, itemForLine) = NCUtility.shared.getLayoutForView(key: key)

        let mainMenuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateViewController(withIdentifier: "NCMainMenuTableViewController") as! NCMainMenuTableViewController
        mainMenuViewController.actions = self.initSortMenu()

        let menuPanelController = NCMenuPanelController()
        menuPanelController.parentPresenter = viewController
        menuPanelController.delegate = mainMenuViewController
        menuPanelController.set(contentViewController: mainMenuViewController)
        menuPanelController.track(scrollView: mainMenuViewController.tableView)

        viewController.present(menuPanelController, animated: true, completion: nil)
    }
    
    @objc func actionMenu() {
                
        switch sort {
        case "fileName":
            titleButton = ascending ? "_sorted_by_name_a_z_" : "_sorted_by_name_z_a_"
        case "date":
            titleButton = ascending ? "_sorted_by_date_less_recent_" : "_sorted_by_date_more_recent_"
        case "size":
            titleButton = ascending ? "_sorted_by_size_largest_" : "_sorted_by_size_smallest_"
        default:
            break
        }
        
        self.sortButton?.setTitle(NSLocalizedString(titleButton, comment: ""), for: .normal)
        
        NCUtility.shared.setLayoutForView(key: key, layout: layout, sort: sort, ascending: ascending, groupBy: groupBy, directoryOnTop: directoryOnTop, titleButton: titleButton, itemForLine: itemForLine)
        
        NotificationCenter.default.postOnMainThread(name: k_notificationCenter_reloadDataSource, userInfo: ["serverUrl":self.serverUrl ?? ""])
    }

    private func initSortMenu() -> [NCMenuAction] {
        var actions = [NCMenuAction]()

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_order_by_name_a_z_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "sortFileNameAZ"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                onTitle: NSLocalizedString("_order_by_name_z_a_", comment: ""),
                onIcon: CCGraphics.changeThemingColorImage(UIImage(named: "sortFileNameZA"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                selected: self.sort == "fileName",
                on: self.sort == "fileName",
                action: { menuAction in
                    if self.sort == "fileName" {
                        self.ascending = !self.ascending
                    } else {
                        self.sort = "fileName"
                    }
                    self.actionMenu()
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_order_by_date_more_recent_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "sortDateMoreRecent"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                onTitle: NSLocalizedString("_order_by_date_less_recent_", comment: ""),
                onIcon: CCGraphics.changeThemingColorImage(UIImage(named: "sortDateLessRecent"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                selected: self.sort == "date",
                on: self.sort == "date",
                action: { menuAction in
                    if self.sort == "date" {
                        self.ascending = !self.ascending
                    } else {
                        self.sort = "date"
                    }
                    self.actionMenu()
                }
            )
        )

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_order_by_size_smallest_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "sortSmallest"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                onTitle: NSLocalizedString("_order_by_size_largest_", comment: ""),
                onIcon: CCGraphics.changeThemingColorImage(UIImage(named: "sortLargest"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                selected: self.sort == "size",
                on: self.sort == "size",
                action: { menuAction in
                    if self.sort == "size" {
                        self.ascending = !self.ascending
                    } else {
                        self.sort = "size"
                    }
                    self.actionMenu()
                }
            )
        )

        if !(hideDirectoryOnTop ?? false) {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_directory_on_top_no_", comment: ""),
                    icon: CCGraphics.changeThemingColorImage(UIImage(named: "foldersOnTop"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                    selected: self.directoryOnTop,
                    on: self.directoryOnTop,
                    action: { menuAction in
                        self.directoryOnTop = !self.directoryOnTop
                        self.actionMenu()
                    }
                )
            )
        }
        
        return actions
    }
}
