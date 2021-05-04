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
    private var serverUrl: String = ""
    private var hideDirectoryOnTop: Bool?
    
    private var key = ""
    private var layout = ""
    private var sort = ""
    private var ascending = true
    private var groupBy = ""
    private var directoryOnTop = false
    private var titleButtonHeader = ""
    private var itemForLine: Int = 0
    private var fillBackgroud = ""
    private var fillBackgroudContentMode = ""

    func toggleMenu(viewController: UIViewController, key: String, sortButton: UIButton?, serverUrl: String, hideDirectoryOnTop: Bool = false) {
        
        self.key = key
        self.sortButton = sortButton
        self.serverUrl = serverUrl
        self.hideDirectoryOnTop = hideDirectoryOnTop
        
        (layout, sort, ascending, groupBy, directoryOnTop, titleButtonHeader, itemForLine, fillBackgroud, fillBackgroudContentMode) = NCUtility.shared.getLayoutForView(key: key, serverUrl: serverUrl)

        let menuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateInitialViewController() as! NCMenu
        var actions = [NCMenuAction]()

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_order_by_name_a_z_", comment: ""),
                icon: UIImage(named: "sortFileNameAZ")!.image(color: NCBrandColor.shared.gray, size: 50),
                onTitle: NSLocalizedString("_order_by_name_z_a_", comment: ""),
                onIcon: UIImage(named: "sortFileNameZA")!.image(color: NCBrandColor.shared.gray, size: 50),
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
                icon: UIImage(named: "sortDateMoreRecent")!.image(color: NCBrandColor.shared.gray, size: 50),
                onTitle: NSLocalizedString("_order_by_date_less_recent_", comment: ""),
                onIcon: UIImage(named: "sortDateLessRecent")!.image(color: NCBrandColor.shared.gray, size: 50),
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
                icon: UIImage(named: "sortSmallest")!.image(color: NCBrandColor.shared.gray, size: 50),
                onTitle: NSLocalizedString("_order_by_size_largest_", comment: ""),
                onIcon: UIImage(named: "sortLargest")!.image(color: NCBrandColor.shared.gray, size: 50),
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

        if !hideDirectoryOnTop {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_directory_on_top_no_", comment: ""),
                    icon: UIImage(named: "foldersOnTop")!.image(color: NCBrandColor.shared.gray, size: 50),
                    selected: self.directoryOnTop,
                    on: self.directoryOnTop,
                    action: { menuAction in
                        self.directoryOnTop = !self.directoryOnTop
                        self.actionMenu()
                    }
                )
            )
        }
        
        menuViewController.actions = actions

        let menuPanelController = NCMenuPanelController()
        menuPanelController.parentPresenter = viewController
        menuPanelController.delegate = menuViewController
        menuPanelController.set(contentViewController: menuViewController)
        menuPanelController.track(scrollView: menuViewController.tableView)

        viewController.present(menuPanelController, animated: true, completion: nil)
    }
    
    func actionMenu() {
                
        switch sort {
        case "fileName":
            titleButtonHeader = ascending ? "_sorted_by_name_a_z_" : "_sorted_by_name_z_a_"
        case "date":
            titleButtonHeader = ascending ? "_sorted_by_date_less_recent_" : "_sorted_by_date_more_recent_"
        case "size":
            titleButtonHeader = ascending ? "_sorted_by_size_smallest_" : "_sorted_by_size_largest_"
        default:
            break
        }
        
        self.sortButton?.setTitle(NSLocalizedString(titleButtonHeader, comment: ""), for: .normal)
        
        NCUtility.shared.setLayoutForView(key: key, serverUrl: serverUrl, layout: layout, sort: sort, ascending: ascending, groupBy: groupBy, directoryOnTop: directoryOnTop, titleButtonHeader: titleButtonHeader, itemForLine: itemForLine, fillBackgroud: fillBackgroud, fillBackgroudContentMode: fillBackgroudContentMode)
        
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["serverUrl":self.serverUrl])
    }
}
