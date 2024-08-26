//
//  NCShareCells.swift
//  Nextcloud
//
//  Created by Henrik Storch on 18.03.22.
//  Copyright © 2022 Henrik Storch. All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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

protocol NCShareCellConfig {
    var title: String { get }
    func getCell(for share: NCTableShareable) -> UITableViewCell
    func didSelect(for share: NCTableShareable)
}

protocol NCToggleCellConfig: NCShareCellConfig {
    func isOn(for share: NCTableShareable) -> Bool
    func didChange(_ share: NCTableShareable, to newValue: Bool)
}

extension NCToggleCellConfig {
    func getCell(for share: NCTableShareable) -> UITableViewCell {
        return NCShareToggleCell(isOn: isOn(for: share))
    }

    func didSelect(for share: NCTableShareable) {
        didChange(share, to: !isOn(for: share))
    }
}

protocol NCPermission: NCToggleCellConfig {
    static var forDirectory: [Self] { get }
    static var forFile: [Self] { get }
    static func forDirectoryE2EE(account: String) -> [NCPermission]
    func hasResharePermission(for parentPermission: Int) -> Bool
    func hasDownload() -> Bool
}

enum NCUserPermission: CaseIterable, NCPermission {
    func hasResharePermission(for parentPermission: Int) -> Bool {
        if self == .download { return true }
        return ((permissionBitFlag & parentPermission) != 0)
    }

    func hasDownload() -> Bool {
        return self == .download
    }

    var permissionBitFlag: Int {
        switch self {
        case .reshare: return NCPermissions().permissionShareShare
        case .edit: return NCPermissions().permissionUpdateShare
        case .create: return NCPermissions().permissionCreateShare
        case .delete: return NCPermissions().permissionDeleteShare
        case .download: return NCPermissions().permissionDownloadShare
        }
    }

    func didChange(_ share: NCTableShareable, to newValue: Bool) {
        if self == .download {
            share.attributes = NCManageDatabase.shared.setAttibuteDownload(state: newValue)
        } else {
            share.permissions ^= permissionBitFlag
        }
    }

    func isOn(for share: NCTableShareable) -> Bool {
        if self == .download {
            return NCManageDatabase.shared.isAttributeDownloadEnabled(attributes: share.attributes)
        } else {
            return (share.permissions & permissionBitFlag) != 0
        }
    }

    static func forDirectoryE2EE(account: String) -> [NCPermission] {
        if NCCapabilities.shared.getCapabilities(account: account).capabilityE2EEApiVersion == NCGlobal.shared.e2eeVersionV20 {
            return NCUserPermission.allCases
        }
        return []
    }

    case reshare, edit, create, delete, download
    static let forDirectory: [NCUserPermission] = NCUserPermission.allCases
    static let forFile: [NCUserPermission] = [.reshare, .edit]

    var title: String {
        switch self {
        case .reshare: return NSLocalizedString("_share_can_reshare_", comment: "")
        case .edit: return NSLocalizedString("_share_can_change_", comment: "")
        case .create: return NSLocalizedString("_share_can_create_", comment: "")
        case .delete: return NSLocalizedString("_share_can_delete_", comment: "")
        case .download: return NSLocalizedString("_share_can_download_", comment: "")
        }
    }
}

enum NCLinkPermission: NCPermission {
    func didChange(_ share: NCTableShareable, to newValue: Bool) {
        guard self != .allowEdit || newValue else {
            share.permissions = NCPermissions().permissionReadShare
            return
        }
        share.permissions = permissionValue
    }

    func hasResharePermission(for parentPermission: Int) -> Bool {
        permissionValue & parentPermission == permissionValue
    }

    func hasDownload() -> Bool {
        return false
    }

    var permissionValue: Int {
        switch self {
        case .allowEdit:
            return NCPermissions().getPermission(
                canEdit: true,
                canCreate: true,
                canChange: true,
                canDelete: true,
                canShare: false,
                isDirectory: false)
        case .viewOnly:
            return NCPermissions().getPermission(
                canEdit: false,
                canCreate: false,
                canChange: false,
                canDelete: false,
                // not possible to create "read-only" shares without reshare option
                // https://github.com/nextcloud/server/blame/f99876997a9119518fe5f7ad3a3a51d33459d4cc/apps/files_sharing/lib/Controller/ShareAPIController.php#L1104-L1107
                canShare: true,
                isDirectory: true)
        case .uploadEdit:
            return NCPermissions().getPermission(
                canEdit: true,
                canCreate: true,
                canChange: true,
                canDelete: true,
                canShare: false,
                isDirectory: true)
        case .fileDrop:
            return NCPermissions().permissionCreateShare
        case .secureFileDrop:
            return NCPermissions().permissionCreateShare
        }
    }

    func isOn(for share: NCTableShareable) -> Bool {
        let permissions = NCPermissions()
        switch self {
        case .allowEdit: return permissions.isAnyPermissionToEdit(share.permissions)
        case .viewOnly: return !permissions.isAnyPermissionToEdit(share.permissions) && share.permissions != permissions.permissionCreateShare
        case .uploadEdit: return permissions.isAnyPermissionToEdit(share.permissions) && share.permissions != permissions.permissionCreateShare
        case .fileDrop: return share.permissions == permissions.permissionCreateShare
        case .secureFileDrop: return share.permissions == permissions.permissionCreateShare
        }
    }

    static func forDirectoryE2EE(account: String) -> [NCPermission] {
        return [NCLinkPermission.secureFileDrop]
    }

    var title: String {
        switch self {
        case .allowEdit: return NSLocalizedString("_share_can_change_", comment: "")
        case .viewOnly: return NSLocalizedString("_share_read_only_", comment: "")
        case .uploadEdit: return NSLocalizedString("_share_allow_upload_", comment: "")
        case .fileDrop: return NSLocalizedString("_share_file_drop_", comment: "")
        case .secureFileDrop: return NSLocalizedString("_share_secure_file_drop_", comment: "")
        }
    }

    case allowEdit, viewOnly, uploadEdit, fileDrop, secureFileDrop
    static let forDirectory: [NCLinkPermission] = [.viewOnly, .uploadEdit, .fileDrop]
    static let forFile: [NCLinkPermission] = [.allowEdit]
}

enum NCShareDetails: CaseIterable, NCShareCellConfig {
    func didSelect(for share: NCTableShareable) {
        switch self {
        case .hideDownload: share.hideDownload.toggle()
        case .expirationDate: return
        case .password: return
        case .note: return
        case .label: return
        }
    }

    func getCell(for share: NCTableShareable) -> UITableViewCell {
        switch self {
        case .hideDownload:
            return NCShareToggleCell(isOn: share.hideDownload)
        case .expirationDate:
            return NCShareDateCell(share: share)
        case .password: return NCShareToggleCell(isOn: !share.password.isEmpty, customIcons: ("lock", "lock_open"))
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
    static let forLink: [NCShareDetails] = NCShareDetails.allCases
    static let forUser: [NCShareDetails] = [.expirationDate, .note]
}

struct NCShareConfig {
    let permissions: [NCPermission]
    let advanced: [NCShareDetails]
    let share: NCTableShareable
    let resharePermission: Int

    init(parentMetadata: tableMetadata, share: NCTableShareable) {
        self.share = share
        self.resharePermission = parentMetadata.sharePermissionsCollaborationServices
        let type: NCPermission.Type = share.shareType == NCShareCommon().SHARE_TYPE_LINK ? NCLinkPermission.self : NCUserPermission.self
        self.permissions = parentMetadata.directory ? (parentMetadata.e2eEncrypted ? type.forDirectoryE2EE(account: parentMetadata.account) : type.forDirectory) : type.forFile
        self.advanced = share.shareType == NCShareCommon().SHARE_TYPE_LINK ? NCShareDetails.forLink : NCShareDetails.forUser
    }

    func cellFor(indexPath: IndexPath) -> UITableViewCell? {
        let cellConfig = config(for: indexPath)
        let cell = cellConfig?.getCell(for: share)
        cell?.textLabel?.text = cellConfig?.title
        if let cellConfig = cellConfig as? NCPermission, !cellConfig.hasResharePermission(for: resharePermission), !cellConfig.hasDownload() {
            cell?.isUserInteractionEnabled = false
            cell?.textLabel?.isEnabled = false
        }
        return cell
    }

    func didSelectRow(at indexPath: IndexPath) {
        let cellConfig = config(for: indexPath)
        cellConfig?.didSelect(for: share)
    }

    func config(for indexPath: IndexPath) -> NCShareCellConfig? {
        if indexPath.section == 0, indexPath.row < permissions.count {
            return permissions[indexPath.row]
        } else if indexPath.section == 1, indexPath.row < advanced.count {
            return advanced[indexPath.row]
        } else { return nil }
    }
}

class NCShareToggleCell: UITableViewCell {
    typealias CustomToggleIcon = (onIconName: String?, offIconName: String?)
    init(isOn: Bool, customIcons: CustomToggleIcon? = nil) {
        super.init(style: .default, reuseIdentifier: "toggleCell")
        self.accessibilityValue = isOn ? NSLocalizedString("_on_", comment: "") : NSLocalizedString("_off_", comment: "")

        guard let customIcons = customIcons,
              let iconName = isOn ? customIcons.onIconName : customIcons.offIconName else {
            self.accessoryType = isOn ? .checkmark : .none
            return
        }
        let image = NCUtility().loadImage(named: iconName, colors: [NCBrandColor.shared.customer], size: self.frame.height - 26)
        self.accessoryView = UIImageView(image: image)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class NCShareDateCell: UITableViewCell {
    let picker = UIDatePicker()
    let textField = UITextField()
    var shareType: Int
    var onReload: (() -> Void)?
    let shareCommon = NCShareCommon()

    init(share: NCTableShareable) {
        self.shareType = share.shareType
        super.init(style: .value1, reuseIdentifier: "shareExpDate")

        picker.datePickerMode = .date
        picker.minimumDate = Date()
        picker.preferredDatePickerStyle = .wheels
        picker.action(for: .valueChanged) { datePicker in
            guard let datePicker = datePicker as? UIDatePicker else { return }
            self.detailTextLabel?.text = DateFormatter.shareExpDate.string(from: datePicker.date)
        }
        accessoryView = textField

        let toolbar = UIToolbar.toolbar {
            self.resignFirstResponder()
            share.expirationDate = nil
            self.onReload?()
        } onDone: {
            self.resignFirstResponder()
            share.expirationDate = self.picker.date as NSDate
            self.onReload?()
        }

        textField.isAccessibilityElement = false
        textField.accessibilityElementsHidden = true
        textField.inputAccessoryView = toolbar.wrappedSafeAreaContainer
        textField.inputView = picker

        if let expDate = share.expirationDate {
            detailTextLabel?.text = DateFormatter.shareExpDate.string(from: expDate as Date)
        }
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func checkMaximumDate(account: String) {
        let defaultExpDays = defaultExpirationDays(account: account)
        if defaultExpDays > 0 && isExpireDateEnforced(account: account) {
            let enforcedInSecs = TimeInterval(defaultExpDays * 24 * 60 * 60)
            self.picker.maximumDate = Date().advanced(by: enforcedInSecs)
        }
    }

    private func isExpireDateEnforced(account: String) -> Bool {
        switch self.shareType {
        case shareCommon.SHARE_TYPE_LINK,
            shareCommon.SHARE_TYPE_EMAIL,
            shareCommon.SHARE_TYPE_GUEST:
            return NCCapabilities.shared.getCapabilities(account: account).capabilityFileSharingPubExpireDateEnforced
        case shareCommon.SHARE_TYPE_USER,
            shareCommon.SHARE_TYPE_GROUP,
            shareCommon.SHARE_TYPE_CIRCLE,
            shareCommon.SHARE_TYPE_ROOM:
            return NCCapabilities.shared.getCapabilities(account: account).capabilityFileSharingInternalExpireDateEnforced
        case shareCommon.SHARE_TYPE_REMOTE,
            shareCommon.SHARE_TYPE_REMOTE_GROUP:
            return NCCapabilities.shared.getCapabilities(account: account).capabilityFileSharingRemoteExpireDateEnforced
        default:
            return false
        }
    }

    private func defaultExpirationDays(account: String) -> Int {
        switch self.shareType {
        case shareCommon.SHARE_TYPE_LINK,
            shareCommon.SHARE_TYPE_EMAIL,
            shareCommon.SHARE_TYPE_GUEST:
            return NCCapabilities.shared.getCapabilities(account: account).capabilityFileSharingPubExpireDateDays
        case shareCommon.SHARE_TYPE_USER,
            shareCommon.SHARE_TYPE_GROUP,
            shareCommon.SHARE_TYPE_CIRCLE,
            shareCommon.SHARE_TYPE_ROOM:
            return NCCapabilities.shared.getCapabilities(account: account).capabilityFileSharingInternalExpireDateDays
        case shareCommon.SHARE_TYPE_REMOTE,
            shareCommon.SHARE_TYPE_REMOTE_GROUP:
            return NCCapabilities.shared.getCapabilities(account: account).capabilityFileSharingRemoteExpireDateDays
        default:
            return 0
        }
    }
}
