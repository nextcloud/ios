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

class CCNotification: UITableViewController {

    var resultSearchController = UISearchController()
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.topItem?.title = NSLocalizedString("_notification_", comment: "")
        self.navigationItem.setRightBarButton(UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close)), animated: true)
        
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
        
        let idsNotification: [String] = appDelegate.listOfNotifications.allKeys as! [String]
        
        let idNotification : String! = idsNotification[editActionsForRowAt.row]
        let notification = appDelegate.listOfNotifications[idNotification] as! OCNotifications

        // No Action request
        if notification.actions.count == 0 {
            
            let delete = UITableViewRowAction(style: .normal, title: NSLocalizedString("_delete_", comment: "")) { action, index in
                print("delete button tapped")
            }
            delete.backgroundColor = .red
            
            return [delete]
            
        } else {
        // Action request
            
            var buttons = [UITableViewRowAction]()
            
            for action in notification.actions {
                
                let button = UITableViewRowAction(style: .normal, title: (action as! OCNotificationsAction).label) { action, index in
                    
                    for actionNotification in notification.actions {
                        
                        if (actionNotification as! OCNotificationsAction).label == action.title  {
                            print(action.title!)
                        }
                    }
                }
                if (action as! OCNotificationsAction).type == "DELETE" {
                    button.backgroundColor = .red
                } else {
                    button.backgroundColor = .green
                }
                
                buttons.append(button)
            }
            
            return buttons
        }
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
            
            let urlIcon = URL(string: notification.icon)!
            let pathFileName = (appDelegate.directoryUser) + "/" + urlIcon.lastPathComponent
            let image = UIImage(contentsOfFile: pathFileName)
            
            if image == nil {
                //downloadImage(url: urlIcon)
            } else {
                cell.icon.image = image
            }
            
            cell.date.text = DateFormatter.localizedString(from: notification.date, dateStyle: .medium, timeStyle: .medium)
            cell.subject.text = notification.subject
            cell.message.text = notification.message
            
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: - Get Image from url
    
    func getDataFromUrl(url: URL, completion: @escaping (_ data: Data?, _  response: URLResponse?, _ error: Error?) -> Void) {
        URLSession.shared.dataTask(with: url) {
            (data, response, error) in
            completion(data, response, error)
            }.resume()
    }
    
    func downloadImage(url: URL) {
        
        print("Download Started")
        getDataFromUrl(url: url) { (data, response, error)  in
            guard let data = data, error == nil else { return }
            let fileName = response?.suggestedFilename ?? url.lastPathComponent
            print("Download Finished")
            DispatchQueue.main.async() { () -> Void in
                
                do {
                    let pathFileName = (self.appDelegate.directoryUser) + "/" + fileName
                    try data.write(to: URL(fileURLWithPath: pathFileName), options: .atomic)
                    
                    self.tableView.reloadData()
                } catch {
                    print(error)
                }
            }
        }
    }

}

// MARK: - Class UITableViewCell

class CCNotificationCell: UITableViewCell {
    
    @IBOutlet weak var icon : UIImageView!
    @IBOutlet weak var date: UILabel!
    @IBOutlet weak var subject: UILabel!
    @IBOutlet weak var message: UILabel!
}
