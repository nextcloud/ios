//
//  NCCollectionViewCommon+Menu.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 24.01.20.
//  Copyright © 2020 Philippe Weidmann. All rights reserved.
//  Copyright © 2020 Marino Faggiana All rights reserved.
//  Copyright © 2022 Henrik Storch. All rights reserved.
//
//  Author Philippe Weidmann
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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
import FloatingPanel
import NextcloudKit
import Queuer

extension NCCollectionViewCommon {

    func toggleMenu(metadata: tableMetadata, imageIcon: UIImage?) {

        var actions = [NCMenuAction]()

        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(metadata.ocId) else { return }
        let serverUrl = metadata.serverUrl + "/" + metadata.fileName
        let isDirectoryE2EE = NCUtility.shared.isDirectoryE2EE(metadata: metadata)
        let serverUrlHome = NCUtilityFileSystem.shared.getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId)
        let isOffline: Bool

        if metadata.directory, let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, serverUrl)) {
            isOffline = directory.offline
        } else if let localFile = NCManageDatabase.shared.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
            isOffline = localFile.offline
        } else { isOffline = false }

        let editors = NCUtility.shared.isDirectEditing(account: metadata.account, contentType: metadata.contentType)
        let isRichDocument = NCUtility.shared.isRichDocument(metadata)
        let applicationHandle = NCApplicationHandle()

        var iconHeader: UIImage!

        if imageIcon != nil {
            iconHeader = imageIcon!
        } else {
            if metadata.directory {
                iconHeader = NCBrandColor.cacheImages.folder
            } else {
                iconHeader = NCBrandColor.cacheImages.file
            }
        }

        actions.append(
            NCMenuAction(
                title: metadata.fileNameView,
                icon: iconHeader,
                order: 0,
                action: nil
            )
        )

        if metadata.lock {
            var lockOwnerName = metadata.lockOwnerDisplayName.isEmpty ? metadata.lockOwner : metadata.lockOwnerDisplayName
            var lockIcon = NCUtility.shared.loadUserImage(for: metadata.lockOwner, displayName: lockOwnerName, userBaseUrl: metadata)
            if metadata.lockOwnerType != 0 {
                lockOwnerName += " app"
                if !metadata.lockOwnerEditor.isEmpty, let appIcon = UIImage(named: metadata.lockOwnerEditor) {
                    lockIcon = appIcon
                }
            }

            var lockTimeString: String?
            if let lockTime = metadata.lockTimeOut {
                if lockTime >= Date().addingTimeInterval(60),
                   let timeInterval = (lockTime.timeIntervalSince1970 - Date().timeIntervalSince1970).format() {
                    lockTimeString = String(format: NSLocalizedString("_time_remaining_", comment: ""), timeInterval)
                } else if lockTime > Date() {
                    lockTimeString = NSLocalizedString("_less_a_minute_", comment: "")
                } // else: don't show negative time
            }
            if let lockTime = metadata.lockTime, lockTimeString == nil {
                lockTimeString = DateFormatter.localizedString(from: lockTime, dateStyle: .short, timeStyle: .short)
            }

            actions.append(
                NCMenuAction(
                    title: String(format: NSLocalizedString("_locked_by_", comment: ""), lockOwnerName),
                    details: lockTimeString,
                    icon: lockIcon,
                    order: 10,
                    action: nil)
            )
        }

        //
        // LOCK / UNLOCK
        //
        let hasLockCapability = NCManageDatabase.shared.getCapabilitiesServerInt(account: appDelegate.account, elements: NCElementsJSON.shared.capabilitiesFilesLockVersion) >= 1
        if !metadata.directory, metadata.canUnlock(as: appDelegate.userId), hasLockCapability {
            actions.append(NCMenuAction.lockUnlockFiles(shouldLock: !metadata.lock, metadatas: [metadata], order: 15))
        }

        //
        // SET FOLDER E2EE (ONLY ROOT)
        //
        //if !isDirectoryE2EE && metadata.directory && metadata.size == 0 && !metadata.e2eEncrypted && CCUtility.isEnd(toEndEnabled: appDelegate.account) {
        if metadata.serverUrl == serverUrlHome && metadata.directory && metadata.size == 0 && !metadata.e2eEncrypted && CCUtility.isEnd(toEndEnabled: appDelegate.account) {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_e2e_set_folder_encrypted_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "lock"),
                    order: 15,
                    action: { _ in
                        NextcloudKit.shared.markE2EEFolder(fileId: metadata.fileId, delete: false) { account, error in
                            if error == .success {
                                NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, serverUrl))
                                NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, serverUrlTo: nil, etag: nil, ocId: nil, fileId: nil, encrypted: true, richWorkspace: nil, account: metadata.account)
                                NCManageDatabase.shared.setMetadataEncrypted(ocId: metadata.ocId, encrypted: true)

                                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeStatusFolderE2EE, userInfo: ["serverUrl": metadata.serverUrl])
                            } else {
                                NCContentPresenter.shared.messageNotification(NSLocalizedString("_e2e_error_mark_folder_", comment: ""), error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .error)
                            }
                        }
                    }
                )
            )
        }

        //
        // UNSET FOLDER E2EE
        //
        if !isDirectoryE2EE && metadata.directory && metadata.size == 0 && metadata.e2eEncrypted && CCUtility.isEnd(toEndEnabled: appDelegate.account) {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_e2e_remove_folder_encrypted_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "lock"),
                    order: 15,
                    action: { _ in
                        NextcloudKit.shared.markE2EEFolder(fileId: metadata.fileId, delete: true) { account, error in
                            if error == .success {
                                NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, serverUrl))
                                NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, serverUrlTo: nil, etag: nil, ocId: nil, fileId: nil, encrypted: false, richWorkspace: nil, account: metadata.account)
                                NCManageDatabase.shared.setMetadataEncrypted(ocId: metadata.ocId, encrypted: false)

                                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeStatusFolderE2EE, userInfo: ["serverUrl": metadata.serverUrl])
                            } else {
                                NCContentPresenter.shared.messageNotification(NSLocalizedString("_e2e_error_delete_mark_folder_", comment: ""), error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .error)
                            }
                        }
                    }
                )
            )
        }


        actions.append(.seperator(order: 20))

        //
        // FAVORITE
        // FIXME: PROPPATCH doesn't work
        // https://github.com/nextcloud/files_lock/issues/68
        if !metadata.lock {
            actions.append(
                NCMenuAction(
                    title: metadata.favorite ? NSLocalizedString("_remove_favorites_", comment: "") : NSLocalizedString("_add_favorites_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "star.fill", color: NCBrandColor.shared.yellowFavorite),
                    order: 30,
                    action: { _ in
                        NCNetworking.shared.favoriteMetadata(metadata) { error in
                            if error != .success {
                                NCContentPresenter.shared.showError(error: error)
                            }
                        }
                    }
                )
            )
        }

        //
        // DETAILS
        //
        if !appDelegate.disableSharesView {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_details_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "info"),
                    order: 40,
                    action: { _ in
                        NCFunctionCenter.shared.openShare(viewController: self, metadata: metadata, indexPage: .activity)
                    }
                )
            )
        }

        //
        // OFFLINE
        //
        actions.append(.setAvailableOfflineAction(selectedMetadatas: [metadata], isAnyOffline: isOffline, viewController: self, order: 60, completion: {
            self.reloadDataSource()
        }))

        //
        // OPEN with external editor
        //
        if metadata.classFile == NKCommon.typeClassFile.document.rawValue && editors.contains(NCGlobal.shared.editorText) && ((editors.contains(NCGlobal.shared.editorOnlyoffice) || isRichDocument)) {

            var editor = ""
            var title = ""
            var icon: UIImage?

            if editors.contains(NCGlobal.shared.editorOnlyoffice) {
                editor = NCGlobal.shared.editorOnlyoffice
                title = NSLocalizedString("_open_in_onlyoffice_", comment: "")
                icon = NCUtility.shared.loadImage(named: "onlyoffice")
            } else if isRichDocument {
                editor = NCGlobal.shared.editorCollabora
                title = NSLocalizedString("_open_in_collabora_", comment: "")
                icon = NCUtility.shared.loadImage(named: "collabora")
            }

            if editor != "" {
                actions.append(
                    NCMenuAction(
                        title: title,
                        icon: icon!,
                        order: 70,
                        action: { _ in
                            NCViewer.shared.view(viewController: self, metadata: metadata, metadatas: [metadata], imageIcon: imageIcon, editor: editor, isRichDocument: isRichDocument)
                        }
                    )
                )
            }
        }

        //
        // OPEN IN
        //
        if !metadata.directory && !NCBrandOptions.shared.disable_openin_file {
            actions.append(.openInAction(selectedMetadatas: [metadata], viewController: self, order: 80))
        }

        //
        // PRINT
        //
        if metadata.isPrintable {
            actions.append(.printAction(metadata: metadata, order: 90))
        }

        //
        // SAVE
        //
        if (metadata.classFile == NKCommon.typeClassFile.image.rawValue && metadata.contentType != "image/svg+xml") || metadata.classFile == NKCommon.typeClassFile.video.rawValue {
            actions.append(.saveMediaAction(selectedMediaMetadatas: [metadata], order: 100))
        }

        //
        // SAVE AS SCAN
        //
        if metadata.classFile == NKCommon.typeClassFile.image.rawValue && metadata.contentType != "image/svg+xml" {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_save_as_scan_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "viewfinder.circle"),
                    order: 110,
                    action: { _ in
                        NCFunctionCenter.shared.openDownload(metadata: metadata, selector: NCGlobal.shared.selectorSaveAsScan)
                    }
                )
            )
        }

        //
        // RENAME
        //
        if (!isDirectoryE2EE && metadata.e2eEncrypted) || metadata.lock {
            print("Not possible rename")
        } else {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_rename_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "pencil"),
                    order: 120,
                    action: { _ in

                        if let vcRename = UIStoryboard(name: "NCRenameFile", bundle: nil).instantiateInitialViewController() as? NCRenameFile {

                            vcRename.metadata = metadata
                            vcRename.imagePreview = imageIcon

                            let popup = NCPopupViewController(contentController: vcRename, popupWidth: vcRename.width, popupHeight: vcRename.height)

                            self.present(popup, animated: true)
                        }
                    }
                )
            )
        }

        //
        // COPY - MOVE
        //
        if isDirectoryE2EE || metadata.e2eEncrypted {
            print("Not possible copy/move")
        } else {
            actions.append(.moveOrCopyAction(selectedMetadatas: [metadata], order: 130))
        }

        //
        // COPY
        //
        if !metadata.directory {
            actions.append(.copyAction(selectOcId: [metadata.ocId], hudView: self.view, order: 140))
        }
        
        //
        // MODIFY
        //
        if !isDirectoryE2EE && metadata.contentType != "image/gif" && metadata.contentType != "image/svg+xml" && (metadata.contentType == "com.adobe.pdf" || metadata.contentType == "application/pdf" || metadata.classFile == NKCommon.typeClassFile.image.rawValue) {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_modify_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "pencil.tip.crop.circle"),
                    order: 150,
                    action: { menuAction in
                        NCFunctionCenter.shared.openDownload(metadata: metadata, selector: NCGlobal.shared.selectorLoadFileQuickLook)
                    }
                )
            )
        }

        //
        // COLOR FOLDER
        //
        if self is NCFiles, metadata.directory {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_change_color_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "palette"),
                    order: 160,
                    action: { _ in
                        if let picker = UIStoryboard(name: "NCColorPicker", bundle: nil).instantiateInitialViewController() as? NCColorPicker {
                            picker.metadata = metadata
                            let popup = NCPopupViewController(contentController: picker, popupWidth: 200, popupHeight: 320)
                            popup.backgroundAlpha = 0
                            self.present(popup, animated: true)
                        }
                    }
                )
            )
        }
        
        //
        // DELETE
        //
        if !isDirectoryE2EE && metadata.e2eEncrypted {
            print("Not possible delete")
        } else {
            actions.append(.deleteAction(selectedMetadatas: [metadata], metadataFolder: metadataFolder, viewController: self, order: 170))
        }

        applicationHandle.addCollectionViewCommonMenu(metadata: metadata, imageIcon: imageIcon, actions: &actions)

        presentMenu(with: actions)
    }
}

extension TimeInterval {
    func format() -> String? {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        return formatter.string(from: self)
    }
}
