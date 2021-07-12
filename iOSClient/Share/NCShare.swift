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

import UIKit
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
    @IBOutlet weak var shareInternalLinkDescription: UILabel!
    @IBOutlet weak var buttonInternalCopy: UIButton!
    @IBOutlet weak var buttonCopy: UIButton!
    @IBOutlet weak var buttonMenu: UIButton!
    @IBOutlet weak var tableView: UITableView!
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

    public var metadata: tableMetadata?
    public var sharingEnabled = true
    public var height: CGFloat = 0
    
    private var shareLinkMenuView: NCShareLinkMenuView?
    private var shareUserMenuView: NCShareUserMenuView?
    private var shareMenuViewWindow: UIView?
    private var dropDown = DropDown()
    private var networking: NCShareNetworking?
    private var quickStatusTableShare: tableShare!
    
    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = NCBrandColor.shared.systemBackground

        viewContainerConstraint.constant = height
        searchFieldTopConstraint.constant = 10
                
        searchField.placeholder = NSLocalizedString("_shareLinksearch_placeholder_", comment: "")
        
        shareLinkImage.image = NCShareCommon.shared.createLinkAvatar(imageName: "sharebylink", colorCircle: NCBrandColor.shared.brandElement)
        shareLinkLabel.text = NSLocalizedString("_share_link_", comment: "")
        shareLinkLabel.textColor = NCBrandColor.shared.label
        buttonCopy.setImage(UIImage.init(named: "shareCopy")?.image(color: .gray, size: 50), for: .normal)

        shareInternalLinkImage.image = NCShareCommon.shared.createLinkAvatar(imageName: "shareInternalLink", colorCircle: .gray)
        shareInternalLinkLabel.text = NSLocalizedString("_share_internal_link_", comment: "")
        shareInternalLinkDescription.text = NSLocalizedString("_share_internal_link_des_", comment: "")
        buttonInternalCopy.setImage(UIImage.init(named: "shareCopy")?.image(color: .gray, size: 50), for: .normal)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsSelection = false
        tableView.backgroundColor = NCBrandColor.shared.systemBackground

        tableView.register(UINib.init(nibName: "NCShareLinkCell", bundle: nil), forCellReuseIdentifier: "cellLink")
        tableView.register(UINib.init(nibName: "NCShareUserCell", bundle: nil), forCellReuseIdentifier: "cellUser")
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataNCShare), object: nil)
        
        // Shared with you by ...
        if metadata!.ownerId != "" && metadata!.ownerId != self.appDelegate.userId {
            
            searchFieldTopConstraint.constant = 65
            sharedWithYouByView.isHidden = false
            sharedWithYouByLabel.text = NSLocalizedString("_shared_with_you_by_", comment: "") + " " + metadata!.ownerDisplayName
            sharedWithYouByImage.image = UIImage(named: "avatar")?.imageColor(NCBrandColor.shared.label)

            let fileNameLocalPath = String(CCUtility.getDirectoryUserData()) + "/" + String(CCUtility.getStringUser(appDelegate.user, urlBase: appDelegate.urlBase)) + "-" + metadata!.ownerId + ".png"
            if FileManager.default.fileExists(atPath: fileNameLocalPath) {
                if let image = UIImage(contentsOfFile: fileNameLocalPath) {
                    sharedWithYouByImage.image = NCUtility.shared.createAvatar(image: image, size: 40)
                }
            } else {
                NCCommunication.shared.downloadAvatar(user: metadata!.ownerId, fileNameLocalPath: fileNameLocalPath, size: NCGlobal.shared.avatarSize) { (account, data, errorCode, errorMessage) in
                    if errorCode == 0 && account == self.appDelegate.account && UIImage(data: data!) != nil {
                        if let image = UIImage(contentsOfFile: fileNameLocalPath) {
                            self.sharedWithYouByImage.image = NCUtility.shared.createAvatar(image: image, size: 40)
                        }
                    } 
                }
            }
        } 
        
        reloadData()
        
        networking = NCShareNetworking.init(metadata: metadata!, urlBase: appDelegate.urlBase, view: self.view, delegate: self)
        if sharingEnabled {
            networking?.readShare()
        }
        
        // changeTheming
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(statusReadOnlyClicked), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterStatusReadOnly), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(statusEditingClicked), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterStatusEditing), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(statusFileDropClicked), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterStatusFileDrop), object: nil)
        
        changeTheming()
    }
    
    @objc func changeTheming() {
        tableView.reloadData()
    }
        
    @objc func reloadData() {
        let shares = NCManageDatabase.shared.getTableShares(metadata: metadata!)
        if shares.firstShareLink == nil {
            buttonMenu.setImage(UIImage.init(named: "shareAdd")?.image(color: .gray, size: 50), for: .normal)
            buttonCopy.isHidden = true
        } else {
            buttonMenu.setImage(UIImage.init(named: "shareMenu")?.image(color: .gray, size: 50), for: .normal)
            buttonCopy.isHidden = false
            
            shareLinkLabel.text = NSLocalizedString("_share_link_", comment: "")
            if shares.firstShareLink?.label.count ?? 0 > 0 {
                if let shareLinkLabel = shareLinkLabel {
                    if let label = shares.firstShareLink?.label {
                        shareLinkLabel.text = NSLocalizedString("_share_link_", comment: "") + " (" + label + ")"
                    }
                }
            }
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

        let shares = NCManageDatabase.shared.getTableShares(metadata: metadata)
        tapCopy(with: shares.firstShareLink, sender: sender)
    }
    
    @IBAction func touchUpInsideButtonCopyInernalLink(_ sender: Any) {
        
        guard let metadata = self.metadata else { return }
        
        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        NCNetworking.shared.readFile(serverUrlFileName: serverUrlFileName, account: metadata.account) { (account, metadata, errorCode, errorDescription) in
            if errorCode == 0 && metadata != nil {
                let internalLink = self.appDelegate.urlBase + "/index.php/f/" + metadata!.fileId
                NCShareCommon.shared.copyLink(link: internalLink, viewController: self, sender: sender)
            } else {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
            }
        }
    }
    
    @IBAction func touchUpInsideButtonMenu(_ sender: Any) {

        guard let metadata = self.metadata else { return }
        let isFilesSharingPublicPasswordEnforced = NCManageDatabase.shared.getCapabilitiesServerBool(account: metadata.account, elements: NCElementsJSON.shared.capabilitiesFileSharingPubPasswdEnforced, exists: false)
        let shares = NCManageDatabase.shared.getTableShares(metadata: metadata)

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
            NCShareCommon.shared.copyLink(link: link, viewController: self, sender: sender)
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
        
        networking?.updateShare(idShare: tableShare.idShare, password: nil, permission: permission, note: nil, label: nil, expirationDate: nil, hideDownload: tableShare.hideDownload)
    }
    
    func tapMenu(with tableShare: tableShare?, sender: Any) {
        
        guard let tableShare = tableShare else { return }

        if tableShare.shareType == 3 {
            let views = NCShareCommon.shared.openViewMenuShareLink(shareViewController: self, tableShare: tableShare, metadata: metadata!)
            shareLinkMenuView = views.shareLinkMenuView
            shareMenuViewWindow = views.viewWindow
            
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapLinkMenuViewWindow))
            tap.delegate = self
            shareMenuViewWindow?.addGestureRecognizer(tap)
        } else {
            let views = NCShareCommon.shared.openViewMenuUser(shareViewController: self, tableShare: tableShare, metadata: metadata!)
            shareUserMenuView = views.shareUserMenuView
            shareMenuViewWindow = views.viewWindow
            
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapLinkMenuViewWindow))
            tap.delegate = self
            shareMenuViewWindow?.addGestureRecognizer(tap)
        }
    }
    

    func quickStatus(with tableShare: tableShare?, sender: Any) {

            guard let tableShare = tableShare else { return }

            if tableShare.shareType != 3 {
                self.quickStatusTableShare = tableShare
                let quickStatusMenu = NCShareQuickStatusMenu()
                quickStatusMenu.toggleMenu(viewController: self, directory: metadata!.directory, status: tableShare.permissions)
            }
        }

    
    /// MARK: - NCShareNetworkingDelegate
    
    func readShareCompleted() {
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataNCShare)
    }
    
    func shareCompleted() {
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataNCShare)
    }
    
    func unShareCompleted() { }
    
    func updateShareWithError(idShare: Int) {
        self.reloadData()
    }
    
    func getSharees(sharees: [NCCommunicationSharee]?) {
        
        guard let sharees = sharees else { return }

        dropDown = DropDown()
        let appearance = DropDown.appearance()
        
        appearance.backgroundColor = NCBrandColor.shared.systemBackground
        appearance.cornerRadius = 10
        appearance.shadowColor = UIColor(white: 0.5, alpha: 1)
        appearance.shadowOpacity = 0.9
        appearance.shadowRadius = 25
        appearance.animationduration = 0.25
        appearance.textColor = .darkGray
        appearance.setupMaskedCorners([.layerMaxXMaxYCorner, .layerMinXMaxYCorner])
        
        for sharee in sharees {
            var label = sharee.label
            if sharee.shareType == NCShareCommon.shared.SHARE_TYPE_CIRCLE {
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
            cell.imageItem.image = NCShareCommon.shared.getImageShareType(shareType: sharee.shareType)
            let status = NCUtility.shared.getUserStatus(userIcon: sharee.userIcon, userStatus: sharee.userStatus, userMessage: sharee.userMessage)
            cell.imageStatus.image = status.onlineStatus
            cell.status.text = status.statusMessage
            if cell.status.text?.count ?? 0 > 0 {
                cell.centerTitle.constant = -5
            } else {
                cell.centerTitle.constant = 0
            }
            let fileNameLocalPath = String(CCUtility.getDirectoryUserData()) + "/" + String(CCUtility.getStringUser(self.appDelegate.user, urlBase: self.appDelegate.urlBase)) + "-" + sharee.label + ".png"
            NCOperationQueue.shared.downloadAvatar(user: sharee.shareWith, fileNameLocalPath: fileNameLocalPath, placeholder: UIImage(named: "avatar"), cell: cell, view: nil, indexPath: nil)
            cell.imageShareeType.image = NCShareCommon.shared.getImageShareType(shareType: sharee.shareType)
        }
        
        dropDown.selectionAction = { [weak self] (index, item) in
            let sharee = sharees[index]
            self!.networking?.createShare(shareWith: sharee.shareWith, shareType: sharee.shareType, metadata: self!.metadata!)
        }
        
        dropDown.show()
    }
    
    // MARK: -StatusChangeNotification
    @objc func statusReadOnlyClicked() {
        let permission = CCUtility.getPermissionsValue(byCanEdit: false, andCanCreate: false, andCanChange: false, andCanDelete: false, andCanShare: false, andIsFolder: metadata!.directory)
        
        networking?.updateShare(idShare: self.quickStatusTableShare.idShare, password: nil, permission: permission, note: nil, label: nil, expirationDate: nil, hideDownload: self.quickStatusTableShare.hideDownload)
    }
    
    @objc func statusEditingClicked() {
        let permission = CCUtility.getPermissionsValue(byCanEdit: true, andCanCreate: true, andCanChange: true, andCanDelete: true, andCanShare: false, andIsFolder: metadata!.directory)

        networking?.updateShare(idShare: self.quickStatusTableShare.idShare, password: nil, permission: permission, note: nil, label: nil, expirationDate: nil, hideDownload: self.quickStatusTableShare.hideDownload)
    }
    
    @objc func statusFileDropClicked() {
        let permission = NCGlobal.shared.permissionCreateShare

        networking?.updateShare(idShare: self.quickStatusTableShare.idShare, password: nil, permission: permission, note: nil, label: nil, expirationDate: nil, hideDownload: self.quickStatusTableShare.hideDownload)
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
        let shares = NCManageDatabase.shared.getTableShares(metadata: metadata!)
        
        if shares.share != nil {
            numOfRows = shares.share!.count
        }
        
        return numOfRows
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let shares = NCManageDatabase.shared.getTableShares(metadata: metadata!)
        let tableShare = shares.share![indexPath.row]
        
        // LINK
        if tableShare.shareType == 3 {
            if let cell = tableView.dequeueReusableCell(withIdentifier: "cellLink", for: indexPath) as? NCShareLinkCell {
                cell.tableShare = tableShare
                cell.delegate = self
                cell.labelTitle.text = NSLocalizedString("_share_link_", comment: "")
                if tableShare.label.count > 0 {
                    cell.labelTitle.text = NSLocalizedString("_share_link_", comment: "") + " (" + tableShare.label + ")"
                }
                cell.labelTitle.textColor = NCBrandColor.shared.label
                return cell
            }
        } else {
        // USER
            if let cell = tableView.dequeueReusableCell(withIdentifier: "cellUser", for: indexPath) as? NCShareUserCell {
                
                cell.tableShare = tableShare
                cell.delegate = self
                cell.labelTitle.text = tableShare.shareWithDisplayname
                cell.labelTitle.textColor = NCBrandColor.shared.label
                cell.labelCanEdit.text = NSLocalizedString("_share_permission_edit_", comment: "")
                cell.labelCanEdit.textColor = NCBrandColor.shared.label
                cell.isUserInteractionEnabled = true

                cell.switchCanEdit.isHidden = true//false
                cell.labelCanEdit.isHidden = true//false

                cell.buttonMenu.isHidden = false
                cell.imageItem.image = NCShareCommon.shared.getImageShareType(shareType: tableShare.shareType)
                
                let status = NCUtility.shared.getUserStatus(userIcon: tableShare.userIcon, userStatus: tableShare.userStatus, userMessage: tableShare.userMessage)
                cell.imageStatus.image = status.onlineStatus
                cell.status.text = status.statusMessage
                
                let fileNameLocalPath = String(CCUtility.getDirectoryUserData()) + "/" + String(CCUtility.getStringUser(appDelegate.user, urlBase: appDelegate.urlBase)) + "-" + tableShare.shareWith + ".png"
                NCOperationQueue.shared.downloadAvatar(user: tableShare.shareWith, fileNameLocalPath: fileNameLocalPath, placeholder: UIImage(named: "avatar"), cell: cell, view: tableView, indexPath: indexPath)
                
                if CCUtility.isAnyPermission(toEdit: tableShare.permissions) {
                    cell.switchCanEdit.setOn(true, animated: false)
                } else {
                    cell.switchCanEdit.setOn(false, animated: false)
                }
                
                // If the initiator or the recipient is not the current user, show the list of sharees without any options to edit it.
                if tableShare.uidOwner != self.appDelegate.userId && tableShare.uidFileOwner != self.appDelegate.userId {
                    cell.isUserInteractionEnabled = false
//                    cell.switchCanEdit.isHidden = true
//                    cell.labelCanEdit.isHidden = true
                    cell.buttonMenu.isHidden = true
                }
                
                cell.btnQuickStatus.setTitle("", for: .normal)
                cell.btnQuickStatus.contentHorizontalAlignment = .left
                
                if tableShare.permissions == NCGlobal.shared.permissionCreateShare {
                    cell.labelQuickStatus.text = NSLocalizedString("_share_file_drop_", comment: "")
                } else {
                    // Read Only
                    if CCUtility.isAnyPermission(toEdit: tableShare.permissions) {
                        cell.labelQuickStatus.text = NSLocalizedString("_share_editing_", comment: "")
                    } else {
                        cell.labelQuickStatus.text = NSLocalizedString("_share_read_only_", comment: "")
                    }
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
        
        imageItem.image = NCShareCommon.shared.createLinkAvatar(imageName: "sharebylink", colorCircle: NCBrandColor.shared.brandElement)
        buttonCopy.setImage(UIImage.init(named: "shareCopy")!.image(color: .gray, size: 50), for: .normal)
        buttonMenu.setImage(UIImage.init(named: "shareMenu")!.image(color: .gray, size: 50), for: .normal)
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

class NCShareUserCell: UITableViewCell, NCCellProtocol {
    
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var labelCanEdit: UILabel!
    @IBOutlet weak var switchCanEdit: UISwitch!
    @IBOutlet weak var buttonMenu: UIButton!
    @IBOutlet weak var imageStatus: UIImageView!
    @IBOutlet weak var status: UILabel!

    @IBOutlet weak var btnQuickStatus: UIButton!
    @IBOutlet weak var labelQuickStatus: UILabel!
    @IBOutlet weak var imageDownArrow: UIImageView!

//
//    @IBOutlet weak var labelQuickStatus: UILabel!
//    @IBOutlet weak var imageDownArrow: UIImageView!
    
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
    
    var tableShare: tableShare?
    var delegate: NCShareUserCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        switchCanEdit.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchCanEdit.onTintColor = NCBrandColor.shared.brandElement
        buttonMenu.setImage(UIImage.init(named: "shareMenu")!.image(color: .gray, size: 50), for: .normal)
        labelQuickStatus.textColor = NCBrandColor.shared.customer
        imageDownArrow.image = UIImage(named: "downArrow")?.imageColor(NCBrandColor.shared.customer)
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

class NCShareUserDropDownCell: DropDownCell, NCCellProtocol {
    
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var imageStatus: UIImageView!
    @IBOutlet weak var status: UILabel!
    @IBOutlet weak var imageShareeType: UIImageView!
    @IBOutlet weak var centerTitle: NSLayoutConstraint!
    
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
}
