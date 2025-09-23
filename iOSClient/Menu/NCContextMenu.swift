// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import Alamofire
import NextcloudKit
import SVGKit

class NCContextMenu: NSObject {
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let database = NCManageDatabase.shared
    let global = NCGlobal.shared
    let networking = NCNetworking.shared

    let metadata: tableMetadata
    let sceneIdentifier: String
    let viewController: UIViewController
    let image: UIImage?

    init(metadata: tableMetadata, viewController: UIViewController, sceneIdentifier: String, image: UIImage?) {
        self.metadata = metadata
        self.viewController = viewController
        self.sceneIdentifier = sceneIdentifier
        self.image = image
    }

    func viewMenu() -> UIMenu {
        let database = NCManageDatabase.shared

           guard let metadata = database.getMetadataFromOcId(metadata.ocId),
                 let capabilities = NCNetworking.shared.capabilities[metadata.account] else {
               return UIMenu()
           }

           var menuElements: [UIMenuElement] = []
           let localFile = database.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
           let isOffline = localFile?.offline == true

        var downloadRequest: DownloadRequest?
        var titleDeleteConfirmFile = NSLocalizedString("_delete_file_", comment: "")
        let metadataMOV = self.database.getMetadataLivePhoto(metadata: metadata)
        let hud = NCHud(viewController.view)

        if metadata.directory { titleDeleteConfirmFile = NSLocalizedString("_delete_folder_", comment: "") }

        // MENU ITEMS

        let detail = UIAction(title: NSLocalizedString("_details_", comment: ""),
                              image: utility.loadImage(named: "info.circle")) { _ in
            NCDownloadAction.shared.openShare(viewController: self.viewController, metadata: self.metadata, page: .activity)
        }

        let favorite = UIAction(title: metadata.favorite ?
                                NSLocalizedString("_remove_favorites_", comment: "") :
                                NSLocalizedString("_add_favorites_", comment: ""),
                                image: utility.loadImage(named: self.metadata.favorite ? "star.slash" : "star", colors: [NCBrandColor.shared.yellowFavorite])) { _ in
            self.networking.favoriteMetadata(self.metadata) { error in
                if error != .success {
                    NCContentPresenter().showError(error: error)
                }
            }
        }

        let share = UIAction(title: NSLocalizedString("_share_", comment: ""),
                             image: utility.loadImage(named: "square.and.arrow.up") ) { _ in
            if self.utilityFileSystem.fileProviderStorageExists(self.metadata) {
                Task {
                    await self.networking.transferDispatcher.notifyAllDelegates { delegate in
                        let metadata = self.metadata.detachedCopy()
                        metadata.sessionSelector = self.global.selectorOpenIn
                        delegate.transferChange(status: self.global.networkingStatusDownloaded,
                                                metadata: metadata,
                                                error: .success)
                    }
                }
            } else {
                Task { @MainActor in
                    guard let metadata = await self.database.setMetadataSessionInWaitDownloadAsync(ocId: self.metadata.ocId,
                                                                                                   session: self.networking.sessionDownload,
                                                                                                   selector: self.global.selectorOpenIn,
                                                                                                   sceneIdentifier: self.sceneIdentifier) else {
                        return
                    }

                    hud.ringProgress(text: NSLocalizedString("_downloading_", comment: ""), tapToCancelDetailText: true) {
                        if let request = downloadRequest {
                            request.cancel()
                        }
                    }

                    let results = await self.networking.downloadFile(metadata: metadata) { request in
                        downloadRequest = request
                    } progressHandler: { progress in
                        hud.progress(progress.fractionCompleted)
                    }
                    if results.nkError == .success || results.afError?.isExplicitlyCancelledError ?? false {
                        hud.dismiss()
                    } else {
                        hud.error(text: results.nkError.errorDescription)
                    }
                }
            }
        }

        let viewInFolder = UIAction(title: NSLocalizedString("_view_in_folder_", comment: ""),
                                    image: utility.loadImage(named: "questionmark.folder")) { _ in
            NCDownloadAction.shared.openFileViewInFolder(serverUrl: self.metadata.serverUrl, fileNameBlink: self.metadata.fileName, fileNameOpen: nil, sceneIdentifier: self.sceneIdentifier)
        }

        let livePhotoSave = UIAction(title: NSLocalizedString("_livephoto_save_", comment: ""), image: utility.loadImage(named: "livephoto")) { _ in
            if let metadataMOV = metadataMOV {
                self.networking.saveLivePhotoQueue.addOperation(NCOperationSaveLivePhoto(metadata: self.metadata, metadataMOV: metadataMOV, hudView: self.viewController.view))
            }
        }

        let modify = UIAction(title: NSLocalizedString("_modify_", comment: ""),
                              image: utility.loadImage(named: "pencil.tip.crop.circle")) { _ in
            Task { @MainActor in
                if self.utilityFileSystem.fileProviderStorageExists(self.metadata) {
                    await self.networking.transferDispatcher.notifyAllDelegates { delegate in
                        let metadata = self.metadata.detachedCopy()
                        metadata.sessionSelector = self.global.selectorLoadFileQuickLook
                        delegate.transferChange(status: self.global.networkingStatusDownloaded,
                                                metadata: metadata,
                                                error: .success)
                    }
                } else {
                    guard let metadata = await self.database.setMetadataSessionInWaitDownloadAsync(ocId: self.metadata.ocId,
                                                                                                   session: self.networking.sessionDownload,
                                                                                                   selector: self.global.selectorLoadFileQuickLook,
                                                                                                   sceneIdentifier: self.sceneIdentifier) else {
                        return
                    }

                    hud.ringProgress(text: NSLocalizedString("_downloading_", comment: "")) {
                        if let request = downloadRequest {
                            request.cancel()
                        }
                    }

                    let results = await self.networking.downloadFile(metadata: metadata) { request in
                        downloadRequest = request
                    } progressHandler: { progress in
                        hud.progress(progress.fractionCompleted)
                    }
                    if results.nkError == .success || results.afError?.isExplicitlyCancelledError ?? false {
                        hud.dismiss()
                    } else {
                        hud.error(text: results.nkError.errorDescription)
                    }
                }
            }
        }

        let deleteConfirmFile = UIAction(title: titleDeleteConfirmFile,
                                         image: utility.loadImage(named: "trash"), attributes: .destructive) { _ in

            var alertStyle = UIAlertController.Style.actionSheet
            if UIDevice.current.userInterfaceIdiom == .pad {
                alertStyle = .alert
            }
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: alertStyle)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_delete_file_", comment: ""), style: .destructive) { _ in
                if let viewController = self.viewController as? NCCollectionViewCommon {
                    Task {
                        await self.networking.setStatusWaitDelete(metadatas: [self.metadata], sceneIdentifier: self.sceneIdentifier)
                        await viewController.reloadDataSource()
                    }
                }
                if let viewController = self.viewController as? NCMedia {
                    Task {
                        await viewController.deleteImage(with: self.metadata.ocId)
                    }
                }
            })
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel) { _ in })
            self.viewController.present(alertController, animated: true, completion: nil)
        }

        let deleteConfirmLocal = UIAction(title: NSLocalizedString("_remove_local_file_", comment: ""),
                                          image: utility.loadImage(named: "trash"), attributes: .destructive) { _ in
            Task {
                var metadatasError: [tableMetadata: NKError] = [:]
                let error = await self.networking.deleteCache(self.metadata, sceneIdentifier: self.sceneIdentifier)
                metadatasError[self.metadata.detachedCopy()] = error

                await self.networking.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferChange(status: self.global.networkingStatusDelete,
                                            metadatasError: metadatasError)
                }
            }
        }

        let deleteSubMenu = UIMenu(title: NSLocalizedString("_delete_file_", comment: ""),
                                   image: utility.loadImage(named: "trash"),
                                   options: .destructive,
                                   children: [deleteConfirmLocal, deleteConfirmFile])

        //
        // LOCK / UNLOCK
        //
        if NCNetworking.shared.isOnline,
           !metadata.directory,
           metadata.canUnlock(as: metadata.userId),
           !capabilities.filesLockVersion.isEmpty {
            menuElements.append(ContextMenuActions.lockUnlock(shouldLock: !metadata.lock, metadatas: [metadata]))
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

            let action = UIAction(
                title: NSLocalizedString("_e2e_set_folder_encrypted_", comment: ""),
                image: utility.loadImage(named: "lock", colors: [NCBrandColor.shared.iconImageColor])
            ) { _ in
                Task {
                    let error = await NCNetworkingE2EEMarkFolder().markFolderE2ee(
                        account: metadata.account,
                        serverUrlFileName: metadata.serverUrlFileName,
                        userId: metadata.userId
                    )
                    if error != .success {
                        NCContentPresenter().showError(error: error)
                    }
                }
            }

            menuElements.append(action)
        }

        //
        // UNSET FOLDER E2EE
        //
        if NCNetworking.shared.isOnline,
           metadata.canUnsetDirectoryAsE2EE {

            let action = UIAction(
                title: NSLocalizedString("_e2e_remove_folder_encrypted_", comment: ""),
                image: utility.loadImage(named: "lock", colors: [NCBrandColor.shared.iconImageColor])
            ) { [self] _ in
                Task {
                    let results = await NextcloudKit.shared.markE2EEFolderAsync(
                        fileId: metadata.fileId,
                        delete: true,
                        account: metadata.account
                    ) { task in
                        Task {
                            let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                                account: metadata.account,
                                path: metadata.fileId,
                                name: "markE2EEFolder"
                            )
                            await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                        }
                    }

                    if results.error == .success {
                        await database.deleteE2eEncryptionAsync(
                            predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrlFileName)
                        )
                        await database.setMetadataEncryptedAsync(ocId: metadata.ocId, encrypted: false)
                        await (viewController as? NCCollectionViewCommon)?.reloadDataSource()
                    } else {
                        NCContentPresenter().messageNotification(
                            NSLocalizedString("_e2e_error_", comment: ""),
                            error: results.error,
                            delay: NCGlobal.shared.dismissAfterSecond,
                            type: .error
                        )
                    }
                }
            }

            menuElements.append(action)
        }

        //
        // OFFLINE
        //
        if NCNetworking.shared.isOnline,
           metadata.canSetAsAvailableOffline {

            menuElements.append(ContextMenuActions.setAvailableOffline(selectedMetadatas: [metadata], isAnyOffline: isOffline, viewController: viewController))

        }

        //
        // SAVE AS SCAN
        //
        if NCNetworking.shared.isOnline,
           metadata.isSavebleAsImage {

            let action = UIAction(
                title: NSLocalizedString("_save_as_scan_", comment: ""),
                image: utility.loadImage(named: "doc.viewfinder", colors: [NCBrandColor.shared.iconImageColor])
            ) { [self] _ in
                Task {
                    if self.utilityFileSystem.fileProviderStorageExists(metadata) {
                        await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                            let metadataCopy = metadata.detachedCopy()
                            metadataCopy.sessionSelector = NCGlobal.shared.selectorSaveAsScan
                            delegate.transferChange(
                                status: NCGlobal.shared.networkingStatusDownloaded,
                                metadata: metadataCopy,
                                error: .success
                            )
                        }
                    } else {
                        if let metadata = await self.database.setMetadataSessionInWaitDownloadAsync(
                            ocId: metadata.ocId,
                            session: NCNetworking.shared.sessionDownload,
                            selector: NCGlobal.shared.selectorSaveAsScan,
                            sceneIdentifier: sceneIdentifier
                        ) {
                            await NCNetworking.shared.downloadFile(metadata: metadata)
                        }
                    }
                }
            }

            menuElements.append(action)
        }

        //
        // RENAME
        //
        if metadata.isRenameable {
            let action = UIAction(
                title: NSLocalizedString("_rename_", comment: ""),
                image: utility.loadImage(named: "text.cursor", colors: [NCBrandColor.shared.iconImageColor])
            ) { [self] _ in
                Task { @MainActor in
                    let capabilities = await NKCapabilities.shared.getCapabilities(for: metadata.account)
                    let fileNameNew = await UIAlertController.renameFileAsync(
                        fileName: metadata.fileNameView,
                        isDirectory: metadata.directory,
                        capabilities: capabilities,
                        account: metadata.account,
                        presenter: viewController
                    )

                    if await NCManageDatabase.shared.getMetadataAsync(
                        predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND fileName == %@", metadata.account, metadata.serverUrl, fileNameNew)
                    ) != nil {
                        NCContentPresenter().showError(
                            error: NKError(errorCode: 0, errorDescription: "_rename_already_exists_")
                        )
                        return
                    }

                    NCNetworking.shared.renameMetadata(metadata, fileNameNew: fileNameNew)
                }
            }

            menuElements.append(action)
        }

        if metadata.isCopyableMovable {
            menuElements.append(ContextMenuActions.moveOrCopy(selectedMetadatas: [metadata], account: metadata.account, viewController: viewController))
        }

        //
        // MODIFY WITH QUICK LOOK
        //
        if NCNetworking.shared.isOnline,
           metadata.isModifiableWithQuickLook {

            let action = UIAction(
                title: NSLocalizedString("_modify_", comment: ""),
                image: utility.loadImage(named: "pencil.tip.crop.circle", colors: [NCBrandColor.shared.iconImageColor])
            ) { [self] _ in
                Task {
                    if self.utilityFileSystem.fileProviderStorageExists(metadata) {
                        await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                            let metadataCopy = metadata.detachedCopy()
                            metadataCopy.sessionSelector = NCGlobal.shared.selectorLoadFileQuickLook
                            delegate.transferChange(
                                status: NCGlobal.shared.networkingStatusDownloaded,
                                metadata: metadataCopy,
                                error: .success
                            )
                        }
                    } else {
                        if let metadata = await self.database.setMetadataSessionInWaitDownloadAsync(
                            ocId: metadata.ocId,
                            session: NCNetworking.shared.sessionDownload,
                            selector: NCGlobal.shared.selectorLoadFileQuickLook,
                            sceneIdentifier: sceneIdentifier
                        ) {
                            await NCNetworking.shared.downloadFile(metadata: metadata)
                        }
                    }
                }
            }

            menuElements.append(action)
        }

        //
        // COLOR FOLDER
        //
        if viewController is NCFiles,
           metadata.directory {

            let action = UIAction(
                title: NSLocalizedString("_change_color_", comment: ""),
                image: utility.loadImage(named: "paintpalette", colors: [NCBrandColor.shared.iconImageColor])
            ) { [self] _ in
                if let picker = UIStoryboard(name: "NCColorPicker", bundle: nil)
                    .instantiateInitialViewController() as? NCColorPicker {

                    picker.metadata = metadata
                    picker.collectionViewCommon = viewController as? NCFiles
                    let popup = NCPopupViewController(
                        contentController: picker,
                        popupWidth: 200,
                        popupHeight: 320
                    )
                    popup.backgroundAlpha = 0
                    self.viewController.present(popup, animated: true)
                }
            }

            menuElements.append(action)
        }

        if let apps = capabilities.declarativeUI?.apps {
            for (appName, context) in apps {
                for item in context.contextMenu {
                    if item.mimetypeFilters == nil || (item.mimetypeFilters?.contains(metadata.contentType) == true) {

                        let deferredElement = UIDeferredMenuElement { [self] completion in
                            Task {
                                var iconImage: UIImage
                                if let iconUrl = item.icon,
                                   let url = URL(string: metadata.urlBase + iconUrl) {
                                    do {
                                        let (data, _) = try await URLSession.shared.data(from: url)
                                        iconImage = SVGKImage(data: data)?.uiImage ?? UIImage()
                                    } catch {
                                        iconImage = utility.loadImage(
                                            named: "testtube.2",
                                            colors: [NCBrandColor.shared.presentationIconColor]
                                        )
                                    }
                                } else {
                                    iconImage = utility.loadImage(
                                        named: "testtube.2",
                                        colors: [NCBrandColor.shared.presentationIconColor]
                                    )
                                }

                                // Create the action once the icon is ready
                                let action = await UIAction(
                                    title: item.name,
                                    image: iconImage
                                ) { _ in
                                    Task {
                                        await NextcloudKit.shared.sendRequestAsync(
                                            url: item.url,
                                            method: item.method,
                                            userAgent: userAgent,
                                            params: item.params,
                                            bodyParams: item.bodyParams
                                        )
                                    }
                                }

                                await MainActor.run {
                                    completion([action])
                                }
                            }
                        }

                        menuElements.append(deferredElement)
                    }
                }
            }
        }

        // ------ MENU -----

        var menu: [UIMenuElement] = []

        if self.networking.isOnline {
            if metadata.directory {
                if metadata.isDirectoryE2EE || metadata.e2eEncrypted {
                    menu.append(favorite)
                } else {
                    menu.append(favorite)
                    menu.append(deleteConfirmFile)
                }
                return UIMenu(title: "", children: [detail, UIMenu(title: "", options: .displayInline, children: menu + menuElements)])
            } else {
                if metadata.lock {
                    menu.append(favorite)
                    menu.append(share)

                    if self.database.getMetadataLivePhoto(metadata: metadata) != nil {
                        menu.append(livePhotoSave)
                    }
                } else {
                    menu.append(favorite)
                    menu.append(share)

                    if self.database.getMetadataLivePhoto(metadata: metadata) != nil {
                        menu.append(livePhotoSave)
                    }

                    if viewController is NCMedia {
                        menu.append(viewInFolder)
                    }

                    // MODIFY WITH QUICK LOOK
                    if metadata.isModifiableWithQuickLook {
                        menu.append(modify)
                    }

                    if viewController is NCMedia {
                        menu.append(deleteConfirmFile)
                    } else {
                        menu.append(deleteSubMenu)
                    }
                }

                return UIMenu(title: "", children: [detail, UIMenu(title: "", options: .displayInline, children: menu + menuElements)])
            }
        } else {
            return UIMenu()
        }
    }
}
