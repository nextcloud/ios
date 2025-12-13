// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import Alamofire
import NextcloudKit
import LucidBanner

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
    let sender: Any?

    init(metadata: tableMetadata, viewController: UIViewController, sceneIdentifier: String, image: UIImage?, sender: Any?) {
        self.metadata = metadata
        self.viewController = viewController
        self.sceneIdentifier = sceneIdentifier
        self.image = image
        self.sender = sender
    }

    func viewMenu() -> UIMenu {
        var downloadRequest: DownloadRequest?
        var titleDeleteConfirmFile = NSLocalizedString("_delete_file_", comment: "")
        let metadataMOV = self.database.getMetadataLivePhoto(metadata: metadata)
        let scene = SceneManager.shared.getWindow(sceneIdentifier: sceneIdentifier)?.windowScene

        if metadata.directory { titleDeleteConfirmFile = NSLocalizedString("_delete_folder_", comment: "") }

        // MENU ITEMS

        let detail = UIAction(title: NSLocalizedString("_details_", comment: ""),
                              image: utility.loadImage(named: "info.circle")) { _ in
            NCCreate().createShare(viewController: self.viewController, metadata: self.metadata, page: .activity)
        }

        let favorite = UIAction(title: metadata.favorite ?
                                NSLocalizedString("_remove_favorites_", comment: "") :
                                NSLocalizedString("_add_favorites_", comment: ""),
                                image: utility.loadImage(named: self.metadata.favorite ? "star.slash" : "star", colors: [NCBrandColor.shared.yellowFavorite])) { _ in
            self.networking.setStatusWaitFavorite(self.metadata) { error in
                if error != .success {
                    NCContentPresenter().showError(error: error)
                }
            }
        }

        let share = UIAction(title: NSLocalizedString("_share_", comment: ""),
                             image: utility.loadImage(named: "square.and.arrow.up") ) { _ in
            Task {@MainActor in
                let controller = self.viewController.tabBarController as? NCMainTabBarController
                await NCCreate().createActivityViewController(selectedMetadata: [self.metadata],
                                                              controller: controller,
                                                              sender: self.sender)
            }
        }

        let viewInFolder = UIAction(title: NSLocalizedString("_view_in_folder_", comment: ""),
                                    image: utility.loadImage(named: "questionmark.folder")) { _ in
            NCNetworking.shared.openFileViewInFolder(serverUrl: self.metadata.serverUrl, fileNameBlink: self.metadata.fileName, fileNameOpen: nil, sceneIdentifier: self.sceneIdentifier)
        }

        let livePhotoSave = UIAction(title: NSLocalizedString("_livephoto_save_", comment: ""), image: utility.loadImage(named: "livephoto")) { _ in
            if let metadataMOV = metadataMOV {
                self.networking.saveLivePhotoQueue.addOperation(NCOperationSaveLivePhoto(metadata: self.metadata, metadataMOV: metadataMOV, controller: self.viewController.tabBarController))
            }
        }

        let modify = UIAction(title: NSLocalizedString("_modify_", comment: ""),
                              image: utility.loadImage(named: "pencil.tip.crop.circle")) { _ in
            Task { @MainActor in
                if self.utilityFileSystem.fileProviderStorageExists(self.metadata) {
                    await self.networking.transferDispatcher.notifyAllDelegates { delegate in
                        delegate.transferChange(status: self.global.networkingStatusDownloaded,
                                                account: self.metadata.account,
                                                fileName: self.metadata.fileName,
                                                serverUrl: self.metadata.serverUrl,
                                                selector: self.global.selectorLoadFileQuickLook,
                                                ocId: self.metadata.ocId,
                                                destination: nil,
                                                error: .success)
                    }
                } else {
                    guard let metadata = await self.database.setMetadataSessionInWaitDownloadAsync(ocId: self.metadata.ocId,
                                                                                                   session: self.networking.sessionDownload,
                                                                                                   selector: self.global.selectorLoadFileQuickLook,
                                                                                                   sceneIdentifier: self.sceneIdentifier) else {
                        return
                    }

                    let token = showHudBanner(scene: scene,
                                              title: NSLocalizedString("_download_in_progress_", comment: ""),
                                              stage: .button) {
                        if let request = downloadRequest {
                            request.cancel()
                        }
                    }

                    let results = await self.networking.downloadFile(metadata: metadata) { request in
                        downloadRequest = request
                    } progressHandler: { progress in
                        Task {@MainActor in
                            LucidBanner.shared.update(progress: progress.fractionCompleted, for: token)
                        }
                    }
                    LucidBanner.shared.dismiss()

                    if results.nkError == .success || results.afError?.isExplicitlyCancelledError ?? false {
                        //
                    } else {
                        await showErrorBanner(scene: scene, errorDescription: results.nkError.errorDescription, errorCode: results.nkError.errorCode)
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
                    Task {
                        await self.networking.setStatusWaitDelete(metadatas: [self.metadata], sceneIdentifier: self.sceneIdentifier)
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
                let error = await self.networking.deleteCache(self.metadata, sceneIdentifier: self.sceneIdentifier)

                await self.networking.transferDispatcher.notifyAllDelegates { delegate in
                    delegate.transferChange(status: NCGlobal.shared.networkingStatusDelete,
                                            account: self.metadata.account,
                                            fileName: self.metadata.fileName,
                                            serverUrl: self.metadata.serverUrl,
                                            selector: self.metadata.sessionSelector,
                                            ocId: self.metadata.ocId,
                                            destination: nil,
                                            error: error)
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
