//
//  NCMedia+CollectionViewDataSource.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 16/07/24.
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

import UIKit
import NextcloudKit
import RealmSwift

extension NCMedia: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == mediaSectionHeader {
            guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFirstHeaderEmptyData", for: indexPath) as? NCSectionFirstHeaderEmptyData else { return NCSectionFirstHeaderEmptyData() }
            header.emptyImage.image = utility.loadImage(named: "photo", colors: [NCBrandColor.shared.getElement(account: session.account)])
            if self.searchMediaInProgress {
                header.emptyTitle.text = NSLocalizedString("_search_in_progress_", comment: "")
            } else {
                header.emptyTitle.text = NSLocalizedString("_tutorial_photo_view_", comment: "")
            }
            header.emptyDescription.text = ""
            return header
        } else {
            guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as? NCSectionFooter else { return NCSectionFooter() }
            let images = dataSource.metadatas.filter({ $0.isImage }).count
            let video = dataSource.metadatas.count - images

            footer.setTitleLabel("\(images) " + NSLocalizedString("_images_", comment: "") + " • " + "\(video) " + NSLocalizedString("_video_", comment: ""))
            footer.separatorIsHidden(true)
            return footer
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let numberOfItemsInSection = dataSource.metadatas.count
        let assistantEnabled = NCCapabilities.shared.getCapabilities(account: session.account).capabilityAssistantEnabled
        if assistantEnabled {
            assistantButton.isHidden = false
        } else {
            assistantButton.isHidden = true
        }

        self.numberOfColumns = getColumnCount()

        if numberOfItemsInSection == 0 || NCNetworking.shared.isOffline {
            selectOrCancelButton.isHidden = true
            menuButton.isHidden = false
            gradientView.alpha = 0
        } else if isEditMode {
            selectOrCancelButton.isHidden = false
        } else {
            selectOrCancelButton.isHidden = false
            menuButton.isHidden = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.setTitleDate()
        }
        return numberOfItemsInSection
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let metadata = dataSource.getMetadata(indexPath: indexPath) else { return }

        if !collectionView.indexPathsForVisibleItems.contains(indexPath) {
            for case let operation as NCMediaDownloadThumbnail in NCNetworking.shared.downloadThumbnailQueue.operations where operation.metadata.ocId == metadata.ocId {
                operation.cancel()
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let metadata = dataSource.getMetadata(indexPath: indexPath) else { return }

        if !utilityFileSystem.fileProviderStorageImageExists(metadata.ocId, etag: metadata.etag),
           NCNetworking.shared.downloadThumbnailQueue.operations.filter({ ($0 as? NCMediaDownloadThumbnail)?.metadata.ocId == metadata.ocId }).isEmpty {
            NCNetworking.shared.downloadThumbnailQueue.addOperation(NCMediaDownloadThumbnail(metadata: metadata, media: self))
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = (collectionView.dequeueReusableCell(withReuseIdentifier: "mediaCell", for: indexPath) as? NCMediaCell) else {
            fatalError("Unable to dequeue MediaCell with identifier mediaCell")
        }
        guard let metadata = dataSource.getMetadata(indexPath: indexPath) else { return cell }

        let ext = global.getSizeExtension(column: self.numberOfColumns)
        let imageCache = imageCache.getImageCache(ocId: metadata.ocId, etag: metadata.etag, ext: ext)

        cell.imageItem.image = imageCache
        cell.datePhotosOriginal = metadata.datePhotosOriginal as Date
        cell.ocId = metadata.ocId
        cell.imageStatus.image = nil

        if cell.imageItem.frame.width > 60 {
            if metadata.isVideo {
                cell.imageStatus.image = playImage
            } else if metadata.isLivePhoto {
                cell.imageStatus.image = livePhotoImage
            }
        }

        if isEditMode, fileSelect.contains(metadata.ocId) {
            cell.selected(true)
        } else {
            cell.selected(false)
        }

        if cell.imageItem.image == nil {
            if isPinchGestureActive || ext == global.previewExt512 || ext == global.previewExt1024 {
                cell.imageItem.image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: ext)
            } else {
                DispatchQueue.global(qos: .userInteractive).async {
                    let image = self.utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: ext)
                    DispatchQueue.main.async {
                        if let currentCell = collectionView.cellForItem(at: indexPath) as? NCMediaCell,
                           currentCell.ocId == metadata.ocId, let image {
                            self.imageCache.addImageCache(ocId: metadata.ocId, etag: metadata.etag, image: image, ext: ext, cost: indexPath.row)
                            currentCell.imageItem.image = image
                        }
                    }
                }
            }
        }

        return cell
    }
}
