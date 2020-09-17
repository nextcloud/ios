//
//  NCShare.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 17/07/2019.
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
import Parchment
import DropDown
import NCCommunication

class NCShare: UIViewController, UIGestureRecognizerDelegate, NCShareLinkCellDelegate, NCShareUserCellDelegate, NCShareNetworkingDelegate {
   
    @IBOutlet weak var viewContainerConstraint: NSLayoutConstraint!
    @IBOutlet weak var sharedWithYouByView: UIView!
    @IBOutlet weak var sharedWithYouByImage: UIImageView!
    @IBOutlet weak var sharedWithYouByLabel: UILabel!
    @IBOutlet weak var searchFieldTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var searchField: UITextField!
    @IBOutlet weak var shareLinkImage: UIImageView!
    @IBOutlet weak var shareLinkLabel: UILabel!
    @IBOutlet weak var shareInternalLinkImage: UIImageView!
    @IBOutlet weak var shareInternalLinkLabel: UILabel!
    @IBOutlet weak var buttonInternalCopy: UIButton!
    @IBOutlet weak var buttonCopy: UIButton!
    @IBOutlet weak var buttonMenu: UIButton!
    @IBOutlet weak var tableView: UITableView!
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

    var metadata: tableMetadata?
    public var height: CGFloat = 0
    private var shareLinkMenuView: NCShareLinkMenuView?
    private var shareUserMenuView: NCShareUserMenuView?
    private var shareMenuViewWindow: UIView?
    private var dropDown = DropDown()
    private var networking: NCShareNetworking?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewContainerConstraint.constant = height
        searchFieldTopConstraint.constant = 10
        
        searchField.placeholder = NSLocalizedString("_shareLinksearch_placeholder_", comment: "")
        
        shareLinkImage.image = NCShareCommon.sharedInstance.createLinkAvatar(imageName: "sharebylink", colorCircle: NCBrandColor.sharedInstance.brandElement)
        shareLinkLabel.text = NSLocalizedString("_share_link_", comment: "")
        buttonCopy.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "shareCopy"), width: 100, height: 100, color: .gray), for: .normal)

        shareInternalLinkImage.image = NCShareCommon.sharedInstance.createLinkAvatar(imageName: "shareInternalLink", colorCircle: .gray)
        shareInternalLinkLabel.text = NSLocalizedString("_share_internal_link_", comment: "")
        buttonInternalCopy.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "shareCopy"), width: 100, height: 100, color: .gray), for: .normal)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsSelection = false

        tableView.register(UINib.init(nibName: "NCShareLinkCell", bundle: nil), forCellReuseIdentifier: "cellLink")
        tableView.register(UINib.init(nibName: "NCShareUserCell", bundle: nil), forCellReuseIdentifier: "cellUser")
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: NSNotification.Name(rawValue: k_notificationCenter_reloadDataNCShare), object: nil)
        
        // Shared with you by ...
        if metadata!.ownerId != self.appDelegate.userID {
            
            searchFieldTopConstraint.constant = 65
            sharedWithYouByView.isHidden = false
            sharedWithYouByLabel.text = NSLocalizedString("_shared_with_you_by_", comment: "") + " " + metadata!.ownerDisplayName
            
            let fileNameLocalPath = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(appDelegate.user, urlBase: appDelegate.urlBase) + "-" + metadata!.ownerId + ".png"
            if FileManager.default.fileExists(atPath: fileNameLocalPath) {
                if let image = UIImage(contentsOfFile: fileNameLocalPath) { sharedWithYouByImage.image = image }
            } else {
                NCCommunication.shared.downloadAvatar(userID: metadata!.ownerId, fileNameLocalPath: fileNameLocalPath, size: Int(k_avatar_size)) { (account, data, errorCode, errorMessage) in
                    if errorCode == 0 && account == self.appDelegate.account && UIImage(data: data!) != nil {
                        if let image = UIImage(contentsOfFile: fileNameLocalPath) {
                            self.sharedWithYouByImage.image = image
                        }
                    } else {
                        self.sharedWithYouByImage.image = UIImage(named: "avatar")
                    }
                }
            }
        } 
        
        reloadData()
        
        networking = NCShareNetworking.init(metadata: metadata!, urlBase: appDelegate.urlBase, view: self.view, delegate: self)
        networking?.readShare()
        
        // changeTheming
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
        changeTheming()
    }
    
    @objc func changeTheming() {
        appDelegate.changeTheming(self, tableView: tableView, collectionView: nil, form: true)
        
        shareLinkLabel.textColor = NCBrandColor.sharedInstance.textView
    }
        
    @objc func reloadData() {
        let shares = NCManageDatabase.sharedInstance.getTableShares(metadata: metadata!)
        if shares.firstShareLink == nil {
            buttonMenu.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "shareAdd"), width: 100, height: 100, color: UIColor.gray), for: .normal)
            buttonCopy.isHidden = true
        } else {
            buttonMenu.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "shareMenu"), width: 100, height: 100, color: UIColor.gray), for: .normal)
            buttonCopy.isHidden = false
        }
        tableView.reloadData()
    }
    
    // MARK: - IBAction

    @IBAction func searchFieldDidEndOnExit(textField: UITextField) {
        
        guard let searchString = textField.text else { return }

        networking?.getSharees(searchString: searchString)
    }
    
    @IBAction func touchUpInsideButtonCopy(_ sender: Any) {
        
        guard let metadata = self.metadata else { return }

        let shares = NCManageDatabase.sharedInstance.getTableShares(metadata: metadata)
        tapCopy(with: shares.firstShareLink, sender: sender)
    }
    
    @IBAction func touchUpInsideButtonCopyInernalLink(_ sender: Any) {
        
        guard let metadata = self.metadata else { return }
        
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        NCNetworking.shared.readFile(serverUrlFileName: serverUrlFileName, account: metadata.account) { (account, metadata, errorCode, errorDescription) in
            if errorCode == 0 && metadata != nil {
                let internalLink = self.appDelegate.urlBase + "/index.php/f/" + metadata!.fileId
                NCShareCommon.sharedInstance.copyLink(link: internalLink, viewController: self, sender: sender)
            } else {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: errorCode)
            }
        }
    }
    
    @IBAction func touchUpInsideButtonMenu(_ sender: Any) {

        guard let metadata = self.metadata else { return }
        let isFilesSharingPublicPasswordEnforced = NCManageDatabase.sharedInstance.getCapabilitiesServerBool(account: metadata.account, elements: NCElementsJSON.shared.capabilitiesFileSharingPubPasswdEnforced, exists: false)
        let shares = NCManageDatabase.sharedInstance.getTableShares(metadata: metadata)

        if isFilesSharingPublicPasswordEnforced && shares.firstShareLink == nil {
            let alertController = UIAlertController(title: NSLocalizedString("_enforce_password_protection_", comment: ""), message: "", preferredStyle: .alert)
            alertController.addTextField { (textField) in
                textField.isSecureTextEntry = true
            }
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .default) { (action:UIAlertAction) in })
            let okAction = UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default) { (action:UIAlertAction) in
                let password = alertController.textFields?.first?.text
                self.networking?.createShareLink(password: password ?? "")
            }
            
            alertController.addAction(okAction)
            
            self.present(alertController, animated: true, completion:nil)
        } else if shares.firstShareLink == nil {
            networking?.createShareLink(password: "")
        } else {
            tapMenu(with: shares.firstShareLink!, sender: sender)
        }
    }
    
    @objc func tapLinkMenuViewWindow(gesture: UITapGestureRecognizer) {
        shareLinkMenuView?.unLoad()
        shareLinkMenuView = nil
        shareUserMenuView?.unLoad()
        shareUserMenuView = nil
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return gestureRecognizer.view == touch.view
    }
    
    func tapCopy(with tableShare: tableShare?, sender: Any) {
        
        if let link = tableShare?.url {
            NCShareCommon.sharedInstance.copyLink(link: link, viewController: self, sender: sender)
        }
    }
    
    func switchCanEdit(with tableShare: tableShare?, switch: Bool, sender: UISwitch) {
        
        guard let tableShare = tableShare else { return }
        guard let metadata = self.metadata else { return }

        let canShare = CCUtility.isPermission(toCanShare: tableShare.permissions)
        var permission: Int = 0
        
        if sender.isOn {
            permission = CCUtility.getPermissionsValue(byCanEdit: true, andCanCreate: true, andCanChange: true, andCanDelete: true, andCanShare: canShare, andIsFolder: metadata.directory)
        } else {
            permission = CCUtility.getPermissionsValue(byCanEdit: false, andCanCreate: false, andCanChange: false, andCanDelete: false, andCanShare: canShare, andIsFolder: metadata.directory)
        }
        
        networking?.updateShare(idShare: tableShare.idShare, password: nil, permission: permission, note: nil, expirationDate: nil, hideDownload: tableShare.hideDownload)
    }
    
    func tapMenu(with tableShare: tableShare?, sender: Any) {
        
        guard let tableShare = tableShare else { return }

        if tableShare.shareType == 3 {
            let views = NCShareCommon.sharedInstance.openViewMenuShareLink(shareViewController: self, tableShare: tableShare, metadata: metadata!)
            shareLinkMenuView = views.shareLinkMenuView
            shareMenuViewWindow = views.viewWindow
            
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapLinkMenuViewWindow))
            tap.delegate = self
            shareMenuViewWindow?.addGestureRecognizer(tap)
        } else {
            let views = NCShareCommon.sharedInstance.openViewMenuUser(shareViewController: self, tableShare: tableShare, metadata: metadata!)
            shareUserMenuView = views.shareUserMenuView
            shareMenuViewWindow = views.viewWindow
            
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapLinkMenuViewWindow))
            tap.delegate = self
            shareMenuViewWindow?.addGestureRecognizer(tap)
        }
    }
    
    /// MARK: - NCShareNetworkingDelegate
    
    func readShareCompleted() {
        NotificationCenter.default.postOnMainThread(name: k_notificationCenter_reloadDataNCShare)
    }
    
    func shareCompleted() {
        NotificationCenter.default.postOnMainThread(name: k_notificationCenter_reloadDataNCShare)
    }
    
    func unShareCompleted() { }
    
    func updateShareWithError(idShare: Int) { }
    
    func getSharees(sharees: [NCCommunicationSharee]?) {
        
        guard let sharees = sharees else { return }

        dropDown = DropDown()
        let appearance = DropDown.appearance()
        
        appearance.backgroundColor = .white
        appearance.cornerRadius = 10
        appearance.shadowColor = UIColor(white: 0.5, alpha: 1)
        appearance.shadowOpacity = 0.9
        appearance.shadowRadius = 25
        appearance.animationduration = 0.25
        appearance.textColor = .darkGray
        appearance.setupMaskedCorners([.layerMaxXMaxYCorner, .layerMinXMaxYCorner])
        
        for sharee in sharees {
            var label = sharee.label
            if sharee.shareType == NCShareCommon.sharedInstance.SHARE_TYPE_CIRCLE {
                label = label + " (" + sharee.circleInfo + ", " +  sharee.circleOwner + ")"
            }
            dropDown.dataSource.append(label)
        }
        
        dropDown.anchorView = searchField
        dropDown.bottomOffset = CGPoint(x: 0, y: searchField.bounds.height)
        dropDown.width = searchField.bounds.width
        dropDown.direction = .bottom
        
        dropDown.cellNib = UINib(nibName: "NCShareUserDropDownCell", bundle: nil)
        dropDown.customCellConfiguration = { (index: Index, item: String, cell: DropDownCell) -> Void in
            guard let cell = cell as? NCShareUserDropDownCell else { return }
            let sharee = sharees[index]
            cell.imageItem.image = NCShareCommon.sharedInstance.getImageShareType(shareType: sharee.shareType)

            let fileNameLocalPath = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(self.appDelegate.user, urlBase: self.appDelegate.urlBase) + "-" + sharee.label + ".png"
            if FileManager.default.fileExists(atPath: fileNameLocalPath) {
                if let image = UIImage(contentsOfFile: fileNameLocalPath) { cell.imageItem.image = image }
            } else {
                DispatchQueue.global().async {
                    NCCommunication.shared.downloadAvatar(userID: sharee.shareWith, fileNameLocalPath: fileNameLocalPath, size: Int(k_avatar_size)) { (account, data, errorCode, errorMessage) in
                        if errorCode == 0 && account == self.appDelegate.account && UIImage(data: data!) != nil {
                            if let image = UIImage(contentsOfFile: fileNameLocalPath) {
                                DispatchQueue.main.async {
                                    cell.imageItem.image = image
                                }
                            }
                        } 
                    }
                }
            }

            cell.imageShareeType.image = NCShareCommon.sharedInstance.getImageShareType(shareType: sharee.shareType)
        }
        
        dropDown.selectionAction = { [weak self] (index, item) in
            let sharee = sharees[index]
            self!.networking?.createShare(shareWith: sharee.shareWith, shareType: sharee.shareType, metadata: self!.metadata!)
        }
        
        dropDown.show()
    }
}

// MARK: - UITableViewDelegate

extension NCShare: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}

// MARK: - UITableViewDataSource

extension NCShare: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        var numOfRows = 0
        let shares = NCManageDatabase.sharedInstance.getTableShares(metadata: metadata!)
        
        if shares.share != nil {
            numOfRows = shares.share!.count
        }
        
        return numOfRows
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let shares = NCManageDatabase.sharedInstance.getTableShares(metadata: metadata!)
        let tableShare = shares.share![indexPath.row]
        
        // LINK
        if tableShare.shareType == 3 {
            if let cell = tableView.dequeueReusableCell(withIdentifier: "cellLink", for: indexPath) as? NCShareLinkCell {
                cell.tableShare = tableShare
                cell.delegate = self
                cell.labelTitle.text = NSLocalizedString("_share_link_", comment: "")
                cell.labelTitle.textColor = NCBrandColor.sharedInstance.textView
                return cell
            }
        } else {
        // USER
            if let cell = tableView.dequeueReusableCell(withIdentifier: "cellUser", for: indexPath) as? NCShareUserCell {
                
                cell.tableShare = tableShare
                cell.delegate = self
                cell.labelTitle.text = tableShare.shareWithDisplayname
                cell.labelTitle.textColor = NCBrandColor.sharedInstance.textView
                cell.labelCanEdit.text = NSLocalizedString("_share_permission_edit_", comment: "")
                cell.labelCanEdit.textColor = NCBrandColor.sharedInstance.textView
                cell.isUserInteractionEnabled = true
                cell.switchCanEdit.isHidden = false
                cell.labelCanEdit.isHidden = false
                cell.buttonMenu.isHidden = false
                cell.imageItem.image = NCShareCommon.sharedInstance.getImageShareType(shareType: tableShare.shareType)
                
                let fileNameLocalPath = CCUtility.getDirectoryUserData() + "/" + CCUtility.getStringUser(appDelegate.user, urlBase: appDelegate.urlBase) + "-" + tableShare.shareWith + ".png"
                if FileManager.default.fileExists(atPath: fileNameLocalPath) {
                    if let image = UIImage(contentsOfFile: fileNameLocalPath) { cell.imageItem.image = image }
                } else {
                    DispatchQueue.global().async {
                        NCCommunication.shared.downloadAvatar(userID: tableShare.shareWith, fileNameLocalPath: fileNameLocalPath, size: Int(k_avatar_size)) { (account, data, errorCode, errorMessage) in
                            if errorCode == 0 && account == self.appDelegate.account && UIImage(data: data!) != nil {
                                if let image = UIImage(contentsOfFile: fileNameLocalPath) {
                                    cell.imageItem.image = image
                                }
                            }
                        }
                    }
                }
                
                if CCUtility.isAnyPermission(toEdit: tableShare.permissions) {
                    cell.switchCanEdit.setOn(true, animated: false)
                } else {
                    cell.switchCanEdit.setOn(false, animated: false)
                }
                
                // If the initiator or the recipient is not the current user, show the list of sharees without any options to edit it.
                if tableShare.uidOwner != self.appDelegate.userID && tableShare.uidFileOwner != self.appDelegate.userID {
                    cell.isUserInteractionEnabled = false
                    cell.switchCanEdit.isHidden = true
                    cell.labelCanEdit.isHidden = true
                    cell.buttonMenu.isHidden = true
                }
                
                return cell
            }
        }
        
        return UITableViewCell()
    }
}

// MARK: - NCShareLinkCell

class NCShareLinkCell: UITableViewCell {
    
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var buttonCopy: UIButton!
    @IBOutlet weak var buttonMenu: UIButton!
    
    private let iconShare: CGFloat = 200
    
    var tableShare: tableShare?
    var delegate: NCShareLinkCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        imageItem.image = NCShareCommon.sharedInstance.createLinkAvatar(imageName: "sharebylink", colorCircle: NCBrandColor.sharedInstance.brandElement)
        buttonCopy.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "shareCopy"), width:100, height: 100, color: UIColor.gray), for: .normal)
        buttonMenu.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "shareMenu"), width:100, height: 100, color: UIColor.gray), for: .normal)
    }
    
    @IBAction func touchUpInsideCopy(_ sender: Any) {
        delegate?.tapCopy(with: tableShare, sender: sender)
    }
    
    @IBAction func touchUpInsideMenu(_ sender: Any) {
        delegate?.tapMenu(with: tableShare, sender: sender)
    }
}

protocol NCShareLinkCellDelegate {
    func tapCopy(with tableShare: tableShare?, sender: Any)
    func tapMenu(with tableShare: tableShare?, sender: Any)
}

// MARK: - NCShareUserCell

class NCShareUserCell: UITableViewCell {
    
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var labelCanEdit: UILabel!
    @IBOutlet weak var switchCanEdit: UISwitch!
    @IBOutlet weak var buttonMenu: UIButton!
    
    var tableShare: tableShare?
    var delegate: NCShareUserCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        switchCanEdit.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchCanEdit.onTintColor = NCBrandColor.sharedInstance.brandElement
        buttonMenu.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "shareMenu"), width:100, height: 100, color: UIColor.gray), for: .normal)
    }
    
    @IBAction func switchCanEditChanged(sender: UISwitch) {
        delegate?.switchCanEdit(with: tableShare, switch: sender.isOn, sender: sender)
    }
    
    @IBAction func touchUpInsideMenu(_ sender: Any) {
        delegate?.tapMenu(with: tableShare, sender: sender)
    }
}

protocol NCShareUserCellDelegate {
    func switchCanEdit(with tableShare: tableShare?, switch: Bool, sender: UISwitch)
    func tapMenu(with tableShare: tableShare?, sender: Any)
}

// MARK: - NCShareUserDropDownCell

class NCShareUserDropDownCell: DropDownCell {
    
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var imageShareeType: UIImageView!
}
