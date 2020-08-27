//
//  NCMasterNavigationController.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 30/01/2020.
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

class NCMasterNavigationController: UINavigationController {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
        
        changeTheming()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        guard let splitViewController = self.splitViewController else { return }
        
        if let navigationController = splitViewController.viewControllers[splitViewController.viewControllers.count-1] as? UINavigationController {
            
            if splitViewController.isCollapsed {
                
                navigationController.topViewController?.navigationItem.backBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_back_", comment: ""), style: UIBarButtonItem.Style.plain, target: nil, action: nil)
                
            } else {
                
                navigationController.topViewController?.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
            }
        }
    }

    @objc func changeTheming() {
        navigationBar.barTintColor = NCBrandColor.sharedInstance.backgroundView
        navigationBar.tintColor = NCBrandColor.sharedInstance.brandElement
    }
}

extension NCMasterNavigationController: UINavigationControllerDelegate {

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
                
        if self.splitViewController?.isCollapsed == true {
            if (topViewController as? UITabBarController) != nil {
                self.isNavigationBarHidden = true
            } else {
                self.isNavigationBarHidden = false
            }
        } else {
            self.isNavigationBarHidden = true
        }
    }
}
