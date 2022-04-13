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
import NCCommunication
import Queuer

extension NCCollectionViewCommon {

    func toggleMenu(metadata: tableMetadata, imageIcon: UIImage?) {

        var actions = [NCMenuAction]()

        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(metadata.ocId) else { return }
        let serverUrl = metadata.serverUrl + "/" + metadata.fileName
        let isFolderEncrypted = CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account, urlBase: metadata.urlBase)
        let serverUrlHome = NCUtilityFileSystem.shared.getHomeServer(account: appDelegate.account)
        let isOffline: Bool
        let canUnlock = metadata.canUnlock(as: appDelegate.userId)

        if metadata.directory, let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, serverUrl)) {
            isOffline = directory.offline
        } else if let localFile = NCManageDatabase.shared.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
            isOffline = localFile.offline
        } else { isOffline = false }

        let editors = NCUtility.shared.isDirectEditing(account: metadata.account, contentType: metadata.contentType)
        let isRichDocument = NCUtility.shared.isRichDocument(metadata)

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
                action: nil
            )
        )
        
        if metadata.lock {
            let lockOwnerName = metadata.lockOwnerDisplayName.isEmpty ? metadata.lockOwner : metadata.lockOwnerDisplayName
            let lockTime = DateFormatter.localizedString(from: metadata.lockTime ?? Date(), dateStyle: .short, timeStyle: .short)
            actions.append(
                NCMenuAction(
                    title: String(format: NSLocalizedString("_file_locked_by_at_", comment: ""), lockOwnerName, lockTime),
                    icon: NCUtility.shared.loadUserImage(
                        for: metadata.lockOwner,
                           displayName: lockOwnerName,
                           userBaseUrl: metadata),
                    action: nil)
            )
        }
        
        actions.append(.seperator)

        //
        // FAVORITE
        //
        actions.append(
            NCMenuAction(
                title: metadata.favorite ? NSLocalizedString("_remove_favorites_", comment: "") : NSLocalizedString("_add_favorites_", comment: ""),
                icon: NCUtility.shared.loadImage(named: "star.fill", color: NCBrandColor.shared.yellowFavorite),
                action: { _ in
                    NCNetworking.shared.favoriteMetadata(metadata) { errorCode, errorDescription in
                        if errorCode != 0 {
                            NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                        }
                    }
                }
            )
        )

        if !metadata.directory, canUnlock {
            actions.append(.lockUnlockFiles(shouldLock: !metadata.lock, metadatas: [metadata]))
        }

        //
        // DETAIL
        //
        if !isFolderEncrypted && !appDelegate.disableSharesView {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_details_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "info"),
                    action: { _ in
                        NCFunctionCenter.shared.openShare(viewController: self, metadata: metadata, indexPage: .activity)
                    }
                )
            )
        }

        //
        // OFFLINE
        //
        if !isFolderEncrypted {
            actions.append(.setAvailableOfflineAction(selectedMetadatas: [metadata], isAnyOffline: isOffline, viewController: self, completion: self.reloadDataSource))
        }

        //
        // OPEN with external editor
        //
        if metadata.classFile == NCCommunicationCommon.typeClassFile.document.rawValue && editors.contains(NCGlobal.shared.editorText) && ((editors.contains(NCGlobal.shared.editorOnlyoffice) || isRichDocument)) {

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
            actions.append(.openInAction(selectedMetadatas: [metadata], viewController: self))
        }

        //
        // PRINT
        //
        if metadata.isPrintable {
            actions.append(.printAction(metadata: metadata))
        }

        //
        // SAVE
        //
        if (metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue && metadata.contentType != "image/svg+xml") || metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue {
            actions.append(.saveMediaAction(selectedMediaMetadatas: [metadata]))
        }

        //
        // SAVE AS SCAN
        //
        if #available(iOS 13.0, *) {
            if metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue && metadata.contentType != "image/svg+xml" {
                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_save_as_scan_", comment: ""),
                        icon: NCUtility.shared.loadImage(named: "viewfinder.circle"),
                        action: { _ in
                            NCFunctionCenter.shared.openDownload(metadata: metadata, selector: NCGlobal.shared.selectorSaveAsScan)
                        }
                    )
                )
            }
        }

        //
        // RENAME
        //
        if !(isFolderEncrypted && metadata.serverUrl == serverUrlHome), canUnlock {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_rename_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "pencil"),
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
        if !isFolderEncrypted && serverUrl != "" {
            actions.append(.moveOrCopyAction(selectedMetadatas: [metadata]))
        }

        //
        // COPY
        //
        if !metadata.directory {
            actions.append(.copyAction(selectOcId: [metadata.ocId], hudView: self.view))
        }
        
        /*
        //
        // USE AS BACKGROUND
        //
        if #available(iOS 13.0, *) {
            if metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue && self.layoutKey == NCGlobal.shared.layoutViewFiles && !NCBrandOptions.shared.disable_background_image {
                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_use_as_background_", comment: ""),
                        icon: NCUtility.shared.loadImage(named: "text.below.photo"),
                        action: { menuAction in
                            if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                                NCFunctionCenter.shared.saveBackground(metadata: metadata)
                            } else {
                                NCOperationQueue.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorSaveBackground)
                            }
                        }
                    )
                )
            }
        }
        */

        //
        // MODIFY
        //
        if #available(iOS 13.0, *) {
            if !isFolderEncrypted && metadata.contentType != "image/gif" && metadata.contentType != "image/svg+xml" && (metadata.contentType == "com.adobe.pdf" || metadata.contentType == "application/pdf" || metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue) {
                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_modify_", comment: ""),
                        icon: NCUtility.shared.loadImage(named: "pencil.tip.crop.circle"),
                        action: { menuAction in
                            if self is NCFileViewInFolder {
                                self.dismiss(animated: true) {
                                    NCFunctionCenter.shared.openDownload(metadata: metadata, selector: NCGlobal.shared.selectorLoadFileQuickLook)
                                }
                            } else {
                                NCFunctionCenter.shared.openDownload(metadata: metadata, selector: NCGlobal.shared.selectorLoadFileQuickLook)
                            }
                        }
                    )
                )
            }
        }

        //
        // DELETE
        //
        actions.append(.deleteAction(selectedMetadatas: [metadata], metadataFolder: metadataFolder, viewController: self))

        //
        // SET FOLDER E2EE
        //
        if !metadata.e2eEncrypted && metadata.directory && CCUtility.isEnd(toEndEnabled: appDelegate.account) && metadata.serverUrl == serverUrlHome {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_e2e_set_folder_encrypted_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "lock"),
                    action: { _ in
                        NCCommunication.shared.markE2EEFolder(fileId: metadata.fileId, delete: false) { account, errorCode, errorDescription in
                            if errorCode == 0 {
                                NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, serverUrl))
                                NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, serverUrlTo: nil, etag: nil, ocId: nil, fileId: nil, encrypted: true, richWorkspace: nil, account: metadata.account)
                                NCManageDatabase.shared.setMetadataEncrypted(ocId: metadata.ocId, encrypted: true)

                                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeStatusFolderE2EE, userInfo: ["serverUrl": metadata.serverUrl])
                            } else {
                                NCContentPresenter.shared.messageNotification(NSLocalizedString("_e2e_error_mark_folder_", comment: ""), description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: .error, errorCode: errorCode)
                            }
                        }
                    }
                )
            )
        }

        //
        // UNSET FOLDER E2EE
        //
        if metadata.e2eEncrypted && metadata.directory && CCUtility.isEnd(toEndEnabled: appDelegate.account) && metadata.serverUrl == serverUrlHome {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_e2e_remove_folder_encrypted_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "lock"),
                    action: { _ in
                        NCCommunication.shared.markE2EEFolder(fileId: metadata.fileId, delete: true) { account, errorCode, errorDescription in
                            if errorCode == 0 {
                                NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, serverUrl))
                                NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, serverUrlTo: nil, etag: nil, ocId: nil, fileId: nil, encrypted: false, richWorkspace: nil, account: metadata.account)
                                NCManageDatabase.shared.setMetadataEncrypted(ocId: metadata.ocId, encrypted: false)

                                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeStatusFolderE2EE, userInfo: ["serverUrl": metadata.serverUrl])
                            } else {
                                NCContentPresenter.shared.messageNotification(NSLocalizedString("_e2e_error_delete_mark_folder_", comment: ""), description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: .error, errorCode: errorCode)
                            }
                        }
                    }
                )
            )
        }

        presentMenu(with: actions)
    }
}
