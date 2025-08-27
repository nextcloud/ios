//
//  ContextMenuActions.swift
//  Nextcloud
//
//  Created by Milen Pivchev on 25.08.25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import NextcloudKit

enum ContextMenuActions {
    static func deleteOrUnshare(selectedMetadatas: [tableMetadata], metadataFolder: tableMetadata? = nil, controller: NCMainTabBarController?, completion: (() -> Void)? = nil) -> UIAction {

         var titleDelete = NSLocalizedString("_delete_", comment: "")
         var message = NSLocalizedString("_want_delete_", comment: "")
         var icon = "trash"
         var destructive = false

         if selectedMetadatas.count > 1 {
             titleDelete = NSLocalizedString("_delete_selected_files_", comment: "")
             destructive = true
         } else if let metadata = selectedMetadatas.first {
             if NCManageDatabase.shared.isMetadataShareOrMounted(metadata: metadata,
                                                                 metadataFolder: metadataFolder) {
                 titleDelete = NSLocalizedString("_leave_share_", comment: "")
                 message = NSLocalizedString("_want_leave_share_", comment: "")
                 icon = "person.2.slash"
             } else if metadata.directory {
                 titleDelete = NSLocalizedString("_delete_folder_", comment: "")
                 destructive = true
             } else {
                 titleDelete = NSLocalizedString("_delete_file_", comment: "")
                 destructive = true
             }
         }

         return UIAction(
             title: titleDelete,
             image: UIImage(systemName: icon),
             attributes: destructive ? [.destructive] : []
         ) { _ in
             let alert = UIAlertController.deleteFileOrFolder(
                 titleString: titleDelete + "?",
                 message: message,
                 canDeleteServer: selectedMetadatas.allSatisfy { !$0.lock },
                 selectedMetadatas: selectedMetadatas,
                 sceneIdentifier: controller?.sceneIdentifier
             ) { _ in
                 completion?()
             }
             controller?.present(alert, animated: true)
         }
     }

     static func share(selectedMetadatas: [tableMetadata],
                       controller: NCMainTabBarController?,
                       sender: Any?,
                       completion: (() -> Void)? = nil) -> UIAction {
         UIAction(
             title: NSLocalizedString("_share_", comment: ""),
             image: UIImage(systemName: "square.and.arrow.up")
         ) { _ in
             NCDownloadAction.shared.openActivityViewController(
                 selectedMetadata: selectedMetadatas,
                 controller: controller,
                 sender: sender
             )
             completion?()
         }
     }

     static func setAvailableOffline(selectedMetadatas: [tableMetadata],
                                     isAnyOffline: Bool,
                                     viewController: UIViewController,
                                     completion: (() -> Void)? = nil) -> UIAction {
         UIAction(
             title: isAnyOffline
                 ? NSLocalizedString("_remove_available_offline_", comment: "")
                 : NSLocalizedString("_set_available_offline_", comment: ""),
             image: UIImage(systemName: "icloud.and.arrow.down")
         ) { _ in
             if !isAnyOffline, selectedMetadatas.count > 3 {
                 let alert = UIAlertController(
                     title: NSLocalizedString("_set_available_offline_", comment: ""),
                     message: NSLocalizedString("_select_offline_warning_", comment: ""),
                     preferredStyle: .alert
                 )
                 alert.addAction(UIAlertAction(title: NSLocalizedString("_continue_", comment: ""), style: .default) { _ in
                     Task {
                         for metadata in selectedMetadatas {
                             await NCDownloadAction.shared.setMetadataAvalableOffline(metadata, isOffline: isAnyOffline)
                         }
                         completion?()
                     }
                 })
                 alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel))
                 viewController.present(alert, animated: true)
             } else {
                 Task {
                     for metadata in selectedMetadatas {
                         await NCDownloadAction.shared.setMetadataAvalableOffline(metadata, isOffline: isAnyOffline)
                     }
                     completion?()
                 }
             }
         }
     }

     static func moveOrCopy(selectedMetadatas: [tableMetadata],
                            account: String,
                            viewController: UIViewController,
                            completion: (() -> Void)? = nil) -> UIAction {
         UIAction(
             title: NSLocalizedString("_move_or_copy_", comment: ""),
             image: UIImage(systemName: "rectangle.portrait.and.arrow.right")
         ) { _ in
             Task { @MainActor in
                 var fileNameError: NKError?
                 let capabilities = await NKCapabilities.shared.getCapabilities(for: account)

                 for metadata in selectedMetadatas {
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
                     await UIAlertController.warningAsync(message: message, presenter: viewController)
                 } else {
                     let controller = viewController.tabBarController as? NCMainTabBarController
                     NCDownloadAction.shared.openSelectView(items: selectedMetadatas, controller: controller)
                 }
                 completion?()
             }
         }
     }

     static func lockUnlock(shouldLock: Bool,
                            metadatas: [tableMetadata],
                            completion: (() -> Void)? = nil) -> UIAction {
         let titleKey: String
         if metadatas.count == 1 {
             titleKey = shouldLock ? "_lock_file_" : "_unlock_file_"
         } else {
             titleKey = shouldLock ? "_lock_selected_files_" : "_unlock_selected_files_"
         }

         return UIAction(
             title: NSLocalizedString(titleKey, comment: ""),
             image: UIImage(systemName: shouldLock ? "lock" : "lock.open")
         ) { _ in
             for metadata in metadatas where metadata.lock != shouldLock {
                 NCNetworking.shared.lockUnlockFile(metadata, shoulLock: shouldLock)
             }
             completion?()
         }
     }
}
