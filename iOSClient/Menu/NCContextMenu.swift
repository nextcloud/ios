//
//  NCContextMenu.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 10/01/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
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
//

import Foundation
import NextcloudKit

class NCContextMenu: NSObject {

    func viewMenu(ocId: String, viewController: UIViewController, enableDeleteLocal: Bool, enableViewInFolder: Bool, image: UIImage?) -> UIMenu {

        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) else {
            return UIMenu()
        }

        let isDirectoryE2EE = NCUtility.shared.isDirectoryE2EE(metadata: metadata)
        var titleDeleteConfirmFile = NSLocalizedString("_delete_file_", comment: "")
        if metadata.directory { titleDeleteConfirmFile = NSLocalizedString("_delete_folder_", comment: "") }
        var titleSave: String = NSLocalizedString("_save_selected_files_", comment: "")
        let metadataMOV = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata)
        if metadataMOV != nil {
            titleSave = NSLocalizedString("_livephoto_save_", comment: "")
        }
        let titleFavorite = metadata.favorite ? NSLocalizedString("_remove_favorites_", comment: "") : NSLocalizedString("_add_favorites_", comment: "")

        let serverUrl = metadata.serverUrl + "/" + metadata.fileName
        var isOffline = false
        if metadata.directory {
            if let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate!.account, serverUrl)) {
                isOffline = directory.offline
            }
        } else {
            if let localFile = NCManageDatabase.shared.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
                isOffline = localFile.offline
            }
        }
        let titleOffline = isOffline ? NSLocalizedString("_remove_available_offline_", comment: "") : NSLocalizedString("_set_available_offline_", comment: "")
        let titleLock = metadata.lock ? NSLocalizedString("_unlock_file_", comment: "") : NSLocalizedString("_lock_file_", comment: "")
        let iconLock = metadata.lock ? "lock.open" : "lock"
        let copy = UIAction(title: NSLocalizedString("_copy_file_", comment: ""), image: UIImage(systemName: "doc.on.doc")) { _ in
            NCFunctionCenter.shared.copyPasteboard(pasteboardOcIds: [metadata.ocId], hudView: viewController.view)
        }

        let detail = UIAction(title: NSLocalizedString("_details_", comment: ""), image: UIImage(systemName: "info")) { _ in
            NCFunctionCenter.shared.openShare(viewController: viewController, metadata: metadata, indexPage: .activity)
        }

        let offline = UIAction(title: titleOffline, image: UIImage(systemName: "tray.and.arrow.down")) { _ in
            NCFunctionCenter.shared.setMetadataAvalableOffline(metadata, isOffline: isOffline)
            if let viewController = viewController as? NCCollectionViewCommon {
                viewController.reloadDataSource()
            }
        }

        let lockUnlock = UIAction(title: titleLock, image: UIImage(systemName: iconLock)) { _ in
            NCNetworking.shared.lockUnlockFile(metadata, shoulLock: !metadata.lock)
        }
        let save = UIAction(title: titleSave, image: UIImage(systemName: "square.and.arrow.down")) { _ in
            if metadataMOV != nil {
                NCFunctionCenter.shared.saveLivePhoto(metadata: metadata, metadataMOV: metadataMOV!)
            } else {
                if CCUtility.fileProviderStorageExists(metadata) {
                    NCFunctionCenter.shared.saveAlbum(metadata: metadata)
                } else {
                    NCOperationQueue.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorSaveAlbum)
                }
            }
        }

        let viewInFolder = UIAction(title: NSLocalizedString("_view_in_folder_", comment: ""), image: UIImage(systemName: "arrow.forward.square")) { _ in
            NCFunctionCenter.shared.openFileViewInFolder(serverUrl: metadata.serverUrl, fileNameBlink: metadata.fileName, fileNameOpen: nil)
        }

        let openIn = UIAction(title: NSLocalizedString("_open_in_", comment: ""), image: UIImage(systemName: "square.and.arrow.up") ) { _ in
            NCFunctionCenter.shared.openDownload(metadata: metadata, selector: NCGlobal.shared.selectorOpenIn)
        }

        let print = UIAction(title: NSLocalizedString("_print_", comment: ""), image: UIImage(systemName: "printer") ) { _ in
            NCFunctionCenter.shared.openDownload(metadata: metadata, selector: NCGlobal.shared.selectorPrint)
        }

        let modify = UIAction(title: NSLocalizedString("_modify_", comment: ""), image: UIImage(systemName: "pencil.tip.crop.circle")) { _ in
            NCFunctionCenter.shared.openDownload(metadata: metadata, selector: NCGlobal.shared.selectorLoadFileQuickLook)
        }

        let saveAsScan = UIAction(title: NSLocalizedString("_save_as_scan_", comment: ""), image: UIImage(systemName: "viewfinder.circle")) { _ in
            NCFunctionCenter.shared.openDownload(metadata: metadata, selector: NCGlobal.shared.selectorSaveAsScan)
        }

        // let open = UIMenu(title: NSLocalizedString("_open_", comment: ""), image: UIImage(systemName: "square.and.arrow.up"), children: [openIn, openQuickLook])

        let moveCopy = UIAction(title: NSLocalizedString("_move_or_copy_", comment: ""), image: UIImage(systemName: "arrow.up.right.square")) { _ in
            NCFunctionCenter.shared.openSelectView(items: [metadata])
        }

        let rename = UIAction(title: NSLocalizedString("_rename_", comment: ""), image: UIImage(systemName: "pencil")) { _ in

            if let vcRename = UIStoryboard(name: "NCRenameFile", bundle: nil).instantiateInitialViewController() as? NCRenameFile {

                vcRename.metadata = metadata
                vcRename.imagePreview = image

                let popup = NCPopupViewController(contentController: vcRename, popupWidth: vcRename.width, popupHeight: vcRename.height)

                viewController.present(popup, animated: true)
            }
        }

        let favorite = UIAction(title: titleFavorite, image: NCUtility.shared.loadImage(named: "star.fill", color: NCBrandColor.shared.yellowFavorite)) { _ in

            NCNetworking.shared.favoriteMetadata(metadata) { error in
                if error != .success {
                    NCContentPresenter.shared.showError(error: error)
                }
            }
        }

        let deleteConfirmFile = UIAction(title: titleDeleteConfirmFile, image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
            NCNetworking.shared.deleteMetadata(metadata, onlyLocalCache: false) { error in
                if error != .success {
                    NCContentPresenter.shared.showError(error: error)
                }
            }
        }

        let deleteConfirmLocal = UIAction(title: NSLocalizedString("_remove_local_file_", comment: ""), image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
            NCNetworking.shared.deleteMetadata(metadata, onlyLocalCache: true) { _ in
            }
        }

        var delete = UIMenu(title: NSLocalizedString("_delete_file_", comment: ""), image: UIImage(systemName: "trash"), options: .destructive, children: [deleteConfirmLocal, deleteConfirmFile])

        if !enableDeleteLocal {
            delete = UIMenu(title: NSLocalizedString("_delete_file_", comment: ""), image: UIImage(systemName: "trash"), options: .destructive, children: [deleteConfirmFile])
        }

        if metadata.directory {
            delete = UIMenu(title: NSLocalizedString("_delete_folder_", comment: ""), image: UIImage(systemName: "trash"), options: .destructive, children: [deleteConfirmFile])
        }

        // ------ MENU -----

        // DIR

        guard !metadata.directory else {
            var submenu = UIMenu()
            if !isDirectoryE2EE && metadata.e2eEncrypted {
                submenu = UIMenu(title: "", options: .displayInline, children: [favorite, offline, rename, moveCopy])
            } else {
                submenu = UIMenu(title: "", options: .displayInline, children: [favorite, offline, rename, moveCopy, delete])
            }
            guard appDelegate!.disableSharesView == false else { return submenu }
            return UIMenu(title: "", children: [detail, submenu])
        }

        // FILE

        var children: [UIMenuElement] = [offline, openIn, moveCopy, copy]

        if !metadata.lock {
            // Workaround: PROPPATCH doesn't work (favorite)
            // https://github.com/nextcloud/files_lock/issues/68
            children.insert(favorite, at: 0)
            children.append(delete)
            children.insert(rename, at: 3)
        } else if enableDeleteLocal {
            children.append(deleteConfirmLocal)
        }

        if NCManageDatabase.shared.getCapabilitiesServerInt(account: appDelegate!.account, elements: NCElementsJSON.shared.capabilitiesFilesLockVersion) >= 1, metadata.canUnlock(as: appDelegate!.userId) {
            children.insert(lockUnlock, at: metadata.lock ? 0 : 1)
        }

        if (metadata.contentType != "image/svg+xml") && (metadata.classFile == NKCommon.typeClassFile.image.rawValue || metadata.classFile == NKCommon.typeClassFile.video.rawValue) {
            children.insert(save, at: 2)
        }

        if (metadata.contentType != "image/svg+xml") && (metadata.classFile == NKCommon.typeClassFile.image.rawValue) {
            children.insert(saveAsScan, at: 2)
        }

        if (metadata.contentType != "image/svg+xml") && (metadata.classFile == NKCommon.typeClassFile.image.rawValue || metadata.contentType == "application/pdf" || metadata.contentType == "com.adobe.pdf") {
            children.insert(print, at: 2)
        }

        if enableViewInFolder {
            children.insert(viewInFolder, at: children.count - 1)
        }

        if (!isDirectoryE2EE && metadata.contentType != "image/gif" && metadata.contentType != "image/svg+xml") && (metadata.contentType == "com.adobe.pdf" || metadata.contentType == "application/pdf" || metadata.classFile == NKCommon.typeClassFile.image.rawValue) {
            children.insert(modify, at: children.count - 1)
        }

        let submenu = UIMenu(title: "", options: .displayInline, children: children)
        guard appDelegate!.disableSharesView == false else { return submenu }
        return UIMenu(title: "", children: [detail, submenu])
    }
}
