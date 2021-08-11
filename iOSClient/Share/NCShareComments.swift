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

import UIKit
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

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = NCBrandColor.shared.systemBackground
        viewContainerConstraint.constant = height
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = tableView.bounds.height
        tableView.allowsSelection = false
        tableView.backgroundColor = NCBrandColor.shared.systemBackground
        tableView.separatorColor = NCBrandColor.shared.separator
        
        tableView.register(UINib.init(nibName: "NCShareCommentsCell", bundle: nil), forCellReuseIdentifier: "cell")

        newCommentField.placeholder = NSLocalizedString("_new_comment_", comment: "")
        
        // Display Name user & Quota
        guard let activeAccount = NCManageDatabase.shared.getActiveAccount() else {
            return
        }
        
        if activeAccount.displayName.isEmpty {
            labelUser.text = activeAccount.user
        }
        else{
            labelUser.text = activeAccount.displayName
        }
        labelUser.textColor = NCBrandColor.shared.label
        
        imageItem.image = UIImage(named: "avatar")
        let fileNameLocalPath = String(CCUtility.getDirectoryUserData()) + "/" + String(CCUtility.getStringUser(appDelegate.user, urlBase: appDelegate.urlBase)) + "-" + appDelegate.user + ".png"
        if FileManager.default.fileExists(atPath: fileNameLocalPath) {
            if let image = UIImage(contentsOfFile: fileNameLocalPath) {
                imageItem.image = NCUtility.shared.createAvatar(image: image, size: 40)
            }
        }
        
        // Mark comment ad read
        if metadata != nil && metadata!.commentsUnread {
            NCCommunication.shared.markAsReadComments(fileId: metadata!.fileId) { (account, errorCode, errorDescription) in
                if errorCode == 0 {
                    NCManageDatabase.shared.readMarkerMetadata(account: account, fileId: self.metadata!.fileId)
                }
            }
        }
        
        // changeTheming
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)
        
        changeTheming()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        reloadData()
    }
    
    @objc func changeTheming() {
        tableView.reloadData()
    }
    
    @objc func reloadData() {
        
        guard let metadata = self.metadata else { return }

        NCCommunication.shared.getComments(fileId: metadata.fileId) { (account, comments, errorCode, errorDescription) in
            if errorCode == 0 && comments != nil {
                NCManageDatabase.shared.addComments(comments!, account: metadata.account, objectId: metadata.fileId)
                self.tableView.reloadData()
            } else {
                if errorCode != NCGlobal.shared.errorResourceNotFound {
                    NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                }
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
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
            }
        }
    }
    
    func tapMenu(with tableComments: tableComments?, sender: Any) {
       toggleMenu(with: tableComments)
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
        
        let comments = NCManageDatabase.shared.getComments(account: metadata!.account, objectId: metadata!.fileId)
        return comments.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let comments = NCManageDatabase.shared.getComments(account: metadata!.account, objectId: metadata!.fileId)
        let tableComments = comments[indexPath.row]
        
        if let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as? NCShareCommentsCell {
            
            cell.tableComments = tableComments
            cell.delegate = self
            cell.sizeToFit()
            
            // Image
            let fileNameLocalPath = String(CCUtility.getDirectoryUserData()) + "/" + String(CCUtility.getStringUser(appDelegate.user, urlBase: appDelegate.urlBase)) + "-" + tableComments.actorId + ".png"
            NCOperationQueue.shared.downloadAvatar(user: tableComments.actorId, fileNameLocalPath: fileNameLocalPath, imageAvatar: &cell.imageItem.image)
            // Username
            cell.labelUser.text = tableComments.actorDisplayName
            cell.labelUser.textColor = NCBrandColor.shared.label
            // Date
            cell.labelDate.text = CCUtility.dateDiff(tableComments.creationDateTime as Date)
            cell.labelDate.textColor = NCBrandColor.shared.systemGray4
            // Message
            cell.labelMessage.text = tableComments.message
            cell.labelMessage.textColor = NCBrandColor.shared.label
            // Button Menu
            if tableComments.actorId == appDelegate.userId {
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

class NCShareCommentsCell: UITableViewCell, NCCellProtocol {
    
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var labelUser: UILabel!
    @IBOutlet weak var buttonMenu: UIButton!
    @IBOutlet weak var labelDate: UILabel!
    @IBOutlet weak var labelMessage: UILabel!
    
    var filePreviewImageView : UIImageView? {
        get{
            return nil
        }
    }
    var avatarImageView: UIImageView? {
        get{
            return imageItem
        }
    }
    
    var tableComments: tableComments?
    var delegate: NCShareCommentsCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        buttonMenu.setImage(UIImage.init(named: "shareMenu")!.image(color: .lightGray, size: 50), for: .normal)
    }
    
    @IBAction func touchUpInsideMenu(_ sender: Any) {
        delegate?.tapMenu(with: tableComments, sender: sender)
    }
}

protocol NCShareCommentsCellDelegate {
    func tapMenu(with tableComments: tableComments?, sender: Any)
}
