//
//  NCViewer.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 07/02/2020.
//  Copyright © 2020 Marino Faggiana All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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

class NCViewerContextMenu {
    let database = NCManageDatabase.shared
    weak var delegate: ContextMenuDelegate?

    func makeContextMenu(controller: NCMainTabBarController?, metadata: tableMetadata, webView: Bool, sender: Any?) -> UIMenu? {

           guard let metadata = self.database.getMetadataFromOcId(metadata.ocId),
                 let controller,
                 let capabilities = NCNetworking.shared.capabilities[metadata.account] else {
               return nil
           }

           var menuElements: [UIMenuElement] = []
           let localFile = self.database.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
           let isOffline = localFile?.offline == true

           //
           // DETAIL
           //
           if !(!capabilities.fileSharingApiEnabled && !capabilities.filesComments && capabilities.activity.isEmpty) {
               let action = UIAction(
                   title: NSLocalizedString("_details_", comment: ""),
                   image: UIImage(systemName: "info.circle")
               ) { _ in
                   NCDownloadAction.shared.openShare(viewController: controller,
                                                     metadata: metadata,
                                                     page: .activity)
                   self.delegate?.onContextMenuItemSelected()
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

                   self.delegate?.onContextMenuItemSelected()
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
                   image: UIImage(systemName: metadata.favorite ? "star.slash" : "star")
               ) { _ in
                   NCNetworking.shared.favoriteMetadata(metadata) { error in
                       if error != .success {
                           NCContentPresenter().showError(error: error)
                       }
                   }

                   self.delegate?.onContextMenuItemSelected()
               }
               menuElements.append(action)
           }

           //
           // OFFLINE
           //
           if !webView, metadata.canSetAsAvailableOffline {
               menuElements.append(ContextMenuActions.setAvailableOffline(selectedMetadatas: [metadata], isAnyOffline: isOffline, viewController: controller) {
                   self.delegate?.onContextMenuItemSelected()
               })
           }

           //
           // SHARE
           //
           if !webView, metadata.canShare {
               menuElements.append(ContextMenuActions.share(selectedMetadatas: [metadata], controller: controller, sender: sender) {
                   self.delegate?.onContextMenuItemSelected()
               })
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

                       self.delegate?.onContextMenuItemSelected()
                   })

               menuElements.append(UIAction(
                   title: NSLocalizedString("_go_to_page_", comment: ""),
                   image: UIImage(systemName: "number.circle")) { _ in
                       NotificationCenter.default.postOnMainThread(
                           name: NCGlobal.shared.notificationCenterMenuGotToPageInPDF
                       )

                       self.delegate?.onContextMenuItemSelected()
                   })
           }

           //
           // DELETE
           //
           if !webView, metadata.isDeletable {
               menuElements.append(ContextMenuActions.deleteOrUnshare(selectedMetadatas: [metadata], controller: controller) {
                   self.delegate?.onContextMenuItemSelected()
               })
           }

           return UIMenu(title: "", children: menuElements)
       }
}

protocol ContextMenuDelegate: AnyObject {
    func onContextMenuItemSelected()
}
