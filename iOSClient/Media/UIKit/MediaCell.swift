//
//  MediaCell.swift
//  Nextcloud
//
//  Created by Milen on 19.01.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation

//struct RowData {
//    var scaledThumbnails: [ScaledThumbnail] = []
//    var shrinkRatio: CGFloat = 0
//}
//
//struct ScaledThumbnail: Hashable {
//    let image: UIImage
//    var isPlaceholderImage = false
//    var scaledSize: CGSize = .zero
//    let metadata: tableMetadata
//
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(metadata.ocId)
//    }
//}

class MediaCell: UICollectionViewCell {
    static let identifier = "MediaCell"
    var medatadata: tableMetadata?
    var image = UIImage()

    @Published private(set) var rowData = RowData()

    private var metadatas: [tableMetadata] = []
    private let cache = NCImageCache.shared

    private let queuer = NCNetworking.shared.downloadThumbnailQueue

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

    func configure(metadata: tableMetadata, thumbnail: ScaledThumbnail) {
        self.medatadata = metadata
        self.imageView.image = thumbnail.image
//        titleLabel.text = metadata.name
//    }
        let thumbnailPath = NCUtilityFileSystem().getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)
        if let cachedImage = cache.getMediaImage(ocId: metadata.ocId, etag: metadata.etag) {
            let thumbnail: ScaledThumbnail

            if case let .actual(image) = cachedImage {
                thumbnail = ScaledThumbnail(image: image, metadata: metadata)
            } else {
                let image = UIImage(systemName: metadata.isVideo ? "video.fill" : "photo.fill")!.withRenderingMode(.alwaysTemplate)
                thumbnail = ScaledThumbnail(image: image, isPlaceholderImage: true, metadata: metadata)
            }

            DispatchQueue.main.async {
//                thumbnails.append(thumbnail)
                self.calculateShrinkRatio(metadatas: self.metadatas, rowData: &self.rowData, thumbnails: &thumbnails, rowWidth: rowWidth, spacing: spacing)
            }
        } else if FileManager.default.fileExists(atPath: thumbnailPath) {
            // Load thumbnail from file
            if let image = UIImage(contentsOfFile: thumbnailPath) {
                let thumbnail = ScaledThumbnail(image: image, metadata: metadata)
                cache.setMediaImage(ocId: metadata.ocId, etag: metadata.etag, image: .actual(image))

                DispatchQueue.main.async {
                    thumbnails.append(thumbnail)
                    self.calculateShrinkRatio(metadatas: self.metadatas, rowData: &self.rowData, thumbnails: &thumbnails, rowWidth: rowWidth, spacing: spacing)
                }
            }
        } else {
            if queuer.operations.filter({ ($0 as? NCMediaDownloadThumbnaill)?.metadata.ocId == metadata.ocId }).isEmpty {
                let concurrentOperation = NCMediaDownloadThumbnaill(metadata: metadata, cache: cache, rowWidth: rowWidth, spacing: spacing, maxWidth: UIScreen.main.bounds.width, maxHeight: UIScreen.main.bounds.height) { thumbnail in
                    DispatchQueue.main.async {
                        thumbnails.append(thumbnail)
                        self.calculateShrinkRatio(metadatas: self.metadatas, rowData: &self.rowData, thumbnails: &thumbnails, rowWidth: rowWidth, spacing: spacing)
                    }
                }

                queuer.addOperation(concurrentOperation)
            }
        }
    }

    private func calculateShrinkRatio(metadata: tableMetadata, rowData: inout RowData, thumbnails: inout ScaledThumbnail, rowWidth: CGFloat, spacing: CGFloat) {
//        if thumbnails.count == metadatas.count {
//            thumbnails.enumerated().forEach { index, thumbnail in
                thumbnail.scaledSize = getScaledThumbnailSize(of: thumbnail, thumbnailsInRow: thumbnails)
//            }

            let shrinkRatio = getShrinkRatio(thumbnailsInRow: thumbnails, fullWidth: rowWidth, spacing: spacing)

            rowData.scaledThumbnails = thumbnails
            rowData.shrinkRatio = shrinkRatio
        }
    }
}
