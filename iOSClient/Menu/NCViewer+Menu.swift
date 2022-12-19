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
        let isDirectoryE2EE = NCUtility.shared.isDirectoryE2EE(metadata: metadata)
        let isOffline = localFile?.offline == true

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
        // DETAIL
        //
        if !appDelegate.disableSharesView {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_details_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "info"),
                    action: { _ in
                        NCFunctionCenter.shared.openShare(viewController: viewController, metadata: metadata, indexPage: .activity)
                    }
                )
            )
        }

        //
        // OFFLINE
        //
        if metadata.session == "" && !webView {
            actions.append(.setAvailableOfflineAction(selectedMetadatas: [metadata], isAnyOffline: isOffline, viewController: viewController))
        }

        //
        // OPEN IN
        //
        if metadata.session == "" && !webView {
            actions.append(.openInAction(selectedMetadatas: [metadata], viewController: viewController))
        }

        //
        // PRINT
        //
        if metadata.classFile == NKCommon.typeClassFile.image.rawValue || metadata.contentType == "application/pdf" || metadata.contentType == "com.adobe.pdf" {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_print_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "printer"),
                    action: { _ in
                        NCFunctionCenter.shared.openDownload(metadata: metadata, selector: NCGlobal.shared.selectorPrint)
                    }
                )
            )
        }
        
        //
        // CONVERSION VIDEO TO MPEG4 (MFFF Lib)
        //
#if MFFFLIB
        if metadata.classFile == NKCommon.typeClassFile.video.rawValue {
            
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
        // SAVE IMAGE / VIDEO
        //
        if metadata.classFile == NKCommon.typeClassFile.image.rawValue || metadata.classFile == NKCommon.typeClassFile.video.rawValue {
            actions.append(.saveMediaAction(selectedMediaMetadatas: [metadata]))
        }

        //
        // SAVE AS SCAN
        //
        if metadata.classFile == NKCommon.typeClassFile.image.rawValue && metadata.contentType != "image/svg+xml" {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_save_as_scan_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "viewfinder.circle"),
                    action: { _ in
                        NCFunctionCenter.shared.openDownload(metadata: metadata, selector: NCGlobal.shared.selectorSaveAsScan)
                    }
                )
            )
        }

        //
        // RENAME
        //
        if !webView, !metadata.lock {
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
        if !webView {
            actions.append(.moveOrCopyAction(selectedMetadatas: [metadata]))
        }

        //
        // COPY
        //
        actions.append(.copyAction(selectOcId: [metadata.ocId], hudView: viewController.view))

        //
        // VIEW IN FOLDER
        //
        if !webView {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_view_in_folder_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "arrow.forward.square"),
                    action: { menuAction in
                        NCFunctionCenter.shared.openFileViewInFolder(serverUrl: metadata.serverUrl, fileNameBlink: metadata.fileName, fileNameOpen: nil)
                    }
                )
            )
        }

        //
        // DOWNLOAD IMAGE MAX RESOLUTION
        //
        if metadata.session == "" {
            if metadata.classFile == NKCommon.typeClassFile.image.rawValue && !CCUtility.fileProviderStorageExists(metadata) && metadata.session == "" {
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
        }

        //
        // PDF
        //
        if metadata.contentType == "com.adobe.pdf" || metadata.contentType == "application/pdf" {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_search_", comment: ""),
                    icon: UIImage(named: "search")!.image(color: NCBrandColor.shared.gray, size: 50),
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
        // MODIFY
        //
        if !isDirectoryE2EE && metadata.contentType != "image/gif" && (metadata.contentType == "com.adobe.pdf" || metadata.contentType == "application/pdf" || metadata.classFile == NKCommon.typeClassFile.image.rawValue) {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_modify_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "pencil.tip.crop.circle"),
                    action: { _ in
                        NCFunctionCenter.shared.openDownload(metadata: metadata, selector: NCGlobal.shared.selectorLoadFileQuickLook)
                    }
                )
            )
        }

        //
        // DELETE
        //
        if !webView {
            actions.append(.deleteAction(selectedMetadatas: [metadata], metadataFolder: nil, viewController: viewController))
        }

        viewController.presentMenu(with: actions)
    }
}
