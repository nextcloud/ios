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
    func toggleMenu(controller: NCMainTabBarController?, metadata: tableMetadata, webView: Bool, imageIcon: UIImage?, indexPath: IndexPath = IndexPath()) {
        guard let metadata = self.database.getMetadataFromOcId(metadata.ocId),
              let controller else { return }
        var actions = [NCMenuAction]()
        let localFile = self.database.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
        let isOffline = localFile?.offline == true

        //
        // DETAIL
        //
        if !NCCapabilities.shared.disableSharesView(account: metadata.account) {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_details_", comment: ""),
                    icon: utility.loadImage(named: "info.circle", colors: [NCBrandColor.shared.iconImageColor]),
                    action: { _ in
                        NCActionCenter.shared.openShare(viewController: controller, metadata: metadata, page: .activity)
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
                        NCActionCenter.shared.openFileViewInFolder(serverUrl: metadata.serverUrl, fileNameBlink: metadata.fileName, fileNameOpen: nil, sceneIdentifier: controller.sceneIdentifier)
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
            actions.append(.setAvailableOfflineAction(selectedMetadatas: [metadata], isAnyOffline: isOffline, viewController: controller))
        }

        //
        // SHARE
        //
        if !webView, metadata.canShare {
            actions.append(.share(selectedMetadatas: [metadata], controller: controller))
        }

        //
        // SAVE LIVE PHOTO
        //
        if let metadataMOV = self.database.getMetadataLivePhoto(metadata: metadata),
           let hudView = controller.view {
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
                            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadedFile,
                                                                        object: nil,
                                                                        userInfo: ["ocId": metadata.ocId,
                                                                                   "ocIdTransfer": metadata.ocIdTransfer,
                                                                                   "session": metadata.session,
                                                                                   "selector": NCGlobal.shared.selectorSaveAsScan,
                                                                                   "error": NKError(),
                                                                                   "account": metadata.account],
                                                                        second: 0.5)
                        } else {
                            guard let metadata = self.database.setMetadatasSessionInWaitDownload(metadatas: [metadata],
                                                                                                 session: NCNetworking.shared.sessionDownload,
                                                                                                 selector: NCGlobal.shared.selectorSaveAsScan,
                                                                                                 sceneIdentifier: controller.sceneIdentifier) else { return }
                            NCNetworking.shared.download(metadata: metadata, withNotificationProgressTask: true)
                        }
                    }
                )
            )
        }

        //
        // DOWNLOAD - LOCAL
        //
        if !webView, metadata.session.isEmpty, !self.utilityFileSystem.fileProviderStorageExists(metadata) {
            var title = ""
            if metadata.isImage {
                title = NSLocalizedString("_try_download_full_resolution_", comment: "")
            } else if metadata.isVideo {
                title = NSLocalizedString("_download_video_", comment: "")
            } else if metadata.isAudio {
                title = NSLocalizedString("_download_audio_", comment: "")
            } else {
                title = NSLocalizedString("_download_file_", comment: "")
            }
            actions.append(
                NCMenuAction(
                    title: title,
                    icon: utility.loadImage(named: "iphone.circle", colors: [NCBrandColor.shared.iconImageColor]),
                    action: { _ in
                        guard let metadata = self.database.setMetadatasSessionInWaitDownload(metadatas: [metadata],
                                                                                             session: NCNetworking.shared.sessionDownload,
                                                                                             selector: "",
                                                                                             sceneIdentifier: controller.sceneIdentifier) else { return }
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
                    icon: utility.loadImage(named: "number.circle", colors: [NCBrandColor.shared.iconImageColor]),
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
                            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadedFile,
                                                                        object: nil,
                                                                        userInfo: ["ocId": metadata.ocId,
                                                                                   "ocIdTransfer": metadata.ocIdTransfer,
                                                                                   "session": metadata.session,
                                                                                   "selector": NCGlobal.shared.selectorLoadFileQuickLook,
                                                                                   "error": NKError(),
                                                                                   "account": metadata.account],
                                                                        second: 0.5)
                        } else {
                            guard let metadata = self.database.setMetadatasSessionInWaitDownload(metadatas: [metadata],
                                                                                                 session: NCNetworking.shared.sessionDownload,
                                                                                                 selector: NCGlobal.shared.selectorLoadFileQuickLook,
                                                                                                 sceneIdentifier: controller.sceneIdentifier) else { return }
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
            actions.append(.deleteAction(selectedMetadatas: [metadata], metadataFolder: nil, controller: controller))
        }

        controller.presentMenu(with: actions)
    }
}
