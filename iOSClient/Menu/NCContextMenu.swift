// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import Alamofire
import NextcloudKit

class NCContextMenu: NSObject {
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let database = NCManageDatabase.shared
    let global = NCGlobal.shared
    let networking = NCNetworking.shared

    let metadata: tableMetadata
    let sceneIdentifier: String
    let viewController: UIViewController
    let image: UIImage?

    init(metadata: tableMetadata, viewController: UIViewController, sceneIdentifier: String, image: UIImage?) {
        self.metadata = metadata
        self.viewController = viewController
        self.sceneIdentifier = sceneIdentifier
        self.image = image
    }

    func viewMenu() -> UIMenu {
        var downloadRequest: DownloadRequest?
        var titleDeleteConfirmFile = NSLocalizedString("_delete_file_", comment: "")
        let metadataMOV = self.database.getMetadataLivePhoto(metadata: metadata)
        let hud = NCHud(viewController.view)

        if metadata.directory { titleDeleteConfirmFile = NSLocalizedString("_delete_folder_", comment: "") }

        // MENU ITEMS

        let detail = UIAction(title: NSLocalizedString("_details_", comment: ""),
                              image: utility.loadImage(named: "info.circle")) { _ in
            NCDownloadAction.shared.openShare(viewController: self.viewController, metadata: self.metadata, page: .activity)
        }

        let favorite = UIAction(title: metadata.favorite ?
                                NSLocalizedString("_remove_favorites_", comment: "") :
                                NSLocalizedString("_add_favorites_", comment: ""),
                                image: utility.loadImage(named: self.metadata.favorite ? "star.slash" : "star", colors: [NCBrandColor.shared.yellowFavorite])) { _ in
            self.networking.favoriteMetadata(self.metadata) { error in
                if error != .success {
                    NCContentPresenter().showError(error: error)
                }
            }
        }

        let share = UIAction(title: NSLocalizedString("_share_", comment: ""),
                             image: utility.loadImage(named: "square.and.arrow.up") ) { _ in
            if self.utilityFileSystem.fileProviderStorageExists(self.metadata) {
                self.networking.notifyAllDelegates { delegate in
                    let metadata = self.metadata.detachedCopy()
                    metadata.sessionSelector = self.global.selectorOpenIn
                    delegate.transferChange(status: self.global.networkingStatusDownloaded,
                                            metadata: metadata,
                                            error: .success)
                }
            } else {
                guard let metadata = self.database.setMetadataSessionInWaitDownload(ocId: self.metadata.ocId,
                                                                                    session: self.networking.sessionDownload,
                                                                                    selector: self.global.selectorOpenIn,
                                                                                    sceneIdentifier: self.sceneIdentifier) else {
                    return
                }

                hud.initHudRing(text: NSLocalizedString("_downloading_", comment: ""), tapToCancelDetailText: true) {
                    if let request = downloadRequest {
                        request.cancel()
                    }
                }

                self.networking.download(metadata: metadata) {
                } requestHandler: { request in
                    downloadRequest = request
                } progressHandler: { progress in
                    hud.progress(progress.fractionCompleted)
                } completion: { afError, error in
                    if error == .success || afError?.isExplicitlyCancelledError ?? false {
                        hud.dismiss()
                    } else {
                        hud.error(text: error.errorDescription)
                    }
                }
            }
        }

        let viewInFolder = UIAction(title: NSLocalizedString("_view_in_folder_", comment: ""),
                                    image: utility.loadImage(named: "questionmark.folder")) { _ in
            NCDownloadAction.shared.openFileViewInFolder(serverUrl: self.metadata.serverUrl, fileNameBlink: self.metadata.fileName, fileNameOpen: nil, sceneIdentifier: self.sceneIdentifier)
        }

        let livePhotoSave = UIAction(title: NSLocalizedString("_livephoto_save_", comment: ""), image: utility.loadImage(named: "livephoto")) { _ in
            if let metadataMOV = metadataMOV {
                self.networking.saveLivePhotoQueue.addOperation(NCOperationSaveLivePhoto(metadata: self.metadata, metadataMOV: metadataMOV, hudView: self.viewController.view))
            }
        }

        let modify = UIAction(title: NSLocalizedString("_modify_", comment: ""),
                              image: utility.loadImage(named: "pencil.tip.crop.circle")) { _ in
            if self.utilityFileSystem.fileProviderStorageExists(self.metadata) {
                self.networking.notifyAllDelegates { delegate in
                    let metadata = self.metadata.detachedCopy()
                    metadata.sessionSelector = self.global.selectorLoadFileQuickLook
                    delegate.transferChange(status: self.global.networkingStatusDownloaded,
                                            metadata: metadata,
                                            error: .success)
                }
            } else {
                guard let metadata = self.database.setMetadataSessionInWaitDownload(ocId: self.metadata.ocId,
                                                                                    session: self.networking.sessionDownload,
                                                                                    selector: self.global.selectorLoadFileQuickLook,
                                                                                    sceneIdentifier: self.sceneIdentifier) else {
                    return
                }

                hud.initHudRing(text: NSLocalizedString("_downloading_", comment: "")) {
                    if let request = downloadRequest {
                        request.cancel()
                    }
                }

                self.networking.download(metadata: metadata) {
                } requestHandler: { request in
                    downloadRequest = request
                } progressHandler: { progress in
                    hud.progress(progress.fractionCompleted)
                } completion: { afError, error in
                    if error == .success || afError?.isExplicitlyCancelledError ?? false {
                        hud.dismiss()
                    } else {
                        hud.error(text: error.errorDescription)
                    }
                }
            }
        }

        let deleteConfirmFile = UIAction(title: titleDeleteConfirmFile,
                                         image: utility.loadImage(named: "trash"), attributes: .destructive) { _ in

            var alertStyle = UIAlertController.Style.actionSheet
            if UIDevice.current.userInterfaceIdiom == .pad {
                alertStyle = .alert
            }
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: alertStyle)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_delete_file_", comment: ""), style: .destructive) { _ in
                if let viewController = self.viewController as? NCCollectionViewCommon {
                    self.networking.setStatusWaitDelete(metadatas: [self.metadata], sceneIdentifier: self.sceneIdentifier)
                    Task {
                        await viewController.reloadDataSource()
                    }
                }
                if let viewController = self.viewController as? NCMedia {
                    Task {
                        await viewController.deleteImage(with: self.metadata.ocId)
                    }
                }
            })
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel) { _ in })
            self.viewController.present(alertController, animated: true, completion: nil)
        }

        let deleteConfirmLocal = UIAction(title: NSLocalizedString("_remove_local_file_", comment: ""),
                                          image: utility.loadImage(named: "trash"), attributes: .destructive) { _ in
            Task {
                var metadatasError: [tableMetadata: NKError] = [:]
                let error = await self.networking.deleteCache(self.metadata, sceneIdentifier: self.sceneIdentifier)
                metadatasError[self.metadata.detachedCopy()] = error

                self.networking.notifyAllDelegates { delegate in
                    delegate.transferChange(status: self.global.networkingStatusDelete,
                                            metadatasError: metadatasError)
                }
            }
        }

        let deleteSubMenu = UIMenu(title: NSLocalizedString("_delete_file_", comment: ""),
                                   image: utility.loadImage(named: "trash"),
                                   options: .destructive,
                                   children: [deleteConfirmLocal, deleteConfirmFile])

        // ------ MENU -----

        var menu: [UIMenuElement] = []

        if self.networking.isOnline {
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
                    menu.append(share)

                    if self.database.getMetadataLivePhoto(metadata: metadata) != nil {
                        menu.append(livePhotoSave)
                    }
                } else {
                    menu.append(favorite)
                    menu.append(share)

                    if self.database.getMetadataLivePhoto(metadata: metadata) != nil {
                        menu.append(livePhotoSave)
                    }

                    if viewController is NCMedia {
                        menu.append(viewInFolder)
                    }

                    // MODIFY WITH QUICK LOOK
                    if metadata.isModifiableWithQuickLook {
                        menu.append(modify)
                    }

                    if viewController is NCMedia {
                        menu.append(deleteConfirmFile)
                    } else {
                        menu.append(deleteSubMenu)
                    }
                }
                return UIMenu(title: "", children: [detail, UIMenu(title: "", options: .displayInline, children: menu)])
            }
        } else {
            return UIMenu()
        }
    }
}
