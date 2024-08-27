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
    func toggleMenu(metadata: tableMetadata, indexPath: IndexPath, imageIcon: UIImage?) {
        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(metadata.ocId),
              let sceneIdentifier = (tabBarController as? NCMainTabBarController)?.sceneIdentifier else { return }
        var actions = [NCMenuAction]()
        let serverUrl = metadata.serverUrl + "/" + metadata.fileName
        var isOffline: Bool = false
        let applicationHandle = NCApplicationHandle()
        var iconHeader: UIImage!

        if metadata.directory, let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", appDelegate.account, serverUrl)) {
            isOffline = directory.offline
        } else if let localFile = NCManageDatabase.shared.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
            isOffline = localFile.offline
        }

        if imageIcon != nil {
            iconHeader = imageIcon!
        } else {
            if metadata.directory {
                iconHeader = NCImageCache.images.folder
            } else {
                iconHeader = NCImageCache.images.file
            }
        }

        actions.append(
            NCMenuAction(
                title: metadata.fileNameView,
                boldTitle: true,
                icon: iconHeader,
                order: 0,
                action: nil
            )
        )

        actions.append(.seperator(order: 1))

        //
        // DETAILS
        //
        if !NCGlobal.shared.disableSharesView {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_details_", comment: ""),
                    icon: utility.loadImage(named: "info.circle", colors: [NCBrandColor.shared.iconImageColor]),
                    order: 10,
                    action: { _ in
                        NCActionCenter.shared.openShare(viewController: self, metadata: metadata, page: .activity)
                    }
                )
            )
        }

        if metadata.lock {
            var lockOwnerName = metadata.lockOwnerDisplayName.isEmpty ? metadata.lockOwner : metadata.lockOwnerDisplayName
            var lockIcon = utility.loadUserImage(for: metadata.lockOwner, displayName: lockOwnerName, userBaseUrl: metadata)
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
                    order: 20,
                    action: nil)
            )
        }

        //
        // VIEW IN FOLDER
        //
        if layoutKey != NCGlobal.shared.layoutViewFiles {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_view_in_folder_", comment: ""),
                    icon: utility.loadImage(named: "questionmark.folder", colors: [NCBrandColor.shared.iconImageColor]),
                    order: 21,
                    action: { _ in
                        NCActionCenter.shared.openFileViewInFolder(serverUrl: metadata.serverUrl, fileNameBlink: metadata.fileName, fileNameOpen: nil, sceneIdentifier: sceneIdentifier)
                    }
                )
            )
        }

        //
        // LOCK / UNLOCK
        //
        if !metadata.directory, metadata.canUnlock(as: appDelegate.userId), !NCGlobal.shared.capabilityFilesLockVersion.isEmpty {
            actions.append(NCMenuAction.lockUnlockFiles(shouldLock: !metadata.lock, metadatas: [metadata], order: 30))
        }

        //
        // SET FOLDER E2EE
        //
        if metadata.canSetDirectoryAsE2EE {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_e2e_set_folder_encrypted_", comment: ""),
                    icon: utility.loadImage(named: "lock", colors: [NCBrandColor.shared.iconImageColor]),
                    order: 30,
                    action: { _ in
                        Task {
                            let error = await NCNetworkingE2EEMarkFolder().markFolderE2ee(account: metadata.account, fileName: metadata.fileName, serverUrl: metadata.serverUrl, userId: metadata.userId)
                            if error != .success {
                                NCContentPresenter().showError(error: error)
                            }
                        }
                    }
                )
            )
        }

        //
        // UNSET FOLDER E2EE
        //
        if metadata.canUnsetDirectoryAsE2EE {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_e2e_remove_folder_encrypted_", comment: ""),
                    icon: utility.loadImage(named: "lock", colors: [NCBrandColor.shared.iconImageColor]),
                    order: 30,
                    action: { _ in
                        NextcloudKit.shared.markE2EEFolder(fileId: metadata.fileId, delete: true, account: metadata.account) { _, error in
                            if error == .success {
                                NCManageDatabase.shared.deleteE2eEncryption(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", self.appDelegate.account, serverUrl))
                                NCManageDatabase.shared.setDirectory(serverUrl: serverUrl, encrypted: false, account: metadata.account)
                                NCManageDatabase.shared.setMetadataEncrypted(ocId: metadata.ocId, encrypted: false)

                                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterChangeStatusFolderE2EE, userInfo: ["serverUrl": metadata.serverUrl])
                            } else {
                                NCContentPresenter().messageNotification(NSLocalizedString("_e2e_error_", comment: ""), error: error, delay: NCGlobal.shared.dismissAfterSecond, type: .error)
                            }
                        }
                    }
                )
            )
        }

        //
        // FAVORITE
        // FIXME: PROPPATCH doesn't work
        // https://github.com/nextcloud/files_lock/issues/68
        if !metadata.lock {
            actions.append(
                NCMenuAction(
                    title: metadata.favorite ? NSLocalizedString("_remove_favorites_", comment: "") : NSLocalizedString("_add_favorites_", comment: ""),
                    icon: utility.loadImage(named: metadata.favorite ? "star.slash" : "star", colors: [NCBrandColor.shared.yellowFavorite]),
                    order: 50,
                    action: { _ in
                        NCNetworking.shared.favoriteMetadata(metadata) { error in
                            if error != .success {
                                NCContentPresenter().showError(error: error)
                            }
                        }
                    }
                )
            )
        }

        //
        // OFFLINE
        //
        if metadata.canSetAsAvailableOffline {
            actions.append(.setAvailableOfflineAction(selectedMetadatas: [metadata], isAnyOffline: isOffline, viewController: self, order: 60, completion: {
                self.reloadDataSource()
            }))
        }

        //
        // SHARE
        //
        if metadata.canShare {
            actions.append(.share(selectedMetadatas: [metadata], viewController: self, order: 80))
        }

        //
        // SAVE LIVE PHOTO
        //
        if let metadataMOV = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata),
           let hudView = self.tabBarController?.view {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_livephoto_save_", comment: ""),
                    icon: NCUtility().loadImage(named: "livephoto", colors: [NCBrandColor.shared.iconImageColor]),
                    order: 100,
                    action: { _ in
                        NCNetworking.shared.saveLivePhotoQueue.addOperation(NCOperationSaveLivePhoto(metadata: metadata, metadataMOV: metadataMOV, hudView: hudView))
                    }
                )
            )
        }

        //
        // SAVE AS SCAN
        //
        if metadata.isSavebleAsImage {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_save_as_scan_", comment: ""),
                    icon: utility.loadImage(named: "doc.viewfinder", colors: [NCBrandColor.shared.iconImageColor]),
                    order: 110,
                    action: { _ in
                        if self.utilityFileSystem.fileProviderStorageExists(metadata) {
                            NotificationCenter.default.post(
                                name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile),
                                object: nil,
                                userInfo: ["ocId": metadata.ocId,
                                           "selector": NCGlobal.shared.selectorSaveAsScan,
                                           "error": NKError(),
                                           "account": metadata.account])
                        } else {
                            guard let metadata = NCManageDatabase.shared.setMetadatasSessionInWaitDownload(metadatas: [metadata],
                                                                                                           session: NextcloudKit.shared.nkCommonInstance.sessionIdentifierDownload,
                                                                                                           selector: NCGlobal.shared.selectorSaveAsScan,
                                                                                                           sceneIdentifier: sceneIdentifier) else { return }
                            NCNetworking.shared.download(metadata: metadata, withNotificationProgressTask: true)
                        }
                    }
                )
            )
        }

        //
        // RENAME
        //
        if metadata.isRenameable {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_rename_", comment: ""),
                    icon: utility.loadImage(named: "text.cursor", colors: [NCBrandColor.shared.iconImageColor]),
                    order: 120,
                    action: { _ in
                        self.present(UIAlertController.renameFile(metadata: metadata, indexPath: indexPath), animated: true)
                    }
                )
            )
        }

        //
        // COPY - MOVE
        //
        if metadata.isCopyableMovable {
            actions.append(.moveOrCopyAction(selectedMetadatas: [metadata], viewController: self, indexPath: [indexPath], order: 130))
        }

        //
        // MODIFY WITH QUICK LOOK
        //
        if metadata.isModifiableWithQuickLook {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_modify_", comment: ""),
                    icon: utility.loadImage(named: "pencil.tip.crop.circle", colors: [NCBrandColor.shared.iconImageColor]),
                    order: 150,
                    action: { _ in
                        if self.utilityFileSystem.fileProviderStorageExists(metadata) {
                            NotificationCenter.default.post(
                                name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile),
                                object: nil,
                                userInfo: ["ocId": metadata.ocId,
                                           "selector": NCGlobal.shared.selectorLoadFileQuickLook,
                                           "error": NKError(),
                                           "account": metadata.account])
                        } else {
                            guard let metadata = NCManageDatabase.shared.setMetadatasSessionInWaitDownload(metadatas: [metadata],
                                                                                                           session: NextcloudKit.shared.nkCommonInstance.sessionIdentifierDownload,
                                                                                                           selector: NCGlobal.shared.selectorLoadFileQuickLook,
                                                                                                           sceneIdentifier: sceneIdentifier) else { return }
                            NCNetworking.shared.download(metadata: metadata, withNotificationProgressTask: true)
                        }
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
                    icon: utility.loadImage(named: "paintpalette", colors: [NCBrandColor.shared.iconImageColor]),
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
        if metadata.isDeletable {
            actions.append(.deleteAction(selectedMetadatas: [metadata], indexPaths: [indexPath], metadataFolder: metadataFolder, viewController: self, order: 170))
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
