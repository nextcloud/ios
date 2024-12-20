//
//  NCMenuAction.swift
//  Nextcloud
//
//  Created by Henrik Storch on 17.02.22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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

import Foundation
import UIKit
import NextcloudKit

class NCMenuAction {
    let title: String
    let boldTitle: Bool
    let details: String?
    let icon: UIImage
    let selectable: Bool
    var onTitle: String?
    var onIcon: UIImage?
    let destructive: Bool
    var selected: Bool = false
    var isOn: Bool = false
    var action: ((_ menuAction: NCMenuAction) -> Void)?
    var rowHeight: CGFloat { self.title == NCMenuAction.seperatorIdentifier ? NCMenuAction.seperatorHeight : self.details != nil ? 76 : 56 }
    var order: Int = 0
	var isHeader = false

	init(title: String, boldTitle: Bool = false, destructive: Bool = false, details: String? = nil, icon: UIImage, isHeader: Bool = false, order: Int = 0, action: ((_ menuAction: NCMenuAction) -> Void)?) {
        self.title = title
        self.boldTitle = boldTitle
        self.destructive = destructive
        self.details = details
        self.icon = icon
		self.isHeader = isHeader
        self.action = action
        self.selectable = false
        self.order = order
    }

    init(title: String, boldTitle: Bool = false, destructive: Bool = false, details: String? = nil, icon: UIImage, onTitle: String? = nil, onIcon: UIImage? = nil, selected: Bool, on: Bool, order: Int = 0, action: ((_ menuAction: NCMenuAction) -> Void)?) {
        self.title = title
        self.boldTitle = boldTitle
        self.destructive = destructive
        self.details = details
        self.icon = icon
        self.onTitle = onTitle ?? title
        self.onIcon = onIcon ?? icon
        self.action = action
        self.selected = selected
        self.isOn = on
        self.selectable = true
        self.order = order
    }
}

// MARK: - Actions

extension NCMenuAction {
    static let seperatorIdentifier = "NCMenuAction.SEPARATOR"
    static let seperatorHeight: CGFloat = 0.5

    /// A static seperator, with no actions, text, or icons
    static func seperator(order: Int = 0) -> NCMenuAction {
        return NCMenuAction(title: seperatorIdentifier, icon: UIImage(), order: order, action: nil)
    }

    /// Select all items
    static func selectAllAction(action: @escaping () -> Void) -> NCMenuAction {
        NCMenuAction(
            title: NSLocalizedString("_select_all_", comment: ""),
            icon: NCImagesRepository.menuIconSelectAll,
            action: { _ in action() }
        )
    }

    /// Cancel
    static func cancelAction(action: @escaping () -> Void) -> NCMenuAction {
        NCMenuAction(
            title: NSLocalizedString("_cancel_", comment: ""),
            icon: NCImagesRepository.menuIconClose,
            action: { _ in action() }
        )
    }

    /// Delete files either from cache or from Nextcloud
    static func deleteAction(selectedMetadatas: [tableMetadata], metadataFolder: tableMetadata? = nil, controller: NCMainTabBarController?, order: Int = 0, completion: (() -> Void)? = nil) -> NCMenuAction {
        var titleDelete = NSLocalizedString("_delete_", comment: "")
        var message = NSLocalizedString("_want_delete_", comment: "")
        var icon = NCImagesRepository.menuIconDelete
        let permissions = NCPermissions()

        if selectedMetadatas.count > 1 {
            titleDelete = NSLocalizedString("_delete_selected_files_", comment: "")
        } else if let metadata = selectedMetadatas.first {
            if NCManageDatabase.shared.isMetadataShareOrMounted(metadata: metadata, metadataFolder: metadataFolder) {
                titleDelete = NSLocalizedString("_leave_share_", comment: "")
                message = NSLocalizedString("_want_leave_share_", comment: "")
                icon = NCImagesRepository.menuIconUnshare
				isDestructive = false
            } else if metadata.directory {
                titleDelete = NSLocalizedString("_delete_folder_", comment: "")
            } else {
                titleDelete = NSLocalizedString("_delete_file_", comment: "")
            }

            if let metadataFolder = metadataFolder {
                let isShare = metadata.permissions.contains(permissions.permissionShared) && !metadataFolder.permissions.contains(permissions.permissionShared)
                let isMounted = metadata.permissions.contains(permissions.permissionMounted) && !metadataFolder.permissions.contains(permissions.permissionMounted)
                if isShare || isMounted {
                    titleDelete = NSLocalizedString("_leave_share_", comment: "")
                    icon = NCImagesRepository.menuIconUnshare
					isDestructive = false
                }
            }
        } // else: no metadata selected

        let canDeleteServer = selectedMetadatas.allSatisfy { !$0.lock }
        var fileList = ""
        for (ix, metadata) in selectedMetadatas.enumerated() {
            guard ix < 3 else { fileList += "\n - ..."; break }
            fileList += "\n - " + metadata.fileNameView
        }

        return NCMenuAction(
            title: titleDelete,
			destructive: isDestructive,
            icon: icon,
            order: order,
            action: { _ in
                let alertController = UIAlertController.deleteFileOrFolder(titleString: titleDelete + "?", message: message + fileList, canDeleteServer: canDeleteServer, selectedMetadatas: selectedMetadatas, sceneIdentifier: controller?.sceneIdentifier) { _ in
                    completion?()
                }

                controller?.present(alertController, animated: true, completion: nil)
            })
    }

    /// Open "share view" (activity VC) to open files in another app
    static func share(selectedMetadatas: [tableMetadata], controller: NCMainTabBarController?, order: Int = 0, completion: (() -> Void)? = nil) -> NCMenuAction {
        NCMenuAction(
            title: NSLocalizedString("_share_", comment: ""),
            icon: NCImagesRepository.menuIconShare,
            order: order,
            action: { _ in
                NCActionCenter.shared.openActivityViewController(selectedMetadata: selectedMetadatas, controller: controller)
                completion?()
            }
        )
    }

    /// Set (or remove) a file as *available offline*. Downloads the file if not downloaded already
    static func setAvailableOfflineAction(selectedMetadatas: [tableMetadata], isAnyOffline: Bool, viewController: UIViewController, order: Int = 0, completion: (() -> Void)? = nil) -> NCMenuAction {
        NCMenuAction(
            title: isAnyOffline ? NSLocalizedString("_remove_available_offline_", comment: "") : NSLocalizedString("_set_available_offline_", comment: ""),
            icon: isAnyOffline ? NCImagesRepository.menuIconAvailableOffline : NCImagesRepository.menuIconAddToOffline,
            order: order,
            action: { _ in
                if !isAnyOffline, selectedMetadatas.count > 3 {
                    let alert = UIAlertController(
                        title: NSLocalizedString("_set_available_offline_", comment: ""),
                        message: NSLocalizedString("_select_offline_warning_", comment: ""),
                        preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("_continue_", comment: ""), style: .default, handler: { _ in
                        selectedMetadatas.forEach { NCActionCenter.shared.setMetadataAvalableOffline($0, isOffline: isAnyOffline) }
                        completion?()
                    }))
                    alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel))
                    viewController.present(alert, animated: true)
                } else {
                    selectedMetadatas.forEach { NCActionCenter.shared.setMetadataAvalableOffline($0, isOffline: isAnyOffline) }
                    completion?()
                }
            }
        )
    }
    /// Open view that lets the user move or copy the files within Nextcloud
    static func moveOrCopyAction(selectedMetadatas: [tableMetadata], viewController: UIViewController, order: Int = 0, completion: (() -> Void)? = nil) -> NCMenuAction {
        NCMenuAction(
            title: NSLocalizedString("_move_or_copy_", comment: ""),
            icon: NCImagesRepository.menuIconMoveOrCopy,
            order: order,
            action: { _ in
                var fileNameError: NKError?

                for metadata in selectedMetadatas {
                    if let sceneIdentifier = metadata.sceneIdentifier,
                       let controller = SceneManager.shared.getController(sceneIdentifier: sceneIdentifier),
                       let checkError = FileNameValidator.shared.checkFileName(metadata.fileNameView, account: controller.account) {

                        fileNameError = checkError
                        break
                    }
                }

                if let fileNameError {
                    viewController.present(UIAlertController.warning(message: "\(fileNameError.errorDescription) \(NSLocalizedString("_please_rename_file_", comment: ""))"), animated: true, completion: nil)
                } else {
                    let controller = viewController.mainTabBarController
                    NCActionCenter.shared.openSelectView(items: selectedMetadatas, controller: controller)
                    completion?()
                }
            }
        )
    }

    /// Lock or unlock a file using *files_lock*
    static func lockUnlockFiles(shouldLock: Bool, metadatas: [tableMetadata], order: Int = 0, completion: (() -> Void)? = nil) -> NCMenuAction {
        let titleKey: String
        if metadatas.count == 1 {
            titleKey = shouldLock ? "_lock_file_" : "_unlock_file_"
        } else {
            titleKey = shouldLock ? "_lock_selected_files_" : "_unlock_selected_files_"
        }
        let image = !shouldLock ? NCImagesRepository.menuIconLockOpen : NCImagesRepository.menuIconLock
        return NCMenuAction(
            title: NSLocalizedString(titleKey, comment: ""),
            icon: image,
            order: order,
            action: { _ in
                for metadata in metadatas where metadata.lock != shouldLock {
                    NCNetworking.shared.lockUnlockFile(metadata, shoulLock: shouldLock)
                }
                completion?()
            }
        )
    }
}

