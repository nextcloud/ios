//
//  NCMediaRowViewModel.swift
//  Nextcloud
//
//  Created by Milen on 05.09.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import Foundation
import NextcloudKit
import Queuer

struct RowData {
    var scaledThumbnails: [ScaledThumbnail] = []
    var shrinkRatio: CGFloat = 0
}

struct ScaledThumbnail: Hashable {
    let image: UIImage
    var isPlaceholderImage = false
    var scaledSize: CGSize = .zero
    let metadata: tableMetadata

    func hash(into hasher: inout Hasher) {
        hasher.combine(metadata.ocId)
    }
}

@MainActor class NCMediaRowViewModel: ObservableObject {
    @Published private(set) var rowData = RowData()

    private var metadatas: [tableMetadata] = []

    internal let cache = NCCache()

//    internal lazy var cache = manager.cache
//    internal lazy var thumbnailsQueue = manager.queuer

    var operations: [ConcurrentOperation] = []

    func configure(metadatas: [tableMetadata]) {
        self.metadatas = metadatas
    }

    func downloadThumbnails(rowWidth: CGFloat, spacing: CGFloat) {
        var thumbnails: [ScaledThumbnail] = []

        metadatas.forEach { metadata in
            let thumbnailPath = NCUtilityFileSystem().getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)
            if let cachedImage = cache.getMediaImage(ocId: metadata.ocId) {
                let thumbnail = ScaledThumbnail(image: cachedImage, metadata: metadata)
                thumbnails.append(thumbnail)

                DispatchQueue.main.async {
                    self.calculateShrinkRatio(thumbnails: &thumbnails, rowWidth: rowWidth, spacing: spacing)
                }
            } else if FileManager.default.fileExists(atPath: thumbnailPath) {
                // Load thumbnail from file
                if let image = UIImage(contentsOfFile: thumbnailPath) {
                    let thumbnail = ScaledThumbnail(image: image, metadata: metadata)
                    cache.setMediaImage(ocId: metadata.ocId, image: image)
//                    cache.setValue(thumbnail, forKey: metadata.ocId)
                    thumbnails.append(thumbnail)

                    DispatchQueue.main.async {
                        self.calculateShrinkRatio(thumbnails: &thumbnails, rowWidth: rowWidth, spacing: spacing)
                    }
                }
            } else {
                let fileNamePath = NCUtilityFileSystem().getFileNamePath(metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId)
                let fileNamePreviewLocalPath = NCUtilityFileSystem().getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)
                let fileNameIconLocalPath = NCUtilityFileSystem().getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)

                var etagResource: String?
                if FileManager.default.fileExists(atPath: fileNameIconLocalPath) && FileManager.default.fileExists(atPath: fileNamePreviewLocalPath) {
                    etagResource = metadata.etagResource
                }
                let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

//                let concurrentOperation = ConcurrentOperation { _ in
                    NextcloudKit.shared.downloadPreview(
                        fileNamePathOrFileId: fileNamePath,
                        fileNamePreviewLocalPath: fileNamePreviewLocalPath,
                        widthPreview: Int(UIScreen.main.bounds.width) / 2,
                        heightPreview: Int(UIScreen.main.bounds.height) / 2,
                        fileNameIconLocalPath: fileNameIconLocalPath,
                        sizeIcon: NCGlobal.shared.sizeIcon,
                        etag: etagResource,
                        options: options) { _, _, imageIcon, _, etag, error in
                            NCManageDatabase.shared.setMetadataEtagResource(ocId: metadata.ocId, etagResource: etag)

                            let thumbnail: ScaledThumbnail

                            if error == .success, let image = imageIcon {
                                thumbnail = ScaledThumbnail(image: image, metadata: metadata)
                                self.cache.setMediaImage(ocId: metadata.ocId, image: image)
                            } else {
                                thumbnail = ScaledThumbnail(image: UIImage(systemName: metadata.isVideo ? "video.fill" : "photo.fill")!.withRenderingMode(.alwaysTemplate), isPlaceholderImage: true, metadata: metadata)
                            }

                            thumbnails.append(thumbnail)
//                            self.cache.setValue(thumbnail, forKey: metadata.ocId)

                            DispatchQueue.main.async {
                                self.calculateShrinkRatio(thumbnails: &thumbnails, rowWidth: rowWidth, spacing: spacing)
                            }
                        }
//                }

//                operations.append(concurrentOperation)
//                thumbnailsQueue.addOperation(concurrentOperation)
            }
        }
    }

    private func calculateShrinkRatio(thumbnails: inout [ScaledThumbnail], rowWidth: CGFloat, spacing: CGFloat) {
            if thumbnails.count == self.metadatas.count {
                thumbnails.enumerated().forEach { index, thumbnail in
                    thumbnails[index].scaledSize = self.getScaledThumbnailSize(of: thumbnail, thumbnailsInRow: thumbnails)
                }

                let shrinkRatio = self.getShrinkRatio(thumbnailsInRow: thumbnails, fullWidth: rowWidth, spacing: spacing)

                self.rowData.scaledThumbnails = thumbnails
                self.rowData.shrinkRatio = shrinkRatio
            }
        }

    func cancelDownloadingThumbnails() {
        operations.forEach {( $0.cancel() )}
        operations.removeAll()
    }

    private func getScaledThumbnailSize(of thumbnail: ScaledThumbnail, thumbnailsInRow thumbnails: [ScaledThumbnail]) -> CGSize {
        let maxHeight = thumbnails.compactMap { CGFloat($0.image.size.height) }.max() ?? 0

        let height = thumbnail.image.size.height
        let width = thumbnail.image.size.width

        let scaleFactor = maxHeight / height
        let newHeight = height * scaleFactor
        let newWidth = width * scaleFactor

        return .init(width: newWidth, height: newHeight)
    }

    private func getShrinkRatio(thumbnailsInRow thumbnails: [ScaledThumbnail], fullWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        var newSummedWidth: CGFloat = 0

        for thumbnail in thumbnails {
            newSummedWidth += CGFloat(thumbnail.scaledSize.width)
        }

        let spacingWidth = spacing * CGFloat(thumbnails.count - 1)
        let shrinkRatio: CGFloat = (fullWidth - spacingWidth) / newSummedWidth

        return shrinkRatio
    }
}
