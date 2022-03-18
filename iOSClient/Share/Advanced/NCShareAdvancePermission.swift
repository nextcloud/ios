//
//  NCShareAdvancePermission.swift
//  Nextcloud
//
//  Created by T-systems on 09/08/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import UIKit
import NCCommunication
import SVGKit
import CloudKit

class NCShareAdvancePermission: UITableViewController, NCShareAdvanceFotterDelegate {
    func dismissShareAdvanceView(shouldSave: Bool) {
        defer { navigationController?.popViewController(animated: true) }
        guard shouldSave else { return }
        // TODO: Save / Create
    }
    
    var share: tableShare!
    var metadata: tableMetadata!
    var shareConfig: ShareConfig!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.shareConfig = ShareConfig(isDirectory: metadata.directory, share: share)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        guard tableView.tableHeaderView == nil, tableView.tableFooterView == nil else { return }
        setupHeaderView()
        setupFooterView()
    }

    func setupFooterView() {
        guard let footerView = (Bundle.main.loadNibNamed("NCShareAdvancePermissionFooter", owner: self, options: nil)?.first as? NCShareAdvancePermissionFooter) else { return }
        footerView.setupUI(with: share, delegate: self)

        footerView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 100)
        tableView.tableFooterView = footerView
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        footerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        footerView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor).isActive = true
        footerView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor).isActive = true
        footerView.heightAnchor.constraint(equalToConstant: 100).isActive = true
    }

    func setupHeaderView() {
        guard let headerView = (Bundle.main.loadNibNamed("NCShareAdvancePermissionHeader", owner: self, options: nil)?.first as? NCShareAdvancePermissionHeader) else { return }
        headerView.setupUI(with: metadata)

        headerView.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: 200)
        tableView.tableHeaderView = headerView
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.heightAnchor.constraint(equalToConstant: 200).isActive = true
        headerView.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 { return NSLocalizedString("_advanced_", comment: "") }
        else if section == 1 { return NSLocalizedString("_misc_", comment: "") }
        else { return nil }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { return shareConfig.permissions.count }
        else if section == 1 { return shareConfig.advanced.count }
        else { return 0 }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = shareConfig.cellFor(indexPath: indexPath) else { return UITableViewCell() }
        if let cell = cell as? DatePickerTableViewCell {
            cell.onReload = tableView.reloadData
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let cellConfig = shareConfig.config(for: indexPath) else { return }
        if let cellConfig = cellConfig as? Advanced {
            switch cellConfig {
            case .hideDownload:
                share.hideDownload.toggle()
                tableView.reloadData()
            case .expirationDate:
                let cell = tableView.cellForRow(at: indexPath) as? DatePickerTableViewCell
                cell?.textField.becomeFirstResponder()
            case .password:
                guard share.password.isEmpty else {
                    share.password = ""
                    tableView.reloadData()
                    return
                }
                let alertController = UIAlertController(title: NSLocalizedString("_enforce_password_protection_", comment: ""), message: "", preferredStyle: .alert)
                alertController.addTextField { textField in
                    textField.isSecureTextEntry = true
                }
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .default) { _ in })
                let okAction = UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default) { _ in
                    let password = alertController.textFields?.first?.text
                    self.share.password = password ?? ""
                    tableView.reloadData()
                }

                alertController.addAction(okAction)

                self.present(alertController, animated: true)
            case .note:
                let storyboard = UIStoryboard(name: "NCShare", bundle: nil)
                guard let viewNewUserComment = storyboard.instantiateViewController(withIdentifier: "NCShareNewUserAddComment") as? NCShareNewUserAddComment else { return }
                viewNewUserComment.metadata = self.metadata
                viewNewUserComment.share = self.share
                viewNewUserComment.onDismiss = tableView.reloadData
                self.navigationController?.pushViewController(viewNewUserComment, animated: true)
            }
        } else {
            cellConfig.didSelect(for: share)
            tableView.reloadData()
        }
    }
}

protocol ShareCellConfig {
    var title: String { get }
    func getCell(for share: tableShare) -> UITableViewCell
    func didSelect(for share: tableShare)
}

protocol ToggleCellConfig: ShareCellConfig {
    func isOn(for share: tableShare) -> Bool
    func didChange(_ share: tableShare, to newValue: Bool)
}

extension ToggleCellConfig {
    func getCell(for share: tableShare) -> UITableViewCell {
        return ToggleCell(isOn: isOn(for: share))
    }

    func didSelect(for share: tableShare) {
        didChange(share, to: !isOn(for: share))
    }
}

protocol Permission: ToggleCellConfig {
    static var forDirectory: [Self] { get }
    static var forFile: [Self] { get }
}

enum UserPermission: CaseIterable, Permission {
    var permissionBitFlag: Int {
        switch self {
        case .reshare: return NCGlobal.shared.permissionShareShare
        case .edit: return NCGlobal.shared.permissionUpdateShare
        case .create: return NCGlobal.shared.permissionCreateShare
        case .delete: return NCGlobal.shared.permissionDeleteShare
        }
    }

    func didChange(_ share: tableShare, to newValue: Bool) {
        share.permissions ^= permissionBitFlag
    }

    func isOn(for share: tableShare) -> Bool {
        return (share.permissions & permissionBitFlag) != 0
    }

    case reshare, edit, create, delete
    static let forDirectory: [UserPermission] = UserPermission.allCases
    static let forFile: [UserPermission] = [.reshare, .edit]

    var title: String {
        switch self {
        case .reshare: return NSLocalizedString("_share_can_reshare_", comment: "")
        case .edit: return NSLocalizedString("_share_can_change_", comment: "")
        case .create: return NSLocalizedString("_share_can_create_", comment: "")
        case .delete: return NSLocalizedString("_share_can_delete_", comment: "")
        }
    }
}

enum LinkPermission: Permission {
    func didChange(_ share: tableShare, to newValue: Bool) {
        guard self != .allowEdit else {
            // file
            share.permissions = CCUtility.getPermissionsValue(
                byCanEdit: newValue,
                andCanCreate: newValue,
                andCanChange: newValue,
                andCanDelete: newValue,
                andCanShare: false,
                andIsFolder: false)
            return
        }
        // can't deselect, only change
        guard newValue == true else { return }
        switch self {
        case .allowEdit: return
        case .viewOnly:
            share.permissions = CCUtility.getPermissionsValue(
                byCanEdit: false,
                andCanCreate: false,
                andCanChange: false,
                andCanDelete: false,
                andCanShare: false,
                andIsFolder: true)
        case .uploadEdit:
            share.permissions = CCUtility.getPermissionsValue(
                byCanEdit: true,
                andCanCreate: true,
                andCanChange: true,
                andCanDelete: true,
                andCanShare: false,
                andIsFolder: true)
        case .fileDrop:
            share.permissions = NCGlobal.shared.permissionCreateShare
        }
    }

    func isOn(for share: tableShare) -> Bool {
        switch self {
        case .allowEdit: return CCUtility.isAnyPermission(toEdit: share.permissions)
        case .viewOnly: return !CCUtility.isAnyPermission(toEdit: share.permissions) && share.permissions != NCGlobal.shared.permissionCreateShare
        case .uploadEdit: return CCUtility.isAnyPermission(toEdit: share.permissions) && share.permissions != NCGlobal.shared.permissionCreateShare
        case .fileDrop: return share.permissions == NCGlobal.shared.permissionCreateShare
        }
    }

    var title: String {
        switch self {
        case .allowEdit: return NSLocalizedString("_share_can_change_", comment: "")
        case .viewOnly: return NSLocalizedString("_share_read_only_", comment: "")
        case .uploadEdit: return NSLocalizedString("_share_allow_upload_", comment: "")
        case .fileDrop: return NSLocalizedString("_share_file_drop_", comment: "")
        }
    }

    case allowEdit, viewOnly, uploadEdit, fileDrop
    static let forDirectory: [LinkPermission] = [.viewOnly, .uploadEdit, .fileDrop]
    static let forFile: [LinkPermission] = [.allowEdit]
}

enum Advanced: CaseIterable, ShareCellConfig {
    func didSelect(for share: tableShare) {
        switch self {
        case .hideDownload: share.hideDownload.toggle()
        case .expirationDate: return
        case .password: return
        case .note: return
        }
    }

    func getCell(for share: tableShare) -> UITableViewCell {
        switch self {
        case .hideDownload:
            return ToggleCell(isOn: share.hideDownload)
        case .expirationDate:
            return DatePickerTableViewCell(share: share)
        case .password: return ToggleCell(isOn: !share.password.isEmpty)
        case .note:
            let cell = UITableViewCell(style: .value1, reuseIdentifier: "shareNote")
            cell.detailTextLabel?.text = share.note
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }

    var title: String {
        switch self {
        case .hideDownload: return NSLocalizedString("_share_hide_download_", comment: "")
        case .expirationDate: return NSLocalizedString("_share_expiration_date_", comment: "")
        case .password: return NSLocalizedString("_share_password_protect_", comment: "")
        case .note: return NSLocalizedString("_share_note_recipient_", comment: "")
        }
    }

    case hideDownload, expirationDate, password, note
    static let forLink: [Advanced] = Advanced.allCases
    static let forUser: [Advanced] = [.expirationDate, .note]
}

struct ShareConfig {

    let permissions: [Permission]
    let advanced: [Advanced]
    let share: tableShare

    init(isDirectory: Bool, share: tableShare) {
        self.share = share
        let type: Permission.Type = share.shareType == 3 ? LinkPermission.self : UserPermission.self
        self.permissions = isDirectory ? type.forDirectory : type.forFile
        self.advanced = share.shareType == 3 ? Advanced.forLink : Advanced.forUser
    }

    func cellFor(indexPath: IndexPath) -> UITableViewCell? {
        let cellConfig = config(for: indexPath)
        let cell = cellConfig?.getCell(for: share)
        cell?.textLabel?.text = cellConfig?.title
        return cell
    }

    func didSelectRow(at indexPath: IndexPath) {
        let cellConfig = config(for: indexPath)
        cellConfig?.didSelect(for: share)
    }

    func config(for indexPath: IndexPath) -> ShareCellConfig? {
        if indexPath.section == 0, indexPath.row < permissions.count {
            return  permissions[indexPath.row]
        } else if indexPath.section == 1, indexPath.row < advanced.count {
            return advanced[indexPath.row]
        } else { return nil }
    }
}

class ToggleCell: UITableViewCell {
    init(isOn: Bool) {
        super.init(style: .default, reuseIdentifier: "toggleCell")
        if isOn {
            self.accessoryType = .checkmark
        } else {
            self.accessoryType = .none
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension DateFormatter {
    static let shareExpDate: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.formatterBehavior = .behavior10_4
        dateFormatter.dateStyle = .medium
        return dateFormatter
    }()
}

open class DatePickerTableViewCell: UITableViewCell {
    let picker = UIDatePicker()
    let textField = UITextField()

    var onReload: (() -> Void)?

    init(share: tableShare) {
        super.init(style: .value1, reuseIdentifier: "shareExpDate")
        picker.datePickerMode = .date
        if #available(iOS 13.4, *) {
            picker.preferredDatePickerStyle = .wheels
        }
        picker.action(for: .valueChanged) { datePicker in
            guard let datePicker = datePicker as? UIDatePicker else { return }
            self.detailTextLabel?.text = DateFormatter.shareExpDate.string(from: datePicker.date)
        }
        accessoryView = textField

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let doneButton = UIBarButtonItem(title: "_done_", style: .done) {
            self.resignFirstResponder()
            share.date = self.picker.date as NSDate
            self.onReload?()
        }
        let spaceButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
        let cancelButton = UIBarButtonItem(title: NSLocalizedString("_clear_", comment: ""), style: .plain) {
            self.resignFirstResponder()
            share.date = nil
            self.onReload?()
        }
        toolbar.setItems([cancelButton, spaceButton, doneButton], animated: false)

        textField.inputAccessoryView = toolbar
        textField.inputView = picker

        if let expDate = share.date {
            detailTextLabel?.text = DateFormatter.shareExpDate.string(from: expDate as Date)
        }
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
