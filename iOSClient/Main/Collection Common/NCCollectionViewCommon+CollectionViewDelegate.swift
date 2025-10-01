// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import NextcloudKit
import Alamofire

extension NCCollectionViewCommon: UICollectionViewDelegate {
    func didSelectMetadata(_ metadata: tableMetadata, withOcIds: Bool) {
        let capabilities = NCNetworking.shared.capabilities[session.account] ?? NKCapabilities.Capabilities()
        if metadata.e2eEncrypted {
            if capabilities.e2EEEnabled {
                if !NCPreferences().isEndToEndEnabled(account: metadata.account) {
                    let e2ee = NCEndToEndInitialize()
                    e2ee.delegate = self
                    e2ee.initEndToEndEncryption(controller: self.controller, metadata: metadata)
                    return
                }
            } else {
                NCContentPresenter().showInfo(error: NKError(errorCode: global.errorE2EENotEnabled, errorDescription: "_e2e_server_disabled_"))
                return
            }
        }

        func downloadFile() async {
            let hud = NCHud(self.tabBarController?.view)
            var downloadRequest: DownloadRequest?
            guard let  metadata = await database.setMetadataSessionInWaitDownloadAsync(ocId: metadata.ocId,
                                                                                       session: self.networking.sessionDownload,
                                                                                       selector: global.selectorLoadFileView,
                                                                                       sceneIdentifier: self.controller?.sceneIdentifier) else {
                return
            }

            hud.ringProgress(text: NSLocalizedString("_downloading_", comment: ""), tapToCancelDetailText: true) {
                if let request = downloadRequest {
                    request.cancel()
                }
            }

            let results = await self.networking.downloadFile(metadata: metadata) { request in
                downloadRequest = request
            } progressHandler: { progress in
                hud.progress(progress.fractionCompleted)
            }
            if results.nkError == .success || results.afError?.isExplicitlyCancelledError ?? false {
                hud.dismiss()
            } else {
                hud.error(text: results.nkError.errorDescription)
            }
        }

        if metadata.directory {
            pushMetadata(metadata)
        } else {
            Task { @MainActor in
                let image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: self.global.previewExt1024, userId: metadata.userId, urlBase: metadata.urlBase)
                let fileExists = utilityFileSystem.fileProviderStorageExists(metadata)

                // --- E2EE -------
                if metadata.isDirectoryE2EE {
                    if fileExists {
                        if let vc = await NCViewer().getViewerController(metadata: metadata, delegate: self) {
                            self.navigationController?.pushViewController(vc, animated: true)
                        }
                    } else {
                        await downloadFile()
                    }
                    return
                }
                // ---------------

                if metadata.isImage || metadata.isAudioOrVideo {
                    let metadatas = self.dataSource.getMetadatas()
                    let ocIds = metadatas.filter { $0.classFile == NKTypeClassFile.image.rawValue ||
                        $0.classFile == NKTypeClassFile.video.rawValue ||
                        $0.classFile == NKTypeClassFile.audio.rawValue }.map(\.ocId)

                    if let vc = await NCViewer().getViewerController(metadata: metadata, ocIds: withOcIds ? ocIds : nil, image: image, delegate: self) {
                        self.navigationController?.pushViewController(vc, animated: true)
                    }
                } else if !metadata.isDirectoryE2EE, metadata.isAvailableEditorView || utilityFileSystem.fileProviderStorageExists(metadata) || metadata.name == self.global.talkName {
                    if let vc = await NCViewer().getViewerController(metadata: metadata, image: image, delegate: self) {
                        self.navigationController?.pushViewController(vc, animated: true)
                    }
                } else if NextcloudKit.shared.isNetworkReachable() {
                    guard let  metadata = await database.setMetadataSessionInWaitDownloadAsync(ocId: metadata.ocId,
                                                                                               session: self.networking.sessionDownload,
                                                                                               selector: global.selectorLoadFileView,
                                                                                               sceneIdentifier: self.controller?.sceneIdentifier) else {
                        return
                    }

                    if metadata.name == "files" {
                        await downloadFile()
                    } else if !metadata.url.isEmpty,
                              let vc = await NCViewer().getViewerController(metadata: metadata, delegate: self) {
                        self.navigationController?.pushViewController(vc, animated: true)
                    }
                } else {
                    let error = NKError(errorCode: global.errorOffline, errorDescription: "_go_online_")
                    NCContentPresenter().showInfo(error: error)
                }
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let metadata = self.dataSource.getMetadata(indexPath: indexPath) else {
            return
        }

        if self.isEditMode {
            if let index = self.fileSelect.firstIndex(of: metadata.ocId) {
                self.fileSelect.remove(at: index)
            } else {
                self.fileSelect.append(metadata.ocId)
            }
            self.collectionView.reloadItems(at: [indexPath])
            self.tabBarSelect?.update(fileSelect: self.fileSelect, metadatas: self.getSelectedMetadatas(), userId: metadata.userId)
            // self.collectionView.reloadSections(IndexSet(integer: indexPath.section))

            self.collectionView.collectionViewLayout.invalidateLayout()
            return
        }

        self.didSelectMetadata(metadata, withOcIds: true)
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let metadata = self.dataSource.getMetadata(indexPath: indexPath),
              metadata.classFile != NKTypeClassFile.url.rawValue,
              !isEditMode
        else {
            return nil
        }
        let identifier = indexPath as NSCopying
        var image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: global.previewExt1024, userId: metadata.userId, urlBase: metadata.urlBase)

        if image == nil {
            let cell = collectionView.cellForItem(at: indexPath)
            if cell is NCListCell {
                image = (cell as? NCListCell)?.imageItem.image
            } else if cell is NCGridCell {
                image = (cell as? NCGridCell)?.imageItem.image
            } else if cell is NCPhotoCell {
                image = (cell as? NCPhotoCell)?.imageItem.image
            }
        }

        return UIContextMenuConfiguration(identifier: identifier, previewProvider: {
            return nil
        }, actionProvider: { _ in
            let contextMenu = NCContextMenu(metadata: metadata.detachedCopy(), viewController: self, sceneIdentifier: self.sceneIdentifier, image: image)
            return contextMenu.viewMenu()
        })
    }

    func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        animator.addCompletion {
            if let indexPath = configuration.identifier as? IndexPath {
                self.collectionView(collectionView, didSelectItemAt: indexPath)
            }
        }
    }
}
