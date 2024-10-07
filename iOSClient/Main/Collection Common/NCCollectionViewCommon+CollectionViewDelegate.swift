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

extension NCCollectionViewCommon: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let metadata = self.dataSource.getMetadata(indexPath: indexPath),
              !metadata.isInvalidated,
              (metadata.name == global.appName || metadata.name == NCGlobal.shared.talkName)
        else { return }

        if isEditMode {
            if let index = fileSelect.firstIndex(of: metadata.ocId) {
                fileSelect.remove(at: index)
            } else {
                fileSelect.append(metadata.ocId)
            }
            collectionView.reloadItems(at: [indexPath])
            tabBarSelect.update(fileSelect: fileSelect, metadatas: getSelectedMetadatas(), userId: metadata.userId)
            return
        }

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
            let image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal.shared.previewExt1024)
            if !metadata.isDirectoryE2EE, (metadata.isImage || metadata.isAudioOrVideo) {
                let metadatas = self.dataSource.getMetadatas()
                let ocIds = metadatas.filter { $0.classFile == NKCommon.TypeClassFile.image.rawValue ||
                                               $0.classFile == NKCommon.TypeClassFile.video.rawValue ||
                                               $0.classFile == NKCommon.TypeClassFile.audio.rawValue }.map(\.ocId)

                return NCViewer().view(viewController: self, metadata: metadata, ocIds: ocIds, image: image)

            } else if metadata.isAvailableEditorView ||
                      utilityFileSystem.fileProviderStorageExists(metadata) ||
                      metadata.name == NCGlobal.shared.talkName {

                NCViewer().view(viewController: self, metadata: metadata, image: image)

            } else if NextcloudKit.shared.isNetworkReachable(),
                      let metadata = database.setMetadatasSessionInWaitDownload(metadatas: [metadata],
                                                                                               session: NCNetworking.shared.sessionDownload,
                                                                                               selector: global.selectorLoadFileView,
                                                                                               sceneIdentifier: self.controller?.sceneIdentifier) {

                NCNetworking.shared.download(metadata: metadata, withNotificationProgressTask: true)
            } else {
                let error = NKError(errorCode: global.errorOffline, errorDescription: "_go_online_")

                NCContentPresenter().showInfo(error: error)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let metadata = self.dataSource.getMetadata(indexPath: indexPath) else { return nil }
        if isEditMode || metadata.classFile == NKCommon.TypeClassFile.url.rawValue { return nil }
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
            return NCViewerProviderContextMenu(metadata: metadata, image: image)
        }, actionProvider: { _ in
            return NCContextMenu().viewMenu(ocId: metadata.ocId, viewController: self, image: image)
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
