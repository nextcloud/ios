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
import OSLog

protocol NCShareCellConfig {
    var title: String { get }
    func getCell(for share: Shareable) -> UITableViewCell
    func didSelect(for share: Shareable)
}

protocol NCToggleCellConfig: NCShareCellConfig {
    func isOn(for share: Shareable) -> Bool
    func didChange(_ share: Shareable, to newValue: Bool)
}

extension NCToggleCellConfig {
    func getCell(for share: Shareable) -> UITableViewCell {
        return NCShareToggleCell(isOn: isOn(for: share))
    }

    func didSelect(for share: Shareable) {
        didChange(share, to: !isOn(for: share))
    }
}

protocol NCPermission: NCToggleCellConfig {
    static var forDirectory: [Self] { get }
    static var forFile: [Self] { get }
    static func forDirectoryE2EE(account: String) -> [NCPermission]
    func hasPermission(for parentPermission: Int) -> Bool
    func hasReadPermission() -> Bool
}

enum NCUserPermission: CaseIterable, NCPermission {
    func hasPermission(for parentPermission: Int) -> Bool {
        return ((permissionBitFlag & parentPermission) != 0)
    }

    func hasReadPermission() -> Bool {
        return self == .read
    }

    var permissionBitFlag: Int {
        switch self {
        case .read: return NCPermissions().permissionReadShare
        case .reshare: return NCPermissions().permissionShareShare
        case .edit: return NCPermissions().permissionEditShare
        case .create: return NCPermissions().permissionCreateShare
        case .delete: return NCPermissions().permissionDeleteShare
        }
    }

    func didChange(_ share: Shareable, to newValue: Bool) {
        share.permissions ^= permissionBitFlag
    }

    func isOn(for share: Shareable) -> Bool {
        return (share.permissions & permissionBitFlag) != 0
    }

    static func forDirectoryE2EE(account: String) -> [NCPermission] {
        if NCCapabilities.shared.getCapabilities(account: account).capabilityE2EEApiVersion == NCGlobal.shared.e2eeVersionV20 {
            return NCUserPermission.allCases
        }
        return []
    }

    case read, reshare, edit, create, delete
    static let forDirectory: [NCUserPermission] = NCUserPermission.allCases
    static let forFile: [NCUserPermission] = [.read, .reshare, .edit]

    var title: String {
        switch self {
        case .read: return NSLocalizedString("_share_can_read_", comment: "")
        case .reshare: return NSLocalizedString("_share_can_reshare_", comment: "")
        case .edit: return NSLocalizedString("_share_can_change_", comment: "")
        case .create: return NSLocalizedString("_share_can_create_", comment: "")
        case .delete: return NSLocalizedString("_share_can_delete_", comment: "")
        }
    }
}

enum NCLinkEmailPermission: CaseIterable, NCPermission {
    static func forDirectoryE2EE(account: String) -> [any NCPermission] {
        if NCCapabilities.shared.getCapabilities(account: account).capabilityE2EEApiVersion == NCGlobal.shared.e2eeVersionV20 {
            return NCUserPermission.allCases
        }
        return []
    }

    func hasReadPermission() -> Bool {
        return self == .read
    }

    func hasPermission(for parentPermission: Int) -> Bool {
        return ((permissionBitFlag & parentPermission) != 0)
    }

    var permissionBitFlag: Int {
        switch self {
        case .read: return NCPermissions().permissionReadShare
        case .edit: return NCPermissions().permissionEditShare
        case .create: return NCPermissions().permissionCreateShare
        case .delete: return NCPermissions().permissionDeleteShare
        }
    }

    func didChange(_ share: Shareable, to newValue: Bool) {
        share.permissions ^= permissionBitFlag
    }

    func isOn(for share: Shareable) -> Bool {
        return (share.permissions & permissionBitFlag) != 0
    }

    var title: String {
        switch self {
        case .read: return NSLocalizedString("_share_can_read_", comment: "")
        case .edit: return NSLocalizedString("_share_can_change_", comment: "")
        case .create: return NSLocalizedString("_share_can_create_", comment: "")
        case .delete: return NSLocalizedString("_share_can_delete_", comment: "")
        }
    }

    case edit, read, create, delete
    static let forDirectory: [NCLinkEmailPermission] = NCLinkEmailPermission.allCases
    static let forFile: [NCLinkEmailPermission] = [.read, .edit]
}

///
/// Individual aspects of share.
///
enum NCAdvancedPermission: CaseIterable, NCShareCellConfig {
    func didSelect(for share: Shareable) {
        switch self {
        case .hideDownload: share.hideDownload.toggle()
        case .limitDownload: return
        case .expirationDate: return
        case .password: return
        case .note: return
        case .label: return
        case .downloadAndSync: return
        }
    }

    func getCell(for share: Shareable) -> UITableViewCell {
        switch self {
        case .hideDownload:
            return NCShareToggleCell(isOn: share.hideDownload)
        case .limitDownload:
            let cell = UITableViewCell(style: .value1, reuseIdentifier: "downloadLimit")
            cell.accessibilityIdentifier = "downloadLimit"
            cell.accessoryType = .disclosureIndicator
            return cell
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
        case .downloadAndSync:
            return NCShareToggleCell(isOn: share.downloadAndSync)
        }
    }

    var title: String {
        switch self {
        case .hideDownload: return NSLocalizedString("_share_hide_download_", comment: "")
        case .limitDownload: return NSLocalizedString("_share_limit_download_", comment: "")
        case .expirationDate: return NSLocalizedString("_share_expiration_date_", comment: "")
        case .password: return NSLocalizedString("_share_password_protect_", comment: "")
        case .note: return NSLocalizedString("_share_note_recipient_", comment: "")
        case .label: return NSLocalizedString("_share_link_name_", comment: "")
        case .downloadAndSync: return NSLocalizedString("_share_can_download_", comment: "")
        }
    }

    case label, hideDownload, limitDownload, expirationDate, password, note, downloadAndSync
    static let forLink: [NCAdvancedPermission] = [.expirationDate, .hideDownload, .label, .limitDownload, .note, .password]
    static let forUser: [NCAdvancedPermission] = [.expirationDate, .note, .downloadAndSync]
}

struct NCShareConfig {
    let permissions: [NCPermission]
    let advanced: [NCAdvancedPermission]
    let shareable: Shareable
    let sharePermission: Int
    let isDirectory: Bool

    /// There are many share types, but we only classify them as a link share (link type, email type) and a user share (every other share type).
    init(parentMetadata: tableMetadata, share: Shareable) {
        self.shareable = share
        self.sharePermission = parentMetadata.sharePermissionsCollaborationServices
        self.isDirectory = parentMetadata.directory
        let type: NCPermission.Type = (share.shareType == NCShareCommon().SHARE_TYPE_LINK || share.shareType == NCShareCommon().SHARE_TYPE_EMAIL) ? NCLinkEmailPermission.self : NCUserPermission.self
        self.permissions = parentMetadata.directory ? (parentMetadata.e2eEncrypted ? type.forDirectoryE2EE(account: parentMetadata.account) : type.forDirectory) : type.forFile

        if share.shareType == NCShareCommon().SHARE_TYPE_LINK {
            let hasDownloadLimitCapability = NCCapabilities
                .shared
                .getCapabilities(account: parentMetadata.account)
                .capabilityFileSharingDownloadLimit

            if parentMetadata.isDirectory || hasDownloadLimitCapability == false {
                self.advanced = NCAdvancedPermission.forLink.filter { $0 != .limitDownload }
            } else {
                self.advanced = NCAdvancedPermission.forLink
            }
        } else {
            self.advanced = NCAdvancedPermission.forUser
        }
    }

    func cellFor(indexPath: IndexPath) -> UITableViewCell? {
        let cellConfig = config(for: indexPath)
        let cell = cellConfig?.getCell(for: shareable)
        cell?.textLabel?.text = cellConfig?.title
        Logger().info("\(cellConfig?.title ?? "")")

        if let cellConfig = cellConfig as? NCPermission, !cellConfig.hasPermission(for: sharePermission) {
            cell?.isUserInteractionEnabled = false
            cell?.textLabel?.isEnabled = false
        }

        // For user permissions: Read permission is always enabled and we show it as a non-interactable permission for brevity.
        if let cellConfig = cellConfig as? NCUserPermission, cellConfig.hasReadPermission() {
            cell?.isUserInteractionEnabled = false
            cell?.textLabel?.isEnabled = false
        }

        // For link permissions: Read permission is always enabled and we show it as a non-interactable permission in files only for brevity.
        if let cellConfig = cellConfig as? NCLinkEmailPermission, cellConfig.hasReadPermission(), !isDirectory {
            cell?.isUserInteractionEnabled = false
            cell?.textLabel?.isEnabled = false
        }

        return cell
    }

    func didSelectRow(at indexPath: IndexPath) {
        let cellConfig = config(for: indexPath)
        cellConfig?.didSelect(for: shareable)
    }

    func config(for indexPath: IndexPath) -> NCShareCellConfig? {
        if indexPath.section == 0, indexPath.row < permissions.count {
            return permissions[indexPath.row]
        } else if indexPath.section == 1, indexPath.row < advanced.count {
            return advanced[indexPath.row]
        } else { return nil }
    }
}
