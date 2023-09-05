//
//  NCMediaRowViewModel.swift
//  Nextcloud
//
//  Created by Milen on 05.09.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import Foundation
import NextcloudKit

@MainActor class NCMediaRowViewModel: ObservableObject {
    @Published private(set) var rowData = RowData()

    private var metadatas: [tableMetadata] = []

    func configure(metadatas: [tableMetadata]) {
        self.metadatas = metadatas
    }

    func downloadThumbnails() {
        var thumbnails: [ScaledThumbnail] = []

        metadatas.enumerated().forEach { index, metadata in
            let thumbnailPath = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)

            if let thumbnailPath, FileManager.default.fileExists(atPath: thumbnailPath) {
                // Load thumbnail from file
                if let image = UIImage(contentsOfFile: thumbnailPath) {
                    thumbnails.append(ScaledThumbnail(image: image, metadata: metadata))

                    if thumbnails.count == self.metadatas.count {
                        thumbnails.enumerated().forEach { index, thumbnail in
                            thumbnails[index].scaledSize = getScaledThumbnailSize(of: thumbnail, thumbnailsInRow: thumbnails)
                        }

                        let shrinkRatio = getShrinkRatio(thumbnailsInRow: thumbnails, fullWidth: UIScreen.main.bounds.width)

                        rowData.scaledThumbnails = thumbnails
                        rowData.shrinkRatio = shrinkRatio
                    }
                }
            } else {
                let fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId, account: metadata.account)!
                let fileNamePreviewLocalPath = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)!
                let fileNameIconLocalPath = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)!

                var etagResource: String?
                if FileManager.default.fileExists(atPath: fileNameIconLocalPath) && FileManager.default.fileExists(atPath: fileNamePreviewLocalPath) {
                    etagResource = metadata.etagResource
                }
                let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

                NextcloudKit.shared.downloadPreview(
                    fileNamePathOrFileId: fileNamePath,
                    fileNamePreviewLocalPath: fileNamePreviewLocalPath,
                    widthPreview: Int(UIScreen.main.bounds.width) / 2,
                    heightPreview: Int(UIScreen.main.bounds.height) / 2,
                    fileNameIconLocalPath: fileNameIconLocalPath,
                    sizeIcon: NCGlobal.shared.sizeIcon,
                    etag: etagResource,
                    options: options) { _, _, imageIcon, _, etag, error in
                        if error == .success, let image = imageIcon {
                            NCManageDatabase.shared.setMetadataEtagResource(ocId: metadata.ocId, etagResource: etag)
                            DispatchQueue.main.async {
                                thumbnails.append(ScaledThumbnail(image: image, metadata: metadata))

                                if thumbnails.count == self.metadatas.count {
                                    thumbnails.enumerated().forEach { index, thumbnail in
                                        thumbnails[index].scaledSize = self.getScaledThumbnailSize(of: thumbnail, thumbnailsInRow: thumbnails)
                                    }

                                    let shrinkRatio = self.getShrinkRatio(thumbnailsInRow: thumbnails, fullWidth: UIScreen.main.bounds.width)

                                    self.rowData.scaledThumbnails = thumbnails
                                    self.rowData.shrinkRatio = shrinkRatio
                                }
                            }
                        }
                    }
            }
        }

    }

    func getScaledThumbnailSize(of thumbnail: ScaledThumbnail, thumbnailsInRow thumbnails: [ScaledThumbnail]) -> CGSize {
        let maxHeight = thumbnails.compactMap { CGFloat($0.image.size.height) }.max() ?? 0

        let height = thumbnail.image.size.height
        let width = thumbnail.image.size.width

        let scaleFactor = maxHeight / height
        let newHeight = height * scaleFactor
        let newWidth = width * scaleFactor

        return .init(width: newWidth, height: newHeight)
    }

    func getShrinkRatio(thumbnailsInRow thumbnails: [ScaledThumbnail], fullWidth: CGFloat) -> CGFloat {
        var newSummedWidth: CGFloat = 0

        for thumbnail in thumbnails {
            newSummedWidth += CGFloat(thumbnail.scaledSize.width)
        }

        let shrinkRatio: CGFloat = fullWidth / newSummedWidth

        return shrinkRatio
    }
}
