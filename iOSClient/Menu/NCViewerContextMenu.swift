// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import FloatingPanel
import NextcloudKit

/**
 A context menu created to be used universally with the different `NCViewer`s
 */
enum NCViewerContextMenu {
    static func makeContextMenu(controller: NCMainTabBarController?, metadata: tableMetadata, webView: Bool, sender: Any?) -> UIMenu? {
        let database = NCManageDatabase.shared

           guard let metadata = database.getMetadataFromOcId(metadata.ocId),
                 let controller,
                 let capabilities = NCNetworking.shared.capabilities[metadata.account] else {
               return nil
           }

           var menuElements: [UIMenuElement] = []
           let localFile = database.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
           let isOffline = localFile?.offline == true

           //
           // DETAIL
           //
           if !(!capabilities.fileSharingApiEnabled && !capabilities.filesComments && capabilities.activity.isEmpty), !metadata.isDirectoryE2EE, !metadata.e2eEncrypted {
               let action = UIAction(
                   title: NSLocalizedString("_details_", comment: ""),
                   image: UIImage(named: "share")?.withTintColor(NCBrandColor.shared.iconImageColor)
               ) { _ in
                   NCCreate().createShare(viewController: controller,
                                          metadata: metadata,
                                          page: .activity)
               }
               menuElements.append(action)
           }

           //
           // VIEW IN FOLDER
           //
           if !webView {
               let action = UIAction(
                   title: NSLocalizedString("_view_in_folder_", comment: ""),
                   image: UIImage(systemName: "arrow.forward.square")?.withTintColor(NCBrandColor.shared.iconImageColor)
               ) { _ in
                   NCNetworking.shared.openFileViewInFolder(serverUrl: metadata.serverUrl,
                                                            fileNameBlink: metadata.fileName,
                                                            fileNameOpen: nil,
                                                            sceneIdentifier: controller.sceneIdentifier)
               }
               menuElements.append(action)
           }

           //
           // FAVORITE
           //
           if !metadata.lock, !metadata.isDirectoryE2EE, !metadata.e2eEncrypted {
               let action = UIAction(
                   title: metadata.favorite
                   ? NSLocalizedString("_remove_favorites_", comment: "")
                   : NSLocalizedString("_add_favorites_", comment: ""),
                   image: NCUtility().loadImage(named: metadata.favorite ? "star" : "star.fill", colors: [NCBrandColor.shared.yellowFavorite])
//                   image: NCUtility().loadImage(named: metadata.favorite ? "star" : "star.fill", colors: [metadata.favorite ? NCBrandColor.shared.yellowFavorite : NCBrandColor.shared.iconImageColor2])
               ) { _ in
                   NCNetworking.shared.setStatusWaitFavorite(metadata) { error in
                       if error != .success {
                           Task {
                               await showErrorBanner(controller: controller, text: error.errorDescription)
                           }
                       }
                   }
               }
               menuElements.append(action)
           }

           //
           // OFFLINE
           //
           if !webView, metadata.canSetAsAvailableOffline {
               menuElements.append(ContextMenuActions.setAvailableOffline(selectedMetadatas: [metadata], isAnyOffline: isOffline, viewController: controller))
           }

           //
           // SHARE
           //
//           if !webView, metadata.canShare {
//               menuElements.append(ContextMenuActions.share(selectedMetadatas: [metadata], controller: controller, sender: sender))
//           }

            //
            // PRINT
            //
//            if !webView, metadata.isPrintable {
//                let action = UIAction(
//                    title: NSLocalizedString("_print_", comment: ""),
//                    image: NCUtility().loadImage(named: "printer", colors: [NCBrandColor.shared.iconImageColor])
//                ) { _ in
//                    if NCUtilityFileSystem().fileProviderStorageExists(metadata) {
//                        metadata.sessionSelector = NCGlobal.shared.selectorPrint
//                        NCDownloadAction.shared.downloadedFile(metadata: metadata, error: NKError())
//                    } else {
//                        NCNetworking.shared.downloadQueue.addOperation(NCOperationDownload(metadata: metadata, selector: NCGlobal.shared.selectorPrint))
//
//                    }
//                }
//                menuElements.append(action)
//            }
        
            //
            // SAVE CAMERA ROLL
            //
            if !webView, metadata.isSavebleInCameraRoll {
                menuElements.append(ContextMenuActions.saveMediaAction(selectedMediaMetadatas: [metadata], controller: controller))
            }


            //
            // RENAME
            //
            if !webView, metadata.isRenameable, !metadata.isDirectoryE2EE {
                menuElements.append(
                    UIAction(
                        title: NSLocalizedString("_rename_", comment: ""),
                        image: NCUtility().loadImage(named: "rename", colors: [NCBrandColor.shared.iconImageColor]).withTintColor(NCBrandColor.shared.iconImageColor),
                        ) { _ in

                            if let vcRename = UIStoryboard(name: "NCRenameFile", bundle: nil).instantiateInitialViewController() as? NCRenameFile {

                                vcRename.metadata = metadata
                                vcRename.disableChangeExt = true
//                                vcRename.imagePreview = imageIcon
//                                vcRename.indexPath = indexPath

                                let popup = NCPopupViewController(contentController: vcRename, popupWidth: vcRename.width, popupHeight: vcRename.height)

                                controller.present(popup, animated: true)
                            }
                        }
                    )
            }
        
            //
            // COPY - MOVE
            //
            if !webView, metadata.isCopyableMovable {
//                menuElements.append(ContextMenuActions.moveOrCopyAction(selectedMetadatas: [metadata], account: metadata.account, controller: controller))
            }
            
            // COPY IN PASTEBOARD
            //
            if !webView, metadata.isCopyableInPasteboard, !metadata.isDirectoryE2EE {
//                menuElements.append(ContextMenuActions.copyAction(fileSelect: [metadata.ocId], controller: controller))
            }
           //
           // PDF EXAMPLES
           //
           if metadata.isPDF {
               menuElements.append(UIAction(
                   title: NSLocalizedString("_search_", comment: ""),
                   image: UIImage(named: "search")?.withTintColor(NCBrandColor.shared.iconImageColor)) { _ in
                       NotificationCenter.default.postOnMainThread(
                           name: NCGlobal.shared.notificationCenterMenuSearchTextPDF
                       )
                   })

               menuElements.append(UIAction(
                   title: NSLocalizedString("_go_to_page_", comment: ""),
                   image: UIImage(named: "go-to-page")?.image(color: NCBrandColor.shared.iconImageColor, size: 24).withTintColor(NCBrandColor.shared.iconImageColor)) { _ in
                       NotificationCenter.default.postOnMainThread(
                           name: NCGlobal.shared.notificationCenterMenuGotToPageInPDF
                       )
                   })
           }

            //
            // MODIFY WITH QUICK LOOK
            //
            if !webView, metadata.isModifiableWithQuickLook {
                menuElements.append(
                    UIAction(
                        title: NSLocalizedString("_modify_", comment: ""),
                        image: NCUtility().loadImage(named: "pencil.tip.crop.circle", colors: [NCBrandColor.shared.iconImageColor]).withTintColor(NCBrandColor.shared.iconImageColor)) { _ in
                            Task {
                                if NCUtilityFileSystem().fileProviderStorageExists(metadata) {
                                    await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                                        let metadata = metadata.detachedCopy()
                                        metadata.sessionSelector = NCGlobal.shared.selectorLoadFileQuickLook
//                                        delegate.transferChange(status: NCGlobal.shared.networkingStatusDownloaded,
//                                                                metadata: metadata,
//                                                                error: .success)
                                    }
                                } else {
                                    if let metadata = await NCManageDatabase.shared.setMetadataSessionInWaitDownloadAsync(ocId: metadata.ocId,
                                                                                                                session: NCNetworking.shared.sessionDownload,
                                                                                                                selector: NCGlobal.shared.selectorLoadFileQuickLook,
                                                                                                                          sceneIdentifier: controller.sceneIdentifier) {
                                        await NCNetworking.shared.downloadFile(metadata: metadata)
                                    }
                                }
                            }
                        }
                )
            }
           //
           // DELETE
           //
           if !webView, metadata.isDeletable {
               menuElements.append(ContextMenuActions.deleteOrUnshare(selectedMetadatas: [metadata], controller: controller))
           }

           return UIMenu(title: "", children: menuElements)
       }
}
