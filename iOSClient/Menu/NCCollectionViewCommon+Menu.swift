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
import SVGKit

extension NCCollectionViewCommon {
    func toggleMenu(metadata: tableMetadata, image: UIImage?, sender: Any?) {
        guard let metadata = database.getMetadataFromOcId(metadata.ocId),
              let sceneIdentifier = self.controller?.sceneIdentifier else {
            return
        }
        let tableLocalFile = database.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
        let fileExists = NCUtilityFileSystem().fileProviderStorageExists(metadata)
        var actions = [NCMenuAction]()
        var isOffline: Bool = false
        let applicationHandle = NCApplicationHandle()
        var iconHeader: UIImage!
        let capabilities = NCNetworking.shared.capabilities[session.account] ?? NKCapabilities.Capabilities()

        if metadata.directory, let directory = database.getTableDirectory(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
            isOffline = directory.offline
        } else if let localFile = database.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
            isOffline = localFile.offline
        }

        if let image {
            iconHeader = image
        } else {
            if metadata.directory {
                iconHeader = imageCache.getFolder(account: metadata.account)
            } else {
                iconHeader = imageCache.getImageFile()
            }
        }

        actions.append(
            NCMenuAction(
                title: metadata.fileNameView,
                boldTitle: true,
                icon: iconHeader,
                order: 0,
                sender: sender,
                action: nil
            )
        )

        actions.append(.seperator(order: 1, sender: sender))

        //
        // DETAILS
        //
        if NCNetworking.shared.isOnline,
           !(!capabilities.fileSharingApiEnabled && !capabilities.filesComments && capabilities.activity.isEmpty) {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_details_", comment: ""),
                    icon: utility.loadImage(named: "info.circle", colors: [NCBrandColor.shared.iconImageColor]),
                    order: 10,
                    sender: sender,
                    action: { _ in
                        NCDownloadAction.shared.openShare(viewController: self, metadata: metadata, page: .activity)
                    }
                )
            )
        }

        if metadata.lock {
            var lockOwnerName = metadata.lockOwnerDisplayName.isEmpty ? metadata.lockOwner : metadata.lockOwnerDisplayName
            var lockIcon = utility.loadUserImage(for: metadata.lockOwner, displayName: lockOwnerName, urlBase: metadata.urlBase)
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
                    sender: sender,
                    action: nil)
            )
        }

        //
        // VIEW IN FOLDER
        //
        if NCNetworking.shared.isOnline,
           layoutKey != NCGlobal.shared.layoutViewFiles {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_view_in_folder_", comment: ""),
                    icon: utility.loadImage(named: "questionmark.folder", colors: [NCBrandColor.shared.iconImageColor]),
                    order: 21,
                    sender: sender,
                    action: { _ in
                        NCDownloadAction.shared.openFileViewInFolder(serverUrl: metadata.serverUrl, fileNameBlink: metadata.fileName, fileNameOpen: nil, sceneIdentifier: sceneIdentifier)
                    }
                )
            )
        }

        //
        // LOCK / UNLOCK
        //
        if NCNetworking.shared.isOnline,
           !metadata.directory,
           metadata.canUnlock(as: metadata.userId),
           !capabilities.filesLockVersion.isEmpty {
            actions.append(NCMenuAction.lockUnlockFiles(shouldLock: !metadata.lock, metadatas: [metadata], order: 30, sender: sender))
        }

        //
        // SET FOLDER E2EE
        //
        if NCNetworking.shared.isOnline,
           metadata.directory,
           metadata.size == 0,
           !metadata.e2eEncrypted,
           NCPreferences().isEndToEndEnabled(account: metadata.account),
           metadata.serverUrl == NCUtilityFileSystem().getHomeServer(urlBase: metadata.urlBase, userId: metadata.userId) {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_e2e_set_folder_encrypted_", comment: ""),
                    icon: utility.loadImage(named: "lock", colors: [NCBrandColor.shared.iconImageColor]),
                    order: 30,
                    sender: sender,
                    action: { _ in
                        Task {
                            let error = await NCNetworkingE2EEMarkFolder().markFolderE2ee(account: metadata.account, serverUrlFileName: metadata.serverUrlFileName, userId: metadata.userId)
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
        if NCNetworking.shared.isOnline,
           metadata.canUnsetDirectoryAsE2EE {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_e2e_remove_folder_encrypted_", comment: ""),
                    icon: utility.loadImage(named: "lock", colors: [NCBrandColor.shared.iconImageColor]),
                    order: 30,
                    sender: sender,
                    action: { _ in
                        Task {
                            let results = await NextcloudKit.shared.markE2EEFolderAsync(fileId: metadata.fileId, delete: true, account: metadata.account) { task in
                                Task {
                                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: metadata.account,
                                                                                                                path: metadata.fileId,
                                                                                                                name: "markE2EEFolder")
                                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                                }
                            }
                            if results.error == .success {
                                await self.database.deleteE2eEncryptionAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrlFileName))
                                await self.database.setMetadataEncryptedAsync(ocId: metadata.ocId, encrypted: false)
                                await self.reloadDataSource()
                            } else {
                                NCContentPresenter().messageNotification(NSLocalizedString("_e2e_error_", comment: ""), error: results.error, delay: NCGlobal.shared.dismissAfterSecond, type: .error)
                            }
                        }
                    }
                )
            )
        }

        //
        // FAVORITE
        if !metadata.lock {
            actions.append(
                NCMenuAction(
                    title: metadata.favorite ? NSLocalizedString("_remove_favorites_", comment: "") : NSLocalizedString("_add_favorites_", comment: ""),
                    icon: utility.loadImage(named: metadata.favorite ? "star.slash" : "star", colors: [NCBrandColor.shared.yellowFavorite]),
                    order: 50,
                    sender: sender,
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
        if NCNetworking.shared.isOnline,
           metadata.canSetAsAvailableOffline {
            actions.append(.setAvailableOfflineAction(selectedMetadatas: [metadata], isAnyOffline: isOffline, viewController: self, order: 60, sender: sender, completion: {
                Task {
                    await self.reloadDataSource()
                }
            }))
        }

        //
        // SHARE
        //
        if (NCNetworking.shared.isOnline || (tableLocalFile != nil && fileExists)) && metadata.canShare {
            actions.append(.share(selectedMetadatas: [metadata], controller: self.controller, order: 80, sender: sender))
        }

        //
        // SAVE LIVE PHOTO
        //
        if NCNetworking.shared.isOnline,
           let metadataMOV = database.getMetadataLivePhoto(metadata: metadata),
           let hudView = self.tabBarController?.view {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_livephoto_save_", comment: ""),
                    icon: NCUtility().loadImage(named: "livephoto", colors: [NCBrandColor.shared.iconImageColor]),
                    order: 100,
                    sender: sender,
                    action: { _ in
                        NCNetworking.shared.saveLivePhotoQueue.addOperation(NCOperationSaveLivePhoto(metadata: metadata, metadataMOV: metadataMOV, hudView: hudView))
                    }
                )
            )
        }

        //
        // SAVE AS SCAN
        //
        if NCNetworking.shared.isOnline,
           metadata.isSavebleAsImage {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_save_as_scan_", comment: ""),
                    icon: utility.loadImage(named: "doc.viewfinder", colors: [NCBrandColor.shared.iconImageColor]),
                    order: 110,
                    sender: sender,
                    action: { _ in
                        Task {
                            if self.utilityFileSystem.fileProviderStorageExists(metadata) {
                                await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                                    let metadata = metadata.detachedCopy()
                                    metadata.sessionSelector = NCGlobal.shared.selectorSaveAsScan
                                    delegate.transferChange(status: NCGlobal.shared.networkingStatusDownloaded,
                                                            metadata: metadata,
                                                            error: .success)
                                }
                            } else {
                                if let metadata = await self.database.setMetadataSessionInWaitDownloadAsync(ocId: metadata.ocId,
                                                                                                            session: NCNetworking.shared.sessionDownload,
                                                                                                            selector: NCGlobal.shared.selectorSaveAsScan,
                                                                                                            sceneIdentifier: sceneIdentifier) {
                                    await NCNetworking.shared.downloadFile(metadata: metadata)
                                }
                            }
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
                    sender: sender,
                    action: { _ in
                        Task { @MainActor in
                            let capabilities = await NKCapabilities.shared.getCapabilities(for: metadata.account)
                            let fileNameNew = await UIAlertController.renameFileAsync(fileName: metadata.fileNameView, isDirectory: metadata.directory, capabilities: capabilities, account: metadata.account, presenter: self)

                            if await NCManageDatabase.shared.getMetadataAsync(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, fileNameNew)) != nil {
                                NCContentPresenter().showError(error: NKError(errorCode: 0, errorDescription: "_rename_already_exists_"))
                                return
                            }

                            NCNetworking.shared.renameMetadata(metadata, fileNameNew: fileNameNew)
                        }
                    }
                )
            )
        }

        //
        // COPY - MOVE
        //
        if metadata.isCopyableMovable {
            actions.append(.moveOrCopyAction(selectedMetadatas: [metadata], account: metadata.account, viewController: self, order: 130, sender: sender))
        }

        //
        // MODIFY WITH QUICK LOOK
        //
        if NCNetworking.shared.isOnline,
           metadata.isModifiableWithQuickLook {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_modify_", comment: ""),
                    icon: utility.loadImage(named: "pencil.tip.crop.circle", colors: [NCBrandColor.shared.iconImageColor]),
                    order: 150,
                    sender: sender,
                    action: { _ in
                        Task {
                            if self.utilityFileSystem.fileProviderStorageExists(metadata) {
                                await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                                    let metadata = metadata.detachedCopy()
                                    metadata.sessionSelector = NCGlobal.shared.selectorLoadFileQuickLook
                                    delegate.transferChange(status: NCGlobal.shared.networkingStatusDownloaded,
                                                            metadata: metadata,
                                                            error: .success)
                                }
                            } else {
                                if let metadata = await self.database.setMetadataSessionInWaitDownloadAsync(ocId: metadata.ocId,
                                                                                                            session: NCNetworking.shared.sessionDownload,
                                                                                                            selector: NCGlobal.shared.selectorLoadFileQuickLook,
                                                                                                            sceneIdentifier: sceneIdentifier) {
                                    await NCNetworking.shared.downloadFile(metadata: metadata)
                                }
                            }
                        }
                    }
                )
            )
        }

        //
        // COLOR FOLDER
        //
        if self is NCFiles,
           metadata.directory {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_change_color_", comment: ""),
                    icon: utility.loadImage(named: "paintpalette", colors: [NCBrandColor.shared.iconImageColor]),
                    order: 160,
                    sender: sender,
                    action: { _ in
                        if let picker = UIStoryboard(name: "NCColorPicker", bundle: nil).instantiateInitialViewController() as? NCColorPicker {
                            picker.metadata = metadata
                            picker.collectionViewCommon = self
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
            actions.append(.deleteOrUnshareAction(selectedMetadatas: [metadata], metadataFolder: metadataFolder, controller: self.controller, order: 170, sender: sender))
        }

        if let apps = capabilities.declarativeUI?.apps {
            for (appName, context) in apps {
                for item in context.contextMenu {

                    if item.mimetypeFilters == nil || (item.mimetypeFilters?.contains(metadata.contentType) == true) {
                        let iconImage: UIImage
                        if let icon = item.icon, let source = SVGKSourceURL.source(from: URL(string: icon)) {
                            iconImage = SVGKImage(source: source)?.uiImage ?? UIImage()
                        } else {
                            iconImage = utility.loadImage(named: "testtube.2", colors: [NCBrandColor.shared.presentationIconColor])
                        }

                            actions.append(
                            NCMenuAction(
                                title: item.name,
                                icon: iconImage,
                                order: Int.max,
                                sender: sender,
                                action: { _ in
                                    Task {
                                        await NextcloudKit.shared.sendRequestAsync(url: item.url,
                                                                                   method: item.method,
                                                                                   userAgent: userAgent,
                                                                                   params: item.params,
                                                                                   bodyParams: item.bodyParams)
                                    }
                                }
                            )
                        )
                    }
                }
            }
        }

//        capabilities.declarativeUI?.contextMenu.forEach { item in
//                   actions.append(
//                       NCMenuAction(
//                           title: item.title,
//                           icon: utility.loadImage(named: "testtube.2", colors: [NCBrandColor.shared.presentationIconColor]),
//                           order: Int.max,
//                           sender: sender,
//                           action: { _ in
//
//                           }
//                       )
//                   )
//               }

        applicationHandle.addCollectionViewCommonMenu(metadata: metadata, image: image, actions: &actions)

        presentMenu(with: actions, controller: controller, sender: sender)
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

