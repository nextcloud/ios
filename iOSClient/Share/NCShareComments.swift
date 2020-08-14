//
//  NCShareComments.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 28/07/2019.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
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
import NCCommunication

class NCShareComments: UIViewController, NCShareCommentsCellDelegate {
   
    @IBOutlet weak var viewContainerConstraint: NSLayoutConstraint!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var labelUser: UILabel!
    @IBOutlet weak var newCommentField: UITextField!

    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

    var metadata: tableMetadata?
    public var height: CGFloat = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewContainerConstraint.constant = height
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = tableView.bounds.height
        tableView.allowsSelection = false
        tableView.backgroundColor = NCBrandColor.sharedInstance.backgroundForm
        tableView.separatorColor = NCBrandColor.sharedInstance.separator
        
        tableView.register(UINib.init(nibName: "NCShareCommentsCell", bundle: nil), forCellReuseIdentifier: "cell")

        newCommentField.placeholder = NSLocalizedString("_new_comment_", comment: "")
        
        // Display Name user & Quota
        guard let tabAccount = NCManageDatabase.sharedInstance.getAccountActive() else {
            return
        }
        
        if tabAccount.displayName.isEmpty {
            labelUser.text = tabAccount.user
        }
        else{
            labelUser.text = tabAccount.displayName
        }
        
        let fileNameLocalPath = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(appDelegate.user, urlBase: appDelegate.urlBase) + "-" + appDelegate.user + ".png"
        if FileManager.default.fileExists(atPath: fileNameLocalPath) {
            if let image = UIImage(contentsOfFile: fileNameLocalPath) {
                imageItem.image = image
            }
        }
        
        // Mark comment ad read
        if metadata != nil && metadata!.commentsUnread {
            NCCommunication.shared.markAsReadComments(fileId: metadata!.fileId) { (account, errorCode, errorDescription) in
                if errorCode == 0 {
                    NCManageDatabase.sharedInstance.readMarkerMetadata(account: account, fileId: self.metadata!.fileId)
                }
            }
        }
        
        // changeTheming
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
        changeTheming()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        reloadData()
    }
    
    @objc func changeTheming() {
        appDelegate.changeTheming(self, tableView: tableView, collectionView: nil, form: true)
        
        labelUser.textColor = NCBrandColor.sharedInstance.textView
    }
    
    @objc func reloadData() {
        
        guard let metadata = self.metadata else { return }

        NCCommunication.shared.getComments(fileId: metadata.fileId) { (account, comments, errorCode, errorDescription) in
            if errorCode == 0 && comments != nil {
                NCManageDatabase.sharedInstance.addComments(comments!, account: metadata.account, objectId: metadata.fileId)
                self.tableView.reloadData()
            } else {
               NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
            }
        }
        
        tableView.reloadData()
    }
    
    // MARK: - IBAction & Tap
    
    @IBAction func newCommentFieldDidEndOnExit(textField: UITextField) {
        
        guard let message = textField.text else { return }
        guard let metadata = self.metadata else { return }
        if message.count == 0 { return }

        NCCommunication.shared.putComments(fileId: metadata.fileId, message: message) { (account, errorCode, errorDescription) in
            if errorCode == 0 {
                self.newCommentField.text = ""
                self.reloadData()
            } else {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
            }
        }
    }
    
    func tapMenu(with tableComments: tableComments?, sender: Any) {
        let mainMenuViewController = UIStoryboard.init(name: "NCMenu", bundle: nil).instantiateViewController(withIdentifier: "NCMainMenuTableViewController") as! NCMainMenuTableViewController

        var actions = [NCMenuAction]()

        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_edit_comment_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "edit"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                    guard let metadata = self.metadata else { return }
                    guard let tableComments = tableComments else { return }
                    
                    let alert = UIAlertController(title: NSLocalizedString("_edit_comment_", comment: ""), message: nil, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: nil))
                    
                    alert.addTextField(configurationHandler: { textField in
                        textField.placeholder = NSLocalizedString("_new_comment_", comment: "")
                    })
                    
                    alert.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { action in
                        if let message = alert.textFields?.first?.text {
                            if message != "" {
                                NCCommunication.shared.updateComments(fileId: metadata.fileId, messageId: tableComments.messageId, message: message) { (account, errorCode, errorDescription) in
                                    if errorCode == 0 {
                                        self.reloadData()
                                    } else {
                                        NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                                    }
                                }
                            }
                        }
                    }))
                    
                    self.present(alert, animated: true)
                }
            )
        )
        
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_delete_comment_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "trash"), width: 50, height: 50, color: .red),
                action: { menuAction in
                    guard let metadata = self.metadata else { return }
                    guard let tableComments = tableComments else { return }

                    NCCommunication.shared.deleteComments(fileId: metadata.fileId, messageId: tableComments.messageId) { (account, errorCode, errorDescription) in
                        if errorCode == 0 {
                            self.reloadData()
                        } else {
                            NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
                        }
                    }
                }
            )
        )
        
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_cancel_", comment: ""),
                icon: CCGraphics.changeThemingColorImage(UIImage(named: "cancel"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon),
                action: { menuAction in
                }
            )
        )
        
        mainMenuViewController.actions = actions

        let menuPanelController = NCMenuPanelController()
        menuPanelController.parentPresenter = self
        menuPanelController.delegate = mainMenuViewController
        menuPanelController.set(contentViewController: mainMenuViewController)
        menuPanelController.track(scrollView: mainMenuViewController.tableView)
        self.present(menuPanelController, animated: true, completion: nil)
    }
}

// MARK: - UITableViewDelegate

extension NCShareComments: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}

// MARK: - UITableViewDataSource

extension NCShareComments: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        let comments = NCManageDatabase.sharedInstance.getComments(account: metadata!.account, objectId: metadata!.fileId)
        return comments.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let comments = NCManageDatabase.sharedInstance.getComments(account: metadata!.account, objectId: metadata!.fileId)
        let tableComments = comments[indexPath.row]
        
        if let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as? NCShareCommentsCell {
            
            cell.tableComments = tableComments
            cell.delegate = self
            cell.sizeToFit()
            
            // Image
            let fileNameLocalPath = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(appDelegate.user, urlBase: appDelegate.urlBase) + "-" + tableComments.actorId + ".png"
            if FileManager.default.fileExists(atPath: fileNameLocalPath) {
                if let image = UIImage(contentsOfFile: fileNameLocalPath) { cell.imageItem.image = image }
            } else {
                DispatchQueue.global().async {
                    NCCommunication.shared.downloadAvatar(userID: tableComments.actorId, fileNameLocalPath: fileNameLocalPath, size: 128) { (account, data, errorCode, errorMessage) in
                        if errorCode == 0 && UIImage(data: data!) != nil {
                            cell.imageItem.image = UIImage(named: "avatar")
                        }
                    }
                    /*
                    let url = self.appDelegate.urlBase + k_avatar + tableComments.actorId + "/" + k_avatar_size
                    let encodedString = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                    OCNetworking.sharedManager()?.downloadContents(ofUrl: encodedString, completion: { (data, message, errorCode) in
                        if errorCode == 0 && UIImage(data: data!) != nil {
                            do {
                                try data!.write(to: NSURL(fileURLWithPath: fileNameLocalPath) as URL, options: .atomic)
                                if let image = UIImage(contentsOfFile: fileNameLocalPath) { cell.imageItem.image = image }
                            } catch { return }
                        } else {
                            cell.imageItem.image = UIImage(named: "avatar")
                        }
                    })
                    */
                }
            }
            // Username
            cell.labelUser.text = tableComments.actorDisplayName
            cell.labelUser.textColor = NCBrandColor.sharedInstance.textView
            // Date
            cell.labelDate.text = CCUtility.dateDiff(tableComments.creationDateTime as Date)
            cell.labelDate.textColor = NCBrandColor.sharedInstance.graySoft
            // Message
            cell.labelMessage.text = tableComments.message
            cell.labelMessage.textColor = NCBrandColor.sharedInstance.textView
            // Button Menu
            if tableComments.actorId == appDelegate.userID {
                cell.buttonMenu.isHidden = false
            } else {
                cell.buttonMenu.isHidden = true
            }
            
            return cell
        }
        
        return UITableViewCell()
    }
}

// MARK: - NCShareCommentsCell

class NCShareCommentsCell: UITableViewCell {
    
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var labelUser: UILabel!
    @IBOutlet weak var buttonMenu: UIButton!
    @IBOutlet weak var labelDate: UILabel!
    @IBOutlet weak var labelMessage: UILabel!
    
    var tableComments: tableComments?
    var delegate: NCShareCommentsCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        buttonMenu.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "shareMenu"), width:100, height: 100, color: UIColor.lightGray), for: .normal)
    }
    
    @IBAction func touchUpInsideMenu(_ sender: Any) {
        delegate?.tapMenu(with: tableComments, sender: sender)
    }
}

protocol NCShareCommentsCellDelegate {
    func tapMenu(with tableComments: tableComments?, sender: Any)
}
