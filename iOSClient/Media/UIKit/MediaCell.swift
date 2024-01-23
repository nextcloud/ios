//
//  MediaCell.swift
//  Nextcloud
//
//  Created by Milen on 19.01.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import UIKit
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
    func configure(image: UIImage) {


//                self.medatadata = metadata
                self.imageView.image = image
//        self.shrinkRatio = shrinkRatio
//        self.thumbnail = thumbnail
//                titleLabel.text = metadata.name

        var thumbnails: [ScaledThumbnail] = []

            }
//        for metadata in metadatas {
//            let thumbnailPath = NCUtilityFileSystem().getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)
//            if let cachedImage = cache.getMediaImage(ocId: metadata.ocId, etag: metadata.etag) {
//                let thumbnail: ScaledThumbnail
//
//                if case let .actual(image) = cachedImage {
//                    thumbnail = ScaledThumbnail(image: image, metadata: metadata)
//                } else {
//                    let image = UIImage(systemName: metadata.isVideo ? "video.fill" : "photo.fill")!.withRenderingMode(.alwaysTemplate)
//                    thumbnail = ScaledThumbnail(image: image, isPlaceholderImage: true, metadata: metadata)
//                }
//
//                DispatchQueue.main.async {
//                    thumbnails.append(thumbnail)
//                    self.calculateShrinkRatio(metadatas: metadatas, rowData: &self.rowData, thumbnails: &thumbnails, rowWidth: self.rowWidth, spacing: self.spacing)
//
//                    self.imageView.image = thumbnails.
//                    //                        collectionView.collectionViewLayout.invalidateLayout()
//
//                }
//            } else if FileManager.default.fileExists(atPath: thumbnailPath) {
//                // Load thumbnail from file
//                if let image = UIImage(contentsOfFile: thumbnailPath) {
//                    let thumbnail = ScaledThumbnail(image: image, metadata: metadata)
//                    cache.setMediaImage(ocId: metadata.ocId, etag: metadata.etag, image: .actual(image))
//
//                    DispatchQueue.main.async {
//                        thumbnails.append(thumbnail)
//                        self.calculateShrinkRatio(metadatas: self.metadatas, rowData: &self.rowData, thumbnails: &thumbnails, rowWidth: self.rowWidth, spacing: self.spacing)
//                        self.imageView.image = thumbnails[index].image
//                        //                                                collectionView.collectionViewLayout.invalidateLayout()
//                    }
//                }
//            } else {
//                if queuer.operations.filter({ ($0 as? NCMediaDownloadThumbnaill)?.metadata.ocId == metadata.ocId }).isEmpty {
//                    let concurrentOperation = NCMediaDownloadThumbnaill(metadata: metadata, cache: cache, rowWidth: rowWidth, spacing: spacing, maxWidth: UIScreen.main.bounds.width, maxHeight: UIScreen.main.bounds.height) { thumbnail in
//                        DispatchQueue.main.async {
//                            thumbnails.append(thumbnail)
//                            self.calculateShrinkRatio(metadatas: self.metadatas, rowData: &self.rowData, thumbnails: &thumbnails, rowWidth: self.rowWidth, spacing: self.spacing)
//                            self.imageView.image = thumbnails[index].image
//                            //                                collectionView.collectionViewLayout.invalidateLayout()
//                        }
//                    }
//
//                    queuer.addOperation(concurrentOperation)
//                }
//            }
//
//            //            print("TEST")
//            //            print(thumbnails.count)
//            //            if thumbnails.count == 3 {
//            //                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MediaCell.identifier, for: indexPath) as? MediaCell
//            //                let metadata = metadatas[indexPath.row]
//            //                cell?.backgroundColor = .black
//            //                return cell!
//            //            }
//            //
//            //            cell?.backgroundColor = UIColor(hue: CGFloat(drand48()), saturation: 1, brightness: 1, alpha: 1)
//            //            return cell!
//        }
    }

//    private func calculateShrinkRatio(metadatas: [tableMetadata], rowData: inout RowData, thumbnails: inout [ScaledThumbnail], rowWidth: CGFloat, spacing: CGFloat) {
//        if thumbnails.count == metadatas.count {
//            thumbnails.enumerated().forEach { index, thumbnail in
//                thumbnails[index].scaledSize = getScaledThumbnailSize(of: thumbnail, thumbnailsInRow: thumbnails)
//            }
//
//            let shrinkRatio = getShrinkRatio(thumbnailsInRow: thumbnails, fullWidth: rowWidth, spacing: spacing)
//
//            rowData.scaledThumbnails = thumbnails
//            rowData.shrinkRatio = shrinkRatio
//        }
//    }

//    private func getScaledThumbnailSize(of thumbnail: ScaledThumbnail, thumbnailsInRow thumbnails: [ScaledThumbnail]) -> CGSize {
//        let maxHeight = thumbnails.compactMap { CGFloat($0.image.size.height) }.max() ?? 0
//
//        let height = thumbnail.image.size.height
//        let width = thumbnail.image.size.width
//
//        let scaleFactor = maxHeight / height
//        let newHeight = height * scaleFactor
//        let newWidth = width * scaleFactor
//
//        return .init(width: newWidth, height: newHeight)
//    }
//
//    private func getShrinkRatio(thumbnailsInRow thumbnails: [ScaledThumbnail], fullWidth: CGFloat, spacing: CGFloat) -> CGFloat {
//        var newSummedWidth: CGFloat = 0
//
//        for thumbnail in thumbnails {
//            newSummedWidth += CGFloat(thumbnail.scaledSize.width)
//        }
//
//        let spacingWidth = spacing * CGFloat(thumbnails.count - 1)
//        let shrinkRatio: CGFloat = (fullWidth - spacingWidth) / newSummedWidth
//
//        return shrinkRatio
//    }
//
//    func cancelDownloadingThumbnails() {
//        metadatas.forEach { metadata in
//            for case let operation as NCMediaDownloadThumbnaill in queuer.operations where operation.metadata.ocId == metadata.ocId {
//                operation.cancel()
//            }
//        }
//    }

