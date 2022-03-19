//
//  ShareCells.swift
//  Nextcloud
//
//  Created by Henrik Storch on 18.03.22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//

import UIKit

protocol ShareCellConfig {
    var title: String { get }
    func getCell(for share: TableShareable) -> UITableViewCell
    func didSelect(for share: TableShareable)
}

protocol ToggleCellConfig: ShareCellConfig {
    func isOn(for share: TableShareable) -> Bool
    func didChange(_ share: TableShareable, to newValue: Bool)
}

extension ToggleCellConfig {
    func getCell(for share: TableShareable) -> UITableViewCell {
        return ToggleCell(isOn: isOn(for: share))
    }

    func didSelect(for share: TableShareable) {
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

    func didChange(_ share: TableShareable, to newValue: Bool) {
        share.permissions ^= permissionBitFlag
    }

    func isOn(for share: TableShareable) -> Bool {
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
    func didChange(_ share: TableShareable, to newValue: Bool) {
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

    func isOn(for share: TableShareable) -> Bool {
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
    func didSelect(for share: TableShareable) {
        switch self {
        case .hideDownload: share.hideDownload.toggle()
        case .expirationDate: return
        case .password: return
        case .note: return
        case .label: return
        }
    }

    func getCell(for share: TableShareable) -> UITableViewCell {
        switch self {
        case .hideDownload:
            return ToggleCell(isOn: share.hideDownload)
        case .expirationDate:
            return DatePickerTableViewCell(share: share)
        case .password: return ToggleCell(isOn: !share.password.isEmpty, customIcons: ("lock", "lock.open"))
        case .note:
            let cell = UITableViewCell(style: .value1, reuseIdentifier: "shareNote")
            cell.detailTextLabel?.text = share.note
            cell.accessoryType = .disclosureIndicator
            return cell
        case .label:
            let cell = UITableViewCell(style: .value1, reuseIdentifier: "shareLabel")
            cell.detailTextLabel?.text = share.label
            return cell
        }
    }

    var title: String {
        switch self {
        case .hideDownload: return NSLocalizedString("_share_hide_download_", comment: "")
        case .expirationDate: return NSLocalizedString("_share_expiration_date_", comment: "")
        case .password: return NSLocalizedString("_share_password_protect_", comment: "")
        case .note: return NSLocalizedString("_share_note_recipient_", comment: "")
        case .label: return NSLocalizedString("_share_link_name_", comment: "")
        }
    }

    case label, hideDownload, expirationDate, password, note
    static let forLink: [Advanced] = Advanced.allCases
    static let forUser: [Advanced] = [.expirationDate, .note]
}

struct ShareConfig {
    let permissions: [Permission]
    let advanced: [Advanced]
    let share: TableShareable

    init(isDirectory: Bool, share: TableShareable) {
        self.share = share
        let type: Permission.Type = share.shareType == NCShareCommon.shared.SHARE_TYPE_LINK ? LinkPermission.self : UserPermission.self
        self.permissions = isDirectory ? type.forDirectory : type.forFile
        self.advanced = share.shareType == NCShareCommon.shared.SHARE_TYPE_LINK ? Advanced.forLink : Advanced.forUser
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
    typealias CustomToggleIcon = (onIconName: String?, offIconName: String?)
    init(isOn: Bool, customIcons: CustomToggleIcon? = nil) {
        super.init(style: .default, reuseIdentifier: "toggleCell")
        guard let customIcons = customIcons,
              let iconName = isOn ? customIcons.onIconName : customIcons.offIconName else {
            self.accessoryType = isOn ? .checkmark : .none
            return
        }
        let image = NCUtility.shared.loadImage(named: iconName, color: NCBrandColor.shared.brandElement)
        self.accessoryView = UIImageView(image: image)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

open class DatePickerTableViewCell: UITableViewCell {
    let picker = UIDatePicker()
    let textField = UITextField()

    var onReload: (() -> Void)?

    init(share: TableShareable) {
        super.init(style: .value1, reuseIdentifier: "shareExpDate")
        picker.datePickerMode = .date
        picker.minimumDate = Date()
        if #available(iOS 13.4, *) {
            picker.preferredDatePickerStyle = .wheels
        }
        picker.action(for: .valueChanged) { datePicker in
            guard let datePicker = datePicker as? UIDatePicker else { return }
            self.detailTextLabel?.text = DateFormatter.shareExpDate.string(from: datePicker.date)
        }
        accessoryView = textField

        let toolbar = UIToolbar.toolbar {
            self.resignFirstResponder()
            share.expirationDate = nil
            self.onReload?()
        } completion: {
            self.resignFirstResponder()
            share.expirationDate = self.picker.date as NSDate
            self.onReload?()
        }

        textField.inputAccessoryView = toolbar
        textField.inputView = picker

        if let expDate = share.expirationDate {
            detailTextLabel?.text = DateFormatter.shareExpDate.string(from: expDate as Date)
        }
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
