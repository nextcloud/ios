// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

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
            let images = dataSource.compactMetadatas.filter({ $0.isImage }).count
            let video = dataSource.compactMetadatas.count - images

            footer.setTitleLabel("\(images) " + NSLocalizedString("_images_", comment: "") + " • " + "\(video) " + NSLocalizedString("_video_", comment: ""))
            return footer
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let numberOfItemsInSection = dataSource.compactMetadatas.count
        self.numberOfColumns = getColumnCount()
        return numberOfItemsInSection
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let compactMetadata = dataSource.getcompactMetadata(indexPath: indexPath) else { return }

        if !collectionView.indexPathsForVisibleItems.contains(indexPath) {
            for case let operation as NCMediaDownloadThumbnail in networking.downloadThumbnailQueue.operations where operation.compactMetadata.ocId == compactMetadata.ocId {
                operation.cancel()
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let compactMetadata = dataSource.getcompactMetadata(indexPath: indexPath) else { return }
        if !utilityFileSystem.fileProviderStorageImageExists(compactMetadata.ocId, etag: compactMetadata.etag, userId: self.session.userId, urlBase: self.session.urlBase),
           NCNetworking.shared.downloadThumbnailQueue.operations.filter({ ($0 as? NCMediaDownloadThumbnail)?.compactMetadata.ocId == compactMetadata.ocId }).isEmpty {
            NCNetworking.shared.downloadThumbnailQueue.addOperation(NCMediaDownloadThumbnail(compactMetadata: compactMetadata, media: self))
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = (collectionView.dequeueReusableCell(withReuseIdentifier: "mediaCell", for: indexPath) as? NCMediaCell) else {
            fatalError("Unable to dequeue MediaCell with identifier mediaCell")
        }
        guard let compactMetadata = dataSource.getcompactMetadata(indexPath: indexPath) else { return cell }

        let ext = global.getSizeExtension(column: self.numberOfColumns)
        let imageCache = imageCache.getImageCache(ocId: compactMetadata.ocId, etag: compactMetadata.etag, ext: ext)

        cell.imageItem.image = imageCache
        cell.date = compactMetadata.date
        cell.ocId = compactMetadata.ocId
        cell.imageStatus.image = nil

        if cell.imageItem.frame.width > 60 {
            if compactMetadata.isVideo {
                cell.imageStatus.image = playImage
            } else if compactMetadata.isLivePhoto {
                cell.imageStatus.image = livePhotoImage
            }
        }

        if isEditMode, fileSelect.contains(compactMetadata.ocId) {
            cell.selected(true, color: NCBrandColor.shared.getElement(account: session.account))
        } else {
            cell.selected(false, color: NCBrandColor.shared.getElement(account: session.account))
        }

        if cell.imageItem.image == nil {
            if isPinchGestureActive || ext == global.previewExt512 || ext == global.previewExt1024 {
                cell.imageItem.image = utility.getImage(ocId: compactMetadata.ocId, etag: compactMetadata.etag, ext: ext, userId: self.session.userId, urlBase: self.session.urlBase)
            } else {
                let session = self.session
                DispatchQueue.global(qos: .userInteractive).async {
                    let image = self.utility.getImage(ocId: compactMetadata.ocId, etag: compactMetadata.etag, ext: ext, userId: session.userId, urlBase: session.urlBase)
                    DispatchQueue.main.async {
                        if let currentCell = collectionView.cellForItem(at: indexPath) as? NCMediaCell,
                           currentCell.ocId == compactMetadata.ocId, let image {
                            self.imageCache.addImageCache(ocId: compactMetadata.ocId, etag: compactMetadata.etag, image: image, ext: ext, cost: indexPath.row)
                            currentCell.imageItem.image = image
                        }
                    }
                }
            }
        }

        return cell
    }
}
