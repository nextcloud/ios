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
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath), !metadata.isInvalidated else { return }

        if isEditMode {
            if let index = selectOcId.firstIndex(of: metadata.ocId) {
                selectOcId.remove(at: index)
            } else {
                selectOcId.append(metadata.ocId)
            }
            collectionView.reloadItems(at: [indexPath])
            tabBarSelect.update(selectOcId: selectOcId, metadatas: getSelectedMetadatas(), userId: appDelegate.userId)
            return
        }

        if metadata.e2eEncrypted {
            if NCGlobal.shared.capabilityE2EEEnabled {
                if !NCKeychain().isEndToEndEnabled(account: appDelegate.account) {
                    let e2ee = NCEndToEndInitialize()
                    e2ee.delegate = self
                    e2ee.initEndToEndEncryption(viewController: self.tabBarController, metadata: metadata)
                    return
                }
            } else {
                NCContentPresenter().showInfo(error: NKError(errorCode: NCGlobal.shared.errorE2EENotEnabled, errorDescription: "_e2e_server_disabled_"))
                return
            }
        }

        if metadata.directory {
            pushMetadata(metadata)
        } else {
            let imageIcon = UIImage(contentsOfFile: utilityFileSystem.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
            if !metadata.isDirectoryE2EE && (metadata.isImage || metadata.isAudioOrVideo) {
                var metadatas: [tableMetadata] = []
                for metadata in dataSource.getMetadataSourceForAllSections() {
                    if metadata.isImage || metadata.isAudioOrVideo {
                        metadatas.append(metadata)
                    }
                }
                return NCViewer().view(viewController: self, metadata: metadata, metadatas: metadatas, imageIcon: imageIcon)
            } else if metadata.isAvailableEditorView || utilityFileSystem.fileProviderStorageExists(metadata) {
                NCViewer().view(viewController: self, metadata: metadata, metadatas: [metadata], imageIcon: imageIcon)
            } else if NextcloudKit.shared.isNetworkReachable(),
                      let metadata = NCManageDatabase.shared.setMetadatasSessionInWaitDownload(metadatas: [metadata],
                                                                                               session: NextcloudKit.shared.nkCommonInstance.sessionIdentifierDownload,
                                                                                               selector: NCGlobal.shared.selectorLoadFileView,
                                                                                               sceneIdentifier: (self.tabBarController as? NCMainTabBarController)?.sceneIdentifier) {
                NCNetworking.shared.download(metadata: metadata, withNotificationProgressTask: true)
            } else {
                let error = NKError(errorCode: NCGlobal.shared.errorOffline, errorDescription: "_go_online_")
                NCContentPresenter().showInfo(error: error)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let metadata = dataSource.cellForItemAt(indexPath: indexPath) else { return nil }
        if isEditMode || metadata.classFile == NKCommon.TypeClassFile.url.rawValue { return nil }
        let identifier = indexPath as NSCopying
        var image: UIImage?
        let cell = collectionView.cellForItem(at: indexPath)

        if cell is NCListCell {
            image = (cell as? NCListCell)?.imageItem.image
        } else if cell is NCGridCell {
            image = (cell as? NCGridCell)?.imageItem.image
        } else if cell is NCPhotoCell {
            image = (cell as? NCPhotoCell)?.imageItem.image
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
