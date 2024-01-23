//
//  MediaCell.swift
//  Nextcloud
//
//  Created by Milen on 19.01.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import UIKit
import Queuer
import NextcloudKit

protocol MediaCellDelegate: AnyObject {
    func onImageLoaded(indexPath: IndexPath)
}

class MediaCell: UICollectionViewCell {
    private(set) var rowData = RowData()

    private var metadatas: [tableMetadata] = []
    private let cache = NCImageCache.shared

    private let queuer = NCNetworking.shared.downloadThumbnailQueue

    static let identifier = "MediaCell"
    var medatadata: tableMetadata?
    var image = UIImage()
    //    var shrinkRatio: CGFloat


    let rowWidth = UIScreen.main.bounds.width
    let spacing: CGFloat = 2

//    var newHeight: CGFloat = 0
//    var newWidth: CGFloat = 0
//    var shrinkRatio: CGFloat = 0

    weak var delegate: MediaCellDelegate?
//    var indexPath: IndexPath?

    //    var thumbnail: ScaledThumbnail

    //    @Published private(set) var rowData = RowData()
    //
    //    private var metadatas: [tableMetadata] = []
    //    private let cache = NCImageCache.shared
    //
    //    private let queuer = NCNetworking.shared.downloadThumbnailQueue

    // Add subviews and set up the cell
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        // Configure label...
        return label
    }()

    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        //        contentView.addSubview(titleLabel)
        //        contentView.backgroundColor = .systemBlue
        //        titleLabel.frame = contentView.bounds
        imageView.contentMode = .scaleToFill

        imageView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(imageView)

        imageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true
        imageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        imageView.heightAnchor.constraint(equalTo: contentView.heightAnchor).isActive = true
        imageView.widthAnchor.constraint(equalTo: contentView.widthAnchor).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    //    func configure(metadatas: [tableMetadata], index: Int, thumbnail: ScaledThumbnail) {
    func configure(metadata: tableMetadata, indexPath: IndexPath) {
//        self.indexPath = indexPath

        let thumbnailPath = NCUtilityFileSystem().getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)
        if let cachedImage = cache.getMediaImage(ocId: metadata.ocId, etag: metadata.etag) {
            //                    let thumbnail: ScaledThumbnail

            if case let .actual(image) = cachedImage {
                //                cellData.append(.init(indexPath: indexPath, ocId: metadata.ocId, imageHeight: image.size.height, imageWidth: image.size.width))
                //                cell?.configure(image: image)
                self.image = image
                imageView.image = image
                delegate?.onImageLoaded(indexPath: indexPath)
            } else {
                let image = UIImage(systemName: metadata.isVideo ? "video.fill" : "photo.fill")!.withRenderingMode(.alwaysTemplate)
                //                cellData.append(.init(indexPath: indexPath, ocId: metadata.ocId, isPlaceholderImage: true, imageHeight: image.size.height, imageWidth: image.size.width))
                //                cell?.configure(image: image)
                //                collectionView.reloadItems(at: [indexPath])
                self.image = image
                imageView.image = image
                delegate?.onImageLoaded(indexPath: indexPath)
            }

            DispatchQueue.main.async {
                //                    thumbnails.append(thumbnail)
                //                    self.calculateShrinkRatio(metadatas: self.metadatas, rowData: &rowData, thumbnails: &thumbnails, rowWidth: self.rowWidth, spacing: self.spacing)
                //                                            collectionView.collectionViewLayout.invalidateLayout()

            }
        } else if FileManager.default.fileExists(atPath: thumbnailPath) {
            // Load thumbnail from file
            if let image = UIImage(contentsOfFile: thumbnailPath) {
//                let thumbnail = ScaledThumbnail(image: image, metadata: metadata)
                cache.setMediaImage(ocId: metadata.ocId, etag: metadata.etag, image: .actual(image))

                self.image = image
                imageView.image = image
                delegate?.onImageLoaded(indexPath: indexPath)
                //                DispatchQueue.main.async {

                //                    self.cellData.append(.init(indexPath: indexPath, ocId: metadata.ocId, imageHeight: image.size.height, imageWidth: image.size.width))
                //                    cell?.configure(image: image)
                //                    collectionView.reloadItems(at: [indexPath])
                //                        thumbnails.append(thumbnail)
                //                        self.calculateShrinkRatio(metadatas: self.metadatas, rowData: &rowData, thumbnails: &thumbnails, rowWidth: self.rowWidth, spacing: self.spacing)
                //                            collectionView.collectionViewLayout.invalidateLayout()
                //                }
            }
        } else {
            if queuer.operations.filter({ ($0 as? NCMediaDownloadThumbnaill)?.metadata.ocId == metadata.ocId }).isEmpty {
                let concurrentOperation = NCMediaDownloadThumbnaill(metadata: metadata, cache: cache, rowWidth: rowWidth, spacing: spacing, maxWidth: UIScreen.main.bounds.width, maxHeight: UIScreen.main.bounds.height) { thumbnail in
                    //                    DispatchQueue.main.async {
                    //                        self.cellData.append(.init(indexPath: indexPath, ocId: metadata.ocId, imageHeight: thumbnail.image.size.height, imageWidth: thumbnail.image.size.width))
                    //                        cell?.configure(image: thumbnail.image)
                    //                        collectionView.reloadItems(at: [indexPath])

                    DispatchQueue.main.async {
                        self.image = thumbnail.image
                        self.imageView.image = thumbnail.image
                        self.delegate?.onImageLoaded(indexPath: indexPath)
                    }


                    //                            thumbnails.append(thumbnail)
                    //                            self.calculateShrinkRatio(metadatas: self.metadatas, rowData: &rowData, thumbnails: &thumbnails, rowWidth: self.rowWidth, spacing: self.spacing)
                    //                                collectionView.collectionViewLayout.invalidateLayout()
                    //                    }
                }

                queuer.addOperation(concurrentOperation)
            }
        }
    }

    class NCMediaDownloadThumbnaill: ConcurrentOperation {
        let metadata: tableMetadata
        let cache: NCImageCache
        let rowWidth: CGFloat
        let spacing: CGFloat
        let maxWidth: CGFloat
        let maxHeight: CGFloat

        let onThumbnailDownloaded: (ScaledThumbnail) -> Void

        init(metadata: tableMetadata, cache: NCImageCache, rowWidth: CGFloat, spacing: CGFloat, maxWidth: CGFloat, maxHeight: CGFloat, onThumbnailDownloaded: @escaping (ScaledThumbnail) -> Void) {
            self.metadata = metadata
            self.cache = cache
            self.rowWidth = rowWidth
            self.spacing = spacing
            self.maxWidth = maxWidth
            self.maxHeight = maxHeight
            self.onThumbnailDownloaded = onThumbnailDownloaded
        }

        override func start() {
            guard !isCancelled else { return self.finish() }

            let fileNamePath = NCUtilityFileSystem().getFileNamePath(metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId)
            let fileNamePreviewLocalPath = NCUtilityFileSystem().getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)
            let fileNameIconLocalPath = NCUtilityFileSystem().getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)

            var etagResource: String?
            if FileManager.default.fileExists(atPath: fileNameIconLocalPath) && FileManager.default.fileExists(atPath: fileNamePreviewLocalPath) {
                etagResource = metadata.etagResource
            }
            let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

            NextcloudKit.shared.downloadPreview(
                fileNamePathOrFileId: fileNamePath,
                fileNamePreviewLocalPath: fileNamePreviewLocalPath,
                widthPreview: Int(self.maxWidth) / 2,
                heightPreview: Int(self.maxHeight) / 2,
                fileNameIconLocalPath: fileNameIconLocalPath,
                sizeIcon: NCGlobal.shared.sizeIcon,
                etag: etagResource,
                options: options) { _, _, imageIcon, _, etag, error in
                    NCManageDatabase.shared.setMetadataEtagResource(ocId: self.metadata.ocId, etagResource: etag)

                    let thumbnail: ScaledThumbnail

                    if error == .success, let image = imageIcon {
                        thumbnail = ScaledThumbnail(image: image, metadata: self.metadata)
                        self.cache.setMediaImage(ocId: self.metadata.ocId, etag: self.metadata.etag, image: .actual(image))
                    } else {
                        let image = UIImage(systemName: self.metadata.isVideo ? "video.fill" : "photo.fill")!.withRenderingMode(.alwaysTemplate)
                        thumbnail = ScaledThumbnail(image: image, isPlaceholderImage: true, metadata: self.metadata)
                        self.cache.setMediaImage(ocId: self.metadata.ocId, etag: self.metadata.etag, image: .placeholder)
                    }

                    self.onThumbnailDownloaded(thumbnail)

                    self.finish()
                }
        }
    }
}
