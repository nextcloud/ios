//
//  CCNotification.swift
//  Nextcloud
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
import NCCommunication

class CCNotification: UITableViewController, CCNotificationCelllDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    static var notifications = [OCNotifications]()
    static var notificationsAccount = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("_notification_", comment: "")
                
        self.tableView.tableFooterView = UIView()
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 50.0
        self.tableView.allowsSelection = false
        
        // empty Data Source
        self.tableView.emptyDataSetSource = self
        self.tableView.emptyDataSetDelegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
        changeTheming()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        getNetwokingNotification()
    }
    
    @objc func changeTheming() {
        appDelegate.changeTheming(self, tableView: tableView, collectionView: nil, form: false)
    }

    @objc func viewClose() {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: DZNEmpty
    
    func backgroundColor(forEmptyDataSet scrollView: UIScrollView) -> UIColor? {
        return NCBrandColor.sharedInstance.backgroundView
    }
    
    func image(forEmptyDataSet scrollView: UIScrollView) -> UIImage? {
        return CCGraphics.changeThemingColorImage(UIImage.init(named: "notification"), width: 300, height: 300, color: NCBrandColor.sharedInstance.graySoft)
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        let text = "\n"+NSLocalizedString("_no_notification_", comment: "")
        let attributes = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 20), NSAttributedString.Key.foregroundColor: UIColor.lightGray]
        return NSAttributedString.init(string: text, attributes: attributes)
    }
    
    func emptyDataSetShouldAllowScroll(_ scrollView: UIScrollView) -> Bool {
        return true
    }
    
    // MARK: - Table

    @objc func reloadDatasource() {
        self.tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return CCNotification.notifications.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! CCNotificationCell
        cell.delegate = self
        
        let notification = CCNotification.notifications[indexPath.row]
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
        
        // Avatar
        cell.avatar.isHidden = true
        cell.avatarLeadingMargin.constant = 10

        if let parameter = notification.subjectRichParameters as?  Dictionary<String, Any> {
            if let user = parameter["user"] as? Dictionary<String, Any> {
                if let name = user["id"] as? String {
                    let fileNameLocalPath = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(appDelegate.activeUser, activeUrl: appDelegate.activeUrl) + "-" + name + ".png"
                    if FileManager.default.fileExists(atPath: fileNameLocalPath) {
                        if let image = UIImage(contentsOfFile: fileNameLocalPath) {
                            cell.avatar.isHidden = false
                            cell.avatarLeadingMargin.constant = 50
                            cell.avatar.image = image
                        }
                    } else {
                        DispatchQueue.global().async {
                            NCCommunication.sharedInstance.downloadAvatar(serverUrl: self.appDelegate.activeUrl, userID: name, fileNameLocalPath: fileNameLocalPath, size: Int(k_avatar_size), customUserAgent: nil, addCustomHeaders: nil, account: self.appDelegate.activeAccount) { (account, data, errorCode, errorMessage) in
                                if errorCode == 0 && account == self.appDelegate.activeAccount && UIImage(data: data!) != nil {
                                    if let image = UIImage(contentsOfFile: fileNameLocalPath) {
                                        cell.avatar.isHidden = false
                                        cell.avatarLeadingMargin.constant = 50
                                        cell.avatar.image = image
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        //
        //cell.date.text = DateFormatter.localizedString(from: notification.date, dateStyle: .medium, timeStyle: .medium)
        //
        cell.notification = notification
        cell.date.text = CCUtility.dateDiff(notification.date)
        cell.date.textColor = .gray
        cell.subject.text = notification.subject
        cell.subject.textColor = NCBrandColor.sharedInstance.textView
        cell.message.text = notification.message.replacingOccurrences(of: "<br />", with: "\n")
        cell.message.textColor = .gray
        
        cell.remove.setImage(CCGraphics.changeThemingColorImage(UIImage(named: "exit")!, width: 40, height: 40, color: .gray), for: .normal)
        
        cell.primary.isEnabled = false
        cell.primary.isHidden = true
        cell.primary.titleLabel?.font = .systemFont(ofSize: 14)
        cell.primary.setTitleColor(.white, for: .normal)
        cell.primary.layer.cornerRadius = 15
        cell.primary.layer.masksToBounds = true
        cell.primary.layer.backgroundColor = NCBrandColor.sharedInstance.brand.cgColor
        
        cell.secondary.isEnabled = false
        cell.secondary.isHidden = true
        cell.secondary.titleLabel?.font = .systemFont(ofSize: 14)
        cell.secondary.setTitleColor(.gray, for: .normal)
        cell.secondary.layer.cornerRadius = 15
        cell.secondary.layer.masksToBounds = true
        cell.secondary.layer.backgroundColor = NCBrandColor.sharedInstance.graySoft.withAlphaComponent(0.1).cgColor
        cell.secondary.layer.borderWidth = 0.3
        cell.secondary.layer.borderColor = UIColor.gray.cgColor
        
        cell.messageBottomMargin.constant = 10
        
        // Action
        if notification.actions.count > 0  {
            
            if notification.actions.count == 1 {
                
                let action = notification.actions[0] as! OCNotificationsAction

                cell.primary.isEnabled = true
                cell.primary.isHidden = false
                cell.primary.setTitle(action.label, for: .normal)
                
            } else if notification.actions.count == 2 {
            
                cell.primary.isEnabled = true
                cell.primary.isHidden = false
                
                cell.secondary.isEnabled = true
                cell.secondary.isHidden = false
            
                for action in notification.actions {
                    
                    let label = (action as! OCNotificationsAction).label
                    let primary = (action as! OCNotificationsAction).primary
                    
                    if primary {
                        cell.primary.setTitle(label, for: .normal)
                    } else {
                        cell.secondary.setTitle(label, for: .normal)
                    }
                }
            }
            
            let widthPrimary = cell.primary.intrinsicContentSize.width + 30;
            let widthSecondary = cell.secondary.intrinsicContentSize.width + 30;
            
            if widthPrimary > widthSecondary {
                cell.primaryWidth.constant = widthPrimary
                cell.secondaryWidth.constant = widthPrimary
            } else {
                cell.primaryWidth.constant = widthSecondary
                cell.secondaryWidth.constant = widthSecondary
            }
            
            cell.messageBottomMargin.constant = 40
        }
        
        return cell
    }
    
    // MARK: tap Action
    
    func tapRemove(with notification: OCNotifications?) {
        
        let serverUrl = self.appDelegate.activeUrl + "/" + k_url_acces_remote_notification_api + "/" + String(notification!.idNotification)
        
        OCNetworking.sharedManager().setNotificationWithAccount(self.appDelegate.activeAccount, serverUrl: serverUrl, type: "DELETE", completion: { (account, message, errorCode) in
            
            if errorCode == 0 && account == self.appDelegate.activeAccount {
                
                //let listOfNotifications = self.appDelegate.listOfNotifications as NSArray as! [OCNotifications]
                
                if let index = CCNotification.self.notifications.firstIndex(where: {$0.idNotification == notification!.idNotification})  {
                    CCNotification.self.notifications.remove(at: index)
                }
                
                self.reloadDatasource()
                
            } else if errorCode != 0 {
                NCContentPresenter.shared.messageNotification("_error_", description: message, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
            } else {
                print("[LOG] It has been changed user during networking process, error.")
            }
        })
    }

    func tapAction(with notification: OCNotifications?, label: String) {
        
        for action in notification!.actions {
            
            if (action as! OCNotificationsAction).label == label {
                
                OCNetworking.sharedManager().setNotificationWithAccount(self.appDelegate.activeAccount, serverUrl: (action as! OCNotificationsAction).link, type: (action as! OCNotificationsAction).type, completion: { (account, message, errorCode) in
                    
                    if errorCode == 0 && account == self.appDelegate.activeAccount {
                                                
                        if let index = CCNotification.self.notifications.firstIndex(where: {$0.idNotification == notification!.idNotification})  {
                            CCNotification.self.notifications.remove(at: index)
                        }
                        
                        self.reloadDatasource()
                        
                    } else if errorCode != 0 {
                        NCContentPresenter.shared.messageNotification("_error_", description: message, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                    } else {
                        print("[LOG] It has been changed user during networking process, error.")
                    }
                })
            }
        }
    }
    
    // MARK: Load notification networking
    func getNetwokingNotification() {
    
        NCUtility.sharedInstance.startActivityIndicator(view: self.navigationController?.view, bottom: 0)

        // Verify User
        if appDelegate.activeAccount != CCNotification.notificationsAccount {
            CCNotification.notifications.removeAll()
            reloadDatasource()
            CCNotification.notificationsAccount = appDelegate.activeAccount
        }
                
        OCNetworking.sharedManager().getNotificationWithAccount(CCNotification.notificationsAccount, completion: { (account, listOfNotifications, message, errorCode) in
            
            if errorCode == 0 && account == CCNotification.self.notificationsAccount {
                    
                CCNotification.self.notifications.removeAll()
                let sortedListOfNotifications = (listOfNotifications! as NSArray).sortedArray(using: [NSSortDescriptor(key: "date", ascending: false)])
                    
                for notification in sortedListOfNotifications {
                    // download icon
                    if let icon = (notification as! OCNotifications).icon {
                        NCUtility.sharedInstance.convertSVGtoPNGWriteToUserData(svgUrlString: icon, fileName: nil, width: 25, rewrite: false, account: self.appDelegate.activeAccount, closure: { (imageNamePath) in })
                    }
                    
                    CCNotification.self.notifications.append(notification as! OCNotifications)
                }
                
                self.reloadDatasource()
            }
            
            NCUtility.sharedInstance.stopActivityIndicator()
        })
    }
}

// MARK: - Class UITableViewCell

class CCNotificationCell: UITableViewCell {
    
    var delegate: CCNotificationCelllDelegate?
    var notification: OCNotifications?

    @IBOutlet weak var icon : UIImageView!
    @IBOutlet weak var avatar : UIImageView!
    @IBOutlet weak var date: UILabel!
    @IBOutlet weak var subject: UILabel!
    @IBOutlet weak var message: UILabel!
    @IBOutlet weak var remove: UIButton!
    @IBOutlet weak var primary: UIButton!
    @IBOutlet weak var secondary: UIButton!

    @IBOutlet weak var avatarLeadingMargin: NSLayoutConstraint!
    @IBOutlet weak var messageBottomMargin: NSLayoutConstraint!
    @IBOutlet weak var primaryWidth: NSLayoutConstraint!
    @IBOutlet weak var secondaryWidth: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    @IBAction func touchUpInsideRemove(_ sender: Any) {
        delegate?.tapRemove(with: notification)
    }
    
    @IBAction func touchUpInsidePrimary(_ sender: Any) {
        let button = sender as! UIButton
        delegate?.tapAction(with: notification, label: button.titleLabel!.text!)
    }
    
    @IBAction func touchUpInsideSecondary(_ sender: Any) {
        let button = sender as! UIButton
        delegate?.tapAction(with: notification, label: button.titleLabel!.text!)
    }
}

protocol CCNotificationCelllDelegate {
    func tapRemove(with notification: OCNotifications?)
    func tapAction(with notification: OCNotifications?, label: String)
}
