// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import SwiftUI
import Alamofire
import NextcloudKit
import SVGKit
import LucidBanner

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
    let sender: Any?

    init(metadata: tableMetadata, viewController: UIViewController, sceneIdentifier: String, image: UIImage?, sender: Any?) {
        self.metadata = metadata
        self.viewController = viewController
        self.sceneIdentifier = sceneIdentifier
        self.image = image
        self.sender = sender
    }

    func viewMenu() -> UIMenu {
        let database = NCManageDatabase.shared

        guard let metadata = database.getMetadataFromOcId(metadata.ocId),
              let capabilities = NCNetworking.shared.capabilities[metadata.account] else {
            return UIMenu()
        }

        var deleteMenu: [UIMenuElement] = []
        var mainActionsMenu: [UIMenuElement] = []
        var clientIntegrationMenu: [UIMenuElement] = []

        let localFile = database.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
        let isOffline = localFile?.offline == true

        // Build top menu items
        let detail = makeDetailAction(metadata: metadata)
        let favorite = makeFavoriteAction(metadata: metadata)
        let share = makeShareAction()

        buildMainActionsMenu(
            metadata: metadata,
            capabilities: capabilities,
            isOffline: isOffline,
            mainActionsMenu: &mainActionsMenu
        )

        buildClientIntegrationMenuItems(
            capabilities: capabilities,
            metadata: metadata,
            clientIntegrationMenu: &clientIntegrationMenu
        )

        buildDeleteMenu(metadata: metadata, deleteMenu: &deleteMenu)

        // Assemble final menu
        if self.networking.isOnline {
            let baseChildren = [
                UIMenu(title: "", options: .displayInline, children: mainActionsMenu),
                UIMenu(title: "", options: .displayInline, children: clientIntegrationMenu),
                UIMenu(title: "", options: .displayInline, children: deleteMenu)
            ]

            let finalMenu = UIMenu(title: "", children: (metadata.lock ? [detail] : [detail, share, favorite]) + baseChildren)
            finalMenu.preferredElementSize = .medium

            return finalMenu
        } else {
            return UIMenu()
        }
    }

    // MARK: Basic Actions

    private func makeDetailAction(metadata: tableMetadata) -> UIAction {
        return UIAction(
            title: NSLocalizedString("_details_", comment: ""),
            image: utility.loadImage(named: "info.circle.fill")
        ) { _ in
            NCCreate().createShare(viewController: self.viewController, metadata: metadata, page: .activity)
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
            self.networking.setStatusWaitFavorite(metadata) { error in
                if error != .success {
                    NCContentPresenter().showError(error: error)
                }
            }
        }
    }

    private func makeShareAction() -> UIAction {
        return UIAction(
            title: NSLocalizedString("_share_", comment: ""),
            image: utility.loadImage(named: "square.and.arrow.up.fill")
        ) { _ in
            Task { @MainActor in
                let controller = self.viewController.tabBarController as? NCMainTabBarController
                await NCCreate().createActivityViewController(
                    selectedMetadata: [self.metadata],
                    controller: controller,
                    sender: self.sender
                )
            }
        }
    }

    // MARK: Main Actions Menu

    private func buildMainActionsMenu(
        metadata: tableMetadata,
        capabilities: NKCapabilities.Capabilities,
        isOffline: Bool,
        mainActionsMenu: inout [UIMenuElement]
    ) {
        // Lock/Unlock
        if NCNetworking.shared.isOnline,
           !metadata.directory,
           metadata.canUnlock(as: metadata.userId),
           !capabilities.filesLockVersion.isEmpty {
            mainActionsMenu.append(
                ContextMenuActions.lockUnlock(shouldLock: !metadata.lock, metadatas: [metadata])
            )
        }

        // E2EE actions
        addE2EEActions(metadata: metadata, capabilities: capabilities, mainActionsMenu: &mainActionsMenu)

        // Offline
        if NCNetworking.shared.isOnline,
           metadata.canSetAsAvailableOffline {
            mainActionsMenu.append(
                ContextMenuActions.setAvailableOffline(
                    selectedMetadatas: [metadata],
                    isAnyOffline: isOffline,
                    viewController: viewController
                )
            )
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
                    selectedMetadatas: [metadata],
                    account: metadata.account,
                    viewController: viewController
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
           metadata.serverUrl == NCUtilityFileSystem().getHomeServer(urlBase: metadata.urlBase, userId: metadata.userId) {
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
                    userId: metadata.userId
                )
                if error != .success {
                    NCContentPresenter().showError(error: error)
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
                    await self.database.deleteE2eEncryptionAsync(
                        predicate: NSPredicate(
                            format: "account == %@ AND serverUrl == %@",
                            metadata.account,
                            metadata.serverUrlFileName
                        )
                    )
                    await self.database.setMetadataEncryptedAsync(ocId: metadata.ocId, encrypted: false)
                    await (self.viewController as? NCCollectionViewCommon)?.reloadDataSource()
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
    }

    // MARK: File Actions

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
                    if let metadata = await self.database.setMetadataSessionInWaitDownloadAsync(
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
                    NCContentPresenter().showError(
                        error: NKError(errorCode: 0, errorDescription: "_rename_already_exists_")
                    )
                    return
                }

                NCNetworking.shared.setStatusWaitRename(metadata, fileNameNew: fileNameNew)
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
                    if let metadata = await self.database.setMetadataSessionInWaitDownloadAsync(
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

                picker.metadata = metadata
                picker.collectionViewCommon = self.viewController as? NCFiles
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

    private func buildDeleteMenu(metadata: tableMetadata, deleteMenu: inout [UIMenuElement]) {
        let deleteConfirmLocal = makeDeleteLocalAction(metadata: metadata)
        let deleteConfirmFile = makeDeleteFileAction(metadata: metadata)

        let deleteSubMenu = UIMenu(
            title: NSLocalizedString("_delete_", comment: ""),
            image: utility.loadImage(named: "trash"),
            options: .destructive,
            children: [deleteConfirmLocal, deleteConfirmFile]
        )

        if metadata.directory {
            if !metadata.isDirectoryE2EE && !metadata.e2eEncrypted {
                deleteMenu.append(deleteSubMenu)
            }
        } else {
            if !metadata.lock {
                deleteMenu.append(deleteSubMenu)
            }
        }
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
            if let viewController = self.viewController as? NCCollectionViewCommon {
                Task {
                    await self.networking.setStatusWaitDelete(
                        metadatas: [metadata],
                        sceneIdentifier: self.sceneIdentifier
                    )
                    await viewController.reloadDataSource()
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
            image: utility.loadImage(named: "trash"),
            attributes: .destructive
        ) { _ in
            Task {
                let error = await self.networking.deleteCache(
                    metadata,
                    sceneIdentifier: self.sceneIdentifier
                )

                await self.networking.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferChange(
                        status: NCGlobal.shared.networkingStatusDelete,
                        account: metadata.account,
                        fileName: metadata.fileName,
                        serverUrl: metadata.serverUrl,
                        selector: metadata.sessionSelector,
                        ocId: metadata.ocId,
                        destination: nil,
                        error: error
                    )
                }
            }
        }
    }

    // MARK: Client Integration

    private func buildClientIntegrationMenuItems(capabilities: NKCapabilities.Capabilities, metadata: tableMetadata, clientIntegrationMenu: inout [UIMenuElement]) {
        guard let apps = capabilities.clientIntegration?.apps else { return }

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
                            var iconImage: UIImage
                            if let iconUrl = item.icon,
                               let url = URL(string: metadata.urlBase + iconUrl) {
                                do {
                                    let (data, _) = try await URLSession.shared.data(from: url)
                                    iconImage = SVGKImage(data: data)?.uiImage.withRenderingMode(.alwaysTemplate) ?? UIImage()
                                } catch {
                                    iconImage = self.utility.loadImage(
                                        named: "testtube.2",
                                        colors: [NCBrandColor.shared.presentationIconColor]
                                    )
                                }
                            } else {
                                iconImage = self.utility.loadImage(
                                    named: "testtube.2",
                                    colors: [NCBrandColor.shared.presentationIconColor]
                                )
                            }

                            let action = await UIAction(
                                title: item.name,
                                image: iconImage
                            ) { _ in
                                Task {
                                    let response = await NextcloudKit.shared.sendRequestAsync(account: metadata.account,
                                                                                              fileId: metadata.fileId,
                                                                                              filePath: self.utilityFileSystem.getRelativeFilePath(metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId),
                                                                                              url: item.url,
                                                                                              method: item.method,
                                                                                              params: item.params)

                                    if response.error != .success {
                                        NCContentPresenter().showError(error: response.error)
                                    } else {
                                        if let tooltip = response.uiResponse?.ocs.data.tooltip {
                                            NCContentPresenter().showCustomMessage(message: tooltip, type: .success)
                                        } else {
                                            let baseURL = metadata.urlBase

                                            await MainActor.run {
                                                guard let ui = response.uiResponse?.ocs.data.root, let firstRow = ui.rows.first, let child = firstRow.children.first else { return }

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
    }
}
