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
    let details: String?
    let icon: UIImage
    let selectable: Bool
    var onTitle: String?
    var onIcon: UIImage?
    var selected: Bool = false
    var isOn: Bool = false
    var action: ((_ menuAction: NCMenuAction) -> Void)?
    var rowHeight: CGFloat { self.title == NCMenuAction.seperatorIdentifier ? NCMenuAction.seperatorHeight : self.details != nil ? 80 : 60 }
    var order: Int = 0

    init(title: String, details: String? = nil, icon: UIImage, order: Int = 0, action: ((_ menuAction: NCMenuAction) -> Void)?) {
        self.title = title
        self.details = details
        self.icon = icon
        self.action = action
        self.selectable = false
        self.order = order
    }

    init(title: String, details: String? = nil, icon: UIImage, onTitle: String? = nil, onIcon: UIImage? = nil, selected: Bool, on: Bool, order: Int = 0, action: ((_ menuAction: NCMenuAction) -> Void)?) {
        self.title = title
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
            icon: NCUtility.shared.loadImage(named: "checkmark.circle.fill"),
            action: { _ in action() }
        )
    }

    /// Copy files to pasteboard
    static func copyAction(selectOcId: [String], hudView: UIView, order: Int = 0, completion: (() -> Void)? = nil) -> NCMenuAction {
        NCMenuAction(
            title: NSLocalizedString("_copy_file_", comment: ""),
            icon: NCUtility.shared.loadImage(named: "doc.on.doc"),
            order: order,
            action: { _ in
                NCActionCenter.shared.copyPasteboard(pasteboardOcIds: selectOcId, hudView: hudView)
                completion?()
            }
        )
    }

    /// Delete files either from cache or from Nextcloud
    static func deleteAction(selectedMetadatas: [tableMetadata], metadataFolder: tableMetadata? = nil, viewController: UIViewController, order: Int = 0, completion: (() -> Void)? = nil) -> NCMenuAction {
        var titleDelete = NSLocalizedString("_delete_", comment: "")
        if selectedMetadatas.count > 1 {
            titleDelete = NSLocalizedString("_delete_selected_files_", comment: "")
        } else if let metadata = selectedMetadatas.first {
            if NCManageDatabase.shared.isMetadataShareOrMounted(metadata: metadata, metadataFolder: metadataFolder) {
                titleDelete = NSLocalizedString("_leave_share_", comment: "")
            } else if metadata.directory {
                titleDelete = NSLocalizedString("_delete_folder_", comment: "")
            } else {
                titleDelete = NSLocalizedString("_delete_file_", comment: "")
            }

            if let metadataFolder = metadataFolder {
                let isShare = metadata.permissions.contains(NCGlobal.shared.permissionShared) && !metadataFolder.permissions.contains(NCGlobal.shared.permissionShared)
                let isMounted = metadata.permissions.contains(NCGlobal.shared.permissionMounted) && !metadataFolder.permissions.contains(NCGlobal.shared.permissionMounted)
                if isShare || isMounted {
                    titleDelete = NSLocalizedString("_leave_share_", comment: "")
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
            icon: NCUtility.shared.loadImage(named: "trash"),
            order: order,
            action: { _ in
                let alertController = UIAlertController(
                    title: titleDelete,
                    message: NSLocalizedString("_want_delete_", comment: "") + fileList,
                    preferredStyle: .alert)
                if canDeleteServer {
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_delete_", comment: ""), style: .default) { (_: UIAlertAction) in
                        selectedMetadatas.forEach({ NCOperationQueue.shared.delete(metadata: $0, onlyLocalCache: false) })
                        completion?()
                    })
                }

                // NCMedia removes image from collection view if removed from cache
                if !(viewController is NCMedia) {
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("_remove_local_file_", comment: ""), style: .default) { (_: UIAlertAction) in
                        selectedMetadatas.forEach({ NCOperationQueue.shared.delete(metadata: $0, onlyLocalCache: true) })
                        completion?()
                    })
                }
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_delete_", comment: ""), style: .default) { (_: UIAlertAction) in })
                viewController.present(alertController, animated: true, completion: nil)
            }
        )
    }

    /// Open "share view" (activity VC) to open files in another app
    static func openInAction(selectedMetadatas: [tableMetadata], viewController: UIViewController, order: Int = 0, completion: (() -> Void)? = nil) -> NCMenuAction {
        NCMenuAction(
            title: NSLocalizedString("_open_in_", comment: ""),
            icon: NCUtility.shared.loadImage(named: "square.and.arrow.up"),
            order: order,
            action: { _ in
                NCActionCenter.shared.openActivityViewController(selectedMetadata: selectedMetadatas)
                completion?()
            }
        )
    }

    /// Save selected files to user's photo library
    static func saveMediaAction(selectedMediaMetadatas: [tableMetadata], order: Int = 0, completion: (() -> Void)? = nil) -> NCMenuAction {
        var title: String = NSLocalizedString("_save_selected_files_", comment: "")
        var icon = NCUtility.shared.loadImage(named: "square.and.arrow.down")
        if selectedMediaMetadatas.allSatisfy({ NCManageDatabase.shared.getMetadataLivePhoto(metadata: $0) != nil }) {
            title = NSLocalizedString("_livephoto_save_", comment: "")
            icon = NCUtility.shared.loadImage(named: "livephoto")
        }

        return NCMenuAction(
            title: title,
            icon: icon,
            order: order,
            action: { _ in
                for metadata in selectedMediaMetadatas {
                    if let metadataMOV = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
                        NCActionCenter.shared.saveLivePhoto(metadata: metadata, metadataMOV: metadataMOV)
                    } else {
                        if CCUtility.fileProviderStorageExists(metadata) {
                            NCActionCenter.shared.saveAlbum(metadata: metadata)
                        } else {
                            NCOperationQueue.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorSaveAlbum)
                        }
                    }
                }
                completion?()
            }
        )
    }

    /// Set (or remove) a file as *available offline*. Downloads the file if not downloaded already
    static func setAvailableOfflineAction(selectedMetadatas: [tableMetadata], isAnyOffline: Bool, viewController: UIViewController, order: Int = 0, completion: (() -> Void)? = nil) -> NCMenuAction {
        NCMenuAction(
            title: isAnyOffline ? NSLocalizedString("_remove_available_offline_", comment: "") : NSLocalizedString("_set_available_offline_", comment: ""),
            icon: NCUtility.shared.loadImage(named: "tray.and.arrow.down"),
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
    static func moveOrCopyAction(selectedMetadatas: [tableMetadata], order: Int = 0, completion: (() -> Void)? = nil) -> NCMenuAction {
        NCMenuAction(
            title: NSLocalizedString("_move_or_copy_selected_files_", comment: ""),
            icon: NCUtility.shared.loadImage(named: "arrow.up.right.square"),
            order: order,
            action: { _ in
                NCActionCenter.shared.openSelectView(items: selectedMetadatas)
                completion?()
            }
        )
    }

    /// Open AirPrint view to print a single file
    static func printAction(metadata: tableMetadata, order: Int = 0) -> NCMenuAction {
        NCMenuAction(
            title: NSLocalizedString("_print_", comment: ""),
            icon: NCUtility.shared.loadImage(named: "printer"),
            order: order,
            action: { _ in
                if CCUtility.fileProviderStorageExists(metadata) {
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadedFile, userInfo: ["ocId": metadata.ocId, "selector": NCGlobal.shared.selectorPrint, "error": NKError(), "account": metadata.account])
                } else {
                    NCNetworking.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorPrint) { _, _ in }
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
        let imageName = !shouldLock ? "lock_open" : "lock"
        return NCMenuAction(
            title: NSLocalizedString(titleKey, comment: ""),
            icon: NCUtility.shared.loadImage(named: imageName),
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
