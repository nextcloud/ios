//
//  NCShareLinkMenuView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 25/07/2019.
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

import Foundation
import FSCalendar

class NCShareLinkMenuView: UIView, UIGestureRecognizerDelegate, NCShareNetworkingDelegate, FSCalendarDelegate, FSCalendarDelegateAppearance {
    
    @IBOutlet weak var switchAllowEditing: UISwitch!
    @IBOutlet weak var labelAllowEditing: UILabel!
    
    @IBOutlet weak var switchReadOnly: UISwitch!
    @IBOutlet weak var labelReadOnly: UILabel!
    
    @IBOutlet weak var switchAllowUploadAndEditing: UISwitch!
    @IBOutlet weak var labelAllowUploadAndEditing: UILabel!
    
    @IBOutlet weak var switchFileDrop: UISwitch!
    @IBOutlet weak var labelFileDrop: UILabel!
    
    @IBOutlet weak var switchHideDownload: UISwitch!
    @IBOutlet weak var labelHideDownload: UILabel!
    
    @IBOutlet weak var switchPasswordProtect: UISwitch!
    @IBOutlet weak var labelPasswordProtect: UILabel!
    @IBOutlet weak var fieldPasswordProtect: UITextField!
    
    @IBOutlet weak var switchSetExpirationDate: UISwitch!
    @IBOutlet weak var labelSetExpirationDate: UILabel!
    @IBOutlet weak var fieldSetExpirationDate: UITextField!
    
    @IBOutlet weak var imageNoteToRecipient: UIImageView!
    @IBOutlet weak var labelNoteToRecipient: UILabel!
    @IBOutlet weak var fieldNoteToRecipient: UITextField!
    
    @IBOutlet weak var buttonDeleteShareLink: UIButton!
    @IBOutlet weak var labelDeleteShareLink: UILabel!
    @IBOutlet weak var imageDeleteShareLink: UIImageView!
    
    @IBOutlet weak var buttonAddAnotherLink: UIButton!
    @IBOutlet weak var labelAddAnotherLink: UILabel!
    @IBOutlet weak var imageAddAnotherLink: UIImageView!
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    var width: CGFloat = 0
    var height: CGFloat = 0
    
    private var tableShare: tableShare?
    var metadata: tableMetadata?
    
    var viewWindow: UIView?
    var viewWindowCalendar: UIView?
    
    override func awakeFromNib() {
        
        layer.borderColor = UIColor.lightGray.cgColor
        layer.borderWidth = 0.5
        layer.cornerRadius = 5
        layer.masksToBounds = false
        layer.shadowOffset = CGSize(width: 2, height: 2)
        layer.shadowOpacity = 0.2
        
        switchAllowEditing?.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchAllowEditing?.onTintColor = NCBrandColor.sharedInstance.brand
        switchReadOnly?.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchReadOnly?.onTintColor = NCBrandColor.sharedInstance.brand
        switchAllowUploadAndEditing?.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchAllowUploadAndEditing?.onTintColor = NCBrandColor.sharedInstance.brand
        switchFileDrop?.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchFileDrop?.onTintColor = NCBrandColor.sharedInstance.brand
        switchHideDownload.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchHideDownload.onTintColor = NCBrandColor.sharedInstance.brand
        switchPasswordProtect.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchPasswordProtect.onTintColor = NCBrandColor.sharedInstance.brand
        switchSetExpirationDate.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchSetExpirationDate.onTintColor = NCBrandColor.sharedInstance.brand
        
        fieldSetExpirationDate.inputView = UIView()
        
        imageNoteToRecipient.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "file_txt"), width: 100, height: 100, color: UIColor(red: 76/255, green: 76/255, blue: 76/255, alpha: 1))
        imageDeleteShareLink.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "trash"), width: 100, height: 100, color: UIColor(red: 76/255, green: 76/255, blue: 76/255, alpha: 1))
        imageAddAnotherLink.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "add"), width: 100, height: 100, color: UIColor(red: 76/255, green: 76/255, blue: 76/255, alpha: 1))
    }
    
    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
    }
    
    func unLoad() {
        viewWindowCalendar?.removeFromSuperview()
        viewWindow?.removeFromSuperview()
        
        viewWindowCalendar = nil
        viewWindow = nil
    }
    
    func reloadData(idRemoteShared: Int) {
        
        guard let metadata = self.metadata else { return }
        tableShare = NCManageDatabase.sharedInstance.getTableShare(account: metadata.account, idRemoteShared: idRemoteShared)
        guard let tableShare = self.tableShare else { return }

        if metadata.directory {
            // Read Only
            if UtilsFramework.isAnyPermission(toEdit: tableShare.permissions) {
                switchReadOnly.setOn(false, animated: false)
                switchAllowUploadAndEditing.setOn(true, animated: false)
            } else {
                switchReadOnly.setOn(true, animated: false)
                switchAllowUploadAndEditing.setOn(false, animated: false)
            }
            // File Drop
            if UtilsFramework.isPermission(toCanCreate: tableShare.permissions) {
                switchReadOnly.setOn(false, animated: false)
                switchAllowUploadAndEditing.setOn(false, animated: false)
                switchFileDrop.setOn(true, animated: false)
            } else {
                switchFileDrop.setOn(false, animated: false)
            }
        } else {
            // Allow editing
            if UtilsFramework.isAnyPermission(toEdit: tableShare.permissions) {
                switchAllowEditing.setOn(true, animated: false)
            } else {
                switchAllowEditing.setOn(false, animated: false)
            }
        }
       
        // Hide download
        if tableShare.hideDownload {
            switchHideDownload.setOn(true, animated: false)
        } else {
            switchHideDownload.setOn(false, animated: false)
        }
        
        // Password protect
        if tableShare.shareWith.count > 0 {
            switchPasswordProtect.setOn(true, animated: false)
            fieldPasswordProtect.isEnabled = true
            fieldPasswordProtect.text = tableShare.shareWith
        } else {
            switchPasswordProtect.setOn(false, animated: false)
            fieldPasswordProtect.isEnabled = false
            fieldPasswordProtect.text = ""
        }
        
        // Set expiration date
        if tableShare.expirationDate != nil {
            switchSetExpirationDate.setOn(true, animated: false)
            fieldSetExpirationDate.isEnabled = true
            
            let dateFormatter = DateFormatter()
            dateFormatter.formatterBehavior = .behavior10_4
            dateFormatter.dateStyle = .medium
            fieldSetExpirationDate.text = dateFormatter.string(from: tableShare.expirationDate! as Date)
        } else {
            switchSetExpirationDate.setOn(false, animated: false)
            fieldSetExpirationDate.isEnabled = false
            fieldSetExpirationDate.text = ""
        }
        
        // Note to recipient
        fieldNoteToRecipient.text = tableShare.note
    }
    
    // MARK: - IBAction

    // Allow editing
    @IBAction func switchAllowEditingChanged(sender: UISwitch) {
        
        guard let tableShare = self.tableShare else { return }
        guard let metadata = self.metadata else { return }

        var permission: Int = 0
        
        if sender.isOn {
            permission = UtilsFramework.getPermissionsValue(byCanEdit: true, andCanCreate: true, andCanChange: true, andCanDelete: true, andCanShare: false, andIsFolder: metadata.directory)
        } else {
            permission = UtilsFramework.getPermissionsValue(byCanEdit: false, andCanCreate: false, andCanChange: false, andCanDelete: false, andCanShare: false, andIsFolder: metadata.directory)
        }
        
        let networking = NCShareNetworking.init(account: metadata.account, activeUrl: appDelegate.activeUrl,  view: self, delegate: self)
        networking.updateShare(idRemoteShared: tableShare.idRemoteShared, password: nil, permission: permission, note: nil, expirationTime: nil, hideDownload: tableShare.hideDownload)
    }
    
    // Read Only
    @IBAction func switchReadOnly(sender: UISwitch) {
    }
    
    // Allow Upload And Editing
    @IBAction func switchAllowUploadAndEditing(sender: UISwitch) {
    }
  
    // File Drop
    @IBAction func switchFileDrop(sender: UISwitch) {
    }
    
    // Hide download
    @IBAction func switchHideDownloadChanged(sender: UISwitch) {
        
        guard let tableShare = self.tableShare else { return }
        
        let networking = NCShareNetworking.init(account: metadata!.account, activeUrl: appDelegate.activeUrl,  view: self, delegate: self)
        networking.updateShare(idRemoteShared: tableShare.idRemoteShared, password: nil, permission: 0, note: nil, expirationTime: nil, hideDownload: sender.isOn)
    }
    
    // Password protect
    @IBAction func switchPasswordProtectChanged(sender: UISwitch) {
        
        guard let tableShare = self.tableShare else { return }
        guard let metadata = self.metadata else { return }
        
        if sender.isOn {
            fieldPasswordProtect.isEnabled = true
            fieldPasswordProtect.text = ""
            fieldPasswordProtect.becomeFirstResponder()
        } else {
            let networking = NCShareNetworking.init(account: metadata.account, activeUrl: appDelegate.activeUrl,  view: self, delegate: self)
            networking.updateShare(idRemoteShared: tableShare.idRemoteShared, password: "", permission: 0, note: nil, expirationTime: nil, hideDownload: tableShare.hideDownload)
        }
    }
    
    @IBAction func fieldPasswordProtectDidEndOnExit(textField: UITextField) {
        
        guard let tableShare = self.tableShare else { return }
        guard let metadata = self.metadata else { return }

        let networking = NCShareNetworking.init(account: metadata.account, activeUrl: appDelegate.activeUrl,  view: self, delegate: self)
        networking.updateShare(idRemoteShared: tableShare.idRemoteShared, password: fieldPasswordProtect.text, permission: 0, note: nil, expirationTime: nil, hideDownload: tableShare.hideDownload)
    }
    
    // Set expiration date
    @IBAction func switchSetExpirationDate(sender: UISwitch) {
        
        guard let tableShare = self.tableShare else { return }
        guard let metadata = self.metadata else { return }

        if sender.isOn {
            fieldSetExpirationDate.isEnabled = true
            fieldSetExpirationDate(sender: fieldSetExpirationDate)
        } else {
            let networking = NCShareNetworking.init(account: metadata.account, activeUrl: appDelegate.activeUrl,  view: self, delegate: self)
            networking.updateShare(idRemoteShared: tableShare.idRemoteShared, password: nil, permission: 0, note: nil, expirationTime: "", hideDownload: tableShare.hideDownload)
        }
    }
    
    @IBAction func fieldSetExpirationDate(sender: UITextField) {
        
        let calendar = NCShareCommon.sharedInstance.openCalendar(view: self, width: width, height: height)
        calendar.calendarView.delegate = self
        viewWindowCalendar = calendar.viewWindow
    }
    
    // Note to recipient
    @IBAction func fieldNoteToRecipientDidEndOnExit(textField: UITextField) {
        
        guard let tableShare = self.tableShare else { return }
        guard let metadata = self.metadata else { return }
        if fieldNoteToRecipient.text == nil { return }
        
        let networking = NCShareNetworking.init(account: metadata.account, activeUrl: appDelegate.activeUrl,  view: self, delegate: self)
        networking.updateShare(idRemoteShared: tableShare.idRemoteShared, password: nil, permission: 0, note: fieldNoteToRecipient.text, expirationTime: nil, hideDownload: tableShare.hideDownload)
    }
    
    // Delete share link
    @IBAction func buttonDeleteShareLink(sender: UIButton) {
        
        guard let tableShare = self.tableShare else { return }
        guard let metadata = self.metadata else { return }
        
        let networking = NCShareNetworking.init(account: metadata.account, activeUrl: appDelegate.activeUrl,  view: self, delegate: self)
        
        networking.unShare(idRemoteShared: tableShare.idRemoteShared)
    }
    
    // Add another link
    @IBAction func buttonAddAnotherLink(sender: UIButton) {
        
        guard let metadata = self.metadata else { return }

        let networking = NCShareNetworking.init(account: metadata.account, activeUrl: appDelegate.activeUrl,  view: self, delegate: self)
        
        networking.share(metadata: metadata, password: "", permission: 1, hideDownload: false)
    }
    
    // MARK: - Delegate networking
    
    func readShareCompleted() {
        reloadData(idRemoteShared: tableShare?.idRemoteShared ?? 0)
    }
    
    func shareCompleted() {
        unLoad()
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "reloadDataNCShare"), object: nil, userInfo: nil)
    }
    
    func unShareCompleted() {
        unLoad()
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "reloadDataNCShare"), object: nil, userInfo: nil)
    }
    
    func updateShareWithError(idRemoteShared: Int) {
        reloadData(idRemoteShared: idRemoteShared)
    }
    
    func getUserAndGroup(items: [OCShareUser]?) { }
    
    // MARK: - Delegate calendar
    
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        
        if monthPosition == .previous || monthPosition == .next {
            calendar.setCurrentPage(date, animated: true)
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.formatterBehavior = .behavior10_4
            dateFormatter.dateStyle = .medium
            fieldSetExpirationDate.text = dateFormatter.string(from:date)
            fieldSetExpirationDate.endEditing(true)
            
            viewWindowCalendar?.removeFromSuperview()
            
            guard let tableShare = self.tableShare else { return }
            guard let metadata = self.metadata else { return }

            let networking = NCShareNetworking.init(account: metadata.account, activeUrl: appDelegate.activeUrl,  view: self, delegate: self)
            dateFormatter.dateFormat = "YYYY-MM-dd"
            let expirationTime = dateFormatter.string(from: date)
            networking.updateShare(idRemoteShared: tableShare.idRemoteShared, password: nil, permission: 0, note: nil, expirationTime: expirationTime, hideDownload: tableShare.hideDownload)
        }
    }
    
    func calendar(_ calendar: FSCalendar, shouldSelect date: Date, at monthPosition: FSCalendarMonthPosition) -> Bool {
        return date > Date()
    }
    
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, titleDefaultColorFor date: Date) -> UIColor? {
        if date > Date() {
            return UIColor(red: 60/255, green: 60/255, blue: 60/255, alpha: 1)
        } else {
            return UIColor(red: 190/255, green: 190/255, blue: 190/255, alpha: 1)
        }
    }
}
