//
//  NCShare+Menu.swift
//  Nextcloud
//
//  Created by Henrik Storch on 16.03.22.
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

import Foundation
import UIKit
import NextcloudKit

class NCContextMenuShare: NSObject {
    let share: tableShare
    let isDirectory: Bool
    let canReshare: Bool
    let utility = NCUtility()
    let database = NCManageDatabase.shared
    let shareController: NCShare

    init(share: tableShare, isDirectory: Bool, canReshare: Bool, shareController: NCShare) {
        self.share = share
        self.isDirectory = isDirectory
        self.canReshare = canReshare
        self.shareController = shareController
    }

    func viewMenu() -> UIMenu {
        var actions: [UIMenuElement] = []

        // Add share link (only for public links with reshare permission)
        if share.shareType == NKShare.ShareType.publicLink.rawValue, canReshare {
            let addLinkAction = UIAction(
                title: NSLocalizedString("_share_add_sharelink_", comment: ""),
                image: utility.loadImage(named: "plus", colors: [NCBrandColor.shared.iconImageColor])
            ) { [self] _ in
                shareController.makeNewLinkShare()
            }
            actions.append(addLinkAction)
        }

        // Details action
        let detailsAction = UIAction(
            title: NSLocalizedString("_details_", comment: ""),
            image: utility.loadImage(named: "pencil", colors: [NCBrandColor.shared.iconImageColor])
        ) { [self] _ in
            openAdvancePermission(shareController: shareController)
        }
        actions.append(detailsAction)

        // Unshare action (destructive)
        let unshareAction = UIAction(
            title: NSLocalizedString("_share_unshare_", comment: ""),
            image: utility.loadImage(named: "person.2.slash"),
            attributes: .destructive
        ) { [self] _ in
            Task {
                await performUnshare(shareController: shareController)
            }
        }
        actions.append(unshareAction)

        return UIMenu(title: "", children: actions)
    }

    func quickPermissionsMenu() -> UIMenu {
        var actions: [UIMenuElement] = []

        let isReadOnly = share.permissions == (NKShare.Permission.read.rawValue + NKShare.Permission.share.rawValue) || share.permissions == NKShare.Permission.read.rawValue
        let isEditing = hasUploadPermission()
        let isFileDrop = share.permissions == NKShare.Permission.create.rawValue

        // Read Only
        let readOnlyAction = UIAction(
            title: NSLocalizedString("_share_read_only_", comment: ""),
            image: utility.loadImage(named: "eye", colors: [NCBrandColor.shared.iconImageColor]),
            state: isReadOnly ? .on : .off
        ) { [self] _ in
            let permissions = NCSharePermissions.getPermissionValue(canCreate: false, canEdit: false, canDelete: false, canShare: false, isDirectory: self.isDirectory)
            shareController.updateSharePermissions(share: share, permissions: permissions)
        }
        actions.append(readOnlyAction)

        // Editing
        let editingAction = UIAction(
            title: NSLocalizedString("_share_editing_", comment: ""),
            image: utility.loadImage(named: "pencil", colors: [NCBrandColor.shared.iconImageColor]),
            state: isEditing ? .on : .off
        ) { [self] _ in
            let permissions = NCSharePermissions.getPermissionValue(canCreate: true, canEdit: true, canDelete: true, canShare: true, isDirectory: self.isDirectory)
            shareController.updateSharePermissions(share: share, permissions: permissions)
        }
        actions.append(editingAction)

        // File Drop (only for directories with public link or email share)
        if isDirectory && (share.shareType == NKShare.ShareType.publicLink.rawValue || share.shareType == NKShare.ShareType.email.rawValue) {
            let fileDropAction = UIAction(
                title: NSLocalizedString("_share_file_drop_", comment: ""),
                image: utility.loadImage(named: "arrow.up.document", colors: [NCBrandColor.shared.iconImageColor]),
                state: isFileDrop ? .on : .off
            ) { [self] _ in
                let permissions = NCSharePermissions.getPermissionValue(canRead: false, canCreate: true, canEdit: false, canDelete: false, canShare: false, isDirectory: self.isDirectory)
                shareController.updateSharePermissions(share: share, permissions: permissions)
            }
            actions.append(fileDropAction)
        }

        // Custom Permissions
        let customAction = UIAction(
            title: NSLocalizedString("_custom_permissions_", comment: ""),
            image: utility.loadImage(named: "ellipsis", colors: [NCBrandColor.shared.iconImageColor])
        ) { [self] _ in
            openAdvancePermission(shareController: shareController)
        }
        actions.append(customAction)

        return UIMenu(title: "", children: actions)
    }

    private func hasUploadPermission() -> Bool {
        let uploadPermissions = [
            NCSharePermissions.permissionMaxFileShare,
            NCSharePermissions.permissionMaxFolderShare,
            NCSharePermissions.permissionDefaultFileRemoteShareNoSupportShareOption,
            NCSharePermissions.permissionDefaultFolderRemoteShareNoSupportShareOption
        ]
        return uploadPermissions.contains(share.permissions)
    }

    private func openAdvancePermission(shareController: NCShare) {
        guard let advancePermission = UIStoryboard(name: "NCShare", bundle: nil).instantiateViewController(withIdentifier: "NCShareAdvancePermission") as? NCShareAdvancePermission,
              let navigationController = shareController.navigationController,
              !share.isInvalidated,
              let metadata = shareController.metadata else { return }

        advancePermission.networking = shareController.networking
        advancePermission.share = tableShare(value: share)
        advancePermission.oldTableShare = tableShare(value: share)
        advancePermission.metadata = metadata

        if let downloadLimit = try? database.getDownloadLimit(byAccount: metadata.account, shareToken: share.token) {
            advancePermission.downloadLimit = .limited(limit: downloadLimit.limit, count: downloadLimit.count)
        }

        navigationController.pushViewController(advancePermission, animated: true)
    }

    @MainActor
    private func performUnshare(shareController: NCShare) async {
        let capabilities = NCNetworking.shared.capabilities[share.account] ?? NKCapabilities.Capabilities()

        if share.shareType != NKShare.ShareType.publicLink.rawValue,
           let metadata = shareController.metadata,
           metadata.e2eEncrypted && NCGlobal.shared.isE2eeVersion2(capabilities.e2EEApiVersion) {
            if await NCNetworkingE2EE().isInUpload(account: metadata.account, serverUrl: metadata.serverUrlFileName) {
                let error = NKError(errorCode: NCGlobal.shared.errorE2EEUploadInProgress, errorDescription: NSLocalizedString("_e2e_in_upload_", comment: ""))
                return NCContentPresenter().showInfo(error: error)
            }
            let error = await NCNetworkingE2EE().uploadMetadata(serverUrl: metadata.serverUrlFileName, addUserId: nil, removeUserId: share.shareWith, account: metadata.account)
            if error != .success {
                return NCContentPresenter().showError(error: error)
            }
        }
        shareController.networking?.unShare(idShare: share.idShare)
    }
}

extension NCShare {
    func presentQuickStatusActionSheet(for share: tableShare, sender: Any?) {
        guard let metadata = metadata else { return }

        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let isDirectory = metadata.directory

        // Read Only
        let readOnlyAction = UIAlertAction(title: NSLocalizedString("_share_read_only_", comment: ""), style: .default) { [weak self] _ in
            let permissions = NCSharePermissions.getPermissionValue(canCreate: false, canEdit: false, canDelete: false, canShare: false, isDirectory: isDirectory)
            self?.updateSharePermissions(share: share, permissions: permissions)
        }
        alertController.addAction(readOnlyAction)

        // Editing
        let editingAction = UIAlertAction(title: NSLocalizedString("_share_editing_", comment: ""), style: .default) { [weak self] _ in
            let permissions = NCSharePermissions.getPermissionValue(canCreate: true, canEdit: true, canDelete: true, canShare: true, isDirectory: isDirectory)
            self?.updateSharePermissions(share: share, permissions: permissions)
        }
        alertController.addAction(editingAction)

        // File Drop (only for directories with public link or email share)
        if isDirectory && (share.shareType == NKShare.ShareType.publicLink.rawValue || share.shareType == NKShare.ShareType.email.rawValue) {
            let fileDropAction = UIAlertAction(title: NSLocalizedString("_share_file_drop_", comment: ""), style: .default) { [weak self] _ in
                let permissions = NCSharePermissions.getPermissionValue(canRead: false, canCreate: true, canEdit: false, canDelete: false, canShare: false, isDirectory: isDirectory)
                self?.updateSharePermissions(share: share, permissions: permissions)
            }
            alertController.addAction(fileDropAction)
        }

        // Custom Permissions
        let customAction = UIAlertAction(title: NSLocalizedString("_custom_permissions_", comment: ""), style: .default) { [weak self] _ in
            self?.openAdvancePermission(for: share)
        }
        alertController.addAction(customAction)

        // Cancel
        let cancelAction = UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel)
        alertController.addAction(cancelAction)

        // iPad popover support
        if let popover = alertController.popoverPresentationController,
           let sourceView = sender as? UIView {
            popover.sourceItem = sourceView
        }

        present(alertController, animated: true)
    }

    private func openAdvancePermission(for share: tableShare) {
        guard let advancePermission = UIStoryboard(name: "NCShare", bundle: nil).instantiateViewController(withIdentifier: "NCShareAdvancePermission") as? NCShareAdvancePermission,
              !share.isInvalidated,
              let metadata = metadata else { return }

        advancePermission.networking = networking
        advancePermission.share = tableShare(value: share)
        advancePermission.oldTableShare = tableShare(value: share)
        advancePermission.metadata = metadata

        if let downloadLimit = try? NCManageDatabase.shared.getDownloadLimit(byAccount: metadata.account, shareToken: share.token) {
            advancePermission.downloadLimit = .limited(limit: downloadLimit.limit, count: downloadLimit.count)
        }

        navigationController?.pushViewController(advancePermission, animated: true)
    }

    func updateSharePermissions(share: tableShare, permissions: Int) {
        let updatedShare = tableShare(value: share)
        updatedShare.permissions = permissions

        var downloadLimit: DownloadLimitViewModel = .unlimited

        do {
            if let model = try database.getDownloadLimit(byAccount: metadata.account, shareToken: updatedShare.token) {
                downloadLimit = .limited(limit: model.limit, count: model.count)
            }
        } catch {
            nkLog(error: "Failed to get download limit from database!")
            return
        }

        networking?.updateShare(updatedShare, downloadLimit: downloadLimit)
    }
}
