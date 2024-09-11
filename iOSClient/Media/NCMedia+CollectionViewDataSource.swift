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
            if self.hasRun || imageCache.createCacheInProgress {
                header.emptyTitle.text = NSLocalizedString("_search_in_progress_", comment: "")
            } else {
                header.emptyTitle.text = NSLocalizedString("_tutorial_photo_view_", comment: "")
            }
            header.emptyDescription.text = ""
            return header
        }
        return UICollectionReusableView()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let numberOfItemsInSection = dataSource.getMetadatas().count
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
        self.columnPhoto = getColumnCount()
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
            for case let operation as NCOperationConvertLivePhoto in NCNetworking.shared.convertLivePhotoQueue.operations where operation.ocId == metadata.ocId {
                operation.cancel()
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = (collectionView.dequeueReusableCell(withReuseIdentifier: "gridCell", for: indexPath) as? NCGridMediaCell)!
        guard let metadata = dataSource.getMetadata(indexPath: indexPath) else {
            return cell
        }

        cell.date = metadata.date as Date
        cell.ocId = metadata.ocId
        cell.account = metadata.account

        if let image = getImage(metadata: metadata) {
            cell.imageItem.image = image
        } else {
            cell.imageItem.image = nil
        }

        // Convert OLD Live Photo
        if NCCapabilities.shared.getCapabilities(account: metadata.account).isLivePhotoServerAvailable, metadata.isLivePhoto, metadata.isNotFlaggedAsLivePhotoByServer,
           let metadata = database.getMetadataFromOcId(metadata.ocId) {
            NCNetworking.shared.convertLivePhoto(metadata: metadata)
        }

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
