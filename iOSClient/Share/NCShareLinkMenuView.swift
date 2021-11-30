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

import UIKit
import FSCalendar
import NCCommunication

class NCShareLinkMenuView: UIView, UIGestureRecognizerDelegate, UITextFieldDelegate, NCShareNetworkingDelegate, FSCalendarDelegate, FSCalendarDelegateAppearance {

    @IBOutlet weak var fieldLabel: UITextField!

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
    var shareViewController: NCShare?
    private var networking: NCShareNetworking?

    var viewWindow: UIView?
    var viewWindowCalendar: UIView?
    private var calendar: FSCalendar?
    private var activeTextfieldDiff: CGFloat = 0
    private var activeTextField = UITextField()

    override func awakeFromNib() {

        layer.borderColor = UIColor.lightGray.cgColor
        layer.borderWidth = 0.5
        layer.cornerRadius = 5
        layer.masksToBounds = false
        layer.shadowOffset = CGSize(width: 2, height: 2)
        layer.shadowOpacity = 0.2

        fieldLabel?.placeholder = NSLocalizedString("_Link_name_", comment: "")

        switchAllowEditing?.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchAllowEditing?.onTintColor = NCBrandColor.shared.brandElement
        switchReadOnly?.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchReadOnly?.onTintColor = NCBrandColor.shared.brandElement
        switchAllowUploadAndEditing?.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchAllowUploadAndEditing?.onTintColor = NCBrandColor.shared.brandElement
        switchFileDrop?.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchFileDrop?.onTintColor = NCBrandColor.shared.brandElement
        switchHideDownload.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchHideDownload.onTintColor = NCBrandColor.shared.brandElement
        switchPasswordProtect.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchPasswordProtect.onTintColor = NCBrandColor.shared.brandElement
        switchSetExpirationDate.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchSetExpirationDate.onTintColor = NCBrandColor.shared.brandElement

        labelAllowEditing?.text = NSLocalizedString("_share_allow_editing_", comment: "")
        labelAllowEditing?.textColor = NCBrandColor.shared.label
        labelReadOnly?.text = NSLocalizedString("_share_read_only_", comment: "")
        labelReadOnly?.textColor = NCBrandColor.shared.label
        labelAllowUploadAndEditing?.text = NSLocalizedString("_share_allow_upload_", comment: "")
        labelAllowUploadAndEditing?.textColor = NCBrandColor.shared.label
        labelFileDrop?.text = NSLocalizedString("_share_file_drop_", comment: "")
        labelFileDrop?.textColor = NCBrandColor.shared.label
        labelHideDownload?.text = NSLocalizedString("_share_hide_download_", comment: "")
        labelHideDownload?.textColor = NCBrandColor.shared.label
        labelPasswordProtect?.text = NSLocalizedString("_share_password_protect_", comment: "")
        labelPasswordProtect?.textColor = NCBrandColor.shared.label
        labelSetExpirationDate?.text = NSLocalizedString("_share_expiration_date_", comment: "")
        labelSetExpirationDate?.textColor = NCBrandColor.shared.label
        labelNoteToRecipient?.text = NSLocalizedString("_share_note_recipient_", comment: "")
        labelNoteToRecipient?.textColor = NCBrandColor.shared.label
        labelDeleteShareLink?.text = NSLocalizedString("_share_delete_sharelink_", comment: "")
        labelDeleteShareLink?.textColor = NCBrandColor.shared.label
        labelAddAnotherLink?.text = NSLocalizedString("_share_add_sharelink_", comment: "")
        labelAddAnotherLink?.textColor = NCBrandColor.shared.label

        fieldSetExpirationDate.inputView = UIView()

        fieldLabel.delegate = self
        fieldPasswordProtect.delegate = self
        fieldNoteToRecipient.delegate = self

        imageNoteToRecipient.image = UIImage(named: "file_txt")!.image(color: NCBrandColor.shared.gray, size: 50)
        imageDeleteShareLink.image = NCUtility.shared.loadImage(named: "trash", color: NCBrandColor.shared.gray, size: 50)
        imageAddAnotherLink.image =  NCUtility.shared.loadImage(named: "plus", color: NCBrandColor.shared.gray, size: 50)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)

        if newWindow == nil {
            // UIView disappear
            shareViewController?.reloadData()
        } else {
            // UIView appear
            networking = NCShareNetworking(metadata: metadata!, urlBase: appDelegate.urlBase, view: self, delegate: self)
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
        tableShare = NCManageDatabase.shared.getTableShare(account: metadata.account, idShare: idShare)
        guard let tableShare = self.tableShare else { return }

        // Label
        fieldLabel.text = tableShare.label

        if metadata.directory {
            // File Drop
            if tableShare.permissions == NCGlobal.shared.permissionCreateShare {
                switchReadOnly.setOn(false, animated: false)
                switchAllowUploadAndEditing.setOn(false, animated: false)
                switchFileDrop.setOn(true, animated: false)
            } else {
                // Read Only
                if CCUtility.isAnyPermission(toEdit: tableShare.permissions) {
                    switchReadOnly.setOn(false, animated: false)
                    switchAllowUploadAndEditing.setOn(true, animated: false)
                } else {
                    switchReadOnly.setOn(true, animated: false)
                    switchAllowUploadAndEditing.setOn(false, animated: false)
                }
                switchFileDrop.setOn(false, animated: false)
            }
        } else {
            // Allow editing
            if CCUtility.isAnyPermission(toEdit: tableShare.permissions) {
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

    func textFieldDidBeginEditing(_ textField: UITextField) {

        self.activeTextField = textField
    }

    // MARK: - Keyboard notification

    @objc internal func keyboardWillShow(_ notification: Notification?) {

        activeTextfieldDiff = 0

        if let info = notification?.userInfo, let centerObject = self.activeTextField.superview?.convert(self.activeTextField.center, to: nil) {

            let frameEndUserInfoKey = UIResponder.keyboardFrameEndUserInfoKey
            if let keyboardFrame = info[frameEndUserInfoKey] as? CGRect {
                let diff = keyboardFrame.origin.y - centerObject.y - self.activeTextField.frame.height
                if diff < 0 {
                    activeTextfieldDiff = diff
                    self.frame.origin.y += diff
                }
            }
        }
    }

    @objc func keyboardWillHide(_ notification: Notification) {
        self.frame.origin.y -= activeTextfieldDiff
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

    // Allow editing (file)
    @IBAction func switchAllowEditingChanged(sender: UISwitch) {

        guard let tableShare = self.tableShare else { return }
        guard let metadata = self.metadata else { return }

        var permissions: Int = 0

        if sender.isOn {
            permissions = CCUtility.getPermissionsValue(byCanEdit: true, andCanCreate: true, andCanChange: true, andCanDelete: true, andCanShare: false, andIsFolder: metadata.directory)
        } else {
            permissions = CCUtility.getPermissionsValue(byCanEdit: false, andCanCreate: false, andCanChange: false, andCanDelete: false, andCanShare: false, andIsFolder: metadata.directory)
        }

        networking?.updateShare(idShare: tableShare.idShare, password: nil, permissions: permissions, note: nil, label: nil, expirationDate: nil, hideDownload: tableShare.hideDownload)
    }

    // Read Only (directory)
    @IBAction func switchReadOnly(sender: UISwitch) {

        guard let tableShare = self.tableShare else { return }
        guard let metadata = self.metadata else { return }
        let permissions = CCUtility.getPermissionsValue(byCanEdit: false, andCanCreate: false, andCanChange: false, andCanDelete: false, andCanShare: false, andIsFolder: metadata.directory)

        if sender.isOn && permissions != tableShare.permissions {
            switchAllowUploadAndEditing.setOn(false, animated: false)
            switchFileDrop.setOn(false, animated: false)
            networking?.updateShare(idShare: tableShare.idShare, password: nil, permissions: permissions, note: nil, label: nil, expirationDate: nil, hideDownload: tableShare.hideDownload)
        } else {
            sender.setOn(true, animated: false)
        }
    }

    // Allow Upload And Editing (directory)
    @IBAction func switchAllowUploadAndEditing(sender: UISwitch) {

        guard let tableShare = self.tableShare else { return }
        guard let metadata = self.metadata else { return }
        let permissions = CCUtility.getPermissionsValue(byCanEdit: true, andCanCreate: true, andCanChange: true, andCanDelete: true, andCanShare: false, andIsFolder: metadata.directory)

        if sender.isOn && permissions != tableShare.permissions {
            switchReadOnly.setOn(false, animated: false)
            switchFileDrop.setOn(false, animated: false)
            networking?.updateShare(idShare: tableShare.idShare, password: nil, permissions: permissions, note: nil, label: nil, expirationDate: nil, hideDownload: tableShare.hideDownload)
        } else {
            sender.setOn(true, animated: false)
        }
    }

    // File Drop (directory)
    @IBAction func switchFileDrop(sender: UISwitch) {

        guard let tableShare = self.tableShare else { return }
        let permissions = NCGlobal.shared.permissionCreateShare

        if sender.isOn && permissions != tableShare.permissions {
            switchReadOnly.setOn(false, animated: false)
            switchAllowUploadAndEditing.setOn(false, animated: false)
            networking?.updateShare(idShare: tableShare.idShare, password: nil, permissions: permissions, note: nil, label: nil, expirationDate: nil, hideDownload: tableShare.hideDownload)
        } else {
            sender.setOn(true, animated: false)
        }
    }

    // Hide download
    @IBAction func switchHideDownloadChanged(sender: UISwitch) {

        guard let tableShare = self.tableShare else { return }

        networking?.updateShare(idShare: tableShare.idShare, password: nil, permissions: tableShare.permissions, note: nil, label: nil, expirationDate: nil, hideDownload: sender.isOn)
    }

    // Password protect
    @IBAction func switchPasswordProtectChanged(sender: UISwitch) {

        guard let tableShare = self.tableShare else { return }

        if sender.isOn {
            fieldPasswordProtect.isEnabled = true
            fieldPasswordProtect.text = ""
            fieldPasswordProtect.becomeFirstResponder()
        } else {
            networking?.updateShare(idShare: tableShare.idShare, password: "", permissions: tableShare.permissions, note: nil, label: nil, expirationDate: nil, hideDownload: tableShare.hideDownload)
        }
    }

    @IBAction func fieldPasswordProtectDidEndOnExit(textField: UITextField) {

        guard let tableShare = self.tableShare else { return }

        networking?.updateShare(idShare: tableShare.idShare, password: fieldPasswordProtect.text, permissions: tableShare.permissions, note: nil, label: nil, expirationDate: nil, hideDownload: tableShare.hideDownload)
    }

    // Set expiration date
    @IBAction func switchSetExpirationDate(sender: UISwitch) {

        guard let tableShare = self.tableShare else { return }

        if sender.isOn {
            fieldSetExpirationDate.isEnabled = true
            fieldSetExpirationDate(sender: fieldSetExpirationDate)
        } else {
            networking?.updateShare(idShare: tableShare.idShare, password: nil, permissions: tableShare.permissions, note: nil, label: nil, expirationDate: "", hideDownload: tableShare.hideDownload)
        }
    }

    @IBAction func fieldSetExpirationDate(sender: UITextField) {

        let calendar = NCShareCommon.shared.openCalendar(view: self, width: width, height: height)
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

        networking?.updateShare(idShare: tableShare.idShare, password: nil, permissions: tableShare.permissions, note: fieldNoteToRecipient.text, label: nil, expirationDate: nil, hideDownload: tableShare.hideDownload)
    }

    // Label
    @IBAction func fielLabelDidEndOnExit(textField: UITextField) {

        guard let tableShare = self.tableShare else { return }
        if fieldLabel.text == nil { return }

        networking?.updateShare(idShare: tableShare.idShare, password: nil, permissions: tableShare.permissions, note: nil, label: fieldLabel.text, expirationDate: nil, hideDownload: tableShare.hideDownload)
    }

    // Delete share link
    @IBAction func buttonDeleteShareLink(sender: UIButton) {

        guard let tableShare = self.tableShare else { return }

        networking?.unShare(idShare: tableShare.idShare)
    }

    // Add another link
    @IBAction func buttonAddAnotherLink(sender: UIButton) {

        networking?.createShareLink(password: "")
    }

    // MARK: - Delegate networking

    func readShareCompleted() {
        reloadData(idShare: tableShare?.idShare ?? 0)
    }

    func shareCompleted() {
        unLoad()
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataNCShare)
    }

    func unShareCompleted() {
        unLoad()
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataNCShare)
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
            fieldSetExpirationDate.text = dateFormatter.string(from: date)
            fieldSetExpirationDate.endEditing(true)

            viewWindowCalendar?.removeFromSuperview()

            guard let tableShare = self.tableShare else { return }

            dateFormatter.dateFormat = "YYYY-MM-dd HH:mm:ss"
            let expirationDate = dateFormatter.string(from: date)

            networking?.updateShare(idShare: tableShare.idShare, password: nil, permissions: tableShare.permissions, note: nil, label: nil, expirationDate: expirationDate, hideDownload: tableShare.hideDownload)
        }
    }

    func calendar(_ calendar: FSCalendar, shouldSelect date: Date, at monthPosition: FSCalendarMonthPosition) -> Bool {
        return date > Date()
    }

    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, titleDefaultColorFor date: Date) -> UIColor? {
        return date > Date() ? NCBrandColor.shared.label : NCBrandColor.shared.systemGray3
    }
}
