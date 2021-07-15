//
//  NCPermissionMenuView.swift
//  Nextcloud
//
//  Created by T-systems on 15/06/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import Foundation
import FSCalendar
import NCCommunication

class NCPermissionMenuView: UIView, UIGestureRecognizerDelegate, NCShareNetworkingDelegate, FSCalendarDelegate, FSCalendarDelegateAppearance {
    @IBOutlet weak var switchReadOnly: UISwitch!
    @IBOutlet weak var labelReadOnly: UILabel!
    
    @IBOutlet weak var switchEditing: UISwitch!
    @IBOutlet weak var labelEditing: UILabel!
    
    @IBOutlet weak var switchFileDrop: UISwitch!
    @IBOutlet weak var labelFileDrop: UILabel!
    
    private var tableShare: tableShare?
    var metadata: tableMetadata?
    private var networking: NCShareNetworking?
    var width: CGFloat = 0
    var height: CGFloat = 0
    var viewWindow: UIView?
    var shareViewController: NCShare?
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    override func awakeFromNib() {
        
        layer.borderColor = UIColor.lightGray.cgColor
        layer.borderWidth = 0.5
        layer.cornerRadius = 5
        layer.masksToBounds = false
        layer.shadowOffset = CGSize(width: 2, height: 2)
        layer.shadowOpacity = 0.2
        
        switchReadOnly?.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchReadOnly?.onTintColor = NCBrandColor.shared.brandElement
        switchEditing?.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchEditing?.onTintColor = NCBrandColor.shared.brandElement
        switchFileDrop?.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchFileDrop?.onTintColor = NCBrandColor.shared.brandElement
        
        labelReadOnly?.text = NSLocalizedString("_share_read_only_", comment: "")
        labelReadOnly?.textColor = NCBrandColor.shared.label
        labelEditing?.text = NSLocalizedString("_share_editing_", comment: "")
        labelEditing?.textColor = NCBrandColor.shared.label
        labelFileDrop?.text = NSLocalizedString("_share_file_drop_", comment: "")
        labelFileDrop?.textColor = NCBrandColor.shared.label
    }
    
    func reloadData(idShare: Int) {
        
        guard let metadata = self.metadata else { return }
        tableShare = NCManageDatabase.shared.getTableShare(account: metadata.account, idShare: idShare)
        guard let tableShare = self.tableShare else { return }

        // Can reshare (file)
//        let canReshare = CCUtility.isPermission(toCanShare: tableShare.permissions)
//        switchCanReshare.setOn(canReshare, animated: false)
        
        if metadata.directory {
            // File Drop4
            if tableShare.permissions == NCGlobal.shared.permissionCreateShare {
                switchReadOnly.setOn(false, animated: false)
                switchEditing.setOn(false, animated: false)
                switchFileDrop.setOn(true, animated: false)
            } else {
                // Read Only
                if CCUtility.isAnyPermission(toEdit: tableShare.permissions) {
                    switchReadOnly.setOn(false, animated: false)
                    switchEditing.setOn(true, animated: false)
                } else {
                    switchReadOnly.setOn(true, animated: false)
                    switchEditing.setOn(false, animated: false)
                }
                switchFileDrop.setOn(false, animated: false)
            }
        } else {
            // Allow editing
            labelEditing?.text = NSLocalizedString("_share_editing_", comment: "")
            if CCUtility.isAnyPermission(toEdit: tableShare.permissions) {
                switchEditing.setOn(true, animated: false)
                switchReadOnly.setOn(false, animated: false)
            } else {
                switchEditing.setOn(false, animated: false)
                switchReadOnly.setOn(true, animated: false)
            }
        }
    }
    
    // Read Only (directory)
    @IBAction func switchReadOnly(sender: UISwitch) {
        
        guard let tableShare = self.tableShare else { return }
        guard let metadata = self.metadata else { return }
        let permission = CCUtility.getPermissionsValue(byCanEdit: false, andCanCreate: false, andCanChange: false, andCanDelete: false, andCanShare: false, andIsFolder: metadata.directory)

        if sender.isOn && permission != tableShare.permissions {
            switchEditing.setOn(false, animated: false)
            if metadata.directory {
                switchFileDrop.setOn(false, animated: false)
            }
            networking?.updateShare(idShare: tableShare.idShare, password: nil, permission: permission, note: nil, expirationDate: nil, hideDownload: tableShare.hideDownload)
        } else {
            sender.setOn(true, animated: false)
        }
    }

    // Allow Upload And Editing (directory)
    @IBAction func switchAllowEditingChanged(sender: UISwitch) {
        
        guard let tableShare = self.tableShare else { return }
        guard let metadata = self.metadata else { return }
        let permission = CCUtility.getPermissionsValue(byCanEdit: true, andCanCreate: true, andCanChange: true, andCanDelete: true, andCanShare: false, andIsFolder: metadata.directory)

        if sender.isOn && permission != tableShare.permissions {
            switchReadOnly.setOn(false, animated: false)
            if metadata.directory {
                switchFileDrop.setOn(false, animated: false)
            }
            networking?.updateShare(idShare: tableShare.idShare, password: nil, permission: permission, note: nil, expirationDate: nil, hideDownload: tableShare.hideDownload)
        } else {
            sender.setOn(true, animated: false)
        }
    }
    
    // File Drop (directory)
    @IBAction func switchFileDrop(sender: UISwitch) {
        
        guard let tableShare = self.tableShare else { return }
        let permission = NCGlobal.shared.permissionCreateShare

        if sender.isOn && permission != tableShare.permissions {
            switchReadOnly.setOn(false, animated: false)
            switchEditing.setOn(false, animated: false)
            networking?.updateShare(idShare: tableShare.idShare, password: nil, permission: permission, note: nil, expirationDate: nil, hideDownload: tableShare.hideDownload)
        } else {
            sender.setOn(true, animated: false)
        }
    }
    
    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        
        if newWindow == nil {
            // UIView disappear
            shareViewController?.reloadData()
        } else {
            // UIView appear
            networking = NCShareNetworking.init(metadata: metadata!, urlBase: appDelegate.urlBase,  view: self, delegate: self)
        }
    }
    
    func unLoad() {
//        viewWindowCalendar?.removeFromSuperview()
        viewWindow?.removeFromSuperview()
        
//        viewWindowCalendar = nil
        viewWindow = nil
    }
    
    func readShareCompleted() {
        reloadData(idShare: tableShare?.idShare ?? 0)
    }
    
    func shareCompleted() { }
    
    func unShareCompleted() {   }
    
    func updateShareWithError(idShare: Int) {
        reloadData(idShare: idShare)
    }
    
    func getSharees(sharees: [NCCommunicationSharee]?) {    }
    
}
