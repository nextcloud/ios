// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit

/// A collection of default UI actions used throughout the app
enum ContextMenuActions {
    static func delete(metadatas: [tableMetadata],
                       controller: NCMainTabBarController?,
                       completion: (() -> Void)? = nil) -> UIAction {
         return UIAction(
             title: NSLocalizedString("_delete_", comment: ""),
             image: UIImage(systemName: "trash"),
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

     static func share(metadatas: [tableMetadata],
                       controller: NCMainTabBarController?,
                       sender: Any?,
                       completion: (() -> Void)? = nil) -> UIAction {
         UIAction(
             title: NSLocalizedString("_share_", comment: ""),
             image: UIImage(systemName: "square.and.arrow.up")
         ) { _ in
             Task {
                 await NCCreate().createActivityViewController(
                    selectedMetadata: metadatas,
                    controller: controller,
                    sender: sender
                 )
                 completion?()
             }
         }
     }

     static func setAvailableOffline(metadatas: [tableMetadata],
                                     isAnyOffline: Bool,
                                     controller: NCMainTabBarController?,
                                     completion: (() -> Void)? = nil) -> UIAction {
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

     static func moveOrCopy(metadatas: [tableMetadata],
                            account: String,
                            controller: NCMainTabBarController?,
                            completion: (() -> Void)? = nil) -> UIAction {
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
                        let checkError = FileNameValidator.checkFileName(metadata.fileNameView,
                                                                         account: controller.account,
                                                                         capabilities: capabilities) {
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

    static func lockUnlock(isLocked: Bool,
                           metadata: tableMetadata,
                           controller: NCMainTabBarController?,
                           completion: (() -> Void)? = nil) -> UIAction {
        let titleKey: String
        var subtitleKey: String = ""
        let image: UIImage?
        if !metadata.canUnlock(as: metadata.userId), isLocked {
            titleKey = String(format: NSLocalizedString("_locked_by_", comment: ""), metadata.lockOwnerDisplayName)
            image = UIImage(systemName: "lock")
        } else {
            titleKey = isLocked ? "_unlock_file_" : "_lock_file_"
            image = UIImage(systemName: isLocked ? "lock.open" : "lock")
            subtitleKey = !metadata.lockOwnerDisplayName.isEmpty ? String(format: NSLocalizedString("_locked_by_", comment: ""), metadata.lockOwnerDisplayName) : ""
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
