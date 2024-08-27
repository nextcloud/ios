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

extension NCViewer {

    func toggleMenu(viewController: UIViewController, metadata: tableMetadata, webView: Bool, imageIcon: UIImage?, indexPath: IndexPath = IndexPath()) {
        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(metadata.ocId),
              let sceneIdentifier = (viewController.tabBarController as? NCMainTabBarController)?.sceneIdentifier else { return }
        var actions = [NCMenuAction]()
        let localFile = NCManageDatabase.shared.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
        let isOffline = localFile?.offline == true

        //
        // DETAIL
        //
        if !NCGlobal.shared.disableSharesView {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_details_", comment: ""),
                    icon: utility.loadImage(named: "info.circle", colors: [NCBrandColor.shared.iconImageColor]),
                    action: { _ in
                        NCActionCenter.shared.openShare(viewController: viewController, metadata: metadata, page: .activity)
                    }
                )
            )
        }

        //
        // VIEW IN FOLDER
        //
        if !webView {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_view_in_folder_", comment: ""),
                    icon: utility.loadImage(named: "questionmark.folder", colors: [NCBrandColor.shared.iconImageColor]),
                    action: { _ in
                       NCActionCenter.shared.openFileViewInFolder(serverUrl: metadata.serverUrl, fileNameBlink: metadata.fileName, fileNameOpen: nil, sceneIdentifier: sceneIdentifier)
                    }
                )
            )
        }

        //
        // FAVORITE
        // Workaround: PROPPATCH doesn't work
        // https://github.com/nextcloud/files_lock/issues/68
        if !metadata.lock {
            actions.append(
                NCMenuAction(
                    title: metadata.favorite ? NSLocalizedString("_remove_favorites_", comment: "") : NSLocalizedString("_add_favorites_", comment: ""),
                    icon: utility.loadImage(named: metadata.favorite ? "star.slash" : "star", colors: [NCBrandColor.shared.yellowFavorite]),
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
        if !webView, metadata.canSetAsAvailableOffline {
            actions.append(.setAvailableOfflineAction(selectedMetadatas: [metadata], isAnyOffline: isOffline, viewController: viewController))
        }

        //
        // SHARE
        //
        if !webView, metadata.canShare {
            actions.append(.share(selectedMetadatas: [metadata], viewController: viewController))
        }

        //
        // SAVE LIVE PHOTO
        //
        if let metadataMOV = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata),
           let hudView = viewController.tabBarController?.view {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_livephoto_save_", comment: ""),
                    icon: NCUtility().loadImage(named: "livephoto", colors: [NCBrandColor.shared.iconImageColor]),
                    action: { _ in
                        NCNetworking.shared.saveLivePhotoQueue.addOperation(NCOperationSaveLivePhoto(metadata: metadata, metadataMOV: metadataMOV, hudView: hudView))
                    }
                )
            )
        }

        //
        // SAVE AS SCAN
        //
        if !webView, metadata.isSavebleAsImage {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_save_as_scan_", comment: ""),
                    icon: utility.loadImage(named: "doc.viewfinder", colors: [NCBrandColor.shared.iconImageColor]),
                    action: { _ in
                        if self.utilityFileSystem.fileProviderStorageExists(metadata) {
                            NotificationCenter.default.post(
                                name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile),
                                object: nil,
                                userInfo: ["ocId": metadata.ocId,
                                           "selector": NCGlobal.shared.selectorSaveAsScan,
                                           "error": NKError(),
                                           "account": metadata.account])
                        } else {
                            guard let metadata = NCManageDatabase.shared.setMetadatasSessionInWaitDownload(metadatas: [metadata],
                                                                                                           session: NextcloudKit.shared.nkCommonInstance.sessionIdentifierDownload,
                                                                                                           selector: NCGlobal.shared.selectorSaveAsScan,
                                                                                                           sceneIdentifier: sceneIdentifier) else { return }
                            NCNetworking.shared.download(metadata: metadata, withNotificationProgressTask: true)
                        }
                    }
                )
            )
        }

        //
        // RENAME
        //
        if !webView, metadata.isRenameable {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_rename_", comment: ""),
                    icon: utility.loadImage(named: "text.cursor", colors: [NCBrandColor.shared.iconImageColor]),
                    action: { _ in
                        viewController.present(UIAlertController.renameFile(metadata: metadata, indexPath: indexPath), animated: true)
                    }
                )
            )
        }

        //
        // COPY - MOVE
        //
        if !webView, metadata.isCopyableMovable {
            actions.append(.moveOrCopyAction(selectedMetadatas: [metadata], viewController: viewController, indexPath: []))
        }

        //
        // DOWNLOAD FULL RESOLUTION
        //
        if !webView, metadata.session.isEmpty, !self.utilityFileSystem.fileProviderStorageExists(metadata) {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_try_download_full_resolution_", comment: ""),
                    icon: utility.loadImage(named: "photo", colors: [NCBrandColor.shared.iconImageColor]),
                    action: { _ in
                        guard let metadata = NCManageDatabase.shared.setMetadatasSessionInWaitDownload(metadatas: [metadata],
                                                                                                       session: NextcloudKit.shared.nkCommonInstance.sessionIdentifierDownload,
                                                                                                       selector: "",
                                                                                                       sceneIdentifier: sceneIdentifier) else { return }
                        NCNetworking.shared.download(metadata: metadata, withNotificationProgressTask: true)
                    }
                )
            )
        }

        //
        // PDF
        //
        if metadata.isPDF {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_search_", comment: ""),
                    icon: utility.loadImage(named: "magnifyingglass", colors: [NCBrandColor.shared.iconImageColor]),
                    action: { _ in
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterMenuSearchTextPDF)
                    }
                )
            )

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_go_to_page_", comment: ""),
                    icon: utility.loadImage(named: "book.pages", colors: [NCBrandColor.shared.iconImageColor]),
                    action: { _ in
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterMenuGotToPageInPDF)
                    }
                )
            )
        }

        //
        // MODIFY WITH QUICK LOOK
        //
        if !webView, metadata.isModifiableWithQuickLook {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_modify_", comment: ""),
                    icon: utility.loadImage(named: "pencil.tip.crop.circle", colors: [NCBrandColor.shared.iconImageColor]),
                    action: { _ in
                        if self.utilityFileSystem.fileProviderStorageExists(metadata) {
                            NotificationCenter.default.post(
                                name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile),
                                object: nil,
                                userInfo: ["ocId": metadata.ocId,
                                           "selector": NCGlobal.shared.selectorLoadFileQuickLook,
                                           "error": NKError(),
                                           "account": metadata.account])
                        } else {
                            guard let metadata = NCManageDatabase.shared.setMetadatasSessionInWaitDownload(metadatas: [metadata],
                                                                                                           session: NextcloudKit.shared.nkCommonInstance.sessionIdentifierDownload,
                                                                                                           selector: NCGlobal.shared.selectorLoadFileQuickLook,
                                                                                                           sceneIdentifier: sceneIdentifier) else { return }
                            NCNetworking.shared.download(metadata: metadata, withNotificationProgressTask: true)
                        }
                    }
                )
            )
        }

        //
        // DELETE
        //
        if !webView, metadata.isDeletable {
            actions.append(.deleteAction(selectedMetadatas: [metadata], indexPaths: [], metadataFolder: nil, viewController: viewController))
        }

        viewController.presentMenu(with: actions)
    }
}
