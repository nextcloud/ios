//
//  NCContextMenu.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 10/01/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
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

import Foundation
import Alamofire
import NextcloudKit
import JGProgressHUD

class NCContextMenu: NSObject {

    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()

    func viewMenu(ocId: String, viewController: UIViewController, image: UIImage?) -> UIMenu {
        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId),
              let sceneIdentifier = (viewController.tabBarController as? NCMainTabBarController)?.sceneIdentifier else { return UIMenu() }
        var downloadRequest: DownloadRequest?
        var titleDeleteConfirmFile = NSLocalizedString("_delete_file_", comment: "")
        let metadataMOV = NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata)

        if metadata.directory { titleDeleteConfirmFile = NSLocalizedString("_delete_folder_", comment: "") }

        let hud = JGProgressHUD()
        hud.indicatorView = JGProgressHUDRingIndicatorView()
        hud.textLabel.text = NSLocalizedString("_downloading_", comment: "")
        hud.detailTextLabel.text = NSLocalizedString("_tap_to_cancel_", comment: "")
        if let indicatorView = hud.indicatorView as? JGProgressHUDRingIndicatorView { indicatorView.ringWidth = 1.5 }
        hud.tapOnHUDViewBlock = { _ in
            if let request = downloadRequest {
                request.cancel()
            }
        }

        // MENU ITEMS

        let detail = UIAction(title: NSLocalizedString("_details_", comment: ""),
                              image: UIImage(systemName: "info.circle")) { _ in
            NCActionCenter.shared.openShare(viewController: viewController, metadata: metadata, page: .activity)
        }

        let favorite = UIAction(title: metadata.favorite ?
                                NSLocalizedString("_remove_favorites_", comment: "") :
                                NSLocalizedString("_add_favorites_", comment: ""),
                                image: utility.loadImage(named: metadata.favorite ? "star.slash" : "star", color: NCBrandColor.shared.yellowFavorite)) { _ in
            NCNetworking.shared.favoriteMetadata(metadata) { error in
                if error != .success {
                    NCContentPresenter().showError(error: error)
                }
            }
        }

        let share = UIAction(title: NSLocalizedString("_share_", comment: ""),
                              image: UIImage(systemName: "square.and.arrow.up") ) { _ in
            if self.utilityFileSystem.fileProviderStorageExists(metadata) {
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile),
                    object: nil,
                    userInfo: ["ocId": metadata.ocId,
                               "selector": NCGlobal.shared.selectorOpenIn,
                               "error": NKError(),
                               "account": metadata.account])
            } else {
                guard let metadata = NCManageDatabase.shared.setMetadatasSessionInWaitDownload(metadatas: [metadata],
                                                                                               session: NextcloudKit.shared.nkCommonInstance.sessionIdentifierDownload,
                                                                                               selector: NCGlobal.shared.selectorOpenIn) else { return }
                hud.show(in: viewController.view)
                NCNetworking.shared.download(metadata: metadata, withNotificationProgressTask: false) {
                } requestHandler: { request in
                    downloadRequest = request
                } progressHandler: { progress in
                    hud.progress = Float(progress.fractionCompleted)
                } completion: { afError, error in
                    DispatchQueue.main.async {
                        if error == .success || afError?.isExplicitlyCancelledError ?? false {
                            hud.dismiss()
                        } else {
                            hud.indicatorView = JGProgressHUDErrorIndicatorView()
                            hud.textLabel.text = error.description
                            hud.dismiss(afterDelay: NCGlobal.shared.dismissAfterSecond)
                        }
                    }
                }
            }
        }

        let viewInFolder = UIAction(title: NSLocalizedString("_view_in_folder_", comment: ""),
                                    image: UIImage(systemName: "questionmark.folder")) { _ in
            NCActionCenter.shared.openFileViewInFolder(serverUrl: metadata.serverUrl, fileNameBlink: metadata.fileName, fileNameOpen: nil, sceneIdentifier: sceneIdentifier)
        }

        let livePhotoSave = UIAction(title: NSLocalizedString("_livephoto_save_", comment: ""),
                                     image: UIImage(systemName: "livephoto")) { _ in
            if let metadataMOV = metadataMOV {
                NCNetworking.shared.saveLivePhotoQueue.addOperation(NCOperationSaveLivePhoto(metadata: metadata, metadataMOV: metadataMOV, hudView: viewController.view))
            }
        }

        let modify = UIAction(title: NSLocalizedString("_modify_", comment: ""),
                              image: UIImage(systemName: "pencil.tip.crop.circle")) { _ in
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
                                                                                               selector: NCGlobal.shared.selectorLoadFileQuickLook) else { return }
                hud.show(in: viewController.view)
                NCNetworking.shared.download(metadata: metadata, withNotificationProgressTask: false) {
                } requestHandler: { request in
                    downloadRequest = request
                } progressHandler: { progress in
                    hud.progress = Float(progress.fractionCompleted)
                } completion: { afError, error in
                    DispatchQueue.main.async {
                        if error == .success || afError?.isExplicitlyCancelledError ?? false {
                            hud.dismiss()
                        } else {
                            hud.indicatorView = JGProgressHUDErrorIndicatorView()
                            hud.textLabel.text = error.description
                            hud.dismiss(afterDelay: NCGlobal.shared.dismissAfterSecond)
                        }
                    }
                }
            }
        }

        let deleteConfirmFile = UIAction(title: titleDeleteConfirmFile,
                                         image: UIImage(systemName: "trash"), attributes: .destructive) { _ in

            var alertStyle = UIAlertController.Style.actionSheet
            if UIDevice.current.userInterfaceIdiom == .pad {
                alertStyle = .alert
            }
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: alertStyle)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_delete_file_", comment: ""), style: .destructive) { _ in
                Task {
                    var ocId: [String] = []
                    let error = await NCNetworking.shared.deleteMetadata(metadata, onlyLocalCache: false)
                    if error == .success {
                        ocId.append(metadata.ocId)
                    } else {
                        NCContentPresenter().showError(error: error)
                    }
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDeleteFile, userInfo: ["ocId": ocId, "onlyLocalCache": false, "error": error])
                }
            })
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel) { _ in })
            viewController.present(alertController, animated: true, completion: nil)
        }

        let deleteConfirmLocal = UIAction(title: NSLocalizedString("_remove_local_file_", comment: ""),
                                          image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
            Task {
                var ocId: [String] = []
                let error = await NCNetworking.shared.deleteMetadata(metadata, onlyLocalCache: true)
                if error == .success {
                    ocId.append(metadata.ocId)
                } else {
                    NCContentPresenter().showError(error: error)
                }
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDeleteFile, userInfo: ["ocId": ocId, "onlyLocalCache": true, "error": error])
            }
        }

        let deleteSubMenu = UIMenu(title: NSLocalizedString("_delete_file_", comment: ""),
                                   image: UIImage(systemName: "trash"),
                                   options: .destructive,
                                   children: [deleteConfirmLocal, deleteConfirmFile])

        // ------ MENU -----

        var menu: [UIMenuElement] = []

        if metadata.directory {

            if metadata.isDirectoryE2EE || metadata.e2eEncrypted {
                menu.append(favorite)
            } else {
                menu.append(favorite)
                menu.append(deleteConfirmFile)
            }
            return UIMenu(title: "", children: [detail, UIMenu(title: "", options: .displayInline, children: menu)])

        } else {

            if metadata.lock {
                menu.append(favorite)
                if metadata.isDocumentViewableOnly {
                    //
                } else {
                    menu.append(share)
                    if NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) != nil {
                        menu.append(livePhotoSave)
                    }
                }
            } else {
                menu.append(favorite)
                if metadata.isDocumentViewableOnly {
                    if viewController is NCMedia {
                        menu.append(viewInFolder)
                    }
                } else {
                    menu.append(share)
                    if NCManageDatabase.shared.getMetadataLivePhoto(metadata: metadata) != nil {
                        menu.append(livePhotoSave)
                    }

                    if viewController is NCMedia {
                        menu.append(viewInFolder)
                    }

                    // MODIFY WITH QUICK LOOK
                    if metadata.isModifiableWithQuickLook {
                        menu.append(modify)
                    }
                }
                if viewController is NCMedia {
                    menu.append(deleteConfirmFile)
                } else {
                    menu.append(deleteSubMenu)
                }
            }
            return UIMenu(title: "", children: [detail, UIMenu(title: "", options: .displayInline, children: menu)])
        }
    }
}
