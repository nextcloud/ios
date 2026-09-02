// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

/// A collection of default UI actions used throughout the app.
enum NCContextMenuActions {
    static func inlineMenu(
        children: [UIMenuElement],
        preferredElementSize: UIMenu.ElementSize? = nil
    ) -> UIMenu? {
        guard !children.isEmpty else { return nil }

        let menu = UIMenu(title: "", options: .displayInline, children: children)
        if let preferredElementSize {
            menu.preferredElementSize = preferredElementSize
        }
        return menu
    }

    static func detail(
        metadata: tableMetadata,
        controller: NCMainTabBarController?,
        presentViewController: UIViewController?
    ) -> UIAction {
        UIAction(
            title: NSLocalizedString("_details_", comment: ""),
            image: NCUtility().loadImage(named: "info.circle.fill")
        ) { _ in
            NCCreate().createShare(
                controller: controller,
                presentViewController: presentViewController,
                metadata: metadata,
                page: .activity
            )
        }
    }

    static func favorite(
        metadata: tableMetadata,
        completion: (() -> Void)? = nil
    ) -> UIAction {
        UIAction(
            title: metadata.favorite
                ? NSLocalizedString("_remove_favorites_", comment: "")
                : NSLocalizedString("_add_favorites_", comment: ""),
            image: NCUtility().loadImage(
                named: metadata.favorite ? "star.slash.fill" : "star.fill",
                colors: [NCBrandColor.shared.yellowFavorite]
            )
        ) { _ in
            Task {
                await NCNetworking.shared.setStatusWaitFavorite(metadata)
                completion?()
            }
        }
    }

    static func share(
        metadatas: [tableMetadata],
        controller: NCMainTabBarController?,
        presentViewController: UIViewController?,
        sender: Any?,
        completion: (() -> Void)? = nil
    ) -> UIAction {
        UIAction(
            title: NSLocalizedString("_share_", comment: ""),
            image: NCUtility().loadImage(named: "square.and.arrow.up.fill")
        ) { _ in
            Task { @MainActor in
                await NCCreate().createActivityViewController(
                    selectedMetadata: metadatas,
                    controller: controller,
                    presentViewController: presentViewController,
                    sender: sender
                )
                completion?()
            }
        }
    }

    static func saveLivePhoto(
        metadata: tableMetadata,
        metadataMOV: tableMetadata,
        windowScene: UIWindowScene?
    ) -> UIAction {
        UIAction(
            title: NSLocalizedString("_livephoto_save_", comment: ""),
            image: NCUtility().loadImage(named: "livephoto", colors: [NCBrandColor.shared.iconImageColor])
        ) { _ in
            NCSaveLivePhoto(metadata: metadata, metadataMOV: metadataMOV, windowScene: windowScene).start()
        }
    }

    static func delete(
        metadatas: [tableMetadata],
        controller: NCMainTabBarController?,
        completion: (() -> Void)? = nil
    ) -> UIAction {
        UIAction(
            title: NSLocalizedString("_delete_", comment: ""),
            image: NCUtility().loadImage(named: "trash"),
            attributes: [.destructive]
        ) { _ in
            let alert = UIAlertController.alertDeleteFileOrFolder(
                titleString: NSLocalizedString("_delete_", comment: "") + "?",
                message: NSLocalizedString("_want_delete_", comment: ""),
                canDeleteServer: true,
                metadatas: metadatas
            ) { _ in
                completion?()
            }
            controller?.present(alert, animated: true)
        }
    }

    static func setAvailableOffline(
        metadatas: [tableMetadata],
        isAnyOffline: Bool,
        controller: NCMainTabBarController?,
        completion: (() -> Void)? = nil
    ) -> UIAction {
        UIAction(
            title: isAnyOffline
                ? NSLocalizedString("_remove_available_offline_", comment: "")
                : NSLocalizedString("_set_available_offline_", comment: ""),
            image: UIImage(systemName: "icloud.and.arrow.down")
        ) { _ in
            if !isAnyOffline, metadatas.count > 3 {
                let alert = UIAlertController(
                    title: NSLocalizedString("_set_available_offline_", comment: ""),
                    message: NSLocalizedString("_select_offline_warning_", comment: ""),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: NSLocalizedString("_continue_", comment: ""), style: .default) { _ in
                    Task {
                        for metadata in metadatas {
                            await NCNetworking.shared.setMetadataAvalableOffline(metadata, isOffline: isAnyOffline)
                        }
                        completion?()
                    }
                })
                alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel))
                controller?.present(alert, animated: true)
            } else {
                Task {
                    for metadata in metadatas {
                        await NCNetworking.shared.setMetadataAvalableOffline(metadata, isOffline: isAnyOffline)
                    }
                    completion?()
                }
            }
        }
    }

    static func saveAsScan(
        metadata: tableMetadata,
        sceneIdentifier: String?
    ) -> UIAction {
        UIAction(
            title: NSLocalizedString("_save_as_scan_", comment: ""),
            image: NCUtility().loadImage(named: "doc.viewfinder", colors: [NCBrandColor.shared.iconImageColor])
        ) { _ in
            Task {
                if NCUtilityFileSystem().fileProviderStorageExists(metadata) {
                    await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                        delegate.transferChange(
                            networkingStatus: NCGlobal.shared.networkingStatusDownloaded,
                            account: metadata.account,
                            fileName: metadata.fileName,
                            serverUrl: metadata.serverUrl,
                            selector: NCGlobal.shared.selectorSaveAsScan,
                            ocId: metadata.ocId,
                            destination: nil,
                            error: .success
                        )
                    }
                } else if let metadata = await NCManageDatabase.shared.setMetadataSessionInWaitDownloadAsync(
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

    static func rename(
        metadata: tableMetadata,
        presenter: UIViewController,
        windowScene: UIWindowScene?
    ) -> UIAction {
        UIAction(
            title: NSLocalizedString("_rename_", comment: ""),
            image: NCUtility().loadImage(named: "text.cursor", colors: [NCBrandColor.shared.iconImageColor])
        ) { _ in
            Task { @MainActor in
                let capabilities = await NKCapabilities.shared.getCapabilities(for: metadata.account)
                let fileNameNew = await UIAlertController.renameFileAsync(
                    fileName: metadata.fileNameView,
                    isDirectory: metadata.directory,
                    capabilities: capabilities,
                    account: metadata.account,
                    presenter: presenter
                )

                if await NCManageDatabase.shared.getMetadataAsync(
                    predicate: NSPredicate(
                        format: "account == %@ AND serverUrl == %@ AND fileName == %@",
                        metadata.account,
                        metadata.serverUrl,
                        fileNameNew
                    )
                ) != nil {
                    await showErrorBanner(
                        windowScene: windowScene,
                        text: "_rename_already_exists_",
                        errorCode: 0
                    )
                    return
                }

                let error = await NCNetworking.shared.setStatusWaitRename(
                    metadata,
                    fileNameNew: fileNameNew,
                    windowScene: windowScene
                )
                if error != .success {
                    await showErrorBanner(windowScene: windowScene, error: error)
                }
            }
        }
    }

    static func moveOrCopy(
        metadatas: [tableMetadata],
        account: String,
        controller: NCMainTabBarController?,
        completion: (() -> Void)? = nil
    ) -> UIAction {
        UIAction(
            title: NSLocalizedString("_move_or_copy_", comment: ""),
            image: UIImage(systemName: "rectangle.portrait.and.arrow.right")
        ) { _ in
            Task { @MainActor in
                guard let controller else {
                    completion?()
                    return
                }

                var fileNameError: NKError?
                let capabilities = await NKCapabilities.shared.getCapabilities(for: account)

                for metadata in metadatas {
                    if let sceneIdentifier = metadata.sceneIdentifier,
                       let controller = SceneManager.shared.getController(sceneIdentifier: sceneIdentifier),
                       let checkError = FileNameValidator.checkFileName(
                        metadata.fileNameView,
                        account: controller.account,
                        capabilities: capabilities
                       ) {
                        fileNameError = checkError
                        break
                    }
                }

                if let fileNameError {
                    let message = "\(fileNameError.errorDescription) \(NSLocalizedString("_please_rename_file_", comment: ""))"
                    await UIAlertController.warningAsync(message: message, presenter: controller)
                } else {
                    NCSelectOpen.shared.openView(items: metadatas, controller: controller)
                }
                completion?()
            }
        }
    }

    static func lockUnlock(
        isLocked: Bool,
        metadata: tableMetadata,
        controller: NCMainTabBarController?,
        completion: (() -> Void)? = nil
    ) -> UIAction {
        let titleKey: String
        var subtitleKey = ""
        let image: UIImage?

        if !metadata.canUnlock(as: metadata.userId), isLocked {
            titleKey = String(format: NSLocalizedString("_locked_by_", comment: ""), metadata.lockOwnerDisplayName)
            image = UIImage(systemName: "lock")
        } else {
            titleKey = isLocked ? "_unlock_file_" : "_lock_file_"
            image = UIImage(systemName: isLocked ? "lock.open" : "lock")
            subtitleKey = !metadata.lockOwnerDisplayName.isEmpty
                ? String(format: NSLocalizedString("_locked_by_", comment: ""), metadata.lockOwnerDisplayName)
                : ""
        }

        return UIAction(
            title: NSLocalizedString(titleKey, comment: ""),
            subtitle: subtitleKey,
            image: image,
            attributes: metadata.canUnlock(as: metadata.userId) ? [] : [.disabled]
        ) { _ in
            Task {
                let error = await NCNetworking.shared.lockUnlockFile(metadata, shouldLock: !isLocked)
                if error != .success {
                    let windowScene = await SceneManager.shared.getWindowScene(controller: controller)
                    await showErrorBanner(windowScene: windowScene, error: error)
                }
                completion?()
            }
        }
    }
}
