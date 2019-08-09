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
        
        let fileNameLocalPath = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(appDelegate.activeUser, activeUrl: appDelegate.activeUrl) + "-" + appDelegate.activeUser + ".png"
        if FileManager.default.fileExists(atPath: fileNameLocalPath) {
            if let image = UIImage(contentsOfFile: fileNameLocalPath) {
                imageItem.image = image
            }
        }
        
        reloadData()
    }
    
    @objc func reloadData() {
        
        guard let metadata = self.metadata else { return }

        OCNetworking.sharedManager()?.getCommentsWithAccount(appDelegate.activeAccount, fileID: metadata.fileID, completion: { (account, items, message, errorCode) in
            if errorCode == 0 {
                let itemsNCComments = items as! [NCComments]
                NCManageDatabase.sharedInstance.addComments(itemsNCComments, account: metadata.account, fileID: metadata.fileID)
                self.tableView.reloadData()
            } else {
                self.appDelegate.messageNotification("_share_", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            }
        })
        
        tableView.reloadData()
    }
    
    // MARK: - IBAction
    
    @IBAction func newCommentFieldDidEndOnExit(textField: UITextField) {
        
        guard let message = textField.text else { return }
        guard let metadata = self.metadata else { return }

        OCNetworking.sharedManager()?.putComments(withAccount: appDelegate.activeAccount, fileID: metadata.fileID, message: message, completion: { (account, message, errorCode) in
            if errorCode == 0 {
                self.newCommentField.text = ""
                self.reloadData()
            } else {
                self.appDelegate.messageNotification("_share_", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            }
        })
    }
    
    func tapMenu(with tableComments: tableComments?, sender: Any) {
        
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
        
        let comments = NCManageDatabase.sharedInstance.getComments(account: metadata!.account, fileID: metadata!.fileID)
        return comments.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let comments = NCManageDatabase.sharedInstance.getComments(account: metadata!.account, fileID: metadata!.fileID)
        let tableComments = comments[indexPath.row]
        
        if let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as? NCShareCommentsCell {
            
            cell.tableComments = tableComments
            cell.delegate = self
            cell.sizeToFit()
            
            // Image
            let fileNameLocalPath = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(appDelegate.activeUser, activeUrl: appDelegate.activeUrl) + "-" + tableComments.actorId + ".png"
            if FileManager.default.fileExists(atPath: fileNameLocalPath) {
                if let image = UIImage(contentsOfFile: fileNameLocalPath) {
                    cell.imageItem.image = image
                }
            } else {
                DispatchQueue.global().async {
                    let url = self.appDelegate.activeUrl + k_avatar + tableComments.actorId + "/128"
                    let encodedString = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                    OCNetworking.sharedManager()?.downloadContents(ofUrl: encodedString, completion: { (data, message, errorCode) in
                        if errorCode == 0 && UIImage(data: data!) != nil {
                            do {
                                try data!.write(to: NSURL(fileURLWithPath: fileNameLocalPath) as URL, options: .atomic)
                            } catch { return }
                            cell.imageItem.image = UIImage(data: data!)
                        } else {
                            cell.imageItem.image = UIImage(named: "avatar")
                        }
                    })
                }
            }
            // Username
            cell.labelUser.text = tableComments.actorDisplayName
            // Date
            cell.labelDate.text = CCUtility.dateDiff(tableComments.creationDateTime as Date)
            // Message
            cell.labelMessage.text = tableComments.message
            
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
