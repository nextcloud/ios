//
//  NCCollectionViewCommon+CollectionViewDelegate.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 02/07/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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
import UIKit
import NextcloudKit
import Alamofire

extension NCCollectionViewCommon: UICollectionViewDelegate {
    func didSelectMetadata(_ metadata: tableMetadata, withOcIds: Bool) {
        if metadata.e2eEncrypted {
            if NCCapabilities.shared.getCapabilities(account: metadata.account).capabilityE2EEEnabled {
                if !NCKeychain().isEndToEndEnabled(account: metadata.account) {
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

        if metadata.directory {
            pushMetadata(metadata)
        } else {
            let image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: self.global.previewExt1024)

            if !metadata.isDirectoryE2EE, metadata.isImage || metadata.isAudioOrVideo {
                let metadatas = self.dataSource.getMetadatas()
                let ocIds = metadatas.filter { $0.classFile == NKCommon.TypeClassFile.image.rawValue ||
                                               $0.classFile == NKCommon.TypeClassFile.video.rawValue ||
                                               $0.classFile == NKCommon.TypeClassFile.audio.rawValue }.map(\.ocId)

                return NCViewer().view(viewController: self, metadata: metadata, ocIds: withOcIds ? ocIds : nil, image: image)

            } else if metadata.isAvailableEditorView ||
                      utilityFileSystem.fileProviderStorageExists(metadata) ||
                        metadata.name == self.global.talkName {

                NCViewer().view(viewController: self, metadata: metadata, image: image)

            } else if NextcloudKit.shared.isNetworkReachable(),
                      let metadata = database.setMetadataSessionInWaitDownload(metadata: metadata,
                                                                               session: NCNetworking.shared.sessionDownload,
                                                                               selector: global.selectorLoadFileView,
                                                                               sceneIdentifier: self.controller?.sceneIdentifier,
                                                                               sync: false) {
                if metadata.name == "files" {
                    let hud = NCHud(self.tabBarController?.view)
                    var downloadRequest: DownloadRequest?

                    hud.initHudRing(text: NSLocalizedString("_downloading_", comment: ""), tapToCancelDetailText: true) {
                        if let request = downloadRequest {
                            request.cancel()
                        }
                    }

                    NCNetworking.shared.download(metadata: metadata) {
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
                } else if !metadata.url.isEmpty {
                    NCViewer().view(viewController: self, metadata: metadata, image: nil)
                }
            } else {
                let error = NKError(errorCode: global.errorOffline, errorDescription: "_go_online_")

                NCContentPresenter().showInfo(error: error)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.dataSource.getMetadata(indexPath: indexPath) { metadata in
            guard let metadata else {
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
                return
            }

            self.didSelectMetadata(metadata, withOcIds: true)
        }
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let metadata = self.dataSource.getMetadata(indexPath: indexPath),
              metadata.classFile != NKCommon.TypeClassFile.url.rawValue,
              !isEditMode
        else {
            return nil
        }
        let identifier = indexPath as NSCopying
        var image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: global.previewExt1024)

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
            return NCViewerProviderContextMenu(metadata: metadata, image: image, sceneIdentifier: self.sceneIdentifier)
        }, actionProvider: { _ in
            let contextMenu = NCContextMenu(metadata: tableMetadata(value: metadata), viewController: self, sceneIdentifier: self.sceneIdentifier, image: image)
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
