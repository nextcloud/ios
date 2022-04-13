//
//  NCMenuAction.swift
//  Nextcloud
//
//  Created by Henrik Storch on 17.02.22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//

import Foundation
import UIKit

class NCMenuAction {
    let title: String
    let icon: UIImage
    let selectable: Bool
    var onTitle: String?
    var onIcon: UIImage?
    var selected: Bool = false
    var isOn: Bool = false
    var action: ((_ menuAction: NCMenuAction) -> Void)?

    init(title: String, icon: UIImage, action: ((_ menuAction: NCMenuAction) -> Void)?) {
        self.title = title
        self.icon = icon
        self.action = action
        self.selectable = false
    }

    init(title: String, icon: UIImage, onTitle: String? = nil, onIcon: UIImage? = nil, selected: Bool, on: Bool, action: ((_ menuAction: NCMenuAction) -> Void)?) {
        self.title = title
        self.icon = icon
        self.onTitle = onTitle ?? title
        self.onIcon = onIcon ?? icon
        self.action = action
        self.selected = selected
        self.isOn = on
        self.selectable = true
    }
}

// MARK: - Actions

extension NCMenuAction {
    static let seperatorIdentifier = "NCMenuAction.SEPERATOR"

    /// A static seperator, with no actions, text, or icons
    static var seperator: NCMenuAction {
        return NCMenuAction(title: seperatorIdentifier, icon: UIImage(), action: nil)
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
    static func copyAction(selectOcId: [String], hudView: UIView, completion: (() -> Void)? = nil) -> NCMenuAction {
        NCMenuAction(
            title: NSLocalizedString("_copy_file_", comment: ""),
            icon: NCUtility.shared.loadImage(named: "doc.on.doc"),
            action: { _ in
                NCFunctionCenter.shared.copyPasteboard(pasteboardOcIds: selectOcId, hudView: hudView)
                completion?()
            }
        )
    }

    /// Delete files either from cache or from Nextcloud
    static func deleteAction(selectedMetadatas: [tableMetadata], metadataFolder: tableMetadata? = nil, viewController: UIViewController, completion: (() -> Void)? = nil) -> NCMenuAction {
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

        let canDeleteServer = selectedMetadatas.contains(
            where: { $0.canUnlock(as: (UIApplication.shared.delegate as? AppDelegate)?.userId ?? "") })
        var fileList = ""
        for (ix, metadata) in selectedMetadatas.enumerated() {
            guard ix < 3 else { fileList += "\n - ..."; break }
            fileList += "\n - " + metadata.fileName
        }

        return NCMenuAction(
            title: titleDelete,
            icon: NCUtility.shared.loadImage(named: "trash"),
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
    static func openInAction(selectedMetadatas: [tableMetadata], viewController: UIViewController, completion: (() -> Void)? = nil) -> NCMenuAction {
        NCMenuAction(
            title: NSLocalizedString("_open_in_", comment: ""),
            icon: NCUtility.shared.loadImage(named: "square.and.arrow.up"),
            action: { _ in
                if viewController is NCFileViewInFolder {
                    viewController.dismiss(animated: true) {
                        NCFunctionCenter.shared.openActivityViewController(selectedMetadata: selectedMetadatas)
                    }
                } else {
                    NCFunctionCenter.shared.openActivityViewController(selectedMetadata: selectedMetadatas)
                }
                completion?()
            }
        )
    }

    /// Save selected files to user's photo library
    static func saveMediaAction(selectedMediaMetadatas: [tableMetadata], completion: (() -> Void)? = nil) -> NCMenuAction {
        var title: String = NSLocalizedString("_save_selected_files_", comment: "")
        var icon = NCUtility.shared.loadImage(named: "square.and.arrow.down")
        if selectedMediaMetadatas.allSatisfy({ NCManageDatabase.shared.getMetadataLivePhoto(metadata: $0) != nil }) {
            title = NSLocalizedString("_livephoto_save_", comment: "")
            icon = NCUtility.shared.loadImage(named: "livephoto")
        }

        return NCMenuAction(
            title: title,
            icon: icon,
            action: { _ in
                for metadata in selectedMediaMetadatas {
                    if let metadataMOV = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
                        NCFunctionCenter.shared.saveLivePhoto(metadata: metadata, metadataMOV: metadataMOV)
                    } else {
                        if CCUtility.fileProviderStorageExists(metadata) {
                            NCFunctionCenter.shared.saveAlbum(metadata: metadata)
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
    static func setAvailableOfflineAction(selectedMetadatas: [tableMetadata], isAnyOffline: Bool, viewController: UIViewController, completion: (() -> Void)? = nil) -> NCMenuAction {
        NCMenuAction(
            title: isAnyOffline ? NSLocalizedString("_remove_available_offline_", comment: "") :  NSLocalizedString("_set_available_offline_", comment: ""),
            icon: NCUtility.shared.loadImage(named: "tray.and.arrow.down"),
            action: { _ in
                if !isAnyOffline, selectedMetadatas.count > 3 {
                    let alert = UIAlertController(
                        title: NSLocalizedString("_set_available_offline_", comment: ""),
                        message: NSLocalizedString("_select_offline_warning_", comment: ""),
                        preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("_continue_", comment: ""), style: .default, handler: { _ in
                        selectedMetadatas.forEach { NCFunctionCenter.shared.setMetadataAvalableOffline($0, isOffline: isAnyOffline) }
                        completion?()
                    }))
                    alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel))
                    viewController.present(alert, animated: true)
                } else {
                    selectedMetadatas.forEach { NCFunctionCenter.shared.setMetadataAvalableOffline($0, isOffline: isAnyOffline) }
                    completion?()
                }
            }
        )
    }

    /// Open view that lets the user move or copy the files within Nextcloud
    static func moveOrCopyAction(selectedMetadatas: [tableMetadata], completion: (() -> Void)? = nil) -> NCMenuAction {
        NCMenuAction(
            title: NSLocalizedString("_move_or_copy_selected_files_", comment: ""),
            icon: NCUtility.shared.loadImage(named: "arrow.up.right.square"),
            action: { _ in
                NCFunctionCenter.shared.openSelectView(items: selectedMetadatas)
                completion?()
            }
        )
    }

    /// Open AirPrint view to print a single file
    static func printAction(metadata: tableMetadata) -> NCMenuAction {
        NCMenuAction(
            title: NSLocalizedString("_print_", comment: ""),
            icon: NCUtility.shared.loadImage(named: "printer"),
            action: { _ in
                NCFunctionCenter.shared.openDownload(metadata: metadata, selector: NCGlobal.shared.selectorPrint)
            }
        )
    }

    /// Lock or unlock a file using files_lock
    static func lockUnlockFiles(shouldLock: Bool, metadatas: [tableMetadata], completion: (() -> Void)? = nil) -> NCMenuAction {
        let titleKey: String
        if metadatas.count == 1 {
            titleKey = shouldLock ? "_lock_file_" : "_unlock_file_"
        } else {
            titleKey = shouldLock ? "_lock_selected_files_" : "_unlock_selected_files_"
        }
        let imageName = !shouldLock ? "lock.open" : "lock"
        return NCMenuAction(
            title: NSLocalizedString(titleKey, comment: ""),
            icon: NCUtility.shared.loadImage(named: imageName),
            action: { _ in
                for metadata in metadatas where metadata.lock != shouldLock {
                    NCNetworking.shared.lockUnlockFile(metadata, shoulLock: shouldLock)
                }
                completion?()
            }
        )
    }
}
