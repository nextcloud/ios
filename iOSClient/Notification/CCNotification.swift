//
//  CCNotification.swift
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 27/01/17.
//  Copyright (c) 2017 Marino Faggiana. All rights reserved.
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

class CCNotification: UITableViewController {

    var resultSearchController = UISearchController()
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.topItem?.title = NSLocalizedString("_notification_", comment: "")
        self.navigationController?.navigationBar.barTintColor = NCBrandColor.sharedInstance.brand
        self.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.brandText
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NCBrandColor.sharedInstance.brandText]
        self.navigationController?.navigationBar.isTranslucent = false

        self.navigationItem.setRightBarButton(UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(viewClose)), animated: true)
        
        self.tableView.separatorColor = NCBrandColor.sharedInstance.seperator
        self.tableView.tableFooterView = UIView()
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 50.0

        // Register to receive notification reload data
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadDatasource), name: Notification.Name("notificationReloadData"), object: nil)

        reloadDatasource()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @objc func viewClose() {
        
        // Stop listening notification reload data
        NotificationCenter.default.removeObserver(self, name: Notification.Name("notificationReloadData"), object: nil);
        
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Table

    @objc func reloadDatasource() {
        self.tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt: IndexPath) -> [UITableViewRowAction]? {
        
        let notification = appDelegate.listOfNotifications.object(at: editActionsForRowAt.row) as! OCNotifications
        
        // No Action request
        if notification.actions.count == 0 {
            
            let remove = UITableViewRowAction(style: .normal, title: NSLocalizedString("_remove_", comment: "")) { action, index in

                tableView.setEditing(false, animated: true)

                OCnetworking.sharedManager().setNotificationWithAccount(self.appDelegate.activeAccount, serverUrl: "\(self.appDelegate.activeUrl!)/\(k_url_acces_remote_notification_api)/\(notification.idNotification)", type: "DELETE", completion: { (account, message, errorCode) in
                    
                    if errorCode == 0 && account == self.appDelegate.activeAccount {
                        
                        let listOfNotifications = self.appDelegate.listOfNotifications as NSArray as! [OCNotifications]
                        
                        if let index = listOfNotifications.index(where: {$0.idNotification == notification.idNotification})  {
                            self.appDelegate.listOfNotifications.removeObject(at: index)
                        }
                        
                        self.reloadDatasource()
                        
                        if self.appDelegate.listOfNotifications.count == 0 {
                            self.viewClose()
                        }
                        
                    } else if errorCode != 0 {
                        self.appDelegate.messageNotification("_error_", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
                    }
                })
            }
            
            remove.backgroundColor = .red
 
            return [remove]
 
        } else {
        // Action request
            
            var buttons = [UITableViewRowAction]()
            
            for action in notification.actions {
                
                let button = UITableViewRowAction(style: .normal, title: (action as! OCNotificationsAction).label) { action, index in
                    
                    for actionNotification in notification.actions {
                        
                        if (actionNotification as! OCNotificationsAction).label == action.title  {
                            
                            tableView.setEditing(false, animated: true)

                            OCnetworking.sharedManager().setNotificationWithAccount(self.appDelegate.activeAccount, serverUrl: (actionNotification as! OCNotificationsAction).link, type: (actionNotification as! OCNotificationsAction).type, completion: { (account, message, errorCode) in
                                
                                if errorCode == 0 && account == self.appDelegate.activeAccount {
                                    
                                    let listOfNotifications = self.appDelegate.listOfNotifications as NSArray as! [OCNotifications]
                                    
                                    if let index = listOfNotifications.index(where: {$0.idNotification == notification.idNotification})  {
                                        self.appDelegate.listOfNotifications.removeObject(at: index)
                                    }
                                    
                                    self.reloadDatasource()
                                    
                                    if self.appDelegate.listOfNotifications.count == 0 {
                                        self.viewClose()
                                    }
                                    
                                } else if errorCode != 0 {
                                    self.appDelegate.messageNotification("_error_", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
                                }
                            })
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
        
        let selectionColor : UIView = UIView.init()
        selectionColor.backgroundColor = NCBrandColor.sharedInstance.getColorSelectBackgrond()
        cell.selectedBackgroundView = selectionColor
        
        if self.resultSearchController.isActive {
            
        } else {
            
            let notification = appDelegate.listOfNotifications.object(at: indexPath.row) as! OCNotifications
            let urlIcon = URL(string: notification.icon)
            var image : UIImage?
            
            if let urlIcon = urlIcon {
                let pathFileName = CCUtility.getDirectoryUserData() + "/" + urlIcon.deletingPathExtension().lastPathComponent + ".png"
                image = UIImage(contentsOfFile: pathFileName)
            }
            
            if let image = image {
                cell.icon.image = CCGraphics.changeThemingColorImage(image, multiplier: 2, color: NCBrandColor.sharedInstance.brandElement)
            } else {
                cell.icon.image = CCGraphics.changeThemingColorImage(#imageLiteral(resourceName: "notification"), multiplier:2, color: NCBrandColor.sharedInstance.brandElement)
            }
            
            //
            //cell.date.text = DateFormatter.localizedString(from: notification.date, dateStyle: .medium, timeStyle: .medium)
            //
            cell.date.text = CCUtility.dateDiff(notification.date)
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
                    let pathFileName = CCUtility.getDirectoryUserData() + "/" + fileName
                    try data.write(to: URL(fileURLWithPath: pathFileName), options: .atomic)
                    
                    self.reloadDatasource()
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
