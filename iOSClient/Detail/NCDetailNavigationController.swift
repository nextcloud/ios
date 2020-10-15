//
//  NCDetailNavigationController.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 07/02/2020.
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

import Foundation

class NCDetailNavigationController: UINavigationController {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
        
        changeTheming()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let buttonMore = UIBarButtonItem.init(image: CCGraphics.changeThemingColorImage(UIImage(named: "more"), width: 50, height: 50, color: NCBrandColor.sharedInstance.textView), style: .plain, target: self, action: #selector(self.openMenuMore))
        topViewController?.navigationItem.rightBarButtonItem = buttonMore
               
        topViewController?.navigationItem.leftBarButtonItem = nil
        if let splitViewController = self.splitViewController {
            if !splitViewController.isCollapsed {
                topViewController?.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
            }
        }        
    }
    
    //MARK: - NotificationCenter

    @objc func changeTheming() {
        navigationBar.barTintColor = NCBrandColor.sharedInstance.backgroundView
        navigationBar.tintColor = NCBrandColor.sharedInstance.brandElement
    }

    //MARK: - Button

    @objc func openMenuMore() {
        if let metadata = appDelegate.activeDetail?.metadata {
            self.toggleMoreMenu(viewController: self, metadata: metadata)
        }
    }
}
