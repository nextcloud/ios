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
           if !(!capabilities.fileSharingApiEnabled && !capabilities.filesComments && capabilities.activity.isEmpty) {
               let action = UIAction(
                   title: NSLocalizedString("_details_", comment: ""),
                   image: UIImage(systemName: "info")
               ) { _ in
                   NCDownloadAction.shared.openShare(viewController: controller,
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
                   image: UIImage(systemName: "questionmark.folder")
               ) { _ in
                   NCDownloadAction.shared.openFileViewInFolder(serverUrl: metadata.serverUrl,
                                                                fileNameBlink: metadata.fileName,
                                                                fileNameOpen: nil,
                                                                sceneIdentifier: controller.sceneIdentifier)
               }
               menuElements.append(action)
           }

           //
           // FAVORITE
           //
           if !metadata.lock {
               let action = UIAction(
                   title: metadata.favorite
                   ? NSLocalizedString("_remove_favorites_", comment: "")
                   : NSLocalizedString("_add_favorites_", comment: ""),
                   image: NCUtility().loadImage(named: metadata.favorite ? "star.slash" : "star", colors: [NCBrandColor.shared.yellowFavorite])
               ) { _ in
                   NCNetworking.shared.setStatusWaitFavorite(metadata) { error in
                       if error != .success {
                           NCContentPresenter().showError(error: error)
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
           if !webView, metadata.canShare {
               menuElements.append(ContextMenuActions.share(selectedMetadatas: [metadata], controller: controller, sender: sender))
           }

           //
           // PDF EXAMPLES
           //
           if metadata.isPDF {
               menuElements.append(UIAction(
                   title: NSLocalizedString("_search_", comment: ""),
                   image: UIImage(systemName: "magnifyingglass")) { _ in
                       NotificationCenter.default.postOnMainThread(
                           name: NCGlobal.shared.notificationCenterMenuSearchTextPDF
                       )
                   })

               menuElements.append(UIAction(
                   title: NSLocalizedString("_go_to_page_", comment: ""),
                   image: UIImage(systemName: "number.circle")) { _ in
                       NotificationCenter.default.postOnMainThread(
                           name: NCGlobal.shared.notificationCenterMenuGotToPageInPDF
                       )
                   })
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
