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

class CCNotification: UITableViewController, OCNetworkingDelegate {

    var resultSearchController = UISearchController()
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.topItem?.title = NSLocalizedString("_notification_", comment: "")
        self.navigationController?.navigationBar.barTintColor = NCBrandColor.sharedInstance.brand
        self.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.navigationBarText
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: NCBrandColor.sharedInstance.navigationBarText]

        self.navigationItem.setRightBarButton(UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(viewClose)), animated: true)
        
        self.tableView.separatorColor = NCBrandColor.sharedInstance.seperator
        self.tableView.tableFooterView = UIView()

        // Register to receive notification reload data
        NotificationCenter.default.addObserver(self, selector: #selector(self.tableView.reloadData), name: Notification.Name("notificationReloadData"), object: nil)

        self.tableView.reloadData()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func viewClose() {
        
        // Stop listening notification reload data
        NotificationCenter.default.removeObserver(self, name: Notification.Name("notificationReloadData"), object: nil);
        
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Table

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt: IndexPath) -> [UITableViewRowAction]? {
        
        let notification = appDelegate.listOfNotifications.object(at: editActionsForRowAt.row) as! OCNotifications
        
        // No Action request
        if notification.actions.count == 0 {
            
            let remove = UITableViewRowAction(style: .normal, title: NSLocalizedString("_remove_", comment: "")) { action, index in

                tableView.setEditing(false, animated: true)

                let metadataNet = CCMetadataNet.init(account: self.appDelegate.activeAccount)!
                
                metadataNet.action = actionSetNotificationServer
                metadataNet.assetLocalIdentifier = "\(notification.idNotification)"
                metadataNet.options = "DELETE"
                metadataNet.serverUrl = "\(self.appDelegate.activeUrl!)/\(k_url_acces_remote_notification_api)/\(metadataNet.assetLocalIdentifier!)"

                self.appDelegate.addNetworkingOperationQueue(self.appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
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

                            let metadataNet = CCMetadataNet.init(account: self.appDelegate.activeAccount)!
                            
                            metadataNet.action = actionSetNotificationServer
                            metadataNet.assetLocalIdentifier = "\(notification.idNotification)"
                            metadataNet.serverUrl =  (actionNotification as! OCNotificationsAction).link
                            metadataNet.options = (actionNotification as! OCNotificationsAction).type
                            
                            self.appDelegate.addNetworkingOperationQueue(self.appDelegate.netQueue, delegate: self, metadataNet: metadataNet)
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
        
        let notification = appDelegate.listOfNotifications.object(at: indexPath.row) as! OCNotifications
        
        if notification.message.characters.count > 0 {
            
            return 160
            
        } else {
            
            return 120
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
            
            if urlIcon != nil {
                let pathFileName = (appDelegate.directoryUser) + "/" + (urlIcon?.lastPathComponent)!
                image = UIImage(contentsOfFile: pathFileName)
            }
            
            if image == nil {
                
                cell.icon.image = CCGraphics.changeThemingColorImage(#imageLiteral(resourceName: "notification"), color: NCBrandColor.sharedInstance.brand)
                //downloadImage(url: urlIcon)
                
            } else {
                
                cell.icon.image = image
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
    
    // MARK: - Networking delegate

    func setNotificationServerFailure(_ metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        appDelegate.messageNotification("_error_", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
    }
    
    func setNotificationServerSuccess(_ metadataNet: CCMetadataNet!) {
        
        let listOfNotifications = appDelegate.listOfNotifications as NSArray as! [OCNotifications]
        
        if let index = listOfNotifications.index(where: {$0.idNotification == Int(metadataNet.assetLocalIdentifier)})  {
            appDelegate.listOfNotifications.removeObject(at: index)
        }
        
        self.tableView.reloadData()
        
        if appDelegate.listOfNotifications.count == 0 {
            viewClose()
        }
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
