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

    func toggleMenu(viewController: UIViewController, metadata: tableMetadata, webView: Bool, imageIcon: UIImage?) {

        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(metadata.ocId) else { return }
        
        var actions = [NCMenuAction]()
        var titleFavorite = NSLocalizedString("_add_favorites_", comment: "")
        if metadata.favorite { titleFavorite = NSLocalizedString("_remove_favorites_", comment: "") }
        let localFile = NCManageDatabase.shared.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))
        let isOffline = localFile?.offline == true

        //
        // DETAIL
        //
        if !appDelegate.disableSharesView {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_details_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "info"),
                    action: { _ in
                        NCActionCenter.shared.openShare(viewController: viewController, metadata: metadata, indexPage: .activity)
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
                    icon: NCUtility.shared.loadImage(named: "questionmark.folder"),
                    action: { menuAction in
                        NCActionCenter.shared.openFileViewInFolder(serverUrl: metadata.serverUrl, fileNameBlink: metadata.fileName, fileNameOpen: nil)
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
                    title: titleFavorite,
                    icon: NCUtility.shared.loadImage(named: "star.fill", color: NCBrandColor.shared.yellowFavorite),
                    action: { _ in
                        NCNetworking.shared.favoriteMetadata(metadata) { error in
                            if error != .success {
                                NCContentPresenter.shared.showError(error: error)
                            }
                        }
                    }
                )
            )
        }

        //
        // OFFLINE
        //
        if !webView, metadata.isSettableOnOffline {
            actions.append(.setAvailableOfflineAction(selectedMetadatas: [metadata], isAnyOffline: isOffline, viewController: viewController))
        }

        //
        // OPEN IN
        //
        if !webView, metadata.canOpenIn {
            actions.append(.openInAction(selectedMetadatas: [metadata], viewController: viewController))
        }

        //
        // PRINT
        //
        if !webView, metadata.isPrintable {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_print_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "printer"),
                    action: { _ in
                        if CCUtility.fileProviderStorageExists(metadata) {
                            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadedFile, userInfo: ["ocId": metadata.ocId, "selector": NCGlobal.shared.selectorPrint, "error": NKError(), "account": metadata.account])
                        } else {
                            NCNetworking.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorPrint) { _, _ in }
                        }
                    }
                )
            )
        }
        
        //
        // CONVERSION VIDEO TO MPEG4 (MFFF Lib)
        //
#if MFFFLIB
        if metadata.classFile == NKCommon.TypeClassFile.video.rawValue {
            
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_video_processing_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "film"),
                    action: { menuAction in
                        if let ncplayer = (viewController as? NCViewerMediaPage)?.currentViewController.ncplayer {
                            ncplayer.convertVideo(withAlert: false)
                        }
                    }
                )
            )
        }
#endif
        
        //
        // SAVE CAMERA ROLL
        //
        if !webView, metadata.isSavebleInCameraRoll {
            actions.append(.saveMediaAction(selectedMediaMetadatas: [metadata]))
        }

        //
        // SAVE AS SCAN
        //
        if !webView, metadata.isSavebleAsImage {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_save_as_scan_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "viewfinder.circle"),
                    action: { _ in
                        if CCUtility.fileProviderStorageExists(metadata) {
                            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadedFile, userInfo: ["ocId": metadata.ocId, "selector": NCGlobal.shared.selectorSaveAsScan, "error": NKError(), "account": metadata.account])
                        } else {
                            NCNetworking.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorSaveAsScan) { _, _ in }
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
                    icon: NCUtility.shared.loadImage(named: "pencil"),
                    action: { _ in

                        if let vcRename = UIStoryboard(name: "NCRenameFile", bundle: nil).instantiateInitialViewController() as? NCRenameFile {

                            vcRename.metadata = metadata
                            vcRename.disableChangeExt = true
                            vcRename.imagePreview = imageIcon

                            let popup = NCPopupViewController(contentController: vcRename, popupWidth: vcRename.width, popupHeight: vcRename.height)

                            viewController.present(popup, animated: true)
                        }
                    }
                )
            )
        }

        //
        // COPY - MOVE
        //
        if !webView, metadata.isCopyableMovable {
            actions.append(.moveOrCopyAction(selectedMetadatas: [metadata]))
        }

        //
        // COPY IN PASTEBOARD
        //
        if !webView, metadata.isCopyableInPasteboard {
            actions.append(.copyAction(selectOcId: [metadata.ocId], hudView: viewController.view))
        }

        //
        // DOWNLOAD IMAGE MAX RESOLUTION
        //
        if !webView, metadata.session.isEmpty, metadata.classFile == NKCommon.TypeClassFile.image.rawValue, !CCUtility.fileProviderStorageExists(metadata) {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_download_image_max_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "square.and.arrow.down"),
                    action: { _ in
                        NCNetworking.shared.download(metadata: metadata, selector: "") { _, _ in }
                    }
                )
            )
        }

        //
        // PDF
        //
        if metadata.contentType == "com.adobe.pdf" || metadata.contentType == "application/pdf" {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_search_", comment: ""),
                    icon: UIImage(named: "search")!.image(color: UIColor.systemGray, size: 50),
                    action: { _ in
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterMenuSearchTextPDF)
                    }
                )
            )

            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_go_to_page_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "repeat"),
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
                    icon: NCUtility.shared.loadImage(named: "pencil.tip.crop.circle"),
                    action: { _ in
                        if CCUtility.fileProviderStorageExists(metadata) {
                            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadedFile, userInfo: ["ocId": metadata.ocId, "selector": NCGlobal.shared.selectorLoadFileQuickLook, "error": NKError(), "account": metadata.account])
                        } else {
                            NCNetworking.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorLoadFileQuickLook) { _, _ in }
                        }
                    }
                )
            )
        }

        //
        // DELETE
        //
        if !webView, metadata.isDeletable {
            actions.append(.deleteAction(selectedMetadatas: [metadata], metadataFolder: nil, viewController: viewController))
        }

        viewController.presentMenu(with: actions)
    }
}
