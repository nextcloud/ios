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
            if self.hasRunSearchMedia {
                header.emptyTitle.text = NSLocalizedString("_search_in_progress_", comment: "")
            } else {
                header.emptyTitle.text = NSLocalizedString("_tutorial_photo_view_", comment: "")
            }
            header.emptyDescription.text = ""
            return header
        } else {
            guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionFooter", for: indexPath) as? NCSectionFooter else { return NCSectionFooter() }
            let images = dataSource.getMetadatas().filter({ $0.isImage }).count
            let video = dataSource.getMetadatas().count - images

            footer.setTitleLabel("\(images) " + NSLocalizedString("_images_", comment: "") + " • " + "\(video) " + NSLocalizedString("_video_", comment: ""))
            footer.separatorIsHidden(true)
            return footer
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let numberOfItemsInSection = dataSource.getMetadatas().count
        self.numberOfColumns = getColumnCount()

        if numberOfItemsInSection == 0 || NCNetworking.shared.isOffline {
            selectOrCancelButton.isHidden = true
            menuButton.isHidden = false
            gradientView.alpha = 0
            activityIndicatorTrailing.constant = 50
        } else if isEditMode {
            selectOrCancelButton.isHidden = false
            menuButton.isHidden = true
            activityIndicatorTrailing.constant = 150
        } else {
            selectOrCancelButton.isHidden = false
            menuButton.isHidden = false
            activityIndicatorTrailing.constant = 150
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.setTitleDate()
        }
        return numberOfItemsInSection
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let metadata = dataSource.getMetadata(indexPath: indexPath) else { return }

        if !hiddenCellMetadats.contains(metadata.ocId + metadata.etag) {
            hiddenCellMetadats.append(metadata.ocId + metadata.etag)
        }

        if !collectionView.indexPathsForVisibleItems.contains(indexPath) {
            for case let operation as NCMediaDownloadThumbnail in NCNetworking.shared.downloadThumbnailQueue.operations where operation.metadata.ocId == metadata.ocId {
                operation.cancel()
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let metadata = dataSource.getMetadata(indexPath: indexPath),
              let cell = (cell as? NCGridMediaCell) else { return }
        let width = self.collectionView.frame.size.width / CGFloat(self.numberOfColumns)
        let ext = NCGlobal.shared.getSizeExtension(width: width)
        let imageCache = imageCache.getImageCache(ocId: metadata.ocId, etag: metadata.etag, ext: ext)
        let cost = indexPath.row

        cell.imageItem.image = imageCache

        if imageCache == nil {
            if self.transitionColumns {
                cell.imageItem.image = getImage(metadata: metadata, width: width, cost: cost)
            } else {
                DispatchQueue.global(qos: .userInteractive).async {
                    let image = self.getImage(metadata: metadata, width: width, cost: cost)
                    DispatchQueue.main.async {
                        cell.imageItem.image = image
                    }
                }
            }
        } else {
            print("[DEBUG] in cache, cost \(indexPath.row)")
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = (collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as? NCGridMediaCell)!
        guard let metadata = dataSource.getMetadata(indexPath: indexPath) else {
            return cell
        }

        cell.date = metadata.date as Date
        cell.ocId = metadata.ocId

        if metadata.isVideo {
           cell.imageStatus.image = playImage
        } else if metadata.isLivePhoto {
            cell.imageStatus.image = livePhotoImage
        } else {
            cell.imageStatus.image = nil
        }

        if isEditMode, selectOcId.contains(metadata.ocId) {
            cell.selected(true)
        } else {
            cell.selected(false)
        }

        return cell
    }
}
