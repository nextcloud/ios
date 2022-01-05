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
import NCCommunication

extension NCViewer {

    func toggleMenu(viewController: UIViewController, metadata: tableMetadata, webView: Bool, imageIcon: UIImage?) {

        var actions = [NCMenuAction]()

        var titleFavorite = NSLocalizedString("_add_favorites_", comment: "")
        if metadata.favorite { titleFavorite = NSLocalizedString("_remove_favorites_", comment: "") }
        let localFile = NCManageDatabase.shared.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId))

        var titleOffline = ""
        if localFile == nil || localFile!.offline == false {
            titleOffline = NSLocalizedString("_set_available_offline_", comment: "")
        } else {
            titleOffline = NSLocalizedString("_remove_available_offline_", comment: "")
        }

        var titleDelete = NSLocalizedString("_delete_", comment: "")
        if NCManageDatabase.shared.isMetadataShareOrMounted(metadata: metadata, metadataFolder: nil) {
            titleDelete = NSLocalizedString("_leave_share_", comment: "")
        } else if metadata.directory {
            titleDelete = NSLocalizedString("_delete_folder_", comment: "")
        } else {
            titleDelete = NSLocalizedString("_delete_file_", comment: "")
        }

        let isFolderEncrypted = CCUtility.isFolderEncrypted(metadata.serverUrl, e2eEncrypted: metadata.e2eEncrypted, account: metadata.account, urlBase: metadata.urlBase)

        //
        // FAVORITE
        //
        actions.append(
            NCMenuAction(
                title: titleFavorite,
                icon: NCUtility.shared.loadImage(named: "star.fill", color: NCBrandColor.shared.yellowFavorite),
                action: { _ in
                    NCNetworking.shared.favoriteMetadata(metadata) { errorCode, errorDescription in
                        if errorCode != 0 {
                            NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                        }
                    }
                }
            )
        )

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
            actions.append(
                NCMenuAction(
                    title: titleOffline,
                    icon: NCUtility.shared.loadImage(named: "tray.and.arrow.down"),
                    action: { _ in
                        if (localFile == nil || !CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView)) && metadata.session == "" {
                            NCNetworking.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorLoadOffline) { _ in }
                        } else {
                            NCManageDatabase.shared.setLocalFile(ocId: metadata.ocId, offline: !localFile!.offline)
                        }
                    }
                )
            )
        }

        //
        // OPEN IN
        //
        if metadata.session == "" && !webView {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_open_in_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "square.and.arrow.up"),
                    action: { _ in
                        NCFunctionCenter.shared.openDownload(metadata: metadata, selector: NCGlobal.shared.selectorOpenIn)
                    }
                )
            )
        }

        //
        // PRINT
        //
        if metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue || metadata.contentType == "application/pdf" || metadata.contentType == "com.adobe.pdf" {
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
        if metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue {
            
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_video_conversion_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "film"),
                    action: { menuAction in
                        if let ncplayer = (viewController as? NCViewerMediaPage)?.currentViewController.ncplayer {
                            ncplayer.convertVideo()
                        }
                    }
                )
            )
        }
        #endif
        
        //
        // SAVE IMAGE / VIDEO
        //
        if metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue || metadata.classFile == NCCommunicationCommon.typeClassFile.video.rawValue {

            var title: String = NSLocalizedString("_save_selected_files_", comment: "")
            var icon = NCUtility.shared.loadImage(named: "square.and.arrow.down")
            let metadataMOV = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata)
            if metadataMOV != nil {
                title = NSLocalizedString("_livephoto_save_", comment: "")
                icon = NCUtility.shared.loadImage(named: "livephoto")
            }

            actions.append(
                NCMenuAction(
                    title: title,
                    icon: icon,
                    action: { _ in
                        if metadataMOV != nil {
                            NCFunctionCenter.shared.saveLivePhoto(metadata: metadata, metadataMOV: metadataMOV!)
                        } else {
                            NCOperationQueue.shared.download(metadata: metadata, selector: NCGlobal.shared.selectorSaveAlbum)
                        }
                    }
                )
            )
        }

        //
        // SAVE AS SCAN
        //
        if #available(iOS 13.0, *) {
            if metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue && metadata.contentType != "image/svg+xml" {
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
        }

        //
        // RENAME
        //
        if !webView {
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
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_move_or_copy_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "arrow.up.right.square"),
                    action: { _ in

                        let storyboard = UIStoryboard(name: "NCSelect", bundle: nil)
                        let navigationController = storyboard.instantiateInitialViewController() as! UINavigationController
                        let viewController = navigationController.topViewController as! NCSelect

                        viewController.delegate = NCViewer.shared
                        viewController.typeOfCommandView = .copyMove
                        viewController.items = [metadata]

                        self.appDelegate.window?.rootViewController?.present(navigationController, animated: true, completion: nil)
                    }
                )
            )
        }

        //
        // COPY
        //
        actions.append(
            NCMenuAction(
                title: NSLocalizedString("_copy_file_", comment: ""),
                icon: NCUtility.shared.loadImage(named: "doc.on.doc"),
                action: { _ in
                    self.appDelegate.pasteboardOcIds = [metadata.ocId]
                    NCFunctionCenter.shared.copyPasteboard()
                }
            )
        )

        //
        // VIEW IN FOLDER
        //
        if !webView {
            actions.append(
                NCMenuAction(
                    title: NSLocalizedString("_view_in_folder_", comment: ""),
                    icon: NCUtility.shared.loadImage(named: "arrow.forward.square"),
                    action: { menuAction in
                        NCFunctionCenter.shared.openFileViewInFolder(serverUrl: metadata.serverUrl, fileName: metadata.fileName)
                    }
                )
            )
        }

        //
        // DOWNLOAD IMAGE MAX RESOLUTION
        //
        if metadata.session == "" {
            if metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue && !CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) && metadata.session == "" {
                actions.append(
                    NCMenuAction(
                        title: NSLocalizedString("_download_image_max_", comment: ""),
                        icon: NCUtility.shared.loadImage(named: "square.and.arrow.down"),
                        action: { _ in
                            NCNetworking.shared.download(metadata: metadata, selector: "") { _ in }
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

            var title = ""
            var icon = UIImage()

            if CCUtility.getPDFDisplayDirection() == .horizontal {
                title = NSLocalizedString("_pdf_vertical_", comment: "")
                icon = UIImage(named: "pdf-vertical")!.image(color: NCBrandColor.shared.gray, size: 50)
            } else {
                title = NSLocalizedString("_pdf_horizontal_", comment: "")
                icon = UIImage(named: "pdf-horizontal")!.image(color: NCBrandColor.shared.gray, size: 50)
            }

            actions.append(
                NCMenuAction(
                    title: title,
                    icon: icon,
                    action: { _ in
                        if CCUtility.getPDFDisplayDirection() == .horizontal {
                            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterMenuPDFDisplayDirection, userInfo: ["direction": PDFDisplayDirection.vertical])
                        } else {
                            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterMenuPDFDisplayDirection, userInfo: ["direction": PDFDisplayDirection.horizontal])
                        }
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
        if #available(iOS 13.0, *) {
            if !isFolderEncrypted && metadata.contentType != "image/gif" && (metadata.contentType == "com.adobe.pdf" || metadata.contentType == "application/pdf" || metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue) {
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
        }

        //
        // DELETE
        //
        if !webView {
            actions.append(
                NCMenuAction(
                    title: titleDelete,
                    icon: NCUtility.shared.loadImage(named: "trash"),
                    action: { _ in

                        let alertController = UIAlertController(title: "", message: NSLocalizedString("_want_delete_", comment: ""), preferredStyle: .alert)

                        alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_delete_", comment: ""), style: .default) { (_: UIAlertAction) in

                            NCNetworking.shared.deleteMetadata(metadata, onlyLocalCache: false) { errorCode, errorDescription in
                                if errorCode != 0 {
                                    NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                                }
                            }
                        })

                        alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_delete_", comment: ""), style: .default) { (_: UIAlertAction) in })

                        viewController.present(alertController, animated: true, completion: nil)
                    }
                )
            )
        }

        viewController.presentMenu(with: actions)
    }
}
