//
//  NCShareUserMenuView.swift
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
import NCCommunication

class NCShareUserMenuView: UIView, UIGestureRecognizerDelegate, NCShareNetworkingDelegate, FSCalendarDelegate, FSCalendarDelegateAppearance {
    
    @IBOutlet weak var switchCanReshare: UISwitch!
    @IBOutlet weak var labelCanReshare: UILabel!
    
    @IBOutlet weak var switchCanCreate: UISwitch!
    @IBOutlet weak var labelCanCreate: UILabel!
    
    @IBOutlet weak var switchCanChange: UISwitch!
    @IBOutlet weak var labelCanChange: UILabel!
    
    @IBOutlet weak var switchCanDelete: UISwitch!
    @IBOutlet weak var labelCanDelete: UILabel!
    
    @IBOutlet weak var switchSetExpirationDate: UISwitch!
    @IBOutlet weak var labelSetExpirationDate: UILabel!
    @IBOutlet weak var fieldSetExpirationDate: UITextField!
    
    @IBOutlet weak var imageNoteToRecipient: UIImageView!
    @IBOutlet weak var labelNoteToRecipient: UILabel!
    @IBOutlet weak var fieldNoteToRecipient: UITextField!
    
    @IBOutlet weak var buttonUnshare: UIButton!
    @IBOutlet weak var labelUnshare: UILabel!
    @IBOutlet weak var imageUnshare: UIImageView!
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    var width: CGFloat = 0
    var height: CGFloat = 0
    
    private var tableShare: tableShare?
    var metadata: tableMetadata?
    var shareViewController: NCShare?
    private var networking: NCShareNetworking?

    var viewWindow: UIView?
    var viewWindowCalendar: UIView?
    private var calendar: FSCalendar?

    override func awakeFromNib() {
        
        layer.borderColor = UIColor.lightGray.cgColor
        layer.borderWidth = 0.5
        layer.cornerRadius = 5
        layer.masksToBounds = false
        layer.shadowOffset = CGSize(width: 2, height: 2)
        layer.shadowOpacity = 0.2
        
        switchCanReshare.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchCanReshare.onTintColor = NCBrandColor.sharedInstance.brandElement
        switchCanCreate?.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchCanCreate?.onTintColor = NCBrandColor.sharedInstance.brandElement
        switchCanChange?.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchCanChange?.onTintColor = NCBrandColor.sharedInstance.brandElement
        switchCanDelete?.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchCanDelete?.onTintColor = NCBrandColor.sharedInstance.brandElement
        switchSetExpirationDate.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchSetExpirationDate.onTintColor = NCBrandColor.sharedInstance.brandElement
        
        labelCanReshare?.text = NSLocalizedString("_share_can_reshare_", comment: "")
        labelCanReshare?.textColor = NCBrandColor.sharedInstance.textView
        labelCanCreate?.text = NSLocalizedString("_share_can_create_", comment: "")
        labelCanCreate?.textColor = NCBrandColor.sharedInstance.textView
        labelCanChange?.text = NSLocalizedString("_share_can_change_", comment: "")
        labelCanChange?.textColor = NCBrandColor.sharedInstance.textView
        labelCanDelete?.text = NSLocalizedString("_share_can_delete_", comment: "")
        labelCanDelete?.textColor = NCBrandColor.sharedInstance.textView
        labelSetExpirationDate?.text = NSLocalizedString("_share_expiration_date_", comment: "")
        labelSetExpirationDate?.textColor = NCBrandColor.sharedInstance.textView
        labelNoteToRecipient?.text = NSLocalizedString("_share_note_recipient_", comment: "")
        labelNoteToRecipient?.textColor = NCBrandColor.sharedInstance.textView
        labelUnshare?.text = NSLocalizedString("_share_unshare_", comment: "")
        labelUnshare?.textColor = NCBrandColor.sharedInstance.textView
        
        fieldSetExpirationDate.inputView = UIView()
        
        imageNoteToRecipient.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "file_txt"), width: 100, height: 100, color: UIColor(red: 76/255, green: 76/255, blue: 76/255, alpha: 1))
        imageUnshare.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "trash"), width: 100, height: 100, color: UIColor(red: 76/255, green: 76/255, blue: 76/255, alpha: 1))
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
        viewWindowCalendar?.removeFromSuperview()
        viewWindow?.removeFromSuperview()
        
        viewWindowCalendar = nil
        viewWindow = nil
    }
    
    func reloadData(idShare: Int) {
        
        guard let metadata = self.metadata else { return }
        tableShare = NCManageDatabase.sharedInstance.getTableShare(account: metadata.account, idShare: idShare)
        guard let tableShare = self.tableShare else { return }

        // Can reshare (file)
        let canReshare = CCUtility.isPermission(toCanShare: tableShare.permissions)
        switchCanReshare.setOn(canReshare, animated: false)
        
        if metadata.directory {
            // Can create (folder)
            let canCreate = CCUtility.isPermission(toCanCreate: tableShare.permissions)
            switchCanCreate.setOn(canCreate, animated: false)
            
            // Can change (folder)
            let canChange = CCUtility.isPermission(toCanChange: tableShare.permissions)
            switchCanChange.setOn(canChange, animated: false)
            
            // Can delete (folder)
            let canDelete = CCUtility.isPermission(toCanDelete: tableShare.permissions)
            switchCanDelete.setOn(canDelete, animated: false)
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
    
    // MARK: - Tap viewWindowCalendar
    @objc func tapViewWindowCalendar(gesture: UITapGestureRecognizer) {
        calendar?.removeFromSuperview()
        viewWindowCalendar?.removeFromSuperview()
        
        calendar = nil
        viewWindowCalendar = nil
        
        reloadData(idShare: tableShare?.idShare ?? 0)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return gestureRecognizer.view == touch.view
    }
    
    // MARK: - IBAction

    // Can reshare
    @IBAction func switchCanReshareChanged(sender: UISwitch) {
        
        guard let tableShare = self.tableShare else { return }
        guard let metadata = self.metadata else { return }

        let canEdit = CCUtility.isAnyPermission(toEdit: tableShare.permissions)
        let canCreate = CCUtility.isPermission(toCanCreate: tableShare.permissions)
        let canChange = CCUtility.isPermission(toCanChange: tableShare.permissions)
        let canDelete = CCUtility.isPermission(toCanDelete: tableShare.permissions)
        
        var permission: Int = 0
        
        if metadata.directory {
            permission = CCUtility.getPermissionsValue(byCanEdit: canEdit, andCanCreate: canCreate, andCanChange: canChange, andCanDelete: canDelete, andCanShare: sender.isOn, andIsFolder: metadata.directory)
        } else {
            if sender.isOn {
                if canEdit {
                    permission = CCUtility.getPermissionsValue(byCanEdit: true, andCanCreate: true, andCanChange: true, andCanDelete: true, andCanShare: sender.isOn, andIsFolder: metadata.directory)
                } else {
                    permission = CCUtility.getPermissionsValue(byCanEdit: false, andCanCreate: false, andCanChange: false, andCanDelete: false, andCanShare: sender.isOn, andIsFolder: metadata.directory)
                }
            } else {
                if canEdit {
                    permission = CCUtility.getPermissionsValue(byCanEdit: true, andCanCreate: true, andCanChange: true, andCanDelete: true, andCanShare: sender.isOn, andIsFolder: metadata.directory)
                } else {
                    permission = CCUtility.getPermissionsValue(byCanEdit: false, andCanCreate: false, andCanChange: false, andCanDelete: false, andCanShare: sender.isOn, andIsFolder: metadata.directory)
                }
            }
        }
        
        networking?.updateShare(idShare: tableShare.idShare, password: nil, permission: permission, note: nil, expirationDate: nil, hideDownload: tableShare.hideDownload)
    }
    
    @IBAction func switchCanCreate(sender: UISwitch) {
        
        guard let tableShare = self.tableShare else { return }
        guard let metadata = self.metadata else { return }

        let canEdit = CCUtility.isAnyPermission(toEdit: tableShare.permissions)
        let canChange = CCUtility.isPermission(toCanChange: tableShare.permissions)
        let canDelete = CCUtility.isPermission(toCanDelete: tableShare.permissions)
        let canShare = CCUtility.isPermission(toCanShare: tableShare.permissions)

        let permission = CCUtility.getPermissionsValue(byCanEdit: canEdit, andCanCreate: sender.isOn, andCanChange: canChange, andCanDelete: canDelete, andCanShare: canShare, andIsFolder: metadata.directory)

        networking?.updateShare(idShare: tableShare.idShare, password: nil, permission: permission, note: nil, expirationDate: nil, hideDownload: tableShare.hideDownload)
    }
    
    @IBAction func switchCanChange(sender: UISwitch) {
        
        guard let tableShare = self.tableShare else { return }
        guard let metadata = self.metadata else { return }
        
        let canEdit = CCUtility.isAnyPermission(toEdit: tableShare.permissions)
        let canCreate = CCUtility.isPermission(toCanCreate: tableShare.permissions)
        let canDelete = CCUtility.isPermission(toCanDelete: tableShare.permissions)
        let canShare = CCUtility.isPermission(toCanShare: tableShare.permissions)
        
        let permission = CCUtility.getPermissionsValue(byCanEdit: canEdit, andCanCreate: canCreate, andCanChange: sender.isOn, andCanDelete: canDelete, andCanShare: canShare, andIsFolder: metadata.directory)

        networking?.updateShare(idShare: tableShare.idShare, password: nil, permission: permission, note: nil, expirationDate: nil, hideDownload: tableShare.hideDownload)
    }
    
    @IBAction func switchCanDelete(sender: UISwitch) {
        
        guard let tableShare = self.tableShare else { return }
        guard let metadata = self.metadata else { return }
        
        let canEdit = CCUtility.isAnyPermission(toEdit: tableShare.permissions)
        let canCreate = CCUtility.isPermission(toCanCreate: tableShare.permissions)
        let canChange = CCUtility.isPermission(toCanChange: tableShare.permissions)
        let canShare = CCUtility.isPermission(toCanShare: tableShare.permissions)
        
        let permission = CCUtility.getPermissionsValue(byCanEdit: canEdit, andCanCreate: canCreate, andCanChange: canChange, andCanDelete: sender.isOn, andCanShare: canShare, andIsFolder: metadata.directory)

        networking?.updateShare(idShare: tableShare.idShare, password: nil, permission: permission, note: nil, expirationDate: nil, hideDownload: tableShare.hideDownload)
    }
    
    // Set expiration date
    @IBAction func switchSetExpirationDate(sender: UISwitch) {
        
        guard let tableShare = self.tableShare else { return }
        
        if sender.isOn {
            fieldSetExpirationDate.isEnabled = true
            fieldSetExpirationDate(sender: fieldSetExpirationDate)
        } else {
            networking?.updateShare(idShare: tableShare.idShare, password: nil, permission: tableShare.permissions, note: nil, expirationDate: "", hideDownload: tableShare.hideDownload)
        }
    }
    
    @IBAction func fieldSetExpirationDate(sender: UITextField) {
        
        let calendar = NCShareCommon.sharedInstance.openCalendar(view: self, width: width, height: height)
        calendar.calendarView.delegate = self
        self.calendar = calendar.calendarView
        viewWindowCalendar = calendar.viewWindow
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapViewWindowCalendar))
        tap.delegate = self
        viewWindowCalendar?.addGestureRecognizer(tap)
    }
    
    // Note to recipient
    @IBAction func fieldNoteToRecipientDidEndOnExit(textField: UITextField) {
        
        guard let tableShare = self.tableShare else { return }
        if fieldNoteToRecipient.text == nil { return }
        
        networking?.updateShare(idShare: tableShare.idShare, password: nil, permission: tableShare.permissions, note: fieldNoteToRecipient.text, expirationDate: nil, hideDownload: tableShare.hideDownload)
    }
    
    // Unshare
    @IBAction func buttonUnshare(sender: UIButton) {
        
        guard let tableShare = self.tableShare else { return }
        
        networking?.unShare(idShare: tableShare.idShare)
    }
    
    // MARK: - Delegate networking
    
    func readShareCompleted() {
        reloadData(idShare: tableShare?.idShare ?? 0)
    }
    
    func shareCompleted() {
        unLoad()
        NotificationCenter.default.postOnMainThread(name: k_notificationCenter_reloadDataNCShare)
    }
    
    func unShareCompleted() {
        unLoad()
        NotificationCenter.default.postOnMainThread(name: k_notificationCenter_reloadDataNCShare)
    }
    
    func updateShareWithError(idShare: Int) {
        reloadData(idShare: idShare)
    }
    
    func getSharees(sharees: [NCCommunicationSharee]?) { }
    
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
            
            dateFormatter.dateFormat = "YYYY-MM-dd HH:mm:ss"
            let expirationDate = dateFormatter.string(from: date)
            
            networking?.updateShare(idShare: tableShare.idShare, password: nil, permission: tableShare.permissions, note: nil, expirationDate: expirationDate, hideDownload: tableShare.hideDownload)
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
