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
    
    private var layout = ""
    private var typeLayout = ""
    private var datasourceSorted = ""
    private var datasourceAscending = true
    private var datasourceGroupBy = ""
    private var datasourceDirectoryOnTop = false
    private var datasourceTitleButton = ""
    
    @objc func toggleMenu(viewController: UIViewController, layout: String, sortButton: UIButton?, serverUrl: String?, hideDirectoryOnTop: Bool = false) {
        
        self.layout = layout
        self.sortButton = sortButton
        self.serverUrl = serverUrl
        self.hideDirectoryOnTop = hideDirectoryOnTop
        
        (typeLayout, datasourceSorted, datasourceAscending, datasourceGroupBy, datasourceDirectoryOnTop, datasourceTitleButton) = NCUtility.shared.getLayoutForView(key: layout)

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
                
        switch datasourceSorted {
        case "fileName":
            self.datasourceTitleButton = datasourceAscending ? "_sorted_by_name_a_z_" : "_sorted_by_name_z_a_"
        case "date":
            self.datasourceTitleButton = datasourceAscending ? "_sorted_by_date_less_recent_" : "_sorted_by_date_more_recent_"
        case "size":
            self.datasourceTitleButton = datasourceAscending ? "_sorted_by_size_largest_" : "_sorted_by_size_smallest_"
        default:
            break
        }
        
        self.sortButton?.setTitle(NSLocalizedString(self.datasourceTitleButton, comment: ""), for: .normal)
        
        NCUtility.shared.setLayoutForView(key: self.layout, layout: self.typeLayout, sort: self.datasourceSorted, ascending: self.datasourceAscending, groupBy: self.datasourceGroupBy, directoryOnTop: self.datasourceDirectoryOnTop, titleButton: self.datasourceTitleButton)
        
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
                selected: self.datasourceSorted == "fileName",
                on: self.datasourceSorted == "fileName",
                action: { menuAction in
                    if self.datasourceSorted == "fileName" {
                        self.datasourceAscending = !self.datasourceAscending
                    } else {
                        self.datasourceSorted = "fileName"
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
                selected: self.datasourceSorted == "date",
                on: self.datasourceSorted == "date",
                action: { menuAction in
                    if self.datasourceSorted == "date" {
                        self.datasourceAscending = !self.datasourceAscending
                    } else {
                        self.datasourceSorted = "date"
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
                selected: self.datasourceSorted == "size",
                on: self.datasourceSorted == "size",
                action: { menuAction in
                    if self.datasourceSorted == "size" {
                        self.datasourceAscending = !self.datasourceAscending
                    } else {
                        self.datasourceSorted = "size"
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
                    selected: self.datasourceDirectoryOnTop,
                    on: self.datasourceDirectoryOnTop,
                    action: { menuAction in
                        self.datasourceDirectoryOnTop = !self.datasourceDirectoryOnTop
                        self.actionMenu()
                    }
                )
            )
        }
        
        return actions
    }
}
