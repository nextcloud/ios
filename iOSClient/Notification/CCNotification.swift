//
//  CCNotification.swift
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 27/01/17.
//  Copyright (c) 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
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

class CCNotification: UITableViewController, UISearchResultsUpdating {

    var resultSearchController = UISearchController()
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.topItem?.title = NSLocalizedString("_notification_", comment: "")
        self.navigationItem.setRightBarButton(UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close)), animated: true)
        
        self.resultSearchController = ({

            let controller = UISearchController(searchResultsController: nil)
            
            controller.searchBar.sizeToFit()
            controller.searchResultsUpdater = self
            controller.dimsBackgroundDuringPresentation = false
            controller.searchBar.scopeButtonTitles = ["A", "B", "C", "D"]
            
            self.tableView.tableHeaderView = controller.searchBar
            self.tableView.tableFooterView = UIView()
            
            return controller
        })()
        
        self.tableView.reloadData()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    
    func close() {
        
        self.dismiss(animated: true) { 
            
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
   
    override func tableView(_ tableView: UITableView, editActionsForRowAt: IndexPath) -> [UITableViewRowAction]? {
        
        let favorite = UITableViewRowAction(style: .normal, title: "Favorite") { action, index in
            print("favorite button tapped")
        }
        favorite.backgroundColor = .red
        
        let share = UITableViewRowAction(style: .normal, title: "Share") { action, index in
            print("share button tapped")
        }
        share.backgroundColor = .green
        
        return [share, favorite]
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if self.resultSearchController.isActive {
            return 0
        } else {
            let numRecord = appDelegate.listOfNotifications.count
            return numRecord
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! CCNotificationCell
        
        if self.resultSearchController.isActive {
            
        } else {
            
            let idsNotification: [String] = appDelegate.listOfNotifications.allKeys as! [String]

            let idNotification : String! = idsNotification[indexPath.row]
            let notification = appDelegate.listOfNotifications[idNotification] as! OCNotifications
                
            cell.date.text = DateFormatter.localizedString(from: notification.date, dateStyle: .medium, timeStyle: .medium)
            cell.subject.text = "let notification = appDelegate.listOfNotifications[idNotification] as! OCNotificationslet notification = appDelegate.listOfNotifications[idNotification] as! OCNotifications"//notification.subject
            cell.message.text = "let notification = appDelegate.listOfNotifications[idNotification] as! OCNotificationslet notification = appDelegate.listOfNotifications[idNotification] as! OCNotifications"//notification.message
        }
        
        return cell
    }
    
    func updateSearchResults(for searchController: UISearchController) {
    }
}

// MARK: - Class UITableViewCell

class CCNotificationCell: UITableViewCell {
    
    @IBOutlet weak var icon : UIImageView!
    @IBOutlet weak var date: UILabel!
    @IBOutlet weak var subject: UILabel!
    @IBOutlet weak var message: UILabel!
}
