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

    func collectionView(_ collectionView: UICollectionView,
                        didEndDisplaying cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        guard let compactMetadata = dataSource.getCompactMetadata(indexPath: indexPath) else {
            return
        }

        Task {
            await NCTransferCoordinator.shared.cancel(identifier: compactMetadata.ocId)
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        willDisplay cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        guard let compactMetadata = dataSource.getCompactMetadata(indexPath: indexPath) else {
            return
        }
        let ocId = compactMetadata.ocId
        let ext = NCGlobal.shared.getSizeExtension(column: self.numberOfColumns)
        let imageExists = self.utilityFileSystem.fileProviderStorageImageExists(ocId, etag: compactMetadata.etag, userId: self.session.userId, urlBase: self.session.urlBase)

        guard !imageExists else {
            return
        }

        Task {
            await NCTransferCoordinator.shared.start(
                identifier: ocId,
                priority: .visible
            ) { [weak self] in
                guard let self,
                      let metadata = await NCManageDatabase.shared.getMetadataFromOcIdAsync(ocId) else {
                    return
                }
                let iconName = metadata.iconName
                let account = metadata.account

                let result = await NextcloudKit.shared.downloadPreviewAsync(
                    fileId: metadata.fileId,
                    etag: metadata.etag,
                    account: account,
                    options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
                )

                guard !Task.isCancelled,
                      result.error == .success,
                      let data = result.responseData?.data else {
                    return
                }

                NCUtility().createImageFileFrom(data: data, metadata: metadata)

                let image = NCUtility().getImage(
                    ocId: metadata.ocId,
                    etag: metadata.etag,
                    ext: ext,
                    userId: metadata.userId,
                    urlBase: metadata.urlBase
                )

                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    guard let visibleIndexPath = self.collectionView.indexPathsForVisibleItems.first(where: {
                        self.dataSource.getCompactMetadata(indexPath: $0)?.ocId == ocId
                    }),
                    let cell = self.collectionView.cellForItem(at: visibleIndexPath) as? NCMediaCell, cell.ocId == ocId else {
                        return
                    }

                    if let image {
                        cell.imageItem.contentMode = .scaleAspectFill

                        UIView.transition(
                            with: cell.imageItem,
                            duration: 0.75,
                            options: .transitionCrossDissolve
                        ) {
                            cell.imageItem.image = image
                        }
                    } else {
                        cell.imageItem.contentMode = .scaleAspectFit
                        cell.imageItem.image = NCUtility().loadImage(
                            named: iconName,
                            useTypeIconFile: true,
                            account: account
                        )
                    }
                }
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = (collectionView.dequeueReusableCell(withReuseIdentifier: "mediaCell", for: indexPath) as? NCMediaCell) else {
            fatalError("Unable to dequeue MediaCell with identifier mediaCell")
        }
        guard let compactMetadata = dataSource.getCompactMetadata(indexPath: indexPath) else { return cell }

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
