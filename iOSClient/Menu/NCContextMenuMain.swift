// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import SwiftUI
import Alamofire
import NextcloudKit
import LucidBanner

/// A context menu used in ``NCCollectionViewCommon`` and ``NCMedia``
/// See ``NCCollectionViewCommon/collectionView(_:contextMenuConfigurationForItemAt:point:)``,
/// ``NCCollectionViewCommon/openContextMenu(with:button:sender:)``, ``NCMedia/collectionView(_:contextMenuConfigurationForItemAt:point:)`` for usage details.
@MainActor
class NCContextMenuMain: NSObject {
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()

    let metadata: tableMetadata
    let viewController: UIViewController
    let controller: NCMainTabBarController?
    let sender: Any?

    internal var sceneIdentifier: String {
        controller?.sceneIdentifier ?? ""
    }

    internal var windowScene: UIWindowScene? {
       SceneManager.shared.getWindow(sceneIdentifier: self.controller?.sceneIdentifier)?.windowScene
    }

    init(metadata: tableMetadata, viewController: UIViewController, controller: NCMainTabBarController?, sender: Any?) {
        self.metadata = metadata
        self.viewController = viewController
        self.controller = controller
        self.sender = sender
    }

    func viewMenu() -> UIMenu {
        guard let capabilities = NCNetworking.shared.capabilities[metadata.account] else {
            return UIMenu()
        }

        let topMenuItems = buildTopMenuItems(metadata: metadata)

        let mainActionsMenu = buildMainActionsMenu(
            metadata: metadata,
            capabilities: capabilities
        )

        let clientIntegrationMenu = buildClientIntegrationMenuItems(
            capabilities: capabilities,
            metadata: metadata
        )

        let deleteMenu = buildDeleteMenu(metadata: metadata)

        // Assemble final menu
        let baseChildren = [
            UIMenu(title: "", options: .displayInline, children: mainActionsMenu),
            UIMenu(title: "", options: .displayInline, children: clientIntegrationMenu),
            UIMenu(title: "", options: .displayInline, children: deleteMenu)
        ]

        let finalMenu = UIMenu(title: "", children: topMenuItems + baseChildren)
        finalMenu.preferredElementSize = .medium // top menu items are shown in a short format style

        return finalMenu
    }

    // MARK: Top Menu Items

    private func buildTopMenuItems(metadata: tableMetadata, appending items: [UIMenuElement] = []) -> [UIMenuElement] {
        var topActionsMenu: [UIMenuElement] = []

        if metadata.canShare {
            topActionsMenu.append(makeShareAction())
        }

        topActionsMenu.append(makeDetailAction(metadata: metadata))

        if !metadata.lock {
            topActionsMenu.append(makeFavoriteAction(metadata: metadata))
        }

        return topActionsMenu
    }

    // MARK: Basic Actions

    private func makeDetailAction(metadata: tableMetadata) -> UIAction {
        return UIAction(
            title: NSLocalizedString("_details_", comment: ""),
            image: utility.loadImage(named: "info.circle.fill")
        ) { _ in
            NCCreate().createShare(viewController: self.viewController,
                                   controller: self.controller,
                                   metadata: metadata,
                                   page: .activity)
        }
    }

    private func makeFavoriteAction(metadata: tableMetadata) -> UIAction {
        return UIAction(
            title: metadata.favorite ?
            NSLocalizedString("_remove_favorites_", comment: "") :
                NSLocalizedString("_add_favorites_", comment: ""),
            image: utility.loadImage(
                named: metadata.favorite ? "star.slash.fill" : "star.fill",
                colors: [NCBrandColor.shared.yellowFavorite]
            )
        ) { _ in
            Task {
                await NCNetworking.shared.setStatusWaitFavorite(metadata)
            }
        }
    }

    private func makeShareAction() -> UIAction {
        return UIAction(
            title: NSLocalizedString("_share_", comment: ""),
            image: utility.loadImage(named: "square.and.arrow.up.fill")
        ) { _ in
            Task { @MainActor in
                await NCCreate().createActivityViewController(
                    selectedMetadata: [self.metadata],
                    controller: self.controller,
                    sender: self.sender
                )
            }
        }
    }

    // MARK: Main Actions Menu

    private func buildMainActionsMenu(
        metadata: tableMetadata,
        capabilities: NKCapabilities.Capabilities
    ) -> [UIMenuElement] {
        var mainActionsMenu: [UIMenuElement] = []
        // Lock/Unlock
        if NCNetworking.shared.isOnline,
           !metadata.directory,
           !capabilities.filesLockVersion.isEmpty {
            mainActionsMenu.append(
                ContextMenuActions.lockUnlock(isLocked: metadata.lock,
                                              metadata: metadata,
                                              controller: controller)
            )
        }

        // E2EE actions
        addE2EEActions(metadata: metadata, capabilities: capabilities, mainActionsMenu: &mainActionsMenu)

        // Offline
        if NCNetworking.shared.isOnline,
           metadata.canSetAsAvailableOffline {
            mainActionsMenu.append(
                ContextMenuActions.setAvailableOffline(
                    metadatas: [metadata],
                    isAnyOffline: metadata.isOffline,
                    controller: controller
                )
            )
        }

        // Save Live Photo
        if NCNetworking.shared.isOnline,
           let metadataMOV = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) {
            mainActionsMenu.append(makeSaveLivePhotoAction(metadata: metadata, metadataMOV: metadataMOV))
        }

        // Save as scan
        if NCNetworking.shared.isOnline,
           metadata.isSavebleAsImage {
            mainActionsMenu.append(makeSaveAsScanAction(metadata: metadata))
        }

        // Rename
        if metadata.isRenameable {
            mainActionsMenu.append(makeRenameAction(metadata: metadata))
        }

        // Move/Copy
        if metadata.isCopyableMovable {
            mainActionsMenu.append(
                ContextMenuActions.moveOrCopy(
                    metadatas: [metadata],
                    account: metadata.account,
                    controller: controller
                )
            )
        }

        // Modify with Quick Look
        if NCNetworking.shared.isOnline,
           metadata.isModifiableWithQuickLook {
            mainActionsMenu.append(makeModifyWithQuickLookAction(metadata: metadata))
        }

        // Color folder
        if viewController is NCFiles,
           metadata.directory {
            mainActionsMenu.append(makeColorFolderAction(metadata: metadata))
        }

        return mainActionsMenu
    }

    // MARK: E2EE Actions

    private func addE2EEActions(
        metadata: tableMetadata,
        capabilities: NKCapabilities.Capabilities,
        mainActionsMenu: inout [UIMenuElement]
    ) {
        // Set folder E2EE
        if NCNetworking.shared.isOnline,
           metadata.directory,
           metadata.size == 0,
           !metadata.e2eEncrypted,
           NCPreferences().isEndToEndEnabled(account: metadata.account),
           metadata.serverUrl == self.utilityFileSystem.getHomeServer(urlBase: metadata.urlBase, userId: metadata.userId) {
            mainActionsMenu.append(makeSetFolderE2EEAction(metadata: metadata))
        }

        // Unset folder E2EE
        if NCNetworking.shared.isOnline,
           metadata.canUnsetDirectoryAsE2EE {
            mainActionsMenu.append(makeUnsetFolderE2EEAction(metadata: metadata))
        }
    }

    private func makeSetFolderE2EEAction(metadata: tableMetadata) -> UIAction {
        return UIAction(
            title: NSLocalizedString("_e2e_set_folder_encrypted_", comment: ""),
            image: utility.loadImage(named: "lock", colors: [NCBrandColor.shared.iconImageColor])
        ) { _ in
            Task {
                let error = await NCNetworkingE2EEMarkFolder().markFolderE2ee(
                    account: metadata.account,
                    serverUrlFileName: metadata.serverUrlFileName,
                    userId: metadata.userId,
                    sceneIdentifier: self.sceneIdentifier
                )
                if error != .success {
                    await showErrorBanner(windowScene: self.windowScene, text: error.errorDescription, errorCode: error.errorCode)
                }
            }
        }
    }

    private func makeUnsetFolderE2EEAction(metadata: tableMetadata) -> UIAction {
        return UIAction(
            title: NSLocalizedString("_e2e_remove_folder_encrypted_", comment: ""),
            image: utility.loadImage(named: "lock", colors: [NCBrandColor.shared.iconImageColor])
        ) { _ in
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
                    await NCManageDatabase.shared.deleteE2eEncryptionAsync(
                        predicate: NSPredicate(
                            format: "account == %@ AND serverUrl == %@",
                            metadata.account,
                            metadata.serverUrlFileName
                        )
                    )
                    await NCManageDatabase.shared.setMetadataEncryptedAsync(ocId: metadata.ocId, encrypted: false)
                    await (self.viewController as? NCCollectionViewCommon)?.reloadDataSource()
                } else {
                    await showErrorBanner(windowScene: self.windowScene,
                                          text: results.error.errorDescription,
                                          errorCode: results.error.errorCode)
                }
            }
        }
    }

    // MARK: File Actions

    private func makeSaveLivePhotoAction(metadata: tableMetadata, metadataMOV: tableMetadata) -> UIAction {
        return UIAction(
            title: NSLocalizedString("_livephoto_save_", comment: ""),
            image: utility.loadImage(named: "livephoto", colors: [NCBrandColor.shared.iconImageColor])
        ) { _ in
            NCNetworking.shared.saveLivePhotoQueue.addOperation(NCOperationSaveLivePhoto(metadata: metadata, metadataMOV: metadataMOV, windowScene: self.windowScene))
        }
    }

    private func makeSaveAsScanAction(metadata: tableMetadata) -> UIAction {
        return UIAction(
            title: NSLocalizedString("_save_as_scan_", comment: ""),
            image: utility.loadImage(named: "doc.viewfinder", colors: [NCBrandColor.shared.iconImageColor])
        ) { _ in
            Task {
                if self.utilityFileSystem.fileProviderStorageExists(metadata) {
                    await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                        delegate.transferChange(
                            status: NCGlobal.shared.networkingStatusDownloaded,
                            account: metadata.account,
                            fileName: metadata.fileName,
                            serverUrl: metadata.serverUrl,
                            selector: NCGlobal.shared.selectorSaveAsScan,
                            ocId: metadata.ocId,
                            destination: nil,
                            error: .success
                        )
                    }
                } else {
                    if let metadata = await NCManageDatabase.shared.setMetadataSessionInWaitDownloadAsync(
                        ocId: metadata.ocId,
                        session: NCNetworking.shared.sessionDownload,
                        selector: NCGlobal.shared.selectorSaveAsScan,
                        sceneIdentifier: self.sceneIdentifier
                    ) {
                        await NCNetworking.shared.downloadFile(metadata: metadata)
                    }
                }
            }
        }
    }

    private func makeRenameAction(metadata: tableMetadata) -> UIAction {
        return UIAction(
            title: NSLocalizedString("_rename_", comment: ""),
            image: utility.loadImage(named: "text.cursor", colors: [NCBrandColor.shared.iconImageColor])
        ) { _ in
            Task { @MainActor in
                let capabilities = await NKCapabilities.shared.getCapabilities(for: metadata.account)
                let fileNameNew = await UIAlertController.renameFileAsync(
                    fileName: metadata.fileNameView,
                    isDirectory: metadata.directory,
                    capabilities: capabilities,
                    account: metadata.account,
                    presenter: self.viewController
                )

                if await NCManageDatabase.shared.getMetadataAsync(
                    predicate: NSPredicate(
                        format: "account == %@ AND serverUrl == %@ AND fileName == %@",
                        metadata.account,
                        metadata.serverUrl,
                        fileNameNew
                    )
                ) != nil {
                    await showErrorBanner(windowScene: self.windowScene,
                                          text: "_rename_already_exists_",
                                          errorCode: 0)
                    return
                }

                let error = await NCNetworking.shared.setStatusWaitRename(metadata, fileNameNew: fileNameNew, windowScene: self.windowScene)
                if error != .success {
                    await showErrorBanner(windowScene: self.windowScene, error: error)
                }
            }
        }
    }

    private func makeModifyWithQuickLookAction(metadata: tableMetadata) -> UIAction {
        return UIAction(
            title: NSLocalizedString("_modify_", comment: ""),
            image: utility.loadImage(named: "pencil.tip.crop.circle", colors: [NCBrandColor.shared.iconImageColor])
        ) { _ in
            Task {
                if self.utilityFileSystem.fileProviderStorageExists(metadata) {
                    await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                        delegate.transferChange(
                            status: NCGlobal.shared.networkingStatusDownloaded,
                            account: metadata.account,
                            fileName: metadata.fileName,
                            serverUrl: metadata.serverUrl,
                            selector: NCGlobal.shared.selectorLoadFileQuickLook,
                            ocId: metadata.ocId,
                            destination: nil,
                            error: .success
                        )
                    }
                } else {
                    if let metadata = await NCManageDatabase.shared.setMetadataSessionInWaitDownloadAsync(
                        ocId: metadata.ocId,
                        session: NCNetworking.shared.sessionDownload,
                        selector: NCGlobal.shared.selectorLoadFileQuickLook,
                        sceneIdentifier: self.sceneIdentifier
                    ) {
                        await NCNetworking.shared.downloadFile(metadata: metadata)
                    }
                }
            }
        }
    }

    private func makeColorFolderAction(metadata: tableMetadata) -> UIAction {
        return UIAction(
            title: NSLocalizedString("_change_color_", comment: ""),
            image: utility.loadImage(named: "paintpalette", colors: [NCBrandColor.shared.iconImageColor])
        ) { _ in
            if let picker = UIStoryboard(name: "NCColorPicker", bundle: nil)
                .instantiateInitialViewController() as? NCColorPicker {
                if let tableDirectory = NCManageDatabase.shared.getTableDirectory(
                    predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrlFileName)
                ), let hex = tableDirectory.colorFolder, let color = UIColor(hex: hex) {
                    picker.selectedColor = color
                }
                picker.onColorSelected = { [weak self] hexColor in
                    Task { @MainActor in
                        await NCManageDatabase.shared.updateDirectoryColorFolderAsync(hexColor, metadata: metadata, serverUrl: metadata.serverUrlFileName)
                        (self?.viewController as? NCFiles)?.collectionView.reloadData()
                    }
                }
                let popup = NCPopupViewController(
                    contentController: picker,
                    popupWidth: 200,
                    popupHeight: 320
                )
                popup.backgroundAlpha = 0
                self.viewController.present(popup, animated: true)
            }
        }
    }

    // MARK: Delete Menu

    private func buildDeleteMenu(metadata: tableMetadata) -> [UIMenuElement] {
        var deleteMenu: [UIMenuElement] = []

        /*
        let deleteConfirmLocal = makeDeleteLocalAction(metadata: metadata)
        let deleteConfirmFile = makeDeleteFileAction(metadata: metadata)

        let deleteSubMenu = UIMenu(
            title: NSLocalizedString("_delete_", comment: ""),
            image: utility.loadImage(named: "trash"),
            options: .destructive,
            children: [deleteConfirmLocal, deleteConfirmFile]
        )
        */

        deleteMenu.append(makeDeleteLocalAction(metadata: metadata))

        if metadata.isDeletable {
            deleteMenu.append(makeDeleteFileAction(metadata: metadata))
        }

        return deleteMenu
    }

    private func makeDeleteFileAction(metadata: tableMetadata) -> UIAction {
        return UIAction(
            title: NSLocalizedString(
                metadata.directory ? "_delete_folder_" : "_delete_file_",
                comment: ""
            ),
            image: utility.loadImage(named: "trash"),
            attributes: .destructive
        ) { _ in
            if self.viewController is NCCollectionViewCommon {
                Task {
                    if metadata.isDirectoryE2EE {
                        if NCNetworking.shared.isOffline {
                            await showErrorBanner(windowScene: self.windowScene,
                                                  text: "_offline_not_allowed_",
                                                  errorCode: NCGlobal.shared.errorOfflineNotAllowed)
                        } else {
                            let results = showHudBanner(windowScene: self.windowScene,
                                                        title: "_delete_in_progress_")

                            let error = await NCNetworkingE2EEDelete().delete(metadata: metadata)

                            if error == .success {
                                completeHudBannerSuccess(token: results.token, banner: results.banner)
                            } else {
                                completeHudBannerError(description: error.errorDescription, token: results.token, banner: results.banner)
                            }

                            await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                                delegate.transferReloadDataSource(serverUrl: metadata.serverUrl, requestData: false, status: nil)
                            }
                        }
                    } else {
                        let error = await NCNetworking.shared.setStatusWaitDelete(metadatas: [metadata])
                        if error != .success {
                            await showErrorBanner(windowScene: self.windowScene, error: error)
                        }
                    }
                }
            } else if let viewController = self.viewController as? NCMedia {
                Task {
                    await viewController.deleteImage(with: metadata.ocId)
                }
            }
        }
    }

    private func makeDeleteLocalAction(metadata: tableMetadata) -> UIAction {
        return UIAction(
            title: NSLocalizedString("_remove_local_file_", comment: ""),
            image: utility.loadImage(named: "document.on.trash")
        ) { _ in
            Task { @MainActor in
                var token: Int?
                var banner: LucidBanner?
                if metadata.isDirectory {
                    (banner, token) = showHudBanner(windowScene: self.windowScene, title: "_delete_in_progress_")
                }

                await NCNetworking.shared.deleteCache(metadata, progress: { progress in
                    Task {
                        if let token {
                            banner?.update(
                                payload: LucidBannerPayload.Update(progress: progress),
                                for: token
                            )
                        }
                    }

                })

                if let banner {
                    banner.dismiss()
                }
            }
        }
    }

    // MARK: Client Integration

    private func buildClientIntegrationMenuItems(capabilities: NKCapabilities.Capabilities, metadata: tableMetadata) -> [UIMenuElement] {
        var clientIntegrationMenu: [UIMenuElement] = []
        guard let apps = capabilities.clientIntegration?.apps else { return [] }

        for (_, context) in apps {
            for item in context.contextMenu {
                var shouldShowMenu = false

                if let mimetypeFilters = item.mimetypeFilters {
                    let filters = mimetypeFilters.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    shouldShowMenu = filters.contains(where: { filter in // If app has specific mimetypes, we should only show the menu if the file/folder matches one of them.
                        if filter.hasSuffix("/") {
                            // Handle wildcard MIME types like "audio/", "video/", "image/"
                            return metadata.contentType.hasPrefix(filter)
                        } else {
                            return metadata.contentType == filter
                        }
                    })
                } else {
                    shouldShowMenu = true // if app has no mimetypes, then menu should be shown for every file/folder
                }

                if shouldShowMenu {
                    let deferredElement = UIDeferredMenuElement { completion in
                        Task {
                            var iconImage = UIImage(systemName: "exclamationmark.triangle.fill")

                            if let iconUrl = item.icon {
                                let results = await NextcloudKit.shared.downloadContentAsync(serverUrl: metadata.urlBase + iconUrl, account: metadata.account)
                                if results.error == .success, let data = results.responseData?.data,
                                   let image = try? await NCSVGRenderer().renderSVGToUIImage(
                                    svgData: data,
                                    size: CGSize(width: UIScreen.main.scale * 20,
                                                 height: UIScreen.main.scale * 20),
                                    tintColor: NCBrandColor.shared.iconImageColor,
                                    trimTransparentPixels: false) {
                                    iconImage = image
                                }
                            }

                            let action = UIAction(
                                title: item.name,
                                image: iconImage
                            ) { _ in
                                Task {
                                    let results = await NextcloudKit.shared.sendRequestAsync(
                                        account: metadata.account,
                                        fileId: metadata.fileId,
                                        filePath: self.utilityFileSystem.getRelativeFilePath(metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId),
                                        url: item.url,
                                        method: item.method,
                                        params: item.params
                                    )
                                    if results.error != .success {
                                        await showErrorBanner(windowScene: self.windowScene,
                                                              text: results.error.errorDescription,
                                                              errorCode: results.error.errorCode)
                                    } else {
                                        if let tooltip = results.uiResponse?.ocs.data.tooltip {
                                            await showInfoBanner(windowScene: self.windowScene, text: tooltip)
                                        } else {
                                            let baseURL = metadata.urlBase

                                            await MainActor.run {
                                                guard let ui = results.uiResponse?.ocs.data.root, let firstRow = ui.rows.first, let child = firstRow.children.first else { return }

                                                let viewer = ClientIntegrationUIViewer(
                                                    rows: [.init(element: child.element, title: child.text, urlString: child.url)],
                                                    baseURL: baseURL
                                                )
                                                let hosting = UIHostingController(rootView: viewer)
                                                hosting.modalPresentationStyle = .pageSheet
                                                self.viewController.present(hosting, animated: true)
                                            }
                                        }
                                    }
                                }
                            }

                            await MainActor.run {
                                completion([action])
                            }
                        }
                    }

                    clientIntegrationMenu.append(deferredElement)
                }
            }
        }

        return clientIntegrationMenu
    }
}
