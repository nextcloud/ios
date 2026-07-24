// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit
import RealmSwift

extension NCMedia: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == mediaSectionHeader {
            if dataSource.isEmpty() {
                guard let header = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    withReuseIdentifier: "sectionFirstHeaderEmptyData",
                    for: indexPath
                ) as? NCSectionFirstHeaderEmptyData else {
                    return NCSectionFirstHeaderEmptyData()
                }

                header.emptyImage.isHidden = false
                header.emptyDescription.isHidden = false

                header.emptyImage.image = utility.loadImage(
                    named: "photo",
                    colors: [
                        NCBrandColor.shared.getElement(
                            account: session.account
                        )
                    ]
                )

                if searchMediaInProgress {
                    header.emptyTitle.text = NSLocalizedString(
                        "_search_in_progress_",
                        comment: ""
                    )
                } else {
                    header.emptyTitle.text = NSLocalizedString(
                        "_tutorial_photo_view_",
                        comment: ""
                    )
                }

                header.emptyDescription.text = ""

                return header
            }

            guard let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: "sectionHeader",
                for: indexPath
            ) as? NCMediaSectionHeader else {
                return NCMediaSectionHeader()
            }

            guard let yearMonth = dataSource.yearMonth(for: indexPath.section) else {
                header.titleLabel.text = nil
                return header
            }

            var components = DateComponents()
            components.year = yearMonth.year
            components.month = yearMonth.month
            components.day = 1

            if let date = Calendar.current.date(from: components) {
                header.titleLabel.text = date.formatted(
                    .dateTime
                        .month(.wide)
                        .year()
                )
            } else {
                header.titleLabel.text = "\(yearMonth.month)/\(yearMonth.year)"
            }

            return header
        }

        guard let footer = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: "sectionFooter",
            for: indexPath
        ) as? NCSectionFooter else {
            return NCSectionFooter()
        }

        guard indexPath.section == dataSource.numberOfSections - 1 else {
            footer.setTitleLabel("")
            return footer
        }

        let images = dataSource.compactMetadatas.filter(\.isImage).count
        let videos = dataSource.compactMetadatas.count - images

        footer.setTitleLabel(
            "\(images) "
            + NSLocalizedString("_images_", comment: "")
            + " • "
            + "\(videos) "
            + NSLocalizedString("_video_", comment: "")
        )

        return footer
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard !dataSource.isEmpty() else {
            return 0
        }
        return dataSource.numberOfItems(in: section)
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        dataSource.isEmpty() ? 1 : dataSource.numberOfSections
    }

    func collectionView(_ collectionView: UICollectionView,
                        didEndDisplaying cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        guard let cell = cell as? NCMediaCell else {
            return
        }

        Task {
            await NCTransferCoordinator.shared.cancel(identifier: cell.identifier)
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
            ) {
                guard var metadata = await NCManageDatabase.shared.getMetadataFromOcIdAsync(ocId) else {
                    return
                }

                if metadata.placeholder {
                    let result = await self.networking.readFileAsync(
                        serverUrlFileName: metadata.serverUrlFileName,
                        account: metadata.account
                    )

                    guard !Task.isCancelled,
                          result.error == .success,
                          let hydratedMetadata = result.metadata else {
                        return
                    }

                    await self.database.addMetadataAsync(hydratedMetadata)
                    metadata = hydratedMetadata
                }

                let iconName = metadata.iconName
                let account = metadata.account

                let result = await NextcloudKit.shared.downloadPreviewAsync(
                    fileId: metadata.fileId,
                    etag: metadata.etag,
                    account: metadata.account
                )

                guard !Task.isCancelled,
                      result.error == .success,
                      let data = result.responseData?.data else {
                    return
                }

                let image = NCUtility().createImageFileFrom(
                    data: data,
                    metadata: metadata,
                    ext: ext)

                await MainActor.run {
                    guard let visibleIndexPath = self.collectionView.indexPathsForVisibleItems.first(where: {
                        self.dataSource.getCompactMetadata(indexPath: $0)?.ocId == ocId
                    }),
                    let cell = self.collectionView.cellForItem(at: visibleIndexPath) as? NCMediaCell, cell.identifier == ocId else {
                        return
                    }

                    if let image {
                        cell.image.contentMode = .scaleAspectFill

                        UIView.transition(
                            with: cell.image,
                            duration: 0.75,
                            options: .transitionCrossDissolve
                        ) {
                            cell.image.image = image
                        }
                    } else {
                        cell.image.contentMode = .scaleAspectFit
                        cell.image.image = NCUtility().loadImage(
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

        cell.image.image = imageCache
        cell.date = compactMetadata.date
        cell.identifier = compactMetadata.ocId
        cell.imageStatus.image = nil

        if cell.image.frame.width > 60 {
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

        if cell.image.image == nil {
            let session = self.session

            DispatchQueue.global(qos: .userInteractive).async {
                let image = self.utility.getImage(
                    ocId: compactMetadata.ocId,
                    etag: compactMetadata.etag,
                    ext: ext,
                    userId: session.userId,
                    urlBase: session.urlBase
                )

                DispatchQueue.main.async {
                    guard let currentCell = collectionView.cellForItem(at: indexPath) as? NCMediaCell,
                          currentCell.identifier == compactMetadata.ocId,
                          let image else {
                        return
                    }

                    self.imageCache.addImageCache(
                        ocId: compactMetadata.ocId,
                        etag: compactMetadata.etag,
                        image: image,
                        ext: ext
                    )

                    currentCell.image.image = image
                }
            }
        }

        return cell
    }
}
